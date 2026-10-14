# Referências de combate (D081)

O que estudamos de outros jogos e projetos para o combate do Tico. Mecânica não tem dono: copiamos o *como funciona*,
nunca o código ou a arte de jogo fechado.

## Clair Obscur: Expedition 33 (a referência da luta por turnos)

Dos guias e da comunidade (números de jogadores e de quem faz mod, não oficiais):

- **Defesa em tempo real, sem aviso na tela.** No turno do inimigo não aparece anel nem seta: você lê o golpe pelo
  movimento e, muito, pelo **som** (um assobio, um grunhido, um "tum" antes do impacto).
- **Aparar:** apertar na hora do impacto, janela de uns **0,15 s** (9 quadros a 60 por s). Não vale desde o primeiro
  quadro: o "escudo" sobe um instante depois de apertar. Errar = leva o golpe inteiro. Cada aparada dá **1 PA**.
- **Aparar todos os golpes da sequência = contra-ataque** forte.
- **Esquivar:** mais folgada (uns 0,15 s de invulnerável depois de apertar, e dá para tentar de novo dentro do mesmo
  golpe), mas não dá PA. A esquiva perfeita tem o mesmo tempo da aparada.
- **Pular:** para golpes rasteiros/ondas. **Contra-ataque de gradiente:** golpe especial (a tela escurece), janela folgada.
- **Sequências:** inimigos do começo atacam 1 a 3 vezes seguidas; os do fim, 5 a 7, com **pegadinhas** (pausa, atraso).
- **Dificuldade fácil:** janelas 40% maiores e dano menor (o resto do jogo é igual).
- **Quebra:** golpes de muitos acertos enchem a barra; quebrado, o inimigo perde a vez.
- **Mira livre** (gasta PA) para acertar ponto fraco.

Fontes: [maxroll (guia de combate)](https://maxroll.gg/clair-obscur-expedition-33/guides/combat-guide),
[Siliconera (janelas +40% no fácil)](https://www.siliconera.com/clair-obscur-expedition-33-patch-adjusts-dodge-and-parry-timing/),
[Game Rant (aparar)](https://gamerant.com/clair-obscur-expedition-33-how-time-parries/),
[GameFAQs (tempo de aparar/esquivar)](https://gamefaqs.gamespot.com/boards/469495-clair-obscur-expedition-33/80976022).

O que já temos parecido: turno, d20 para acertar (D&D), aparar/esquivar com tempo (anel), aparar a sequência inteira =
contra-ataque (combo), quebra de postura. O que é diferente: a nossa defesa mostra o anel; a deles é só o golpe e o som.

## Projetos abertos em Godot (código MIT)

- **[Snaiel/Godot4ThirdPersonCombatPrototype](https://github.com/Snaiel/Godot4ThirdPersonCombatPrototype)** (combate
  do Sekiro): a aparada tem janela de 0,2 s; apertar de novo em menos de 0,4 s encolhe a janela (0,1 → 0,05 → nada).
  Quem acerta o tempo tem folga, quem martela o botão perde. Bloquear (segurar) segura o dano mas enche a instabilidade.
- **[GDQuest third-person controller](https://github.com/GDQuest/godot-4-3d-third-person-controller)** (código MIT, arte
  CC-BY-NC: a arte não serve): a câmera segue a altura do **chão** (não o quique do corpo) e, preso numa quina, o
  personagem é empurrado para fora da parede. O resto (braço de mola, aceleração, giro suave) já temos.

## Mixamo (animações)

Baixadas 15 de adaga, faca, espada de uma mão, guarda, bloqueio e esquiva, exportadas no "Tico_para_Mixamo" (o Tico que
o Gabriel subiu lá). **Ficam só no PC** (a licença não deixa publicar as animações soltas e o repositório é público):
`assets/kits/mixamo/fbx/` e `actors/tico_lirou/mixamo_tico.res` estão no `.gitignore`. Para refazer em outro PC: baixar
os mesmos .fbx do Mixamo para essa pasta e rodar `tools/art/importar_mixamo.gd` (duas vezes, com `--import` no meio) e
`tools/art/retarget_ual_tico.gd -- mixamo`.

Resultado no Tico: são de gente comprida com espada; com o braço curto, a barriga e a adaga de 42 cm a lâmina entrava no
corpo em quase todas. O `EncaixeCorpo` (tools/art/encaixe_corpo.gd) abre o braço e gira o antebraço quadro a quadro até a
lâmina sair: 7 de 15 ficaram limpas, e dessas as que ficam bonitas no Tico são o **corte para fora** e as duas
**estocadas de faca**. As guardas abaixam a cabeça grande ou põem a lâmina na frente da cara; os combos longos giram o
corpo todo e ainda cruzam a lâmina pelo corpo.
