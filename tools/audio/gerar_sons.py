"""Gera os sons do dia a dia de Arandu (D059) sem baixar nada: só numpy.

Uso: python tools/audio/gerar_sons.py
Escreve em assets/audio/:
  ambiente/cidade.wav        laço de 40 s: vento entre as casas + conversa distante (sem palavras) + rumor da cidade
  sfx/madeira_0..3.wav       rangidos de madeira
  sfx/pombo_0..1.wav         arrulho de pombo
  sfx/cachorro_0..1.wav      cachorro latindo longe
  sfx/gato_0.wav             miado curto
  sfx/pegar_comida_0..2.wav  saquinho / pano sendo mexido
  musica/rotina.wav          violão dedilhado em lá menor, lento, levemente melancólico (laço de ~55 s)
Tudo é sorteado com semente fixa: rodar de novo dá os mesmos arquivos.
"""
import os
import wave

import numpy as np

RATE = 22050
ROOT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio")
rng = np.random.default_rng(59)


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
    print(rel, f"{len(x) / RATE:.1f}s")


def shape(x, gain):
    """Filtra pelo espectro: gain(f) -> multiplicador (filtro fixo, sem fase)."""
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1.0 / RATE)
    return np.fft.irfft(spec * gain(f), len(x))


def band(f, center, width):
    return np.exp(-0.5 * ((f - center) / width) ** 2)


def lowpass(f, cut, order=2):
    return 1.0 / np.sqrt(1.0 + (f / cut) ** (2 * order))


def smooth_noise(n, rate_hz):
    """Ruído lento (0..1) para modular coisas: pontos sorteados a rate_hz, interpolados."""
    points = int(n / RATE * rate_hz) + 3
    knots = rng.random(points)
    xs = np.linspace(0, points - 1, n)
    return np.interp(xs, np.arange(points), knots)


def env(n, attack, release):
    e = np.ones(n)
    a = max(1, int(attack * RATE))
    r = max(1, int(release * RATE))
    e[:a] = np.linspace(0, 1, a)
    e[-r:] *= np.linspace(1, 0, r)
    return e


def loop_crossfade(x, seconds=2.0):
    """Fecha o laço: o fim se mistura com o começo (sem estalo quando repete)."""
    k = int(seconds * RATE)
    head, body, tail = x[:k], x[k:-k], x[-k:]
    t = np.linspace(0, 1, k)
    return np.concatenate([tail * (1 - t) + head * t, body])


# --- ambiente da cidade -------------------------------------------------------------------------

def cidade():
    n = RATE * 44
    # vento: ruído marrom, grave, subindo e descendo devagar, com um assobio leve de vez em quando
    white = rng.standard_normal(n)
    wind = shape(white, lambda f: lowpass(f, 380, 2) * (f > 30))
    wind *= 0.35 + 0.65 * smooth_noise(n, 0.18) ** 1.5
    whistle = shape(rng.standard_normal(n), lambda f: band(f, 900, 60)) * smooth_noise(n, 0.1) ** 4 * 0.5
    # conversa distante: várias "vozes" de ruído com formantes, em sílabas, com pausas; abafadas pela distância
    murmur = np.zeros(n)
    for v in range(7):
        pitch = rng.uniform(0.85, 1.25)
        voice = rng.standard_normal(n)
        voice = shape(voice, lambda f, p=pitch: band(f, 500 * p, 160) + 0.7 * band(f, 1300 * p, 260) + 0.3 * band(f, 2400 * p, 300))
        syll = 0.5 + 0.5 * np.sin(2 * np.pi * np.cumsum(rng.uniform(3.0, 5.0) + 1.5 * smooth_noise(n, 2.0)) / RATE)
        phrase = (smooth_noise(n, rng.uniform(0.25, 0.5)) > rng.uniform(0.45, 0.6)).astype(float)
        phrase = np.convolve(phrase, np.ones(2000) / 2000, mode="same")
        murmur += voice * syll ** 2 * phrase * rng.uniform(0.6, 1.0)
    murmur = shape(murmur, lambda f: lowpass(f, 1100, 2))
    # rumor de cidade (bem grave) para não ficar um silêncio digital entre as coisas
    rumble = shape(rng.standard_normal(n), lambda f: lowpass(f, 120, 2) * (f > 25))
    mix = wind / np.std(wind) * 0.55 + whistle / (np.std(whistle) + 1e-9) * 0.05 \
        + murmur / np.std(murmur) * 0.22 + rumble / np.std(rumble) * 0.2
    save("ambiente/cidade.wav", loop_crossfade(mix, 3.0), -9.0)


# --- efeitos soltos -----------------------------------------------------------------------------

