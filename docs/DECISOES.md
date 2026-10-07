# Decisões (histórico D001–D029)

> **Arquivo fechado.** O log de decisões agora é [`docs/gdd/decisoes.md`](gdd/decisoes.md) (D031), que resume estas
> entradas e recebe as novas. Este arquivo fica como detalhe histórico.

Registro curto do que foi decidido e por quê, para os dois humanos e os dois Claudes. Decisão nova vai no topo. Mudou de ideia? Não apague: crie uma nova entrada que "substitui a Dxxx".

Formato: **Dxxx — título** · data · quem · decisão · porquê.

---

**D029: Cena de abertura do Tico com o rato** · 2026-10-07 · Gabriel ("muda a cena inicial pro Tico oferecendo na real um rato pra Tika Muro, elabora a cena")
- Roteiro novo em `story/tico_cena1.tres` (falas em HISTORIA.md, marcadas como proposta), com a piada do "bumbum" da história do Tico e o "Idiota." da versão do pão.
- Rato assado no espeto modelado por script (`tools/blender/gerado/modelar_rato.py`): `actors/props/rato/rato_espeto.glb` (com o nó `Traseiro` separado) e `rato_traseiro.glb` (o pedaço que vai para a Tika).
- Cenário (`tools/art/montar_cena_tico.gd`): fogueirinha entre pedras com fogo pequeno, marca `EspetoNoFogo`, câmera nova `Plano5` (close no fogo). O pão saiu da cena (as peças continuam no catálogo).

**D028: Esqueleto humanoide + animações prontas por retarget (Tico primeiro)** · 2026-10-07 · Gabriel ("as animações tão horríveis... ele segurando aquele suposto pão ta uma nojeira") · substitui a D020
- **Por que:** a D020 fazia esqueleto e cada animação à mão em código (poses chutadas). Agora o personagem ganha um esqueleto humanoide com os nomes padrão do Godot e as **76 animações do KayKit** (feitas por animador) tocam nele pelo *retarget* do Godot (BoneMap + "Rename Bones" + "Fix Silhouette" só nos braços).
- **Pesos:** o cálculo automático do Blender falha na malha do TRELLIS (buracos). `tools/blender/gerado/rig_tico_humanoide.py` calcula: tronco e rabo por "o ponto da pele enxerga o osso" (raio num corpo fechado por voxel), membros por região + distância, suavização pelas arestas, até 4 ossos por vértice.
- **Arquivos:** `actors/tico_lirou/tico_lirou_humanoide.glb` (+ `mapa_ossos_tico.tres`), `assets/kits/kaykit/animacoes/humanoide.res` (biblioteca extraída por `tools/art/extrair_animacoes.gd`), mapas criados por `tools/art/criar_mapas_de_ossos.gd`. O Animator do Tico usa Idle, Walking_A, Running_A, Dualwield_Melee_Attack_Slice/Stab, Spellcast_Shoot, Use_Item, Dodge_Forward, Hit_A, Death_A. A cena do pão usa Sit_Floor_Idle; `[na mão:]` prende na palma do `RightHand`; pão remodelado (filão com cortes).
- **Guia para fazer à mão:** `docs/GUIA_ESQUELETO.md`.
- **Falta:** um gesto de "comer sentado" (não existe no pacote: precisaria ser animado no Blender); Tika e os outros heróis ainda sem esqueleto humanoide.

