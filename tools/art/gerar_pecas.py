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
PP = "res://assets/kits/polypizza/"
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

    def glb(self, path, pos=(0, 0, 0), rot=0.0, scale=1, name=None, parent="."):
        """Modelo .glb do poly.pizza (D041): 'Medieval-Village-Pack/Fantasy_Inn'."""
        rid = self.ext_res("PackedScene", PP + path + ".glb")
        base = name or path.split("/")[-1]
        self.node(self.unique(base) if parent == "." else base, None, parent, "transform = " + xf(pos, rot, scale), instance=rid)

    def scene(self, name, path, pos=(0, 0, 0), rot=0.0, scale=1, parent=".", *props):
        rid = self.ext_res("PackedScene", path)
        self.node(self.unique(name) if parent == "." else name, None, parent, "transform = " + xf(pos, rot, scale), *props, instance=rid)

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


def house(file, title, w, d, floors, walls, roof, gable, door_cell=None, chimney=True, door=True, front="", extra=None):
    """w x d células de 2 m. walls: estilo de parede por andar ('Wall_Plaster', 'Wall_UnevenBrick', 'Wall_Plaster_WoodGrid').
    D061: dá para entrar: a porta fica aberta, encostada na parede de dentro, e o tamanho vai nos metadados ("celulas",
    "porta") para o montar_interiores.gd mobiliar cada casa. front="arcos": a frente do térreo é toda em arcos abertos
    (oficina). Venezianas abertas e trepadeira mudam de casa para casa (sorteio pelo nome do arquivo)."""
    door_cell = w // 2 if door_cell is None else door_cell
    s = Scene(title, groups=AUTO, props=["metadata/celulas = Vector2i(%d, %d)" % (w, d), "metadata/porta = %d" % door_cell,
                                         "metadata/andares = %d" % len(walls), 'metadata/frente = "%s"' % front])
    hw, hd = float(w), float(d)
    luck = sum(ord(c) for c in file)
    shutters = luck % 3 != 0
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
            if f == 0 and front == "arcos":
                s.piece("vila/Wall_Arch", (x, y, -hd), math.pi)
            elif front_door:
                s.piece("vila/" + base + "_Door_Round", (x, y, -hd), math.pi)
                # a folha aberta para dentro, encostada na parede ao lado do vão (do lado que tem parede)
                if door_cell < w - 1:
                    s.piece("vila/Door_1_Round", (x + 0.55, y, -hd + 0.36), 0.0, name="Porta")
                else:
                    s.piece("vila/Door_1_Round", (x - 0.55, y, -hd + 0.36), math.pi, name="Porta")
            elif grid:
                s.piece("vila/Wall_Plaster_WoodGrid", (x, y, -hd), math.pi)
            else:
                s.piece("vila/" + base + "_Window_Wide_Round", (x, y, -hd), math.pi)
                s.piece("vila/Window_Wide_Round1", (x, y, -hd), math.pi)
                if shutters:
                    s.piece("vila/WindowShutters_Wide_Round_Open", (x, y, -hd), math.pi, name="Veneziana")
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
                    if shutters and f == 0:
                        s.piece("vila/WindowShutters_Wide_Round_Open", (sign * hw, y, z), rot, name="Veneziana")
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
    # trepadeira subindo por uma das quinas da frente (em metade das casas)
    if luck % 2 == 0 and front != "arcos":
        side = 1 if luck % 4 == 0 else -1
        s.piece("vila/Prop_Vine%d" % (1 + luck % 3 * 3 if luck % 3 != 2 else 5), (side * (hw - 0.05), 0, -hd - 0.12), math.pi, name="Trepadeira")
    if extra:
        extra(s)
    s.save(file)


house("casa", "Casa", 3, 3, 1, ["Wall_Plaster"], "Roof_RoundTiles_6x6", "Roof_Front_Brick6")


def interior_light(s, pos, energy=0.9, rng=4.5, color=(1.0, 0.68, 0.38)):
    s.node(s.unique("Luz"), "OmniLight3D", ".", "transform = " + xf(pos), "light_color = Color(%g, %g, %g, 1)" % color,
           "light_energy = %g" % energy, "omni_range = %g" % rng, "distance_fade_enabled = true", "distance_fade_begin = 30.0",
           "distance_fade_length = 10.0")


