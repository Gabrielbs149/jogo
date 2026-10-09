# 05 · Som

## Decisões fechadas
- Arquivos de áudio vão para o **Git LFS** (D006). Sons em `assets/audio/{musica,ambiente,sfx}/`, instalados por `tools/art/instalar_sons.py`; créditos em `assets/CREDITOS.md`.
- **Primeira trilha (D034), tudo CC0:** efeitos da Kenney (RPG Audio, Impact Sounds, Interface Sounds, UI Audio, Music Jingles) e músicas/ambientes do OpenGameArt.
- **Autoload `Audio`** (`systems/audio/audio.gd`): música com troca suave, ambiente em laço, efeitos por nome com variação (cada nome sorteia entre as versões `_0.._4` e varia um pouco o tom). Botões de qualquer tela fazem clique e som ao passar o mouse sozinhos.
- **Canais de volume:** Musica, Efeitos, Ambiente (`default_bus_layout.tres`; volumes iniciais em `tools/art/configurar_som.gd`).
- **Música por fase** no Inspector da fase (`Level.musica`, `Level.ambiente`): Arandu = "rotina" (violão gerado, D059; antes "The Old Tower Inn", RandomMind) + laço "cidade"; Ethera = "Desert Loop" + vento; arena = "Heartfelt Battle". Vitória e derrota com vinheta.
- **Passos** pelo tipo de chão (`Level.surface_at`): grama, pedra, terra, areia. Em Arandu o chão vem da máscara do chão pintado (calçada = pedra, terra = terra).
- **Luta:** golpe, impacto ao levar dano, esquiva, aparar (metal), queda, som do QTE (perfeito/bom/errou), tique no começo do seu turno.
- **Mundo:** interagir (ler, conversar, descansar, viajar) tem som; toda fogueira estala (`assets/vfx/fogo.tscn`).
- **Cenas:** cada fala faz um tique curto; `[som: nome]` também procura em `assets/audio/`.

## Em aberto
- [A DEFINIR] **Música própria** do jogo (compor/encomendar) ou seguir com as CC0? Tema de cada personagem?
- [A DEFINIR] **Música de chefe** separada da luta normal?
- **Ambiente de cidade (D059):** gerado por `tools/audio/gerar_sons.py` (numpy, sem baixar nada): laço "cidade" (vento + conversa distante sem palavras + rumor), madeira, pombo, cachorro longe, gato, saquinho de pão ("pegar_comida") e a música "rotina". `world/ambiente_camadas.gd` toca os sons soltos de vez em quando em volta do herói (passos na pedra, madeira, bichos), com silêncio entre eles. A música abaixa durante as conversas. Feitos sem ouvir: trocar o que não soar bem.
- [A DEFINIR] **Vinhetas de vitória/derrota:** escolhidas sem ouvir (Kenney "PIZZI07" e "PIZZI16"); trocar se não combinarem.
- [A DEFINIR] **Sons próprios de cada habilidade** (hoje todo ataque usa o mesmo "golpe").
- [A DEFINIR] **Vozes:** dublagem, murmúrios ou só texto?
- **Opções (D038):** volume geral, música, efeitos e ambiente, gravados em `user://opcoes.cfg`.

## Música
| Onde | Faixa | Fonte |
|---|---|---|
| Arandu | The Old Tower Inn | RandomMind, OpenGameArt (CC0) |
| Ethera | Desert Loop | OpenGameArt (CC0) |
| Arena | Heartfelt Battle (loop) | OpenGameArt (CC0) |
| Vitória / derrota | jingles_PIZZI07 / jingles_PIZZI16 | Kenney Music Jingles (CC0) |

## Efeitos
Passos (grama, pedra, areia: Kenney Impact; terra: Kenney RPG), golpe (faca/machado), impacto (soco), aparar (metal), esquiva (pano), queda, QTE (confirmação/clique/erro), interface (clique, passar o mouse), ler (página), conversar (pano), viajar (porta), descansar (couro), tique de turno e de fala. Lista e arquivos em `tools/art/instalar_sons.py`.

## Clima sonoro
- Arandu: música de taverna medieval, calma.
- Ethera: música do deserto + vento em laço; estalo das fogueiras e braseiros.
