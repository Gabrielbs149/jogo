"""Modelos dos inimigos de Ethera (proposta, D036): escaravelho de cinza, sentinela estelar e Último Guardião.

Cada peça é RÍGIDA e presa a um osso só (peso 1): nada estica nem deforma, como bonecos de pedra articulados.
- Escaravelho e sentinela: esqueleto próprio + animações feitas aqui (Idle, Walk, Attack, Hit, Dodge, Death).
- Guardião: esqueleto HUMANOIDE (mesmos nomes do Tico, D028) e usa as animações do KayKit pelo retarget do Godot.

Uso: blender --background --factory-startup --python tools/blender/gerado/modelar_inimigos.py -- C:/dev/jogo [nome]
nome = escaravelho | sentinela | guardiao (sem nome = todos). Texturas em art_src/inimigos/ (pintadas por cima da
textura de rocha do Quaternius). Saída: actors/enemies/<nome>/<nome>.glb e art_src/inimigos/<nome>.blend.
No Blender todos olham para +Y (esquerda em -X), pés na origem. O guardião sai virado 180° (olha para +Z no Godot,
igual ao KayKit; a cena desvira); os outros saem olhando para -Z do Godot, que é a frente do jogo.
"""
import math
import random
import sys

import bmesh
import bpy
from mathutils import Euler, Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ROOT = ARGS[0] if ARGS else "C:/dev/jogo"
ONLY = ARGS[1] if len(ARGS) > 1 else ""
FPS = 30
_SEED = [0]


def _rnd(seed):
    """Sorteio repetível: a mesma peça sai igual toda vez que o script roda."""
    _SEED[0] += 1
    return random.Random(seed or _SEED[0] * 7919)

# --------------------------------------------------------------------------------------------- base


def reset() -> None:
    _SEED[0] = 0
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = FPS


def material(name, color, texture="", emission=None, strength=0.0, rough=0.9):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    if texture:
        img = nodes.new("ShaderNodeTexImage")
        img.image = bpy.data.images.load(ROOT + "/art_src/inimigos/" + texture + ".png")
        mat.node_tree.links.new(img.outputs["Color"], bsdf.inputs["Base Color"])
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
        bsdf.inputs["Emission Strength"].default_value = strength
    return mat


def _finish(o, mat, bone):
    bpy.context.view_layer.objects.active = o
    for other in bpy.context.scene.objects:
        other.select_set(other == o)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    o.data.materials.append(mat)
    group = o.vertex_groups.new(name=bone)
    group.add(list(range(len(o.data.vertices))), 1.0, "REPLACE")
    for poly in o.data.polygons:
        poly.use_smooth = False
    return o


def rock(bone, mat, size, loc, rot=(0, 0, 0), subdiv=2, jitter=0.1, seed=0):
    """Pedra facetada: icosfera torta, esticada em `size` (raios), centro em `loc`."""
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdiv, radius=1.0)
    o = bpy.context.active_object
    rnd = _rnd(seed)
    for v in o.data.vertices:
        v.co *= 1.0 + rnd.uniform(-jitter, jitter)
    o.scale = size
    o.rotation_euler = rot
    o.location = loc
    return _finish(o, mat, bone)


def box(bone, mat, size, loc, rot=(0, 0, 0), bevel=0.03, jitter=0.0, seed=0):
    """Bloco talhado: caixa com quina chanfrada e um pouco torta. `size` = medida total."""
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    o = bpy.context.active_object
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    if bevel > 0:
        mod = o.modifiers.new("Chanfro", "BEVEL")
        mod.width = bevel
        mod.segments = 1
        bpy.ops.object.modifier_apply(modifier=mod.name)
    if jitter > 0:
        rnd = _rnd(seed)
        for v in o.data.vertices:
            v.co += Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1))) * jitter
    o.rotation_euler = rot
    o.location = loc
    return _finish(o, mat, bone)


def limb(bone, mat, a, b, r1, r2, verts=6, jitter=0.0, seed=0):
    """Peça comprida de `a` até `b` (cone/prisma), raio r1 em a e r2 em b."""
    a, b = Vector(a), Vector(b)
    d = b - a
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=d.length)
    o = bpy.context.active_object
    if jitter > 0:
        rnd = _rnd(seed)
        for v in o.data.vertices:
            v.co.x *= 1.0 + rnd.uniform(-jitter, jitter)
            v.co.y *= 1.0 + rnd.uniform(-jitter, jitter)
    o.rotation_euler = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_euler()
    o.location = (a + b) / 2
    return _finish(o, mat, bone)


