"""Gera world/props/*.tscn: as peças do catálogo do editor de mapas, feitas com os kits CC0 do Quaternius
(vila, objetos e natureza) e os personagens do KayKit (D026). As casas são montadas com as peças modulares
do kit (paredes de 2 m na grade, portas, janelas, quinas, telhado e empena).
Rodar: python tools/art/gerar_pecas.py  (APAGA e refaz world/props — mudança feita à mão nas peças se perde).
Os nomes das peças são os mesmos de antes: as fases que já usam uma peça trocam sozinhas."""
import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))).replace("\\", "/") + "/"
OUT = ROOT + "world/props/"
Q = "res://assets/kits/quaternius/"
os.makedirs(OUT, exist_ok=True)
for f in os.listdir(OUT):
    if f.endswith(".tscn"):
        os.remove(OUT + f)


def xf(pos=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
    if not isinstance(scale, (tuple, list)):
        scale = (scale, scale, scale)
    if not isinstance(rot, (tuple, list)):
        rot = (0, rot, 0)
    rx, ry, rz = rot
    cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
    Ry = [[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]]
    Rx = [[1, 0, 0], [0, cx, -sx], [0, sx, cx]]
    Rz = [[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]]
    mul = lambda a, b: [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
    m = mul(mul(Ry, Rx), Rz)
    m = [[m[i][j] * scale[j] for j in range(3)] for i in range(3)]
    vals = [m[0][0], m[0][1], m[0][2], m[1][0], m[1][1], m[1][2], m[2][0], m[2][1], m[2][2], pos[0], pos[1], pos[2]]
    return "Transform3D(%s)" % ", ".join(("%.4f" % v).rstrip("0").rstrip(".") if abs(v) > 1e-9 else "0" for v in vals)


class Scene:
    def __init__(self, name, typ="Node3D", props=(), groups=()):
        self.ext, self.ext_ids, self.subs, self.sub_ids, self.nodes = [], {}, [], {}, []
        self.root = [name, typ, list(props), list(groups)]
        self.count = {}

    def ext_res(self, kind, path):
        if path not in self.ext_ids:
            rid = "%d_%s" % (len(self.ext_ids) + 1, os.path.basename(path).split(".")[0][:14])
            self.ext_ids[path] = rid
            self.ext.append('[ext_resource type="%s" path="%s" id="%s"]' % (kind, path, rid))
        return self.ext_ids[path]

    def sub(self, kind, key, body):
        if key not in self.sub_ids:
            self.sub_ids[key] = "%s_%d" % (kind, len(self.sub_ids) + 1)
            self.subs.append('[sub_resource type="%s" id="%s"]\n%s\n' % (kind, self.sub_ids[key], body))
        return self.sub_ids[key]

    def mat(self, name):
        return 'ExtResource("%s")' % self.ext_res("Material", "res://assets/materials/%s.tres" % name)

    def color(self, rgb, rough=0.9, emit=None):
        body = "albedo_color = Color(%g, %g, %g, 1)\nroughness = %g" % (tuple(rgb) + (rough,))
        if emit:
            body += "\nemission_enabled = true\nemission = Color(%g, %g, %g, 1)\nemission_energy_multiplier = %g" % (tuple(emit[0]) + (emit[1],))
        return 'SubResource("%s")' % self.sub("StandardMaterial3D", ("c", tuple(rgb), rough, str(emit)), body)

    def box(self, size):
        return self.sub("BoxMesh", ("box",) + tuple(size), "size = Vector3(%g, %g, %g)" % tuple(size))

    def cyl(self, rt, rb, h, seg=16):
        return self.sub("CylinderMesh", ("cyl", rt, rb, h, seg), "top_radius = %g\nbottom_radius = %g\nheight = %g\nradial_segments = %d" % (rt, rb, h, seg))

    def unique(self, base):
        n = self.count.get(base, 0)
        self.count[base] = n + 1
        return base if n == 0 else "%s%d" % (base, n + 1)

    def node(self, name, typ, parent, *props, instance=None):
        head = '[node name="%s"' % name
        if typ:
            head += ' type="%s"' % typ
        head += ' parent="%s"' % parent
        if instance:
            head += ' instance=ExtResource("%s")' % instance
        self.nodes.append(head + "]" + ("\n" + "\n".join(props) if props else "") + "\n")

    def mesh(self, name, mesh_id, material, pos, rot=(0, 0, 0), scale=1, parent="."):
        self.node(self.unique(name) if parent == "." else name, "MeshInstance3D", parent, "transform = " + xf(pos, rot, scale),
                  'mesh = SubResource("%s")' % mesh_id, "material_override = " + material)

    def piece(self, kit_path, pos=(0, 0, 0), rot=0.0, scale=1, name=None, parent="."):
        """Uma peça de kit (glTF do Quaternius): 'vila/Wall_Plaster_Straight'."""
        rid = self.ext_res("PackedScene", Q + kit_path + ".gltf")
        base = name or kit_path.split("/")[-1]
        self.node(self.unique(base) if parent == "." else base, None, parent, "transform = " + xf(pos, rot, scale), instance=rid)

    def scene(self, name, path, pos=(0, 0, 0), rot=0.0, scale=1, parent=".", *props):
        rid = self.ext_res("PackedScene", path)
        self.node(name, None, parent, "transform = " + xf(pos, rot, scale), *props, instance=rid)

    def body(self, shape, pos, layer=1, name="Body", rot=(0, 0, 0)):
        kind, dims = shape
        if kind == "box":
            sid = self.sub("BoxShape3D", ("bs",) + tuple(dims), "size = Vector3(%g, %g, %g)" % tuple(dims))
        elif kind == "cyl":
            sid = self.sub("CylinderShape3D", ("cs",) + tuple(dims), "radius = %g\nheight = %g" % tuple(dims))
        else:
            sid = self.sub("CapsuleShape3D", ("cap",) + tuple(dims), "radius = %g\nheight = %g" % tuple(dims))
        self.node(name, "StaticBody3D", ".", "transform = " + xf(pos, rot), "collision_layer = %d" % layer, "collision_mask = 0")
        self.node("Shape", "CollisionShape3D", name, 'shape = SubResource("%s")' % sid)

    def save(self, file):
        name, typ, props, groups = self.root
        head = '[node name="%s" type="%s"' % (name, typ)
        if groups:
            head += " groups=[%s]" % ", ".join('"%s"' % g for g in groups)
        head += "]" + ("\n" + "\n".join(props) if props else "") + "\n"
        text = "[gd_scene format=3]\n\n" + "\n".join(self.ext) + ("\n\n" if self.ext else "") + "\n".join(self.subs) + "\n" + head + "\n" + "\n".join(self.nodes)
        open(OUT + file + ".tscn", "w", encoding="utf-8", newline="\n").write(text)


AUTO = ["colisao_auto"]  # a fase dá colisão do formato da malha (world/level.gd)


def kit_prop(file, title, kit_path, scale=1.0, collide=True, rot=0.0):
    s = Scene(title, groups=AUTO if collide else [])
    s.piece(kit_path, rot=rot, scale=scale, name="Model")
    s.save(file)


def tree(file, title, kit_path, scale, trunk_r=0.35, trunk_h=4.0):
    s = Scene(title)
    s.piece(kit_path, scale=scale, name="Model")
    s.body(("cyl", (trunk_r * scale, trunk_h * scale)), (0, trunk_h * scale / 2, 0), 1)
    s.save(file)


# --- casas: paredes de 2 m na grade; frente (porta) para -Z ----------------------------------------
WALL_H = 3.12


def house(file, title, w, d, floors, walls, roof, gable, door_cell=None, chimney=True, door=True):
    """w x d células de 2 m. walls: estilo de parede por andar ('Wall_Plaster', 'Wall_UnevenBrick', 'Wall_Plaster_WoodGrid')."""
    s = Scene(title, groups=AUTO)
    hw, hd = float(w), float(d)
    door_cell = w // 2 if door_cell is None else door_cell
    for f, style in enumerate(walls):
        y = f * WALL_H
        grid = style.endswith("WoodGrid")
        base = "Wall_Plaster" if grid else style
        for i in range(w):
            x = -hw + 1.0 + i * 2.0
            if f == 0:
                for j in range(d):
                    s.piece("vila/Floor_Brick", (x, 0, -hd + 1.0 + j * 2.0))
            elif i == 0:
                for j in range(d):
                    for k in range(w):
                        s.piece("vila/Floor_WoodDark", (-hw + 1.0 + k * 2.0, y, -hd + 1.0 + j * 2.0))
            front_door = door and f == 0 and i == door_cell
            if front_door:
                s.piece("vila/" + base + "_Door_Round", (x, y, -hd), math.pi)
                s.piece("vila/Door_1_Round", (x + 0.53, y, -hd + 0.1), math.pi)
            elif grid:
                s.piece("vila/Wall_Plaster_WoodGrid", (x, y, -hd), math.pi)
            else:
                s.piece("vila/" + base + "_Window_Wide_Round", (x, y, -hd), math.pi)
                s.piece("vila/Window_Wide_Round1", (x, y, -hd), math.pi)
            back = "Wall_Plaster_WoodGrid" if grid else base + ("_Window_Wide_Round" if (i % 2 == 1 and f > 0) else "_Straight")
            s.piece("vila/" + back, (x, y, hd), 0.0)
            if back.endswith("Window_Wide_Round"):
                s.piece("vila/Window_Wide_Round1", (x, y, hd), 0.0)
        for j in range(d):
            z = -hd + 1.0 + j * 2.0
            side_window = j == d // 2
            for sign, rot in ((1, math.pi / 2), (-1, -math.pi / 2)):
                if grid:
                    s.piece("vila/Wall_Plaster_WoodGrid", (sign * hw, y, z), rot)
                elif side_window:
                    s.piece("vila/" + base + "_Window_Wide_Round", (sign * hw, y, z), rot)
                    s.piece("vila/Window_Wide_Round1", (sign * hw, y, z), rot)
                else:
                    s.piece("vila/" + base + "_Straight", (sign * hw, y, z), rot)
        for cx, cz in ((hw, hd), (-hw, hd), (hw, -hd), (-hw, -hd)):
            s.piece("vila/Corner_Exterior_Wood", (cx, y, cz))
    top = len(walls) * WALL_H
    s.piece("vila/" + roof, (0, top, 0))
    if gable:
        s.piece("vila/" + gable, (0, top, hd))
        s.piece("vila/" + gable, (0, top, -hd), math.pi)
    if chimney:
        s.piece("vila/Prop_Chimney", (hw - 1.2, top + 0.6, hd - 1.6))
    s.save(file)


house("casa", "Casa", 3, 3, 1, ["Wall_Plaster"], "Roof_RoundTiles_6x6", "Roof_Front_Brick6")
house("casa_barro", "Casa_barro", 3, 3, 1, ["Wall_UnevenBrick"], "Roof_RoundTiles_6x6", "Roof_Front_Brick6")
house("casa_grande", "Casa_grande", 4, 4, 2, ["Wall_UnevenBrick", "Wall_Plaster"], "Roof_RoundTiles_8x8", "Roof_Front_Brick8", 1)
house("casa_grande_barro", "Casa_grande_barro", 4, 4, 2, ["Wall_Plaster", "Wall_Plaster_WoodGrid"], "Roof_RoundTiles_8x8", "Roof_Front_Brick8", 2)
house("casa_estreita", "Casa_estreita", 2, 3, 2, ["Wall_Plaster", "Wall_Plaster_WoodGrid"], "Roof_RoundTiles_4x6", "Roof_Front_Brick4", 0, False)
house("casa_estreita_pedra", "Casa_estreita_pedra", 2, 3, 2, ["Wall_UnevenBrick", "Wall_Plaster"], "Roof_RoundTiles_4x6", "Roof_Front_Brick4", 1, False)
house("casa_longa", "Casa_longa", 3, 4, 1, ["Wall_Plaster"], "Roof_RoundTiles_6x8", "Roof_Front_Brick6", 1)
house("sobrado_longo", "Sobrado_longo", 3, 4, 2, ["Wall_UnevenBrick", "Wall_Plaster_WoodGrid"], "Roof_RoundTiles_6x8", "Roof_Front_Brick6", 1)
house("torre", "Torre", 2, 2, 3, ["Wall_UnevenBrick", "Wall_UnevenBrick", "Wall_UnevenBrick"], "Roof_Tower_RoundTiles", None, chimney=False, door=False)

s = Scene("Muro", groups=AUTO)
for i in range(3):
    s.piece("vila/Wall_UnevenBrick_Straight", (-2.0 + i * 2.0, 0, 0))
s.save("muro")

s = Scene("Portao", groups=AUTO)
s.piece("vila/Wall_Arch", (0, 0, 0))
s.piece("vila/Wall_Arch", (0, 0, -0.35))
for x in (-2.0, 2.0):
    s.piece("vila/Wall_UnevenBrick_Straight", (x, 0, 0))
s.save("portao")

s = Scene("Marquise", groups=AUTO)
# presa na parede (o lado +Z encosta na parede), sai 1,5 m para a frente
for x in (-1.0, 1.0):
    s.piece("vila/Roof_Wooden_2x1", (x, 3.1, -0.1), math.pi, (1, 1, 0.8))
for x in (-1.9, 1.9):
    s.piece("vila/Prop_Support", (x, 1.1, 0.0), 0.0)
s.save("marquise")

s = Scene("Barraca", groups=AUTO)
s.piece("objetos/Stall_Empty", scale=1.25, name="Stall")
s.piece("objetos/FarmCrate_Apple", (-0.45, 1.02, 0.1), 0.2)
s.piece("objetos/FarmCrate_Apple", (0.45, 1.02, 0.05), -0.15)
s.piece("objetos/Barrel_Apples", (1.6, 0, 0.5), 0.4)
s.save("barraca")

s = Scene("Barraca_carroca", groups=AUTO)
s.piece("objetos/Stall_Cart_Empty", name="Cart")
s.piece("objetos/FarmCrate_Apple", (-0.6, 0.85, 0.0))
s.save("barraca_carroca")

s = Scene("Poco", groups=AUTO)
s.mesh("Ring", s.cyl(1.2, 1.3, 0.95, 24), s.mat("pedra_poco"), (0, 0.47, 0))
s.mesh("Rim", s.cyl(1.28, 1.28, 0.14, 24), s.mat("calcada"), (0, 0.98, 0))
s.mesh("Water", s.cyl(1.0, 1.0, 0.05, 24), s.color((0.16, 0.34, 0.42), 0.1), (0, 0.75, 0))
for x in (-1.1, 1.1):
    s.mesh("Post", s.box((0.2, 2.4, 0.2)), s.mat("tabuas"), (x, 1.6, 0))
s.mesh("Axle", s.cyl(0.07, 0.07, 2.4, 10), s.mat("tabuas"), (0, 2.3, 0), (0, 0, math.pi / 2))
s.piece("vila/Roof_RoundTile_2x1_Long", (0, 2.95, 0), math.pi / 2, 0.75, name="Roof")
s.piece("objetos/Bucket_Wooden_1", (0.75, 1.05, 0.35), 0.4)
s.save("poco")

s = Scene("Pilar", groups=AUTO)
s.mesh("Base", s.box((1.5, 0.5, 1.5)), s.mat("arenito"), (0, 0.25, 0))
s.mesh("Stone", s.cyl(0.52, 0.6, 3.4, 16), s.mat("arenito"), (0, 2.2, 0))
s.mesh("Top", s.box((1.4, 0.35, 1.4)), s.mat("arenito"), (0, 4.07, 0))
s.save("pilar")

# --- natureza ------------------------------------------------------------------------------------
tree("arvore", "Arvore", "natureza/CommonTree_1", 1.0)
tree("arvore_pequena", "Arvore_pequena", "natureza/CommonTree_3", 0.75)
tree("pinheiro", "Pinheiro", "natureza/Pine_1", 1.0)
tree("arvore_torta", "Arvore_torta", "natureza/TwistedTree_1", 0.45, 0.6, 6.0)
tree("arvore_morta", "Arvore_morta", "natureza/DeadTree_1", 0.7, 0.35, 5.0)
tree("tronco_seco", "Tronco_seco", "natureza/DeadTree_3", 0.45, 0.35, 6.0)
kit_prop("arbusto", "Arbusto", "natureza/Bush_Common", 1.0, False)
kit_prop("arbusto_baixo", "Arbusto_baixo", "natureza/Bush_Common_Flowers", 0.8, False)
kit_prop("suculenta", "Suculenta", "natureza/Plant_1_Big", 0.9, False)
kit_prop("samambaia", "Samambaia", "natureza/Fern_1", 0.9, False)
kit_prop("grama", "Grama", "natureza/Grass_Wispy_Tall", 1.0, False)
kit_prop("flores", "Flores", "natureza/Flower_3_Group", 0.8, False)
kit_prop("toco", "Toco", "natureza/DeadTree_5", 0.25)
kit_prop("rocha", "Rocha", "natureza/Rock_Medium_2", 0.8)
kit_prop("rocha_grande", "Rocha_grande", "natureza/Rock_Medium_1", 1.3)
kit_prop("penhasco", "Penhasco", "natureza/Rock_Medium_3", 3.2)
kit_prop("pedregulhos", "Pedregulhos", "natureza/RockPath_Round_Wide", 1.2, False)
kit_prop("pedras", "Pedras", "natureza/RockPath_Square_Wide", 1.0, False)
kit_prop("pedrinhas", "Pedrinhas", "natureza/Pebble_Round_1", 1.5, False)

# --- objetos -------------------------------------------------------------------------------------
kit_prop("caixote", "Caixote", "objetos/Crate_Wooden", 0.8)
kit_prop("caixote_alto", "Caixote_alto", "vila/Prop_Crate", 1.0)
kit_prop("caixote_macas", "Caixote_macas", "objetos/FarmCrate_Apple", 1.0, False)
kit_prop("barril", "Barril", "objetos/Barrel", 1.0)
kit_prop("barril_vinho", "Barril_vinho", "objetos/Barrel_Apples", 1.0)
kit_prop("balde", "Balde", "objetos/Bucket_Wooden_1", 1.0, False)
kit_prop("cesto", "Cesto", "objetos/Bag", 1.0, False)
kit_prop("jarro", "Jarro", "objetos/Pot_1", 1.0, False)
kit_prop("vaso", "Vaso", "objetos/Vase_2", 1.0, False)
kit_prop("banquinho", "Banquinho", "objetos/Stool", 1.0, False)
kit_prop("cadeira", "Cadeira", "objetos/Chair_1", 1.0, False)
kit_prop("banco", "Banco", "objetos/Bench", 1.0)
kit_prop("mesa", "Mesa", "objetos/Table_Large", 1.0)
kit_prop("bau", "Bau", "objetos/Chest_Wood", 1.0)
kit_prop("bigorna", "Bigorna", "objetos/Anvil", 1.0)
kit_prop("bancada", "Bancada", "objetos/Workbench", 1.0)
kit_prop("caldeirao", "Caldeirao", "objetos/Cauldron", 1.0)
kit_prop("boneco_treino", "Boneco_treino", "objetos/Dummy", 1.0)
kit_prop("carroca", "Carroca", "vila/Prop_Wagon", 1.0)
kit_prop("cerca", "Cerca", "vila/Prop_WoodenFence_Single", 1.0)
kit_prop("grade_ferro", "Grade_ferro", "vila/Prop_MetalFence_Simple", 1.0)
kit_prop("barris", "Barris", "objetos/Barrel_Holder", 1.0)

s = Scene("Estandarte")
s.piece("objetos/Banner_1", (0, 2.6, 0), name="Banner")
s.save("estandarte")


def light_child(s, pos, energy=1.4, rng=5.0):
    s.node("Light", "OmniLight3D", ".", "transform = " + xf(pos), "light_color = Color(1, 0.7, 0.4, 1)", "light_energy = %g" % energy,
           "omni_range = %g" % rng)


s = Scene("Lanterna")
# presa na parede: o lado +Z encosta na parede e a lanterna sai para -Z
s.piece("objetos/Lantern_Wall", rot=math.pi, scale=0.55, name="Model")
light_child(s, (0, 0.2, -0.5))
s.save("lanterna")

s = Scene("Tocha")
s.piece("objetos/Torch_Metal", name="Model")
light_child(s, (0, 0.5, 0.25), 1.6, 6.0)
s.save("tocha")

s = Scene("Luz", "OmniLight3D", ["light_color = Color(1, 0.8, 0.55, 1)", "light_energy = 2.0", "omni_range = 8.0"])
s.save("luz")

# --- pão (cena do Tico) --------------------------------------------------------------------------
CRUST, CRUMB = (0.62, 0.36, 0.14), (0.93, 0.82, 0.6)


def bread_parts(s, whole):
    loaf = s.sub("CapsuleMesh", ("loaf",), "radius = 0.045\nheight = 0.2\nradial_segments = 12\nrings = 4")
    half = s.sub("CapsuleMesh", ("half",), "radius = 0.045\nheight = 0.11\nradial_segments = 12\nrings = 4")
    cut = s.sub("CylinderMesh", ("cut",), "top_radius = 0.04\nbottom_radius = 0.04\nheight = 0.004\nradial_segments = 12")
    parent = "."
    if whole:
        s.mesh("Inteiro", loaf, s.color(CRUST, 0.75), (0, 0, 0), (0, 0, math.pi / 2), (1, 1, 0.85))
        s.node("Metade", "Node3D", ".", "visible = false")
        parent = "Metade"
    s.mesh("Casca", half, s.color(CRUST, 0.75), (0, 0, 0), (0, 0, math.pi / 2), (1, 1, 0.85), parent=parent)
    s.mesh("Miolo", cut, s.color(CRUMB, 0.95), (0.055, 0, 0), (0, 0, math.pi / 2), parent=parent)


s = Scene("Pao")
bread_parts(s, True)
s.save("pao")
s = Scene("Meio_pao")
bread_parts(s, False)
s.save("meio_pao")

# --- gente e história ----------------------------------------------------------------------------
s = Scene("Morador")
fig = s.ext_res("Script", "res://world/figurante.gd")
s.node("Figure", "Node3D", ".", 'script = ExtResource("%s")' % fig, 'personagem = "Rogue_Hooded"', "transform = " + xf(scale=0.62))
s.node("Collision", "StaticBody3D", ".", "transform = " + xf((0, 0.9, 0)), "collision_layer = 4", "collision_mask = 0")
cap = s.sub("CapsuleShape3D", ("cap", 0.4, 1.8), "radius = 0.4\nheight = 1.8")
s.node("Shape", "CollisionShape3D", "Collision", 'shape = SubResource("%s")' % cap)
inter = s.ext_res("Script", "res://world/interactable.gd")
s.node("Talk", "Node3D", ".", "transform = " + xf((0, 1, 0)), 'script = ExtResource("%s")' % inter, 'prompt_text = "Falar com o morador"', 'text = "— ..."')
s.save("morador")

s = Scene("Inscricao", groups=AUTO)
inter = s.ext_res("Script", "res://world/interactable.gd")
s.root[2].extend(['script = ExtResource("%s")' % inter, 'prompt_text = "Ler a inscrição"', 'text = "Inscrição: «...»"'])
s.piece("natureza/Rock_Medium_2", (0, 0, 0.25), 0.3, (0.45, 0.8, 0.35), name="Stone")
s.mesh("Glyph", s.box((0.7, 0.5, 0.04)), s.color((1, 0.6, 0.3), 0.5, ((1, 0.55, 0.25), 2.5)), (0, 1.0, -0.25))
s.save("inscricao")

s = Scene("Fogueira")
inter = s.ext_res("Script", "res://world/interactable.gd")
s.root[2].extend(['script = ExtResource("%s")' % inter, "action = 1", 'prompt_text = "Descansar na fogueira"',
                  'text = "Descanso curto à beira do fogo. A vida volta inteira."'])
for i in range(9):
    a = i * 2 * math.pi / 9
    s.piece("natureza/Pebble_Round_%d" % (1 + i % 5), (math.cos(a) * 0.62, 0, math.sin(a) * 0.62), a, 1.0 + (i % 3) * 0.15, name="Stone")
for i in range(4):
    a = i * math.pi / 2 + 0.3
    s.mesh("Log", s.cyl(0.07, 0.08, 0.9, 8), s.mat("tabuas"), (math.cos(a) * 0.15, 0.22, math.sin(a) * 0.15), (0.95, -a, 0))
s.scene("Fire", "res://assets/vfx/fogo.tscn", (0, 0.15, 0))
s.save("fogueira")

s = Scene("Saida", groups=AUTO)
inter = s.ext_res("Script", "res://world/interactable.gd")
s.root[2].extend(['script = ExtResource("%s")' % inter, "action = 3", 'prompt_text = "Seguir viagem"', 'target_scene = "res://levels/ethera/ethera.tscn"'])
s.piece("vila/Wall_Arch", (0, 0, 0), name="Arch")
s.piece("vila/Wall_Arch", (0, 0, -0.3), name="ArchBack")
for x in (-1.15, 1.15):
    s.mesh("Pillar", s.box((0.4, 3.2, 0.5)), s.mat("arenito"), (x, 1.6, -0.15))
s.save("saida")

s = Scene("Lugar_heroi", "Marker3D")
spot = s.ext_res("Script", "res://world/hero_spot.gd")
s.root[2].extend(['script = ExtResource("%s")' % spot, 'hero_id = "naumfode"'])
s.save("lugar_heroi")

for name, enemies in (("grupo_escaravelhos", ["escaravelho_de_cinza", "escaravelho_de_cinza"]), ("grupo_sentinela", ["sentinela_estelar"]),
                      ("grupo_guardiao", ["ultimo_guardiao"])):
    s = Scene(name.capitalize())
    enc = s.ext_res("Script", "res://world/encounter.gd")
    s.root[2].append('script = ExtResource("%s")' % enc)
    for i, e in enumerate(enemies):
        s.scene("Inimigo%d" % (i + 1), "res://actors/enemies/%s.tscn" % e, (i * 2.2 - (len(enemies) - 1) * 1.1, 0.6, 0), math.pi)
    s.save(name)

print("peças:", len([f for f in os.listdir(OUT) if f.endswith(".tscn")]))
