r"""Passo 1b: máscara da silhueta do desenho (traço escuro define a caixa) -> art_src/ref/ref_mask.npy.
Uso: python mascara.py C:\dev\jogo\art_src\ref\tico_ref.png   (precisa: pip install pillow numpy)
"""
import os, sys
import numpy as np
from PIL import Image

im = np.asarray(Image.open(sys.argv[1]).convert("RGB")).astype(float)
lum = im.mean(axis=2)
dark_y = np.nonzero((lum < 70).any(axis=1))[0]
mask = lum < 232
mask[:dark_y.min()] = False
mask[dark_y.max() + 1:] = False
np.save(os.path.join(os.path.dirname(sys.argv[1]), "ref_mask.npy"), mask)
print("máscara:", mask.sum(), "px")
