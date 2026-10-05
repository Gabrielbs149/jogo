"""Monta os kobolds (Tico-Lirou e Tika Muro) no Blender a partir de formas simples e exporta .glb para o Godot.

Uso (sem abrir o Blender):
    blender --background --factory-startup --python tools/blender/kobolds.py -- <raiz_do_repo> [pasta_de_previews]

Gera actors/<nome>/<nome>.glb (+ .blend para editar à mão) e, se pedir, renders de frente, 3/4 e costas.
Convenção: pés na origem, personagem olhando para +Y no Blender (vira -Z no Godot, a frente da engine).
Referência visual: a ilustração dos dois kobolds que o Gabriel mandou (Tico à direita, Tika à esquerda).
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ROOT = ARGS[0] if ARGS else os.getcwd()
PREVIEW_DIR = ARGS[1] if len(ARGS) > 1 else ""

# ---------------------------------------------------------------- utilidades

_materials = {}


def material(name, color, roughness=0.75, emission=0.0):
    key = (name, color, emission)
    if key in _materials:
        return _materials[key]
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    if bpy.app.version < (5, 0, 0):
        mat.use_nodes = True  # no Blender 5 todo material já usa nós
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    if emission > 0.0:
        bsdf.inputs["Emission Color"].default_value = (*color, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission
    _materials[key] = mat
    return mat


def finish(obj, mat, parent, smooth=True, subsurf=0):
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    if smooth:
        for poly in obj.data.polygons:
            poly.use_smooth = True
    if subsurf:
        mod = obj.modifiers.new("Suave", "SUBSURF")
        mod.levels = subsurf
        mod.render_levels = subsurf
    obj.parent = parent
    return obj


def apply_transform(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)


def ellipsoid(name, center, radii, mat, parent, segments=24, rings=14):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=1.0, location=center, segments=segments, ring_count=rings)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = radii
    apply_transform(obj)
    return finish(obj, mat, parent)


def limb(name, p0, p1, radius, mat, parent, cap=True):
    """Cilindro entre dois pontos, com esferas nas pontas (braço, perna, chifre reto)."""
    p0, p1 = Vector(p0), Vector(p1)
    direction = p1 - p0
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=radius, depth=direction.length, location=(p0 + p1) / 2)
    obj = bpy.context.active_object
    obj.name = name
    obj.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    apply_transform(obj)
    finish(obj, mat, parent)
    if cap:
        for i, p in enumerate((p0, p1)):
            ellipsoid(f"{name}_ponta{i}", p, (radius, radius, radius), mat, parent, 12, 8)
    return obj


def cone(name, base, tip, radius, mat, parent, flatten=1.0):
    base, tip = Vector(base), Vector(tip)
    direction = tip - base
    bpy.ops.mesh.primitive_cone_add(vertices=14, radius1=radius, radius2=0.0, depth=direction.length, location=(base + tip) / 2)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = (flatten, 1.0, 1.0)
    obj.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    apply_transform(obj)
    return finish(obj, mat, parent)


def torus(name, center, major, minor, mat, parent, scale=(1, 1, 1), rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, location=center, rotation=rotation,
                                     major_segments=32, minor_segments=10)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    apply_transform(obj)
    return finish(obj, mat, parent)


def box(name, center, size, mat, parent, bevel=0.02, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=center, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    apply_transform(obj)
    finish(obj, mat, parent, smooth=False)
    if bevel > 0:
        mod = obj.modifiers.new("Chanfro", "BEVEL")
        mod.width = bevel
        mod.segments = 3
        for poly in obj.data.polygons:
            poly.use_smooth = True
    return obj


def shell(name, center, radii, mat, parent, cut_front=0.3, thickness=0.015, cut_below=None):
    """Esfera oca aberta na frente (capuz). cut_front: corta faces viradas para +Y acima disso."""
    obj = ellipsoid(name, center, radii, mat, parent, 32, 18)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    remove = []
    for f in bm.faces:
        n = f.normal
        # coordenadas da malha são locais (em volta do centro); cut_below é altura do mundo
        world_z = obj.location.z + f.calc_center_median().z
        if n.y > cut_front or (cut_below is not None and world_z < cut_below):
            remove.append(f)
    bmesh.ops.delete(bm, geom=remove, context="FACES")
    bm.to_mesh(obj.data)
    bm.free()
    mod = obj.modifiers.new("Espessura", "SOLIDIFY")
    mod.thickness = thickness
    mod.offset = -1
    return obj


def open_tube(name, z_bottom, z_top, r_bottom, r_top, mat, parent, open_front=0.45, y_offset=0.0):
    """Manto: tubo cônico aberto na frente (open_front = quanto da frente fica aberto; 0 = fechado)."""
    height = z_top - z_bottom
    bpy.ops.mesh.primitive_cone_add(vertices=32, radius1=r_bottom, radius2=r_top, depth=height,
                                    location=(0, y_offset, z_bottom + height / 2), end_fill_type="NOTHING")
    obj = bpy.context.active_object
    obj.name = name
    if open_front > 0:
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        remove = [f for f in bm.faces if f.normal.y > 1.0 - open_front]
        bmesh.ops.delete(bm, geom=remove, context="FACES")
        bm.to_mesh(obj.data)
        bm.free()
    finish(obj, mat, parent)
    mod = obj.modifiers.new("Espessura", "SOLIDIFY")
    mod.thickness = 0.014
    mod.offset = 1
    return obj


def dot(name, center, radii, direction, size, mat, parent):
    """Pinta uma pinta achatada na superfície de um elipsoide, na direção dada."""
    d = Vector(direction).normalized()
    point = Vector(center) + Vector((d.x * radii[0], d.y * radii[1], d.z * radii[2]))
    normal = Vector((d.x / radii[0], d.y / radii[1], d.z / radii[2])).normalized()
    bpy.ops.mesh.primitive_uv_sphere_add(radius=1.0, location=point + normal * 0.002, segments=12, ring_count=6)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = (size, size, size * 0.25)
    obj.rotation_euler = normal.to_track_quat("Z", "Y").to_euler()
    apply_transform(obj)
    return finish(obj, mat, parent)


def tail(name, points, mat, parent):
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = 1.0
    curve.bevel_resolution = 6
    curve.use_fill_caps = True
    spline = curve.splines.new("NURBS")
    spline.points.add(len(points) - 1)
    for i, (x, y, z, r) in enumerate(points):
        spline.points[i].co = (x, y, z, 1.0)
        spline.points[i].radius = r
    spline.use_endpoint_u = True
    spline.order_u = 4
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.convert(target="MESH")
    obj = bpy.context.active_object
    return finish(obj, mat, parent)


# ---------------------------------------------------------------- o kobold

def build_kobold(cfg):
    root = bpy.data.objects.new(cfg["name"], None)
    bpy.context.collection.objects.link(root)

    skin = material("Pele", (0.33, 0.62, 0.2))
    spots = material("Pintas", (0.55, 0.8, 0.32))
    belly = material("Barriga", (0.95, 0.72, 0.5))
    claw = material("Garra", (0.08, 0.07, 0.07), 0.4)
    horn = material("Chifre", (0.93, 0.84, 0.62), 0.5)
    crest = material("Crista", (0.9, 0.62, 0.74))
    cloth = material(f"Manto_{cfg['name']}", cfg["cloth"], 0.9)
    hood = material(f"Capuz_{cfg['name']}", cfg["hood"], 0.9)
    scarf = material(f"Cachecol_{cfg['name']}", cfg["scarf"], 0.9)
    sash = material("Faixa", (0.6, 0.52, 0.42), 0.95)
    wrap = material("Perneira", (0.42, 0.3, 0.2), 0.95)
    strap = material("Correia", (0.18, 0.15, 0.17), 0.9)
    leather = material("Couro", (0.42, 0.26, 0.15), 0.8)
    bedroll = material("Saco de dormir", (0.22, 0.24, 0.28), 0.95)
    white = material("Olho", (0.97, 0.97, 0.95), 0.3)
    iris = material(f"Iris_{cfg['name']}", cfg["eye"], 0.3, emission=0.6)
    pupil = material("Pupila", (0.02, 0.02, 0.03), 0.2)
    tooth = material("Dente", (0.98, 0.97, 0.92), 0.4)
    shroom = material(f"Cogumelo_{cfg['name']}", cfg["mushroom"], 0.6)
    shroom_spot = material("Cogumelo pinta", (0.2, 0.55, 0.55), 0.6)
    bulb = material("Bulbo", (0.55, 0.3, 0.85), 0.4, emission=0.4)

    # Pés e pernas (perneiras de pano)
    for side in (-1, 1):
        x = 0.11 * side
        ellipsoid(f"Pe_{side}", (x, 0.04, 0.045), (0.075, 0.11, 0.045), skin, root)
        for t in (-1, 0, 1):
            cone(f"Garra_pe_{side}_{t}", (x + 0.035 * t, 0.13, 0.03), (x + 0.045 * t, 0.17, 0.012), 0.012, claw, root)
        limb(f"Perna_{side}", (x, 0.0, 0.07), (x, 0.0, 0.32), 0.058, skin, root)
        bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.078, depth=0.15, location=(x, 0.0, 0.16))
        legwrap = bpy.context.active_object
        legwrap.name = f"Perneira_{side}"
        finish(legwrap, wrap, root)
        torus(f"Perneira_faixa_{side}", (x, 0.0, 0.13), 0.078, 0.012, strap, root)
        torus(f"Perneira_borda_{side}", (x, 0.0, 0.235), 0.082, 0.016, wrap, root)

    # Corpo, barriga e pintas
    body_c, body_r = (0.0, 0.0, 0.46), (0.2, 0.17, 0.25)
    ellipsoid("Corpo", body_c, body_r, skin, root)
    ellipsoid("Barriga", (0.0, 0.07, 0.42), (0.15, 0.12, 0.19), belly, root)

    # Rabo (sai de trás, curva para o lado)
    tail("Rabo", [(0, -0.12, 0.33, 0.1), (0.0, -0.3, 0.22, 0.085), (0.08, -0.48, 0.13, 0.065),
                  (0.25, -0.6, 0.08, 0.045), (0.45, -0.62, 0.07, 0.025), (0.58, -0.56, 0.08, 0.008)], skin, root)
    for i, (x, y, z) in enumerate(((0.02, -0.3, 0.3), (0.09, -0.47, 0.19), (0.27, -0.6, 0.12), (0.43, -0.62, 0.095))):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=1.0, location=(x, y, z), segments=10, ring_count=5)
        sp = bpy.context.active_object
        sp.name = f"Pinta_rabo_{i}"
        sp.scale = (0.03, 0.03, 0.008)
        apply_transform(sp)
        finish(sp, spots, root)

    # Manto (Tico: aberto na frente; Tika: vestido fechado e mais comprido)
    open_tube("Manto", cfg["robe_bottom"], 0.66, 0.27, 0.17, cloth, root, open_front=cfg["robe_open"], y_offset=-0.01)
    torus("Faixa_cintura", (0, 0.0, 0.43), 0.19, 0.03, sash, root, scale=(1.05, 0.95, 1))
    torus("Cinto", (0, 0.0, 0.4), 0.2, 0.012, strap, root, scale=(1.05, 0.95, 1))
    for side in (-1, 1):
        x = 0.2 * side
        limb(f"Manga_{side}", (x * 0.95, 0.0, 0.62), (x * 1.35, 0.03, 0.5), 0.075, cloth, root, cap=False)
        limb(f"Braco_{side}", (x * 1.2, 0.02, 0.56), (x * 1.45, 0.07, 0.37), 0.048, skin, root)
        ellipsoid(f"Mao_{side}", (x * 1.48, 0.09, 0.34), (0.05, 0.055, 0.045), skin, root)
        for t in (-1, 0, 1):
            cone(f"Garra_mao_{side}_{t}", (x * 1.48 + 0.02 * t, 0.12, 0.31), (x * 1.5 + 0.025 * t, 0.14, 0.27), 0.01, claw, root)
        dot(f"Pinta_braco_{side}", (x * 1.33, 0.045, 0.46), (0.048, 0.048, 0.1), (side, 0.4, 0.2), 0.022, spots, root)

    # Cachecol
    torus("Cachecol", (0, 0.0, 0.67), 0.13, 0.05, scarf, root, scale=(1.0, 0.95, 0.8))
    box("Cachecol_ponta", (0.07, 0.11, 0.56), (0.07, 0.025, 0.16), scarf, root, bevel=0.01, rotation=(0.15, 0, -0.2))

    # Cabeça
    head_c, head_r = (0.0, 0.03, 0.87), (0.2, 0.2, 0.18)
    ellipsoid("Cabeca", head_c, head_r, skin, root)
    snout_c, snout_r = (0.0, 0.22, 0.83), (0.135, 0.16, 0.085)
    ellipsoid("Focinho", snout_c, snout_r, skin, root)
    ellipsoid("Mandibula", (0.0, 0.2, 0.765), (0.115, 0.135, 0.05), belly, root)
    for i, x in enumerate((-0.07, -0.025, 0.025, 0.07)):
        cone(f"Dente_{i}", (x, 0.335 - abs(x) * 0.6, 0.79), (x, 0.34 - abs(x) * 0.6, 0.765), 0.011, tooth, root)
    for side in (-1, 1):
        ellipsoid(f"Narina_{side}", (0.035 * side, 0.37, 0.86), (0.012, 0.01, 0.008), claw, root)
    for i, d in enumerate(((0.3, 0.6, 0.7), (-0.4, 0.5, 0.75), (0.7, 0.2, 0.6), (-0.75, 0.1, 0.55), (0.1, -0.3, 0.9), (0.5, -0.5, 0.5), (-0.5, -0.4, 0.6))):
        dot(f"Pinta_cabeca_{i}", head_c, head_r, d, 0.024, spots, root)
    for i, d in enumerate(((0.5, 0.6, 0.6), (-0.4, 0.7, 0.55), (0.1, 0.85, 0.5))):
        dot(f"Pinta_focinho_{i}", snout_c, snout_r, d, 0.018, spots, root)

    # Olhos grandes (desenho: olho de lado, olhando para a frente)
    for side in (-1, 1):
        c = Vector((0.115 * side, 0.12, 0.91))
        look = Vector((0.55 * side, 0.8, 0.1)).normalized()
        ellipsoid(f"Olho_{side}", c, (0.068, 0.068, 0.072), white, root)
        ellipsoid(f"Iris_{side}", c + look * 0.045, (0.046, 0.046, 0.05), iris, root)
        ellipsoid(f"Pupila_{side}", c + look * 0.067, (0.024, 0.024, 0.028), pupil, root)
        ellipsoid(f"Brilho_{side}", c + look * 0.07 + Vector((0.012 * side, 0, 0.02)), (0.01, 0.01, 0.01), white, root)
        if cfg.get("lashes"):
            for k in range(3):
                cone(f"Cilio_{side}_{k}", c + Vector((0.03 * side + 0.02 * k * side, 0.03, 0.06)),
                     c + Vector((0.05 * side + 0.03 * k * side, 0.02, 0.09)), 0.006, claw, root)

    # Chifres e crista
    for side in (-1, 1):
        cone(f"Chifre_{side}", (0.085 * side, -0.01, 1.0), (0.11 * side, -0.07, 1.14), 0.04, horn, root)
    for i, (y, z, r) in enumerate(((0.07, 1.02, 0.06), (0.0, 1.04, 0.065), (-0.07, 1.02, 0.06), (-0.13, 0.98, 0.05))):
        ellipsoid(f"Crista_{i}", (0.0, y, z), (r * 0.9, r, r * 0.8), crest, root, 12, 8)

    # Capuz com ponta de folha
    shell("Capuz", (0.0, 0.0, 0.88), (0.25, 0.25, 0.235), hood, root, cut_front=0.12, thickness=0.018, cut_below=0.7)
    leaf = cone("Capuz_folha", (0.0, -0.17, 1.03), cfg["hood_tip"], 0.08, hood, root, flatten=0.3)

    # Mochila, saco de dormir e cogumelo
    box("Mochila", (0.0, -0.25, 0.55), (0.32, 0.15, 0.3), leather, root, bevel=0.04)
    box("Bolso", (0.0, -0.33, 0.5), (0.2, 0.04, 0.14), leather, root, bevel=0.02)
    bpy.ops.mesh.primitive_cylinder_add(vertices=18, radius=0.075, depth=0.38, location=(0.0, -0.25, 0.74), rotation=(0, math.pi / 2, 0))
    roll = bpy.context.active_object
    roll.name = "Saco_de_dormir"
    finish(roll, bedroll, root)
    for side in (-1, 1):
        torus(f"Saco_amarra_{side}", (0.12 * side, -0.25, 0.74), 0.078, 0.01, strap, root, rotation=(0, math.pi / 2, 0))
        box(f"Alca_{side}", (0.12 * side, 0.02, 0.62), (0.035, 0.36, 0.02), leather, root, bevel=0.005, rotation=(0.35, 0, 0))
    mx, my, mz, mr = cfg["mushroom_pos"]
    shell("Cogumelo", (mx, my, mz), (mr, mr, mr * 0.75), shroom, root, cut_front=2.0, thickness=0.02, cut_below=mz - 0.005)
    for i, d in enumerate(((0.6, 0.2, 0.7), (-0.5, -0.3, 0.7), (0.0, 0.6, 0.75), (0.2, -0.7, 0.6), (-0.7, 0.4, 0.5))):
        dot(f"Cogumelo_pinta_{i}", (mx, my, mz), (mr, mr, mr * 0.75), d, mr * 0.22, shroom_spot, root)
    for i, (dx, dz) in enumerate(((0.06, -0.03), (0.1, 0.0))):
        ellipsoid(f"Bulbo_{i}", (mx + dx * (mr / 0.1), my - 0.02, mz + dz), (0.03, 0.03, 0.03), bulb, root, 12, 8)

    # Arma na cintura / costas
    box("Bainha", (0.2, -0.08, 0.36), (0.035, 0.03, 0.2), leather, root, bevel=0.008, rotation=(0.4, 0.2, 0.3))
    if cfg.get("swords"):
        for k, x in enumerate((-0.14, -0.08)):
            box(f"Cabo_{k}", (x, -0.3, 0.42), (0.025, 0.025, 0.16), strap, root, bevel=0.005, rotation=(0.0, 0.5, 0.0))
    return root


TICO = {
    "name": "TicoLirou", "cloth": (0.12, 0.34, 0.33), "hood": (0.1, 0.28, 0.25), "scarf": (0.07, 0.2, 0.16),
    "eye": (0.22, 0.45, 0.95), "mushroom": (0.93, 0.62, 0.8), "robe_open": 0.5, "robe_bottom": 0.2,
    "hood_tip": (0.0, -0.36, 1.18), "mushroom_pos": (0.1, -0.27, 0.84, 0.09),
}
TIKA = {
    "name": "TikaMuro", "cloth": (0.3, 0.15, 0.36), "hood": (0.33, 0.17, 0.4), "scarf": (0.3, 0.14, 0.34),
    "eye": (0.88, 0.15, 0.55), "mushroom": (0.93, 0.55, 0.78), "robe_open": 0.0, "robe_bottom": 0.24,
    "hood_tip": (0.0, -0.3, 1.1), "mushroom_pos": (-0.06, -0.27, 0.86, 0.14), "lashes": True, "swords": True,
}


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _materials.clear()


def export(root, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in bpy.context.scene.objects:
        obj.select_set(True)
    name = root.name.lower().replace("lirou", "_lirou").replace("muro", "_muro")
    glb = os.path.join(out_dir, f"{name}.glb")
    bpy.ops.export_scene.gltf(filepath=glb, export_format="GLB", export_apply=True, export_yup=True,
                              use_selection=False, export_cameras=False, export_lights=False)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "art_src", f"{name}.blend"))
    print("EXPORTADO", glb)
    return name


def render_previews(name):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_cavity = True
    scene.display.shading.show_shadows = True
    scene.render.resolution_x = 640
    scene.render.resolution_y = 720
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("Fundo")
    scene.world = world
    world.color = (0.95, 0.95, 0.95)
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = 1.55
    cam = bpy.data.objects.new("Cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    target = Vector((0.05, -0.1, 0.62))
    for label, angle in (("frente", 0.0), ("tres_quartos", -40.0), ("lado", -90.0), ("costas", 180.0)):
        a = math.radians(angle)
        offset = Vector((math.sin(a) * 4.0, math.cos(a) * 4.0, 0.9))
        cam.location = target + offset
        cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(PREVIEW_DIR, f"{name}_{label}.png")
        bpy.ops.render.render(write_still=True)
    print("PREVIEWS", PREVIEW_DIR)


for cfg, folder in ((TICO, "tico_lirou"), (TIKA, "tika_muro")):
    reset_scene()
    root = build_kobold(cfg)
    name = export(root, os.path.join(ROOT, "actors", folder))
    if PREVIEW_DIR:
        render_previews(name)
