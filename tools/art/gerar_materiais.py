"""Gera assets/materials/*.tres com as texturas do Quaternius (D026), em projeção triplanar no mundo
(a textura não estica, seja qual for o tamanho da peça). Os nomes de arquivo são os mesmos de antes,
então tudo que já usava um material (chão, praça, ruínas...) troca sozinho.
Uso: python tools/art/gerar_materiais.py
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
V = "res://assets/kits/quaternius/vila/"

# nome: (textura base, metros por repetição, tom, tem ORM?, rugosidade separada?)
MATS = {
    "reboco": ("T_Plaster", 2.5, (1, 1, 1)),
    "reboco_barro": ("T_Plaster", 2.5, (1.0, 0.82, 0.62)),
    "telha": ("T_RoundTiles", 2.0, (1, 1, 1)),
    "calcada": ("T_Brick", 2.0, (1, 1, 1)),
    "caminho": ("T_UnevenBrick", 2.5, (0.92, 0.88, 0.8)),
    "tabuas": ("T_WoodTrim", 2.0, (1, 1, 1)),
    "muralha": ("T_UnevenBrick", 2.5, (1, 1, 1)),
    "arenito": ("T_Brick", 2.0, (1.0, 0.86, 0.66)),
    "pedra_poco": ("T_UnevenBrick", 1.6, (1, 1, 1)),
    "palha": ("T_RoundTiles", 1.6, (0.95, 0.8, 0.45)),
    "tijolo_vermelho": ("T_RedBrick", 2.0, (1, 1, 1)),
}
# chão: cor + manchas (ruído) do kit
GROUND = {
    "chao_cascalho": ((0.78, 0.66, 0.48), 9.0),
    "areia": ((0.86, 0.72, 0.52), 12.0),
    "areia_ethera": ((0.88, 0.6, 0.44), 12.0),
}


def tex_lines(name):
    files = {
        "albedo": V + name + "_BaseColor.png",
        "normal": V + name + "_Normal.png",
        "orm": V + name + "_ORM.png",
        "rough": V + name + "_Roughness.png",
    }
    return {k: v for k, v in files.items() if os.path.exists(os.path.join(ROOT, v.replace("res://", "")))}


for mat, (tex, meters, tint) in MATS.items():
    t = tex_lines(tex)
    s = 1.0 / meters
    use_orm = "orm" in t
    kind = "ORMMaterial3D" if use_orm else "StandardMaterial3D"
    ext, body, n = [], [], 1
    for key in ("albedo", "normal", "orm", "rough"):
        if key in t:
            ext.append('[ext_resource type="Texture2D" path="%s" id="%d_%s"]' % (t[key], n, key))
            n += 1
    ids = {line.split('id="')[1].split("_", 1)[1].rstrip('"]'): line.split('id="')[1].rstrip('"]') for line in ext}
    body.append('resource_name = "%s"' % mat)
    body.append("albedo_color = Color(%g, %g, %g, 1)" % tint)
    body.append('albedo_texture = ExtResource("%s")' % ids["albedo"])
    if use_orm:
        body.append('orm_texture = ExtResource("%s")' % ids["orm"])
    elif "rough" in ids:
        body.append('roughness_texture = ExtResource("%s")' % ids["rough"])
        body.append("roughness_texture_channel = 0")
    if "normal" in ids:
        body.append("normal_enabled = true")
        body.append('normal_texture = ExtResource("%s")' % ids["normal"])
    body.append("uv1_scale = Vector3(%g, %g, %g)" % (s, s, s))
    body.append("uv1_triplanar = true")
    body.append("uv1_world_triplanar = true")
    body.append("texture_filter = 5")
    text = '[gd_resource type="%s" format=3]\n\n%s\n\n[resource]\n%s\n' % (kind, "\n".join(ext), "\n".join(body))
    open(os.path.join(ROOT, "assets", "materials", mat + ".tres"), "w", encoding="utf-8", newline="\n").write(text)

for mat, (color, meters) in GROUND.items():
    s = 1.0 / meters
    text = ('[gd_resource type="StandardMaterial3D" format=3]\n\n'
            '[ext_resource type="Texture2D" path="%sT_Noise_Terrain_suave.png" id="1_noise"]\n\n'
            '[resource]\nresource_name = "%s"\nalbedo_color = Color(%g, %g, %g, 1)\nalbedo_texture = ExtResource("1_noise")\n'
            'roughness = 1.0\nuv1_scale = Vector3(%g, %g, %g)\nuv1_triplanar = true\nuv1_world_triplanar = true\ntexture_filter = 5\n'
            ) % (V, mat, color[0], color[1], color[2], s, s, s)
    open(os.path.join(ROOT, "assets", "materials", mat + ".tres"), "w", encoding="utf-8", newline="\n").write(text)

print(sorted(f for f in os.listdir(os.path.join(ROOT, "assets", "materials"))))
