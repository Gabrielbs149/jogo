"""O canto do Tico e da Tika no beco (D062): as peças feitas sob medida para o beco de Arandu.

- barraco: lona remendada presa num varão na parede da casa da viúva e numa travessa sobre duas estacas
- cama_tico: papelão da caixa de sabão + colchão de palha (saco de farinha) + travesseiro + colcha de retalhos
- cama_tika: papelão + manta dobrada + rolinho de pano de travesseiro
- assento: saco dobrado onde o Tico senta encostado na parede do fundo
- varal: corda com os panos deles secando, presa num toco na parede do sapateiro
- lenha: feixe de gravetos amarrado e uns soltos
- cinzas: o fundo da fogueirinha (cinza, tocos queimados)
- prateleira: tábua em duas cavilhas na parede do fundo

Tudo é pensado nas coordenadas do Godot (x = ao comprido do beco, para a rua; y = para cima; z = para o norte), com a
origem de cada peça onde o montar_beco.gd põe ela. As texturas vêm de assets/beco/tex/ (texturas_beco.py).

Uso: blender --background --factory-startup --python tools/blender/gerado/modelar_beco.py -- C:/dev/jogo [peça]
Saída: assets/beco/<peça>.gltf (+ .bin), com as texturas apontando para assets/beco/tex/.
"""
import math
import random
import sys

import bpy
from mathutils import Vector, noise

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ROOT = ARGS[0] if ARGS else "C:/dev/jogo"
ONLY = ARGS[1] if len(ARGS) > 1 else ""
OUT = ROOT + "/assets/beco/"
TEX = OUT + "tex/"


# --------------------------------------------------------------------------------------------- base

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _MATS.clear()


def B(p):
    """Godot (x, y, z) -> Blender (x, -z, y). O exportador do glTF desfaz isso."""
    return (p[0], -p[2], p[1])


_MATS = {}


def mat(name, tex=None, color=(0.5, 0.5, 0.5), rough=1.0, alpha=False, emit=None):
    key = name
    if key in _MATS:
        return _MATS[key]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nodes = m.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    if tex:
        img = bpy.data.images.load(TEX + tex, check_existing=True)
        node = nodes.new("ShaderNodeTexImage")
        node.image = img
        m.node_tree.links.new(node.outputs["Color"], bsdf.inputs["Base Color"])
        if alpha:
            m.node_tree.links.new(node.outputs["Alpha"], bsdf.inputs["Alpha"])
    if emit:
        bsdf.inputs["Emission Color"].default_value = (*emit[0], 1.0)
        bsdf.inputs["Emission Strength"].default_value = emit[1]
    _MATS[key] = m
    return m


def mesh_obj(name, verts, faces, uvs=None, material=None, smooth=True):
    """verts em coordenadas do Godot; uvs = uma (u, v) por vértice."""
    me = bpy.data.meshes.new(name)
    me.from_pydata([B(v) for v in verts], [], faces)
    me.update()
    if uvs:
        layer = me.uv_layers.new(name="UVMap")
        for poly in me.polygons:
            for li in poly.loop_indices:
                vi = me.loops[li].vertex_index
                layer.data[li].uv = uvs[vi]
    for poly in me.polygons:
        poly.use_smooth = smooth
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    if material:
        me.materials.append(material)
    return ob


def grid(name, nu, nv, fn, material, uv_scale=(1.0, 1.0), smooth=True):
    """Superfície a partir de fn(u, v) -> ponto do Godot, com u, v em 0..1."""
    verts, uvs, faces = [], [], []
    for j in range(nv + 1):
        for i in range(nu + 1):
            u, v = i / nu, j / nv
            verts.append(fn(u, v))
            uvs.append((u * uv_scale[0], v * uv_scale[1]))
    for j in range(nv):
        for i in range(nu):
            a = j * (nu + 1) + i
            faces.append((a, a + 1, a + nu + 2, a + nu + 1))
    return mesh_obj(name, verts, faces, uvs, material, smooth)


def solidify(ob, thickness):
    mod = ob.modifiers.new("espessura", "SOLIDIFY")
    mod.thickness = thickness
    mod.offset = 0.0
    return ob


def subsurf(ob, levels=1):
    mod = ob.modifiers.new("suave", "SUBSURF")
    mod.levels = levels
    mod.render_levels = levels
    return ob


