"""Esqueleto HUMANOIDE do Tico-Lirou (D028), no padrão que o Godot usa para trocar animações entre personagens
(SkeletonProfileHumanoid): Hips, Spine, Chest, Neck, Head, Left/Right UpperArm, LowerArm, Hand, UpperLeg,
LowerLeg, Foot + Tail1..3. As animações vêm prontas de outro personagem (KayKit) pelo retarget do Godot.

Pesos: o Blender calcula pelo método de calor ("Automatic Weights") numa CÓPIA FECHADA do modelo (remesh em voxel),
porque a malha do TRELLIS tem buracos e o cálculo direto falha; depois os pesos são transferidos para a malha original.
O modelo é exportado olhando para +Z no Godot (igual aos personagens do KayKit); a cena do herói vira o modelo.

Uso: blender --background --factory-startup --python tools/blender/gerado/rig_tico_humanoide.py -- C:/dev/jogo [tico|tika]
Cada personagem tem um PERFIL abaixo: o .blend limpo (no Blender olhando para +Y, esquerda em -X, pés na origem),
onde ficam os ossos (medidos com grade na foto de frente e de lado) e as regiões do corpo (mochila, braços, pernas, rabo).
Tico: art_src/tico_lirou.blend -> actors/tico_lirou/tico_lirou_humanoide.glb.
Tika (D046): art_src/tika_muro_limpa.blend -> actors/tika_muro/tika_muro_humanoide.glb.
"""
import math
import sys

import bpy
from mathutils import Vector

_ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ROOT = _ARGS[0] if _ARGS else "C:/dev/jogo"
WHO = _ARGS[1] if len(_ARGS) > 1 else "tico"
K = 10.0
# só o tronco e o rabo usam o teste de "enxergar o osso" (separa barriga, costas e rabo)
VISIBILITY = {"Hips", "Spine", "Chest", "Tail1", "Tail2", "Tail3"}

# osso: (cabeça, ponta, pai) — coordenadas do Blender, olhando para +Y, esquerda em -X
TICO_BONES = {
    "Root": ((0, 0, 0), (0, 0.12, 0), None),
    "Hips": ((0, 0.05, 0.30), (0, 0.045, 0.45), "Root"),
    "Spine": ((0, 0.045, 0.45), (0, 0.05, 0.62), "Hips"),
    "Chest": ((0, 0.05, 0.62), (0, 0.06, 0.76), "Spine"),
    "Neck": ((0, 0.06, 0.76), (0, 0.07, 0.82), "Chest"),
    "Head": ((0, 0.07, 0.82), (0, 0.1, 1.1), "Neck"),
    "LeftUpperArm": ((-0.2, 0.12, 0.66), (-0.25, 0.06, 0.5), "Chest"),
    "LeftLowerArm": ((-0.25, 0.06, 0.5), (-0.295, 0.21, 0.38), "LeftUpperArm"),
    "LeftHand": ((-0.295, 0.21, 0.38), (-0.3, 0.25, 0.31), "LeftLowerArm"),
    "RightUpperArm": ((0.2, 0.12, 0.66), (0.245, 0.03, 0.5), "Chest"),
    "RightLowerArm": ((0.245, 0.03, 0.5), (0.29, 0.19, 0.37), "RightUpperArm"),
    "RightHand": ((0.29, 0.19, 0.37), (0.3, 0.24, 0.3), "RightLowerArm"),
    "LeftUpperLeg": ((-0.12, 0.05, 0.3), (-0.145, 0.08, 0.17), "Hips"),
    "LeftLowerLeg": ((-0.145, 0.08, 0.17), (-0.15, 0.03, 0.05), "LeftUpperLeg"),
    "LeftFoot": ((-0.15, 0.03, 0.05), (-0.15, 0.17, 0.02), "LeftLowerLeg"),
    "RightUpperLeg": ((0.12, 0.12, 0.3), (0.14, 0.17, 0.17), "Hips"),
    "RightLowerLeg": ((0.14, 0.17, 0.17), (0.135, 0.18, 0.05), "RightUpperLeg"),
    "RightFoot": ((0.135, 0.18, 0.05), (0.14, 0.3, 0.02), "RightLowerLeg"),
    "Tail1": ((0, -0.12, 0.32), (0, -0.25, 0.24), "Hips"),
    "Tail2": ((0, -0.25, 0.24), (0, -0.38, 0.2), "Tail1"),
    "Tail3": ((0, -0.38, 0.2), (0, -0.53, 0.2), "Tail2"),
}

