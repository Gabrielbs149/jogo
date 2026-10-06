"""Junta as animações baixadas do Mixamo num só .glb com os nomes que o jogo usa.
Entrada: art_src/mixamo/<heroi>_<animação>.fbx. A de "idle" tem que ter vindo COM a malha (skin);
as outras só com o movimento (sem skin), todas do mesmo personagem enviado ao Mixamo.
Saída: actors/<pasta>/<heroi>.glb (frente para +Y no Blender = -Z no Godot, pés na origem, altura pedida)
e art_src/<heroi>_mixamo.blend.

Uso: blender --background --factory-startup --python tools/blender/gerado/juntar_mixamo.py -- C:/dev/jogo tico tico_lirou 1.18
"""
import math
import sys

import bpy
import numpy as np
from mathutils import Matrix

args = sys.argv[sys.argv.index("--") + 1:]
ROOT, HERO, FOLDER = args[0], args[1], args[2]
HEIGHT = float(args[3]) if len(args) > 3 else 1.18
ANIMS = ["idle", "walk", "run", "attack", "dash_strike", "cast", "hide", "dodge", "hit", "down"]
SRC = ROOT + "/art_src/mixamo/%s_%s.fbx"


def imported(path: str) -> list:
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=path)
    return [o for o in bpy.data.objects if o not in before]


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = 30
objs = imported(SRC % (HERO, "idle"))
arm = next(o for o in objs if o.type == "ARMATURE")
mesh = next(o for o in objs if o.type == "MESH")
arm.name = HERO + "_rig"
actions = {}
first = arm.animation_data.action
first.name = "idle"
actions["idle"] = first

for name in ANIMS[1:]:
    new = imported(SRC % (HERO, name))
    other = next(o for o in new if o.type == "ARMATURE")
    act = other.animation_data.action
    act.name = name
    act.use_fake_user = True
    actions[name] = act
    for o in new:
        bpy.data.objects.remove(o, do_unlink=True)
    print("animação", name, act.frame_range[:])

# frente do personagem para +Y: o focinho (cabeça) fica do lado oposto ao rabo
bpy.context.view_layer.update()
arm.animation_data.action = None
bpy.context.scene.frame_set(0)
bpy.context.view_layer.update()
co = np.array([tuple(mesh.matrix_world @ v.co) for v in mesh.data.vertices])
z0, z1 = co[:, 2].min(), co[:, 2].max()
# a ponta do rabo é o ponto mais longe do centro na parte de baixo: ali é o lado de trás
low = co[co[:, 2] < z0 + (z1 - z0) * 0.35]
tip = low[np.argmax(np.abs(low[:, 1] - np.median(co[:, 1])))]
back_y = tip[1] - np.median(co[:, 1])
print("altura importada %.3f, ponta do rabo em y %+.3f" % (z1 - z0, back_y))
fix = Matrix.Identity(4)
if back_y > 0:  # rabo para +Y = olhando para -Y: vira
    fix = Matrix.Rotation(math.pi, 4, "Z")
scale = HEIGHT / (z1 - z0)
arm.matrix_world = Matrix.Scale(scale, 4) @ fix @ arm.matrix_world
bpy.context.view_layer.update()
co = np.array([tuple(mesh.matrix_world @ v.co) for v in mesh.data.vertices])
print("final: altura %.3f, pés em z %.3f, x %.2f..%.2f y %.2f..%.2f" % (co[:, 2].max() - co[:, 2].min(), co[:, 2].min(),
      co[:, 0].min(), co[:, 0].max(), co[:, 1].min(), co[:, 1].max()))

# o Mixamo não conhece rabo: ele prende o rabo nas pernas e o rabo "chuta" junto. Rabo vai todo para o quadril.
TAIL_Y, TAIL_Z = -0.15 * HEIGHT / 1.18, 0.45 * HEIGHT / 1.18
tail_idx = [i for i, (x, y, z) in enumerate(co) if y < TAIL_Y and z < TAIL_Z]
hips = next((g for g in mesh.vertex_groups if g.name.endswith("Hips")), None)
if hips and tail_idx:
    for group in mesh.vertex_groups:
        group.remove(tail_idx)
    hips.add(tail_idx, 1.0, "REPLACE")
print("rabo preso no quadril:", len(tail_idx), "vértices")

# uma faixa NLA por animação, para o exportador levar todas
arm.animation_data_create()
for name in ANIMS:
    act = actions[name]
    track = arm.animation_data.nla_tracks.new()
    track.name = name
    strip = track.strips.new(name, int(act.frame_range[0]), act)
    if hasattr(strip, "action_slot") and len(act.slots) > 0:
        strip.action_slot = act.slots[0]
for img in bpy.data.images:
    if img.source == "FILE" and img.packed_file is None:
        try:
            img.pack()
        except RuntimeError:
            pass

bpy.ops.wm.save_as_mainfile(filepath=ROOT + "/art_src/%s_mixamo.blend" % HERO)
for o in bpy.context.scene.objects:
    o.select_set(o in (arm, mesh))
bpy.context.view_layer.objects.active = arm
bpy.ops.export_scene.gltf(
    filepath=ROOT + "/actors/%s/%s.glb" % (FOLDER, FOLDER), export_format="GLB", use_selection=True,
    export_yup=True, export_apply=False, export_skins=True, export_animations=True,
    export_animation_mode="NLA_TRACKS", export_force_sampling=True,
)
print("exportado", len(ANIMS), "animações")