def tube(name, points, radius, material, sides=8, r_end=None, uv_len=1.0, caps=True):
    """Cano/galho/corda passando pelos pontos (Godot). raio vai de radius a r_end."""
    pts = [Vector(p) for p in points]
    r_end = radius if r_end is None else r_end
    verts, uvs, faces = [], [], []
    total = sum((pts[i + 1] - pts[i]).length for i in range(len(pts) - 1)) or 1.0
    run = 0.0
    up = Vector((0, 1, 0))
    for k, p in enumerate(pts):
        if k < len(pts) - 1:
            t = (pts[k + 1] - p).normalized()
        else:
            t = (p - pts[k - 1]).normalized()
        if k > 0:
            run += (p - pts[k - 1]).length
        side = t.cross(up)
        if side.length < 1e-4:
            side = t.cross(Vector((1, 0, 0)))
        side.normalize()
        other = t.cross(side).normalized()
        r = radius + (r_end - radius) * (run / total)
        for s in range(sides + 1):
            a = 2 * math.pi * s / sides
            q = p + (side * math.cos(a) + other * math.sin(a)) * r
            verts.append(tuple(q))
            uvs.append((s / sides, run / uv_len))
    ring = sides + 1
    for k in range(len(pts) - 1):
        for s in range(sides):
            a = k * ring + s
            faces.append((a, a + ring, a + ring + 1, a + 1))
    if caps:
        for k, sign in ((0, 1), (len(pts) - 1, -1)):
            center = len(verts)
            verts.append(tuple(pts[k]))
            uvs.append((0.5, 0.5))
            for s in range(sides):
                a = k * ring + s
                faces.append((center, a + 1, a) if sign > 0 else (center, a, a + 1))
    return mesh_obj(name, verts, faces, uvs, material)


def stick(name, a, b, r, material, bend=0.0, seed=0, segs=6, r_end=None):
    """Galho levemente torto de a até b."""
    rnd = random.Random(seed)
    a, b = Vector(a), Vector(b)
    pts = []
    side = Vector((rnd.uniform(-1, 1), rnd.uniform(-0.3, 0.3), rnd.uniform(-1, 1))).normalized()
    for i in range(segs + 1):
        t = i / segs
        off = side * math.sin(math.pi * t) * bend
        jitter = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1))) * r * 0.25
        pts.append(tuple(a.lerp(b, t) + off + (jitter if 0 < i < segs else Vector())))
    return tube(name, pts, r, material, sides=7, r_end=r_end if r_end else r * 0.8, uv_len=0.6)


def coil(name, center, axis, radius, turns, length, material, rope_r=0.007):
    """Amarração: corda enrolada em volta de um galho (eixo = direção do galho)."""
    axis = Vector(axis).normalized()
    side = axis.cross(Vector((0, 1, 0)))
    if side.length < 1e-3:
        side = axis.cross(Vector((1, 0, 0)))
    side.normalize()
    other = axis.cross(side).normalized()
    pts = []
    steps = int(turns * 14)
    for i in range(steps + 1):
        t = i / steps
        a = t * turns * 2 * math.pi
        p = Vector(center) + axis * (t - 0.5) * length + (side * math.cos(a) + other * math.sin(a)) * radius
        pts.append(tuple(p))
    return tube(name, pts, rope_r, material, sides=5, uv_len=0.1, caps=False)


