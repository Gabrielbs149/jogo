"""Passo 3 (dentro do Blender, via bl.py code): reduz a malha gerada, pinta projetando o desenho,
espelha para o lado que o desenho não mostra, preenche o resto por região e assa tudo numa textura 2048.
Ajuste AZ/EL (de achar_angulo.py), FACE_ROT (frente vira +Y) e HEIGHT. Cena "Gerado", malha "geometry_0".
"""
import bpy, bmesh, math
import numpy as np
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

S = r"C:\dev\jogo\art_src\ref"  # desenho recortado (tico_ref.png) + máscara (ref_mask.npy, de mascara.py)
AZ, EL = math.radians(140), math.radians(14)
FACE_ROT = -90.0  # graus em Z para a frente virar +Y
TARGET_FACES = 30000
HEIGHT = 1.18

scn = bpy.data.scenes["Gerado"]
bpy.context.window.scene = scn
src = bpy.data.objects["geometry_0"]

# --- 1) cópia reduzida, frente para +Y, pés na origem, altura do Tico antigo
old = bpy.data.objects.get("TicoGerado")
if old:
    bpy.data.objects.remove(old)
obj = src.copy(); obj.data = src.data.copy(); obj.name = "TicoGerado"; obj.data.name = "TicoGerado"
scn.collection.objects.link(obj)
obj.parent = None
obj.hide_render = False
obj.matrix_world = src.matrix_world.copy()
src.hide_set(True); src.hide_render = True
for o in scn.objects:
    if o.type == "EMPTY":
        o.hide_set(True)
dec = obj.modifiers.new("Reduz", "DECIMATE")
dec.ratio = TARGET_FACES / len(obj.data.polygons)
bpy.context.view_layer.objects.active = obj
for o in scn.objects:
    o.select_set(o == obj)
bpy.ops.object.modifier_apply(modifier=dec.name)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

me = obj.data
n = len(me.vertices)
co = np.empty(n * 3); me.vertices.foreach_get("co", co); co = co.reshape(-1, 3)

# --- 2) projeção: mesma convenção do ajuste de silhueta
d = np.array([math.sin(AZ) * math.cos(EL), -math.cos(AZ) * math.cos(EL), -math.sin(EL)])
right = np.array([-math.cos(AZ), -math.sin(AZ), 0.0])
up = np.cross(right, d); up /= np.linalg.norm(up)
u = co @ right; v = co @ up
mask = np.load(S + r"\ref_mask.npy")
ys, xs = np.nonzero(mask)
x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
img = bpy.data.images.get("tico_ref.png") or bpy.data.images.load(S + r"\tico_ref.png")
W, H = img.size
pix = np.array(img.pixels[:]).reshape(H, W, 4)[::-1, :, :3]  # linha 0 = topo
px = x0 + (u - u.min()) / (u.max() - u.min()) * (x1 - x0)
py = y0 + (v.max() - v) / (v.max() - v.min()) * (y1 - y0)

# --- 3) visibilidade: normal virada para a câmera e sem nada na frente
me.calc_normals_split() if hasattr(me, "calc_normals_split") else None
nor = np.empty(n * 3); me.vertices.foreach_get("normal", nor); nor = nor.reshape(-1, 3)
facing = nor @ (-d)
bm = bmesh.new(); bm.from_mesh(me)
bvh = BVHTree.FromBMesh(bm)
cam_dir = Vector((-d).tolist())
vis = np.zeros(n)
for i in range(n):
    if facing[i] < 0.2:
        continue
    p = Vector(co[i].tolist()) + cam_dir * 0.004
    hit = bvh.ray_cast(p, cam_dir, 5.0)
    if hit[0] is None:
        vis[i] = min(1.0, (facing[i] - 0.2) / 0.25)

