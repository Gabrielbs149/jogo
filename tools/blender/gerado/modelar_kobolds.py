"""Tico-Lirou e Tika-Muro refeitos do zero (D039), no estilo dos personagens do KayKit/Quaternius: chibi, liso,
cores chapadas. Corpo e cabeça numa malha fechada só (metaballs -> remesh), então o peso dos ossos sai certo pelo
cálculo de calor do Blender; roupas coladas no corpo herdam o peso da pele mais próxima; acessórios rígidos.
Esqueleto HUMANOIDE (mesmos nomes do D028) para usar as animações do KayKit pelo retarget do Godot.

Uso: blender --background --factory-startup --python tools/blender/gerado/modelar_kobolds.py -- C:/dev/jogo [tico|tika]
Saída: actors/tico_lirou/tico_lirou_humanoide.glb, actors/tika_muro/tika_muro.glb e os .blend em art_src/.
Referência do Tico: art_src/ref/tico_ref.png. Tika: kobold de roxo, olhos rosa, cogumelo grande, duas espadas.
No Blender o personagem olha para +Y (esquerda dele em -X) e sai virado 180° (olha para +Z no Godot, como o KayKit).
"""
import math
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ROOT = ARGS[0] if ARGS else "C:/dev/jogo"
ONLY = ARGS[1] if len(ARGS) > 1 else ""
K = 10.0  # tudo 10x maior durante a montagem (o cálculo de calor falha em modelos pequenos)
V = 0.574  # raio visível de uma metaball (rigidez 2, limiar 0,6) por raio de influência

# ------------------------------------------------------------------------------------------------ cores


def material(name, color, rough=0.85, emission=0.0, metal=0.0):
    mat = bpy.data.materials.get(name)
    if mat:
        return mat
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if emission > 0:
        bsdf.inputs["Emission Color"].default_value = (*color, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission
    return mat


def srgb(hex_color):
    """'#7fbf4d' -> cor linear do Blender."""
    h = hex_color.lstrip("#")
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return tuple(out)


# ------------------------------------------------------------------------------------------------ peças


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def S(v):
    return Vector(v) * K


def _finish(o, mat, bone=None):
    bpy.context.view_layer.objects.active = o
    for other in bpy.context.scene.objects:
        other.select_set(other == o)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if mat:
        o.data.materials.append(mat)
    if bone:
        g = o.vertex_groups.new(name=bone)
        g.add(list(range(len(o.data.vertices))), 1.0, "REPLACE")
    return o


def smooth(o, level=1):
    for p in o.data.polygons:
        p.use_smooth = True
    if level:
        mod = o.modifiers.new("Sub", "SUBSURF")
        mod.levels = level
        mod.render_levels = level
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return o


def sphere(mat, center, half, bone=None, rot=(0, 0, 0), segs=16, rings=10):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segs, ring_count=rings, radius=1.0)
    o = bpy.context.active_object
    o.scale = S(half)
    o.rotation_euler = rot
    o.location = S(center)
    _finish(o, mat, bone)
    for p in o.data.polygons:
        p.use_smooth = True
    return o


def cone(mat, a, b, r1, r2, bone=None, verts=10):
    a, b = S(a), S(b)
    d = b - a
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1 * K, radius2=r2 * K, depth=d.length)
    o = bpy.context.active_object
    o.rotation_euler = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_euler()
    o.location = (a + b) / 2
    _finish(o, mat, bone)
    for p in o.data.polygons:
        p.use_smooth = True
    return o


def box(mat, center, size, bone=None, rot=(0, 0, 0), bevel=0.25, sub=2):
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    o = bpy.context.active_object
    o.scale = S(size)
    bpy.ops.object.transform_apply(scale=True)
    if bevel > 0:
        mod = o.modifiers.new("Bevel", "BEVEL")
        mod.width = min(size) * K * bevel
        mod.segments = 2
        bpy.ops.object.modifier_apply(modifier=mod.name)
    o.rotation_euler = rot
    o.location = S(center)
    _finish(o, mat, bone)
    smooth(o, 0)
    return o


