"""Passo 1: gera a FORMA 3D a partir do desenho pelo Space oficial tencent/Hunyuan3D-2.1 (Hugging Face, grátis).
Uso: python gerar_hunyuan.py desenho.png saida.glb
Sem conta só cabe a forma (/shape_generation); forma+textura (/generation_all) pede Hugging Face PRO.
A cota grátis de GPU é diária. Precisa: pip install gradio_client
"""
import shutil, sys
from gradio_client import Client, handle_file

img, out = sys.argv[1], sys.argv[2]
c = Client(sys.argv[3] if len(sys.argv) > 3 else "tencent/Hunyuan3D-2.1", verbose=False)
res = c.predict(
    image=handle_file(img),
    steps=30,
    guidance_scale=5.0,
    seed=1234,
    octree_resolution=256,
    check_box_rembg=True,
    num_chunks=8000,
    randomize_seed=False,
    api_name="/shape_generation",
)
shape = res[0]["value"] if isinstance(res[0], dict) else res[0]
shutil.copy(shape, out)
print("salvo", out)
