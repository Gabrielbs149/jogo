# 00 · Visão geral

> Fonte da verdade do design do jogo. Os outros arquivos de `docs/gdd/` detalham cada tema; o log de decisões fica em
> [decisoes.md](decisoes.md). O que é sugestão e ainda não foi decidido aparece como *(proposta)*.

## Decisões fechadas
- **Engine:** Godot 4.7.2, GDScript com tipagem estática, sem C# (D001).
- **Forma do jogo:** 3D. Exploração em 3ª pessoa (WASD + mouse) e luta **por turnos com QTE numa arena separada**, no estilo de Clair Obscur, com regras de D&D 5.5 adaptadas (D018 + D022).
- **Você escolhe 1 dos 5 heróis** da história e começa sozinho. Os outros você encontra pelo caminho e pode chamar para o grupo, mas **na luta só o seu personagem participa** (D018, D022).
- **Cada herói começa num lugar diferente.** Tico-Lirou começa em Arandu, a cidade natal dele (D019).
- **História:** a campanha de RPG de mesa do grupo, "A Noite Sem Nome" / Plano do Fogo, em Novazul (D013). O mundo é do mestre; o jogo adapta.
- **Visual estilizado** com kits prontos: Quaternius no cenário e KayKit nos moradores. Os heróis principais têm modelo próprio (D017, D026).
- **Equipe:** Gabriel (`@Gabrielbs149`) e John (`@JohnG-404`), cada um com o seu Claude.
- **Nome na tela inicial:** "A NOITE SEM NOME" (acima) e "Plano do Fogo" (título) — é o que está em `ui/title/title_screen.tscn`.

## Em aberto
- [A DEFINIR] **Gênero em uma palavra para a loja:** "RPG de ação"? "RPG por turnos com QTE"? "Aventura narrativa"?
- [A DEFINIR] **Público-alvo:** o grupo da mesa e amigos? Quem gosta de RPG por turnos (Clair Obscur, Persona)? Faixa etária?
- [A DEFINIR] **Plataforma:** só PC Windows? Linux/Steam Deck? Web? Controle além de teclado e mouse? (D007 deixou "resolução base e plataforma alvo" pendentes.)
- [A DEFINIR] **Distribuição e preço:** grátis no itch.io? Steam (US$ 100 por jogo)? Só para o grupo?
- [A DEFINIR] **Duração alvo:** quantas horas? Quantos capítulos (Astros)?
- [A DEFINIR] **Nome definitivo do jogo:** "Plano do Fogo", "A Noite Sem Nome" ou outro?
- [A DEFINIR] **O que o jogo NÃO é** (para cortar discussão): mundo aberto? multiplayer? combate em tempo real?
- [A DEFINIR] **Pilares** (até 3). O GDD antigo tinha "ação com cara de D&D / o grupo é escolha sua / ruínas que contam a história", escritos antes da D022 (que tirou o grupo da luta). Ainda valem?

## Conceito
Você segue um dos cinco aventureiros que perderam as sombras no mesmo dia, a partir da cidade onde a história dele começa, e atravessa Novazul encontrando os outros. Explorar é andar e conversar em 3ª pessoa; lutar é um duelo por turnos em que cada golpe e cada defesa dependem do dado de D&D **e** do seu tempo de reação.

## Pitch em 2 frases *(proposta de texto)*
Cinco desconhecidos perderam as sombras no mesmo dia, e agora os astros querem terminar a história deles antes da hora. Escolha quem você vai seguir, encontre os outros pelo caminho e vença duelos por turnos em que o dado de D&D e o seu reflexo decidem cada golpe.

## Referências citadas nas conversas
| Referência | O que pegar | Onde foi decidido |
|---|---|---|
| Clair Obscur: Expedition 33 | luta por turnos com reação em tempo real (QTE, esquiva, aparar) | D022 |
| League of Legends | habilidades em teclas (Q/E/R) com custo | D018 |
| D&D 5.5 | d20 contra CA, vantagem, salvamentos, classes | D018, D022 |
| God of War 3 | um chefe (Astro) por capítulo | HISTORIA, *(proposta)* |
| Journey | luz quente e ruínas que contam história, **com moderação** e sem copiar marcas | D014 |
| Jogo do Yoda (YouTube, Unity + Claude) | comparação de visual: chão pintado, vegetação, cidade cheia | D027 |
