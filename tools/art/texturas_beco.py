"""Texturas do canto do Tico e da Tika no beco (D062): lona remendada, colcha de retalhos, saco de palha, papelão da
caixa de sabão, panos do varal, chão do beco, manchas de umidade e o desenho de giz. Tudo pintado aqui com ruído (sem
foto), no mesmo jeito "pintado à mão" das texturas do Quaternius. Repetível: a mesma semente dá a mesma imagem.

Uso: python tools/art/texturas_beco.py   (SEM -I: precisa do numpy e do Pillow)
Saída: assets/beco/tex/*.png (o modelar_beco.py do Blender e o montar_beco.gd usam).
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))).replace("\\", "/") + "/"
OUT = ROOT + "assets/beco/tex/"
FONT = ROOT + "assets/fonts/cinzel.ttf"
os.makedirs(OUT, exist_ok=True)


# --------------------------------------------------------------------------------------------- ruído

def noise(size, scale, seed, octaves=4):
    """Ruído suave (value noise com várias oitavas), 0..1, que repete nas bordas."""
    rng = np.random.default_rng(seed)
    h, w = size if isinstance(size, tuple) else (size, size)
    out = np.zeros((h, w))
    amp, total = 1.0, 0.0
    for o in range(octaves):
        cells = max(2, int(scale * (2 ** o)))
        grid = rng.random((cells, cells))
        ys = np.linspace(0, cells, h, endpoint=False)
        xs = np.linspace(0, cells, w, endpoint=False)
        y0 = np.floor(ys).astype(int)
        x0 = np.floor(xs).astype(int)
        fy = ys - y0
        fx = xs - x0
        fy = fy * fy * (3 - 2 * fy)
        fx = fx * fx * (3 - 2 * fx)
        y1 = (y0 + 1) % cells
        x1 = (x0 + 1) % cells
        a = grid[np.ix_(y0 % cells, x0 % cells)]
        b = grid[np.ix_(y0 % cells, x1)]
        c = grid[np.ix_(y1, x0 % cells)]
        d = grid[np.ix_(y1, x1)]
        top = a + (b - a) * fx[None, :]
        bot = c + (d - c) * fx[None, :]
        out += (top + (bot - top) * fy[:, None]) * amp
        total += amp
        amp *= 0.5
    return out / total


def weave(size, period, strength=0.12):
    """Trama de tecido: fios cruzados (um sobe, outro desce)."""
    h, w = size if isinstance(size, tuple) else (size, size)
    y, x = np.mgrid[0:h, 0:w]
    a = np.sin(x * 2 * math.pi / period)
    b = np.sin(y * 2 * math.pi / period)
    checker = np.sign(np.sin(x * math.pi / period) * np.sin(y * math.pi / period))
    return 1.0 + strength * (0.5 * a * (checker > 0) + 0.5 * b * (checker < 0))


def to_img(rgb):
    return Image.fromarray(np.clip(rgb * 255, 0, 255).astype(np.uint8))


def tint(base, n, amount):
    return base[None, None, :] * (1.0 + (n[..., None] - 0.5) * amount)


def col(hexstr):
    hexstr = hexstr.lstrip("#")
    return np.array([int(hexstr[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


# --------------------------------------------------------------------------------------------- tecidos

FABRICS = {
    # nome: (cor, padrão)
    "vermelho": ("#9a4436", "liso"), "azul": ("#4c6480", "liso"), "mostarda": ("#b48a3c", "liso"),
    "verde": ("#5f7347", "liso"), "vinho": ("#6e3341", "liso"), "cru": ("#c9b48e", "liso"),
    "xadrez_azul": ("#4b5f7d", "xadrez"), "xadrez_verm": ("#94463a", "xadrez"), "listra": ("#7d6a4d", "listra"),
    "bolinha": ("#7a4f62", "bolinha"), "juta": ("#8d6f47", "juta"), "lilas": ("#7c6595", "liso"),
}


def fabric(size, name, seed):
    """Um pedaço de pano (cor + padrão + trama + desbotado)."""
    hexc, kind = FABRICS[name]
    base = col(hexc)
    n = noise(size, 3, seed)
    img = tint(base, n, 0.35)
    h, w = size if isinstance(size, tuple) else (size, size)
    y, x = np.mgrid[0:h, 0:w]
    if kind == "xadrez":
        p = max(16, w // 6)
        band = ((x // (p // 2)) % 2 == 0).astype(float) * 0.5 + ((y // (p // 2)) % 2 == 0).astype(float) * 0.5
        light = col("#d9cdb0")
        img = img * (1 - 0.35 * band[..., None]) + light[None, None, :] * 0.35 * band[..., None]
        thin = ((x % p) < 2) | ((y % p) < 2)
        img[thin] = img[thin] * 0.6
    elif kind == "listra":
        p = max(12, w // 9)
        stripe = ((x // p) % 2 == 0)
        img[stripe] = img[stripe] * 0.7 + col("#d1b98a") * 0.3
    elif kind == "bolinha":
        p = max(14, w // 8)
        cx = (x % p) - p / 2
        cy = ((y + (x // p % 2) * p // 2) % p) - p / 2
        dot = cx * cx + cy * cy < (p * 0.16) ** 2
        img[dot] = col("#e2d6bd")
    elif kind == "juta":
        img = img * weave(size, 7, 0.28)[..., None]
    img = img * weave(size, 4, 0.07)[..., None]
    fade = noise(size, 2, seed + 7)
    img = img * (1 - 0.25 * fade[..., None]) + col("#cbbd9f")[None, None, :] * 0.25 * fade[..., None]
    return img


def stitches(draw, points, color, dash=9, gap=6, width=3):
    """Pesponto tracejado ao longo de uma linha (costura à mão)."""
    for (x0, y0), (x1, y1) in zip(points, points[1:]):
        length = math.hypot(x1 - x0, y1 - y0)
        steps = int(length // (dash + gap)) + 1
        for i in range(steps):
            t0 = i * (dash + gap) / max(length, 1)
            t1 = min(1.0, t0 + dash / max(length, 1))
            if t0 >= 1:
                break
            draw.line([(x0 + (x1 - x0) * t0, y0 + (y1 - y0) * t0), (x0 + (x1 - x0) * t1, y0 + (y1 - y0) * t1)],
                      fill=color, width=width)


def stains(img, seed, count, dark=0.75, size=0.18):
    """Manchas d'água/sujeira: borrões mais escuros com borda marcada."""
    h, w = img.shape[:2]
    rng = np.random.default_rng(seed)
    y, x = np.mgrid[0:h, 0:w]
    n = noise((h, w), 6, seed + 3)
    for _ in range(count):
        cx, cy = rng.random() * w, rng.random() * h
        r = (0.4 + rng.random()) * size * w
        d = np.hypot(x - cx, y - cy) / r + (n - 0.5) * 0.35
        inside = np.clip(1 - d, 0, 1) ** 0.7
        rim = np.exp(-((d - 1.0) ** 2) / 0.004) * 0.5
        img = img * (1 - (1 - dark) * np.clip(inside * 1.5, 0, 1)[..., None] * 0.6) * (1 - 0.15 * rim[..., None])
    return img