def block(bone, mat, a, b, w, d, bevel=0.04, jitter=0.012, seed=0):
    """Bloco de pedra ao longo do osso (de `a` até `b`), largura w (X) e profundidade d (Y)."""
    a, b = Vector(a), Vector(b)
    axis = b - a
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    o = bpy.context.active_object
    o.scale = (w, d, axis.length)
    bpy.ops.object.transform_apply(scale=True)
    mod = o.modifiers.new("Chanfro", "BEVEL")
    mod.width = bevel
    mod.segments = 1
    bpy.ops.object.modifier_apply(modifier=mod.name)
    rnd = _rnd(seed)
    for v in o.data.vertices:
        v.co += Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1))) * jitter
    o.rotation_euler = Vector((0, 0, 1)).rotation_difference(axis.normalized()).to_euler()
    o.location = (a + b) / 2
    return _finish(o, mat, bone)


def join(name):
    objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    bpy.context.view_layer.objects.active = objs[0]
    for o in bpy.context.scene.objects:
        o.select_set(o in objs)
    bpy.ops.object.join()
    mesh = bpy.context.active_object
    mesh.name = name
    mesh.data.name = name
    _box_uv(mesh, 0.9)
    return mesh


def _box_uv(mesh, size):
    """Projeção de caixa: cada face pega a textura pelo eixo para onde mais aponta."""
    bm = bmesh.new()
    bm.from_mesh(mesh.data)
    uv = bm.loops.layers.uv.new("UVMap")
    for face in bm.faces:
        n = face.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        for loop in face.loops:
            c = loop.vert.co
            if ax == 0:
                loop[uv].uv = (c.y / size, c.z / size)
            elif ax == 1:
                loop[uv].uv = (c.x / size, c.z / size)
            else:
                loop[uv].uv = (c.x / size, c.y / size)
    bm.to_mesh(mesh.data)
    bm.free()


def armature(name, bones, up=True):
    """bones: nome -> (cabeça, pai) com osso curto apontando para cima (up=True: eixos do osso = do mundo),
    ou nome -> (cabeça, ponta, pai) para o humanoide."""
    data = bpy.data.armatures.new(name)
    rig = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    for o in bpy.context.scene.objects:
        o.select_set(o == rig)
    bpy.ops.object.mode_set(mode="EDIT")
    for bone, spec in bones.items():
        eb = data.edit_bones.new(bone)
        eb.head = Vector(spec[0])
        eb.tail = Vector(spec[0]) + Vector((0, 0, 0.1)) if up else Vector(spec[1])
        eb.roll = 0.0
    for bone, spec in bones.items():
        parent = spec[-1]
        if parent:
            data.edit_bones[bone].parent = data.edit_bones[parent]
            data.edit_bones[bone].use_connect = False
    if not up:
        bpy.ops.armature.select_all(action="SELECT")
        bpy.ops.armature.calculate_roll(type="GLOBAL_NEG_Y")
    bpy.ops.object.mode_set(mode="OBJECT")
    return rig


def skin(mesh, rig):
    mesh.parent = rig
    mod = mesh.modifiers.new("Armature", "ARMATURE")
    mod.object = rig


# --------------------------------------------------------------------------------------------- animação
# Ossos "para cima" com roll 0: X do osso = X do mundo, Y do osso = cima, Z do osso = trás.
# k(...) recebe graus em eixos do mundo: pitch (em X, + levanta a frente), yaw (em Z, + gira para a esquerda),
# roll (em Y, + levanta o lado esquerdo... ou seja, -X sobe) e deslocamento (x, y=frente, z=cima).


class Anim:
    def __init__(self, rig, name, length, linear=()):
        self.rig = rig
        self.name = name
        self.length = length
        self.keys = {}  # (osso, quadro) -> dict
        self.linear = set(linear)

    def k(self, frame, bone, pitch=0.0, yaw=0.0, roll=0.0, move=(0, 0, 0), scale=1.0):
        self.keys[(bone, frame)] = (pitch, yaw, roll, move, scale)
        return self

    def build(self):
        rig = self.rig
        rig.animation_data_create()
        action = bpy.data.actions.new(self.name)
        action.use_fake_user = True
        rig.animation_data.action = action
        bones = [pb.name for pb in rig.pose.bones]
        keyed = {b for (b, _f) in self.keys}
        for pb in rig.pose.bones:
            pb.rotation_mode = "XYZ"
        for bone in bones:
            frames = sorted(f for (b, f) in self.keys if b == bone)
            if 0 not in frames:
                frames.insert(0, 0)
                self.keys[(bone, 0)] = (0, 0, 0, (0, 0, 0), 1.0)
            if self.length not in frames and bone in keyed:
                frames.append(self.length)
                self.keys[(bone, self.length)] = (0, 0, 0, (0, 0, 0), 1.0)
            elif bone not in keyed:
                frames.append(self.length)
                self.keys[(bone, self.length)] = (0, 0, 0, (0, 0, 0), 1.0)
            pb = rig.pose.bones[bone]
            for f in frames:
                pitch, yaw, roll, move, s = self.keys[(bone, f)]
                pb.rotation_euler = Euler((math.radians(pitch), math.radians(yaw), -math.radians(roll)), "XYZ")
                pb.location = Vector((move[0], move[2], -move[1]))
                pb.scale = Vector((s, s, s))
                for path in ("rotation_euler", "location", "scale"):
                    pb.keyframe_insert(path, frame=f)
        if self.linear:
            for fc in _fcurves(action):
                if any(f'"{b}"' in fc.data_path for b in self.linear):
                    for kp in fc.keyframe_points:
                        kp.interpolation = "LINEAR"
        track = rig.animation_data.nla_tracks.new()
        track.name = self.name
        track.strips.new(self.name, 0, action)
        rig.animation_data.action = None
        for pb in rig.pose.bones:
            pb.rotation_euler = Euler((0, 0, 0))
            pb.location = Vector((0, 0, 0))
            pb.scale = Vector((1, 1, 1))