**D027: Arandu replanejada como cidade de verdade** · 2026-10-07 · Gabriel ("faça o seu melhor trabalho em Arandu, pense na arquitetura da cidade"; "só ouço risada dessa cidade")
- **Por que estava feia:** comparando com o jogo do Yoda (Unity, mesmo modelo de IA), a diferença não era o motor nem os modelos, e sim a montagem: chão de uma cor só, praça em disco duro, casas soltas no vazio, pouca vegetação e cidade sem gente.
- **Planta:** muralha quadrada de 70 m com torres nos cantos e duas torres guardando o arco do portão norte (face de pedra para fora). Duas ruas de pedra em cruz (portão → praça → sul; oeste ↔ leste) e praça redonda com o poço, quatro barracas, bancos e árvores. Casas **coladas, de frente para a rua**, misturando estreitas de dois andares, térreas, compridas e sobrados; esquinas da praça com prédios maiores virados para o centro (Taverna, Casa do Conselho, Casa do Mercador, Capela com campanário). Ferraria com quintal, quintais com árvores e cercas, estrada de terra com cerca do portão para fora e floresta em volta.
- **Beco do Tico:** um beco de 3 m saindo da rua do portão, fechado no fundo, com o papelão, o caneco, caixote e barril. A cena de abertura foi remontada nele (`tools/art/montar_cena_tico.gd`, câmeras sempre do lado aberto do beco).
- **Chão pintado** (`assets/shaders/chao_pintado.gdshader`): grama em tons variados, terra e calçada misturadas por uma máscara (`levels/arandu/art/chao_mascara.png`, vermelho = terra, verde = calçada) com bordas quebradas por ruído.
- **Grama e flores:** ~9.400 tufos em `MultiMesh` por pedaços de 30 m que somem a 75 m (`levels/arandu/art/grama/`). Precisa montar COM janela (sem janela o Godot não guarda as posições).
- **Gente:** além dos 4 moradores com fala, figurantes de fundo (guarda no portão, compradores na feira, gente sentada nos bancos, conversa na porta da taverna, ferreiro, crianças, leitora) no grupo `Crowd`.
- **Luz e câmera:** sol de tarde mais macio, neblina com perspectiva aérea, cor um pouco mais saturada; câmera da exploração um pouco mais alta e afastada (5,8 m).
- **Novas peças:** casa estreita (de reboco e de pedra), casa comprida, sobrado comprido, torre. Editor de mapas: grama não é clicável.
- **Como refazer:** `godot --path . -s tools/art/montar_arandu.gd` (com janela) e depois `godot --headless --path . -s tools/art/montar_cena_tico.gd`. Rodar de novo APAGA mudanças feitas à mão em prédios/decoração — depois de montada, Arandu se ajusta no editor de mapas.

**D026: Visual com kits prontos: Quaternius (cenário) + KayKit (moradores)** · 2026-10-06 · Gabriel ("você não consegue fazer texturas realistas... procure modelos padrões já existentes e simples de montar") · substitui a D024
- **Como foi escolhido:** montei a MESMA cena (duas casas, feira, barris, árvores, Tico e Tika) com Quaternius, KayKit e Kenney, mesma luz e céu, e o Gabriel escolheu vendo as fotos dentro do jogo: **Quaternius + KayKit**. Os do Poly Haven (D024) saíram do projeto (ficam só no histórico do Git).
- **Kits (CC0, versões grátis):** Quaternius Medieval Village, Fantasy Props e Stylized Nature MegaKit + KayKit Adventurers, em `assets/kits/` (texturas de 4K reduzidas para 2K; .png/.bin no LFS). Instalação: `tools/art/instalar_kits.py`. Lista em `assets/CREDITOS.md`.
- **Casas:** montadas com as peças modulares de 2 m (paredes de reboco, pedra ou enxaimel, porta, janelas, quinas, telhado de telha inteiro, empena e chaminé) por `tools/art/gerar_pecas.py`. Casa 6 x 6, sobrado 8 x 8 de dois andares.
- **Catálogo do editor** (66 peças em `world/props/`, mesmos nomes de antes, então as fases trocaram sozinhas) + **todas as peças soltas dos kits** (vila, objetos, natureza) com **busca**. Grade ajustável (as peças de casa encaixam em 2 m) e, com a grade ligada, Q/E giram 90°.
- **Colisão automática:** peças no grupo `colisao_auto` ganham colisão do formato da malha quando a fase abre (`Level._auto_collision`), sem caixas feitas à mão; peça solta de kit colocada pelo editor entra no grupo se for grande (plantas e miudezas, não).
- **Materiais** (`assets/materials/`, mesmos nomes): agora com as texturas do Quaternius (reboco, telha, tijolo, pedra, madeira) e chão de cor + manchas suaves (`tools/art/gerar_materiais.py`).
- **Moradores:** `Figurante` (`world/figurante.gd`): personagem do KayKit (Knight, Barbarian, Mage, Rogue, Rogue_Hooded) parado numa animação em laço (parado, sentado no chão, comemorando...), armas escondidas menos a escolhida. Escolhe-se no Inspector ou no painel do editor de mapas. Em Arandu: padeira (Mage), vendedor (Barbarian com caneco), guarda (Knight com espada), criança (Rogue comemorando).
- **Fases:** muralha de Arandu feita de pedaços de muro do kit, portão em arco com estandartes; Ethera com árvores secas e tortas, rochas estilizadas e a fogueira do acampamento feita de pedras do kit.
- **Inimigos:** continuam os modelos atuais (escaravelhos de cinza, sentinelas e o guardião são da história; os personagens do KayKit são humanos). Para monstros no mesmo estilo existe o KayKit Skeletons (CC0) — falta decidir.