# --------------------------------------------------------------------------------------------- texturas

def lona():
    """Lona do barraco: lona crua velha, cheia de remendos costurados, manchas de chuva e fuligem na beira da frente
    (v alto = beira da frente, perto do fogo)."""
    S = 1024
    rng = np.random.default_rng(11)
    base = col("#a89676")
    img = tint(base, noise(S, 2, 1, 5), 0.22) * weave(S, 5, 0.10)[..., None]
    pil = to_img(img)
    d = ImageDraw.Draw(pil)
    names = ["juta", "azul", "vermelho", "xadrez_verm", "verde", "cru", "mostarda", "listra", "juta", "xadrez_azul"]
    for i, name in enumerate(names):
        pw, ph = int(rng.integers(130, 300)), int(rng.integers(110, 260))
        px, py = int(rng.integers(0, S - pw)), int(rng.integers(0, S - ph))
        patch = to_img(fabric((ph, pw), name, 100 + i))
        mask = Image.new("L", (pw, ph), 0)
        md = ImageDraw.Draw(mask)
        jitter = [(int(rng.integers(0, 10)), int(rng.integers(0, 10))) for _ in range(4)]
        md.polygon([(jitter[0][0], jitter[0][1]), (pw - jitter[1][0], jitter[1][1]),
                    (pw - jitter[2][0], ph - jitter[2][1]), (jitter[3][0], ph - jitter[3][1])], fill=255)
        pil.paste(patch, (px, py), mask)
        corners = [(px + jitter[0][0] + 6, py + jitter[0][1] + 6), (px + pw - jitter[1][0] - 6, py + jitter[1][1] + 6),
                   (px + pw - jitter[2][0] - 6, py + ph - jitter[2][1] - 6), (px + jitter[3][0] + 6, py + ph - jitter[3][1] - 6)]
        stitches(d, corners + [corners[0]], (58, 44, 30), dash=10, gap=7, width=3)
    img = np.asarray(pil).astype(float) / 255.0
    img = stains(img, 5, 4, dark=0.85, size=0.12)
    # fuligem do fogo na beira da frente (v alto) e escorrido de chuva
    h = np.linspace(0, 1, S)[:, None]
    soot = np.clip((h - 0.72) / 0.28, 0, 1) ** 1.6 * (0.6 + 0.4 * noise(S, 5, 9))
    img = img * (1 - 0.55 * soot[..., None])
    # escorrido de chuva: riscos de cima para baixo, mais fortes perto da beira da frente
    rows = np.linspace(0, 1, S)[:, None]
    cols = noise((8, S), 60, 12, 2)[0][None, :]
    streak = np.clip((cols - 0.55) * 4, 0, 1) * rows
    img = img * (1 - 0.18 * streak[..., None])
    to_img(img).save(OUT + "lona.png")


