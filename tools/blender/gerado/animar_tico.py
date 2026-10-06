"""Esqueleto + animações do Tico-Lirou (malha do TRELLIS, sem rig).
Monta um esqueleto de kobold, pesa cada vértice pela distância aos ossos (com regras por região:
cabeça, braços, pernas, rabo, mochila) e cria as animações. Exporta o .glb com esqueleto e animações.

Uso (Blender sem janela):
  blender --background --factory-startup --python tools/blender/gerado/animar_tico.py -- C:/dev/jogo
Lê art_src/tico_lirou.blend (objeto TicoLirou), salva art_src/tico_lirou_rig.blend e actors/tico_lirou/tico_lirou.glb.
Convenção: o Tico olha para +Y, +X é o lado DIREITO dele, pés na origem. Ângulos em graus, eixos do mundo.
"""
import math
import sys

import bpy
import numpy as np
from mathutils import Matrix, Quaternion, Vector

ROOT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "C:/dev/jogo"
FPS = 30

# ---------- ossos: nome -> (cabeça, ponta, pai)
BONES = {
    "root": ((0, 0, 0), (0, 0.15, 0), None),
    "hips": ((0, 0.05, 0.30), (0, 0.04, 0.45), "root"),
    "spine": ((0, 0.04, 0.45), (0, 0.05, 0.62), "hips"),
    "chest": ((0, 0.05, 0.62), (0, 0.06, 0.77), "spine"),
    "head": ((0, 0.06, 0.78), (0, 0.10, 1.10), "chest"),
    "upperarm_r": ((0.20, 0.12, 0.66), (0.245, 0.03, 0.50), "chest"),
    "forearm_r": ((0.245, 0.03, 0.50), (0.29, 0.19, 0.37), "upperarm_r"),
    "hand_r": ((0.29, 0.19, 0.37), (0.30, 0.24, 0.30), "forearm_r"),
    "upperarm_l": ((-0.20, 0.12, 0.66), (-0.25, 0.06, 0.50), "chest"),
    "forearm_l": ((-0.25, 0.06, 0.50), (-0.295, 0.21, 0.38), "upperarm_l"),
    "hand_l": ((-0.295, 0.21, 0.38), (-0.30, 0.25, 0.32), "forearm_l"),
    "thigh_r": ((0.12, 0.12, 0.30), (0.14, 0.17, 0.17), "hips"),
    "shin_r": ((0.14, 0.17, 0.17), (0.135, 0.18, 0.05), "thigh_r"),
    "foot_r": ((0.135, 0.18, 0.05), (0.14, 0.30, 0.02), "shin_r"),
    "thigh_l": ((-0.12, 0.05, 0.30), (-0.145, 0.08, 0.17), "hips"),
    "shin_l": ((-0.145, 0.08, 0.17), (-0.15, 0.03, 0.05), "thigh_l"),
    "foot_l": ((-0.15, 0.03, 0.05), (-0.15, 0.17, 0.02), "shin_l"),
    "tail1": ((0, -0.12, 0.32), (0, -0.25, 0.24), "hips"),
    "tail2": ((0, -0.25, 0.24), (0, -0.38, 0.20), "tail1"),
    "tail3": ((0, -0.38, 0.20), (0, -0.53, 0.20), "tail2"),
}
DEFORM = [b for b in BONES if b != "root"]


def allowed(name: str, v: np.ndarray) -> np.ndarray:
    """Máscara de quais vértices este osso pode mexer (evita mochila balançando com a cabeça etc.)."""
    x, y, z = v[:, 0], v[:, 1], v[:, 2]
    backpack = (y < -0.12) & (z > 0.42) & (z < 0.95)
    if name == "head":
        return (z > 0.72) & ~backpack
    if name.startswith(("upperarm", "forearm", "hand")):
        side = x > 0.15 if name.endswith("_r") else x < -0.15
        return side & (z < 0.75) & ~backpack
    if name.startswith(("thigh", "shin", "foot")):
        side = x > 0.03 if name.endswith("_r") else x < -0.03
        return side & (z < 0.42) & (y > -0.2)
    if name.startswith("tail"):
        return (y < -0.1) & (z < 0.5)
    if name == "hips":
        return z < 0.55
    if name == "spine":
        return (z > 0.35) & (z < 0.8)
    if name == "chest":
        return z > 0.5
    return np.ones(len(v), bool)


