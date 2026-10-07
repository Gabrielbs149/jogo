"""Copia os sons escolhidos (CC0, D034) para assets/audio/. Uso: python tools/art/instalar_sons.py C:/dev/_sons
Fontes: Kenney (RPG Audio, Impact Sounds, Interface Sounds, UI Audio, Music Jingles) e OpenGameArt
(The Old Tower Inn / RandomMind, Desert Loop, Heartfelt Battle, Wind Whoosh Loop, Fire Crackling)."""
import glob
import os
import shutil
import sys

SRC = sys.argv[1] if len(sys.argv) > 1 else "C:/dev/_sons"
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "audio")


def find(name):
    hits = glob.glob(SRC + "/**/" + name, recursive=True)
    hits = [h for h in hits if "/Preview" not in h.replace("\\", "/")]
    assert hits, name
    return hits[0]


PICK = {
    "musica": {"arandu.mp3": "The_Old_Tower_Inn.mp3", "ethera.mp3": "desert_loop_0.mp3",
               "batalha.ogg": "heartfelt-battle_loop.ogg", "batalha_intro.ogg": "heartfelt-battle_intro.ogg",
               "vitoria.ogg": "jingles_PIZZI07.ogg", "derrota.ogg": "jingles_PIZZI16.ogg"},
    "ambiente": {"vento.ogg": "wind_woosh_loop.ogg", "fogo.ogg": "fire-1.ogg"},
    "sfx": {},
}
for kind in ("grass", "concrete", "snow"):
    for i in range(5):
        PICK["sfx"]["passo_%s_%d.ogg" % ({"grass": "grama", "concrete": "pedra", "snow": "areia"}[kind], i)] = "footstep_%s_00%d.ogg" % (kind, i)
for i in range(5):
    PICK["sfx"]["passo_terra_%d.ogg" % i] = "footstep0%d.ogg" % i
for i, f in enumerate(["knifeSlice.ogg", "knifeSlice2.ogg", "drawKnife1.ogg", "drawKnife2.ogg", "chop.ogg"]):
    PICK["sfx"]["golpe_%d.ogg" % i] = f
for i in range(4):
    PICK["sfx"]["impacto_%d.ogg" % i] = "impactPunch_medium_00%d.ogg" % i
    PICK["sfx"]["aparar_%d.ogg" % i] = "impactMetal_heavy_00%d.ogg" % i
    PICK["sfx"]["esquiva_%d.ogg" % i] = "cloth%d.ogg" % (i + 1)
PICK["sfx"].update({
    "queda.ogg": "impactSoft_heavy_000.ogg", "qte_perfeito.ogg": "confirmation_002.ogg", "qte_bom.ogg": "click_002.ogg",
    "qte_errou.ogg": "error_004.ogg", "clique.ogg": "click3.ogg", "passar_mouse.ogg": "rollover2.ogg",
    "ler.ogg": "bookFlip1.ogg", "conversar.ogg": "cloth3.ogg", "viajar.ogg": "doorOpen_1.ogg", "descansar.ogg": "handleSmallLeather.ogg",
    "turno.ogg": "tick_002.ogg", "fala.ogg": "tick_001.ogg",
})

total = 0
for folder, files in PICK.items():
    os.makedirs(os.path.join(OUT, folder), exist_ok=True)
    for dst, src in files.items():
        path = os.path.join(OUT, folder, dst)
        shutil.copyfile(find(src), path)
        total += os.path.getsize(path)
print("arquivos:", sum(len(v) for v in PICK.values()), "tamanho: %.1f MB" % (total / 1e6))