def madeira(i):
    dur = rng.uniform(0.45, 0.9)
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    # fricção: pulsos irregulares (stick-slip) passando por ressonâncias de tábua
    rate = rng.uniform(70, 160) * (1 + 0.6 * np.sin(2 * np.pi * rng.uniform(1, 3) * t)) * (1 + 0.15 * rng.standard_normal(n))
    phase = np.cumsum(rate) / RATE
    pulses = (np.diff(np.floor(phase), prepend=0) > 0).astype(float) * (0.5 + rng.random(n))
    body = shape(pulses, lambda f: band(f, rng.uniform(380, 520), 60) + 0.8 * band(f, rng.uniform(900, 1200), 120)
                 + 0.4 * band(f, 2100, 200))
    save(f"sfx/madeira_{i}.wav", body * env(n, 0.06, 0.25) * np.sin(np.pi * t / dur) ** 0.5, -8.0)


def pombo(i):
    parts = []
    for k, (f0, dur) in enumerate([(rng.uniform(330, 360), 0.32), (rng.uniform(250, 280), 0.55)]):
        n = int(dur * RATE)
        t = np.arange(n) / RATE
        pitch = f0 * (1 + 0.12 * np.sin(np.pi * t / dur)) * (1 + 0.03 * np.sin(2 * np.pi * 28 * t))
        tone = np.sin(2 * np.pi * np.cumsum(pitch) / RATE) + 0.3 * np.sin(4 * np.pi * np.cumsum(pitch) / RATE)
        parts.append(tone * np.sin(np.pi * t / dur) ** 1.5)
        parts.append(np.zeros(int(0.06 * RATE)))
    x = np.concatenate(parts)
    x = shape(x + 0.02 * rng.standard_normal(len(x)), lambda f: lowpass(f, 1800, 2))
    save(f"sfx/pombo_{i}.wav", x, -10.0)


def cachorro(i):
    parts = []
    for k in range(rng.integers(2, 4)):
        dur = rng.uniform(0.13, 0.2)
        n = int(dur * RATE)
        t = np.arange(n) / RATE
        pitch = rng.uniform(420, 560) * (1.25 - 0.45 * t / dur)
        phase = np.cumsum(pitch) / RATE
        tone = sum(np.sin(2 * np.pi * h * phase) / h for h in range(1, 7))
        tone += 0.5 * rng.standard_normal(n)
        parts.append(tone * env(n, 0.01, 0.08))
        parts.append(np.zeros(int(rng.uniform(0.18, 0.32) * RATE)))
    x = np.concatenate(parts + [np.zeros(int(0.6 * RATE))])
    # longe: grave, abafado e com eco das paredes
    x = shape(x, lambda f: band(f, 700, 350) + 0.4 * lowpass(f, 500))
    echo = np.zeros_like(x)
    for d, g in [(0.09, 0.35), (0.21, 0.2), (0.37, 0.1)]:
        k = int(d * RATE)
        echo[k:] += x[:-k] * g
    save(f"sfx/cachorro_{i}.wav", x + echo, -12.0)


def gato():
    dur = 0.75
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    pitch = 520 + 300 * np.sin(np.pi * np.clip(t / dur * 1.3, 0, 1)) ** 2
    phase = np.cumsum(pitch) / RATE
    tone = sum(np.sin(2 * np.pi * h * phase) / h ** 1.2 for h in range(1, 9))
    vowel = shape(tone, lambda f: band(f, 900, 250) + 0.8 * band(f, 1700, 300) + 0.3 * band(f, 3000, 400))
    save("sfx/gato_0.wav", vowel * env(n, 0.05, 0.3), -10.0)


def pegar_comida(i):
    dur = rng.uniform(0.3, 0.45)
    n = int(dur * RATE)
    # papel/pano: estalinhos de ruído agudo em rajada
    clicks = np.zeros(n)
    for k in range(rng.integers(14, 24)):
        at = int(rng.uniform(0, 0.85) * n)
        size = int(rng.uniform(0.004, 0.02) * RATE)
        clicks[at:at + size] += rng.standard_normal(min(size, n - at)) * rng.uniform(0.3, 1.0)
    x = shape(clicks + 0.08 * rng.standard_normal(n), lambda f: band(f, 3200, 1500) + 0.4 * band(f, 1200, 500))
    save(f"sfx/pegar_comida_{i}.wav", x * env(n, 0.01, 0.12), -9.0)


# --- música: violão dedilhado (Karplus-Strong) --------------------------------------------------