def lumpy_box(name, center, size, material, lump=0.012, seed=0, round_levels=2, uv_scale=1.0):
    """Caixa fofa (colchão, travesseiro, saco): cubo arredondado com calombos."""
    cx, cy, cz = center
    sx, sy, sz = size
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    ob = bpy.context.active_object
    ob.name = name
    me = ob.data
    for v in me.vertices:
        g = Vector((v.co.x * sx, v.co.z * sy, -v.co.y * sz))  # Godot local
        v.co = Vector(B(g))
    mod = ob.modifiers.new("suave", "SUBSURF")
    mod.levels = round_levels
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.modifier_apply(modifier="suave")
    me = ob.data
    off = Vector((seed * 3.1, seed * 1.7, seed * 2.3))
    for v in me.vertices:
        g = Vector((v.co.x, v.co.z, -v.co.y))
        n = noise.noise((g * 9.0) + off)
        top = max(0.0, g.y) / max(sy * 0.5, 1e-4)
        g.y += n * lump * (0.4 + top)
        g.x += noise.noise((g * 7.0) + off + Vector((5, 0, 0))) * lump * 0.5
        g.z += noise.noise((g * 7.0) + off + Vector((0, 0, 5))) * lump * 0.5
        v.co = Vector(B((g.x + cx, g.y + cy, g.z + cz)))
    layer = me.uv_layers.new(name="UVMap")
    for poly in me.polygons:
        poly.use_smooth = True
        for li in poly.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            g = Vector((co.x, co.z, -co.y))
            layer.data[li].uv = ((g.x - cx) * uv_scale + 0.5 + (g.y - cy) * 0.6 * uv_scale,
                                 (g.z - cz) * uv_scale + 0.5 + (g.y - cy) * 0.6 * uv_scale)
    me.materials.append(material)
    return ob


def strands(name, spots, material, seed=0):
    """Fiapos de palha: tiras finas (cada uma = 2 triângulos dos dois lados)."""
    rnd = random.Random(seed)
    verts, faces, uvs = [], [], []
    for (x, y, z, spread) in spots:
        a = rnd.uniform(0, 2 * math.pi)
        L = rnd.uniform(0.05, 0.14)
        lift = rnd.uniform(-0.2, 0.5)
        d = Vector((math.cos(a), lift * 0.3, math.sin(a))).normalized()
        p0 = Vector((x + rnd.uniform(-spread, spread), y, z + rnd.uniform(-spread, spread)))
        p1 = p0 + d * L
        w = Vector((-d.z, 0, d.x)).normalized() * 0.004
        base = len(verts)
        for q in (p0 - w, p0 + w, p1 + w * 0.3, p1 - w * 0.3):
            verts.append(tuple(q))
        uvs += [(rnd.random(), 0), (rnd.random(), 0.02), (rnd.random(), 1), (rnd.random(), 0.98)]
        faces.append((base, base + 1, base + 2, base + 3))
        faces.append((base + 3, base + 2, base + 1, base))
    return mesh_obj(name, verts, faces, uvs, material, smooth=False)


def card(name, center, size, yaw, material, lift_edges=0.015, seed=0, thickness=0.008, v_face=0.86):
    """Folha de papelão no chão, com as beiradas um pouco levantadas (empenou com a umidade)."""
    cx, cy, cz = center
    sx, sz = size
    rnd = random.Random(seed)
    c, s = math.cos(yaw), math.sin(yaw)
    corner_lift = [rnd.uniform(0.3, 1.0) for _ in range(4)]

    def fn(u, v):
        x = (u - 0.5) * sx
        z = (v - 0.5) * sz
        edge = max(abs(u - 0.5), abs(v - 0.5)) * 2
        k = corner_lift[(0 if u < 0.5 else 1) + (0 if v < 0.5 else 2)]
        y = max(0.0, edge - 0.75) / 0.25 * lift_edges * k
        y += noise.noise(Vector((x * 4 + seed, z * 4, 0))) * 0.003
        return (cx + x * c - z * s, cy + y, cz + x * s + z * c)

    ob = grid(name, 16, 12, fn, material, uv_scale=(1.0, v_face), smooth=True)
    return solidify(ob, thickness)


def export(name, objects):
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objects:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.export_scene.gltf(filepath=OUT + name + ".gltf", export_format="GLTF_SEPARATE", use_selection=True,
                              export_apply=True, export_keep_originals=True, export_yup=True)
    print("salvo", name, len(objects), "objetos")


def materials():
    return {
        "madeira": mat("Madeira", "madeira.png"),
        "corda": mat("Corda", "corda.png"),
        "lona": mat("Lona", "lona.png"),
        "colcha": mat("Colcha", "colcha.png"),
        "saco": mat("Saco", "saco.png"),
        "palha": mat("Palha", "palha.png"),
        "papelao": mat("Papelao", "papelao.png"),
        "panos": mat("Panos", "panos.png"),
        "cinza": mat("Cinza", "cinza.png"),
        "ferro": mat("Ferro", None, (0.12, 0.11, 0.1), 0.6),
        "carvao": mat("Carvao", None, (0.05, 0.045, 0.04), 1.0),
    }


