"""Rato assado no espeto (cena de abertura do Tico, D029). Estilizado, formas macias (metaballs), cores chapadas.
Gera actors/props/rato/rato_espeto.glb (espeto + rato, com o traseiro como nó separado "Traseiro")
e actors/props/rato/rato_traseiro.glb (só o pedaço de trás, que vai para a Tika).
Convenção no Blender: rato deitado no espeto ao longo de +X (cabeça em +X), espeto sai pelo -X (onde se segura).
Uso: blender -b --factory-startup -P tools/blender/gerado/modelar_rato.py -- C:/dev/jogo
"""
import math
import os
import sys

import bpy
from mathutils import Vector

ROOT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "C:/dev/jogo"
OUT = ROOT + "/actors/props/rato/"
os.makedirs(OUT, exist_ok=True)


def material(name, color, rough=0.55, emit=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    if emit:
        bsdf.inputs["Emission Color"].default_value = (*emit, 1.0)
        bsdf.inputs["Emission Strength"].default_value = 0.6
    return m


def metaball(name, elements, res=0.006):
    data = bpy.data.metaballs.new(name)
    data.threshold = 0.3  # superfície mais "gorda": as bolas se fundem (cabeça presa no corpo)
    data.resolution = res
    data.render_resolution = res
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    for kind, co, radius, size in elements:
        e = data.elements.new(type=kind)
        e.co = Vector(co)
        e.radius = radius
        if kind == "ELLIPSOID":
            e.size_x, e.size_y, e.size_z = size
    return to_mesh(obj)


def to_mesh(obj):
    bpy.context.view_layer.objects.active = obj
    for o in bpy.context.scene.objects:
        o.select_set(o == obj)
    bpy.ops.object.convert(target="MESH")
    mesh = bpy.context.view_layer.objects.active
    bpy.ops.object.shade_smooth()
    return mesh


def sphere(name, co, radius, mat, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, location=co, segments=16, ring_count=10)
    o = bpy.context.active_object
    o.name = name
    o.scale = scale
    bpy.ops.object.shade_smooth()
    o.data.materials.append(mat)
    return o


def tube(name, points, radius, mat, taper_end=0.25):
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = radius
    curve.bevel_resolution = 4
    curve.use_fill_caps = True
    spline = curve.splines.new("BEZIER")
    spline.bezier_points.add(len(points) - 1)
    for p, co in zip(spline.bezier_points, points):
        p.co = Vector(co)
        p.handle_left_type = p.handle_right_type = "AUTO"
    spline.bezier_points[-1].radius = taper_end
    obj = bpy.data.objects.new(name, curve)
    bpy.context.scene.collection.objects.link(obj)
    mesh = to_mesh(obj)
    mesh.data.materials.append(mat)
    return mesh


bpy.ops.wm.read_factory_settings(use_empty=True)
ROAST = material("Assado", (0.2, 0.075, 0.025), 0.35)
CHAR = material("Tostado", (0.06, 0.025, 0.012), 0.55)
SKIN = material("Pele", (0.36, 0.13, 0.08), 0.45)
WOOD = material("Graveto", (0.2, 0.12, 0.06), 0.85)
DARK = material("Olho", (0.05, 0.03, 0.02), 0.3)

# corpo inteiro (uma forma só) e depois cortado em X = 0: frente e traseiro encaixam sem "cintura"
def body(name):
    return metaball(name, [
        ("ELLIPSOID", (-0.02, 0, 0), 0.07, (1.35, 0.78, 0.72)),
        ("BALL", (0.04, 0, 0.002), 0.05, None),       # pescoço/ombros
        ("BALL", (0.075, 0, 0.004), 0.042, None),     # cabeça
        ("ELLIPSOID", (0.118, 0, -0.004), 0.024, (1.0, 0.72, 0.7)),  # focinho
        ("BALL", (-0.07, 0, -0.004), 0.05, None),      # ancas
    ])


front = body("Frente")
back = body("Traseiro")
front.data.materials.append(ROAST)
back.data.materials.append(ROAST)
for obj, keep_positive in ((front, True), (back, False)):
    bpy.context.view_layer.objects.active = obj
    for o in bpy.context.scene.objects:
        o.select_set(o == obj)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.bisect(plane_co=(-0.005, 0, 0), plane_no=(1, 0, 0), clear_inner=keep_positive, clear_outer=not keep_positive,
                        use_fill=True)
    bpy.ops.mesh.select_all(action="DESELECT")
    bpy.ops.object.mode_set(mode="OBJECT")
# tostado: as faces de cima ficam mais escuras (marcas do fogo)
for obj in (front, back):
    obj.data.materials.append(CHAR)
    for poly in obj.data.polygons:
        n = poly.normal
        if n.z > 0.55 and (abs(poly.center.x * 31.0) % 1.0) < 0.35:
            poly.material_index = 1

nose = sphere("Nariz", (0.142, 0, -0.002), 0.008, CHAR)
eyes = [sphere("Olho%d" % i, (0.1, s * 0.024, 0.022), 0.006, DARK, (1.0, 1.0, 0.45)) for i, s in enumerate((-1, 1))]
ears = [sphere("Orelha%d" % i, (0.072, s * 0.028, 0.036), 0.014, SKIN, (0.4, 1.0, 1.0)) for i, s in enumerate((-1, 1))]
for e, s in zip(ears, (-1, 1)):
    e.rotation_euler = (s * 0.4, 0.5, 0)
# patinhas encolhidas, coladas na barriga (rato assado)
legs = [tube("PataF%d" % i, [(0.045, s * 0.028, -0.025), (0.07, s * 0.034, -0.043), (0.09, s * 0.03, -0.045)], 0.007, SKIN, 0.6)
        for i, s in enumerate((-1, 1))]
back_parts = [tube("PataT%d" % i, [(-0.06, s * 0.04, -0.03), (-0.04, s * 0.05, -0.05), (-0.015, s * 0.045, -0.055)], 0.009, SKIN, 0.6)
              for i, s in enumerate((-1, 1))]
tail = tube("Rabo", [(-0.12, 0, 0.0), (-0.16, 0.0, -0.03), (-0.19, 0.015, -0.07), (-0.2, 0.04, -0.1)], 0.008, SKIN, 0.2)
stick = tube("Graveto", [(-0.4, 0.0, -0.035), (-0.12, 0.0, -0.006), (0.22, 0.0, 0.006)], 0.0065, WOOD, 0.75)


def join(name, objs):
    for o in bpy.context.scene.objects:
        o.select_set(o in objs)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = name
    return obj


rat_front = join("Frente", [front, nose] + eyes + ears + legs)
rat_back = join("Traseiro", [back, tail] + back_parts)


def export(path, objs):
    for o in bpy.context.scene.objects:
        o.select_set(o in objs)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True, export_apply=True)


export(OUT + "rato_espeto.glb", [rat_front, rat_back, stick])
# o pedaço da Tika: só o traseiro, com o centro no meio dele
piece = rat_back.copy()
piece.data = rat_back.data.copy()
bpy.context.scene.collection.objects.link(piece)
piece.name = "Traseiro"
for v in piece.data.vertices:
    v.co.x += 0.09
export(OUT + "rato_traseiro.glb", [piece])
print("rato exportado:", len(rat_front.data.polygons) + len(rat_back.data.polygons), "faces")