def _fcurves(action):
    if hasattr(action, "fcurves") and len(action.fcurves):
        return list(action.fcurves)
    out = []
    for layer in getattr(action, "layers", []):
        for strip in layer.strips:
            for bag in strip.channelbags:
                out.extend(bag.fcurves)
    return out


def export(rig, mesh, name, animations=True):
    import os
    folder = ROOT + "/actors/enemies/" + name
    os.makedirs(folder, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=ROOT + "/art_src/inimigos/" + name + ".blend")
    for o in bpy.context.scene.objects:
        o.select_set(o in (rig, mesh))
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(
        filepath=folder + "/" + name + ".glb", export_format="GLB", use_selection=True, export_yup=True,
        export_apply=False, export_skins=True, export_def_bones=False, export_animations=animations,
        export_animation_mode="ACTIONS", export_force_sampling=True, export_image_format="AUTO",
    )
    print("exportado", name)


# --------------------------------------------------------------------------------------------- escaravelho

LEGS = [(1, 0.3, 0.16), (2, 0.02, 0.0), (3, -0.26, -0.16)]  # (n, y do quadril, abertura para frente/trás)
SIDES = [("L", -1), ("R", 1)]
TRIPOD_A = {"L1", "R2", "L3"}


def escaravelho():
    reset()
    ash = material("Cinza", (1, 1, 1), "cinza", rough=0.95)
    dark = material("CinzaEscura", (0.09, 0.075, 0.07), rough=0.9)
    ember = material("Brasa", (0.55, 0.12, 0.03), emission=(1.0, 0.38, 0.1), strength=2.2)
    eye = material("Olho", (1.0, 0.7, 0.3), emission=(1.0, 0.62, 0.25), strength=6.0)

    bones = {"Root": ((0, 0, 0), None), "Body": ((0, 0, 0.5), "Root"), "Head": ((0, 0.6, 0.5), "Body"),
             "MandL": ((-0.07, 0.8, 0.42), "Head"), "MandR": ((0.07, 0.8, 0.42), "Head"),
             "ElytraL": ((-0.05, 0.36, 0.74), "Body"), "ElytraR": ((0.05, 0.36, 0.74), "Body")}
    for n, y, spread in LEGS:
        for side, s in SIDES:
            bones[f"Leg{side}{n}a"] = ((s * 0.3, y, 0.44), "Body")
            bones[f"Leg{side}{n}b"] = ((s * 0.5, y + spread * 0.6, 0.55), f"Leg{side}{n}a")

    # corpo de brasa por baixo da carapaça (aparece nas frestas)
    rock("Body", ember, (0.32, 0.55, 0.2), (0, -0.05, 0.47), jitter=0.06)
    rock("Body", ash, (0.34, 0.25, 0.22), (0, 0.4, 0.6), rot=(0.25, 0, 0), jitter=0.12)
    rock("Body", dark, (0.3, 0.5, 0.14), (0, -0.05, 0.36), jitter=0.08)
    # carapaça em duas metades (élitros), com brasas cravadas
    for side, s in SIDES:
        bone = "Elytra" + side
        rock(bone, ash, (0.21, 0.68, 0.27), (s * 0.15, -0.14, 0.63), rot=(0.06, -s * 0.05, 0), jitter=0.08)
        for p, r in [((0.2, 0.12, 0.84), 0.045), ((0.27, -0.22, 0.78), 0.055), ((0.14, -0.5, 0.74), 0.045),
                     ((0.09, -0.08, 0.89), 0.035)]:
            rock(bone, ember, (r, r * 1.3, r * 0.7), (s * p[0], p[1], p[2]), subdiv=1, jitter=0.2)
    # cabeça, chifre, olhos e mandíbulas
    rock("Head", ash, (0.2, 0.18, 0.15), (0, 0.68, 0.5), jitter=0.12)
    limb("Head", dark, (0, 0.74, 0.6), (0, 0.9, 0.84), 0.065, 0.0, verts=5)
    for side, s in SIDES:
        rock("Head", eye, (0.045, 0.045, 0.045), (s * 0.13, 0.79, 0.55), subdiv=1, jitter=0.0)
        limb("Mand" + side, dark, (s * 0.08, 0.8, 0.42), (s * 0.13, 0.94, 0.41), 0.05, 0.035, verts=5)
        limb("Mand" + side, dark, (s * 0.13, 0.94, 0.41), (s * 0.03, 1.08, 0.4), 0.035, 0.008, verts=5)
    # pernas: coxa e canela, joelho em brasa
    for n, y, spread in LEGS:
        for side, s in SIDES:
            hip = Vector((s * 0.3, y, 0.44))
            knee = Vector((s * 0.5, y + spread * 0.6, 0.55))
            foot = Vector((s * 0.66, y + spread * 1.5, 0.0))
            limb(f"Leg{side}{n}a", dark, hip, knee, 0.075, 0.065, verts=6)
            limb(f"Leg{side}{n}b", dark, knee, foot, 0.06, 0.02, verts=6)
            rock(f"Leg{side}{n}b", ember, (0.045, 0.045, 0.045), knee, subdiv=1, jitter=0.0)
            limb(f"Leg{side}{n}b", ash, knee + (foot - knee) * 0.15, knee + (foot - knee) * 0.55, 0.085, 0.05,
                 verts=5)

    mesh = join("Escaravelho")
    rig = armature("EscaravelhoRig", bones)
    skin(mesh, rig)

    leg_names = [(f"{side}{n}", s) for n, _y, _sp in LEGS for side, s in SIDES]

    def leg(a, f, name, s, swing=0.0, lift=0.0, fold=0.0):
        # swing + = pé para a frente; lift + = coxa sobe; fold + = canela dobra para dentro
        a.k(f, f"Leg{name}a", yaw=s * swing, roll=-s * lift)
        a.k(f, f"Leg{name}b", roll=s * fold)

    # Idle: respira, mexe as mandíbulas e a cabeça
    a = Anim(rig, "Idle", 60)
    a.k(30, "Body", move=(0, 0, 0.014))
    a.k(20, "Head", yaw=7).k(45, "Head", yaw=-5, pitch=-3)
    for side, s in SIDES:
        for f, ang in [(10, 9), (16, 0), (24, 9), (30, 0)]:
            a.k(f, "Mand" + side, yaw=-s * ang)
        a.k(30, "Elytra" + side, roll=-s * 3)
    a.build()

    # Walk: trípode (3 pernas no chão, 3 no ar)
    a = Anim(rig, "Walk", 24)
    for name, s in leg_names:
        if name in TRIPOD_A:
            leg(a, 0, name, s, swing=18)
            leg(a, 12, name, s, swing=-18)
            leg(a, 18, name, s, swing=0, lift=26, fold=12)
            leg(a, 24, name, s, swing=18)
        else:
            leg(a, 0, name, s, swing=-18)
            leg(a, 6, name, s, swing=0, lift=26, fold=12)
            leg(a, 12, name, s, swing=18)
            leg(a, 24, name, s, swing=-18)
    for f, r in [(0, 2), (6, 0), (12, -2), (18, 0), (24, 2)]:
        a.k(f, "Body", roll=r, move=(0, 0, 0.012 if f in (6, 18) else 0))
    a.k(6, "Head", yaw=4).k(18, "Head", yaw=-4)
    a.build()

    # Attack (mordida): empina, abre a carapaça e as mandíbulas, dá o bote e fecha
    a = Anim(rig, "Attack", 28)
    a.k(8, "Body", pitch=13, move=(0, -0.12, 0.04))
    a.k(12, "Body", pitch=-10, move=(0, 0.38, -0.03))
    a.k(19, "Body", pitch=-5, move=(0, 0.25, 0))
    a.k(8, "Head", pitch=16).k(12, "Head", pitch=-14).k(19, "Head", pitch=-4)
    for side, s in SIDES:
        a.k(8, "Mand" + side, yaw=-s * 38).k(12, "Mand" + side, yaw=-s * 36).k(14, "Mand" + side, yaw=s * 10)
        a.k(19, "Mand" + side, yaw=s * 4)
        a.k(8, "Elytra" + side, roll=-s * 24, pitch=-14).k(14, "Elytra" + side, roll=-s * 12, pitch=-6)
        leg(a, 8, f"{side}1", s, swing=20, lift=28, fold=10)
        leg(a, 12, f"{side}1", s, swing=24)
        leg(a, 8, f"{side}3", s, swing=-10)
    a.build()

    # Hit: leva o golpe e recua
    a = Anim(rig, "Hit", 16)
    a.k(3, "Body", pitch=11, roll=5, move=(0, -0.13, 0.03)).k(9, "Body", pitch=-2, move=(0, -0.05, 0))
    a.k(3, "Head", pitch=12)
    for side, s in SIDES:
        a.k(3, "Elytra" + side, roll=-s * 14).k(3, "Mand" + side, yaw=-s * 20)
        leg(a, 3, f"{side}1", s, lift=18)
    a.build()

    # Dodge: agacha e salta de lado
    a = Anim(rig, "Dodge", 14)
    a.k(4, "Body", move=(0, 0, -0.07)).k(8, "Body", roll=-12, move=(0, 0, 0.14))
    for name, s in leg_names:
        leg(a, 8, name, s, lift=14, fold=10)
    a.build()

    # Death: pula, vira de costas e encolhe as pernas
    a = Anim(rig, "Death", 40)
    a.k(6, "Body", roll=35, move=(0, 0, 0.18)).k(14, "Body", roll=180, move=(0, 0, 0.06))
    a.k(40, "Body", roll=180, move=(0, 0, 0.02))
    for side, s in SIDES:
        a.k(6, "Elytra" + side, roll=-s * 20).k(14, "Elytra" + side, roll=-s * 8).k(40, "Elytra" + side, roll=-s * 8)
        a.k(14, "Mand" + side, yaw=-s * 25).k(40, "Mand" + side, yaw=-s * 25)
    a.k(14, "Head", pitch=-15).k(40, "Head", pitch=-22)
    for name, s in leg_names:
        leg(a, 6, name, s, lift=20, fold=10)
        leg(a, 16, name, s, lift=-10, fold=35)
        leg(a, 21, name, s, lift=-20, fold=60)
        leg(a, 26, name, s, lift=-12, fold=40)
        leg(a, 32, name, s, lift=-22, fold=62)
        leg(a, 40, name, s, lift=-22, fold=62)
    a.build()

    export(rig, mesh, "escaravelho")