# Tika (medida já com o corpo no centro: o modelo vem 0,27 m para a frente por causa do rabo comprido e da mochila)
TIKA_BONES = {
    "Root": ((0, 0, 0), (0, 0.12, 0), None),
    "Hips": ((0, -0.02, 0.28), (0, 0.0, 0.42), "Root"),
    "Spine": ((0, 0.0, 0.42), (0, 0.01, 0.56), "Hips"),
    "Chest": ((0, 0.01, 0.56), (0, 0.04, 0.70), "Spine"),
    "Neck": ((0, 0.04, 0.70), (0, 0.07, 0.78), "Chest"),
    "Head": ((0, 0.07, 0.78), (0, 0.12, 1.05), "Neck"),
    "LeftUpperArm": ((-0.15, 0.05, 0.62), (-0.18, 0.09, 0.50), "Chest"),
    "LeftLowerArm": ((-0.18, 0.09, 0.50), (-0.19, 0.14, 0.43), "LeftUpperArm"),
    "LeftHand": ((-0.19, 0.14, 0.43), (-0.19, 0.18, 0.35), "LeftLowerArm"),
    "RightUpperArm": ((0.15, 0.05, 0.62), (0.18, 0.09, 0.50), "Chest"),
    "RightLowerArm": ((0.18, 0.09, 0.50), (0.19, 0.14, 0.43), "RightUpperArm"),
    "RightHand": ((0.19, 0.14, 0.43), (0.19, 0.18, 0.35), "RightLowerArm"),
    "LeftUpperLeg": ((-0.11, 0.0, 0.28), (-0.14, 0.05, 0.17), "Hips"),
    "LeftLowerLeg": ((-0.14, 0.05, 0.17), (-0.16, 0.05, 0.06), "LeftUpperLeg"),
    "LeftFoot": ((-0.16, 0.05, 0.06), (-0.17, 0.16, 0.02), "LeftLowerLeg"),
    "RightUpperLeg": ((0.11, 0.0, 0.28), (0.14, 0.05, 0.17), "Hips"),
    "RightLowerLeg": ((0.14, 0.05, 0.17), (0.16, 0.05, 0.06), "RightUpperLeg"),
    "RightFoot": ((0.16, 0.05, 0.06), (0.17, 0.16, 0.02), "RightLowerLeg"),
    "Tail1": ((0, -0.12, 0.28), (0, -0.32, 0.22), "Hips"),
    "Tail2": ((0, -0.32, 0.22), (0, -0.55, 0.15), "Tail1"),
    "Tail3": ((0, -0.55, 0.15), (0, -0.84, 0.2), "Tail2"),
}

# regiões do corpo (metros, sem escala): o que cada osso pode puxar
PROFILES = {
    "tico": {
        "blend": "/art_src/tico_lirou.blend", "object": "TicoLirou", "rig": "TicoRig", "shift_y": 0.0,
        "out_blend": "/art_src/tico_lirou_humanoide.blend", "out_glb": "/actors/tico_lirou/tico_lirou_humanoide.glb",
        "bones": TICO_BONES,
        "backpack": (-0.12, 0.42, 0.95), "head_z": 0.74, "neck_z": (0.68, 0.9), "arm_x": 0.14, "arm_top": 0.76,
        "leg_top": 0.42, "leg_back": -0.2, "tail": (-0.08, 0.5), "hips_top": 0.56, "spine_z": (0.36, 0.8), "chest_z": 0.5,
        "sleeve_z": 0.5,
    },
    "tika": {
        "blend": "/art_src/tika_muro_limpa.blend", "object": "TikaMuro", "rig": "TikaRig", "shift_y": -0.27,
        "out_blend": "/art_src/tika_muro_humanoide.blend", "out_glb": "/actors/tika_muro/tika_muro_humanoide.glb",
        "bones": TIKA_BONES,
        "backpack": (-0.06, 0.4, 1.02), "head_z": 0.74, "neck_z": (0.66, 0.86), "arm_x": 0.13, "arm_top": 0.7,
        "leg_top": 0.32, "leg_back": -0.12, "tail": (-0.05, 0.4), "hips_top": 0.5, "spine_z": (0.36, 0.76), "chest_z": 0.5,
        "sleeve_z": 0.48,
    },
}
P = PROFILES[WHO]
BONES = P["bones"]