def padaria():
    """Padaria de verdade (D040; maior na D058): 4x5 células (8 x 10 m), dá para entrar. Fachada com três vitrines e a porta
    aberta; o balcão atravessa a loja e separa os fregueses (frente) da cozinha (fundos): forno de tijolo aceso, mesa de
    sovar com farinha, prateleiras de pão. O padeiro anda entre os pontos (Marker3D "Ponto*", a frente do marcador é -Z):
    atende no balcão, vira de costas no forno, na mesa e nas prateleiras. "PontoRoubo" é onde se pega um pão do balcão."""
    s = Scene("Padaria", groups=AUTO)
    hw, hd = 4.0, 5.0
    for i in range(4):
        for j in range(5):
            s.piece("vila/Floor_WoodDark", (-hw + 1.0 + i * 2.0, 0, -hd + 1.0 + j * 2.0))
    # fachada: vitrine, vitrine, porta (aberta para dentro), vitrine
    door_x = 1.0
    for i, kind in enumerate(("vitrine", "vitrine", "porta", "vitrine")):
        x = -hw + 1.0 + i * 2.0
        if kind == "porta":
            s.piece("vila/Wall_Plaster_Door_Round", (x, 0, -hd), math.pi)
            # a folha da porta aberta, encostada na parede de dentro (D060: o vão fica livre para gente passar)
            s.piece("vila/Door_1_Round", (x + 0.55, 0, -hd + 0.36), 0.0, name="Porta")
        else:
            s.piece("vila/Wall_Plaster_Window_Wide_Flat", (x, 0, -hd), math.pi)
            s.piece("vila/Window_Wide_Flat1", (x, 0, -hd), math.pi)
            s.piece("vila/WindowShutters_Wide_Flat_Open", (x, 0, -hd), math.pi)
    # fundos de tijolo e laterais com janelas
    for i in range(4):
        s.piece("vila/Wall_UnevenBrick_Straight", (-hw + 1.0 + i * 2.0, 0, hd), 0.0)
    for j in range(5):
        z = -hd + 1.0 + j * 2.0
        for sign, rot in ((1, math.pi / 2), (-1, -math.pi / 2)):
            if j in (0, 3):
                s.piece("vila/Wall_Plaster_Window_Wide_Round", (sign * hw, 0, z), rot)
                s.piece("vila/Window_Wide_Round1", (sign * hw, 0, z), rot)
            else:
                s.piece("vila/Wall_Plaster_Straight", (sign * hw, 0, z), rot)
    for cx, cz in ((hw, hd), (-hw, hd), (hw, -hd), (-hw, -hd)):
        s.piece("vila/Corner_Exterior_Wood", (cx, 0, cz))
    s.piece("vila/Roof_RoundTiles_8x10", (0, WALL_H, 0))
    s.piece("vila/Roof_Front_Brick8", (0, WALL_H, hd))
    s.piece("vila/Roof_Front_Brick8", (0, WALL_H, -hd), math.pi)
    # forno de tijolo no canto do fundo à esquerda, aceso, com a chaminé saindo pelo telhado
    brick = s.mat("tijolo_vermelho")
    ox, oz = -2.7, 4.1
    s.mesh("Forno", s.box((1.6, 1.0, 1.2)), brick, (ox, 0.5, oz))
    s.mesh("FornoCupula", s.sub("SphereMesh", ("cupula",), "radius = 0.8\nheight = 1.15\nradial_segments = 20\nrings = 10"), brick, (ox, 1.0, oz), scale=(1.0, 0.75, 0.75))
    s.mesh("FornoBoca", s.box((0.62, 0.42, 0.06)), s.color((0.06, 0.025, 0.015), 0.95), (ox, 0.62, oz - 0.58))
    s.mesh("Brasa", s.box((0.5, 0.06, 0.04)), s.color((0.9, 0.3, 0.08), 0.8, ((1.0, 0.35, 0.08), 3.0)), (ox, 0.44, oz - 0.62))
    s.mesh("FornoArco", s.box((0.78, 0.1, 0.12)), s.mat("arenito"), (ox, 0.88, oz - 0.6))
    s.mesh("FornoBase", s.box((0.78, 0.08, 0.14)), s.mat("arenito"), (ox, 0.38, oz - 0.6))
    s.scene("FogoDoForno", "res://assets/vfx/fogo.tscn", (ox, 0.44, oz - 0.65), 0.0, 0.16)
    s.mesh("Cano", s.cyl(0.18, 0.2, 2.2, 12), brick, (ox, 2.4, oz + 0.1))
    s.piece("vila/Prop_Chimney", (ox, WALL_H + 0.4, oz + 0.1), name="Chamine")
    s.piece("objetos/Peg_Rack", (ox + 1.4, 1.6, hd - 0.33), math.pi, name="Ganchos")
    s.piece("objetos/Bucket_Wooden_1", (ox + 1.1, 0, oz - 0.3), name="BaldeForno")
    # balcão atravessando a loja (x de -4 até 1.7); a passagem para os fundos fica à direita (x 2.5 a 4)
    wood = s.mat("tabuas")
    cz = -1.1
    s.mesh("Balcao", s.box((5.7, 0.92, 0.7)), wood, (-1.15, 0.46, cz))
    s.mesh("BalcaoTampo", s.box((5.85, 0.06, 0.86)), s.color((0.42, 0.26, 0.15), 0.7), (-1.15, 0.95, cz))
    s.mesh("BalcaoRodape", s.box((5.72, 0.1, 0.72)), s.color((0.25, 0.15, 0.09), 0.8), (-1.15, 0.05, cz))
    # o armário fica encostado na parede do fundo: a passagem do balcão para a cozinha (x 1,8 a 4) fica livre (D060:
    # o padeiro precisa sair correndo atrás de ladrão)
    s.piece("objetos/Cabinet", (-3.5, 0, 2.4), math.pi / 2, name="BalcaoArmario")
    for k, x in enumerate((-3.4, -3.0, -2.55, -1.8, -1.35, 0.3, 0.75)):
        s.scene("PaoBalcao", "res://world/props/pao.tscn", (x, 1.03, cz - 0.15 + (k % 2) * 0.18), 0.4 * k, 1.6)
    s.piece("objetos/Bucket_Wooden_1", (-0.6, 0.98, cz + 0.2), name="Cesto")
    for k in range(3):
        s.scene("PaoCesto", "res://world/props/pao.tscn", (-0.65 + k * 0.07, 1.23, cz + 0.18 + (k % 2) * 0.06), 0.9 * k, (1.4, 1.4, 1.4))
    s.piece("objetos/Table_Plate", (1.2, 1.0, cz), name="Prato")
    s.scene("MeioPao", "res://world/props/meio_pao.tscn", (1.2, 1.04, cz), 0.6, 1.6)
    # mesa de sovar no meio da cozinha, com farinha e massa
    s.piece("objetos/Table_Large", (0.3, 0, 2.2), math.pi / 2, name="MesaSovar")
    s.piece("objetos/Bag", (0.0, 0.95, 2.3), 0.4, 0.6, name="FarinhaMesa")
    s.scene("MassaMesa", "res://world/props/pao.tscn", (0.6, 1.0, 2.0), 0.3, 2.0)
    # estantes cheias de pão na parede do fundo (direita), onde o padeiro vai buscar (D061)
    for x in (1.25, 2.95):
        s.scene("EstantePao", "res://world/props/estante_paes.tscn", (x, 0, hd - 0.55), 0.0, 1.0)
    # sacos de farinha, barris, banquinho
    for k, (x, z) in enumerate(((3.3, 2.0), (3.5, 2.5), (3.15, 2.6))):
        s.piece("objetos/Bag", (x, 0, z), 0.7 * k, 0.8, name="Farinha")
    s.piece("objetos/Barrel", (3.45, 0, 4.25), name="Barril")
    s.piece("objetos/Stool", (-1.6, 0, 1.6), name="Banquinho")
    # lado dos fregueses: caixotes de pão embaixo das vitrines e um banco de espera
    for x in (-3.0, -1.0, 3.0):
        s.piece("objetos/FarmCrate_Empty", (x, 0.55, -4.35), math.pi, name="Caixote")
        s.piece("objetos/Barrel", (x, 0, -4.35), name="BarrilVitrine")
        for k in range(3):
            s.scene("PaoVitrine", "res://world/props/pao.tscn", (x - 0.2 + k * 0.2, 0.68, -4.35), 1.0 + k, 1.5)
    s.piece("objetos/Bench", (-3.4, 0, -2.6), math.pi / 2, name="BancoEspera")
    # luz de dentro (lanternas nas laterais, na frente e no fundo) e na porta
    for sign in (1, -1):
        for z in (-2.5, 2.5):
            s.scene("LanternaDentro", "res://world/props/lanterna.tscn", (sign * (hw - 0.33), 2.0, z), -sign * math.pi / 2)
    s.scene("LanternaPorta", "res://world/props/lanterna.tscn", (door_x + 1.2, 2.3, -hd - 0.12), 0.0)
    # placa presa na parede, em cima da porta (sem braço para fora: a padaria cabe no quarteirão)
    px = door_x
    s.mesh("Placa", s.box((1.3, 0.5, 0.06)), wood, (px, 2.78, -hd - 0.16))
    font = s.ext_res("FontFile", "res://assets/fonts/cinzel.ttf")
    s.node(s.unique("PlacaTexto"), "Label3D", ".", "transform = " + xf((px, 2.76, -hd - 0.2), math.pi),
           "pixel_size = 0.0042", 'text = "Padaria"', 'font = ExtResource("%s")' % font, "font_size = 48",
           "modulate = Color(0.25, 0.13, 0.06, 1)", "outline_size = 0", "double_sided = false")
    s.scene("PaoPlaca", "res://world/props/pao.tscn", (px, 3.1, -hd - 0.2), 0.0, 2.2)
    # --- D061: a padaria de verdade (antes era "exemplo ruim") ---------------------------------------------
    bg = "Baked-Goods/"
    # no balcão: tortas, rolinhos de canela, croissants, um sininho e o pote de moedas
    s.glb(bg + "Pie_Apple", (-2.0, 0.98, cz - 0.05), 0.3, 0.26, name="Torta")
    s.glb(bg + "Pie_Cherry", (0.05, 0.98, cz - 0.1), 1.2, 0.26, name="Torta")
    for k in range(4):
        s.glb(bg + "Cinnamon_Roll", (-0.95 + (k % 2) * 0.14, 0.98, cz - 0.18 + (k // 2) * 0.16), k, 0.28, name="Rolinho")
    s.piece("objetos/Coin_Pile", (1.5, 0.98, cz + 0.12), 0.0, 0.8, name="Moedas")
    s.piece("objetos/CandleStick", (-3.6, 0.98, cz + 0.1), 0.0, 1.0, name="Vela")
    # vitrine dos fregueses: mesa baixa cheia de doces, no meio da loja
    s.piece("objetos/Table_Large", (-2.2, 0, -3.15), 0.0, (0.62, 0.95, 0.75), name="MesaVitrine")
    vit_y = 0.78
    for k, (item, sc) in enumerate((("Pie_Apple", 0.24), ("Croissant", 0.27), ("Muffin", 0.27), ("Croissant", 0.27), ("Pie_Cherry", 0.24),
                                    ("Muffin", 0.27), ("Cinnamon_Roll", 0.28), ("Cookie", 0.3))):
        s.glb(bg + item, (-2.95 + (k % 4) * 0.48, vit_y, -3.3 + (k // 4) * 0.3), 0.7 * k, sc, name="Doce")
    for k in range(3):
        s.glb(bg + "Baguette", (-3.75, 0.2 + k * 0.03, -1.8 - k * 0.12), 0.25 * k, 0.45, name="Baguete")
    s.piece("objetos/Barrel", (-3.6, 0, -1.9), 0.0, 0.7, name="BarrilBaguete")
    # luz: dois lustres de vela (fregueses e cozinha)
    s.piece("objetos/Chandelier", (-1.0, 3.05, -2.7), 0.0, 1.0, name="Lustre")
    s.piece("objetos/Chandelier", (0.3, 3.05, 2.2), 0.4, 0.9, name="Lustre")
    interior_light(s, (-1.0, 2.2, -2.7), 1.5, 7.0, (1.0, 0.8, 0.55))
    interior_light(s, (0.3, 2.2, 2.2), 1.3, 6.5, (1.0, 0.8, 0.55))
    # lousa do cardápio na parede da esquerda
    board_x = -hw + 0.34
    s.mesh("Lousa", s.box((0.05, 0.95, 1.25)), s.color((0.12, 0.13, 0.12), 0.95), (board_x, 1.75, -3.2))
    s.mesh("LousaMoldura", s.box((0.04, 1.05, 1.35)), wood, (board_x - 0.01, 1.75, -3.2))
    s.node("Cardapio", "Label3D", ".", "transform = " + xf((board_x + 0.035, 1.75, -3.2), math.pi / 2),
           "pixel_size = 0.0028", 'text = "PÃO DO DIA\n\nFilão ....... 2 cobres\nBroa ........ 1 cobre\nTorta ....... 5 cobres\nRosca ...... 3 cobres\n\nFIADO: NÃO"',
           'font = ExtResource("%s")' % s.ext_res("FontFile", "res://assets/fonts/lato.ttf"), "font_size = 34",
           "modulate = Color(0.95, 0.95, 0.9, 1)", "outline_size = 0", "double_sided = false")
    # lenha empilhada do lado do forno e a pá de forno encostada
    log_mat = s.color((0.45, 0.28, 0.15), 0.95)
    for k in range(7):
        row, col = divmod(k, 3)
        s.mesh("Lenha", s.cyl(0.08, 0.08, 0.75, 8), log_mat, (ox + 1.25 + col * 0.17 - row * 0.05, 0.08 + row * 0.15, oz - 0.1), (math.pi / 2, 0, 0))
    s.mesh("PaCabo", s.box((0.05, 1.7, 0.05)), wood, (ox - 1.05, 0.9, oz - 0.7), (0.2, 0, 0.12))
    s.mesh("PaPa", s.box((0.32, 0.03, 0.4)), wood, (ox - 0.95, 0.08, oz - 0.55), (0.0, 0.1, 0.0))
    # farinha no ar em cima da mesa de sovar (poeirinha subindo devagar)
    dust_mat = s.sub("StandardMaterial3D", ("poeira",), "transparency = 1\nshading_mode = 0\nalbedo_color = Color(1, 0.98, 0.92, 0.35)\nbillboard_mode = 3\nparticles_anim_h_frames = 1\nparticles_anim_v_frames = 1")
    dust_mesh = s.sub("QuadMesh", ("poeira_q",), "size = Vector2(0.025, 0.025)\nmaterial = SubResource(\"%s\")" % dust_mat)
    dust_proc = s.sub("ParticleProcessMaterial", ("poeira_p",), "emission_shape = 3\nemission_box_extents = Vector3(0.6, 0.15, 0.35)\ndirection = Vector3(0, 1, 0)\nspread = 60.0\ninitial_velocity_min = 0.03\ninitial_velocity_max = 0.1\ngravity = Vector3(0, 0.02, 0)\nscale_min = 0.5\nscale_max = 1.4")
    s.node("PoeiraDeFarinha", "GPUParticles3D", ".", "transform = " + xf((0.3, 1.05, 2.2)), "amount = 40", "lifetime = 4.0",
           'process_material = SubResource("%s")' % dust_proc, 'draw_pass_1 = SubResource("%s")' % dust_mesh)
    # panelas e utensílios pendurados na parede da cozinha
    s.piece("objetos/Peg_Rack", (-hw + 0.33, 1.7, 2.4), math.pi / 2, name="Ganchos")
    s.piece("objetos/Pot_1", (-hw + 0.45, 1.45, 2.1), 0.0, 0.6, name="Panela")
    s.piece("objetos/Bucket_Wooden_1", (-hw + 0.45, 1.35, 2.7), 0.0, 0.6, name="Balde")
    # --- fachada: toldos listrados em cima das vitrines, floreiras e o cavalete "Pão quente!" -----------
    cream, red = s.color((0.95, 0.9, 0.78), 0.9), s.color((0.72, 0.18, 0.15), 0.9)
    for i, kind in enumerate(("vitrine", "vitrine", "porta", "vitrine")):
        x = -hw + 1.0 + i * 2.0
        if kind == "porta":
            continue
        for k in range(6):
            s.mesh("Toldo", s.box((0.32, 0.03, 1.0)), cream if k % 2 == 0 else red, (x - 0.8 + k * 0.32, 2.42, -hd - 0.48), (-0.38, 0, 0))
        s.mesh("ToldoFranja", s.box((1.92, 0.12, 0.03)), red, (x, 2.2, -hd - 0.95))
        s.mesh("Floreira", s.box((1.4, 0.24, 0.3)), wood, (x, 0.95, -hd - 0.3))
        s.mesh("Terra", s.box((1.3, 0.04, 0.22)), s.color((0.3, 0.2, 0.12), 1.0), (x, 1.08, -hd - 0.3))
        for k in range(3):
            s.piece("natureza/Flower_3_Group", (x - 0.45 + k * 0.45, 1.08, -hd - 0.3), 0.8 * k, 0.45, name="Flores")
    s.mesh("CavaleteA", s.box((0.6, 0.9, 0.03)), s.color((0.12, 0.13, 0.12), 0.95), (door_x + 1.55, 0.48, -hd - 1.0), (0.25, 0.2, 0))
    s.mesh("CavaleteB", s.box((0.6, 0.9, 0.03)), wood, (door_x + 1.55, 0.48, -hd - 0.62), (-0.25, 0.2, 0))
    s.node("CavaleteTexto", "Label3D", ".", "transform = " + xf((door_x + 1.53, 0.52, -hd - 1.06), (0.25, math.pi + 0.2, 0)),
           "pixel_size = 0.0032", 'text = "PÃO\nQUENTE!"', 'font = ExtResource("%s")' % s.ext_res("FontFile", "res://assets/fonts/cinzel.ttf"),
           "font_size = 40", "modulate = Color(0.98, 0.95, 0.85, 1)", "outline_size = 0", "double_sided = false")
    s.piece("objetos/Bench", (door_x - 2.6, 0, -hd - 0.6), 0.0, 0.7, name="BancoFora")
    s.piece("objetos/Bag", (door_x - 2.9, 0.38, -hd - 0.6), 0.5, 0.6, name="CestaFora")
    for k in range(3):
        s.glb(bg + "Bread", (door_x - 2.35 + k * 0.2, 0.4, -hd - 0.6), 0.6 * k, 0.32, name="PaoFora")
    # pontos do padeiro (a frente do marcador é -Z): balcão olhando os fregueses; o resto de costas para eles
    for name, pos, rot in (("PontoBalcao", (-1.4, 0, -0.35), 0.0), ("PontoForno", (ox, 0, oz - 1.25), math.pi),
                           ("PontoMesa", (0.3, 0, 1.15), math.pi), ("PontoPrateleira", (2.1, 0, hd - 1.15), math.pi),
                           ("PontoRoubo", (-3.0, 0, cz - 0.75), 0.0)):
        s.node(name, "Marker3D", ".", "transform = " + xf(pos, rot))
    s.save("padaria")

padaria()


# --- cidade (D041): prédios do Medieval Village Pack (Quaternius) e o resto do poly.pizza ------------------------
MV = "Medieval-Village-Pack/"
K_MV = 3.0  # o pacote vem 3x menor que o mundo (porta de 0,72 -> 2,2 m)
GD = "Low-Poly-Outdoor-Garden-Decorations/"
FOOD = "Food-Kit/"


def sign(s, text, pos, rot=0.0, width=1.0):
    """Placa pendurada num braço de madeira (frente em -Z), com o nome do lugar."""
    wood = s.mat("tabuas")
    x, y, z = pos
    s.mesh("PlacaBraco", s.box((0.08, 0.08, 0.9)), wood, (x, y + 0.62, z - 0.45), (0, rot, 0))
    s.mesh("Placa", s.box((width, 0.45, 0.06)), wood, (x, y, z - 0.8), (0, rot, 0))
    font = s.ext_res("FontFile", "res://assets/fonts/cinzel.ttf")
    for side, r in ((-1, math.pi), (1, 0.0)):
        s.node(s.unique("PlacaTexto"), "Label3D", ".", "transform = " + xf((x, y - 0.02, z - 0.8 + side * 0.035), rot + r),
               "pixel_size = 0.0035", 'text = "%s"' % text, 'font = ExtResource("%s")' % font, "font_size = 44",
               "modulate = Color(0.25, 0.13, 0.06, 1)", "outline_size = 0", "double_sided = false")


def building(file, title, model, label=None, label_pos=(1.6, 2.4, -0.2), extra=None):
    """Prédio do Medieval Village Pack, virado para -Z (a porta do pacote é +Z)."""
    s = Scene(title, groups=AUTO)
    s.glb(MV + model, (0, 0, 0), math.pi, K_MV, name="Modelo")
    if label:
        sign(s, label, label_pos)
    if extra:
        extra(s)
    s.save(file)


def _forge(s):
    s.piece("objetos/Anvil", (-2.2, 0, -5.2), 0.4, 1.2, name="Bigorna")
    s.piece("objetos/WeaponStand", (2.6, 0, -5.0), math.pi, 1.0, name="Armas")
    s.piece("objetos/Whetstone", (-3.6, 0, -4.4), 0.2, 1.0, name="Rebolo")
    s.piece("objetos/Barrel", (-4.6, 0, -3.6), 0.0, 1.0, name="Barril")
    s.glb("Ultimate-RPG-Items-Bundle/Shield_Round", (4.0, 1.2, -4.3), math.pi, 0.5, name="Escudo")
    s.glb("Ultimate-RPG-Items-Bundle/Shield_2", (4.8, 1.2, -4.3), math.pi, 0.5, name="Escudo")
    s.scene("Brasa", "res://assets/vfx/fogo.tscn", (-3.0, 0.2, -3.8), 0.0, 0.35)


def _stable(s):
    for k in range(6):
        s.glb(MV + "Fence", (-8.5 + k * 2.4, 0, -7.5), 0.0, K_MV, name="Cerca")
    for k in range(2):
        s.glb(MV + "Fence", (-9.7, 0, -6.3 + k * 2.4), math.pi / 2, K_MV, name="Cerca")
    s.glb("Farm-Animal-Pack/Horse", (-6.0, 0, -5.4), 1.9, 0.25, name="Cavalo")
    s.glb("Farm-Animal-Pack/Horse", (-3.2, 0, -6.2), -0.6, 0.24, name="Cavalo")
    for k, (x, z) in enumerate(((-8.2, -4.6), (-7.6, -4.2), (-8.6, -3.8))):
        s.glb(MV + "Hay", (x, 0, z), 0.4 * k, K_MV * 1.4, name="Feno")
    s.glb(MV + "Cart", (3.8, 0, -5.6), 2.4, K_MV, name="Carroca")


def _mill(s):
    for k, (x, z) in enumerate(((3.6, -3.6), (4.2, -2.8), (3.2, -2.4))):
        s.glb(MV + "Bags", (x, 0, z), k, K_MV, name="Sacos")
    s.glb(MV + "Hay", (-3.8, 0, -3.0), 0.0, K_MV * 1.4, name="Feno")


def _barracks(s):
    s.piece("objetos/WeaponStand", (2.4, 0, -4.2), math.pi, 1.0, name="Armas")
    s.piece("objetos/Dummy", (-2.6, 0, -4.8), 0.3, 1.0, name="Boneco")
    s.piece("objetos/Banner_1", (1.4, 0, -3.4), math.pi, 1.0, name="Estandarte")


# D061: a estalagem e o ferreiro eram modelos inteiriços (sem interior); agora são casas de entrar, do mesmo porte
house("estalagem", "Estalagem", 4, 6, 2, ["Wall_UnevenBrick", "Wall_Plaster_WoodGrid"], "Roof_RoundTiles_8x12", "Roof_Front_Brick8", 1,
      extra=lambda s: sign(s, "Estalagem", (1.2, 2.7, -6.0), 0.0, 1.3))


def _forge_inside(s):
    """A forja do ferreiro (fogo, coifa, chaminé saindo pelo telhado) no fundo da oficina."""
    sign(s, "Ferreiro", (2.4, 2.7, -4.0), 0.0, 1.2)
    s.scene("Forja", "res://world/props/forja.tscn", (-2.2, 0, 2.9), 0.0, 1.0)


house("ferreiro", "Ferreiro", 4, 4, 1, ["Wall_UnevenBrick"], "Roof_RoundTiles_8x8", "Roof_Front_Brick8", 1, front="arcos",
      extra=_forge_inside)
building("estabulo", "Estabulo", "Fantasy_Stable", "Estábulo", (4.5, 2.4, -4.0), _stable)
building("moinho", "Moinho", "Mill", None, extra=_mill)
building("serraria", "Serraria", "Fantasy_Sawmill")
building("guarita", "Guarita", "Fantasy_Barracks", None, extra=_barracks)
building("torre_sino", "Torre_sino", "Bell_Tower")
house("casa_enxaimel", "Casa_enxaimel", 3, 3, 2, ["Wall_UnevenBrick", "Wall_Plaster_WoodGrid"], "Roof_RoundTiles_6x6", "Roof_Front_Brick6", 1)
house("casa_enxaimel2", "Casa_enxaimel2", 3, 4, 2, ["Wall_Plaster", "Wall_Plaster_WoodGrid"], "Roof_RoundTiles_6x8", "Roof_Front_Brick6", 1)

# poço de pedra com telhado (praças menores) e carroça
s = Scene("Poco_telhado", groups=AUTO)
s.glb(MV + "Well", (0, 0.75, 0), math.pi, K_MV, name="Modelo")
s.save("poco_telhado")


COUNTER_Y = 0.765  # tampo do balcão da Market_Stand_2 (medido nos vértices)


CRATE_NAMES = {"Apple": "maca", "Pear": "pera", "Lemon": "limao", "Cabbage": "couve", "Carrot": "cenoura", "Onion": "cebola",
               "Fish": "peixe"}


def crate_scene(item, scale, lying=False):
    """Caixote raso cheio de uma mercadoria (D049): uma peça própria (world/props/caixa_<nome>.tscn), para o editor
    separar a banca e mover o caixote inteiro. Devolve o caminho da peça."""
    file = "caixa_" + CRATE_NAMES[item.split("/")[-1]]
    s = Scene(file.capitalize(), groups=AUTO)
    crate_of(s, item, scale, (0, 0, 0), lying)
    s.save(file)
    return "res://world/props/%s.tscn" % file


def crate_of(s, item, scale, at, lying=False):
    """Caixote raso cheio de uma mercadoria (duas camadas), com o fundo em `at`."""
    x, y, z = at
    s.piece("objetos/FarmCrate_Empty", (x, y, z), 0.0, 1.0, name="Caixote")
    k = 0
    for layer in range(2):
        for i in range(5):
            for j in range(3):
                jitter = ((k * 37) % 7 - 3) * 0.006
                rot = (math.pi / 2, k * 1.7, 0) if lying else (0, k * 1.7, 0)
                s.glb(item, (x - 0.24 + i * 0.12 + jitter + layer * 0.06, y + 0.06 + layer * 0.06, z - 0.11 + j * 0.11 - jitter), rot, scale, name="Mercadoria")
                k += 1


def stall(file, title, crates=(), loaves=()):
    """Banca de feira: caixotes cheios em cima do balcão (frutas, verduras) ou pães enfileirados na tábua."""
    s = Scene(title, groups=AUTO)
    s.glb(MV + "Market_Stand_2", (0, 0, 0), math.pi, K_MV, name="Banca")
    for k, (item, sc, lying) in enumerate(crates):
        s.scene("Caixa_" + CRATE_NAMES[item.split("/")[-1]], crate_scene(item, sc, lying), (-0.85 + k * 0.85, COUNTER_Y, -0.25))
    for k, (item, sc, rot) in enumerate(loaves):
        s.glb(item, (-1.0 + (k % 6) * 0.4, COUNTER_Y, -0.45 + (k // 6) * 0.35), (0, rot + k * 0.3, 0), sc, name="Mercadoria")
    for x in (-1.6, 1.6):
        s.piece("objetos/FarmCrate_Empty", (x, 0, -1.1), 0.2 * x, 1.0, name="CaixoteChao")
    s.save(file)


stall("banca_frutas", "Banca_frutas", crates=[(FOOD + "Apple", 0.45, False), (FOOD + "Pear", 0.45, False), (FOOD + "Lemon", 0.45, False)])
stall("banca_verduras", "Banca_verduras", crates=[(FOOD + "Cabbage", 0.42, False), (FOOD + "Carrot", 0.35, True), (FOOD + "Onion", 0.45, False)])
stall("banca_paes", "Banca_paes", loaves=[("Baked-Goods/Bread", 0.45, 0.0), ("Baked-Goods/Baguette", 0.42, 1.57), ("Baked-Goods/Bread_Roll", 0.5, 0.0),
                                           ("Baked-Goods/Pie_Apple", 0.32, 0.0), ("Baked-Goods/Croissant", 0.4, 0.4), ("Baked-Goods/Bread", 0.45, 0.6)] * 2)
stall("banca_peixe", "Banca_peixe", crates=[(FOOD + "Fish", 0.55, False), (FOOD + "Fish", 0.55, False), (FOOD + "Onion", 0.45, False)])
s = Scene("Carroca_feira", groups=AUTO)
s.glb(MV + "Cart", (0, 0, 0), math.pi, K_MV, name="Carroca")
for k, (x, z) in enumerate(((-0.25, -0.2), (0.15, 0.1), (-0.1, 0.35), (0.3, -0.3))):
    s.glb(FOOD + ("Apple", "Pumpkin", "Cabbage", "Pear")[k], (x, 1.05, z), k, 0.45, name="Mercadoria")
s.save("carroca_feira")

# --- praça ----------------------------------------------------------------------------------------------
s = Scene("Chafariz", groups=AUTO)
stone = s.mat("pedra_poco")
for k, (r, h) in enumerate(((6.4, 0.18), (5.9, 0.36))):
    s.mesh("Degrau", s.cyl(r, r + 0.06, h, 40), s.mat("calcada"), (0, h / 2, 0))
# bacia: mureta de 16 lados (oca), com o fundo escuro mais baixo e a água à vista
for k in range(16):
    ang = k * 2 * math.pi / 16
    s.mesh("Mureta", s.box((2 * 3.85 * math.tan(math.pi / 16) + 0.06, 0.75, 0.38)), stone,
           (math.sin(ang) * 3.85, 0.36 + 0.375, math.cos(ang) * 3.85), (0, ang, 0))
    s.mesh("Capa", s.box((2 * 3.85 * math.tan(math.pi / 16) + 0.1, 0.08, 0.5)), s.mat("calcada"),
           (math.sin(ang) * 3.85, 1.15, math.cos(ang) * 3.85), (0, ang, 0))
s.mesh("Fundo", s.cyl(3.7, 3.7, 0.3, 32), s.color((0.14, 0.2, 0.2), 0.9), (0, 0.51, 0))
s.glb(GD + "Water_Fountain", (0, 0.92 + 1.25 * 2.4, 0), 0.0, 2.4, name="Fonte")
s.scene("Agua", "res://assets/vfx/agua_chafariz.tscn", (0, 0, 0))
# quatro lanternas na beirada da bacia (de noite o chafariz não vira uma sombra no meio da praça)
for k in range(4):
    ang = math.pi / 4 + k * math.pi / 2
    at = (math.sin(ang) * 3.85, 1.19, math.cos(ang) * 3.85)
    s.glb("Halloween-Bits/Lantern", at, ang, 0.6, name="Lanterna")
    s.node("Luz%d" % k, "OmniLight3D", ".", "transform = " + xf((at[0], at[1] + 0.45, at[2])), "light_color = Color(1, 0.72, 0.42, 1)",
           "light_energy = 0.9", "omni_range = 5.5")
s.save("chafariz")

s = Scene("Estatua", groups=AUTO)
s.mesh("Pedestal", s.box((1.4, 1.2, 1.4)), s.mat("pedra_poco"), (0, 0.6, 0))
s.mesh("Topo", s.box((1.6, 0.15, 1.6)), s.mat("calcada"), (0, 1.27, 0))
s.glb(GD + "Statue_3", (0, 1.35 + 1.34 * 1.3, 0), math.pi, 1.3, name="Figura")
s.save("estatua")

s = Scene("Poste")
# haste de ferro fina, braço curto e a lanterna em cima (3,2 m), luz quente sem sombra
iron = s.color((0.12, 0.11, 0.1), 0.5)
s.mesh("Base", s.cyl(0.16, 0.2, 0.3, 10), s.mat("pedra_poco"), (0, 0.15, 0))
s.mesh("Haste", s.cyl(0.05, 0.065, 2.7, 10), iron, (0, 1.6, 0))
s.mesh("Topo", s.cyl(0.11, 0.08, 0.08, 10), iron, (0, 2.95, 0))
s.glb(GD + "Lamp", (0, 2.99, 0), 0.0, 0.62, name="Lanterna")
s.mesh("Luz", s.sub("SphereMesh", ("bulbo",), "radius = 0.07\nheight = 0.14"), s.color((1, 0.85, 0.6), 0.5, ((1, 0.75, 0.45), 5.0)), (0, 3.2, 0))
s.node("Light", "OmniLight3D", ".", "transform = " + xf((0, 3.2, 0)), "light_color = Color(1, 0.74, 0.45, 1)", "light_energy = 1.5",
       "omni_range = 9.0", "omni_attenuation = 1.3")
s.body(("cyl", (0.12, 3.0)), (0, 1.5, 0))
s.save("poste")

s = Scene("Canteiro", groups=AUTO)
s.glb(GD + "Flower_Bed_2", (0, 0.38, 0), 0.0, 1.0, name="Borda")
s.mesh("Terra", s.cyl(1.55, 1.55, 0.08, 8), s.color((0.32, 0.22, 0.14), 1.0), (0, 0.42, 0), (0, math.pi / 8, 0))
s.glb(GD + "Flowers", (0.9, 0.4 + 0.63 * 0.55, 0.5), 0.0, 0.55, name="Flores")
s.glb(GD + "Flowers", (-0.8, 0.4 + 0.63 * 0.5, -0.6), 1.2, 0.5, name="Flores")
s.scene("Arvore", "res://world/props/arvore_pequena.tscn", (0, 0.42, 0), 0.4, 0.9)
s.save("canteiro")

s = Scene("Banco_praca", groups=AUTO)
s.glb(GD + "Bench", (0, 0.35 * 1.1, 0), 0.0, 1.1, name="Modelo")
s.save("banco_praca")

s = Scene("Pelourinho", groups=AUTO)
s.mesh("Base", s.box((1.6, 0.25, 1.6)), s.mat("tabuas"), (0, 0.12, 0))
s.glb("Medieval-Torture-Devices/Pilory", (0, 0.25, 0), math.pi, 1.3, name="Modelo")
s.save("pelourinho")

for name, path, sc in (("cavalo", "Farm-Animal-Pack/Horse", 0.25), ("vaca", "Farm-Animal-Pack/Cow", 0.25), ("porco", "Farm-Animal-Pack/Pig", 0.15),
                       ("galinha", "Animal-Kit/Chicken", 0.8), ("cachorro", "Animal-Kit/Dog", 0.42), ("gato", "Animal-Kit/Cat", 0.4)):
    s = Scene(name.capitalize())
    s.glb(path, (0, 0, 0), 0.0, sc, name="Modelo")
    s.save(name)

s = Scene("Horta")
for k in range(3):
    s.glb(FOOD + ("Cabbage", "Carrot", "Pumpkin")[k % 3], (-0.5 + k * 0.5, 0, 0), k * 1.3, 0.9, name="Verdura")
s.save("horta")

for k, model in enumerate(("Wooden_Sign_3", "Wooden_Sign_7", "Wooden_Sign_2")):
    s = Scene("Placa_rua%d" % (k + 1), groups=AUTO)
    s.glb("Signs-pack/" + model, (0, 0, 0), math.pi, 1.2, name="Modelo")
    s.save("placa_rua%d" % (k + 1))
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

# --- peças de interior (D061): a frente de cada uma é -Z, o fundo (+Z) encosta na parede ------------------
s = Scene("Lareira", groups=AUTO)
stone, brick, wood = s.mat("arenito"), s.mat("tijolo_vermelho"), s.mat("tabuas")
s.mesh("Base", s.box((1.7, 0.35, 0.9)), stone, (0, 0.175, 0))
s.mesh("Fundo", s.box((1.7, 1.5, 0.3)), brick, (0, 1.1, 0.3))
s.mesh("LadoE", s.box((0.25, 0.85, 0.6)), brick, (-0.72, 0.77, -0.05))
s.mesh("LadoD", s.box((0.25, 0.85, 0.6)), brick, (0.72, 0.77, -0.05))
s.mesh("Arco", s.box((1.7, 0.3, 0.62)), stone, (0, 1.32, -0.04))
s.mesh("Prateleira", s.box((1.9, 0.08, 0.36)), wood, (0, 1.52, -0.12))
s.mesh("Coifa", s.box((1.2, 1.4, 0.45)), brick, (0, 2.25, 0.2))
s.mesh("Brasas", s.box((0.9, 0.06, 0.4)), s.color((0.85, 0.28, 0.07), 0.8, ((1.0, 0.35, 0.08), 3.0)), (0, 0.38, -0.05))
s.scene("Fogo", "res://assets/vfx/fogo.tscn", (0, 0.38, -0.05), 0.0, 0.22)
s.piece("objetos/Cauldron", (0.25, 0.35, -0.08), 0.0, 0.45, name="Panela")
s.piece("objetos/CandleStick", (-0.6, 1.56, -0.12), 0.0, 1.0, name="Vela")
s.piece("objetos/Vase_4", (0.55, 1.56, -0.12), 0.0, 0.5, name="Pote")
interior_light(s, (0, 0.8, -0.7), 1.1, 4.0, (1.0, 0.55, 0.25))
s.save("lareira")

s = Scene("Forja", groups=AUTO)
stone, brick = s.mat("arenito"), s.mat("tijolo_vermelho")
s.mesh("Base", s.box((1.8, 0.9, 1.3)), brick, (0, 0.45, 0))
s.mesh("Borda", s.box((1.9, 0.12, 1.4)), stone, (0, 0.95, 0))
s.mesh("Carvao", s.box((1.1, 0.08, 0.7)), s.color((0.9, 0.25, 0.05), 0.8, ((1.0, 0.3, 0.05), 4.0)), (0, 1.0, -0.1))
s.scene("Fogo", "res://assets/vfx/fogo.tscn", (0, 1.0, -0.1), 0.0, 0.3)
s.mesh("Coifa", s.box((1.7, 0.9, 1.2)), brick, (0, 2.6, 0.1))
s.mesh("Cano", s.box((0.7, 3.6, 0.7)), brick, (0, 4.8, 0.3))
s.piece("objetos/Bucket_Metal", (1.25, 0, -0.3), 0.0, 1.0, name="Balde")
interior_light(s, (0, 1.4, -0.9), 2.2, 7.0, (1.0, 0.45, 0.15))
s.save("forja")

s = Scene("Balcao", groups=AUTO)
wood = s.mat("tabuas")
s.mesh("Corpo", s.box((2.4, 0.92, 0.7)), wood, (0, 0.46, 0))
s.mesh("Tampo", s.box((2.55, 0.06, 0.84)), s.color((0.42, 0.26, 0.15), 0.7), (0, 0.95, 0))
s.mesh("Rodape", s.box((2.42, 0.1, 0.72)), s.color((0.25, 0.15, 0.09), 0.8), (0, 0.05, 0))
for k in range(3):
    s.mesh("Painel", s.box((0.6, 0.55, 0.02)), s.color((0.33, 0.2, 0.11), 0.8), (-0.75 + k * 0.75, 0.48, -0.36))
s.save("balcao")

for file, title, rgb, edge in (("tapete", "Tapete", (0.55, 0.16, 0.12), (0.8, 0.6, 0.25)), ("tapete_azul", "Tapete_azul", (0.18, 0.25, 0.45), (0.85, 0.75, 0.5)),
                               ("tapete_verde", "Tapete_verde", (0.22, 0.38, 0.2), (0.75, 0.62, 0.35))):
    s = Scene(title)
    s.mesh("Borda", s.box((2.2, 0.015, 1.5)), s.color(edge, 1.0), (0, 0.008, 0))
    s.mesh("Meio", s.box((1.95, 0.02, 1.25)), s.color(rgb, 1.0), (0, 0.012, 0))
    s.mesh("Losango", s.box((0.7, 0.024, 0.7)), s.color(edge, 1.0), (0, 0.013, 0), (0, math.pi / 4, 0))
    s.save(file)

s = Scene("Altar", groups=AUTO)
stone = s.mat("arenito")
s.mesh("Pedra", s.box((1.8, 1.0, 0.8)), stone, (0, 0.5, 0))
s.mesh("Toalha", s.box((1.86, 0.03, 0.86)), s.color((0.92, 0.9, 0.82), 1.0), (0, 1.01, 0))
s.mesh("Faixa", s.box((0.5, 0.55, 0.02)), s.color((0.55, 0.2, 0.55), 1.0), (0, 0.75, -0.42))
for x in (-0.65, 0.65):
    s.piece("objetos/CandleStick_Triple", (x, 1.02, 0.05), 0.0, 1.0, name="Candelabro")
s.piece("objetos/Chalice", (0, 1.02, 0.0), 0.0, 1.2, name="Calice")
s.piece("objetos/Book_5", (0.25, 1.03, -0.15), 0.4, 1.0, name="Livro")
interior_light(s, (0, 1.6, -0.6), 0.9, 4.0, (1.0, 0.78, 0.5))
s.save("altar")


def shelf_unit(s, width=1.6, depth=0.42, levels=(0.08, 0.68, 1.28, 1.88)):
    """Estante de tábuas (fundo encostado na parede, +Z); devolve as alturas de cima de cada prateleira."""
    wood = s.mat("tabuas")
    top = levels[-1] + 0.4
    for x in (-width / 2, width / 2):
        s.mesh("Lado", s.box((0.06, top, depth)), wood, (x, top / 2, 0))
    s.mesh("Fundo", s.box((width, top, 0.03)), s.color((0.3, 0.19, 0.11), 0.9), (0, top / 2, depth / 2 - 0.015))
    for y in levels:
        s.mesh("Tabua", s.box((width, 0.05, depth)), wood, (0, y, 0))
    return [y + 0.025 for y in levels]


def shelf_goods(file, title, fill):
    s = Scene(title, groups=AUTO)
    tops = shelf_unit(s)
    for level, y in enumerate(tops[1:] if fill != "paes" else tops):
        fill_level(s, fill, level, y)
    s.save(file)


CLOTH = [(0.75, 0.2, 0.18), (0.2, 0.35, 0.7), (0.85, 0.7, 0.3), (0.3, 0.55, 0.3), (0.55, 0.3, 0.6), (0.9, 0.88, 0.8), (0.4, 0.25, 0.15)]


def fill_level(s, fill, level, y):
    if fill == "potes":
        for k in range(4):
            x = -0.6 + k * 0.4
            if (k + level) % 3 == 0:
                s.piece("objetos/Bottle_1", (x, y, -0.02), 0.3 * k, 1.0, name="Garrafa")
            elif (k + level) % 3 == 1:
                s.piece("objetos/Pot_1", (x, y, -0.02), 0.5 * k, 0.6, name="Pote")
            else:
                s.piece("objetos/Bag", (x, y, -0.02), 0.7 * k, 0.45, name="Saquinho")
    elif fill == "pocoes":
        for k in range(5):
            x = -0.62 + k * 0.31
            kind = ["Potion_1", "Potion_2", "Potion_4", "SmallBottle", "Potion_1"][(k + level) % 5]
            s.piece("objetos/" + kind, (x, y, -0.02), 0.4 * k, 0.9, name="Pocao")
    elif fill == "livros":
        for k in range(3):
            s.piece("objetos/BookGroup_Medium_%d" % (1 + (k + level) % 3), (-0.5 + k * 0.5, y, 0.0), 0.0, 1.0, name="Livros")
    elif fill == "tecidos":
        for k in range(5):
            rgb = CLOTH[(k * 2 + level) % len(CLOTH)]
            s.mesh("Tecido", s.cyl(0.11, 0.11, 0.38, 12), s.color(rgb, 1.0), (-0.6 + k * 0.3, y + 0.11, -0.02), (0, 0, math.pi / 2))
    elif fill == "paes":
        for k in range(5):
            s.scene("Pao", "res://world/props/pao.tscn", (-0.62 + k * 0.31, y + 0.02, -0.04), 0.5 * k + level, 1.5)
    elif fill == "ferramentas":
        s.piece("objetos/Pickaxe_Bronze", (-0.4, y, 0.0), 0.0, 0.8, name="Picareta")
        s.piece("objetos/Axe_Bronze", (0.0, y, 0.0), 0.0, 0.8, name="Machado")
        s.piece("objetos/Chain_Coil", (0.45, y, 0.0), 0.0, 0.8, name="Corrente")


shelf_goods("estante_potes", "Estante_potes", "potes")
shelf_goods("estante_pocoes", "Estante_pocoes", "pocoes")
shelf_goods("estante_livros", "Estante_livros", "livros")
shelf_goods("estante_tecidos", "Estante_tecidos", "tecidos")
shelf_goods("estante_paes", "Estante_paes", "paes")
shelf_goods("estante_ferramentas", "Estante_ferramentas", "ferramentas")


# --- pão (cena do Tico) --------------------------------------------------------------------------
CRUST, CRUST_DARK, CRUMB = (0.78, 0.5, 0.22), (0.55, 0.3, 0.12), (0.95, 0.86, 0.66)


def bread_parts(s, whole):
    """Filão: oval com a base achatada, três cortes claros por cima; a metade mostra o miolo."""
    loaf = s.sub("SphereMesh", ("loaf",), "radius = 0.05\nheight = 0.1\nradial_segments = 20\nrings = 10")
    crumb = s.sub("CylinderMesh", ("crumb",), "top_radius = 0.046\nbottom_radius = 0.046\nheight = 0.004\nradial_segments = 20")
    cut = s.sub("BoxMesh", ("cut",), "size = Vector3(0.012, 0.006, 0.055)")
    parent = "."
    if whole:
        s.mesh("Inteiro", loaf, s.color(CRUST, 0.7), (0, 0, 0), (0, 0, 0), (1.7, 0.72, 1.0))
        for i, x in enumerate((-0.045, 0.0, 0.045)):
            s.mesh("Corte%d" % i, cut, s.color((0.92, 0.74, 0.45), 0.8), (x, 0.034, 0), (0, 0.6, 0))
        s.node("Metade", "Node3D", ".", "visible = false")
        parent = "Metade"
    s.mesh("Casca", loaf, s.color(CRUST, 0.7), (-0.02, 0, 0), (0, 0, 0), (0.95, 0.72, 1.0), parent=parent)
    s.mesh("Miolo", crumb, s.color(CRUMB, 0.95), (0.026, 0, 0), (0, 0, math.pi / 2), (1.0, 1.0, 0.72), parent=parent)
    s.mesh("Base", s.box((0.15, 0.004, 0.07)), s.color(CRUST_DARK, 0.8), (-0.02 if not whole else 0, -0.034, 0), parent=parent)


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

# --- D044: fazendas, cemitério e mais da vila (modelos do acervo do poly.pizza) ---------------------------------
FB = "Farm-Buildings-Bundle/"
HB = "Halloween-Bits/"
AV = "Avulsos/"


def pp_prop(file, title, path, scale, collide=True, rot=math.pi, y=0.0):
    """Um modelo do poly.pizza sozinho, de frente para -Z (os pacotes do Quaternius têm a porta em +Z)."""
    s = Scene(title, groups=AUTO if collide else [])
    s.glb(path, (0, y * scale, 0), rot, scale, name="Modelo")
    s.save(file)


# fazenda
pp_prop("celeiro", "Celeiro", FB + "Barn", 1.3)
pp_prop("celeiro_grande", "Celeiro_grande", FB + "Big_Barn", 1.3)
pp_prop("celeiro_pequeno", "Celeiro_pequeno", FB + "Small_Barn", 1.3)
pp_prop("celeiro_aberto", "Celeiro_aberto", FB + "Open_Barn", 1.3)
pp_prop("silo", "Silo", FB + "Silo", 1.15)
pp_prop("silo_casa", "Silo_casa", FB + "Silo_House", 1.15)
pp_prop("moinho_torre", "Moinho_torre", FB + "Tower_Windmill", 1.3)
pp_prop("galinheiro", "Galinheiro", FB + "ChickenCoop", 1.1)
pp_prop("cerca_fazenda", "Cerca_fazenda", FB + "Fence", 1.0, rot=0.0)
pp_prop("cerca_fazenda2", "Cerca_fazenda2", FB + "Fence_2", 1.0, rot=0.0)
pp_prop("carroca_quebrada", "Carroca_quebrada", AV + "Broken_Cart_NBDHe8J7f9", 0.8, y=1.4)
pp_prop("torre_vigia", "Torre_vigia", AV + "Guard_Tower_sbaM8I229r", 2.4)
pp_prop("estatua_cervo", "Estatua_cervo", AV + "Stag_Statue_cKloIsNcT8", 0.75)
s = Scene("Trigo")
for k in range(9):
    a = k * 2.4
    r = 0.12 + (k % 3) * 0.1
    s.glb(AV + "Wheat_lPspzfC8Pu", (math.cos(a) * r, 0, math.sin(a) * r), (0.06 * ((k % 3) - 1), a, 0.05 * ((k % 2) * 2 - 1)), 1.1 + (k % 4) * 0.08, name="Trigo")
s.save("trigo")
s = Scene("Aboboral")
for k, (model, x, z, sc) in enumerate((("Pumpkin", 0, 0, 0.55), ("Small_Pumpkin", 0.55, 0.3, 0.7), ("Yellow_pumpkin", -0.5, 0.35, 0.7),
                                      ("Small_Pumpkin_2", 0.2, -0.55, 0.5), ("Small_Pumpkin", -0.45, -0.4, 0.6))):
    s.glb(HB + model, (x, 0, z), k * 1.1, sc, name="Abobora")
s.save("aboboral")
# cemitério
pp_prop("lapide", "Lapide", HB + "Gravestone", 0.75)
pp_prop("lapide2", "Lapide2", HB + "Gravestone_2", 0.65)
pp_prop("tumulo", "Tumulo", HB + "Grave", 0.7)
pp_prop("tumulo_rachado", "Tumulo_rachado", HB + "Damaged_Grave", 0.7)
pp_prop("cruz", "Cruz", HB + "Grave_Marker", 0.9)
pp_prop("cruz2", "Cruz2", HB + "Gravemarker", 0.9)
pp_prop("cripta", "Cripta", HB + "Crypt", 0.7)
pp_prop("grade_cemiterio", "Grade_cemiterio", HB + "Iron_Fence", 0.75, rot=0.0)
pp_prop("grade_cemiterio_quebrada", "Grade_cemiterio_quebrada", HB + "Damaged_Iron_fence", 0.75, rot=0.0)
pp_prop("pilar_grade", "Pilar_grade", HB + "Fence_Pillar", 0.75)
pp_prop("portao_cemiterio", "Portao_cemiterio", HB + "Arch_Gate", 0.8, rot=0.0)
pp_prop("santuario", "Santuario", HB + "Shrine", 0.8)
pp_prop("santuario_velas", "Santuario_velas", HB + "Shrine_2", 0.8)
pp_prop("caixao", "Caixao", HB + "Coffin", 0.6)
pp_prop("velas", "Velas", HB + "Candles", 0.8, False)
pp_prop("pinheiro_outono", "Pinheiro_outono", HB + "Autumn_pine", 1.2)
pp_prop("pinheiro_outono2", "Pinheiro_outono2", HB + "Autumn_pine_3", 1.0)
pp_prop("arvore_seca_galhos", "Arvore_seca_galhos", HB + "Dead_tree_2", 1.1)
pp_prop("caminho_pedras", "Caminho_pedras", HB + "Path", 1.0, False)
s = Scene("Poste_lanterna", groups=AUTO)
s.glb(HB + "Post_Lantern", (0, 0, 0), math.pi, 0.9, name="Modelo")
light_child(s, (0, 2.5, -0.95), 1.2, 6.0)
s.save("poste_lanterna")
# mais da vila medieval
house("casa_pedra", "Casa_pedra", 2, 3, 1, ["Wall_UnevenBrick"], "Roof_RoundTiles_4x6", "Roof_Front_Brick4", 0)
pp_prop("gazebo", "Gazebo", MV + "Gazebo", K_MV)
pp_prop("feno", "Feno", MV + "Hay", K_MV * 1.4, False)
pp_prop("sacos", "Sacos", MV + "Bags", K_MV, False)
pp_prop("fardos", "Fardos", MV + "Package", K_MV, False)

print("peças:", len([f for f in os.listdir(OUT) if f.endswith(".tscn")]))