**D025: Cenas por roteiro (cutscenes)** · 2026-10-06 · Gabriel mandou o prólogo da campanha, a história do Tico e a 1ª cena dele
- **Formato:** um `Roteiro` (`story/roteiro.gd`, arquivo `.tres` com o texto editável no Inspector) é escrito do jeito que se escreve a cena — `Nome: "fala"` (ou `Nome:` e a fala entre aspas na linha de baixo), `> narração` no meio da tela — mais comandos entre colchetes: `[tela preta]`, `[abre]`, `[corta: Plano1]`, `[câmera: Plano2 3]`, `[som: cidade | legenda]`, `[pausa 1.5]`, `[mostra:]`/`[esconde:]`, `[anima: Tico sit]`/`[solta:]`, `[coloca: Tico Marca]`, `[olha:]`, `[na mão: Pao]`, `[legenda:]`, `[fim]`. Qualquer outra linha é direção de cena e não aparece — dá para colar o roteiro como ele foi escrito e só acrescentar os comandos. A lista completa está no topo de `story/roteiro.gd`.
- **Quem toca:** `CutscenePlayer` (`story/cutscene_player.tscn`): faixas de cinema, letra a letra, Espaço/F/clique passam, Esc pula. `Level.cena_de_abertura` toca na primeira vez na fase (no lugar das frases de abertura); `Game.PROLOGUE` (`story/prologo.tres`) toca uma vez em todo jogo novo. Câmeras e marcas da cena ficam na própria fase (Camera3D/Marker3D), editáveis no Godot ou no editor de mapas.
- **Tico:** animações novas `sit` e `sit_eat` (sentado no papelão, comendo) em `animar_tico.py`; o `CombatantAnimator` ganhou `hold()`/`release()`. Peças novas: marquise, pão (com a metade) e meio pão.
- **Som:** o projeto ainda não tem arquivos de som. `[som: cidade]` procura `assets/sfx/cidade.ogg`; sem ele, mostra a legenda (gente conversando, carroça, cachorro).
- **História:** a Tika saiu do acampamento de Ethera (pela história, ela foi levada).

**D024: Visual realista com assets do Poly Haven (CC0)** · 2026-10-06 · Gabriel · substituída pela D026 ("esses gráficos são horríveis"; escolheu pacotes grátis + estilo mais realista)
- **Fonte:** Poly Haven (CC0, sem royalty, sem crédito obrigatório; lista em `assets/CREDITOS.md`). Pacotes low-poly (Kenney, Quaternius, KayKit) ficaram de fora por não serem realistas. As árvores "normais" do Poly Haven têm milhões de polígonos: ficaram de fora. Por isso a região virou **árida**: Arandu é uma cidade de reboco e telha de barro, e a vegetação é de deserto (árvore-aljava, suculentas, arbustos secos).
- **Modelos** (`assets/models/*.glb`): baixados em 1k, passados por `tools/blender/gerado/preparar_polyhaven.py` (junta as partes, simplifica até ~14–40 mil triângulos, base no chão, medidas em `medidas.json`).
- **Texturas** (`assets/textures/`, 2k, importadas com compressão VRAM + mipmaps; normal maps marcadas) e **materiais** (`assets/materials/*.tres`, ORMMaterial3D com projeção triplanar no mundo: a textura não estica, seja qual for o tamanho da parede). Reboco branco e de barro, telha, calçada, caminho, cascalho, tábuas, muralha, areia (e areia_ethera, mais avermelhada), arenito, pedra, palha.
- **Céus HDRI** (`assets/skies/`): Arandu de dia com nuvens; `fire_sky.tres` (Ethera, arena e tela de escolha) com entardecer. Iluminação ambiente vem do céu; SSAO, neblina com perspectiva aérea.
- **Fogo** de partículas (`assets/vfx/fogo.tscn`: chamas, faíscas, fumaça e luz tremendo) na fogueira, no acampamento e nos braseiros.
- **Peças do catálogo** refeitas e ampliadas (`world/props/`, geradas por `tools/art/gerar_pecas.py`): casas e sobrados (branco e barro) com vigas, soco de pedra, janelas com venezianas; muro, portão, barraca com mercadorias, poço, pilar; árvores, tronco, toco, suculenta, arbustos, rochas, penhasco, pedras; caixotes, barris, balde, cesto, jarro, vaso, bancos, baú, lanterna.
- **Fases:** Arandu e Ethera mantêm o layout, mas casas, barracas, poço, árvores e rochas viraram essas peças. Ganharam decoração (props nas portas, lanternas) e vegetação/pedras em volta. Tudo editável no editor de mapas.
- **Git:** `.jpg` de `assets/textures/` vão para o LFS (`.gitattributes`). Atenção ao limite do LFS grátis do GitHub (1 GB de espaço e de banda por mês).
- **Falta:** os personagens que ainda são formas simples (moradores de manto, inimigos, altar) e as camas do acampamento.