def _skin_mask(mesh):
    """Cor média da textura em cada vértice -> (é pele verde, é pêssego)."""
    import numpy as np
    mat = mesh.data.materials[0]
    img = [nd.image for nd in mat.node_tree.nodes if nd.type == "TEX_IMAGE"][0]
    w, h = img.size
    px = np.array(img.pixels[:]).reshape(h, w, 4)
    loops = mesh.data.loops
    uv = np.empty(len(loops) * 2)
    mesh.data.uv_layers.active.data.foreach_get("uv", uv)
    uv = uv.reshape(-1, 2)
    vi = np.empty(len(loops), int)
    loops.foreach_get("vertex_index", vi)
    x = np.clip((uv[:, 0] % 1.0) * (w - 1), 0, w - 1).astype(int)
    y = np.clip((uv[:, 1] % 1.0) * (h - 1), 0, h - 1).astype(int)
    n = len(mesh.data.vertices)
    acc = np.zeros((n, 3))
    cnt = np.zeros(n)
    np.add.at(acc, vi, px[y, x, :3])
    np.add.at(cnt, vi, 1)
    c = acc / np.maximum(cnt, 1)[:, None]
    r, g, b = c[:, 0], c[:, 1], c[:, 2]
    skin = (g > r + 0.06) & (g > b + 0.08) & (g > 0.28)
    peach = (r > 0.6) & (r > g + 0.1) & (g > b)
    # capa/manga: verde-azulado escuro (Tico) ou roxo (Tika)
    teal = (g > r + 0.03) & (b > r + 0.03) & (np.abs(g - b) < 0.1) & ~skin
    purple = (r > g + 0.03) & (b > g + 0.03) & ~skin
    return skin, peach, teal | purple


