# 02 · Personagens

> Fichas de jogo (vida, CA, habilidades) moram nos `.tscn` de `actors/heroes/` e `actors/enemies/` e nos `.tres` de
> `data/abilities/` — os números abaixo são cópia para leitura; se divergirem, vale o arquivo do jogo.

## Decisões fechadas
- **Jogáveis:** os 5 heróis da campanha — Tico-Lirou, Namfoodle, Chumasso, José Maria e Bahamut (D013, D018). O jogador escolhe 1; os outros esperam pela fase e entram no grupo se chamados, mas **não lutam** (D022).
- **Vida na arena:** heróis com 2× a vida da ficha; inimigos com a vida da ficha (D022).
- **Habilidades:** 4 por herói (botão esquerdo, Q, E, R), com custo em Pontos de Ação (D018, D022).
- **Namfoodle** é a grafia certa (antes estava "Naumfode"). A **torreta dele é um burro**: "Invocar_Torreta" é a animação de chamar os burros. Altura de 0,95 m confirmada (D033). O id interno nos arquivos continua `naumfode`.
- **Modelos:** cada herói terá modelo próprio (D017). **Tico** (D028) e **Namfoodle** (D032) já têm modelo final, esqueleto e animações. Chumasso, José Maria e Bahamut usam bonecos provisórios.
- **Tico-Lirou** e **Tika-Muro**: história escrita pelo Gabriel (abaixo). A Tika foi levada (não está mais no acampamento).
- **Moradores e figurantes** usam os personagens do KayKit (D026): Knight, Barbarian, Mage, Rogue, Rogue_Hooded.

## Em aberto
- [A DEFINIR] **Grafias:** Chumasso ou Chumaço? Cindralight ou Cindralich?
- [A DEFINIR] **Nomes e efeitos das habilidades** são *(proposta)* (D018): batem com a ficha real de cada um na mesa?
- [A DEFINIR] **Garras psíquicas do Tico:** trocar a Adaga por garras de energia no formato das da Tika (efeito roxo/rosa)?
- [A DEFINIR] **Desenhos de referência / modelos** de Chumasso, José Maria e Bahamut.
- [A DEFINIR] **História e começo** de Namfoodle, Chumasso, José Maria e Bahamut (como a do Tico).
- [A DEFINIR] **Caiaque, Umu (ou Umo?) e Juca:** quem são, aparência, jeito de falar, o que já fizeram na campanha? *(proposta)* Ficam no acampamento entre batalhas.
- [A DEFINIR] **Fenrir:** personagem ou NPC?
- [A DEFINIR] **Tika no jogo:** só aparece em cenas? Vira objetivo (resgate)? Jogável depois?
- [A DEFINIR] **Moradores de Arandu:** as falas (padeira, vendedor, guarda, criança "moço-planta") são *(proposta)*. Valem?
- [A DEFINIR] **Inimigos:** os servos dos Astros (escaravelhos de cinza, sentinelas estelares) e o Último Guardião são *(proposta)* de design; os modelos são provisórios. Estilo dos inimigos (KayKit Skeletons foi citado como opção)?

## Heróis jogáveis
| Herói | Classe (no jogo) | Vida | CA | Habilidades (esq. / Q / E / R) | Começa em |
|---|---|---|---|---|---|
| **Tico-Lirou** | Ladino 3 · Kobold | 44 | 15 | Adaga · Bote das sombras · Espinhos · Camuflagem | Arandu |
| **Namfoodle** | Artífice 3 | 48 | 15 | Coice de burro · Carga de burro · Burro de reparo · Estouro de burros | Ethera (provisório) |
| **Chumasso** | Clérigo 3 (Guerra) · Golias | 60 | 18 | Martelo de guerra · Martelo sagrado · Bênção · Escudo da fé | Ethera (provisório) |
| **José Maria** | Patrulheiro 3 | 52 | 14 | Flecha · Tiro duplo · Marca do caçador · Chuva de flechas | Ethera (provisório) |
| **Bahamut** | Dragão dourado (voa) | 68 | 16 | Garras · Investida alada · Rugido · Sopro dourado | Ethera (provisório) |

*(Na ordem do campo `abilities` de cada `.tscn`.)*

### Tico-Lirou
Na campanha: ladino kobold, "97% planta". Visual: kobold verde de pintas, olho azul, chifres, crista rosa, capuz verde com ponta de folha, manto aberto, barriga cor de pêssego, perneiras, mochila com saco de dormir e cogumelo rosa.