**D023: Editor de mapas dentro do jogo** · 2026-10-06 · Gabriel pediu "câmera lá em cima e liberar todo tipo de edição"
- **Abrir:** botão "Editor de mapas" na tela inicial ou **F2** dentro de qualquer fase (ação `map_editor`). Cena `editor/map_editor.tscn`.
- **Como funciona:** a fase abre parada (`Level.editing = true`: ninguém nasce, nada roda, inimigos e câmera não mexem em nada no `_ready`) e a câmera fica no alto (`EditorCamera`: WASD anda, roda aproxima, botão direito gira, meio arrasta, T = bem de cima).
- **Edição:** clique escolhe, arrastar move (segue o chão), Shift+clique junta, arrastar no vazio seleciona área, Alt+clique pega a parte de dentro. Q/E gira, PgUp/PgDn altura, +/- tamanho, R zera, Del apaga, Ctrl+D duplica, Ctrl+Z/Y desfaz/refaz, G grade de 0,5 m. Aba **Cena** = a árvore inteira da fase (o mesmo que o Godot mostra).
- **Painel da direita:** nome, posição/giro/tamanho, todos os campos `@export` da peça e do que tem dentro (falas, para onde a saída leva, herói que espera, textos da luta, cores do manto, vida dos inimigos...), cores das partes (copia a tinta na 1ª mudança para não pintar as outras), luz. "Fase e céu" = textos da fase, sol, céu e neblina.
- **Catálogo** (`world/props/*.tscn`, cenas comuns — dá para abrir e mudar no Godot; peça nova na pasta aparece sozinha em "Outras"): casa, casa grande, muro, barraca, poço, pilar, árvore, arbusto, rochas, caixote, barril, luz, morador (fala), inscrição, fogueira (descanso), saída (outra fase), herói esperando e grupos de inimigos. Cada peça entra no grupo certo da fase (Buildings, Trees, Encounters...) e os grupos de chão entram no mapa de navegação.
- **Salvar** grava a própria `.tscn` da fase (`PackedScene.pack`) — o arquivo que o Godot abre, então editor do jogo e editor do Godot convivem. Mudança dentro de uma peça vira "Filhos editáveis". Só funciona rodando pelo Godot (o jogo exportado não grava em `res://`). **Testar** joga a fase como está sem salvar (`user://editor_rascunho.tscn`); F2 volta com o que não foi salvo. **Nova fase** copia Arandu deixando só o chão, o sol e o começo.
- Junto: os muros de Arandu viraram uma peça com a colisão dentro (antes malha e colisão eram irmãos); o id de um grupo de inimigos agora é `Encounter.id()` (nome do nó se vazio) para cópias não sumirem juntas; Arandu e Ethera foram regravadas pelo próprio Godot (só formato).
- Porquê: montar fase pelo jogo, sem saber Godot, e ver na hora. Continua valendo o "monta no editor" — o resultado é a mesma cena.

