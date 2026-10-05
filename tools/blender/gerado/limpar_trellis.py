"""Limpa o modelo do TRELLIS: tira o chão, junta vértices, remove sobras, vira a frente para +Y, ajusta altura e reduz faces.
Uso: blender --background --factory-startup --python bl_limpa_trellis.py -- entrada.glb saida.glb saida.blend [altura] [faces] [giro_graus] [desenho_ref.png]
Ex.: ... -- art_src/tico_lirou_trellis_bruto.glb actors/tico_lirou/tico_lirou.glb art_src/tico_lirou.blend 1.18 30000 180 art_src/ref/tico_ref.png
"""
import bpy, bmesh, sys, math
import numpy as np
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
src, out_glb, out_blend = argv[0], argv[1], argv[2]
HEIGHT = float(argv[3]) if len(argv) > 3 else 1.18
FACES = int(argv[4]) if len(argv) > 4 else 30000
TURN = float(argv[5]) if len(argv) > 5 else 180.0

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
obj = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
for o in list(bpy.context.scene.objects):
    if o != obj:
        bpy.data.objects.remove(o)
obj.parent = None
bpy.context.view_layer.objects.active = obj
obj.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
me = obj.data

# textura para saber a cor de cada face
img = None
for n in obj.active_material.node_tree.nodes:
    if n.type == "TEX_IMAGE" and n.image:
        img = n.image
        break
W, H = img.size
pix = np.array(img.pixels[:]).reshape(H, W, 4)
pix0 = pix.copy()

# cores: casa o histograma da textura com o do desenho (o TRELLIS escurece tudo)
REF = argv[6] if len(argv) > 6 else ""
if REF:
    ref = bpy.data.images.load(REF)
    rw, rh = ref.size
    rp = np.array(ref.pixels[:]).reshape(rh, rw, 4)[:, :, :3].reshape(-1, 3)
    rl = rp.mean(1); rs = rp.max(1) - rp.min(1)
    rp = rp[(rl > 0.12) & (rl < 0.9) & ~((rl > 0.6) & (rs < 0.18))]
    tp = pix[:, :, :3].reshape(-1, 3)
    tl = tp.mean(1); ts = tp.max(1) - tp.min(1)
    used = (tp.max(1) > 0.02) & ~((tl > 0.75) & (ts < 0.12))  # fora fundo vazio e o chão branco
    for ch in range(3):
        src_v = tp[used, ch]
        order = np.argsort(src_v)
        q = np.empty_like(src_v); q[order] = np.linspace(0, 1, len(src_v))
        tp[used, ch] = np.quantile(rp[:, ch], q)
    # o que era azul forte (olhos) mantém o azul original, só mais claro: o casamento por canal desbota
    t0 = pix0[:, :, :3].reshape(-1, 3)
    blue = used & (t0[:, 2] - np.maximum(t0[:, 0], t0[:, 1]) > 0.08)
    tp[blue] = np.clip(t0[blue] * 1.35, 0, 1)
    print("texels azuis preservados:", int(blue.sum()))
    pix[:, :, :3] = tp.reshape(H, W, 3)
    img.pixels[:] = pix.ravel()
    img.update()
    print("cores casadas com", REF)

bm = bmesh.new(); bm.from_mesh(me)
uv = bm.loops.layers.uv.active
zs = np.array([v.co.z for v in bm.verts])
zmin = zs.min()

def face_lum(f):
    c = sum((l[uv].uv for l in f.loops), Vector((0, 0))) / len(f.loops)
    x = min(W - 1, max(0, int(c.x * W))); y = min(H - 1, max(0, int(c.y * H)))
    return pix0[y, x, :3].mean()

# 1) chão: faces horizontais, claras, na faixa de altura do chão e fora do pé (largas)
floor_z = None
cand = [f for f in bm.faces if abs(f.normal.z) > 0.9 and face_lum(f) > 0.7]
if cand:
    zc = np.array([f.calc_center_median().z for f in cand])
    hist, edges = np.histogram(zc, bins=40)
    k = int(np.argmax(hist)); floor_z = (edges[k] + edges[k + 1]) / 2