# ---------- animações: lista de (quadro, pose). pose = {osso: [(eixo, graus), ...], "loc": (x, y, z)}
def wave(n, f, amp, phase=0.0):
    return amp * math.sin(2 * math.pi * (f / n) + phase)


def idle(f):
    n = 60
    return {
        "chest": [("X", wave(n, f, 2.0))],
        "head": [("X", wave(n, f, 3.0, 0.8))],
        "upperarm_r": [("X", wave(n, f, 3.0, 0.3))], "upperarm_l": [("X", wave(n, f, 3.0, 0.5))],
        "tail1": [("Z", wave(n, f, 7.0))], "tail2": [("Z", wave(n, f, 9.0, 0.6))], "tail3": [("Z", wave(n, f, 12.0, 1.2))],
        "loc": (0, 0, wave(n, f, 0.008)),
    }


def gait(n, leg, shin, arm, elbow, lean, bob, tail):
    def pose(f):
        s = math.sin(2 * math.pi * f / n)
        c = math.cos(2 * math.pi * f / n)
        return {
            "thigh_r": [("X", leg * s)], "thigh_l": [("X", -leg * s)],
            "shin_r": [("X", -shin * max(0.0, -c))], "shin_l": [("X", -shin * max(0.0, c))],
            "upperarm_r": [("X", -arm * s)], "upperarm_l": [("X", arm * s)],
            "forearm_r": [("X", elbow)], "forearm_l": [("X", elbow)],
            "hips": [("Z", 5.0 * s)], "spine": [("X", -lean)], "chest": [("Z", -6.0 * s)],
            "tail1": [("Z", -tail * s)], "tail2": [("Z", -tail * 1.3 * s)], "tail3": [("Z", -tail * 1.6 * s)],
            "loc": (0, 0, bob * abs(math.sin(2 * math.pi * f / n))),
        }
    return pose


walk = gait(24, 25.0, 30.0, 18.0, 10.0, 3.0, 0.02, 8.0)
run = gait(16, 40.0, 60.0, 35.0, 45.0, 12.0, 0.035, 12.0)

