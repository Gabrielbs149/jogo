"""Traz modelos do ACERVO local (assets/acervo, fora do Git) para dentro do projeto (D060), do mesmo jeito que o
editor de mapas faz ao salvar (D043): copia para assets/kits/polypizza/<pacote>/ (que vai para o Git, LFS) e anota o
crédito do autor em assets/kits/polypizza/CREDITOS.md. Os montadores (montar_vida, montar_cidade...) usam as cópias.

Uso: python tools/art/trazer_do_acervo.py            (traz a lista PEGAR abaixo)
     python tools/art/trazer_do_acervo.py Pacote/Arquivo.glb ...   (traz só esses)
"""
import json
import os
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))).replace("\\", "/") + "/"
ACERVO = ROOT + "assets/acervo/"
DST = ROOT + "assets/kits/polypizza/"
CREDITS = DST + "CREDITOS.md"

# o que a cidade viva usa (pacote/arquivo do acervo)
PEGAR = [
    # bichos animados (D060)
    "Animated-Animal-Pack/Shiba_Inu.glb",
    "Animated-Animal-Pack/Husky.glb",
    "Animated-Animal-Pack/Donkey.glb",
    "Animated-Enemies/Rat.glb",
    # o padeiro briga com o rolo de massa (D060)
    "Food-Kit/Rolling_Pin.glb",
]


def main(wanted):
    index = {x["key"]: x for x in json.load(open(ACERVO + "indice.json", encoding="utf-8"))}
    old = open(CREDITS, encoding="utf-8").read() if os.path.exists(CREDITS) else ""
    add = []
    for rel in wanted:
        src = ACERVO + rel
        if not os.path.exists(src):
            print("não achei no acervo:", rel)
            continue
        dst = DST + rel
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        if not os.path.exists(dst):
            shutil.copy2(src, dst)
            print("copiado:", rel)
        entry = index.get("res://assets/acervo/" + rel, {})
        line = "- %s (%s): %s — res://assets/kits/polypizza/%s" % (entry.get("autor", "?"), entry.get("licenca", "?"),
                                                                    entry.get("nome", os.path.basename(rel)), rel)
        if line not in old:
            add.append(line)
    if add:
        text = old.rstrip("\n")
        if "## Do acervo" not in text:
            text += "\n\n## Do acervo (D043)"
        text += "\n" + "\n".join(add) + "\n"
        open(CREDITS, "w", encoding="utf-8", newline="\n").write(text)
    print(len(add), "créditos novos")


if __name__ == "__main__":
    main(sys.argv[1:] or PEGAR)