**D022: Luta no estilo Clair Obscur: por turnos, só você, numa arena, com QTE** · 2026-10-06 · Gabriel · substitui o combate em tempo real da D018 (a exploração em 3ª pessoa continua)
- **Mapa:** inimigos ficam parados em grupos (`Encounter`). Encostar = luta. Acertar um antes com o botão esquerdo = **primeiro golpe** (você joga primeiro e ganha +1 PA). Q/E/R não funcionam no mapa. Vencido, o grupo some (`Game.defeated`); você volta ao mesmo lugar com a vida que sobrou. Perdeu: volta ao começo da fase com a vida cheia. Fogueira enche a vida.
- **Arena** (`levels/arenas/`, script `battle/battle_arena.gd`): **só o seu personagem** luta (decisão do Gabriel: o jogo é focado em você; quem você recruta fica na história, fora da luta). Ordem por iniciativa (d20 + DES).
- **Seu turno:** **1** = ataque (ganha 1 Ponto de Ação), **Q/E/R** = habilidades (custam PA, `ap_cost` no `.tres`). **A/D** trocam o alvo. Durante o golpe um anel fecha: **Espaço** no tempo certo = **vantagem** no d20 (perfeito, ±0,08 s); quase = normal (±0,2 s); errou = **desvantagem**. Em habilidade de salvamento, o perfeito dá desvantagem no salvamento do inimigo.
- **Turno do inimigo:** pausa variável, o golpe vem e o anel fecha em você: **Espaço esquiva** (±0,15 s: o golpe erra, área não pega) ou **F apara** (±0,08 s: sem dano, você contra-ataca com vantagem e ganha 1 PA). Perdeu o tempo: o inimigo rola o d20 contra a sua CA normalmente.
- **D&D continua:** d20 contra CA, vantagem/desvantagem, salvamentos, ataque furtivo (na arena: com vantagem, ou seja, com o QTE perfeito), Bênção, Marca etc. Efeitos duram **turnos** (`status_turns`). Inimigos voltaram à vida da ficha (16/20/85); o herói fica com 3× (66 no Tico).
- **Simulador:** `tools/simulate_arena.gd` joga cada herói contra cada grupo com três perfis de jogador (bom/médio/fraco no QTE). Herói com 2× a vida da ficha (Tico 44). Tico, 4 lutas por caso, vida cheia no começo: 2 escaravelhos e sentinela = vence sempre (o fraco termina com ~76% da vida); Último Guardião = bom 4/4 (65%), médio 3/4 (33%), fraco 1/4. A vida não enche entre lutas (só na fogueira), então o desgaste soma até o chefe.
- Porquê: o Gabriel quer a luta do Clair Obscur: turnos com reação em tempo real, focada no personagem dele, com quicktime.

**D021: Mixamo para o Tico — testado e descartado** · 2026-10-06 · Gabriel
O Tico foi para o Mixamo com os braços caídos e uma perna à frente: nas animações o braço entrava no corpo e o pé girava como pedal de bicicleta. Uma segunda tentativa em pose T falhou na montagem automática. O Gabriel preferiu voltar às animações por script da D020. Lição para a próxima vez: Mixamo só com o modelo em pose T, pernas retas e sem rabo/manto grande.

**D020: Animação dos heróis: esqueleto e animações por script no Blender + Animator no Godot** · 2026-10-05 · Gabriel pediu as animações do Tico · substituída pela D028
- A malha do TRELLIS vem sem esqueleto. `tools/blender/gerado/animar_tico.py` monta um esqueleto de kobold (20 ossos: tronco, cabeça, braços, pernas, 3 do rabo), pesa cada vértice pela distância aos ossos com regras por região (mochila não balança com a cabeça, manto da perna vai com a perna) e cria 10 animações: `idle`, `walk`, `run`, `attack` (Adaga), `dash_strike` (Bote das sombras), `cast` (Espinhos), `hide` (Camuflagem), `dodge` (Ação ardilosa), `hit`, `down`.
- No Godot, `CombatantAnimator` (nó `Animator` do herói) toca a certa sozinho. Nomes no Inspector, então outro herói usa o mesmo nó com as animações dele.
- Limite: animação feita por script, sem animador de verdade; braço muito erguido estica a manga do manto. Para algo profissional: Mixamo (precisa de conta) ou animar à mão no Blender a partir de `art_src/tico_lirou_rig.blend`.