# --------------------------------------------------------------------------------------------- sentinela

STARS = [(0, 0.55, 0.05), (70, 0.62, -0.09), (150, 0.52, 0.12), (215, 0.6, -0.05), (290, 0.56, 0.03)]


def sentinela():
    reset()
    stone = material("Pedra", (1, 1, 1), "pedra_deserto", rough=0.95)
    star = material("Estrela", (1.0, 0.92, 0.7), emission=(1.0, 0.86, 0.55), strength=7.0)
    line = material("Linha", (0.9, 0.75, 0.5), emission=(1.0, 0.8, 0.5), strength=2.5)
    core = material("Nucleo", (1.0, 0.85, 0.6), emission=(1.0, 0.78, 0.45), strength=3.5)

    bones = {"Root": ((0, 0, 0), None), "Body": ((0, 0, 1.0), "Root"), "Core": ((0, 0.22, 1.08), "Body"),
             "Tail": ((0, 0, 0.55), "Body"), "Tail2": ((0, 0, 0.38), "Tail"),
             "Head": ((0, 0, 1.45), "Root"), "Ring": ((0, 0, 1.1), "Root"),
             "HandL": ((-0.62, 0.05, 0.98), "Root"), "HandR": ((0.62, 0.05, 0.98), "Root")}

    # tronco: prisma de seis lados afinando para baixo, laje nos ombros, moldura do núcleo
    limb("Body", stone, (0, 0, 0.58), (0, 0, 1.3), 0.13, 0.36, verts=6, jitter=0.08)
    rock("Body", stone, (0.42, 0.33, 0.12), (0, 0, 1.33), jitter=0.12)
    for side, s in SIDES:
        rock("Body", stone, (0.21, 0.19, 0.15), (s * 0.45, 0, 1.33), rot=(0, s * 0.35, 0), jitter=0.14)
    for p in [(-0.15, 0.21, 1.07), (0.15, 0.21, 1.07), (0, 0.23, 1.23), (0, 0.2, 0.9)]:
        rock("Body", stone, (0.075, 0.07, 0.075), p, jitter=0.15)
    rock("Core", core, (0.12, 0.1, 0.12), (0, 0.24, 1.07), subdiv=2, jitter=0.0)
    # rabo de pedras soltas
    rock("Tail", stone, (0.12, 0.12, 0.1), (0, 0, 0.47), jitter=0.15)
    rock("Tail2", stone, (0.07, 0.07, 0.07), (0, 0, 0.32), jitter=0.15)
    # cabeça: bloco com olho em fenda e três pontas
    box("Head", stone, (0.3, 0.28, 0.3), (0, 0, 1.6), bevel=0.04, jitter=0.012)
    box("Head", star, (0.18, 0.03, 0.04), (0, 0.145, 1.61), bevel=0.0)
    for x, h in [(-0.1, 0.12), (0, 0.18), (0.1, 0.12)]:
        limb("Head", stone, (x, 0, 1.73), (x * 1.3, 0, 1.73 + h), 0.06, 0.0, verts=4)
    # mãos soltas no ar: punho, lasca do antebraço, brilho nos nós dos dedos
    for side, s in SIDES:
        bone = "Hand" + side
        rock(bone, stone, (0.15, 0.17, 0.19), (s * 0.62, 0.05, 0.98), jitter=0.14)
        rock(bone, stone, (0.08, 0.08, 0.14), (s * 0.6, 0.02, 1.22), jitter=0.15)
        rock(bone, star, (0.035, 0.035, 0.035), (s * 0.62, 0.21, 0.99), subdiv=1, jitter=0.0)
    # constelação girando em volta do peito: estrelas ligadas por linhas
    pts = []
    for ang, r, dz in STARS:
        p = Vector((math.sin(math.radians(ang)) * r, math.cos(math.radians(ang)) * r, 1.1 + dz))
        pts.append(p)
        rock("Ring", star, (0.05, 0.05, 0.05), p, subdiv=1, jitter=0.0)
    for p, q in zip(pts, pts[1:]):
        limb("Ring", line, p, q, 0.009, 0.009, verts=4)

    mesh = join("Sentinela")
    rig = armature("SentinelaRig", bones)
    skin(mesh, rig)

    # Idle (4 s): flutua, a constelação dá uma volta, o núcleo pulsa
    a = Anim(rig, "Idle", 120, linear={"Ring"})
    a.k(30, "Body", move=(0, 0, 0.05)).k(60, "Body").k(90, "Body", move=(0, 0, 0.05))
    a.k(34, "Head", yaw=10, move=(0, 0, 0.05)).k(64, "Head").k(94, "Head", yaw=-8, move=(0, 0, 0.05))
    for side, s in SIDES:
        off = 8 if side == "L" else 16
        a.k(30 + off, "Hand" + side, move=(0, 0, 0.06)).k(60 + off, "Hand" + side, move=(0, 0, -0.02))
        a.k(90 + off, "Hand" + side, move=(0, 0, 0.05))
    for i, f in enumerate([0, 30, 60, 90, 120]):
        a.k(f, "Ring", yaw=-90 * i)
    a.k(60, "Core", scale=1.14)
    a.k(30, "Tail", pitch=6).k(90, "Tail", pitch=-6)
    a.build()

    # Walk: desliza inclinado para frente, mãos ficam para trás, constelação gira rápido
    a = Anim(rig, "Walk", 40, linear={"Ring"})
    for f in [0, 10, 20, 30, 40]:
        bob = 0.03 if f in (10, 30) else 0.0
        a.k(f, "Body", pitch=-12, move=(0, 0, bob))
        a.k(f, "Head", pitch=-6, move=(0, 0.08, bob - 0.02))
        a.k(f, "Tail", pitch=-16)
        for side, s in SIDES:
            a.k(f, "Hand" + side, pitch=10, move=(0, -0.14, 0.05 + (bob if side == "L" else 0.03 - bob)))
    for i, f in enumerate([0, 10, 20, 30, 40]):
        a.k(f, "Ring", yaw=-90 * i)
    a.build()

    # Attack (raio): recua juntando luz no núcleo e empurra as mãos para frente
    a = Anim(rig, "Attack", 36)
    a.k(12, "Body", pitch=9, move=(0, -0.08, 0.03)).k(18, "Body", pitch=-15, move=(0, 0.15, 0))
    a.k(26, "Body", pitch=-8, move=(0, 0.08, 0))
    a.k(12, "Head", pitch=10, move=(0, -0.06, 0.03)).k(18, "Head", pitch=-12, move=(0, 0.18, -0.03))
    a.k(12, "Core", scale=1.6).k(18, "Core", scale=1.9).k(26, "Core", scale=1.3)
    a.k(12, "Ring", yaw=-120).k(18, "Ring", yaw=-200).k(36, "Ring", yaw=-360)
    for side, s in SIDES:
        a.k(12, "Hand" + side, move=(s * 0.1, -0.15, 0.26))
        a.k(18, "Hand" + side, pitch=-20, move=(-s * 0.3, 0.45, 0.12))
        a.k(26, "Hand" + side, pitch=-10, move=(-s * 0.22, 0.32, 0.08))
    a.build()

    # Hit: tranco para trás, núcleo pisca
    a = Anim(rig, "Hit", 16)
    a.k(3, "Body", pitch=18, move=(0, -0.12, 0)).k(3, "Head", pitch=15, move=(0, -0.16, 0.02))
    a.k(3, "Core", scale=0.6).k(6, "Core", scale=1.2)
    for side, s in SIDES:
        a.k(3, "Hand" + side, move=(s * 0.12, -0.1, 0.08))
    a.k(4, "Ring", roll=15)
    a.build()

    # Dodge: inclina e sobe de lado
    a = Anim(rig, "Dodge", 14)
    for bone in ["Body", "Head", "HandL", "HandR", "Ring"]:
        a.k(6, bone, roll=-18 if bone == "Body" else 0, move=(0, 0, 0.12))
    a.build()

    # Death: o núcleo brilha e apaga, e as pedras caem soltas no chão
    a = Anim(rig, "Death", 44)
    a.k(8, "Core", scale=1.7).k(14, "Core", scale=0.05).k(44, "Core", scale=0.05)
    a.k(8, "Body", pitch=8, move=(0, 0, 0.08)).k(20, "Body", pitch=10, move=(0, 0, -0.2))
    a.k(34, "Body", roll=78, move=(0, 0, -0.62)).k(44, "Body", roll=76, move=(0, 0, -0.62))
    a.k(14, "Head", move=(0, 0, 0.06)).k(28, "Head", pitch=-55, move=(0.1, 0.38, -1.34))
    a.k(44, "Head", pitch=-58, move=(0.1, 0.4, -1.36))
    a.k(14, "Ring", pitch=20, move=(0, 0, -0.15)).k(30, "Ring", pitch=6, move=(0, 0, -1.02))
    a.k(44, "Ring", pitch=6, move=(0, 0, -1.02))
    for side, s in SIDES:
        a.k(10, "Hand" + side, move=(s * 0.06, 0, 0.05)).k(22, "Hand" + side, roll=s * 30, move=(s * 0.14, 0, -0.84))
        a.k(44, "Hand" + side, roll=s * 30, move=(s * 0.14, 0, -0.84))
    a.build()

    export(rig, mesh, "sentinela")


