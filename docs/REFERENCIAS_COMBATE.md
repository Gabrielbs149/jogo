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

O que já tínhamos parecido: turno, d20 para acertar (D&D), aparar/esquivar com tempo, aparar a sequência inteira =
contra-ataque (combo), quebra de postura. **Aplicado na D082:** a defesa sem anel (lendo o golpe: o inimigo recua no
preparo, clarão e assobio 0,3 s antes, a batida na hora), janelas um pouco maiores sem o anel, e o anel como opção em
Acessibilidade.

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

## Baldur's Gate 3 (as regras, lidas dos arquivos do jogo)

Extraídas com o LSLib (Norbyte, MIT) dos `.pak` do jogo do Gabriel, só para estudo, em `C:\Users\Gabriel\Tools\estudo\bg3`
(fora do repositório). O que veio para cá (D083), reescrito do nosso jeito:
- quem luta com duas armas ataca com a segunda como ação bônus, sem o modificador no dano (`Target_OffhandAttack`);
- Riposte: reação quando o inimigo erra um corpo a corpo a até 2 m (`Interrupt_Riposte`);
- terreno alto: +2 de mais de 2,3 m acima, -2 de baixo (`HighGroundThreshold`, `HighGroundAttackRollBonus`);
- empurrão: 1 a 6 m conforme a força (`ShoveDistanceMin/Max`); aqui ele também desequilibra o alvo.

## Expedition 33 (os arquivos)

O jogo não é criptografado; o FModel (versão de agosto/2026, com .NET 10 portátil) abre e lista os 155 mil arquivos,
mas as tabelas precisam de um mapa de campos (`.usmap`) que não é público: gerado com o UE4SS rodando o jogo uma vez
(o UE4SS foi tirado da pasta do jogo depois). As tabelas de luta foram lidas com um programinha em CUE4Parse (MIT),
só para estudo, em `C:\Users\Gabriel\Tools\estudo\e33` (fora do repositório). O que elas dizem:

- **Defesa:** apertar deixa o personagem imune por um tempo, e o golpe que chega dentro dele é aparado/esquivado.
  Normal e difícil: aparar **0,15 s**, esquivar **0,22 s**; fácil: 0,35 s e 0,5 s. (A comunidade falava em "janela
  de 0,15 s": é isso, mas contada do aperto para a frente, não em volta do impacto.)
- **Dificuldade:** no fácil a vida dos inimigos é a mesma e o ataque é **×0,25**; no difícil, ataque **×2** e vida
  **×1,25**. Chefe tem ~13× a vida de um inimigo comum do mesmo nível; elite ~6×.
- **Congelar no golpe (hitstop):** muito leve 0,04 s, leve 0,07, médio 0,11, pesado 0,14, muito pesado 0,2 (o tempo
  vai a 0,001 por esse instante).
- **Perfeição do Verso:** +1 por habilidade, defender, esquivar, aparar, contra-atacar, tiro de mira livre, ataque
  básico e QTE; levar golpe tira. Níveis D, C, B, A, S aos 0, 3, 8, 15 e 30 pontos (máximo 99).
- **Gradiente:** cada PA gasto enche 5% da barra; até 3 cargas.

**Aplicado na D084:** a defesa contada do aperto, a dificuldade, o congelar no golpe e o Ritmo do Tico (a Perfeição).
**Aplicado na D085:** a sequência de golpes do inimigo (com a pegadinha), a resposta na tela a cada golpe, a letra do
Ritmo grande e o contra-ataque em cena.