def pluck(freq, dur, bright=0.5, decay=0.996):
    """Corda dedilhada (Karplus-Strong), calculada em blocos do tamanho do período."""
    n = int(dur * RATE)
    period = int(RATE / freq)
    y = np.zeros(n + period + 1)
    burst = rng.uniform(-1, 1, period)
    # ataque mais macio (dedo, não palheta): passa o ruído por uma média
    soft = np.convolve(burst, np.ones(3) / 3, mode="same")
    y[:period] = bright * burst + (1 - bright) * soft
    for start in range(period, n + 1, period):
        end = min(start + period, n + 1)
        idx = np.arange(start, end)
        y[idx] = decay * 0.5 * (y[idx - period] + y[idx - period - 1])
    out = y[:n]
    fade = min(n, int(0.05 * RATE))
    out[-fade:] *= np.linspace(1, 0, fade)
    return out


NOTE = {"E2": 82.41, "F2": 87.31, "G2": 98.0, "A2": 110.0, "B2": 123.47, "C3": 130.81, "D3": 146.83, "E3": 164.81,
        "F3": 174.61, "G3": 196.0, "G#3": 207.65, "A3": 220.0, "B3": 246.94, "C4": 261.63, "D4": 293.66, "E4": 329.63,
        "F4": 349.23, "G4": 392.0, "G#4": 415.3, "A4": 440.0, "B4": 493.88, "C5": 523.25, "D5": 587.33, "E5": 659.26}


def rotina():
    bpm = 72
    beat = 60.0 / bpm
    # lá menor, ritmo de valsa lenta (3/4), arpejo: baixo, 3 notas acima; 16 compassos
    chords = [
        ("A2", ["E3", "A3", "C4"]), ("F2", ["C3", "F3", "A3"]), ("C3", ["G3", "C4", "E4"]), ("E2", ["B2", "E3", "G#3"]),
        ("A2", ["E3", "A3", "C4"]), ("D3", ["A3", "D4", "F4"]), ("E2", ["B2", "E3", "G#3"]), ("E2", ["B2", "E3", "G#3"]),
        ("F2", ["C3", "F3", "A3"]), ("G2", ["D3", "G3", "B3"]), ("C3", ["G3", "C4", "E4"]), ("A2", ["E3", "A3", "C4"]),
        ("D3", ["A3", "D4", "F4"]), ("A2", ["E3", "A3", "C4"]), ("E2", ["B2", "E3", "G#3"]), ("E2", ["B2", "E3", "G#3"]),
    ]
    # melodia simples por cima (uma nota por tempo, None = silêncio), deixa espaço para as falas
    melody = [
        "E4", None, "C4", "F4", None, "E4", "E4", "D4", "C4", "B3", None, None,
        "C4", None, "E4", "F4", "E4", "D4", "B3", None, "G#3", "B3", None, None,
        "A3", "C4", "F4", "G4", "F4", "D4", "E4", None, "C4", "C4", "B3", "A3",
        "D4", None, "F4", "E4", None, "C4", "B3", "C4", "D4", "E4", None, None,
    ]
    bar = 3 * beat
    total = len(chords) * bar + 3.0
    out = np.zeros(int(total * RATE))

    def put(signal, at, gain):
        i = max(0, int(at * RATE))
        end = min(len(out), i + len(signal))
        out[i:end] += signal[: end - i] * gain

    for c, (bass, upper) in enumerate(chords):
        t0 = c * bar + rng.normal(0, 0.006)
        put(pluck(NOTE[bass], 3.2, 0.35, 0.997), t0, 0.9)
        pattern = [(0.0, upper[0]), (1.0, upper[1]), (1.5, upper[2]), (2.0, upper[1]), (2.5, upper[0])]
        for beat_at, note in pattern:
            put(pluck(NOTE[note], 2.0, 0.45, 0.995), t0 + beat_at * beat + rng.normal(0, 0.008), 0.42 + rng.normal(0, 0.04))
    # melodia só na segunda metade (a primeira volta é só o violão, mais calma)
    start = 8 * bar
    for k, note in enumerate(melody[: 24]):
        if note:
            put(pluck(NOTE[note] * 2, 1.6, 0.6, 0.994), start + k * beat + rng.normal(0, 0.01), 0.32)
    # um pouco de ambiência: ecos curtos e bem baixos (sala pequena)
    room = np.zeros_like(out)
    for d, g in [(0.031, 0.25), (0.067, 0.18), (0.113, 0.12), (0.171, 0.08)]:
        k = int(d * RATE)
        room[k:] += out[:-k] * g
    mix = shape(out + room, lambda f: lowpass(f, 4500, 2) * (f > 50))
    loop = loop_crossfade(mix, 2.5)
    save("musica/rotina.wav", loop, -11.0)


if __name__ == "__main__":
    cidade()
    for i in range(4):
        madeira(i)
    for i in range(2):
        pombo(i)
        cachorro(i)
    gato()
    for i in range(3):
        pegar_comida(i)
    rotina()
