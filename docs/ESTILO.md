# Guia de estilo: Negativo + Névoa

O jogo é **2D, visto de lado, pixel art em preto e branco, suspense sinistro e ritmo lento**. A mecânica que define o jogo é a **câmera fotográfica**: o flash mostra a cena em **negativo**, e o negativo revela o que o olho não vê. Fora de casa o mundo é **branco de névoa**; dentro é **breu**.

Referência de traço: a prancha que o Gabriel mandou (contorno claro sobre fundo escuro, texturas pontilhadas, alto contraste, caixa de diálogo com retrato). Referência de visão e mecânica: o "Caminho 3" da proposta de direção de arte.

## Paleta: 6 tons, nenhum a mais
| # | Nome | Hex | Uso |
|---|---|---|---|
| 0 | Breu | `#0A0A0A` | fundo do escuro, silhueta de perto, ameaça |
| 1 | Carvão | `#232323` | sombra dentro do preto, cabelo, chão perto |
| 2 | Sombra | `#474747` | roupa, objeto no escuro, contorno apagado |
| 3 | Cinza | `#767676` | parede, meio-tom, texto secundário |
| 4 | Névoa | `#ABABAB` | distância, pele, luz fraca |
| 5 | Osso | `#E8E8E8` | céu de névoa, papel, flash, texto |

- **A imagem vive nos extremos.** Breu e Osso fazem a cena; os 4 cinzas dão profundidade.
- **Sem degradê liso.** Transição de tom é sempre pontilhado (dither Bayer 4×4).
- **Desenhe com a paleta exata.** O pós-processo (`systems/screen/screen.gdshader`) força a paleta de qualquer jeito: cor fora vira o tom mais próximo pontilhado. Mas arte desenhada certa fica mais limpa.

## Os três estados da tela
| Estado | Quando | Como fica |
|---|---|---|
| **Névoa** | fase com `dark = false` (exteriores) | a cena como foi desenhada. Céu Osso, distância clara, perto escuro: **quanto mais escuro, mais perto** |
| **Escuro** | fase com `dark = true` (interiores) | só os contornos fortes aparecem (diferença de 2+ tons vira linha Sombra); em volta do personagem, a cena aparece apagada |
| **Negativo** | 0,85 s depois de cada foto | a cena **acesa** com os tons invertidos, incluindo tudo que é `Revealable`. Depois se desfaz em pontos |

Consequência para quem desenha **interior**: a arte é desenhada **acesa**, como a foto vai mostrar. No escuro, o jogador só vê o que tem contraste forte. Então:
- **Quer que algo se veja no escuro** (porta, quadro, móvel)? Contorno com 2+ tons de diferença do fundo.
- **Quer que algo só apareça na foto** (papel de parede, mancha, detalhe)? Tons vizinhos (1 de diferença).
- **Quer que algo só exista na foto**? Ponha como filho de um nó `Revealable` (`components/revealable/`).

## Tamanhos
| Coisa | Tamanho |
|---|---|
| Tela | 320×180, ampliada só em número inteiro (×4 = 1280×720, ×6 = 1920×1080) |
| Personagem | 20×32, pés na origem do nó |
| Figuras/criaturas | livres, mas pés na origem e silhueta legível em Breu e invertida em Osso |
| Tiles e props | grade de 16 |
| Retrato do diálogo | 32×32 |
| Chão | linha do chão de cada fase: estrada y = 148, corredor y = 152 |

## Movimento e animação
- Andar a 34 px/s (lento, pesado). Sem corrida e sem pulo, a menos que a história peça.
- Animação travada: andar a 6 quadros/s, parado com piscada rara.
- Nada de rotação ou escala fracionária em sprite. Câmera presa no pixel.

## Texto e interface
- Fonte **Tiny5** (`assets/fonts/tiny5.ttf`, licença OFL), tamanho 10, sem suavização. Tem acento.
- Caixa de diálogo: fundo Breu, borda Osso de 1 px, retrato à esquerda, texto letra por letra, `E` piscando para continuar.
- Avisos ("E ler"): caixinha Breu com borda Névoa, centralizada embaixo.
- Interface fica **acima** do pós-processo (não inverte na foto), mas usa só as cores da paleta.

## Som (quando entrar)
Silêncio como base. Ruído de fita, vento, respiração, passos no assoalho. O clique e o "zumbido" do flash carregando são o som mais importante do jogo. Música rara; quando entra, importa.

## Arte provisória
Toda a arte atual foi gerada por `tools/art/generate.js` ("arte de programador", só para o jogo rodar no estilo). Para trocar: desenhe no Pixelorama (grátis) ou Aseprite **no mesmo arquivo PNG, mesmo tamanho**, e salve por cima. A fonte editável (`.aseprite`, `.pxo`) vai em `art_src/`. Depois de redesenhar um arquivo, não rode o gerador de novo (ele sobrescreve).

## Acessibilidade
O flash tem opção de clarão mais fraco (`Photo.soft_flash`). Vai virar uma configuração no menu.
