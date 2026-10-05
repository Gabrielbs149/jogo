"""Passo 2 (dentro do Blender, via bl.py code): acha de que ângulo a malha gerada bate com a silhueta do desenho.
A malha importada tem que se chamar geometry_0. Imprime os melhores (IoU, azimute, elevação) -> usar em pintar_projecao.py.
"""
import bpy, numpy as np, math
m = bpy.data.objects["geometry_0"]
M = np.array(m.matrix_world)
co = np.empty(len(m.data.vertices) * 3); m.data.vertices.foreach_get("co", co)
co = co.reshape(-1, 3); co = co @ M[:3, :3].T + M[:3, 3]
co = co[::4]
mask = np.load(r"C:\dev\jogo\art_src\ref\ref_mask.npy")
ys, xs = np.nonzero(mask)
y0, y1, x0, x1 = ys.min(), ys.max(), xs.min(), xs.max()
N = 96
ref = mask[y0:y1+1, x0:x1+1]
# reamostra máscara de referência para NxN mantendo proporção na caixa
def resample(mk, n):
    h, w = mk.shape
    yi = (np.arange(n) * h / n).astype(int); xi = (np.arange(n) * w / n).astype(int)
    return mk[yi][:, xi]
refn = resample(ref, N)
best = []
for el in range(6, 21, 2):
    for az in range(132, 149, 2):
        a = math.radians(az); e = math.radians(el)
        d = np.array([math.sin(a)*math.cos(e), -math.cos(a)*math.cos(e), -math.sin(e)])  # direção do olhar (câmera -> objeto)
        right = np.array([-math.cos(a), -math.sin(a), 0.0])
        up = np.cross(right, d); up /= np.linalg.norm(up)
        u = co @ right; v = co @ up
        u = (u - u.min()) / (u.max() - u.min()); v = (v.max() - v) / (v.max() - v.min())
        img = np.zeros((N, N), bool)
        img[np.clip((v * (N-1)).astype(int), 0, N-1), np.clip((u * (N-1)).astype(int), 0, N-1)] = True
        # dilata 1 px para preencher buracos
        img = img | np.roll(img, 1, 0) | np.roll(img, -1, 0) | np.roll(img, 1, 1) | np.roll(img, -1, 1)
        iou = (img & refn).sum() / (img | refn).sum()
        best.append((iou, az, el))
best.sort(reverse=True)
print(best[:6])