# --- 4) cor por vértice: amostra o desenho evitando contorno preto, fundo branco e sombra do chão
lum = pix.mean(axis=2)
def sample(fx, fy):
    cx, cy = int(round(fx)), int(round(fy))
    if not (3 <= cx < W - 3 and 3 <= cy < H - 3):
        return None
    win = pix[cy - 3:cy + 4, cx - 3:cx + 4].reshape(-1, 3)
    wl = win.mean(axis=1)
    sat = win.max(axis=1) - win.min(axis=1)
    shadow = (win[:, 2] - np.maximum(win[:, 0], win[:, 1]) > 0.05) & (sat < 0.16) & (wl > 0.38)
    ok = win[(wl > 0.12) & (wl < 0.86) & ~((wl > 0.6) & (sat < 0.18)) & ~shadow]
    return np.median(ok, axis=0) if len(ok) >= 8 else None

cols = np.zeros((n, 3)); known = np.zeros(n, bool)
mode = np.zeros(n, int)  # 1 = visto no desenho, 2 = espelhado
for i in np.nonzero(vis > 0.3)[0]:
    c = sample(px[i], py[i])
    if c is None:
        vis[i] = 0.0
    else:
        cols[i] = c; known[i] = True; mode[i] = 1
vis[mode != 1] = 0.0
print("vértices visíveis com cor:", known.sum(), "de", n)

# --- 4b) espelho: o lado que o desenho não mostra usa o desenho refletido (personagem olha para −X, simetria em Y)
cyc = float(np.median(co[:, 1]))
flip = np.array([1.0, -1.0, 1.0])
umin, umax, vmin, vmax = u.min(), u.max(), v.min(), v.max()
dbg = [0, 0, 0]
for i in np.nonzero(~known)[0]:
    m = co[i].copy(); m[1] = 2 * cyc - m[1]
    mn = nor[i] * flip
    f = mn @ (-d)
    if f < 0.2:
        continue
    dbg[0] += 1
    # o ponto refletido é visível se o primeiro toque vindo da câmera cai perto dele
    mv = Vector(m.tolist())
    hit = bvh.ray_cast(mv + cam_dir * 3.0, -cam_dir, 6.0)
    if hit[0] is None or (hit[0] - mv).length > 0.05:
        continue
    dbg[1] += 1
    fx = x0 + ((m @ right) - umin) / (umax - umin) * (x1 - x0)
    fy = y0 + (vmax - (m @ up)) / (vmax - vmin) * (y1 - y0)
    c = sample(fx, fy)
    if c is None:
        continue
    cols[i] = c; known[i] = True; mode[i] = 2
    px[i], py[i] = fx, fy
    vis[i] = min(1.0, (f - 0.2) / 0.25)
# na costura entre lado visto e lado espelhado a projeção não é contínua: ali vale só a cor por vértice
for e in bm.edges:
    i, j = e.verts[0].index, e.verts[1].index
    if mode[i] and mode[j] and mode[i] != mode[j]:
        vis[i] = vis[j] = 0.0
print("espelhados:", (mode == 2).sum(), "virados", dbg[0], "livres", dbg[1], "cy", cyc)

# --- 4c) o que ainda falta copia a cor do vértice refletido mais próximo, se a superfície bate
from mathutils.kdtree import KDTree
kd = KDTree(n)
for i in range(n):
    kd.insert(co[i].tolist(), i)
kd.balance()
known1 = known.copy()
for i in np.nonzero(~known1)[0]:
    m = co[i].copy(); m[1] = 2 * cyc - m[1]
    for (_, j, dist) in kd.find_n(m.tolist(), 6):
        if known1[j] and dist < 0.06 and nor[i] @ (nor[j] * flip) > 0.4:
            cols[i] = cols[j]; known[i] = True
            break
print("refletidos por vizinho:", known.sum() - known1.sum())

# --- 5) preenche o resto por REGIÃO: paleta de 10 cores, cada vértice desconhecido recebe a região que mais aparece nos vizinhos
K = 10
kc = cols[known]
rng = np.random.default_rng(1)
cent = kc[rng.choice(len(kc), K, replace=False)]
for _ in range(25):
    lab = np.argmin(((kc[:, None, :] - cent[None]) ** 2).sum(2), axis=1)
    cent = np.array([kc[lab == k].mean(0) if (lab == k).any() else cent[k] for k in range(K)])
