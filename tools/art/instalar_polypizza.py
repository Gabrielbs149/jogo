"""Copia para o projeto só os modelos do poly.pizza que a cidade usa (D041), de C:/dev/_pacotes/polypizza
para assets/kits/polypizza/<pacote>/, e escreve os créditos (CC-BY pede o nome do autor) em assets/kits/polypizza/CREDITOS.md.
Rodar depois de tools/art/baixar_polypizza.py. Uso: python tools/art/instalar_polypizza.py"""
import json
import os
import shutil

SRC = "C:/dev/_pacotes/polypizza/"
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))).replace("\\", "/") + "/"
DST = ROOT + "assets/kits/polypizza/"

# pacote -> lista de modelos (nome do arquivo sem .glb); "*" = todos
PICK = {
    "Medieval-Village-Pack": "*",
    "Ultimate-Fantasy-RTS": ["Town_Center_3", "Town_Center_Second_Age", "Market_Stalls", "Market_Stalls_2", "Market_Stalls_4", "Village_Market"],
    "Low-Poly-Outdoor-Garden-Decorations": ["Water_Fountain", "Statue", "Statue_3", "Statue_4", "Statue_5", "Statue_8", "Garden_Lamp", "Lamp",
                                            "Flower_Bed", "Flower_Bed_2", "Flower_Bed_4", "Flower_Pot", "Flower_Pot_3", "Pillar", "Bench",
                                            "Gazebo", "Bird_House", "Flowers"],
    "Signs-pack": "*",
    "Baked-Goods": ["Baguette", "Bread_Roll", "Bread", "Bread_Half", "Croissant", "Pie_Apple", "Pie_Cherry", "Cinnamon_Roll", "Muffin", "Cookie"],
    "Food-Kit": ["Apple", "Carrot", "Cabbage", "Eggplant", "Cherries", "Capsicum", "Beet", "Broccoli", "Cauliflower", "Pumpkin", "Corn",
                 "Fish", "Steak", "Leek", "Onion", "Potato", "Tomato", "Pear", "Lemon", "Watermelon", "Mushroom", "Cheese", "Bag", "Sack"],
    "Farm-Animal-Pack": ["Horse", "Cow", "Pig", "Sheep"],
    "Animal-Kit": ["Chicken", "Dog", "Cat", "Beagle"],
    "Medieval-Torture-Devices": ["Pilory", "Pilory_2", "Stool"],
    "Witch-cottage-pack": ["Candle_Lantern", "Big_Tree", "Maple_Trees", "Water_Can"],
    "Ultimate-RPG-Items-Bundle": ["Shield", "Shield_Round", "Shield_2", "Sword", "Sword_2", "Claymore", "Axe_Double", "Axe_Small", "Spear",
                                  "Armor_Metal", "Armor_Leather", "Knife", "Scythe", "Coin_Pouch", "Bag", "Parchment", "Scroll", "Gold_Ingots"],
    "Modular-Dungeons-Pack": "*",
    # D044: Arandu maior (fazendas fora da muralha, cemitério da capela)
    "Farm-Buildings-Bundle": "*",
    "Halloween-Bits": ["Gravestone", "Gravestone_2", "Grave", "Grave_2", "Grave_Marker", "Gravemarker", "Damaged_Grave", "Crypt",
                       "Iron_Fence", "Damaged_Iron_fence", "Fence_Gate", "Fence_Pillar", "Broken_Fence_Pillar", "Arch_Gate", "Shrine",
                       "Shrine_2", "Lantern", "Post_Lantern", "Hanging_Lantern", "Pumpkin", "Small_Pumpkin", "Small_Pumpkin_2",
                       "Yellow_pumpkin", "Autumn_pine", "Autumn_pine_2", "Autumn_pine_3", "Autumn_pine_4", "Autumn_pine_5",
                       "Autumn_pine_6", "Dead_tree", "Dead_tree_2", "Tree_Dead_Large_Deco", "Coffin", "Bench", "Candles",
                       "Plaque_Candles", "Path", "Path_2"],
    # avulsos (achados pela busca do site) vão para a pasta Avulsos
    "_avulsos": ["Guard_Tower_sbaM8I229r", "Broken_Cart_NBDHe8J7f9", "Stag_Statue_cKloIsNcT8", "Wall_Flag_TWDvd4qPzq",
                 "Wheat_lPspzfC8Pu"],
}


def main():
    credits = {}
    total = 0
    for pack, wanted in PICK.items():
        man = json.load(open(SRC + pack + "/manifesto.json", encoding="utf-8"))
        out = "Avulsos" if pack.startswith("_") else pack
        os.makedirs(DST + out, exist_ok=True)
        models = man["modelos"].values() if isinstance(man["modelos"], dict) else man["modelos"]
        for m in models:
            if not m.get("arquivo"):
                continue
            name = m["arquivo"][:-4]
            if wanted != "*" and name not in wanted:
                continue
            src = SRC + pack + "/" + m["arquivo"]
            if not os.path.exists(src):
                continue
            shutil.copyfile(src, DST + out + "/" + m["arquivo"])
            total += 1
            credits.setdefault((m["autor"], m["licenca"]), set()).add(out)
    lines = ["# Modelos do poly.pizza (D041)", "",
             "Baixados de https://poly.pizza por `tools/art/baixar_polypizza.py`. CC0 = domínio público; CC-BY 3.0 = livre com crédito ao autor.", ""]
    for (autor, lic), packs in sorted(credits.items()):
        lines.append("- **%s** (%s): %s" % (autor, lic, ", ".join(sorted(packs))))
    open(DST + "CREDITOS.md", "w", encoding="utf-8", newline="\n").write("\n".join(lines) + "\n")
    print("modelos copiados:", total)
    print("\n".join(lines[4:]))


if __name__ == "__main__":
    main()
