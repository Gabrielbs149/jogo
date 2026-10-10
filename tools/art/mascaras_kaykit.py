"""Máscara da roupa dos bonecos do KayKit (D063): para cada textura (paleta de cores lisas), uma imagem preto e branco
com branco onde é pano (as cores que podem girar de matiz) e preto onde é pele, cabelo, couro, metal, olho e boca.
A roupa_tingida.gdshader usa a máscara: assim o tingimento nunca pinta rosto nem mão (antes o giro deixava rosto azul
e cabelo verde, porque a máscara era adivinhada no shader).

Regra (cores da paleta do KayKit): é pano quem é bem colorido (saturação >= 0,3, brilho >= 0,2) e NÃO é da família
laranja/marrom (matiz 0,02..0,11: pele, cabelo castanho, couro, madeira).
Uso: python tools/art/mascaras_kaykit.py   (SEM -I: precisa do Pillow)
"""
import colorsys
import glob
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))).replace("\\", "/") + "/"


def is_cloth(rgb):
    h, s, v = colorsys.rgb_to_hsv(*[c / 255.0 for c in rgb])
    if s < 0.3 or v < 0.2:
        return False
    return not (0.02 <= h <= 0.11)


for path in sorted(glob.glob(ROOT + "assets/kits/kaykit/personagens/*_texture.png")):
    if os.path.basename(path).count("_") < 2:
        continue  # só as texturas que o glb usa (Modelo_modelo_texture.png)
    img = Image.open(path).convert("RGB")
    cache = {}
    mask = Image.new("L", img.size)
    src = img.load()
    dst = mask.load()
    for y in range(img.size[1]):
        for x in range(img.size[0]):
            c = src[x, y]
            if c not in cache:
                cache[c] = 255 if is_cloth(c) else 0
            dst[x, y] = cache[c]
    out = path[:-4] + "_mascara.png"
    mask.save(out)
    print("ok", os.path.basename(out), sum(1 for v in cache.values() if v), "cores de pano de", len(cache))
