# Guia de estilo: Plano do Fogo

O jogo é **3D com câmera de cima, no esquema do Baldur's Gate 3**: o grupo **explora em tempo real** (clique no chão para andar, clique nas coisas para examinar) e o jogo **só entra em turnos quando começa uma luta**. A ambientação é o **Plano do Fogo** da campanha (`docs/HISTORIA.md`): deserto ocre ao entardecer, rochas de obsidiana, brasas no ar, ruínas com runas e braseiros acesos.

> Referências usadas *com moderação*: a luz quente e o vazio contemplativo do Journey. Nada de copiar as marcas registradas dele (figura de manto sem rosto com olhos brilhando, cachecol voando, montanha com feixe de luz). Decisão D014.

## Luz e cor
- **Entardecer quente, mas legível.** Céu roxo-acinzentado no alto e laranja no horizonte. Sol baixo vindo de trás à direita, com sombras longas.
- **Saturação contida.** Areia ocre-marrom, não vermelho puro. Se a tela ficar "de uma cor só", baixe a saturação em `assets/environment/fire_sky.tres` antes de mexer no resto.
- **Brilho só onde tem fogo ou magia:** fogueira, braseiros, runas, olhos de inimigos de pedra, efeitos de habilidade. Roupa e equipamento não brilham.
- Arquivos: céu/névoa/contraste em `assets/environment/fire_sky.tres`; areia em `assets/shaders/sand.gdshader`.

## Personagens
- **Cada herói tem modelo próprio, feito no Blender**, com proporção de desenho (cabeça grande, olhos expressivos), cores sólidas e foscas, e silhueta que se lê de cima.
  - **Tico-Lirou:** feito (`actors/tico_lirou/`), a partir da ilustração do Gabriel. Kobold verde de pintas, olho azul, chifres, crista rosa, capuz verde com ponta de folha, manto aberto, barriga cor de pêssego, perneiras, mochila com saco de dormir e cogumelo rosa.
  - **Tika Muro:** feita (`actors/tika_muro/`). Mesma base, roxo, olhos rosa, cogumelo grande e espadas nas costas.
  - Naumfode, Chumasso, José Maria e Bahamut ainda usam os bonecos provisórios (manto com acessórios, dragão de tecido) até ganharem modelo próprio.
- Fluxo do Blender: herói com desenho de referência → forma gerada pelo Hunyuan3D a partir do desenho e cor projetada do desenho (`tools/blender/gerado/`, ver D016). Sem desenho → `tools/blender/kobolds.py` por primitivas. Para ajustar à mão, abra `art_src/<nome>.blend`, edite e exporte para o mesmo `.glb` (só o objeto do herói selecionado). Convenção: **pés na origem, frente para +Y no Blender** (vira −Z no Godot).

## Cenário
- Ruínas de pedra clara com runas acesas e braseiros; rochas de obsidiana brilhante; brasas subindo no ar; acampamento com fogueira.
- Tudo que bloqueia caminho tem colisão na camada **props** (3) e fica num nó do grupo `nav_source`, para o mapa de navegação contornar.

## Interface
- Painéis marrom-escuros translúcidos, cantos arredondados, linha fina dourada. Texto creme.
- Títulos e nomes em **Cinzel** (`TitleLabel` no tema); texto corrido em **Lato**. Licença OFL, em `assets/fonts/`.
- **Exploração:** grupo à esquerda (F1–F5), painel de história embaixo, dicas no alto. **Combate:** ordem dos turnos no alto, habilidades embaixo, registro à direita.

## Câmera
- Câmera tática a −50°, distância 13 (roda do mouse de 7 a 34), Q/E giram, WASD movem. Na exploração segue o líder; no combate, quem está jogando.
- Na luta, a grade aparece no chão: casas claras para andar, laranja para o alcance, vermelho para a área.
