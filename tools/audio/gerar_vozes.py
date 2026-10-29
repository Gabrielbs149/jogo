"""Gera as vozes das falas (D090) sem baixar nada: só numpy. Não é fala de verdade, é o "balbucio" que acompanha
o texto aparecendo (cada sílaba um somzinho com a vogal da palavra), e o tom de cada personagem vem do jogo
(systems/audio/voz.gd), que toca estes arquivos mais agudos ou mais graves.

Uso: python tools/audio/gerar_vozes.py
Escreve em assets/audio/sfx/:
  voz_<timbre>_<vogal>_<n>.wav    timbre: grave, media, suave; vogal: a, e, i, o, u; n: 0 (só a vogal), 1 ("t/k"
                                  antes, seca), 2 ("m/n" antes, macia)
Tudo é sorteado com semente fixa: rodar de novo dá os mesmos arquivos.
"""
import os
import wave

import numpy as np

RATE = 22050
ROOT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio", "sfx")
rng = np.random.default_rng(90)

# formantes (Hz) e larguras de cada vogal, de uma voz adulta média
VOGAIS = {
    "a": [(730, 90), (1090, 110), (2440, 160)],
    "e": [(530, 70), (1840, 100), (2480, 150)],
    "i": [(300, 50), (2250, 110), (3000, 170)],
    "o": [(570, 70), (840, 80), (2410, 160)],
    "u": [(320, 50), (870, 80), (2240, 150)],
}
# timbre: f0 (Hz), escala dos formantes, sopro, queda dos harmônicos, aspereza (vocal fry), duração (s)
TIMBRES = {
    "grave": dict(f0=108.0, formantes=0.9, sopro=0.05, queda=1.15, aspereza=0.3, dur=0.105),
    "media": dict(f0=150.0, formantes=1.0, sopro=0.06, queda=1.25, aspereza=0.0, dur=0.09),
    "suave": dict(f0=228.0, formantes=1.16, sopro=0.2, queda=1.6, aspereza=0.0, dur=0.08),
}


def save(rel, x, peak_db=-3.0):
    x = np.asarray(x, dtype=np.float64)
    peak = np.max(np.abs(x)) or 1.0
    x = x / peak * (10 ** (peak_db / 20.0))
    data = (np.clip(x, -1, 1) * 32767).astype("<i2")
    path = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())


def shape(x, gain):
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1.0 / RATE)
    return np.fft.irfft(spec * gain(f), len(x))


def band(f, center, width):
    return np.exp(-0.5 * ((f - center) / width) ** 2)


def fonte(n, f0, queda, aspereza):
    """Pregas vocais: harmônicos de f0 caindo com a frequência, o tom descendo um pouco no fim da sílaba."""
    t = np.arange(n) / RATE
    contorno = f0 * np.linspace(1.04, 0.95, n) * (1.0 + 0.012 * np.sin(2 * np.pi * 5.5 * t))
    contorno *= 1.0 + 0.006 * rng.standard_normal(n).cumsum() / np.sqrt(np.arange(1, n + 1))
    fase = 2 * np.pi * np.cumsum(contorno) / RATE
    x = np.zeros(n)
    k = 1
    while k * f0 < 5000:
        x += np.sin(k * fase) / k ** queda
        k += 1
    if aspereza > 0:
        x *= 1.0 - aspereza * (0.5 + 0.5 * np.sign(np.sin(fase / 2)))  # um pulso sim, outro mais fraco
    return x


def silaba(timbre, vogal, onset):
    p = TIMBRES[timbre]
    dur = p["dur"] * rng.uniform(0.94, 1.06)
    n = int(dur * RATE)
    x = fonte(n, p["f0"], p["queda"], p["aspereza"])
    x += p["sopro"] * rng.standard_normal(n)
    forms = [(c * p["formantes"], w * p["formantes"]) for c, w in VOGAIS[vogal]]
    x = shape(x, lambda f: sum(band(f, c, w) * a for (c, w), a in zip(forms, (1.0, 0.7, 0.35))) + 0.02)
    # envelope: entra rápido, segura, sai em cosseno
    env = np.ones(n)
    ataque = int((0.016 if onset == 2 else 0.006) * RATE)
    saida = int(0.035 * RATE)
    env[:ataque] = np.linspace(0, 1, ataque)
    env[-saida:] = 0.5 + 0.5 * np.cos(np.linspace(0, np.pi, saida))
    x *= env
    if onset == 1:
        # "t/k": um estalo de ruído agudo antes da vogal
        m = int(0.012 * RATE)
        burst = shape(rng.standard_normal(m), lambda f: band(f, 3200 * p["formantes"], 900))
        burst *= np.linspace(1, 0, m) ** 2
        x = np.concatenate([burst * 0.6 * np.max(np.abs(x)) / (np.max(np.abs(burst)) or 1), x])
    elif onset == 2:
        # "m/n": um zumbido grave de boca fechada entrando na vogal
        m = int(0.03 * RATE)
        hum = shape(fonte(m, p["f0"], 2.0, p["aspereza"]), lambda f: band(f, 280, 120))
        hum *= np.linspace(0.2, 0.8, m)
        x = np.concatenate([hum * np.max(np.abs(x)) / (np.max(np.abs(hum)) or 1) * 0.5, x])
    return x


if __name__ == "__main__":
    for timbre in TIMBRES:
        for vogal in VOGAIS:
            for onset in range(3):
                save(f"voz_{timbre}_{vogal}_{onset}.wav", silaba(timbre, vogal, onset), -4.0)
    print("vozes:", len(TIMBRES) * len(VOGAIS) * 3, "arquivos")