REST: dict = {}
ANIMS = {
    # nome: (quadros, laço, função ou lista de chaves)
    "idle": (60, True, idle),
    "walk": (24, True, walk),
    "run": (16, True, run),
    # Adaga: puxa o braço direito para trás e estoca para a frente
    "attack": (14, False, [
        (0, REST),
        (4, {"upperarm_r": [("X", -40)], "forearm_r": [("X", 60)], "chest": [("Z", -15)], "hips": [("Z", -5)]}),
        (7, {"upperarm_r": [("X", 85)], "forearm_r": [("X", -5)], "chest": [("Z", 18), ("X", -10)], "spine": [("X", -6)],
             "thigh_r": [("X", 15)], "thigh_l": [("X", -12)], "loc": (0, 0.05, 0)}),
        (10, {"upperarm_r": [("X", 60)], "forearm_r": [("X", 10)], "chest": [("Z", 10)]}),
        (14, REST),
    ]),
    # Bote das sombras: agacha, salta para a frente com as duas mãos
    "dash_strike": (16, False, [
        (0, REST),
        (4, {"thigh_r": [("X", 35)], "thigh_l": [("X", 35)], "shin_r": [("X", -60)], "shin_l": [("X", -60)],
             "spine": [("X", -20)], "loc": (0, 0, -0.07)}),
        (7, {"spine": [("X", -25)], "chest": [("X", -10)], "upperarm_r": [("X", 80)], "upperarm_l": [("X", 80)],
             "thigh_r": [("X", -20)], "thigh_l": [("X", 30)], "tail1": [("X", 15)], "loc": (0, 0.1, 0.08)}),
        (10, {"spine": [("X", -15)], "upperarm_r": [("X", 95)], "upperarm_l": [("X", 70)], "forearm_r": [("X", -10)], "loc": (0, 0.06, 0)}),
        (16, REST),
    ]),
    # Espinhos: ergue os braços e joga para a frente
    "cast": (20, False, [
        (0, REST),
        (7, {"upperarm_r": [("X", 95)], "upperarm_l": [("X", 95)], "forearm_r": [("X", 35)], "forearm_l": [("X", 35)],
             "spine": [("X", 8)], "head": [("X", 10)], "tail1": [("X", -10)]}),
        (11, {"upperarm_r": [("X", 95)], "upperarm_l": [("X", 95)], "forearm_r": [("X", 35)], "forearm_l": [("X", 35)],
              "spine": [("X", 8)], "head": [("X", 10)]}),
        (14, {"upperarm_r": [("X", 70)], "upperarm_l": [("X", 70)], "spine": [("X", -12)], "head": [("X", -8)]}),
        (20, REST),
    ]),
    # Camuflagem: se encolhe no mato
    "hide": (16, False, [
        (0, REST),
        (6, {"thigh_r": [("X", 55)], "thigh_l": [("X", 55)], "shin_r": [("X", -95)], "shin_l": [("X", -95)],
             "spine": [("X", -30)], "head": [("X", -15)], "upperarm_r": [("X", 30)], "upperarm_l": [("X", 30)],
             "loc": (0, 0, -0.13)}),
        (11, {"thigh_r": [("X", 55)], "thigh_l": [("X", 55)], "shin_r": [("X", -95)], "shin_l": [("X", -95)],
              "spine": [("X", -30)], "head": [("X", -15)], "upperarm_r": [("X", 30)], "upperarm_l": [("X", 30)],
              "loc": (0, 0, -0.13)}),
        (16, REST),
    ]),
    # Ação ardilosa: pulinho encolhido
    "dodge": (12, False, [
        (0, REST),
        (3, {"thigh_r": [("X", 30)], "thigh_l": [("X", 30)], "shin_r": [("X", -50)], "shin_l": [("X", -50)], "loc": (0, 0, -0.05)}),
        (6, {"thigh_r": [("X", -35)], "thigh_l": [("X", -35)], "shin_r": [("X", -70)], "shin_l": [("X", -70)],
             "spine": [("X", -20)], "upperarm_r": [("X", -30)], "upperarm_l": [("X", -30)], "tail1": [("X", 20)], "loc": (0, 0, 0.12)}),
        (12, REST),
    ]),
    # levou um golpe
    "hit": (10, False, [
        (0, REST),
        (3, {"spine": [("X", 14)], "chest": [("X", 8)], "head": [("X", 12)], "upperarm_r": [("Y", 0), ("Z", 0)],
             "upperarm_l": [("X", -15)], "loc": (0, -0.05, 0)}),
        (10, REST),
    ]),
    # caiu: tomba de costas e fica no chão
    "down": (24, False, [
        (0, REST),
        (8, {"root": [("X", 30)], "spine": [("X", 10)], "thigh_r": [("X", 20)], "thigh_l": [("X", 20)]}),
        (18, {"root": [("X", 88)], "head": [("X", -10)], "upperarm_r": [("X", -30)], "upperarm_l": [("X", -30)],
              "thigh_r": [("X", 30)], "thigh_l": [("X", 15)], "loc": (0, 0, 0.12)}),
        (24, {"root": [("X", 86)], "head": [("X", -15)], "upperarm_r": [("X", -35)], "upperarm_l": [("X", -25)],
              "thigh_r": [("X", 25)], "thigh_l": [("X", 10)], "loc": (0, 0, 0.12)}),
    ]),
}