def _weights(mesh, rig) -> None:
    """Pesos por "o ponto da pele enxerga o osso": para cada vértice, os ossos visíveis (raio até o ponto mais
    perto do osso sem atravessar o corpo) ganham peso 1/d^4; depois suaviza pelas arestas da malha (juntas macias).
    Regras por região evitam o braço grudar na barriga e a cabeça puxar a mochila."""
    import numpy as np
    from mathutils.bvhtree import BVHTree

    # corpo fechado (voxel) só para os raios: a malha do TRELLIS tem buracos
    proxy = mesh.copy()
    proxy.data = mesh.data.copy()
    bpy.context.scene.collection.objects.link(proxy)
    rem = proxy.modifiers.new("Remesh", "REMESH")
    rem.mode = "VOXEL"
    rem.voxel_size = 0.015 * K
    deps = bpy.context.evaluated_depsgraph_get()
    bvh = BVHTree.FromObject(proxy, deps)

    names = [b for b in BONES if b != "Root"]
    heads = np.array([BONES[b][0] for b in names], float) * K
    tails = np.array([BONES[b][1] for b in names], float) * K
    n = len(mesh.data.vertices)
    co = np.empty(n * 3)
    mesh.data.vertices.foreach_get("co", co)
    v = co.reshape(-1, 3)
    ab = tails - heads
    t = np.clip(np.einsum("nbk,bk->nb", v[:, None, :] - heads[None], ab) / (ab * ab).sum(1)[None], 0.0, 1.0)
    closest = heads[None] + t[..., None] * ab[None]
    d = np.linalg.norm(v[:, None, :] - closest, axis=2)

    # regiões (coordenadas sem escala; olhando para +Y, esquerda em -X), do perfil do personagem
    x, y, z = v[:, 0] / K, v[:, 1] / K, v[:, 2] / K
    bp = P["backpack"]
    backpack = (y < bp[0]) & (z > bp[1]) & (z < bp[2])
    allowed = np.ones_like(d, bool)
    for j, b in enumerate(names):
        if b == "Head":
            allowed[:, j] = (z > P["head_z"]) & ~backpack
        elif b == "Neck":
            allowed[:, j] = (z > P["neck_z"][0]) & (z < P["neck_z"][1]) & ~backpack
        elif "Arm" in b or "Hand" in b:
            side = (x < -P["arm_x"]) if b.startswith("Left") else (x > P["arm_x"])
            allowed[:, j] = side & (z < P["arm_top"]) & ~backpack
        elif "Leg" in b or "Foot" in b:
            side = (x < 0.02) if b.startswith("Left") else (x > -0.02)
            allowed[:, j] = side & (z < P["leg_top"]) & (y > P["leg_back"])
        elif b.startswith("Tail"):
            allowed[:, j] = (y < P["tail"][0]) & (z < P["tail"][1])
        elif b == "Hips":
            allowed[:, j] = z < P["hips_top"]
        elif b == "Spine":
            allowed[:, j] = (z > P["spine_z"][0]) & (z < P["spine_z"][1])
        elif b == "Chest":
            allowed[:, j] = z > P["chest_z"]
    # pela cor da textura: braço e mão seguem o osso onde é PELE (verde; palma cor de pêssego na mão).
    # Perto do osso também vale o que não é pele: as garras (escuras) seguem a mão e a manga da capa segue o braço
    # (antes ficavam presas na barriga e esticavam em espinhos quando a mão mexia). O resto da capa fica no peito.
    skin, peach, teal = _skin_mask(mesh)
    for j, b in enumerate(names):
        if "UpperArm" in b:
            allowed[:, j] &= skin | ((d[:, j] < 0.06 * K) & (z > P["sleeve_z"]))
        elif "LowerArm" in b:
            allowed[:, j] &= skin | ((d[:, j] < 0.045 * K) & ~teal)
        elif "Hand" in b:
            allowed[:, j] &= skin | peach | ((d[:, j] < 0.05 * K) & ~teal)
    print("pele:", int(skin.sum()), "de", n, "vértices")
    d = np.where(allowed, d, np.inf)

    # visibilidade: só testa os ossos até 2,2x a distância do mais perto
    nearest = d.min(1)
    eps = 0.004 * K
    for i in range(n):
        p = Vector(v[i])
        for j in np.nonzero(d[i] < nearest[i] * 2.2 + 0.02 * K)[0]:
            if names[j] not in VISIBILITY:
                continue  # dedos e garras finas "batem" no próprio pé/mão: para membros vale a região + distância
            target = Vector(closest[i, j])
            direction = target - p
            length = direction.length
            if length < eps * 2:
                continue
            direction.normalize()
            hit = bvh.ray_cast(p + direction * eps, direction, length - eps * 2)
            if hit[0] is not None:
                d[i, j] = np.inf
    # quem não enxerga osso nenhum fica com o mais perto permitido
    blind = ~np.isfinite(d).any(1)
    w = np.where(np.isfinite(d), 1.0 / (d + 0.01 * K) ** 4, 0.0)
    if blind.any():
        base = np.where(allowed, np.linalg.norm(v[:, None, :] - closest, axis=2), np.inf)
        w[blind, base[blind].argmin(1)] = 1.0
    w /= w.sum(1, keepdims=True)

    # suaviza pelas arestas (juntas macias), sem espalhar demais
    edges = np.empty(len(mesh.data.edges) * 2, int)
    mesh.data.edges.foreach_get("vertices", edges)
    edges = edges.reshape(-1, 2)
    deg = np.bincount(edges.ravel(), minlength=n).astype(float)[:, None]
    for _ in range(8):
        acc = np.zeros_like(w)
        np.add.at(acc, edges[:, 0], w[edges[:, 1]])
        np.add.at(acc, edges[:, 1], w[edges[:, 0]])
        avg = np.where(deg > 0, acc / np.maximum(deg, 1), w)
        w = 0.5 * w + 0.5 * avg
        w = np.where(allowed, w, 0.0)
        w /= np.maximum(w.sum(1, keepdims=True), 1e-9)
    # no máximo 4 ossos por vértice
    order = np.argsort(-w, axis=1)
    keep = np.zeros_like(w, bool)
    np.put_along_axis(keep, order[:, :4], True, axis=1)
    w = np.where(keep & (w > 0.01), w, 0.0)
    w /= np.maximum(w.sum(1, keepdims=True), 1e-9)

    groups = {b: mesh.vertex_groups.new(name=b) for b in names}
    for j, b in enumerate(names):
        idx = np.nonzero(w[:, j] > 0.0)[0]
        g = groups[b]
        for i in idx:
            g.add([int(i)], float(w[i, j]), "REPLACE")
        print("peso", b, len(idx))
    bpy.data.objects.remove(proxy)