**D019: Cada herói começa a história num lugar diferente; Tico-Lirou começa em Arandu** · 2026-10-05 · Gabriel
- O começo do jogo é calmo e pequeno: nada de fase cheia logo na primeira tela. O lugar de início de cada herói fica em `Game.START_LEVELS` (`systems/game/game.gd`).
- **Tico-Lirou → Arandu** (`levels/arandu/`), a cidade natal dele, onde ele era mendigo: ele acorda no beco onde dorme, com uma praça, poço, mercado, algumas casas, quatro moradores para conversar (F) e o portão que leva para a estrada (vai para Ethera).
- Os outros quatro ainda começam em Ethera até o Gabriel contar o começo de cada um.
- O script da fase virou um só para todas: `world/level.gd` (classe `Level`). Saída para outra fase = `Interactable` com ação TRAVEL e `target_scene`.
- Porquê: o Gabriel quer conhecer o lugar de cada personagem antes da aventura, começando simples.

**D018: Ação em 3ª pessoa com regras de D&D 5.5; você escolhe um herói e recruta os outros no caminho** · 2026-10-05 · Gabriel · substitui D012 e D014 (o combate por turnos sai)
- **Começo:** tela inicial → escolha de quem seguir (os 5 da história) → a fase começa **só com o escolhido**. Os outros quatro esperam pela fase (nós `HeroSpot`); chegando perto, **F conversa** e você decide se chama para o grupo. Quem entra vira aliado controlado pela IA e segue você. A lista de quem entrou fica no autoload `Game`.
- **Controle:** câmera atrás do ombro (mouse gira, mira no centro da tela), **WASD** anda, **Shift** corre, **botão esquerdo** ataca (segure), **Q / E / R** habilidades, **Espaço** esquiva, **F** interage, **Esc** pausa. Q/E/R no lugar do Q/W/E/R do LoL porque o W já anda.
- **Regras (D&D 5.5 adaptado ao tempo real):** ataque = d20 + bônus contra a CA (20 crítico com dados em dobro, 1 erra); **vantagem/desvantagem** com 2d20; **salvamentos** (DES/CON/SAB) contra a CD de quem lançou, metade do dano se passar; **ataque furtivo**, **Bênção** (+1d4), **Marca do caçador**, **Amedrontado**, **Invisível** (Camuflagem), **Esquivar** (desvantagem contra você). O que no D&D é "por turno" ou "por descanso" vira **recarga em segundos**. Cada rolagem aparece no registro da tela.
- **Cair:** herói a 0 PV fica caído; cura levanta. Sem inimigo brigando por 4 s, quem caiu se levanta com 1 PV. Todo mundo caído = derrota. **Fogueira (F) = descanso curto**: vida e recargas cheias.
- **Escala do tempo real:** PV de heróis e inimigos = **3× a ficha** (Tico 22 → 66) e recargas mais longas (ataque básico 1,2–1,9 s), senão a luta acaba em 5 s. A cura do Naumfode subiu junto (4d8+6). Os dados de dano e as CAs são os da ficha. Inimigos percebem você a 9–12 m e chamam só quem está a 5 m, para dar para puxar um de cada vez.
- **Simulação** (`tools/simulate_ethera.gd`, IA no lugar de quem joga, partindo direto para cima dos inimigos): com o grupo inteiro vence em ~20–30 s de jogo; sozinho contra os 7 de uma vez cai em ~30–60 s. Ou seja: Ethera pede grupo (ou puxar um inimigo por vez).
- **Habilidades** em `data/abilities/*.tres` (1ª = botão esquerdo, 2ª = Q, 3ª = E, 4ª = R). Nomes e efeitos das habilidades são *(proposta)*: ajustem à ficha real de cada um na mesa.
- Porquê: o Gabriel quer jogar com o próprio personagem, em 3ª pessoa, com habilidades "tipo LoL" mas com cara de D&D, e montar o grupo na história em vez de ganhar todo mundo de cara.

**D017: Heróis gerados pelo TRELLIS.2 (forma + textura) a partir do desenho** · 2026-10-05 · Gabriel · substitui o método de D016
O TRELLIS.2 (Microsoft, MIT, Space `microsoft/TRELLIS.2` no Hugging Face) gera o modelo já pintado de todos os lados; a pintura projetada de D016 deixava o lado escondido manchado. Passos: `tools/blender/gerado/gerar_trellis2.py` (precisa de login no Hugging Face no PC: conta grátis tem mais cota de GPU que anônimo) → `limpar_trellis.py` (tira o chão e as tiras que a IA inventa, junta vértices, casa as cores com o desenho, frente +Y, altura, 30 mil faces). O bruto fica em `art_src/<nome>_trellis_bruto.glb`.
Porquê: fiel ao desenho por todos os ângulos, grátis e com licença aberta.