# --------------------------------------------------------------------------------------------- peças

## A lona vai da parede da casa da viúva (z = 0, varão na altura ALTO) até a travessa das estacas (z = FRENTE).
FRENTE = 2.72
ALTO = 2.42


def barraco():
    """Origem: canto do fundo do beco com a parede da casa da viúva (x para a rua, z para o norte)."""
    reset()
    M = materials()
    obs = []
    # estacas (galhos com forquilha no alto) e a travessa da frente
    F = FRENTE
    obs.append(stick("EstacaFundo", (0.22, -0.05, F + 0.04), (0.25, 1.98, F + 0.01), 0.045, M["madeira"], 0.03, 1, r_end=0.035))
    obs.append(stick("Forquilha", (0.25, 1.80, F + 0.01), (0.31, 2.0, F + 0.06), 0.02, M["madeira"], 0.0, 10))
    # a outra ponta da travessa: corda esticada até um gancho alto na parede da casa da viúva
    obs.append(tube("CordaDaPonta", [(2.44, 1.86, F + 0.05), (2.42, 2.3, F * 0.55), (2.4, 2.78, 0.06)], 0.009, M["corda"], 6, uv_len=0.1))
    obs.append(tube("GanchoAlto", [(2.4, 2.74, -0.02), (2.4, 2.74, 0.1), (2.4, 2.83, 0.11)], 0.008, M["ferro"], 5))
    obs.append(stick("Travessa", (-0.02, 1.855, F + 0.01), (2.48, 1.845, F + 0.05), 0.04, M["madeira"], 0.03, 3, segs=10))
    # varão na parede, preso em três ganchos de ferro
    obs.append(stick("Varao", (0.02, ALTO, 0.08), (2.45, ALTO - 0.02, 0.08), 0.032, M["madeira"], 0.02, 4, segs=10))
    for k, x in enumerate((0.3, 1.25, 2.25)):
        obs.append(tube("Gancho%d" % k, [(x, ALTO - 0.06, -0.02), (x, ALTO - 0.06, 0.12), (x, ALTO + 0.04, 0.13)], 0.008, M["ferro"], 5))
    # amarrações
    obs.append(coil("AmarraFundo", (0.25, 1.86, F + 0.02), (1, 0, 0.02), 0.048, 4, 0.08, M["corda"]))
    obs.append(coil("AmarraRua", (2.40, 1.86, F + 0.05), (1, 0, 0.02), 0.048, 4, 0.08, M["corda"]))

    # a lona: do varão até a travessa (afunda no meio), passa por cima da travessa e cai uns 25 cm na frente
    def lona(u, v):
        x = -0.04 + 2.56 * u
        mid = math.sin(math.pi * u) * 0.7 + 0.3
        if v < 0.82:
            t = v / 0.82
            z = 0.06 + (FRENTE - 0.04 - 0.06) * t
            y = ALTO + 0.03 + (1.895 - ALTO - 0.03) * t - 0.14 * math.sin(math.pi * t) * mid
        elif v < 0.88:
            t = (v - 0.82) / 0.06
            a = t * math.pi * 0.5
            z = FRENTE + 0.01 + math.sin(a) * 0.05
            y = 1.855 + math.cos(a) * 0.045
        else:
            t = (v - 0.88) / 0.12
            z = FRENTE + 0.06 + t * 0.03
            hem = 0.05 * math.sin(u * 17.0) + 0.03 * math.sin(u * 41.0)
            y = 1.855 - t * (0.24 + hem)
        y += 0.012 * math.sin(u * 37 + v * 9) * math.sin(v * 21) + noise.noise(Vector((u * 6, v * 6, 1))) * 0.012
        return (x, y, z)

    obs.append(solidify(subsurf(grid("Lona", 48, 34, lona, M["lona"], uv_scale=(1.0, 1.0)), 1), 0.006))
    # cordinhas segurando as pontas da lona no varão
    for k, x in enumerate((0.0, 0.8, 1.6, 2.45)):
        obs.append(coil("Laco%d" % k, (x, ALTO, 0.08), (1, 0, 0), 0.04, 2.5, 0.04, M["corda"], 0.006))
    # gancho na travessa para a lanterna
    obs.append(tube("GanchoLanterna", [(1.2, 1.80, F + 0.03), (1.2, 1.70, F + 0.03), (1.23, 1.66, F + 0.03)], 0.006, M["ferro"], 5))
    export("barraco", obs)


