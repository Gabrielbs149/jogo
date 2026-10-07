"""Copia os kits CC0 baixados (Quaternius + KayKit, D026) para assets/kits/, reduzindo texturas maiores que 2048.
Uso: python tools/art/instalar_kits.py C:/dev/_pacotes
Fontes (versões grátis):
  Quaternius Medieval Village / Fantasy Props / Stylized Nature MegaKit (opengameart.org, quaternius.com)
  KayKit Character Pack: Adventurers (github.com/KayKit-Game-Assets)
"""
import glob
import os
import shutil
import sys

from PIL import Image

SRC = sys.argv[1] if len(sys.argv) > 1 else "C:/dev/_pacotes"
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "kits")
MAX = 2048

KITS = {
    "quaternius/vila": [SRC + "/medieval_village_megakitstandard/glTF"],
    "quaternius/natureza": [SRC + "/stylized_nature_megakitstandard/glTF"],
    "quaternius/objetos": [SRC + "/fantasy_props_megakitstandard/Exports/glTF", SRC + "/fantasy_props_megakitstandard/Textures"],
    "kaykit/personagens": glob.glob(SRC + "/kaykit_adventurers/*/addons/kaykit_character_pack_adventures/Characters/gltf"),
}

for dest, sources in KITS.items():
    target = os.path.join(OUT, dest)
    os.makedirs(target, exist_ok=True)
    for src in sources:
        for f in os.listdir(src):
            path = os.path.join(src, f)
            if not os.path.isfile(path) or f.endswith(".import"):
                continue
            out = os.path.join(target, f)
            if f.lower().endswith(".png"):
                im = Image.open(path)
                if max(im.size) > MAX:
                    im = im.resize((min(im.size[0], MAX), min(im.size[1], MAX)), Image.LANCZOS)
                    im.save(out, optimize=True)
                    continue
            shutil.copyfile(path, out)
    size = sum(os.path.getsize(os.path.join(target, f)) for f in os.listdir(target))
    print("%-22s %4d arquivos  %.1f MB" % (dest, len(os.listdir(target)), size / 1e6))