label = np.full(n, -1)
label[known] = np.argmin(((cols[known][:, None, :] - cent[None]) ** 2).sum(2), axis=1)
bm.verts.ensure_lookup_table()
nbr0 = [[e.other_vert(vt).index for e in vt.link_edges] for vt in bm.verts]
for _ in range(2000):
    todo = np.nonzero(label < 0)[0]
    if len(todo) == 0:
        break
    upd = {}
    for i in todo:
        ls = [label[j] for j in nbr0[i] if label[j] >= 0]
        if ls:
            upd[i] = max(set(ls), key=ls.count)
    if not upd:
        break
    for i, l in upd.items():
        label[i] = l
fill = ~known & (label >= 0)
cols[fill] = cent[label[fill]]
known |= fill
# suaviza só as bordas entre regiões preenchidas
for _ in range(2):
    newc = cols.copy()
    for i in np.nonzero(fill)[0]:
        newc[i] = (cols[i] * 2 + cols[nbr0[i]].sum(0)) / (2 + len(nbr0[i]))
    cols = newc

# --- 5b) resto (pedaços soltos) espalhando pela malha a partir dos vizinhos conhecidos
bm.verts.ensure_lookup_table()
nbr = [[e.other_vert(vt).index for e in vt.link_edges] for vt in bm.verts]
for it in range(2000):
    todo = np.nonzero(~known)[0]
    if len(todo) == 0:
        break
    newc = {}
    for i in todo:
        ks = [j for j in nbr[i] if known[j]]
        if ks:
            newc[i] = cols[ks].mean(axis=0)
    if not newc:
        break
    for i, c in newc.items():
        cols[i] = c; known[i] = True
print("preenchido em", it, "passos; sem cor:", (~known).sum())
bm.free()

cols = np.where(cols <= 0.04045, cols / 12.92, ((cols + 0.055) / 1.055) ** 2.4)  # sRGB -> linear
attr = me.color_attributes.get("Cor") or me.color_attributes.new("Cor", "FLOAT_COLOR", "POINT")
rgba = np.concatenate([cols, np.ones((n, 1))], axis=1).ravel()
attr.data.foreach_set("color", rgba)
va = me.attributes.get("Vis") or me.attributes.new("Vis", "FLOAT", "POINT")
va.data.foreach_set("value", vis)

# --- 6) UVs: "Proj" (projeção do desenho) e "UVMap" (desdobramento para a textura final)
while me.uv_layers:
    me.uv_layers.remove(me.uv_layers[0])
uv_bake = me.uv_layers.new(name="UVMap")
uv_proj = me.uv_layers.new(name="Proj")
li = np.empty(len(me.loops), dtype=np.int64); me.loops.foreach_get("vertex_index", li)
puv = np.stack([px[li] / W, 1.0 - py[li] / H], axis=1).ravel()
uv_proj.data.foreach_set("uv", puv)
me.uv_layers.active = uv_bake
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.003)
bpy.ops.object.mode_set(mode="OBJECT")
for p in me.polygons:
    p.use_smooth = True

