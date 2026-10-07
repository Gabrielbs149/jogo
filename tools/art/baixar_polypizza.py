"""Baixa pacotes (bundles) do poly.pizza (D041): cada modelo vira um .glb em C:/dev/_pacotes/polypizza/<pacote>/,
com um manifesto (titulo, autor, licença) para os créditos. Modelos CC-BY pedem o nome do autor nos créditos.
Uso: python tools/art/baixar_polypizza.py Medieval-Village-Pack-NsHhjhlrfY Ultimate-Fantasy-RTS-nSDjmACoSU ...
"""
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request

OUT = "C:/dev/_pacotes/polypizza"
UA = {"User-Agent": "Mozilla/5.0 (jogo Plano do Fogo; download de assets CC0)"}


def get(url):
    """Baixa com paciência: se o site pedir calma (429) ou falhar, espera cada vez mais e tenta de novo."""
    wait = 5.0
    for attempt in range(7):
        try:
            req = urllib.request.Request(url, headers=UA)
            with urllib.request.urlopen(req, timeout=60) as r:
                return r.read()
        except urllib.error.HTTPError as e:
            if e.code not in (429, 500, 502, 503, 504) or attempt == 6:
                raise
        except (urllib.error.URLError, TimeoutError):
            if attempt == 6:
                raise
        time.sleep(wait)
        wait = min(wait * 2.0, 120.0)


def models_of(bundle):
    html = get("https://poly.pizza/bundle/" + bundle).decode("utf-8", "replace").replace("\\u002F", "/")
    out = {}
    for m in re.finditer(r'\{"id":\d+,"title":"((?:[^"\\]|\\.)*)","alt":"(?:[^"\\]|\\.)*","creator":\{"username":"((?:[^"\\]|\\.)*)"'
                         r'.*?"previewUrl":"https://static\.poly\.pizza/([0-9a-f\-]+)\.webp","publicID":"([^"]+)","licence":"([^"]+)"', html):
        title, creator, uuid, pid, licence = m.groups()
        out[pid] = {"titulo": title, "autor": creator, "uuid": uuid, "id": pid, "licenca": licence}
    return list(out.values())


def safe(name):
    return re.sub(r"[^A-Za-z0-9_\-]+", "_", name).strip("_") or "modelo"


def main():
    total = 0
    for bundle in sys.argv[1:]:
        folder = OUT + "/" + (bundle.rsplit("-", 1)[0] or bundle).strip("-")
        try:
            models = models_of(bundle)
        except Exception as e:  # noqa: BLE001 - pacote fora do ar: segue com os outros
            print("%-40s ERRO: %s" % (bundle, e), flush=True)
            continue
        os.makedirs(folder, exist_ok=True)
        names = {}
        for m in models:
            base = safe(m["titulo"])
            n = names.get(base, 0)
            names[base] = n + 1
            m["arquivo"] = base + ("" if n == 0 else "_%d" % (n + 1)) + ".glb"
            path = folder + "/" + m["arquivo"]
            if not os.path.exists(path):
                try:
                    data = get("https://static.poly.pizza/%s.glb" % m["uuid"])
                    open(path, "wb").write(data)
                    total += len(data)
                    time.sleep(0.15)
                except Exception as e:  # noqa: BLE001 - segue com os outros
                    m["erro"] = str(e)
        json.dump({"pacote": bundle, "modelos": models}, open(folder + "/manifesto.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
        lic = sorted({m["licenca"] for m in models})
        print("%-40s %3d modelos  licenças: %s" % (bundle.rsplit("-", 1)[0], len(models), ", ".join(lic)), flush=True)
    print("baixado: %.1f MB" % (total / 1e6))


if __name__ == "__main__":
    main()
