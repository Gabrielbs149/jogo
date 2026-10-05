# Guia de estilo: Journey nas dunas

O jogo é **3D com câmera de cima e combate por turnos** (estilo Baldur's Gate 3) com o **visual do Journey**: deserto dourado ao entardecer, figuras de manto com cachecol que voa, olhos que brilham, ruínas com runas acesas, poeira de areia no vento, uma montanha com um feixe de luz no horizonte. História em `docs/HISTORIA.md`.

## Luz e cor
- **Hora dourada sempre.** Sol baixo (≈17°), vindo de trás à direita da câmera: sombras longas para a frente-esquerda. Céu de azul profundo no alto a laranja-rosado no horizonte.
- **Areia:** laranja profundo nas encostas em sombra, dourado claro no topo das dunas, marcas de vento e brilho de grãos que muda com a câmera (`assets/shaders/sand.gdshader`).
- **Tudo num lugar só:** `assets/environment/journey_sky.tres` (céu, névoa leve, brilho, contraste). Mexa lá para mudar o clima do jogo inteiro.
- **Cor de destaque é luz,** não tinta: runas, olhos, anéis de seleção e magia usam emissão (brilho), em dourado/creme. Vermelho e laranja quente para ataque inimigo.

## Personagens
- **Silhueta primeiro.** Todo herói é um manto (cone) com capuz, rosto escuro, dois olhos brilhando e cachecol. A personalidade vem da **cor do manto + um acessório que se lê de cima**:
  - Tico-Lirou: pequeno (0,72), verde-folha, brotos no capuz, focinho e rabo de kobold.
  - Naumfode: ocre, óculos de latão, mochila com engrenagem, burrinho mecânico do lado.
  - Chumasso: enorme (1,45), azul, rosto cinza de golias, martelo de ouro e ombreiras.
  - José Maria: verde-floresta, arco, aljava e perna de pau.
  - Bahamut: dragão de tecido creme e dourado que flutua e ondula.
- Modelos base: `actors/shared/robed_figure.tscn` (cores e proporções no Inspector) e `actors/bahamut/`. Inimigos de **pedra** com olho de brasa: `actors/enemies/`.
- Movimento: deslizar suave na areia (0,24 s por casa); nada de pulo ou corrida.

## Interface
- Painéis marrom-escuros translúcidos, cantos arredondados, linha fina dourada. Texto creme.
- Títulos e nomes: **Cinzel** (`TitleLabel` no tema). Texto corrido: **Lato**. Licença OFL, em `assets/fonts/`.
- Tema único: `ui/theme/journey_theme.tres`.

## Câmera e combate
- Câmera tática a −50°, distância 15,5 (roda do mouse 7–34), Q/E giram, WASD movem. Segue quem está jogando.
- Grade invisível de casas de 1,6 m; aparece só quando se escolhe andar ou mirar (casas claras = andar; laranja = alcance; vermelho = área).

## Arte provisória e como trocar
- Dunas: `tools/art/generate_dunes.js` gera `levels/dunes_arena/art/dunes.obj`. Pode trocar por um terreno do Blender com o mesmo nome (manter o centro plano para a grade).
- Personagens e ruínas são primitivas do Godot (cones, esferas, caixas). Dá para trocar cada `Model` por um `.glb` do Blender mantendo a origem nos pés e a frente para −Z.