# --- 7) material de projeção (desenho onde se vê, cor espalhada no resto)
mat = bpy.data.materials.get("Tico_proj") or bpy.data.materials.new("Tico_proj")
mat.use_nodes = True
nt = mat.node_tree; nt.nodes.clear()
out = nt.nodes.new("ShaderNodeOutputMaterial")
bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
tex = nt.nodes.new("ShaderNodeTexImage"); tex.image = img; tex.extension = "EXTEND"
uvn = nt.nodes.new("ShaderNodeUVMap"); uvn.uv_map = "Proj"
cattr = nt.nodes.new("ShaderNodeVertexColor"); cattr.layer_name = "Cor"
vattr = nt.nodes.new("ShaderNodeAttribute"); vattr.attribute_name = "Vis"
bw = nt.nodes.new("ShaderNodeRGBToBW")
white = nt.nodes.new("ShaderNodeMapRange"); white.inputs[1].default_value = 0.86; white.inputs[2].default_value = 0.95
white.inputs[3].default_value = 1.0; white.inputs[4].default_value = 0.0
mul = nt.nodes.new("ShaderNodeMath"); mul.operation = "MULTIPLY"
mix = nt.nodes.new("ShaderNodeMix"); mix.data_type = "RGBA"
L = nt.links.new
L(uvn.outputs["UV"], tex.inputs["Vector"])
L(tex.outputs["Color"], bw.inputs[0])
L(bw.outputs[0], white.inputs[0])
L(white.outputs[0], mul.inputs[0])
L(vattr.outputs["Fac"], mul.inputs[1])
L(mul.outputs[0], mix.inputs["Factor"])
L(cattr.outputs["Color"], mix.inputs[6])
L(tex.outputs["Color"], mix.inputs[7])
L(mix.outputs[2], bsdf.inputs["Base Color"])
bsdf.inputs["Roughness"].default_value = 0.85
L(bsdf.outputs[0], out.inputs[0])
bake_img = bpy.data.images.get("Tico_cor") or bpy.data.images.new("Tico_cor", 2048, 2048)
bake_node = nt.nodes.new("ShaderNodeTexImage"); bake_node.image = bake_img; bake_node.name = "AlvoBake"
uvb = nt.nodes.new("ShaderNodeUVMap"); uvb.uv_map = "UVMap"
L(uvb.outputs["UV"], bake_node.inputs["Vector"])
nt.nodes.active = bake_node
me.materials.clear(); me.materials.append(mat)

# --- 8) assa a cor numa textura 2048 no UVMap
scn.render.engine = "CYCLES"
scn.cycles.samples = 4
scn.render.bake.use_pass_direct = False
scn.render.bake.use_pass_indirect = False
scn.render.bake.use_pass_color = True
scn.render.bake.margin = 8
bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"}, uv_layer="UVMap")
bake_img.filepath_raw = r"C:\dev\jogo\art_src\tico_lirou_cor.png"
bake_img.file_format = "PNG"
bake_img.save()

# --- 9) material final simples (só a textura assada) e ajuste de escala/posição
final = bpy.data.materials.get("Tico") or bpy.data.materials.new("Tico")
final.use_nodes = True
ft = final.node_tree; ft.nodes.clear()
fo = ft.nodes.new("ShaderNodeOutputMaterial"); fb = ft.nodes.new("ShaderNodeBsdfPrincipled")
ftex = ft.nodes.new("ShaderNodeTexImage"); ftex.image = bake_img
ft.links.new(ftex.outputs["Color"], fb.inputs["Base Color"])
fb.inputs["Roughness"].default_value = 0.85
ft.links.new(fb.outputs[0], fo.inputs[0])
me.materials.clear(); me.materials.append(final)
me.uv_layers.remove(me.uv_layers["Proj"])

# frente do personagem (−X na malha gerada) passa a ser +Y; pés no chão; altura 1,18 m
co = np.empty(n * 3); me.vertices.foreach_get("co", co); co = co.reshape(-1, 3)
t = math.radians(FACE_ROT)
co[:, :2] = co[:, :2] @ np.array([[math.cos(t), math.sin(t)], [-math.sin(t), math.cos(t)]])
s = HEIGHT / (co[:, 2].max() - co[:, 2].min())
co = co * s
co[:, 0] -= (co[:, 0].max() + co[:, 0].min()) / 2
co[:, 1] -= (co[:, 1].max() + co[:, 1].min()) / 2
co[:, 2] -= co[:, 2].min()
me.vertices.foreach_set("co", co.ravel()); me.update()
scn.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE"
print("pronto:", len(me.polygons), "faces")