def _quilt(name, x0, x1, half_w, top, material, seed=0):
    """Colcha caindo por cima do colchão: plana em cima, desce pelos lados até o chão e fica um pouco no chão."""
    rnd = random.Random(seed)
    W = half_w + top * 1.3 + 0.10  # meia largura da colcha esticada

    def across(d):
        if d < half_w:
            return d, top + 0.012
        if d < half_w + top * 1.3:
            t = (d - half_w) / (top * 1.3)
            return half_w + 0.02 + math.sin(t * math.pi * 0.5) * 0.03, top + 0.012 - t * (top + 0.004)
        return half_w + 0.05 + (d - half_w - top * 1.3), 0.008

    def fn(u, v):
        x = x0 + (x1 - x0) * u
        s = (v - 0.5) * 2 * W
        zz, y = across(abs(s))
        z = math.copysign(zz, s)
        # pé da colcha: depois do colchão desce até o chão
        if x > x1 - 0.12:
            t = (x - (x1 - 0.12)) / 0.12
            y = y - t * (y - 0.008) * 0.9
            x = x1 - 0.12 + t * 0.07
        y += 0.008 * math.sin(u * 23 + seed) * math.sin(v * 17) + noise.noise(Vector((u * 5, v * 5, seed))) * 0.01
        return (x, y, z)

    ob = solidify(subsurf(grid(name, 30, 26, fn, material, uv_scale=(1.0, 1.0)), 1), 0.01)
    return ob


def cama_tico():
    """Origem: a marca TicoDeitado (o meio do papelão de antes). A cabeça fica para -x (o fundo do beco)."""
    reset()
    M = materials()
    obs = []
    obs.append(card("Papelao", (0.10, 0.0, 0.0), (1.30, 0.94), math.radians(2), M["papelao"], 0.02, 1))
    obs.append(card("PapelaoCabeceira", (-0.33, 0.010, -0.12), (0.62, 0.52), math.radians(-9), M["papelao"], 0.015, 2))
    obs.append(lumpy_box("Colchao", (0.12, 0.048, 0.0), (1.12, 0.07, 0.66), M["saco"], 0.012, 1, uv_scale=0.9))
    obs.append(lumpy_box("Travesseiro", (-0.34, 0.098, 0.02), (0.30, 0.05, 0.36), M["saco"], 0.008, 3, uv_scale=1.6))
    obs.append(_quilt("Colcha", -0.10, 0.74, 0.33, 0.085, M["colcha"], 4))
    # a dobra da colcha virada na altura do peito
    roll = [(-0.10, 0.10, z) for z in [-0.44 + 0.88 * i / 10 for i in range(11)]]
    rolled = tube("DobraColcha", roll, 0.022, M["colcha"], sides=9, uv_len=0.9)
    rolled.scale = (1.0, 1.0, 0.55)
    obs.append(rolled)
    spots = []
    rnd = random.Random(7)
    for _ in range(90):
        side = rnd.choice((-1, 1))
        if rnd.random() < 0.6:
            spots.append((rnd.uniform(-0.45, 0.70), rnd.uniform(0.01, 0.05), side * rnd.uniform(0.32, 0.40), 0.02))
        else:
            spots.append((rnd.choice((-0.47, 0.70)) + rnd.uniform(-0.05, 0.05), rnd.uniform(0.01, 0.05), rnd.uniform(-0.35, 0.35), 0.02))
    for _ in range(40):
        spots.append((rnd.uniform(-0.6, 0.8), 0.006, rnd.uniform(-0.6, 0.6), 0.05))
    obs.append(strands("Palha", spots, M["palha"], 8))
    export("cama_tico", obs)