**D016: Heróis com arte de referência: forma gerada por IA + pintura projetada do desenho** · 2026-10-05 · Gabriel · ajusta D015
O Tico-Lirou de primitivas ficou "muito feio" perto do desenho. Agora: a forma 3D sai do desenho pelo Hunyuan3D 2.1 (Space oficial da Tencent no Hugging Face, grátis, Gabriel autorizou mandar a imagem) e a cor é projetada do próprio desenho no Blender, espelhada para o lado que o desenho não mostra e assada numa textura 2048 (`tools/blender/gerado/`). Limite conhecido: o lado oposto ao desenho fica com manchas; textura completa por IA precisa de Hugging Face PRO ou de outro gerador (Tripo/Meshy, conta do Gabriel). `kobolds.py` continua só para a Tika Muro.
Porquê: modelar por primitivas não chega perto do traço do desenho; a forma gerada já traz focinho, dentes, capuz, túnica e mochila.

**D015: Modelos dos heróis no Blender, por script** · 2026-10-05 · Gabriel
`tools/blender/kobolds.py` monta Tico-Lirou e Tika Muro a partir da ilustração do Gabriel e exporta `.glb` (+ `.blend` em `art_src/`). O MCP do Blender (`mcp-for-blender`, telemetria desligada) está no `.mcp.json` para modelar interativamente com o Blender aberto. Os outros heróis seguem o mesmo caminho quando tiverem referência.

