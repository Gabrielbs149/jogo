# Decisões

> Log único de decisões do projeto. **Decisão nova vai no topo da tabela**, com o próximo número.
> Mudou de ideia? Não apague: crie uma nova linha que "substitui a Dxxx" e marque a antiga.
> O texto longo de D001–D029 (com números, arquivos e simulações) está em [`docs/DECISOES.md`](../DECISOES.md), que
> fica como histórico e não recebe mais entradas.

## Decisões fechadas
- Este arquivo é o log oficial a partir de D030 (D031).
- Formato: número · data · tema · decisão · motivo · situação.

## Em aberto
- Nada no momento.

| Nº | Data | Tema | Decisão | Motivo | Situação |
|---|---|---|---|---|---|
| D035 | 2026-10-07 | Arte / Níveis | Ethera no nível de Arandu: chão pintado de areia (trilha batida, piso de pedra nas ruínas), anel de muros partidos, portal de colunas, colunas soltas e entulho, rochas na cor do deserto, capim seco, árvores secas. Jogo (acampamento, heróis, inimigos, inscrições, altar) mantido. Montador `tools/art/montar_ethera.gd`. | Ethera ficou para trás depois da Arandu nova | vale |
| D034 | 2026-10-07 | Som | Primeira trilha com sons CC0 (Kenney + OpenGameArt): autoload `Audio`, música por fase e na luta, passos por tipo de chão, sons de luta, QTE, interface, interação e fogo. | o jogo não tinha nenhum som | vale |
| D033 | 2026-10-07 | Personagens | O nome é **Namfoodle** (não Naumfode). A torreta dele é um burro ("Invocar_Torreta" = chamar os burros). Altura de 0,95 m fica. Id interno nos arquivos continua `naumfode`. | Gabriel respondeu as perguntas do D032 | vale |
| D032 | 2026-10-07 | Arte / Personagens | Namfoodle ganha o modelo enviado pelo Gabriel (anão de barba, óculos, avental e mochila; 0,95 m), com o esqueleto e as 7 animações que vieram nele (Parado, Andar, Correr, Disparar, Invocar_Torreta, Dano, Morte) + as do KayKit pelo retarget (esquiva etc.). O burrinho continua ao lado dele. | Gabriel mandou o modelo pronto | vale |
| D031 | 2026-10-07 | Projeto | Design organizado em `docs/gdd/` (visão, história, personagens, mecânicas, arte, som, níveis, roadmap, decisões), que é a **fonte da verdade**; um comando do Claude por tema em `.claude/commands/`. GDD.md, HISTORIA.md, ESTILO.md e ROADMAP.md antigos viram ponteiros. | Gabriel pediu "repartições por tema" | vale |
| D030 | 2026-10-07 | Git | **Branch por feature + PR** para a `main` (CI verde obrigatório; **revisão do parceiro não é obrigatória**, quem abriu pode fazer o merge). Cada um com sua conta do Claude, sincronizando pelo GitHub. | Gabriel pediu esse fluxo ao organizar o projeto e confirmou que substitui a D003 sem precisar do parceiro | vale; substitui D003 |
| D029 | 2026-10-07 | História | Abertura do Tico com o rato assado dividido com a Tika (ele dá o bumbum). | Gabriel pediu "o Tico oferecendo um rato pra Tika" | vale (falas = proposta) |
| D028 | 2026-10-07 | Arte | Esqueleto humanoide + 76 animações do KayKit por retarget (Tico primeiro). | animações feitas à mão estavam ruins | vale; substitui D020 |
| D027 | 2026-10-07 | Arte / Níveis | Arandu replanejada como cidade de verdade (ruas, praça, muralha, chão pintado, grama, gente). | "só ouço risada dessa cidade" | vale |
| D026 | 2026-10-06 | Arte | Kits prontos: Quaternius (cenário) + KayKit (moradores). | escolhido comparando 3 kits na mesma cena | vale; substitui D024 |
| D025 | 2026-10-06 | História / Técnico | Cenas por roteiro (`Roteiro` + `CutscenePlayer`); prólogo em todo jogo novo. | Gabriel mandou prólogo, história e cena do Tico | vale |
| D024 | 2026-10-06 | Arte | Visual realista com Poly Haven. | "gráficos horríveis" | substituída pela D026 (céus HDRI continuam) |
| D023 | 2026-10-06 | Ferramenta | Editor de mapas dentro do jogo (F2). | "câmera lá em cima e liberar todo tipo de edição" | vale |
| D022 | 2026-10-06 | Mecânicas | Luta por turnos estilo Clair Obscur: só você, arena separada, QTE (vantagem, esquiva, aparar). | Gabriel quer a luta do Clair Obscur, focada no personagem dele | vale; substitui o combate em tempo real da D018 |
| D021 | 2026-10-06 | Arte | Mixamo testado e descartado. | braço sumindo, perna girando | vale |
| D020 | 2026-10-05 | Arte | Esqueleto e animações por script. | primeiras animações do Tico | substituída pela D028 |
| D019 | 2026-10-05 | Níveis | Cada herói começa num lugar; Tico em Arandu. | conhecer o lugar de cada um, começo simples | vale |
| D018 | 2026-10-05 | Mecânicas | 3ª pessoa, WASD, habilidades tipo LoL com regras de D&D 5.5; escolhe 1 herói e recruta os outros. | jogar com o próprio personagem e montar o grupo na história | vale (combate em tempo real trocado pela D022) |
| D017 | 2026-10-05 | Arte | Heróis gerados pelo TRELLIS.2 a partir do desenho. | fiel ao desenho por todos os lados, grátis | vale |
| D016 | 2026-10-05 | Arte | Forma por IA + pintura projetada. | — | substituída pela D017 |
| D015 | 2026-10-05 | Arte | Modelos dos heróis no Blender por script. | — | substituída pela D016/D017 |
| D014 | 2026-10-05 | Mecânicas / Arte | Exploração em tempo real + turnos na luta (estilo BG3); menos Journey. | — | substituída pela D018 (o "Journey com moderação" segue como referência) |
| D013 | 2026-10-05 | História | História = a campanha "A Noite Sem Nome" do grupo. | é a campanha deles | vale |
| D012 | 2026-10-05 | Mecânicas | 3D tático por turnos com visual do Journey. | — | substituída pela D018 |
| D011 | 2026-10-04 | Mecânicas | Câmera fotográfica como mecânica central. | — | substituída |
| D010 | 2026-10-04 | Arte | 2D lateral pixel art P&B. | — | substituída |
| D009 | 2026-10-04 | História / Mecânicas | Ritmo lento, focado em história (objetos e conversas contam o mundo). | — | vale o princípio; números substituídos |
| D008 | 2026-10-04 | Arte | Tons de cinza. | — | substituída |
| D007 | 2026-10-04 | Técnico | 3D em terceira pessoa (Forward+). | — | substituída pela D010, depois 3D voltou (D012/D018) |
| D006 | 2026-10-04 | Técnico | Arquivos grandes no Git LFS. | repo leve para clonar | vale |
| D005 | 2026-10-04 | Técnico | Código em inglês, o resto em PT-BR. | combina com a API do Godot | vale |
| D004 | 2026-10-04 | Técnico | Repo em `C:\dev\`, nunca em pasta sincronizada. | nuvem + Git + Godot corrompe | vale |
| D003 | 2026-10-04 | Git | Trunk-based na `main` + sync frequente. | conflitos pequenos | substituída pela D030 |
| D002 | 2026-10-04 | Projeto | Contexto dos Claudes vive no repo. | contas separadas, sem memória compartilhada | vale |
| D001 | 2026-10-04 | Técnico | Godot 4.7.2 + GDScript tipado. | texto legível pela IA, grátis, CLI, editor visual | vale |