def cama_tika():
    """Origem: a marca TikaSentada (onde ela senta e dorme)."""
    reset()
    M = materials()
    obs = []
    obs.append(card("Papelao", (0.0, 0.0, 0.0), (0.86, 0.62), math.radians(12), M["papelao"], 0.015, 5))
    blanket = lumpy_box("Manta", (0.02, 0.032, 0.0), (0.62, 0.045, 0.44), M["colcha"], 0.006, 6, uv_scale=0.6)
    blanket.rotation_euler = (0, 0, math.radians(8))
    obs.append(blanket)
    corner = lumpy_box("PontaDobrada", (0.22, 0.062, 0.12), (0.22, 0.02, 0.2), M["colcha"], 0.004, 7, round_levels=2, uv_scale=0.6)
    obs.append(corner)
    pillow = tube("Rolinho", [(-0.30, 0.075, z) for z in (-0.17, -0.06, 0.06, 0.17)], 0.045, M["panos"], sides=10, uv_len=0.5)
    obs.append(pillow)
    export("cama_tika", obs)


def assento():
    """Origem: a marca TicoSentado (encostado na parede do fundo)."""
    reset()
    M = materials()
    obs = [lumpy_box("SacoDobrado", (0.02, 0.028, 0.0), (0.44, 0.05, 0.38), M["saco"], 0.008, 9, uv_scale=1.2),
           lumpy_box("SacoDeCima", (0.0, 0.065, -0.02), (0.34, 0.03, 0.3), M["saco"], 0.006, 10, uv_scale=1.4)]
    export("assento", obs)


def varal():
    """Origem: o pé da parede do fundo, a 0,23 m da parede do sapateiro (z para o norte = para a parede)."""
    reset()
    M = materials()
    obs = []
    L = 2.35  # termina antes da janela do sapateiro
    rope = [(L * i / 30, 2.13 - 0.12 * math.sin(math.pi * i / 30), 0.0) for i in range(31)]
    obs.append(tube("Corda", rope, 0.006, M["corda"], sides=5, uv_len=0.1))
    obs.append(stick("Toco", (L, 2.13, 0.24), (L, 2.12, -0.03), 0.022, M["madeira"], 0.0, 20))
    obs.append(tube("Prego", [(0.0, 2.13, 0.0), (0.06, 2.13, 0.0)], 0.007, M["ferro"], 5))

    def rope_y(x):
        return 2.13 - 0.12 * math.sin(math.pi * x / L)

    pieces = [(0.45, 0.40, 0.50), (1.10, 0.46, 0.40), (1.78, 0.36, 0.52)]
    for i, (cx, w, h) in enumerate(pieces):
        def fn(u, v, cx=cx, w=w, h=h, i=i):
            x = cx + (u - 0.5) * w
            top = rope_y(x)
            # a parte de trás (dobrada por cima da corda) é curta: v < 0,15 = atrás, v > 0,15 = frente
            if v < 0.15:
                t = v / 0.15
                y = top - (1 - t) * 0.09
                z = -0.012
            else:
                t = (v - 0.15) / 0.85
                y = top - t * (h + 0.04 * math.sin(u * 9 + i))
                z = 0.012 + 0.025 * math.sin(u * math.pi * 3 + i) * t + noise.noise(Vector((u * 4, v * 4, i))) * 0.015
            return (x, y, z)
        ob = grid("Pano%d" % i, 16, 20, fn, M["panos"], uv_scale=(1.0, 1.0))
        layer = ob.data.uv_layers[0]
        for d in layer.data:
            d.uv = (i * 0.25 + d.uv[0] * 0.25, d.uv[1])
        obs.append(solidify(subsurf(ob, 1), 0.004))
        for k, dx in enumerate((-w * 0.38, w * 0.38)):
            x = cx + dx
            obs.append(tube("Pregador%d_%d" % (i, k), [(x, rope_y(x) + 0.03, 0.0), (x, rope_y(x) - 0.04, 0.0)], 0.009,
                            M["madeira"], 5))
    export("varal", obs)