def torus(mat, center, major, minor, bone=None, rot=(0, 0, 0), scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_torus_add(major_radius=major * K, minor_radius=minor * K, major_segments=24, minor_segments=8)
    o = bpy.context.active_object
    o.scale = scale
    o.rotation_euler = rot
    o.location = S(center)
    _finish(o, mat, bone)
    for p in o.data.polygons:
        p.use_smooth = True
    return o


def join(objs, name):
    bpy.context.view_layer.objects.active = objs[0]
    for o in bpy.context.scene.objects:
        o.select_set(o in objs)
    bpy.ops.object.join()
    o = bpy.context.active_object
    o.name = name
    return o


# ------------------------------------------------------------------------------------------------ corpo


class Body:
    """Corpo inteiro (cabeça, tronco, braços, pernas, rabo) em metaballs; vira uma malha fechada e lisa."""

    def __init__(self):
        self.mb = bpy.data.metaballs.new("Corpo")
        self.mb.threshold = 0.6
        self.mb.resolution = 0.012 * K
        self.mb.render_resolution = 0.012 * K
        self.obj = bpy.data.objects.new("Corpo", self.mb)
        bpy.context.scene.collection.objects.link(self.obj)

    def ell(self, center, half, rot=None):
        e = self.mb.elements.new()
        e.type = "ELLIPSOID"
        big = max(half)
        e.co = S(center)
        e.radius = big * K / V
        e.size_x, e.size_y, e.size_z = half[0] / big, half[1] / big, half[2] / big
        e.stiffness = 2.0
        if rot:
            e.rotation = rot.to_quaternion() if hasattr(rot, "to_quaternion") else rot

    def ball(self, center, r):
        self.ell(center, (r, r, r))

    def chain(self, points):
        """points: [(centro, raio)] — bolas ao longo de cada trecho, raio interpolado."""
        for (a, ra), (b, rb) in zip(points, points[1:]):
            a, b = Vector(a), Vector(b)
            n = max(2, int((b - a).length / (0.45 * min(ra, rb))) + 1)
            for i in range(n):
                t = i / (n - 1)
                self.ball(a.lerp(b, t), ra + (rb - ra) * t)

    def to_mesh(self, voxel=0.0075, faces=14000):
        bpy.context.view_layer.update()
        dg = bpy.context.evaluated_depsgraph_get()
        me = bpy.data.meshes.new_from_object(self.obj.evaluated_get(dg))
        body = bpy.data.objects.new("Corpo_malha", me)
        bpy.context.scene.collection.objects.link(body)
        bpy.data.objects.remove(self.obj)
        bpy.context.view_layer.objects.active = body
        for o in bpy.context.scene.objects:
            o.select_set(o == body)
        mod = body.modifiers.new("Remesh", "REMESH")
        mod.mode = "VOXEL"
        mod.voxel_size = voxel * K
        bpy.ops.object.modifier_apply(modifier=mod.name)
        mod = body.modifiers.new("Liso", "SMOOTH")
        mod.factor = 0.5
        mod.iterations = 4
        bpy.ops.object.modifier_apply(modifier=mod.name)
        mod = body.modifiers.new("Menos", "DECIMATE")
        mod.ratio = min(1.0, faces / max(1, len(body.data.polygons)))
        bpy.ops.object.modifier_apply(modifier=mod.name)
        for p in body.data.polygons:
            p.use_smooth = True
        return body


class Surface:
    """Acha pontos na pele por raio (para encaixar olho, chifre, dente, pinta...)."""

    def __init__(self, obj):
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bm.transform(obj.matrix_world)
        self.tree = BVHTree.FromBMesh(bm)
        bm.free()

    def hit(self, origin, toward):
        """Raio de `origin` (fora) apontando para `toward` (dentro), em metros. Devolve (ponto, normal) em metros."""
        o, t = S(origin), S(toward)
        loc, normal, _i, _d = self.tree.ray_cast(o, (t - o).normalized())
        if loc is None:
            return Vector(toward), Vector((0, 0, 1))
        return loc / K, normal

    def nearest(self, p):
        loc, normal, _i, _d = self.tree.find_nearest(S(p))
        return loc / K, normal


def paint(body, rules, default):
    """Pinta cada face da pele com a primeira regra que bater: rules = [(material, função(centro, normal) -> bool)]."""
    mats = [default] + [m for m, _f in rules]
    body.data.materials.clear()
    index = {}
    for m in mats:
        if m.name not in index:
            body.data.materials.append(m)
            index[m.name] = len(body.data.materials) - 1
    for p in body.data.polygons:
        c = Vector(p.center) / K
        n = Vector(p.normal)
        p.material_index = index[default.name]
        for m, f in rules:
            if f(c, n):
                p.material_index = index[m.name]
                break


def spots(body, surface, region, count, size, seed):
    """Lista de pintas (centro, raio) espalhadas na pele, dentro de `region(c, n)`."""
    rnd = random.Random(seed)
    polys = [p for p in body.data.polygons if region(Vector(p.center) / K, Vector(p.normal))]
    out = []
    for _i in range(count):
        if not polys:
            break
        p = rnd.choice(polys)
        out.append((Vector(p.center) / K, rnd.uniform(size * 0.6, size * 1.3)))
    return out


def spot_discs(surface, spot_list, mat):
    parts = []
    for c, r in spot_list:
        p, n = surface.nearest(c)
        rot = Vector((0, 0, 1)).rotation_difference(n).to_euler()
        parts.append(sphere(mat, p - n * r * 0.18, (r, r, r * 0.3), None, rot, segs=12, rings=6))
    return parts


def in_spots(spot_list):
    def f(c, _n):
        for s, r in spot_list:
            if (c - s).length < r:
                return True
        return False
    return f


# ------------------------------------------------------------------------------------------------ esqueleto

BONES = {
    "Root": ((0, 0, 0), (0, 0.12, 0), None),
    "Hips": ((0, 0, 0.31), (0, 0, 0.44), "Root"),
    "Spine": ((0, 0, 0.44), (0, 0.005, 0.54), "Hips"),
    "Chest": ((0, 0.005, 0.54), (0, 0.01, 0.64), "Spine"),
    "Neck": ((0, 0.01, 0.64), (0, 0.02, 0.71), "Chest"),
    "Head": ((0, 0.02, 0.71), (0, 0.04, 1.0), "Neck"),
    "LeftUpperArm": ((-0.13, 0.0, 0.6), (-0.21, 0.02, 0.48), "Chest"),
    "LeftLowerArm": ((-0.21, 0.02, 0.48), (-0.26, 0.06, 0.37), "LeftUpperArm"),
    "LeftHand": ((-0.26, 0.06, 0.37), (-0.29, 0.09, 0.28), "LeftLowerArm"),
    "RightUpperArm": ((0.13, 0.0, 0.6), (0.21, 0.02, 0.48), "Chest"),
    "RightLowerArm": ((0.21, 0.02, 0.48), (0.26, 0.06, 0.37), "RightUpperArm"),
    "RightHand": ((0.26, 0.06, 0.37), (0.29, 0.09, 0.28), "RightLowerArm"),
    "LeftUpperLeg": ((-0.09, 0.0, 0.29), (-0.105, 0.02, 0.17), "Hips"),
    "LeftLowerLeg": ((-0.105, 0.02, 0.17), (-0.115, 0.0, 0.065), "LeftUpperLeg"),
    "LeftFoot": ((-0.115, 0.0, 0.065), (-0.12, 0.13, 0.02), "LeftLowerLeg"),
    "RightUpperLeg": ((0.09, 0.0, 0.29), (0.105, 0.02, 0.17), "Hips"),
    "RightLowerLeg": ((0.105, 0.02, 0.17), (0.115, 0.0, 0.065), "RightUpperLeg"),
    "RightFoot": ((0.115, 0.0, 0.065), (0.12, 0.13, 0.02), "RightLowerLeg"),
    "Tail1": ((0, -0.1, 0.31), (0, -0.27, 0.23), "Hips"),
    "Tail2": ((0, -0.27, 0.23), (0, -0.44, 0.165), "Tail1"),
    "Tail3": ((0, -0.44, 0.165), (0, -0.68, 0.12), "Tail2"),
}


ALL = ("tronco", "cabeca", "bracos", "pernas", "rabo")


def kobold_body(p, parts=ALL, voxel=0.0075, faces=14000):
    """Corpo de kobold chibi. p = proporções (dicionário com 'magro', 'rabo'). parts = só algumas partes
    (serve para medir a roupa contra o tronco, o braço ou a perna sem os outros membros atrapalharem)."""
    b = Body()
    slim = p.get("magro", 1.0)
    if "tronco" in parts:
        _torso(b, slim)
    if "cabeca" in parts:
        _head(b)
    if "bracos" in parts:
        _arms(b)
    if "pernas" in parts:
        _legs(b)
    if "rabo" in parts:
        _tail(b, p)
    return b.to_mesh(voxel, faces)


def surfaces(p):
    """Superfícies só do tronco (com a base do rabo), só dos braços e só das pernas, para vestir a roupa."""
    out = {}
    for key, parts in (("tronco", ("tronco", "rabo")), ("bracos", ("bracos",)), ("pernas", ("pernas",))):
        mesh = kobold_body(p, parts, voxel=0.012, faces=6000)
        out[key] = Surface(mesh)
        bpy.data.objects.remove(mesh)
    return out


def _torso(b, slim):
    # tronco: quadril largo, barriga redonda, peito, pescoço
    b.ell((0, 0.0, 0.37), (0.165 * slim, 0.145, 0.15))
    b.ell((0, 0.035, 0.41), (0.135 * slim, 0.13, 0.13))
    b.ell((0, 0.0, 0.53), (0.135 * slim, 0.11, 0.11))
    b.ell((0, 0.01, 0.64), (0.08, 0.075, 0.07))


def _head(b):
    # cabeça: crânio, focinho comprido, mandíbula, bochechas, ponta do focinho
    b.ell((0, 0.0, 0.84), (0.17, 0.16, 0.15))
    b.ell((0, 0.13, 0.79), (0.13, 0.13, 0.095))
    b.ell((0, 0.24, 0.775), (0.1, 0.075, 0.072))
    b.ell((0, 0.13, 0.72), (0.115, 0.13, 0.05))
    for s in (-1, 1):
        b.ell((s * 0.1, 0.07, 0.78), (0.07, 0.075, 0.07))


def _arms(b):
    # braços: ombro, cotovelo, pulso, mão e três dedos
    for s in (-1, 1):
        b.chain([((s * 0.12, 0.0, 0.595), 0.05), ((s * 0.21, 0.02, 0.48), 0.042), ((s * 0.26, 0.06, 0.37), 0.038)])
        b.ell((s * 0.275, 0.075, 0.33), (0.048, 0.045, 0.052))
        for k, dx in enumerate((-0.022, 0.0, 0.022)):
            b.chain([((s * 0.28 + dx * s * 0.6, 0.095, 0.3), 0.02), ((s * 0.285 + dx * s, 0.11, 0.265), 0.016)])
        b.chain([((s * 0.25, 0.09, 0.34), 0.018), ((s * 0.245, 0.115, 0.31), 0.015)])  # dedão


def _legs(b):
    # pernas: coxa grossa, joelho, tornozelo, pé com três dedos
    for s in (-1, 1):
        b.chain([((s * 0.09, 0.0, 0.29), 0.078), ((s * 0.105, 0.02, 0.17), 0.06), ((s * 0.115, 0.0, 0.075), 0.05)])
        b.ell((s * 0.118, 0.045, 0.035), (0.06, 0.09, 0.035))
        for dx in (-0.03, 0.0, 0.03):
            b.chain([((s * 0.118 + dx, 0.1, 0.03), 0.022), ((s * 0.118 + dx * 1.3, 0.14, 0.022), 0.017)])


def _tail(b, p):
    # rabo
    b.chain([((0, -0.08, 0.32), 0.11), ((0, -0.27, 0.235), 0.075), ((0, -0.44, 0.17), 0.05),
             ((0, -0.58, 0.13), 0.03), ((0, -0.69 * p.get("rabo", 1.0), 0.115), 0.012)])


def armature(name):
    data = bpy.data.armatures.new(name)
    rig = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    for o in bpy.context.scene.objects:
        o.select_set(o == rig)
    bpy.ops.object.mode_set(mode="EDIT")
    for bone, (head, tail, _parent) in BONES.items():
        eb = data.edit_bones.new(bone)
        eb.head = S(head)
        eb.tail = S(tail)
        eb.use_deform = bone != "Root"
    for bone, (_h, _t, parent) in BONES.items():
        if parent:
            data.edit_bones[bone].parent = data.edit_bones[parent]
            data.edit_bones[bone].use_connect = False
    bpy.ops.armature.select_all(action="SELECT")
    bpy.ops.armature.calculate_roll(type="GLOBAL_NEG_Y")
    bpy.ops.object.mode_set(mode="OBJECT")
    return rig


def skin_body(body, rig):
    """Pele: pesos pelo cálculo de calor (malha fechada)."""
    for o in bpy.context.scene.objects:
        o.select_set(o in (body, rig))
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    missing = sum(1 for v in body.data.vertices if not v.groups)
    print("pele sem peso:", missing, "de", len(body.data.vertices))


def copy_weights(cloth, body):
    """Roupa colada: cada vértice pega o peso da pele mais próxima."""
    for bone in BONES:
        if bone != "Root" and bone not in cloth.vertex_groups:
            cloth.vertex_groups.new(name=bone)
    mod = cloth.modifiers.new("Pesos", "DATA_TRANSFER")
    mod.object = body
    mod.use_vert_data = True
    mod.data_types_verts = {"VGROUP_WEIGHTS"}
    mod.vert_mapping = "POLYINTERP_NEAREST"
    mod.layers_vgroup_select_src = "ALL"
    mod.layers_vgroup_select_dst = "NAME"
    bpy.context.view_layer.objects.active = cloth
    for o in bpy.context.scene.objects:
        o.select_set(o == cloth)
    bpy.ops.object.modifier_apply(modifier=mod.name)


def finish_rig(rig, parts, body, name, out_glb, blend):
    """Junta tudo numa malha, limita a 4 ossos por vértice, vira 180° e exporta."""
    rigid = [o for o in parts if o.vertex_groups and len(o.vertex_groups) == 1]
    cloth = [o for o in parts if o not in rigid]
    for o in cloth:
        copy_weights(o, body)
    mesh = join([body] + parts, name)
    for m in list(mesh.modifiers):
        mesh.modifiers.remove(m)
    bpy.context.view_layer.objects.active = mesh
    for o in bpy.context.scene.objects:
        o.select_set(o == mesh)
    bpy.ops.object.vertex_group_limit_total(limit=4)
    bpy.ops.object.vertex_group_normalize_all(lock_active=False)
    mesh.parent = rig
    mesh.matrix_parent_inverse = rig.matrix_world.inverted()
    mod = mesh.modifiers.new("Armature", "ARMATURE")
    mod.object = rig
    rig.rotation_euler = (0, 0, math.pi)
    rig.scale = (1 / K, 1 / K, 1 / K)
    for o in bpy.context.scene.objects:
        o.select_set(o in (rig, mesh))
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bpy.ops.wm.save_as_mainfile(filepath=blend)
    for o in bpy.context.scene.objects:
        o.select_set(o in (rig, mesh))
    bpy.ops.export_scene.gltf(
        filepath=out_glb, export_format="GLB", use_selection=True, export_yup=True, export_apply=False,
        export_skins=True, export_animations=False, export_def_bones=False,
    )
    print("exportado", out_glb, len(mesh.data.polygons), "faces")


# ------------------------------------------------------------------------------------------------ rosto


def eye(surface, s, iris_color, place, size=0.062, look=0.35, lashes=None):
    """Olho grande de desenho: branco, íris, pupila e brilho, encaixado na lateral da cabeça."""
    white = material("Olho_branco", srgb("#f7f4ee"), rough=0.3)
    iris = material("Iris_" + iris_color, srgb(iris_color), rough=0.3)
    black = material("Pupila", srgb("#14100e"), rough=0.3)
    shine = material("Brilho", (1, 1, 1), rough=0.1, emission=1.5)
    head = Vector((0, 0.02, 0.84))
    target = Vector((s * place[0], place[1], place[2]))
    point, normal = surface.hit(head + (target - head) * 3.0, head)
    out = (normal.normalized() + Vector((0, look, 0))).normalized()
    center = point - out * size * 0.35
    rot = Vector((0, 0, 1)).rotation_difference(out).to_euler()
    parts = [sphere(white, center, (size, size, size * 0.8), "Head", rot)]
    parts.append(sphere(iris, center + out * size * 0.68, (size * 0.66, size * 0.72, size * 0.22), "Head", rot))
    parts.append(sphere(black, center + out * size * 0.8, (size * 0.33, size * 0.4, size * 0.12), "Head", rot))
    up = Vector((0, 0, 1))
    parts.append(sphere(shine, center + out * size * 0.86 + up * size * 0.25 - Vector((s, 0, 0)) * size * 0.12,
                        (size * 0.15, size * 0.15, size * 0.06), "Head", rot, segs=10, rings=6))
    if lashes:
        lash = material("Cilios", srgb("#1b1418"))
        for k, ang in enumerate((-0.6, -0.15, 0.3)):
            base = center + out * size * 0.3 + up * size * 0.85 + Vector((s * 0.6, 0, 0)) * size * (0.3 + ang * 0.6)
            tip = base + (up * 0.7 + Vector((s, 0, 0)) * (0.6 + k * 0.25) - out * 0.1).normalized() * size * 0.55
            parts.append(cone(lash, base, tip, size * 0.07, 0.0, "Head", verts=6))
    return parts


def face_details(surface, horn_color, teeth=True, nostrils=True):
    parts = []
    horn = material("Chifre", srgb(horn_color), rough=0.6)
    for s in (-1, 1):
        base, n = surface.hit((s * 0.25, -0.05, 1.15), (s * 0.06, 0.0, 0.84))
        tip = base + (Vector((s * 0.35, -0.55, 1.0)).normalized()) * 0.11
        mid = base + (tip - base) * 0.5 + Vector((0, 0.02, 0.0))
        parts.append(cone(horn, base - n * 0.01, mid, 0.03, 0.02, "Head"))
        parts.append(cone(horn, mid, tip, 0.021, 0.0, "Head"))
    if nostrils:
        dark = material("Narina", srgb("#2a3a20"))
        for s in (-1, 1):
            p, n = surface.hit((s * 0.04, 0.5, 0.82), (s * 0.03, 0.2, 0.79))
            parts.append(sphere(dark, p - n * 0.003, (0.01, 0.01, 0.006), "Head",
                                Vector((0, 0, 1)).rotation_difference(n).to_euler(), segs=8, rings=5))
    if teeth:
        white = material("Dente", srgb("#fbf6e8"), rough=0.4)
        for k in range(7):
            x = (k - 3) * 0.033
            y = 0.2 - abs(x) * 1.1
            p, n = surface.hit((x * 1.4, y + 0.3, 0.745), (0, y - 0.1, 0.745))
            parts.append(cone(white, p - n * 0.004, p + Vector((0, 0, -0.022)) + n * 0.006, 0.009, 0.0, "Head", verts=6))
    return parts


# ------------------------------------------------------------------------------------------------ roupas


def shell(mat, ring_points, thickness, bone=None):
    """Malha de roupa por anéis: ring_points = lista de anéis (cada um uma lista de pontos em metros)."""
    bm = bmesh.new()
    rings = [[bm.verts.new(S(p)) for p in ring] for ring in ring_points]
    n = len(rings[0])
    for a, b in zip(rings, rings[1:]):
        for i in range(n):
            j = (i + 1) % n
            if a[i] is None or b[i] is None or a[j] is None or b[j] is None:
                continue
            bm.faces.new((a[i], a[j], b[j], b[i]))
    me = bpy.data.meshes.new("Roupa")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("Roupa", me)
    bpy.context.scene.collection.objects.link(o)
    _finish(o, mat, bone)
    mod = o.modifiers.new("Grossura", "SOLIDIFY")
    mod.thickness = thickness * K
    mod.offset = 1.0
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.modifier_apply(modifier=mod.name)
    smooth(o, 1)
    return o


def around(surface, axis_a, axis_b, levels, gap, segs=28, skip=None, flare=None):
    """Anéis em volta de um eixo (tronco, braço), colados na pele + `gap`. skip(ângulo, t) apaga um pedaço (abertura)."""
    a, b = Vector(axis_a), Vector(axis_b)
    d = (b - a).normalized()
    side = Vector((1, 0, 0)) if abs(d.x) < 0.9 else Vector((0, 1, 0))
    u = (side - d * side.dot(d)).normalized()
    w = d.cross(u)
    rings = []
    for t in levels:
        c = a + (b - a) * t
        ring = []
        for i in range(segs):
            ang = 2 * math.pi * i / segs
            dirv = u * math.cos(ang) + w * math.sin(ang)
            if skip and skip(ang, t, dirv):
                ring.append(None)
                continue
            p, _n = surface.hit(c + dirv * 0.6, c)
            extra = gap + (flare(t) if flare else 0.0)
            ring.append(p + dirv * extra)
        rings.append(ring)
    # anéis com buraco: a face só nasce onde os quatro cantos existem
    return [[p if p is not None else None for p in ring] for ring in rings]


def shell_rings(mat, rings, thickness):
    """Como shell(), mas aceita None (buraco) dentro dos anéis."""
    bm = bmesh.new()
    vs = [[bm.verts.new(S(p)) if p is not None else None for p in ring] for ring in rings]
    n = len(vs[0])
    for a, b in zip(vs, vs[1:]):
        for i in range(n):
            j = (i + 1) % n
            q = (a[i], a[j], b[j], b[i])
            if any(v is None for v in q):
                continue
            bm.faces.new(q)
    for v in [v for v in bm.verts if not v.link_faces]:
        bm.verts.remove(v)
    me = bpy.data.meshes.new("Roupa")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("Roupa", me)
    bpy.context.scene.collection.objects.link(o)
    _finish(o, mat)
    mod = o.modifiers.new("Grossura", "SOLIDIFY")
    mod.thickness = thickness * K
    mod.offset = 1.0
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.modifier_apply(modifier=mod.name)
    smooth(o, 1)
    return o


def hood(mat, surface, tip, opening=0.32, low=0.6, extra=0.035):
    """Capuz: casca em volta da cabeça, aberta na frente para o rosto, ponta para trás e caindo até os ombros."""
    center = Vector((0, 0.0, 0.84))
    rings = []
    tip = Vector(tip)
    for k in range(13):
        lat = math.radians(90 - k * 13)  # do alto (90°) até bem embaixo
        ring = []
        for i in range(28):
            lon = 2 * math.pi * i / 28
            dirv = Vector((math.cos(lat) * math.sin(lon), math.cos(lat) * math.cos(lon), math.sin(lat))).normalized()
            front = dirv.y > opening - (0.25 if k > 8 else 0.0) and dirv.z > -0.95 + (0 if k < 11 else 0.0)
            if front and k >= 2:
                ring.append(None)
                continue
            p, _n = surface.hit(center + dirv * 0.7, center)
            q = p + dirv * extra
            if q.z < low:  # embaixo, o capuz cai até os ombros
                q.z = low + (q.z - low) * 0.3
            # ponta do capuz: puxa o alto de trás
            pull = max(0.0, dirv.dot((tip - center).normalized())) ** 6
            q = q.lerp(tip, pull * 0.85)
            ring.append(q)
        rings.append(ring)
    return shell_rings(mat, rings, 0.012)


def robe(mat, surface, top, bottom, gap, segs=32, opening=None, hem_jitter=0.0, seed=1, max_r=0.215):
    """Túnica/casaco: anéis do ombro até a barra. Colado no tronco em cima e solto (sem entrar nas pernas) embaixo.
    opening(t, dirv) -> True apaga (frente aberta)."""
    rnd = random.Random(seed)
    levels = 12
    radii = [0.0] * segs
    rings = []
    for k in range(levels):
        t = k / (levels - 1)
        z = top + (bottom - top) * t
        c = Vector((0, 0.0, z))
        ring = []
        for i in range(segs):
            ang = 2 * math.pi * i / segs
            dirv = Vector((math.sin(ang), math.cos(ang), 0))
            p, _n = surface.hit(c + dirv * 0.6, c)
            r = min((p - c).length + gap, max_r)
            if k > 0:
                r = max(r, radii[i] * 0.995)  # embaixo não volta para dentro (não entra entre as pernas)
            radii[i] = r
            zz = z - (rnd.uniform(0, hem_jitter) if k == levels - 1 else 0.0)
            ring.append(None if opening and opening(t, dirv) else Vector((c.x, c.y, zz)) + dirv * r)
        rings.append(ring)
    return shell_rings(mat, rings, 0.01)


def ring(mat, surface, center, axis, gap, minor=0.009, segs=16):
    """Argola/amarra justa em volta de um membro: mede o raio pela superfície e faz um toro."""
    c, d = Vector(center), Vector(axis).normalized()
    u = (Vector((1, 0, 0)) - d * d.x).normalized() if abs(d.x) < 0.9 else Vector((0, 1, 0))
    w = d.cross(u)
    rs = []
    for i in range(segs):
        ang = 2 * math.pi * i / segs
        dirv = u * math.cos(ang) + w * math.sin(ang)
        p, _n = surface.hit(c + dirv * 0.1, c)
        rs.append((p - c).length)
    r = sum(rs) / len(rs) + gap
    return torus(mat, center, r, minor, rot=Vector((0, 0, 1)).rotation_difference(d).to_euler())


def band(mat, surface, a, b, levels, gap, segs=20):
    return shell_rings(mat, around(surface, a, b, levels, gap, segs=segs), 0.008)


def backpack(leather, roll, strap, mush=None):
    parts = [box(leather, (0, -0.19, 0.5), (0.24, 0.13, 0.27), "Chest", bevel=0.3)]
    parts.append(box(leather, (0, -0.265, 0.45), (0.17, 0.05, 0.12), "Chest", bevel=0.35))
    parts.append(cone(roll, (-0.16, -0.19, 0.67), (0.16, -0.19, 0.67), 0.065, 0.065, "Chest", verts=16))
    for x in (-0.1, 0.1):
        parts.append(torus(strap, (x, -0.19, 0.67), 0.069, 0.008, "Chest", rot=(0, math.pi / 2, 0)))
    for s in (-1, 1):  # alças por cima dos ombros
        parts.append(torus(strap, (s * 0.085, -0.04, 0.585), 0.12, 0.011, "Chest", rot=(0, math.pi / 2, 0), scale=(1, 0.95, 1.1)))
    if mush:
        stem = material("Talo", srgb("#f1e6cc"))
        for (x, y, z), r, cap in mush:
            parts.append(cone(stem, (x, y, z), (x, y, z + r * 0.9), r * 0.35, r * 0.3, "Chest"))
            parts.append(sphere(cap, (x, y, z + r * 0.95), (r, r, r * 0.55), "Chest"))
    return parts


def claws(color):
    mat = material("Garra", srgb(color), rough=0.5)
    parts = []
    for s in (-1, 1):
        side = "Left" if s < 0 else "Right"
        for dx in (-0.022, 0.0, 0.022):
            a = Vector((s * 0.285 + dx * s, 0.112, 0.262))
            parts.append(cone(mat, a, a + Vector((0, 0.018, -0.022)), 0.009, 0.0, side + "Hand", verts=6))
        for dx in (-0.03, 0.0, 0.03):
            a = Vector((s * 0.118 + dx * 1.3, 0.155, 0.022))
            parts.append(cone(mat, a, a + Vector((0, 0.03, -0.012)), 0.01, 0.0, side + "Foot", verts=6))
    return parts


def tail_spikes(surface, color, count=6, start=0):
    mat = material("Espinho", srgb(color), rough=0.6)
    parts = []
    for k in range(start, count):
        t = 0.12 + k * 0.13
        y = -0.12 - t * 0.55
        z = 0.32 - t * 0.2 + 0.09 * (1 - t)
        p, n = surface.hit((0, y, z + 0.4), (0, y, z - 0.1))
        h = 0.04 * (1 - t * 0.7)
        parts.append(cone(mat, p - n * 0.01, p + (n + Vector((0, -0.6, 0))).normalized() * h, h * 0.55, 0.0, verts=6))
    return parts


# ------------------------------------------------------------------------------------------------ Tico


def tico():
    reset()
    skin = material("Pele", srgb("#6cb548"))
    spot = material("Pinta", srgb("#3f8a34"))
    belly = material("Barriga", srgb("#f3c393"))
    tail_under = material("RaboBaixo", srgb("#e9a26a"))
    shirt = material("Camisa", srgb("#4a3c6b"))
    wraps = material("Faixa", srgb("#7a5f46"))
    crest = material("Crista", srgb("#e8b2b6"))
    body = kobold_body({})
    surface = Surface(body)
    parts_of = surfaces({})

    def front_belly(c, n):
        return c.y > 0.03 and (c.x / 0.125) ** 2 + ((c.z - 0.36) / 0.15) ** 2 < 1.0

    def under_snout(c, n):
        return c.y > 0.0 and 0.64 < c.z < 0.752 and abs(c.x) < 0.16

    def tail_bottom(c, n):
        return c.y < -0.12 and c.z < 0.3 - (-c.y - 0.12) * 0.32

    def chest_shirt(c, n):
        return c.y > 0.0 and 0.46 < c.z < 0.62 and abs(c.x) < 0.1 and n.y > 0.4

    def leg_wrap(c, n):
        return abs(c.x) > 0.04 and 0.06 < c.z < 0.17 and c.y > -0.09

    def green(c, n):
        return not (front_belly(c, n) or under_snout(c, n) or tail_bottom(c, n))

    def spotty(c, n):  # pintas no alto da cabeça, nos braços, nas pernas e no rabo (não no rosto)
        top = c.z > 0.87 and c.y < 0.08
        return green(c, n) and (top or c.y < -0.25 or abs(c.x) > 0.17 or c.z < 0.25)

    sp = spots(body, surface, spotty, 45, 0.018, 7)
    paint(body, [(wraps, leg_wrap), (shirt, chest_shirt), (belly, front_belly), (belly, under_snout),
                 (tail_under, tail_bottom)], skin)
    rig = armature("TicoRig")
    skin_body(body, rig)

    parts = spot_discs(surface, sp, spot)
    for s in (-1, 1):
        parts += eye(surface, s, "#3c7fe3", (0.13, 0.12, 0.88), size=0.066)
    parts += face_details(surface, "#efe0b6")
    parts.append(sphere(crest, (0, -0.005, 0.975), (0.1, 0.11, 0.055), "Head"))
    teal = material("Capuz", srgb("#1f4e4a"))
    dark = material("Cachecol", srgb("#1c2322"))
    sash = material("Faixa_cintura", srgb("#d8c69a"))
    ring_mat = material("Amarra", srgb("#3a302c"))
    wraps_cloth = material("Perneira", srgb("#7d6249"))
    parts.append(hood(teal, surface, (0.07, -0.32, 1.06)))
    parts.append(robe(teal, parts_of["tronco"], 0.645, 0.19, 0.02, opening=lambda t, d: d.y > 0.8 - t * 0.12 and t > 0.06,
                      hem_jitter=0.03))
    for s in (-1, 1):  # mangas curtas até perto do cotovelo
        parts.append(band(teal, parts_of["bracos"], (s * 0.11, 0, 0.62), (s * 0.235, 0.04, 0.43), [0.12, 0.4, 0.7, 0.9], 0.016))
    parts.append(torus(dark, (0, 0.012, 0.648), 0.088, 0.034, scale=(1.05, 1, 0.75)))
    parts.append(cone(dark, (0.06, 0.09, 0.63), (0.08, 0.11, 0.5), 0.03, 0.022, verts=8))
    parts.append(band(sash, parts_of["tronco"], (0, 0, 0.44), (0, 0, 0.375), [0.0, 0.5, 1.0], 0.01, segs=28))
    parts.append(band(material("Babado", srgb("#c9b483")), parts_of["tronco"], (0, 0, 0.375), (0, 0, 0.35), [0.0, 1.0], 0.014, segs=28))
    for s in (-1, 1):  # faixas de pano nas canelas, com duas amarras escuras
        knee = Vector((s * 0.105, 0.02, 0.17))
        leg_axis = Vector((s * 0.115, 0.0, 0.065)) - knee
        parts.append(band(wraps_cloth, parts_of["pernas"], knee + leg_axis * 0.05, knee + leg_axis * 0.95, [0.0, 0.5, 1.0], 0.012, segs=18))
        for t in (0.25, 0.8):
            parts.append(ring(ring_mat, parts_of["pernas"], knee + leg_axis * t, leg_axis, 0.017, minor=0.007))
    parts += backpack(material("Couro", srgb("#7b4a2b")), material("Colchonete", srgb("#2e3540")),
                      material("Correia", srgb("#4a2f1e")),
                      mush=[((-0.06, -0.2, 0.73), 0.05, material("Cogumelo_rosa", srgb("#e46aa3"))),
                            ((0.05, -0.17, 0.74), 0.04, material("Cogumelo_roxo", srgb("#8a5cc9")))])
    # adaga na bainha, atravessada nas costas
    sheath = material("Bainha", srgb("#5b3a24"))
    parts.append(cone(sheath, (0.16, -0.16, 0.36), (0.25, -0.1, 0.14), 0.028, 0.02, "Hips", verts=8))
    parts.append(cone(material("Cabo", srgb("#d9d2c4")), (0.16, -0.16, 0.36), (0.12, -0.19, 0.44), 0.016, 0.016, "Hips", verts=8))
    parts += claws("#2b2420")
    parts += tail_spikes(surface, "#e6c58c", start=3)
    finish_rig(rig, parts, body, "TicoLirou", ROOT + "/actors/tico_lirou/tico_lirou_humanoide.glb",
               ROOT + "/art_src/tico_lirou_humanoide.blend")


# ------------------------------------------------------------------------------------------------ Tika


def tika():
    reset()
    skin = material("Pele", srgb("#7cc257"))
    spot = material("Pinta", srgb("#5ea33f"))
    belly = material("Barriga", srgb("#ece4ae"))
    blush = material("Bochecha", srgb("#f2a0b4"))
    pants = material("Calca", srgb("#b99a72"))
    body = kobold_body({"magro": 0.94})
    surface = Surface(body)
    parts_of = surfaces({"magro": 0.94})

    def front_belly(c, n):
        return c.y > 0.03 and (c.x / 0.12) ** 2 + ((c.z - 0.37) / 0.15) ** 2 < 1.0

    def under_snout(c, n):
        return c.y > 0.0 and 0.64 < c.z < 0.752 and abs(c.x) < 0.16

    def tail_bottom(c, n):
        return c.y < -0.12 and c.z < 0.3 - (-c.y - 0.12) * 0.32

    def cheek(c, n):
        return (c - Vector((math.copysign(0.14, c.x), 0.1, 0.78))).length < 0.035

    def legs(c, n):
        return abs(c.x) > 0.04 and 0.06 < c.z < 0.25 and c.y > -0.09

    def green(c, n):
        return not (front_belly(c, n) or under_snout(c, n) or tail_bottom(c, n))

    sp = spots(body, surface, lambda c, n: green(c, n) and (c.y < -0.15 or abs(c.x) > 0.2), 35, 0.018, 11)
    paint(body, [(pants, legs), (blush, cheek), (belly, front_belly), (belly, under_snout), (belly, tail_bottom)], skin)
    rig = armature("TikaRig")
    skin_body(body, rig)

    parts = spot_discs(surface, sp, spot)
    for s in (-1, 1):
        parts += eye(surface, s, "#e45ea4", (0.13, 0.12, 0.88), size=0.068, lashes=True)
    parts += face_details(surface, "#f2e6c4", teeth=False)
    purple = material("Capuz", srgb("#7a57a6"))
    trim = material("Barra", srgb("#5b3f82"))
    ring_mat = material("Amarra", srgb("#4a3a32"))
    parts.append(hood(purple, surface, (0.0, -0.3, 0.98), opening=0.3))
    parts.append(robe(purple, parts_of["tronco"], 0.645, 0.17, 0.022))
    for s in (-1, 1):
        parts.append(band(purple, parts_of["bracos"], (s * 0.11, 0, 0.62), (s * 0.235, 0.04, 0.43), [0.12, 0.42, 0.72, 0.95], 0.018))
        knee = Vector((s * 0.105, 0.02, 0.17))
        leg_axis = Vector((s * 0.115, 0.0, 0.065)) - knee
        parts.append(ring(ring_mat, parts_of["pernas"], knee + leg_axis * 0.8, leg_axis, 0.012))
    parts.append(torus(trim, (0, 0.012, 0.648), 0.086, 0.026, scale=(1.05, 1, 0.75)))
    parts.append(band(trim, parts_of["tronco"], (0, 0, 0.45), (0, 0, 0.405), [0.0, 0.5, 1.0], 0.036, segs=32))
    # cogumelo grande em cima do capuz
    cap = material("Cogumelo_tika", srgb("#f3c9da"))
    dots = material("Cogumelo_pinta", srgb("#4cc0b4"))
    parts.append(cone(material("Talo", srgb("#f1e6cc")), (0.0, -0.03, 0.97), (0.0, -0.03, 1.05), 0.045, 0.04, "Head"))
    parts.append(sphere(cap, (0.0, -0.03, 1.035), (0.14, 0.14, 0.08), "Head"))
    for k in range(6):
        a = k * math.pi / 3 + 0.3
        parts.append(sphere(dots, (math.cos(a) * 0.085, -0.03 + math.sin(a) * 0.085, 1.095), (0.022, 0.022, 0.01), "Head"))
    parts.append(sphere(dots, (0.0, -0.03, 1.125), (0.026, 0.026, 0.01), "Head"))
    parts += backpack(material("Couro", srgb("#b08a5c")), material("Colchonete", srgb("#8e98a3")),
                      material("Correia", srgb("#6b4c32")))
    # as duas espadas ("asas") cruzadas nas costas
    blade = material("Lamina", srgb("#c9d2da"), rough=0.3, metal=0.8)
    grip = material("Punho", srgb("#5a3a26"))
    for s in (-1, 1):
        a = Vector((s * 0.2, -0.25, 0.78))
        b = Vector((-s * 0.12, -0.24, 0.3))
        parts.append(cone(blade, a + (b - a) * 0.18, b, 0.032, 0.008, "Chest", verts=4))
        parts.append(cone(grip, a, a + (b - a) * 0.17, 0.012, 0.012, "Chest", verts=8))
        parts.append(box(grip, a + (b - a) * 0.18, (0.08, 0.02, 0.02), "Chest", bevel=0.3))
    parts += claws("#2f2628")
    parts += tail_spikes(surface, "#d9e3a8", count=6, start=3)
    finish_rig(rig, parts, body, "TikaMuro", ROOT + "/actors/tika_muro/tika_muro.glb", ROOT + "/art_src/tika_muro.blend")


if __name__ == "__main__":
    if ONLY in ("", "tico"):
        tico()
    if ONLY in ("", "tika"):
        tika()
