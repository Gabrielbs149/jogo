"""Monta o ACERVO local do editor de mapas (D043): todos os modelos baixados do poly.pizza
(pacotes por tools/art/baixar_polypizza.py e avulsos por tools/art/buscar_polypizza.py) vão para assets/acervo/,
cada um com a foto do próprio site (.webp), e um índice (assets/acervo/indice.json) que a Biblioteca do editor lê.
O acervo NÃO vai para o Git (é grande demais para o LFS grátis): ao salvar uma fase, o editor copia só os modelos
usados para assets/kits/polypizza/ (que vai para o Git). Uso: python tools/art/montar_acervo.py
"""
import json
import os
import re
import shutil
import time
import urllib.error
import urllib.request

SRC = "C:/dev/_pacotes/polypizza/"
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))).replace("\\", "/") + "/"
DST = ROOT + "assets/acervo/"
UA = {"User-Agent": "Mozilla/5.0 (jogo Plano do Fogo)"}


def get(url):
    """Com paciência: se o site pedir calma (429), espera cada vez mais e tenta de novo."""
    wait = 5.0
    for attempt in range(7):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=30) as r:
                return r.read()
        except urllib.error.HTTPError as e:
            if e.code not in (429, 500, 502, 503, 504) or attempt == 6:
                raise
        except (urllib.error.URLError, TimeoutError):
            if attempt == 6:
                raise
        time.sleep(wait)
        wait = min(wait * 2.0, 120.0)


def pack_name(folder):
    return "Avulsos" if folder == "_avulsos" else folder.replace("-", " ")


def main():
    os.makedirs(DST, exist_ok=True)
    index = []
    copied = 0
    previews = 0
    # modelo que está num pacote não entra de novo como avulso
    in_bundles = set()
    for folder in os.listdir(SRC):
        man_path = SRC + folder + "/manifesto.json"
        if folder != "_avulsos" and os.path.exists(man_path):
            in_bundles.update(m["uuid"] for m in json.load(open(man_path, encoding="utf-8"))["modelos"])
    for folder in sorted(os.listdir(SRC)):
        man_path = SRC + folder + "/manifesto.json"
        if not os.path.exists(man_path):
            continue
        man = json.load(open(man_path, encoding="utf-8"))
        models = man["modelos"].values() if isinstance(man["modelos"], dict) else man["modelos"]
        out_dir = DST + re.sub(r"[^A-Za-z0-9_\-]+", "_", folder) + "/"
        os.makedirs(out_dir, exist_ok=True)
        for m in models:
            if folder == "_avulsos" and m["uuid"] in in_bundles:
                continue
            src = SRC + folder + "/" + m.get("arquivo", "")
            if not m.get("arquivo") or not os.path.exists(src) or os.path.getsize(src) < 200:
                continue
            dst = out_dir + m["arquivo"]
            if not os.path.exists(dst):
                shutil.copyfile(src, dst)
                copied += 1
            webp = dst[:-4] + ".webp"
            if not os.path.exists(webp):
                cache = SRC + folder + "/." + m["uuid"] + ".webp"
                try:
                    if os.path.exists(cache):
                        shutil.copyfile(cache, webp)
                    else:
                        open(webp, "wb").write(get("https://static.poly.pizza/%s.webp" % m["uuid"]))
                        time.sleep(0.08)
                    previews += 1
                except Exception:  # noqa: BLE001 - sem foto, o editor mostra só o nome
                    pass
            index.append({
                "key": "res://" + dst[len(ROOT):],
                "nome": m["titulo"].replace("_", " ").strip(),
                "autor": m["autor"],
                "licenca": m["licenca"],
                "pacote": pack_name(folder),
                "termos": m.get("termos", []),
            })
    json.dump(index, open(DST + "indice.json", "w", encoding="utf-8"), ensure_ascii=False)
    print("acervo: %d modelos (%d copiados agora, %d fotos novas)" % (len(index), copied, previews))


if __name__ == "__main__":
    main()
