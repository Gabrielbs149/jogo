"""Prepara os modelos baixados do Poly Haven (CC0) para o jogo: junta as partes, simplifica o que
for pesado demais (Decimate), põe a base no chão e o centro no meio, e exporta .glb com as texturas.
Também grava o tamanho de cada um (medidas.json) para as colisões das peças.

Uso (Blender sem janela):
  blender -b -P tools/blender/gerado/preparar_polyhaven.py -- <pasta_baixada/models> <saida assets/models>
"""
import json
import os
import sys

import bpy

src, out = sys.argv[sys.argv.index("--") + 1:][:2]
os.makedirs(out, exist_ok=True)

# máximo de triângulos por modelo (o que passar é simplificado)
LIMITE = {
    "namaqualand_cliff_01": 30000, "namaqualand_boulders_01": 20000, "namaqualand_rocks_01": 16000,
    "namaqualand_stones_01": 12000, "quiver_tree_01": 40000, "quiver_tree_02": 30000,
    "othonna_cerarioides": 20000, "wild_rooibos_bush": 12000, "shrub_03": 12000, "shrub_04": 12000,
    "dead_quiver_trunk": 16000, "tree_stump_01": 10000,
}
PADRAO = 14000
medidas = {}

for nome in sorted(os.listdir(src)):
    gltf = os.path.join(src, nome, nome + ".gltf")
    if not os.path.exists(gltf):
        continue
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=gltf)
    malhas = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for o in bpy.context.scene.objects:
        o.select_set(o in malhas)
    bpy.context.view_layer.objects.active = malhas[0]
    if len(malhas) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    # tira o objeto de dentro de pais/vazios mantendo a posição, e aplica giro/escala
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for o in list(bpy.context.scene.objects):
        if o != obj:
            bpy.data.objects.remove(o)
    tris_antes = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    limite = LIMITE.get(nome, PADRAO)
    if tris_antes > limite:
        mod = obj.modifiers.new("Decimate", "DECIMATE")
        mod.ratio = limite / tris_antes
        mod.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=mod.name)
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    # base no chão, centro no meio (no Blender o "para cima" é Z)
    xs = [v.co.x for v in obj.data.vertices]
    ys = [v.co.y for v in obj.data.vertices]
    zs = [v.co.z for v in obj.data.vertices]
    cx, cy, z0 = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, min(zs)
    for v in obj.data.vertices:
        v.co.x -= cx
        v.co.y -= cy
        v.co.z -= z0
    obj.name = nome
    obj.data.name = nome
    bpy.ops.object.shade_smooth_by_angle() if tris > 20000 else None
    destino = os.path.join(out, nome + ".glb")
    bpy.ops.export_scene.gltf(filepath=destino, export_format="GLB", export_yup=True, export_apply=True,
                              export_image_format="AUTO", use_selection=False)
    # medidas no jeito do Godot: x = largura, y = altura, z = fundo
    medidas[nome] = {"x": round(max(xs) - min(xs), 3), "y": round(max(zs) - min(zs), 3), "z": round(max(ys) - min(ys), 3),
                     "tris": tris, "tris_original": tris_antes}
    print("%-26s %8d -> %6d tri   %.2f x %.2f x %.2f m" % (nome, tris_antes, tris, medidas[nome]["x"], medidas[nome]["y"], medidas[nome]["z"]))

json.dump(medidas, open(os.path.join(out, "medidas.json"), "w"), indent=1)