def main() -> None:
    bpy.ops.wm.open_mainfile(filepath=ROOT + P["blend"])
    scene = bpy.context.scene
    mesh = bpy.data.objects[P["object"]]
    for o in list(scene.objects):
        if o != mesh:
            bpy.data.objects.remove(o)
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)
    mesh.vertex_groups.clear()
    for m in list(mesh.modifiers):
        mesh.modifiers.remove(m)
    mesh.parent = None
    bpy.context.view_layer.objects.active = mesh
    for o in scene.objects:
        o.select_set(o == mesh)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if P["shift_y"]:
        # corpo no centro (os pés e o quadril ficam na origem, o rabo vai para trás)
        for vert in mesh.data.vertices:
            vert.co.y += P["shift_y"]
    # o cálculo de calor do Blender falha em modelos pequenos (1,1 m): faz tudo 10x maior e volta no fim
    mesh.scale = (K, K, K)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

    # esqueleto
    arm_data = bpy.data.armatures.new(P["rig"])
    rig = bpy.data.objects.new(P["rig"], arm_data)
    scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    for o in scene.objects:
        o.select_set(o == rig)
    bpy.ops.object.mode_set(mode="EDIT")
    for name, (head, tail, parent) in BONES.items():
        eb = arm_data.edit_bones.new(name)
        eb.head = Vector(head) * K
        eb.tail = Vector(tail) * K
        eb.use_deform = name != "Root"
    for name, (_, _, parent) in BONES.items():
        if parent:
            arm_data.edit_bones[name].parent = arm_data.edit_bones[parent]
            arm_data.edit_bones[name].use_connect = False
    # rolagem coerente (o eixo Z do osso aponta para a frente do personagem), ajuda o retarget
    bpy.ops.armature.select_all(action="SELECT")
    bpy.ops.armature.calculate_roll(type="GLOBAL_NEG_Y")
    bpy.ops.object.mode_set(mode="OBJECT")

    _weights(mesh, rig)

    mesh.parent = rig
    arm_mod = mesh.modifiers.new("Armature", "ARMATURE")
    arm_mod.object = rig

    # volta ao tamanho real e vira 180°: no Godot o modelo olha para +Z, como os personagens do KayKit
    # (a cena do herói desvira)
    rig.rotation_euler = (0, 0, math.pi)
    rig.scale = (1.0 / K, 1.0 / K, 1.0 / K)
    for o in scene.objects:
        o.select_set(o in (rig, mesh))
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)

    bpy.ops.wm.save_as_mainfile(filepath=ROOT + P["out_blend"])
    for o in scene.objects:
        o.select_set(o in (rig, mesh))
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(
        filepath=ROOT + P["out_glb"], export_format="GLB", use_selection=True,
        export_yup=True, export_apply=False, export_skins=True, export_animations=False, export_def_bones=False,
    )
    print("exportado")


main()