**D014: Exploração em tempo real + combate por turnos só na luta (Baldur's Gate 3), e menos Journey** · substituída pela D018 · 2026-10-05 · Gabriel · ajusta D012
O grupo anda livre (clique no chão; o líder vai na frente e os outros em formação, com o mapa de navegação do Godot). Ao chegar perto de um `Encounter`, a grade aparece e começa o combate por turnos; vencendo, volta a exploração e quem caiu levanta com 1 de vida. Tiramos as marcas do Journey (figura sem rosto de olhos brilhando, cachecol voando, montanha com feixe). Ambientação: Plano do Fogo (`docs/ESTILO.md`). Equilíbrio com o novo começo: IA dos heróis vence ~53% em ~10 rodadas.

**D013: História = a campanha "A Noite Sem Nome" do grupo** · 2026-10-05 · Gabriel
O jogo adapta a temporada do Plano do Fogo: cinco heróis que perderam as sombras, a caçada aos Astros (um por capítulo), os três caminhos do fim e o selo de Ethera como capítulo de abertura. Caiaque, Umu e Juca têm destaque (acampamento entre batalhas, proposto). Tudo em `docs/HISTORIA.md`. Dados pessoais da conversa original não entram no repo.

**D012: 3D tático por turnos com visual do Journey** · substituída pela D018 · 2026-10-05 · Gabriel · substitui D010 e D011
Câmera de cima, combate por turnos estilo Baldur's Gate 3: iniciativa (d20 + bônus), em cada turno andar + 1 ação, ataque rola d20 + bônus contra a CA (20 = crítico, 1 = erro), área não rola. Grade invisível de 1,6 m em 8 direções, obstáculos bloqueiam caminho e linha de visão, quem voa passa por cima. Heróis: Tico-Lirou, Naumfode, Chumasso, José Maria e Bahamut (classes em `docs/HISTORIA.md`). Visual Journey (`docs/ESTILO.md`). Renderer Forward+.
Equilíbrio medido com `tools/simulate_battles.gd`: com a IA jogando pelos heróis, eles vencem ~65% em ~8 rodadas. Uma pessoa jogando bem vence mais vezes, mas tem que pensar.
O 2D anterior fica no histórico (commit 947f201).

**D011: Câmera fotográfica é a mecânica central** · substituída pela D012 · 2026-10-04 · Gabriel
Cada foto gasta filme (12 por rolo), dá um flash e mostra a cena em negativo por ~1 s, revelando os `Revealable`. A foto vai para o álbum (Tab) com a legenda do que apareceu nela, e o álbum é onde a história se monta. Controles: A/D ou setas andam, E interage, F fotografa, Tab abre o álbum (controle: analógico/direcional, A, RB ou X, Back).

**D010: 2D lateral, pixel art preto e branco "Negativo + Névoa"** · 2026-10-04 · Gabriel · substitui D007 e D008 · substituída pela D012
2D visto de lado, 320×180 ampliado em inteiro, paleta de 6 tons (Breu → Osso), pontilhado no lugar de degradê, suspense sinistro. Exteriores brancos de névoa ("escuro = perto"); interiores no breu, só contornos. Tudo garantido pelo pós-processo `systems/screen/screen.gdshader`. Referências: proposta "Três caminhos no escuro" (Caminho 3 + névoa do 2) e a prancha de estilo do Gabriel (traço e caixa de diálogo com retrato). Tema da história ainda em aberto (o folclore da prancha era só exemplo de estilo). Guia completo: `docs/ESTILO.md`. Renderer: Compatibility. Fonte: Tiny5 (OFL).
Porquê: visual, mecânica e história são a mesma coisa (é fotografia), e isso faz o jogo ser reconhecível por um print. O 3D anterior fica no histórico do Git (commit 6457f42).

**D009: Ritmo lento, focado em história** · 2026-10-04 · Gabriel · continua valendo; números de 3D substituídos pela D010
Andar 2,4 m/s (Shift = 3,6, passo apressado), aceleração baixa (corpo com peso), pulo de 1 m, câmera mais perto, sobre o ombro e mais suave (FOV 58). A história chega por objetos para examinar e personagens para conversar (`Interactable` + caixa de diálogo com texto letra a letra). O jogador fica parado durante o diálogo.

**D008: Visual em tons de cinza** · 2026-10-04 · Gabriel · substituída pela D010
Só cinza e preto: do preto até um cinza claro (~80%), sem branco e sem cor. Garantido no motor por `assets/environment/gray_world.tres`: saturação 0 + gradiente de correção (preto → cinza 38% → cinza 80%). Mesmo um asset colorido sai cinza. Para ajustar o contraste do jogo inteiro, mexa nos pontos desse gradiente. Névoa cinza densa faz parte da identidade.

**D007: 3D em terceira pessoa** · 2026-10-04 · Gabriel · substituída pela D010
Renderer Forward+. Base: `actors/player` (CharacterBody3D + câmera orbital com SpringArm3D) e fase de teste `levels/sandbox` em greybox (CSG + shader de grade de 1 m). Física interpolada ligada (câmera segue a posição interpolada, sem tremer). Controles: WASD/setas + mouse, ou controle (analógicos, A pula, L3 corre).
Pendente: resolução base e plataforma alvo.

**D006: Arquivos grandes no Git LFS** · 2026-10-04 · Gabriel + John
Áudio, fontes de arte, modelos 3D, fontes e vídeo vão pro LFS. PNG/JPG ficam no Git normal.
Porquê: o repo fica leve para clonar. PNG de jogo 2D é pequeno; se o jogo for 3D com textura grande, a gente revê.

**D005: Código em inglês, o resto em PT-BR** · 2026-10-04
Identificadores, arquivos e nós em inglês; comentários, docs, commits e issues em PT-BR.
Porquê: combina com a API do Godot e evita acento em nome de arquivo; a conversa entre a gente continua em português.

**D004: Repo em `C:\dev\`, nunca em pasta sincronizada** · 2026-10-04
Porquê: OneDrive/Drive + Git + Godot corrompe `.git` e duplica cenas. A nuvem é o GitHub.

**D003: Trunk-based na `main` + sync frequente** · 2026-10-04
Os dois trabalham na `main` com `pull --rebase`. Branch `exp/*` só para mudança grande ou arriscada, via PR.
Porquê: a gente quer mexer em tudo junto, quase em tempo real. Branch longa gera conflito grande; sync pequeno e frequente gera conflito pequeno e raro.

**D002: Contexto compartilhado dos Claudes vive no repo** · 2026-10-04
`CLAUDE.md` + `.claude/` (settings e skills) versionados; `CLAUDE.local.md` é pessoal.
Porquê: as contas são separadas e os Claudes não compartilham memória.

**D001: Godot 4.7.2 + GDScript tipado** · 2026-10-04
Porquê: cenas e recursos em texto (a IA lê e edita, o Git faz merge), CLI completa (import, testes, export headless), grátis (MIT, sem royalty), serve para 2D e 3D, leve, e o editor visual atende o jeito "monta no editor" da gente. GDScript em vez de C#: integração total com o editor, hot reload, não exige .NET SDK e exporta para web.