def colcha():
    """Colcha de retalhos: quadrados de pano diferentes costurados, gasta."""
    S = 1024
    rng = np.random.default_rng(21)
    pil = Image.new("RGB", (S, S))
    d = ImageDraw.Draw(pil)
    names = list(FABRICS.keys())
    n = 5
    cell = S // n
    for gy in range(n):
        for gx in range(n):
            name = names[int(rng.integers(0, len(names)))]
            patch = to_img(fabric((cell, cell), name, 300 + gy * n + gx))
            pil.paste(patch, (gx * cell, gy * cell))
    for k in range(1, n):
        stitches(d, [(k * cell, 0), (k * cell, S)], (232, 220, 190), dash=8, gap=6, width=3)
        stitches(d, [(0, k * cell), (S, k * cell)], (232, 220, 190), dash=8, gap=6, width=3)
    # um remendo por cima de um furo
    stitches(d, [(cell * 2 + 30, cell + 40), (cell * 3 - 20, cell + 40), (cell * 3 - 20, cell * 2 - 30),
                 (cell * 2 + 30, cell * 2 - 30), (cell * 2 + 30, cell + 40)], (60, 40, 30), dash=7, gap=5, width=3)
    img = np.asarray(pil).astype(float) / 255.0
    img = stains(img, 22, 4, dark=0.8, size=0.15)
    edge = np.zeros((S, S))
    edge[:10, :] = edge[-10:, :] = edge[:, :10] = edge[:, -10:] = 1
    img = img * (1 - 0.3 * edge[..., None])
    to_img(img).save(OUT + "colcha.png")