kill = [f for f in cand if floor_z is not None and abs(f.calc_center_median().z - floor_z) < 0.02]
bmesh.ops.delete(bm, geom=kill, context="FACES")
print("chão removido:", len(kill), "faces em z", floor_z)

# 2) junta vértices (TRELLIS entrega em pedaços) e remove ilhas pequenas
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0008)
bm.verts.ensure_lookup_table(); bm.faces.ensure_lookup_table()
seen = set(); parts = []
for f in bm.faces:
    if f.index in seen:
        continue
    stack = [f]; comp = []; seen.add(f.index)
    while stack:
        x = stack.pop(); comp.append(x)
        for e in x.edges:
            for y in e.link_faces:
                if y.index not in seen:
                    seen.add(y.index); stack.append(y)
    parts.append(comp)
parts.sort(key=len, reverse=True)
total = sum(len(p) for p in parts)
zr = max(v.co.z for v in bm.verts) - min(v.co.z for v in bm.verts)
z0 = min(v.co.z for v in bm.verts)
def flat_on_floor(p):
    zz = [v.co.z for f in p for v in f.verts]
    return max(zz) - min(zz) < zr * 0.03 and max(zz) < z0 + zr * 0.12
small = [f for p in parts if len(p) < total * 0.002 or (p is not parts[0] and flat_on_floor(p)) for f in p]
bmesh.ops.delete(bm, geom=small, context="FACES")
print("partes:", len(parts), "ilhas removidas:", len(small), "z0", round(z0, 3), "zr", round(zr, 3))
bm.to_mesh(me); bm.free()

# 3) reduz faces
if len(me.polygons) > FACES:
    dec = obj.modifiers.new("Reduz", "DECIMATE"); dec.ratio = FACES / len(me.polygons)
    bpy.ops.object.modifier_apply(modifier=dec.name)

# 4) frente para +Y, pés na origem, altura do herói
co = np.empty(len(me.vertices) * 3); me.vertices.foreach_get("co", co); co = co.reshape(-1, 3)
t = math.radians(TURN)
co[:, :2] = co[:, :2] @ np.array([[math.cos(t), math.sin(t)], [-math.sin(t), math.cos(t)]])
s = HEIGHT / (co[:, 2].max() - co[:, 2].min())
co *= s
co[:, 0] -= (co[:, 0].max() + co[:, 0].min()) / 2
co[:, 1] -= (co[:, 1].max() + co[:, 1].min()) / 2
co[:, 2] -= co[:, 2].min()
me.vertices.foreach_set("co", co.ravel()); me.update()
# 5) tiras deitadas no chão sem nada em cima (sombra que a IA vira geometria): grade de 10 cm
bm = bmesh.new(); bm.from_mesh(me)
cell = lambda c: (int(math.floor(c.x * 10)), int(math.floor(c.y * 10)))
low = [f for f in bm.faces if max(v.co.z for v in f.verts) < 0.05]
above = {cell(f.calc_center_median()) for f in bm.faces if 0.1 < f.calc_center_median().z < 0.35}
cells = {cell(f.calc_center_median()) for f in low}
groups, seen = [], set()
for c in cells:
    if c in seen:
        continue
    stack, grp = [c], set()
    seen.add(c)
    while stack:
        a = stack.pop(); grp.add(a)
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                b = (a[0] + dx, a[1] + dy)
                if b in cells and b not in seen:
                    seen.add(b); stack.append(b)
    groups.append(grp)
loose = set().union(*[g for g in groups if not any(
    (a[0] + dx, a[1] + dy) in above for a in g for dx in (-1, 0, 1) for dy in (-1, 0, 1))]) if groups else set()
kill = [f for f in low if cell(f.calc_center_median()) in loose]
bmesh.ops.delete(bm, geom=kill, context="FACES")
print("tiras no chão removidas:", len(kill), "faces em", sorted(loose))
bm.to_mesh(me); bm.free()
for p in me.polygons:
    p.use_smooth = True
obj.name = "TicoLirou"; me.name = "TicoLirou"
print("final:", len(me.polygons), "faces")

bpy.ops.export_scene.gltf(filepath=out_glb, export_format="GLB", export_apply=True, export_yup=True)
img.pack()
bpy.ops.wm.save_as_mainfile(filepath=out_blend)