# --------------------------------------------------------------------------------------------- guardião

GUARD_BONES = {
    "Root": ((0, 0, 0), (0, 0.3, 0), None),
    "Hips": ((0, 0, 1.3), (0, 0, 1.55), "Root"),
    "Spine": ((0, 0, 1.55), (0, 0, 1.8), "Hips"),
    "Chest": ((0, 0, 1.8), (0, 0, 2.3), "Spine"),
    "Neck": ((0, 0.02, 2.3), (0, 0.04, 2.42), "Chest"),
    "Head": ((0, 0.04, 2.42), (0, 0.06, 2.8), "Neck"),
    "LeftUpperArm": ((-0.72, 0, 2.18), (-0.95, 0.0, 1.62), "Chest"),
    "LeftLowerArm": ((-0.95, 0, 1.62), (-1.08, 0.12, 1.1), "LeftUpperArm"),
    "LeftHand": ((-1.08, 0.12, 1.1), (-1.12, 0.16, 0.85), "LeftLowerArm"),
    "RightUpperArm": ((0.72, 0, 2.18), (0.95, 0.0, 1.62), "Chest"),
    "RightLowerArm": ((0.95, 0, 1.62), (1.08, 0.12, 1.1), "RightUpperArm"),
    "RightHand": ((1.08, 0.12, 1.1), (1.12, 0.16, 0.85), "RightLowerArm"),
    "LeftUpperLeg": ((-0.34, 0, 1.28), (-0.38, 0.02, 0.72), "Hips"),
    "LeftLowerLeg": ((-0.38, 0.02, 0.72), (-0.4, -0.02, 0.14), "LeftUpperLeg"),
    "LeftFoot": ((-0.4, -0.02, 0.14), (-0.4, 0.4, 0.05), "LeftLowerLeg"),
    "RightUpperLeg": ((0.34, 0, 1.28), (0.38, 0.02, 0.72), "Hips"),
    "RightLowerLeg": ((0.38, 0.02, 0.72), (0.4, -0.02, 0.14), "RightUpperLeg"),
    "RightFoot": ((0.4, -0.02, 0.14), (0.4, 0.4, 0.05), "RightLowerLeg"),
}


