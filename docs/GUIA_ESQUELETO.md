# Guia: esqueleto e animações de um personagem (do jeito que o projeto faz desde a D028)

A ideia: o personagem ganha um **esqueleto humanoide padrão** (nomes de osso iguais aos do Godot) e as animações
**não são feitas à mão** — vêm prontas de outro personagem (KayKit, 76 animações) pelo *retarget* do Godot.
Serve para qualquer personagem de duas pernas e dois braços (Tico, Tika, Namfoodle, José Maria...).

## Jeito rápido (o que o Claude roda)
1. Modelo no Blender em `art_src/<nome>.blend`, um objeto só, **pés no chão (Z = 0)**, olhando para **+Y**.
2. `blender -b --factory-startup -P tools/blender/gerado/rig_tico_humanoide.py -- C:/dev/jogo`
   (copie o arquivo e ajuste a tabela `BONES` com as juntas do novo personagem, em metros).
3. No Godot, no `.glb` gerado: aba **Importar → Esqueleto3D → Retarget → Bone Map** = `mapa_ossos_<nome>.tres`,
   "Rename Bones" ligado, "Unique Node" = `GeneralSkeleton`, "Fix Silhouette" ligado só nos braços.
4. Na cena do modelo, um `AnimationPlayer` com a biblioteca `res://assets/kits/kaykit/animacoes/humanoide.res`.
5. No `Animator` do herói, escolha os nomes (Idle, Walking_A, Running_A, Dualwield_Melee_Attack_Slice...).

## Jeito à mão no Blender (se quiser fazer/consertar você mesmo)
**1. Pose do modelo.** Em pé, braços abertos (em T ou A), pernas um pouco separadas. Se o modelo veio colado
(braço grudado na barriga), o peso vai vazar — separe antes no modo de escultura (Grab) ou peça um modelo novo
em pose T ao gerar (TRELLIS/Hunyuan: escreva "T-pose, arms out" no pedido).

**2. Esqueleto.** `Shift+A → Armadura → Osso único`. No modo de edição (`Tab`), com o osso selecionado:
`E` puxa um osso novo da ponta. Monte nesta ordem e com **estes nomes** (o Godot reconhece sozinho):
`Hips → Spine → Chest → Neck → Head`; do Chest: `LeftUpperArm → LeftLowerArm → LeftHand` (e Right...);
do Hips: `LeftUpperLeg → LeftLowerLeg → LeftFoot` (e Right...). Rabo: `Tail1 → Tail2 → Tail3` saindo do Hips.
Dicas: o lado **esquerdo é o esquerdo do personagem**; joelhos e cotovelos levemente dobrados (para frente e
para trás, respectivamente) para o Blender saber para onde dobrar; use `Shift+E` com espelho em X ligado
(menu *Armature → Symmetrize*) para fazer um lado só.

**3. Pele (pesos).** Modo objeto: selecione o **modelo**, depois o **esqueleto** (Shift+clique), `Ctrl+P →
Com pesos automáticos`. Teste: modo de pose (`Ctrl+Tab`), gire os ossos (`R`). Onde a malha esticar errado,
vá no **Pintar pesos** (selecione o modelo, *Weight Paint*), escolha o osso na lista *Grupos de vértices* e pinte
(vermelho = segue o osso, azul = não segue). Pincel *Smooth* nas juntas.
> Se aparecer "Bone Heat Weighting: failed": a malha tem buracos ou é muito pequena. Escale tudo 10x antes
> (`S 10`, `Ctrl+A → Escala`), faça os pesos e volte (`S 0.1`). Se ainda falhar, use o script do jeito rápido —
> ele calcula os pesos sem depender disso.

**4. Exportar.** *Arquivo → Exportar → glTF (.glb)*, marcando "Selecionados", "+Y para cima", sem animações.
Salve em `actors/<nome>/` e siga os passos 3 a 5 do jeito rápido.

## Personagem que já vem com esqueleto e animações (ex.: Namfoodle, D032)
1. Copie o `.glb` para `art_src/` e prepare com um script como `tools/blender/gerado/preparar_naumfode.py` (tira sobras, corrige material).
2. Crie o mapa de ossos dele em `tools/art/criar_mapas_de_ossos.gd` (nome do osso dele → osso padrão) e ligue no import (*Retarget → Bone Map*).
3. No `Animator` do herói: use os nomes das animações dele e, no campo **Extra Library**, a biblioteca do KayKit para o que faltar (nome com prefixo: `kaykit/Dodge_Forward`).

## Coisas na mão (pão, espada, livro)
Na cena: `[na mão: Pao]` prende o nó na palma do osso `RightHand`. No Godot à mão: um nó `BoneAttachment3D`
filho do `GeneralSkeleton`, *Bone Name* = `RightHand`, e o objeto dentro dele.