def main() -> None:
    bpy.ops.wm.open_mainfile(filepath=ROOT + "/art_src/tico_lirou.blend")
    scene = bpy.context.scene
    scene.render.fps = FPS
    mesh = bpy.data.objects["TicoLirou"]
    for o in list(scene.objects):
        if o.type == "ARMATURE":
            bpy.data.objects.remove(o)
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)
    mesh.vertex_groups.clear()
    for m in list(mesh.modifiers):
        if m.type == "ARMATURE":
            mesh.modifiers.remove(m)
    mesh.parent = None

    # esqueleto
    arm_data = bpy.data.armatures.new("TicoRig")
    rig = bpy.data.objects.new("TicoRig", arm_data)
    scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    for o in scene.objects:
        o.select_set(o == rig)
    bpy.ops.object.mode_set(mode="EDIT")
    for name, (head, tail, parent) in BONES.items():
        eb = arm_data.edit_bones.new(name)
        eb.head = Vector(head)
        eb.tail = Vector(tail)
        eb.roll = 0.0
        eb.use_deform = name != "root"
    for name, (_, _, parent) in BONES.items():
        if parent:
            arm_data.edit_bones[name].parent = arm_data.edit_bones[parent]
            arm_data.edit_bones[name].use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")

    # pesos por distância aos ossos, com as regras por região
    me = mesh.data
    v = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", v)
    v = v.reshape(-1, 3) @ np.array(mesh.matrix_world)[:3, :3].T + np.array(mesh.matrix_world)[:3, 3]
    dists = []
    for name in DEFORM:
        a = np.array(BONES[name][0], float)
        b = np.array(BONES[name][1], float)
        ab = b - a
        t = np.clip(((v - a) @ ab) / (ab @ ab), 0.0, 1.0)
        d = np.linalg.norm(v - (a + t[:, None] * ab), axis=1)
        d[~allowed(name, v)] = np.inf
        dists.append(d)
    dists = np.stack(dists, axis=1)
    w = 1.0 / (dists + 0.012) ** 4
    w[~np.isfinite(dists)] = 0.0
    top = np.argsort(-w, axis=1)[:, :3]
    groups = {name: mesh.vertex_groups.new(name=name) for name in DEFORM}
    lonely = 0
    for i in range(len(v)):
        ws = w[i, top[i]]
        if ws.sum() <= 0.0:
            lonely += 1
            groups["spine"].add([i], 1.0, "REPLACE")
            continue
        ws = ws / ws.sum()
        for k, wk in zip(top[i], ws):
            if wk > 0.02:
                groups[DEFORM[k]].add([i], float(wk), "REPLACE")
    print("vértices sem osso (foram para a coluna):", lonely)
    mesh.parent = rig
    mod = mesh.modifiers.new("Armature", "ARMATURE")
    mod.object = rig

    # animações
    rig.animation_data_create()
    rest = {name: rig.data.bones[name].matrix_local.to_3x3() for name in BONES}
    for pb in rig.pose.bones:
        pb.rotation_mode = "QUATERNION"
    for anim, (length, loop, spec) in ANIMS.items():
        action = bpy.data.actions.new(anim)
        action.use_fake_user = True
        rig.animation_data.action = action
        keys = [(f, spec(f)) for f in range(0, length + 1, 2)] if callable(spec) else spec
        for frame, pose in keys:
            for pb in rig.pose.bones:
                q = Quaternion()
                for axis, deg in pose.get(pb.name, []):
                    world = Matrix.Rotation(math.radians(deg), 3, axis)
                    local = rest[pb.name].inverted() @ world @ rest[pb.name]
                    q = local.to_quaternion() @ q
                pb.rotation_quaternion = q
                pb.location = Vector((0, 0, 0))
                if pb.name == "root":
                    loc = Vector(pose.get("loc", (0, 0, 0)))
                    pb.location = rest["root"].inverted() @ loc
                    pb.keyframe_insert("location", frame=frame)
                pb.keyframe_insert("rotation_quaternion", frame=frame)
        action.frame_range = (0, length)
        # guarda cada animação numa faixa NLA para o exportador levar todas
        track = rig.animation_data.nla_tracks.new()
        track.name = anim
        track.strips.new(anim, 0, action)
        rig.animation_data.action = None
        print("animação", anim, length, "quadros", "(laço)" if loop else "")

    bpy.ops.wm.save_as_mainfile(filepath=ROOT + "/art_src/tico_lirou_rig.blend")
    for o in scene.objects:
        o.select_set(o in (rig, mesh))
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(
        filepath=ROOT + "/actors/tico_lirou/tico_lirou.glb", export_format="GLB", use_selection=True,
        export_yup=True, export_apply=False, export_skins=True, export_animations=True,
        export_animation_mode="NLA_TRACKS", export_force_sampling=True, export_def_bones=False,
    )
    print("exportado com", len(ANIMS), "animações")


main()