def guardiao():
    reset()
    stone = material("Pedra", (1, 1, 1), "pedra_guardiao", rough=0.95)
    ember = material("Brasa", (0.6, 0.15, 0.04), emission=(1.0, 0.42, 0.12), strength=3.5)
    star = material("Estrela", (1.0, 0.92, 0.7), emission=(1.0, 0.86, 0.55), strength=7.0)
    line = material("Linha", (0.9, 0.75, 0.5), emission=(1.0, 0.8, 0.5), strength=2.5)
    b = {k: (Vector(v[0]), Vector(v[1])) for k, v in GUARD_BONES.items()}

    # quadril, cinta de brasa, cintura
    box("Hips", stone, (0.8, 0.52, 0.36), (0, 0, 1.32), bevel=0.05, jitter=0.015)
    box("Spine", ember, (0.6, 0.4, 0.07), (0, 0, 1.53), bevel=0.0)
    box("Spine", stone, (0.68, 0.46, 0.26), (0, 0, 1.68), bevel=0.05, jitter=0.015)
    # peito grande com núcleo de brasa e rachaduras saindo dele
    box("Chest", stone, (1.22, 0.7, 0.64), (0, 0, 2.03), bevel=0.07, jitter=0.025)
    rock("Chest", stone, (0.46, 0.26, 0.34), (0, -0.36, 2.12), jitter=0.12)
    rock("Chest", stone, (0.3, 0.2, 0.18), (-0.25, -0.33, 1.86), jitter=0.12)
    rock("Chest", ember, (0.16, 0.08, 0.16), (0, 0.34, 2.0), subdiv=2, jitter=0.05)
    for p in [(-0.2, 0.36, 2.0), (0.2, 0.36, 2.0), (0, 0.37, 2.2), (0, 0.36, 1.8)]:
        rock("Chest", stone, (0.09, 0.07, 0.09), p, jitter=0.15)
    for q in [(-0.46, 2.22), (0.44, 2.24), (-0.34, 1.8), (0.36, 1.82), (0.06, 2.32)]:
        limb("Chest", ember, (0, 0.352, 2.0), (q[0], 0.352, q[1]), 0.016, 0.006, verts=4)
    # cabeça afundada nos ombros: bloco com testa, olho em fenda e coroa de estrelas
    box("Head", stone, (0.44, 0.44, 0.38), (0, 0.06, 2.56), bevel=0.05, jitter=0.012)
    box("Head", stone, (0.5, 0.14, 0.11), (0, 0.22, 2.67), bevel=0.03, jitter=0.01)
    box("Head", star, (0.28, 0.03, 0.05), (0, 0.285, 2.56), bevel=0.0)
    crown = []
    for ang in (-64, -32, 0, 32, 64):
        p = Vector((math.sin(math.radians(ang)) * 0.4, 0.02, 2.64 + math.cos(math.radians(ang)) * 0.4))
        crown.append(p)
        rock("Head", star, (0.05, 0.05, 0.05), p, subdiv=1, jitter=0.0)
    for p, q in zip(crown, crown[1:]):
        limb("Head", line, p, q, 0.008, 0.008, verts=4)
    # braços: ombreira, braço, antebraço grosso, punho; cotovelo em brasa
    for side, s in [("Left", -1), ("Right", 1)]:
        up, low, hand = b[side + "UpperArm"], b[side + "LowerArm"], b[side + "Hand"]
        rock(side + "UpperArm", stone, (0.37, 0.35, 0.3), (s * 0.8, 0, 2.3), jitter=0.12)
        block(side + "UpperArm", stone, up[0] + (up[1] - up[0]) * 0.15, up[1], 0.34, 0.34)
        rock(side + "LowerArm", ember, (0.11, 0.11, 0.11), low[0], subdiv=1, jitter=0.0)
        block(side + "LowerArm", stone, low[0] + (low[1] - low[0]) * 0.12, low[1], 0.42, 0.42, bevel=0.05)
        rock(side + "Hand", stone, (0.27, 0.27, 0.29), hand[0] + (hand[1] - hand[0]) * 0.55, jitter=0.12)
        # pernas: coxa, canela, joelho em brasa, pé
        th, sh = b[side + "UpperLeg"], b[side + "LowerLeg"]
        block(side + "UpperLeg", stone, th[0] - Vector((0, 0, 0.02)), th[1] + Vector((0, 0, 0.04)), 0.42, 0.42)
        rock(side + "LowerLeg", ember, (0.11, 0.11, 0.11), sh[0], subdiv=1, jitter=0.0)
        block(side + "LowerLeg", stone, sh[0] - Vector((0, 0, 0.06)), sh[1], 0.44, 0.44, bevel=0.05)
        box(side + "Foot", stone, (0.48, 0.68, 0.2), (s * 0.4, 0.13, 0.1), bevel=0.05, jitter=0.015)

    mesh = join("Guardiao")
    rig = armature("GuardiaoRig", GUARD_BONES, up=False)
    for bone in rig.data.bones:
        bone.use_deform = bone.name != "Root"
    skin(mesh, rig)
    # vira 180°: no Godot o modelo olha para +Z, como os personagens do KayKit (a cena do inimigo desvira)
    rig.rotation_euler = (0, 0, math.pi)
    for o in bpy.context.scene.objects:
        o.select_set(o in (rig, mesh))
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    export(rig, mesh, "guardiao", animations=False)


if __name__ == "__main__":
    for name, fn in [("escaravelho", escaravelho), ("sentinela", sentinela), ("guardiao", guardiao)]:
        if ONLY in ("", name):
            fn()