História (texto do Gabriel, 06/10):
> Viveu nas ruas da famosa Arandu, órfão e muito serelepe da cabeça.
> Cresceu na base da sobrevivência e se adaptou bem ao bocado, mesmo não curtindo essa parada de fazer os outros sofrerem violentamente.
> No decorrer da sua vida conheceu de todo tipo de pessoa, mas apenas uma o conquistou — Tika-Muro, uma bela kobold que adorava dividir ratos com tico (ele sempre deixava o bumbum pra ela) e que o acompanhou por grande parte de sua história. Ela sempre dava com duas asas simples, bem gastas pelo tanto que usava, e sabia se virar bem com elas. Tico dizia que aquilo combinava com ela, mesmo sem nunca imaginar que um dia lutaria do mesmo jeito.
> Certo dia, Tico acorda e não vê Tika do seu lado, em cima de seu papelão.
> Desesperado procura por todos os lados, mas nada dela aparecer.
> Após meses, Tico descobre, por meio de mendigos conhecidos, que um pessoal de Cindralight anda sequestrando mendigos para alimentar uma forja.
> Desde então, Tico está em busca de encontrar sua amada, custe o que custar.
> Quando se concentra, Tico manifesta duas garras feitas de pura energia psíquica, moldadas exatamente igual a de Tika — além de estar carregas de lembranças afiadias de tudo que viveu ao lado dela.
> E ele vai fazer de tudo para vê-la novamente.

Cena de abertura (D029, falas *(proposta)*): beco, fogueirinha, rato espetado assando. Tika: "Isso aí é o que eu tô pensando?" — Tico: "Depende. Você tá pensando em jantar?" — "Tô pensando que isso tava vivo de manhã." — "E agora tá crocante. Evolução." — "Pega. Fica com o bumbum." — "Você SEMPRE me dá o bumbum." — "Porque é a melhor parte." — "Porque é a única parte que você não quer." — "...Também." — "Idiota."

### Os outros heróis
- **Namfoodle:** artífice que luta com burros (burro que dá coice, que atropela, burrinho que conserta os amigos). Modelo (D032): anão de barba branca e óculos de proteção, avental de couro, luvas e mochila com um aparelho roxo; 0,95 m. Arquivo do Gabriel: `art_src/naumfode_original.glb` ("Namfoodle").
- **Chumasso:** clérigo guerreiro, golias enorme; bate com o martelo e com a fé.
- **José Maria:** patrulheiro de arco longo e perna de pau; anda devagar e erra pouco.
- **Bahamut:** dragão; voa, morde e cospe fogo dourado.

## Personagens da história
- **Tika-Muro:** a amada do Tico (kobold de roxo, olhos rosa, cogumelo grande, espadas nas costas no modelo). Levada por gente de Cindralight. Tem modelo, ainda sem esqueleto (`actors/tika_muro/`).
- **Caiaque, Umu e Juca:** os NPCs favoritos da mesa ("#teamcaiaque", "as crônicas do Caiaque"). *(proposta)* Esperam o grupo no acampamento entre batalhas, dão conselho/item/reforço e, em algum capítulo, lutam junto.
- **Fenrir:** joga junto com Bahamut e Tico em algumas sessões.
- Citados na enquete do grupo: Blenk, Blonk, Baba/Bebe/Bibi/Bobo/Bubu, Tonhonhonho, **Robinho** (morreu pelo povo, ao se jogar de uma casa de dois andares), Lancelot, Golias. **Bren** (o que trapaceia nas apostas, citado em Ethera).

## Moradores de Arandu *(proposta)*
Padeira (Mage), vendedor de frutas (Barbarian com caneco), guarda do portão (Knight com espada: "lá fora as estrelas andam estranhas"), criança que chama o Tico de "moço-planta" (Rogue). Mais figurantes sem fala pela cidade (D027).

## Inimigos (capítulo de Ethera)
| Inimigo | Vida | CA | Habilidades | Papel |
|---|---|---|---|---|
| Escaravelho de cinza | 16 | 13 | Mordida | servo dos Astros, em dupla |
| Sentinela estelar | 20 | 14 | Raio vigia | servo dos Astros |
| **Último Guardião** (chefe) | 85 | 15 | Pancada · Onda de cinza | o espírito que protege o selo que não existe mais |