def lenha():
    """Origem: no chão, no canto do fundo com a casa da viúva."""
    reset()
    M = materials()
    obs = []
    rnd = random.Random(30)
    for i in range(9):
        y = 0.035 + (i // 4) * 0.05
        z = (i % 4 - 1.5) * 0.06 + rnd.uniform(-0.01, 0.01) + (0.03 if i >= 4 else 0.0)
        L = rnd.uniform(0.5, 0.7)
        x0 = rnd.uniform(-0.05, 0.05)
        obs.append(stick("Graveto%d" % i, (x0, y, z), (x0 + L, y + rnd.uniform(-0.01, 0.01), z + rnd.uniform(-0.04, 0.04)),
                         rnd.uniform(0.022, 0.035), M["madeira"], 0.02, 31 + i))
    obs.append(coil("Amarra", (0.32, 0.07, 0.03), (1, 0, 0), 0.13, 3, 0.05, M["corda"], 0.008))
    export("lenha", obs)


def cinzas():
    """Origem: o meio da fogueirinha (dentro da roda de pedras)."""
    reset()
    M = materials()
    obs = []

    def ash(u, v):
        r = 0.17 * u
        a = v * 2 * math.pi
        h = 0.02 * (1 - u * u) + noise.noise(Vector((math.cos(a) * u * 4, math.sin(a) * u * 4, 2))) * 0.004
        return (math.cos(a) * r, 0.004 + h, math.sin(a) * r)

    disc = grid("Cinza", 6, 24, ash, M["cinza"])
    for d, l in zip(disc.data.uv_layers[0].data, disc.data.loops):
        co = disc.data.vertices[l.vertex_index].co
        d.uv = (co.x / 0.34 + 0.5, -co.y / 0.34 + 0.5)
    obs.append(disc)
    rnd = random.Random(60)
    stone = mat("PedraSuja", None, (0.1, 0.092, 0.085), 1.0)
    for i in range(10):
        a = i * 2 * math.pi / 10 + rnd.uniform(-0.12, 0.12)
        r = 0.23 + rnd.uniform(-0.015, 0.015)
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=1.0)
        ob = bpy.context.active_object
        ob.name = "Pedra%d" % i
        sx, sy, sz = rnd.uniform(0.045, 0.065), rnd.uniform(0.03, 0.045), rnd.uniform(0.04, 0.055)
        for v in ob.data.vertices:
            n = noise.noise(v.co * 2.2 + Vector((i, i * 2, 0))) * 0.25
            v.co = Vector((v.co.x * sx * (1 + n), v.co.y * sz * (1 + n), v.co.z * sy * (1 + n)))
        ob.location = B((math.cos(a) * r, sy * 0.6, math.sin(a) * r))
        ob.rotation_euler = (0, 0, -a)
        ob.data.materials.append(stone)
        for poly in ob.data.polygons:
            poly.use_smooth = True
        obs.append(ob)
    for i in range(4):
        a = i * math.pi / 2 + rnd.uniform(-0.3, 0.3)
        p0 = (math.cos(a) * 0.2, 0.03, math.sin(a) * 0.2)
        p1 = (math.cos(a) * 0.02, 0.06, math.sin(a) * 0.02)
        obs.append(stick("Toco%d" % i, p0, p1, 0.022, M["carvao"], 0.0, 61 + i, r_end=0.012))
    export("cinzas", obs)


def prateleira():
    """Origem: pé da parede do fundo, na ponta sul da tábua (a tábua vai para o norte, +z)."""
    reset()
    M = materials()
    obs = []
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    plank = bpy.context.active_object
    plank.name = "Tabua"
    plank.scale = (0.2, 0.8, 0.025)  # Blender: x, y(-z do Godot), z(y do Godot)
    plank.location = B((0.1, 1.15, 0.4))
    bpy.ops.object.transform_apply(scale=True)
    layer = plank.data.uv_layers.new(name="UVMap")
    for poly in plank.data.polygons:
        for li in poly.loop_indices:
            co = plank.data.vertices[plank.data.loops[li].vertex_index].co
            layer.data[li].uv = (co.x * 2 + co.z, -co.y * 1.2)
    plank.data.materials.append(M["madeira"])
    obs.append(plank)
    for k, z in enumerate((0.12, 0.68)):
        obs.append(stick("Cavilha%d" % k, (-0.02, 1.125, z), (0.17, 1.12, z), 0.018, M["madeira"], 0.0, 70 + k))
    export("prateleira", obs)


PIECES = {"barraco": barraco, "cama_tico": cama_tico, "cama_tika": cama_tika, "assento": assento, "varal": varal,
          "lenha": lenha, "cinzas": cinzas, "prateleira": prateleira}

for name, fn in PIECES.items():
    if ONLY and ONLY != name:
        continue
    fn()
