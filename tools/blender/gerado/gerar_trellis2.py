"""Passo 1: gera o modelo 3D JÁ PINTADO a partir do desenho pelo Space microsoft/TRELLIS.2 (Hugging Face, grátis).
Uso: python gerar_trellis2.py art_src/ref/<nome>_ref.png art_src/<nome>_trellis_bruto.glb
Precisa: pip install gradio_client e login no Hugging Face (python -c "from huggingface_hub import login; login()")
ou HF_TOKEN no ambiente. Sem conta a cota de GPU acaba rápido. Depois: limpar_trellis.py.
"""
import os, shutil, sys
from gradio_client import Client, handle_file

img, out = sys.argv[1], sys.argv[2]
c = Client("microsoft/TRELLIS.2", token=os.environ.get("HF_TOKEN") or None, verbose=False)
c.predict(api_name="/start_session")
pre = c.predict(input=handle_file(img), api_name="/preprocess_image")
pre_path = pre["path"] if isinstance(pre, dict) else pre
print("pre", pre_path)
r = c.predict(image=handle_file(pre_path), seed=0, resolution="1024",
              ss_guidance_strength=7.5, ss_guidance_rescale=0.7, ss_sampling_steps=12, ss_rescale_t=5.0,
              shape_slat_guidance_strength=7.5, shape_slat_guidance_rescale=0.5, shape_slat_sampling_steps=12, shape_slat_rescale_t=3.0,
              tex_slat_guidance_strength=1.0, tex_slat_guidance_rescale=0.0, tex_slat_sampling_steps=12, tex_slat_rescale_t=3.0,
              api_name="/image_to_3d")
print("3d ok")
g = c.predict(decimation_target=100000, texture_size=2048, api_name="/extract_glb")
glb = g[1] if isinstance(g, (list, tuple)) else g
glb = glb["path"] if isinstance(glb, dict) else glb
shutil.copy(glb, out)
print("salvo", out)
