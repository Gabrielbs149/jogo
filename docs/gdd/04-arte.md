# 04 · Arte

> Substitui o antigo `docs/ESTILO.md`, que descrevia câmera tática de cima (D014, já substituída) e o visual
> anterior aos kits. Créditos dos assets de terceiros: `assets/CREDITOS.md`.

## Decisões fechadas
- **Estilo estilizado** com kits prontos e grátis (CC0): **Quaternius** (Medieval Village, Fantasy Props, Stylized Nature) no cenário e **KayKit Adventurers** nos moradores. Escolhido comparando a mesma cena montada com Quaternius, KayKit e Kenney (D026). Realista (Poly Haven) foi testado e descartado (D024 → D026).
- **Heróis principais com modelo próprio** feito a partir do desenho de referência pelo TRELLIS.2 + limpeza no Blender (D017).
- **Esqueleto humanoide padrão + animações prontas do KayKit por retarget** (D028). Mixamo testado e descartado (D021); animação feita à mão em código descartada (D020 → D028). Guia: `docs/GUIA_ESQUELETO.md`.
- **Arandu** planejada como cidade de verdade: muralha com torres, ruas de pedra em cruz, praça com poço e feira, casas coladas viradas para a rua, chão pintado (grama/terra/calçada), muita grama e figurantes (D027).
- **Céus HDRI** (Poly Haven): Arandu de dia com nuvens; Ethera, arena e tela de escolha ao entardecer (D024, mantido na D026).
- **Interface:** painéis marrom-escuros quase opacos (contraste), cantos pouco arredondados, borda fina dourada, texto creme; títulos em **Cinzel**, texto em **Lato** (`ui/theme/`).
- **Padrões de interface de jogo (D038):** nada de fundo em degradê: os menus têm **cena 3D** atrás (acampamento nas ruínas, `ui/menu_fundo/`, montado por `tools/art/montar_fundo_menu.gd`). Teclas aparecem **desenhadas como tecla** (estilo `Keycap`); avisos têm fundo (`ToastLabel`); menu principal em lista à esquerda (`MenuItem`) com foco visível para teclado. HUD do mapa: vida no canto de baixo à esquerda, habilidades em quadrados no centro, dicas de controle num cartão que some sozinho, história como legenda em baixo. Troca de tela com escurecimento.
- **Câmera da exploração:** atrás do ombro, um pouco alta e afastada (5,8 m) para mostrar o cenário (D018, D027).

## Em aberto
- [A DEFINIR] **Paleta oficial:** quais cores definem o jogo? (hoje: Arandu = tarde quente com telhados laranja e grama verde; Ethera = deserto avermelhado ao entardecer). Cada região tem paleta própria?
- [A DEFINIR] **Modelos de Chumasso, José Maria e Bahamut:** faltam os desenhos/modelos.
- [A DEFINIR] **Tika no esqueleto novo** (o modelo tem o braço colado no corpo; pode precisar de ajuste ou modelo novo em pose T).
- [A DEFINIR] **Inimigos:** o visual da D036 (peças rígidas de pedra/carvão com brilho) é proposta. Aprovar ou trocar?
- [A DEFINIR] **Animações que faltam:** gesto de comer sentado (cena do rato), animações próprias de cada habilidade.
- **Mais modelos grátis do poly.pizza (D041):** Medieval Village Pack do Quaternius (estalagem, ferreiro, estábulo, moinho, serraria, guarita, torre do sino, casas de enxaimel, bancas, poço), estátuas/chafariz/canteiros (Zsky, CC-BY), placas (iPoly3D), pães (Isa Lousberg), comida (Kenney), animais (Quaternius e madtrollstudio, CC-BY), itens de RPG e masmorra (Quaternius). Baixados por `tools/art/baixar_polypizza.py` (pacotes inteiros em `C:/dev/_pacotes/polypizza`) e só os usados entram no projeto (`tools/art/instalar_polypizza.py`).
- **Luz de Arandu (D041):** fim de tarde dourado (sol baixo vindo do oeste, sombras longas), tonemap AgX, SSAO + SSIL, névoa leve com raios de sol, cores um pouco mais saturadas; postes e lanternas acesos.
- [A DEFINIR] **Comprar arte paga?** Foi pesquisado: Synty Fantasy Kingdom (US$ 349,99 ou SyntyPass US$ 30/mês; dúvida sobre a licença depois de cancelar) e versões completas do Quaternius (~US$ 45 os três). Nada decidido.
- [A DEFINIR] **Efeitos das habilidades** (cor, forma). Garras psíquicas do Tico em roxo/rosa? *(proposta)*
- [A DEFINIR] **Referências visuais** oficiais (prints de jogos que o grupo quer como alvo).

## Direção visual (o que existe hoje)
- Formas macias, cores fortes mas não saturadas ao máximo, telhado de telha laranja, enxaimel, pedra cinza.
- Chão nunca de uma cor só: grama em vários tons, terra com grão e pedrinhas, calçada de pedra até as fachadas, mato encostado nas paredes (D027).
- Luz de fim de tarde macia, sombra suave, neblina leve com perspectiva aérea.
- Brilho só em fogo e magia (fogueira, braseiros, runas).

## Referências
- Jogo do Yoda (YouTube, Unity + Claude): chão pintado, vegetação espalhada, cidade cheia — usado para diagnosticar o "feio" (D027).
- Journey: luz quente e ruínas que contam história, com moderação e sem copiar as marcas (D014).
- [A DEFINIR] outras.

## Lista de assets
| Tipo | Onde | Estado |
|---|---|---|
| Kits de cenário (vila, objetos, natureza) | `assets/kits/quaternius/` | em uso |
| Prédios, feira, praça, animais, comida (poly.pizza, D041) | `assets/kits/polypizza/` (créditos em `CREDITOS.md` da pasta) | em uso |
| Personagens e 76 animações | `assets/kits/kaykit/` (biblioteca `animacoes/humanoide.res`) | em uso |
| Peças do catálogo do editor (71) | `world/props/` (geradas por `tools/art/gerar_pecas.py`) | em uso |
| Materiais (reboco, telha, calçada...) | `assets/materials/` (`tools/art/gerar_materiais.py`) | em uso |
| Chão pintado | `assets/shaders/chao_pintado.gdshader` + `levels/arandu/art/` | em uso em Arandu |
| Céus | `assets/skies/` | em uso |
| Fogo (partículas) | `assets/vfx/fogo.tscn` | em uso |
| Tico-Lirou | `actors/tico_lirou/` (`tico_lirou_humanoide.glb`, fonte em `art_src/`) | final |
| Tika-Muro | `actors/tika_muro/` | modelo sem esqueleto |
| Rato assado, pão | `actors/props/rato/`, `world/props/pao.tscn` | em uso / fora da cena |
| Namfoodle | `actors/naumfode/` (`naumfode.glb`, preparado por `tools/blender/gerado/preparar_naumfode.py`) | final, com animações próprias |
| Chumasso, José Maria, Bahamut | `actors/heroes/` | provisórios |
| Inimigos de Ethera | `actors/enemies/` | proposta (D036): escaravelho, sentinela, Último Guardião com animação |
| Fontes Cinzel e Lato | `assets/fonts/` | em uso |
