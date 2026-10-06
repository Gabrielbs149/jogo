"""Gera world/props/*.tscn (as peças do catálogo do editor de mapas) com os modelos e materiais do Poly Haven (D024).
Rodar: python tools/art/gerar_pecas.py  (APAGA e refaz world/props — mudança feita à mão nas peças se perde)."""
import json
import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))).replace("\\", "/") + "/"
OUT = ROOT + "world/props/"
MED = json.load(open(ROOT + "assets/models/medidas.json"))
os.makedirs(OUT, exist_ok=True)
for f in os.listdir(OUT):
    if f.endswith(".tscn"):
        os.remove(OUT + f)


def xf(pos=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
    if not isinstance(scale, (tuple, list)):
        scale = (scale, scale, scale)
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
    def __init__(self, name, typ="Node3D", props=()):
        self.ext, self.ext_ids, self.subs, self.sub_ids, self.nodes = [], {}, [], {}, []
        self.root = (name, typ, list(props))

    def ext_res(self, kind, path):
        if path not in self.ext_ids:
            rid = "%d_%s" % (len(self.ext_ids) + 1, os.path.basename(path).split(".")[0][:12])
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

    def prism(self, size):
        return self.sub("PrismMesh", ("prism",) + tuple(size), "size = Vector3(%g, %g, %g)" % tuple(size))

    def node(self, name, typ, parent, *props, instance=None):
        head = '[node name="%s"' % name
        if typ:
            head += ' type="%s"' % typ
        head += ' parent="%s"' % parent
        if instance:
            head += ' instance=ExtResource("%s")' % instance
        self.nodes.append(head + "]" + ("\n" + "\n".join(props) if props else "") + "\n")

    def mesh(self, name, mesh_id, material, pos, rot=(0, 0, 0), scale=1, parent="."):
        self.node(name, "MeshInstance3D", parent, "transform = " + xf(pos, rot, scale), 'mesh = SubResource("%s")' % mesh_id,
                  "material_override = " + material)

    def model(self, name, glb, pos=(0, 0, 0), rot=(0, 0, 0), scale=1, parent="."):
        rid = self.ext_res("PackedScene", "res://assets/models/%s.glb" % glb)
        self.node(name, None, parent, "transform = " + xf(pos, rot, scale), instance=rid)

    def scene(self, name, path, pos=(0, 0, 0), rot=(0, 0, 0), scale=1, parent=".", *props):
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
        name, typ, props = self.root
        head = '[node name="%s" type="%s"]' % (name, typ) + ("\n" + "\n".join(props) if props else "") + "\n"
        text = "[gd_scene format=3]\n\n" + "\n".join(self.ext) + ("\n\n" if self.ext else "") + "\n".join(self.subs) + "\n" + head + "\n" + "\n".join(self.nodes)
        open(OUT + file + ".tscn", "w", encoding="utf-8", newline="\n").write(text)


def model_prop(file, title, glb, scale=1.0, collide="box", layer=4, shrink=0.8, extra=None):
    """Peça feita de um modelo só: colisão do tamanho do modelo (medidas.json)."""
    s = Scene(title)
    s.model("Model", glb, scale=scale)
    m = MED[glb]
    x, y, z = m["x"] * scale, m["y"] * scale, m["z"] * scale
    if collide == "box":
        s.body(("box", (x * shrink, y, z * shrink)), (0, y / 2, 0), layer)
    elif collide == "trunk":
        s.body(("cyl", (max(min(x, z) * 0.18, 0.15), y * 0.6)), (0, y * 0.3, 0), layer)
    elif collide == "round":
        s.body(("cyl", (max(x, z) * 0.5 * shrink, y)), (0, y / 2, 0), layer)
    if extra:
        extra(s)
    s.save(file)


DOOR_DARK, GLASS, CLOTH = (0.22, 0.14, 0.08), (0.1, 0.12, 0.14), (0.62, 0.16, 0.1)


def house(file, title, w, h, d, floors=1, wall="reboco"):
    s = Scene(title)
    s.mesh("Walls", s.box((w, h, d)), s.mat(wall), (0, h / 2, 0))
    s.mesh("Socle", s.box((w + 0.12, 0.6, d + 0.12)), s.mat("pedra_poco"), (0, 0.3, 0))
    rise = 1.9 if w < 8 else 2.6
    half = w / 2 + 0.45
    length = math.hypot(half, rise) + 0.1
    ang = math.atan2(rise, half)
    s.mesh("Gable", s.prism((w, rise, d)), s.mat(wall), (0, h + rise / 2, 0))
    for side, name in ((-1, "RoofL"), (1, "RoofR")):
        s.mesh(name, s.box((length, 0.16, d + 0.9)), s.mat("telha"), (side * half / 2, h + rise / 2 + 0.08, 0), (0, 0, -side * ang))
    s.mesh("Ridge", s.box((0.3, 0.22, d + 0.95)), s.mat("telha"), (0, h + rise + 0.05, 0))
    # vigas de madeira no beiral e nos cantos
    s.mesh("Beam", s.box((w + 0.3, 0.22, 0.22)), s.mat("tabuas"), (0, h - 0.11, -d / 2 - 0.08))
    s.mesh("BeamBack", s.box((w + 0.3, 0.22, 0.22)), s.mat("tabuas"), (0, h - 0.11, d / 2 + 0.08))
    for i, (cx, cz) in enumerate(((-1, -1), (1, -1), (-1, 1), (1, 1))):
        s.mesh("Post%d" % i, s.box((0.24, h, 0.24)), s.mat("tabuas"), (cx * (w / 2 + 0.02), h / 2, cz * (d / 2 + 0.02)))
    # porta e janelas na frente (-Z)
    s.mesh("DoorFrame", s.box((1.5, 2.55, 0.12)), s.mat("tabuas"), (0, 1.27 + 0.3, -d / 2 - 0.04))
    s.mesh("Door", s.box((1.15, 2.3, 0.1)), s.color(DOOR_DARK, 0.8), (0, 1.15 + 0.3, -d / 2 - 0.08))
    rows = [2.2] if floors == 1 else [2.0, 4.0]
    n = 0
    for wy in rows:
        for wx in ((-w / 3, w / 3) if floors == 1 or wy < 3 else (-w / 3, 0, w / 3)):
            if floors > 1 and wy < 3 and abs(wx) < 0.1:
                continue
            s.mesh("Window%d" % n, s.box((0.95, 0.95, 0.08)), s.color(GLASS, 0.3), (wx, wy, -d / 2 - 0.03))
            s.mesh("Sill%d" % n, s.box((1.2, 0.12, 0.25)), s.mat("tabuas"), (wx, wy - 0.55, -d / 2 - 0.1))
            s.mesh("Lintel%d" % n, s.box((1.2, 0.14, 0.16)), s.mat("tabuas"), (wx, wy + 0.55, -d / 2 - 0.07))
            for side in (-1, 1):
                s.mesh("Shutter%d_%d" % (n, side + 1), s.box((0.5, 1.0, 0.06)), s.mat("tabuas"), (wx + side * 0.75, wy, -d / 2 - 0.06))
            n += 1
    s.body(("box", (w, h, d)), (0, h / 2, 0), 1)
    s.save(file)


house("casa", "Casa", 6, 3.6, 5)
house("casa_grande", "Casa_grande", 9, 5.4, 8, floors=2)
house("casa_barro", "Casa_barro", 6, 3.6, 5, wall="reboco_barro")
house("casa_grande_barro", "Casa_grande_barro", 9, 5.4, 8, floors=2, wall="reboco_barro")

s = Scene("Muro")
s.mesh("Wall", s.box((6, 3.4, 1)), s.mat("muralha"), (0, 1.7, 0))
s.mesh("Cap", s.box((6.1, 0.25, 1.2)), s.mat("arenito"), (0, 3.52, 0))
s.body(("box", (6, 3.6, 1)), (0, 1.8, 0), 1)
s.save("muro")

s = Scene("Barraca")
s.mesh("Table", s.box((2.6, 0.12, 1.2)), s.mat("tabuas"), (0, 0.9, 0))
s.mesh("Front", s.box((2.6, 0.8, 0.06)), s.mat("tabuas"), (0, 0.44, -0.57))
for i, (px, pz) in enumerate([(-1.25, -0.55), (1.25, -0.55), (-1.25, 0.55), (1.25, 0.55)]):
    s.mesh("Pole%d" % i, s.box((0.1, 2.6 if pz > 0 else 2.3, 0.1)), s.mat("tabuas"), (px, (2.6 if pz > 0 else 2.3) / 2, pz))
s.mesh("Awning", s.box((3.0, 0.04, 1.7)), s.color(CLOTH, 0.95), (0, 2.45, -0.05), (-0.18, 0, 0))
s.model("Jug", "jug_01", (-0.8, 0.96, 0.1), (0, 0.6, 0), 1.3)
s.model("Vase", "ceramic_vase_01", (-0.35, 0.96, 0.2), scale=1.2)
s.model("Basket", "wicker_basket_01", (0.5, 0.96, 0), (0, 0.3, 0), 1.6)
s.model("Crate", "wooden_crate_01", (1.6, 0, 0.6), (0, 1.2, 0))
s.body(("box", (2.6, 1.0, 1.2)), (0, 0.5, 0), 1)
s.save("barraca")

s = Scene("Poco")
s.mesh("Ring", s.cyl(1.2, 1.3, 0.95, 24), s.mat("pedra_poco"), (0, 0.47, 0))
s.mesh("Rim", s.cyl(1.28, 1.28, 0.12, 24), s.mat("arenito"), (0, 0.98, 0))
s.mesh("Water", s.cyl(1.0, 1.0, 0.05, 24), s.color((0.05, 0.1, 0.12), 0.05), (0, 0.75, 0))
for side in (-1, 1):
    s.mesh("Post%d" % (side + 1), s.box((0.2, 2.4, 0.2)), s.mat("tabuas"), (1.1 * side, 1.6, 0))
s.mesh("Axle", s.cyl(0.07, 0.07, 2.4, 10), s.mat("tabuas"), (0, 2.3, 0), (0, 0, math.pi / 2))
for side, name in ((-1, "RoofL"), (1, "RoofR")):
    s.mesh(name, s.box((1.25, 0.12, 2.9)), s.mat("palha"), (side * 0.52, 3.1, 0), (0, math.pi / 2, -side * 0.6))
s.model("Bucket", "wooden_bucket_01", (0.75, 1.04, 0.35), (0, 0.4, 0), 0.9)
s.body(("cyl", (1.3, 1.0)), (0, 0.5, 0), 1)
s.save("poco")

s = Scene("Pilar")
s.mesh("Base", s.box((1.5, 0.5, 1.5)), s.mat("arenito"), (0, 0.25, 0))
s.mesh("Stone", s.cyl(0.52, 0.6, 3.4, 20), s.mat("arenito"), (0, 2.2, 0))
s.mesh("Top", s.box((1.4, 0.35, 1.4)), s.mat("arenito"), (0, 4.07, 0))
s.body(("cyl", (0.65, 4.2)), (0, 2.1, 0), 4)
s.save("pilar")

s = Scene("Marquise")
# presa na parede (o lado +Z da peça encosta na parede), sai 2 m para a frente a 2,5 m de altura
s.mesh("Roof", s.box((3.2, 0.1, 2.1)), s.mat("telha"), (0, 2.45, -1.0), (-0.2, 0, 0))
s.mesh("Beam", s.box((3.3, 0.16, 0.16)), s.mat("tabuas"), (0, 2.2, -1.95))
s.mesh("WallBeam", s.box((3.3, 0.18, 0.14)), s.mat("tabuas"), (0, 2.62, -0.07))
for i, x in enumerate((-1.45, 1.45)):
    s.mesh("Brace%d" % i, s.box((0.12, 0.12, 1.45)), s.mat("tabuas"), (x, 2.05, -0.95), (0.62, 0, 0))
    s.mesh("Post%d" % i, s.box((0.12, 2.2, 0.12)), s.mat("tabuas"), (x, 1.1, -1.95))
s.save("marquise")

CRUST, CRUMB = (0.62, 0.36, 0.14), (0.93, 0.82, 0.6)


def bread_parts(s, parent, whole):
    loaf = s.sub("CapsuleMesh", ("loaf",), "radius = 0.045\nheight = 0.2\nradial_segments = 12\nrings = 4")
    half = s.sub("CapsuleMesh", ("half",), "radius = 0.045\nheight = 0.11\nradial_segments = 12\nrings = 4")
    cut = s.sub("CylinderMesh", ("cut",), "top_radius = 0.04\nbottom_radius = 0.04\nheight = 0.004\nradial_segments = 12")
    if whole:
        s.mesh("Inteiro", loaf, s.color(CRUST, 0.75), (0, 0, 0), (0, 0, math.pi / 2), (1, 1, 0.85))
        s.node("Metade", "Node3D", ".", "visible = false")
        parent = "Metade"
    s.mesh("Casca", half, s.color(CRUST, 0.75), (0, 0, 0), (0, 0, math.pi / 2), (1, 1, 0.85), parent=parent)
    s.mesh("Miolo", cut, s.color(CRUMB, 0.95), (0.055, 0, 0), (0, 0, math.pi / 2), parent=parent)


s = Scene("Pao")
bread_parts(s, ".", True)
s.save("pao")
s = Scene("Meio_pao")
bread_parts(s, ".", False)
s.save("meio_pao")

# natureza
model_prop("arvore", "Arvore", "quiver_tree_01", 2.2, "trunk", 1)
model_prop("arvore_pequena", "Arvore_pequena", "quiver_tree_02", 2.0, "trunk", 1)
model_prop("suculenta", "Suculenta", "othonna_cerarioides", 1.0, None)
model_prop("arbusto", "Arbusto", "wild_rooibos_bush", 1.0, None)
model_prop("arbusto_baixo", "Arbusto_baixo", "shrub_03", 1.2, None)
model_prop("tronco_seco", "Tronco_seco", "dead_quiver_trunk", 1.6, "trunk", 1)
model_prop("toco", "Toco", "tree_stump_01", 1.0, "round", 4, 0.6)
model_prop("rocha", "Rocha", "namaqualand_boulder_02", 1.0, "box", 4, 0.75)
model_prop("rocha_grande", "Rocha_grande", "namaqualand_boulder_04", 1.4, "box", 4, 0.75)
model_prop("penhasco", "Penhasco", "namaqualand_cliff_01", 1.0, "box", 1, 0.8)
model_prop("pedregulhos", "Pedregulhos", "namaqualand_boulders_01", 1.5, None)
model_prop("pedras", "Pedras", "namaqualand_rocks_01", 1.5, None)
model_prop("pedrinhas", "Pedrinhas", "namaqualand_stones_01", 1.5, None)
# objetos
model_prop("caixote", "Caixote", "wooden_crate_01", 1.0)
model_prop("caixote_alto", "Caixote_alto", "wooden_crate_02", 1.0)
model_prop("barril", "Barril", "barrel_03", 1.0, "round")
model_prop("barril_vinho", "Barril_vinho", "wine_barrel_01", 1.0, "round")
model_prop("barris", "Barris", "wooden_barrels_01", 1.0, "box", 4, 0.7)
model_prop("balde", "Balde", "wooden_bucket_01", 1.0, None)
model_prop("cesto", "Cesto", "wicker_basket_01", 1.4, None)
model_prop("jarro", "Jarro", "jug_01", 1.3, None)
model_prop("vaso", "Vaso", "ceramic_vase_01", 1.5, None)
model_prop("banquinho", "Banquinho", "folding_wooden_stool", 1.0, None)
model_prop("banco", "Banco", "painted_wooden_bench", 1.0, "box", 4, 0.9)
model_prop("bau", "Bau", "treasure_chest", 1.0, "box", 4, 0.9)
model_prop("portao", "Portao", "large_castle_door", 1.0, "box", 1, 1.0)


def lantern_light(s):
    s.node("Light", "OmniLight3D", ".", "transform = " + xf((0, 0.35, 0)), "light_color = Color(1, 0.7, 0.4, 1)", "light_energy = 1.4",
           "omni_range = 5.0")


model_prop("lanterna", "Lanterna", "wooden_lantern_01", 1.0, None, extra=lantern_light)

s = Scene("Luz", "OmniLight3D", ["light_color = Color(1, 0.8, 0.55, 1)", "light_energy = 2.0", "omni_range = 8.0"])
s.save("luz")

# gente e história
s = Scene("Morador")
s.scene("Figure", "res://actors/shared/robed_figure.tscn", (0, 0, 0), (0, 0, 0), 1, ".", "cloth_color = Color(0.55, 0.45, 0.3, 1)")
s.node("Collision", "StaticBody3D", ".", "transform = " + xf((0, 0.9, 0)), "collision_layer = 4", "collision_mask = 0")
cap = s.sub("CapsuleShape3D", ("cap", 0.45, 1.8), "radius = 0.45\nheight = 1.8")
s.node("Shape", "CollisionShape3D", "Collision", 'shape = SubResource("%s")' % cap)
inter = s.ext_res("Script", "res://world/interactable.gd")
s.node("Talk", "Node3D", ".", "transform = " + xf((0, 1, 0)), 'script = ExtResource("%s")' % inter, 'prompt_text = "Falar com o morador"', 'text = "— ..."')
s.save("morador")

s = Scene("Inscricao")
inter = s.ext_res("Script", "res://world/interactable.gd")
s.root[2].extend(['script = ExtResource("%s")' % inter, 'prompt_text = "Ler a inscrição"', 'text = "Inscrição: «...»"'])
s.mesh("Stone", s.box((1.3, 1.7, 0.45)), s.mat("arenito"), (0, 0.85, 0), (0.04, 0, 0.02))
s.mesh("Glyph", s.box((0.7, 0.5, 0.04)), s.color((1, 0.6, 0.3), 0.5, ((1, 0.55, 0.25), 2.5)), (0, 1.1, -0.235))
s.model("Stones", "namaqualand_stones_01", (0, 0, 0), (0, 0.5, 0), 1.0)
s.body(("box", (1.3, 1.7, 0.45)), (0, 0.85, 0), 4)
s.save("inscricao")

s = Scene("Fogueira")
inter = s.ext_res("Script", "res://world/interactable.gd")
s.root[2].extend(['script = ExtResource("%s")' % inter, "action = 1", 'prompt_text = "Descansar na fogueira"',
                  'text = "Descanso curto à beira do fogo. A vida volta inteira."'])
s.model("Pit", "stone_fire_pit", scale=0.85)
for i in range(4):
    a = i * math.pi / 2 + 0.3
    s.mesh("Log%d" % i, s.cyl(0.07, 0.08, 0.9, 8), s.mat("tabuas"), (math.cos(a) * 0.15, 0.22, math.sin(a) * 0.15), (0.95, -a, 0))
s.scene("Fire", "res://assets/vfx/fogo.tscn", (0, 0.15, 0))
s.save("fogueira")

s = Scene("Saida")
inter = s.ext_res("Script", "res://world/interactable.gd")
s.root[2].extend(['script = ExtResource("%s")' % inter, "action = 3", 'prompt_text = "Seguir viagem"', 'target_scene = "res://levels/ethera/ethera.tscn"'])
for side in (-1, 1):
    s.mesh("Pillar%d" % (side + 1), s.box((0.8, 4.0, 0.8)), s.mat("arenito"), (1.8 * side, 2.0, 0))
s.mesh("Top", s.box((4.6, 0.7, 0.95)), s.mat("arenito"), (0, 4.35, 0))
s.model("Stones", "namaqualand_stones_01", (0, 0, 0.6), scale=1.4)
for side in (-1, 1):
    s.body(("box", (0.8, 4.0, 0.8)), (1.8 * side, 2.0, 0), 1, "Body%d" % (side + 1))
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
        s.scene("Inimigo%d" % (i + 1), "res://actors/enemies/%s.tscn" % e, (i * 2.2 - (len(enemies) - 1) * 1.1, 0.6, 0), (0, math.pi, 0))
    s.save(name)

print("peças:", sorted(f[:-5] for f in os.listdir(OUT) if f.endswith(".tscn")))
