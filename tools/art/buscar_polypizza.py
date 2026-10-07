"""Baixa modelos AVULSOS do poly.pizza pela busca do site (D043): para cada termo, percorre as páginas
(?page=N, 64 por página) até acabar, e baixa cada .glb uma vez só (sem repetir o que já veio dos pacotes).
Tudo vai para C:/dev/_pacotes/polypizza/_avulsos/ com um manifesto (título, autor, licença, termos que acharam).
Muitos modelos avulsos são CC-BY (pedem o nome do autor nos créditos): o manifesto guarda isso.
Uso: python tools/art/buscar_polypizza.py [termo ...]   (sem termos: a lista TERMOS abaixo)
"""
import json
import os
import re
import sys
import time
import urllib.parse
import urllib.error
import urllib.request

BASE = "C:/dev/_pacotes/polypizza"
OUT = BASE + "/_avulsos"
UA = {"User-Agent": "Mozilla/5.0 (jogo Plano do Fogo; download de assets livres)"}
MAX_PAGES = 40

TERMOS = [
    # cidade e construções
    "medieval", "fantasy", "castle", "house", "cottage", "tavern", "inn", "shop", "market", "stall", "bakery", "blacksmith", "forge",
    "church", "chapel", "temple", "tower", "wall", "gate", "bridge", "well", "fountain", "windmill", "mill", "barn", "stable", "farm",
    "village", "town", "hut", "tent", "camp", "dock", "pier", "boat", "ship", "cart", "wagon", "carriage", "roof", "door", "window",
    "stairs", "fence", "ruins", "ruin", "pillar", "column", "arch", "statue", "monument", "grave", "tomb", "cemetery", "crypt",
    # masmorra e aventura
    "dungeon", "cave", "mine", "prison", "cage", "torture", "chest", "treasure", "gold", "coin", "key", "trap", "lever", "altar",
    "throne", "crystal", "gem", "portal", "totem", "skull", "bones", "skeleton",
    # objetos
    "barrel", "crate", "box", "sack", "bag", "basket", "bucket", "pot", "jar", "vase", "bottle", "potion", "cauldron", "book",
    "scroll", "candle", "lantern", "lamp", "torch", "campfire", "fire", "table", "chair", "bench", "stool", "bed", "shelf",
    "cabinet", "wardrobe", "rug", "carpet", "banner", "flag", "sign", "anvil", "tool", "hammer", "axe", "pickaxe", "shovel",
    "rope", "ladder", "chain", "bell", "clock", "mirror", "painting", "plate", "cup", "mug", "kitchen", "oven",
    # armas e armaduras
    "sword", "shield", "bow", "arrow", "spear", "dagger", "knife", "mace", "staff", "wand", "armor", "helmet", "crown",
    # comida
    "food", "bread", "cheese", "meat", "fish", "apple", "fruit", "vegetable", "pumpkin", "carrot", "mushroom", "pie", "cake",
    # natureza
    "tree", "pine", "oak", "palm", "bush", "plant", "flower", "grass", "rock", "stone", "boulder", "cliff", "mountain", "log",
    "stump", "cactus", "desert", "sand", "snow", "ice", "lake", "river", "water", "island", "volcano", "lava",
    # gente e bichos
    "character", "person", "knight", "warrior", "wizard", "witch", "king", "queen", "villager", "farmer", "merchant", "guard",
    "soldier", "pirate", "monster", "dragon", "goblin", "orc", "troll", "ghost", "zombie", "demon", "golem", "slime", "spider",
    "bat", "rat", "mouse", "wolf", "bear", "deer", "fox", "rabbit", "horse", "cow", "pig", "sheep", "goat", "chicken", "duck",
    "dog", "cat", "bird", "owl", "crow", "frog", "snake", "lizard", "turtle", "insect", "beetle", "bee", "butterfly",
]


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


def page(term, n):
    url = "https://poly.pizza/search/" + urllib.parse.quote(term) + ("?page=%d" % n if n > 1 else "")
    html = get(url).decode("utf-8", "replace").replace("\\u002F", "/")
    found = []
    for m in re.finditer(r'\{"id":\d+,"title":"((?:[^"\\]|\\.)*)","alt":"(?:[^"\\]|\\.)*","creator":\{"username":"((?:[^"\\]|\\.)*)"'
                         r'.*?"previewUrl":"https://static\.poly\.pizza/([0-9a-f\-]+)\.webp","publicID":"([^"]+)","licence":"([^"]+)"', html):
        title, creator, uuid, pid, licence = m.groups()
        found.append({"titulo": title, "autor": creator, "uuid": uuid, "id": pid, "licenca": licence})
    return found


def known_uuids():
    seen = set()
    for folder in os.listdir(BASE):
        man = BASE + "/" + folder + "/manifesto.json"
        if folder != "_avulsos" and os.path.exists(man):
            for m in json.load(open(man, encoding="utf-8"))["modelos"]:
                seen.add(m["uuid"])
    return seen


def safe(name):
    return re.sub(r"[^A-Za-z0-9_\-]+", "_", name).strip("_")[:60] or "modelo"


def main():
    os.makedirs(OUT, exist_ok=True)
    man_path = OUT + "/manifesto.json"
    manifest = json.load(open(man_path, encoding="utf-8")) if os.path.exists(man_path) else {"modelos": {}}
    models = manifest["modelos"]  # id -> dados
    in_bundles = known_uuids()
    terms = sys.argv[1:] or TERMOS
    total = 0
    for term in terms:
        new = 0
        seen_page = set()
        for n in range(1, MAX_PAGES + 1):
            try:
                found = page(term, n)
            except Exception as e:  # noqa: BLE001
                print("  erro na busca", term, n, e)
                break
            ids = tuple(f["id"] for f in found)
            if not found or ids in seen_page:
                break
            seen_page.add(ids)
            for f in found:
                if f["id"] in models:
                    models[f["id"]].setdefault("termos", [])
                    if term not in models[f["id"]]["termos"]:
                        models[f["id"]]["termos"].append(term)
                    continue
                if f["uuid"] in in_bundles:
                    continue
                f["arquivo"] = safe(f["titulo"]) + "_" + f["id"] + ".glb"
                f["termos"] = [term]
                path = OUT + "/" + f["arquivo"]
                if not os.path.exists(path):
                    try:
                        data = get("https://static.poly.pizza/%s.glb" % f["uuid"])
                        open(path, "wb").write(data)
                        total += len(data)
                    except Exception as e:  # noqa: BLE001
                        f["erro"] = str(e)
                    time.sleep(0.1)
                models[f["id"]] = f
                new += 1
            time.sleep(0.2)
        json.dump(manifest, open(man_path, "w", encoding="utf-8"), ensure_ascii=False, indent=0)
        print("%-12s +%4d  (total %d, %.0f MB novos)" % (term, new, len(models), total / 1e6), flush=True)
    lic = {}
    for m in models.values():
        lic[m["licenca"]] = lic.get(m["licenca"], 0) + 1
    print("modelos avulsos:", len(models), "licenças:", lic)


if __name__ == "__main__":
    main()
