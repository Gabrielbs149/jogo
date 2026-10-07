"""Prepara o modelo do Naumfode (D032) que o Gabriel mandou (art_src/naumfode_original.glb, já com esqueleto e
7 animações): tira a esfera solta que veio junto e exporta actors/naumfode/naumfode.glb (com as animações).
Uso: blender -b --factory-startup -P tools/blender/gerado/preparar_naumfode.py -- C:/dev/jogo
"""
import sys

import bpy

ROOT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "C:/dev/jogo"
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=ROOT + "/art_src/naumfode_original.glb")
for o in list(bpy.context.scene.objects):
    if o.type == "MESH" and o.parent is None:
        print("removido:", o.name)
        bpy.data.objects.remove(o)
# o material veio com emissão ciano constante (força 1) no corpo inteiro: cobria a textura toda
for mat in bpy.data.materials:
    if mat.node_tree:
        for n in mat.node_tree.nodes:
            if n.type == "BSDF_PRINCIPLED":
                n.inputs["Emission Strength"].default_value = 0.0
                n.inputs["Emission Color"].default_value = (0, 0, 0, 1)
                print("emissão desligada:", mat.name)
for o in bpy.context.scene.objects:
    o.select_set(True)
bpy.ops.wm.save_as_mainfile(filepath=ROOT + "/art_src/naumfode.blend")
bpy.ops.export_scene.gltf(filepath=ROOT + "/actors/naumfode/naumfode.glb", export_format="GLB", use_selection=True,
                          export_yup=True, export_animations=True, export_animation_mode="ACTIONS")
print("exportado")