def saco():
    """Saco de juta (o colchão de palha e o travesseiro): trama grossa e costura."""
    S = 512
    img = fabric(S, "juta", 40)
    img = img * (0.85 + 0.15 * noise(S, 8, 41))[..., None]
    pil = to_img(img)
    d = ImageDraw.Draw(pil)
    stitches(d, [(0, 20), (S, 20)], (70, 50, 30), dash=12, gap=8, width=4)
    stitches(d, [(0, S - 20), (S, S - 20)], (70, 50, 30), dash=12, gap=8, width=4)
    # carimbo apagado de saco de farinha
    try:
        font = ImageFont.truetype(FONT, 54)
        layer = Image.new("L", (S, S), 0)
        ImageDraw.Draw(layer).text((S // 2, S // 2), "FARINHA", font=font, fill=110, anchor="mm")
        layer = layer.filter(ImageFilter.GaussianBlur(1.2))
        ink = Image.new("RGB", (S, S), (70, 62, 80))
        pil = Image.composite(ink, pil, layer.point(lambda v: int(v * 0.55)))
    except OSError:
        pass
    pil.save(OUT + "saco.png")


def palha():
    """Palha solta (o recheio que escapa do colchão, o chão do canto)."""
    S = 512
    rng = np.random.default_rng(51)
    pil = to_img(tint(col("#a68a4f"), noise(S, 6, 50), 0.4))
    d = ImageDraw.Draw(pil)
    for _ in range(900):
        x, y = rng.random() * S, rng.random() * S
        a = rng.random() * math.pi
        L = 20 + rng.random() * 50
        c = tuple(int(v) for v in (col("#d8bd73") * (0.7 + 0.4 * rng.random()) * 255))
        d.line([(x, y), (x + math.cos(a) * L, y + math.sin(a) * L)], fill=c, width=int(1 + rng.random() * 3))
    pil.save(OUT + "palha.png")


def papelao():
    """O papelão da caixa de sabão: ondinhas do papelão, fita, carimbo de sabão apagado, manchas e beirada rasgada.
    Metade de cima = face; faixa de baixo (v > 0,86) = a beirada com as ondas aparecendo."""
    S = 1024
    base = col("#b48d5c")
    img = tint(base, noise(S, 3, 60), 0.3)
    x = np.arange(S)[None, :]
    img = img * (1 + 0.04 * np.sin(x * 2 * math.pi / 18))[..., None]
    img = stains(img, 61, 7, dark=0.72, size=0.16)
    pil = to_img(img)
    d = ImageDraw.Draw(pil)
    try:
        font = ImageFont.truetype(FONT, 120)
        small = ImageFont.truetype(FONT, 46)
        layer = Image.new("L", (S, S), 0)
        ld = ImageDraw.Draw(layer)
        ld.text((S // 2, 330), "SABÃO", font=font, fill=255, anchor="mm")
        ld.text((S // 2, 430), "de cinza e sebo", font=small, fill=255, anchor="mm")
        # a barra de sabão com bolhas
        ld.rounded_rectangle((S // 2 - 150, 500, S // 2 + 150, 640), radius=30, outline=255, width=12)
        for bx, by, br in ((S // 2 + 170, 480, 24), (S // 2 + 215, 440, 16), (S // 2 + 200, 395, 10)):
            ld.ellipse((bx - br, by - br, bx + br, by + br), outline=255, width=7)
        wear = (noise(S, 10, 62) > 0.42).astype(np.uint8) * 255
        layer = Image.fromarray(np.minimum(np.asarray(layer), wear)).filter(ImageFilter.GaussianBlur(1.0))
        ink = Image.new("RGB", (S, S), (48, 72, 112))
        pil = Image.composite(ink, pil, layer.point(lambda v: int(v * 0.6)))
    except OSError:
        pass
    d = ImageDraw.Draw(pil)
    # fita velha
    d.rectangle((0, 80, S, 150), fill=(196, 170, 120))
    d.rectangle((0, 80, S, 86), fill=(160, 134, 90))
    # vinco onde a caixa foi dobrada
    d.line([(S * 0.62, 0), (S * 0.62, S * 0.86)], fill=(120, 92, 58), width=6)
    # a beirada: as ondinhas
    top = int(S * 0.86)
    d.rectangle((0, top, S, S), fill=(150, 118, 76))
    for i in range(0, S, 22):
        d.arc((i, top + 20, i + 22, top + 80), 180, 360, fill=(95, 70, 44), width=5)
        d.arc((i + 11, top + 48, i + 33, top + 108), 0, 180, fill=(95, 70, 44), width=5)
    pil.save(OUT + "papelao.png")


def panos():
    """Os panos do varal: quatro pedaços de roupa lado a lado (u = 0..0,25, 0,25..0,5...)."""
    S = 512
    pil = Image.new("RGB", (S * 4, S))
    for i, name in enumerate(["xadrez_azul", "cru", "lilas", "mostarda"]):
        img = fabric(S, name, 500 + i)
        img = stains(img, 510 + i, 2, dark=0.85, size=0.2)
        pil.paste(to_img(img), (i * S, 0))
    d = ImageDraw.Draw(pil)
    for i in range(4):
        stitches(d, [(i * S + 18, 18), (i * S + S - 18, 18), (i * S + S - 18, S - 18), (i * S + 18, S - 18), (i * S + 18, 18)],
                 (60, 45, 35), dash=8, gap=6, width=3)
    pil.save(OUT + "panos.png")


def chao():
    """Chão do beco (RGBA): terra batida escura e úmida perto das paredes, palha espalhada, pedrinhas, folhas, uma poça.
    u = ao comprido do beco (u = 0 no fundo, u = 1 na boca, onde some aos poucos), v = de uma parede à outra."""
    W, H = 2048, 1600
    rng = np.random.default_rng(71)
    n = noise((H, W), 6, 70)
    big = noise((H, W), 2, 75, 3)
    img = tint(col("#55412c"), n, 0.6) * (0.75 + 0.5 * big)[..., None]
    y = np.linspace(0, 1, H)[:, None]
    x = np.linspace(0, 1, W)[None, :]
    wall = np.clip(1 - np.minimum(y, 1 - y) / 0.16, 0, 1) ** 2
    img = img * (1 - 0.35 * wall[..., None])
    img = img * (0.85 + 0.3 * noise((H, W), 24, 72, 3))[..., None]
    pil = to_img(img)
    d = ImageDraw.Draw(pil)
    # pedras chatas fincadas na terra (restos de um calçamento velho)
    for _ in range(90):
        px, py = rng.random() * W, rng.random() * H
        r = 10 + rng.random() * 22
        g = int(62 + rng.random() * 30)
        pts = [(px + math.cos(a) * r * (0.7 + 0.3 * rng.random()), py + math.sin(a) * r * 0.75 * (0.7 + 0.3 * rng.random()))
               for a in np.linspace(0, 2 * math.pi, 9)[:-1]]
        d.polygon(pts, fill=(g, g - 4, g - 10))
        d.line(pts[:4], fill=(g + 22, g + 18, g + 10), width=2)
    # pedrinhas
    for _ in range(260):
        px, py = rng.random() * W, rng.random() * H
        r = 2 + rng.random() * 4
        g = int(70 + rng.random() * 40)
        d.ellipse((px - r, py - r * 0.7, px + r, py + r * 0.7), fill=(g, g - 8, g - 16))
    # palha espalhada (mais no fundo, onde eles dormem)
    for _ in range(1800):
        # mais palha perto da cama (u 0,15..0,4 e v 0,25..0,55) e no fundo
        if rng.random() < 0.6:
            px = (0.12 + rng.random() * 0.3) * W
            py = (0.22 + rng.random() * 0.36) * H
        else:
            px = (rng.random() ** 2.2) * W
            py = rng.random() * H
        a = rng.random() * math.pi
        L = 8 + rng.random() * 22
        c = tuple(int(v) for v in (col("#a88d52") * (0.55 + 0.35 * rng.random()) * 255))
        d.line([(px, py), (px + math.cos(a) * L, py + math.sin(a) * L)], fill=c, width=1)
    # folhas secas
    for _ in range(70):
        px, py = rng.random() * W, rng.random() * H
        a = rng.random() * 360
        leaf = Image.new("RGBA", (40, 24), (0, 0, 0, 0))
        ImageDraw.Draw(leaf).ellipse((6, 7, 30, 17), fill=tuple(int(v) for v in col(["#5f4626", "#6b5228", "#4a3b22"][int(rng.integers(0, 3))]) * 255) + (255,))
        leaf = leaf.rotate(a, expand=True)
        pil.paste(leaf, (int(px), int(py)), leaf)
    img = np.asarray(pil).astype(float) / 255.0
    # a poça perto da boca
    yy, xx = np.mgrid[0:H, 0:W]
    pd = np.hypot((xx - W * 0.78) / 150, (yy - H * 0.3) / 70) + (noise((H, W), 8, 73) - 0.5) * 0.5
    puddle = np.clip((1 - pd) * 4, 0, 1)
    img = img * (1 - 0.45 * puddle[..., None]) + col("#5b6b78")[None, None, :] * 0.25 * puddle[..., None]
    # some na boca do beco (u > 0,8) e um pouquinho nas paredes (para não ter beirada reta)
    fade = np.clip((1 - x) / 0.22, 0, 1) * np.clip(np.minimum(y, 1 - y) / 0.03, 0, 1)
    fade = fade * (0.75 + 0.25 * noise((H, W), 10, 74)) + 0 * y
    alpha = np.clip(fade * 1.15, 0, 1)
    rgba = np.dstack([img, alpha])
    Image.fromarray(np.clip(rgba * 255, 0, 255).astype(np.uint8), "RGBA").save(OUT + "chao.png")
    # e o mapa de brilho: só a poça brilha (rugosidade baixa)
    rough = np.clip(0.95 - 0.75 * puddle, 0, 1)
    Image.fromarray((rough * 255).astype(np.uint8), "L").save(OUT + "chao_rugosidade.png")


def umidade():
    """Mancha de umidade e limo no pé da parede (RGBA, decal)."""
    W, H = 1024, 512
    n = noise((H, W), 5, 80)
    y = np.linspace(0, 1, H)[:, None]  # linha de baixo = pé da parede
    edge = np.clip((0.55 + (n - 0.5) * 0.6) - (1 - y), 0, 1)
    alpha = np.clip(edge * 2.2, 0, 0.8) * (0.7 + 0.3 * noise((H, W), 14, 81))
    rgb = tint(col("#2f3a24"), noise((H, W), 12, 82), 0.6)
    moss = noise((H, W), 20, 83) > 0.6
    rgb[moss] = rgb[moss] * 0.6 + col("#4f6b2c") * 0.4
    side = np.clip(np.minimum(np.linspace(0, 1, W), np.linspace(1, 0, W)) / 0.12, 0, 1)[None, :]
    alpha = alpha * side
    Image.fromarray(np.clip(np.dstack([rgb, alpha]) * 255, 0, 255).astype(np.uint8), "RGBA").save(OUT + "umidade.png")


def giz():
    """Desenho de giz na parede do fundo (proposta, D062): os dois de mãos dadas, um sol e uma casinha com fumaça,
    em giz branco, verde e roxo. Riscado de criança (RGBA)."""
    S = 1024
    rng = np.random.default_rng(91)
    layer = Image.new("RGBA", (S, S // 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)

    def chalk(points, color, width=9, wobble=3.0, passes=2):
        for p in range(passes):
            pts = [(x + rng.normal(0, wobble), y + rng.normal(0, wobble)) for x, y in points]
            d.line(pts, fill=color, width=width, joint="curve")

    def circle(cx, cy, r, color, width=9):
        pts = [(cx + math.cos(a) * r, cy + math.sin(a) * r) for a in np.linspace(0, 2 * math.pi, 28)]
        chalk(pts, color, width)

    white = (235, 232, 222, 235)
    green = (120, 200, 160, 235)
    purple = (190, 140, 230, 235)
    yellow = (245, 215, 110, 235)
    # sol
    circle(130, 120, 52, yellow)
    for k in range(9):
        a = k * 2 * math.pi / 9
        chalk([(130 + math.cos(a) * 70, 120 + math.sin(a) * 70), (130 + math.cos(a) * 100, 120 + math.sin(a) * 100)], yellow, 8)
    # Tico (verde) e Tika (roxa): cabeça de lagartinho, rabo, mãos dadas
    for cx, color, tail in ((420, green, -1), (560, purple, 1)):
        circle(cx, 200, 42, color)
        chalk([(cx - 20, 190), (cx - 60, 170), (cx - 30, 160)], color, 7) if tail < 0 else chalk([(cx + 20, 190), (cx + 60, 170), (cx + 30, 160)], color, 7)
        chalk([(cx, 242), (cx, 360)], color)
        chalk([(cx, 360), (cx - 34, 440)], color)
        chalk([(cx, 360), (cx + 34, 440)], color)
        chalk([(cx, 360), (cx + tail * 70, 400), (cx + tail * 95, 380)], color, 8)
        d.ellipse((cx - 16, 188, cx - 6, 198), fill=white)
        d.ellipse((cx + 6, 188, cx + 16, 198), fill=white)
    chalk([(420, 290), (490, 310), (560, 290)], white, 8)
    chalk([(420, 290), (360, 320)], green, 8)
    chalk([(560, 290), (620, 320)], purple, 8)
    # casinha com fumaça
    chalk([(760, 440), (760, 300), (900, 300), (900, 440), (760, 440)], white)
    chalk([(745, 305), (830, 225), (915, 305)], white)
    chalk([(810, 440), (810, 380), (850, 380), (850, 440)], white, 7)
    chalk([(870, 260), (870, 225), (890, 225), (890, 280)], white, 7)
    chalk([(880, 210), (900, 180), (870, 150), (895, 115)], white, 6, passes=1)
    # um coraçãozinho torto
    heart = [(490, 160)] + [(490 + 16 * math.sin(t) ** 3 * 1.6, 160 - (13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t)) * 1.6)
                            for t in np.linspace(0, 2 * math.pi, 30)]
    chalk(heart, (240, 120, 140, 230), 7)
    arr = np.asarray(layer).astype(float)
    grain = noise((S // 2, S), 60, 92, 2)
    arr[..., 3] *= np.clip(0.45 + 0.8 * grain, 0, 1)
    Image.fromarray(arr.astype(np.uint8), "RGBA").filter(ImageFilter.GaussianBlur(0.8)).save(OUT + "giz.png")


def madeira():
    """Galho/vara descascada (estacas, travessas, lenha): veio ao comprido (v), nós escuros."""
    S = 512
    rng = np.random.default_rng(101)
    x = np.arange(S)[None, :]
    grain = noise((8, S), 50, 100, 3)[0][None, :]
    img = tint(col("#7a5c3e"), np.repeat(grain, S, axis=0), 0.6)
    img = img * (0.9 + 0.2 * noise(S, 6, 102))[..., None]
    pil = to_img(img)
    d = ImageDraw.Draw(pil)
    for _ in range(9):
        cx, cy = rng.random() * S, rng.random() * S
        d.ellipse((cx - 10, cy - 16, cx + 10, cy + 16), fill=(70, 48, 30))
        d.ellipse((cx - 5, cy - 8, cx + 5, cy + 8), fill=(50, 34, 22))
    pil.save(OUT + "madeira.png")


def corda():
    """Corda de sisal: fios torcidos na diagonal."""
    S = 256
    y, x = np.mgrid[0:S, 0:S]
    twist = 0.5 + 0.5 * np.sin((x + y) * 2 * math.pi / 32)
    img = tint(col("#a88d5c"), twist * 0.7 + 0.3 * noise(S, 10, 110), 0.7)
    to_img(img).save(OUT + "corda.png")


def cinza():
    """Cinza da fogueira (o centro da roda de pedras): cinza clara com carvão e brasa apagada."""
    S = 512
    n = noise(S, 8, 120)
    img = tint(col("#6e6a66"), n, 0.6)
    y, x = np.mgrid[0:S, 0:S]
    r = np.hypot(x - S / 2, y - S / 2) / (S / 2)
    img = img * (0.55 + 0.45 * np.clip(r, 0, 1))[..., None]
    coal = noise(S, 20, 121) > 0.64
    img[coal & (r < 0.7)] = col("#1c1a19")
    to_img(img).save(OUT + "cinza.png")


if __name__ == "__main__":
    for f in (lona, colcha, saco, palha, papelao, panos, chao, umidade, giz, madeira, corda, cinza):
        f()
        print("ok", f.__name__)
