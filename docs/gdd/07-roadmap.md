# 07 · Roadmap

> Cada fase tem um critério de saída. As tarefas viram issues no GitHub (label `tarefa`, com dono).
> Divisão por **tarefa**, não por área fixa: os dois mexem em tudo. 🅖 Gabriel · 🅙 John · 🅖🅙 juntos.

## Decisões fechadas
- **Fases do projeto:** 0 Setup → 1 Ideia e protótipos → 2 Vertical slice (`v0.1.0`) → 3 Produção (`v0.x` por ciclo) → 4 Testes e polimento → 5 Lançamento (`v1.0.0`) (roadmap original).
- **Fluxo:** branch por feature e PR para a `main`, sem revisão obrigatória (D030). Cada um com sua conta do Claude; o que vale para os dois mora no repo (D002).
- **Ideia não é tarefa:** ideia vira issue `ideia`; só entra no jogo depois de aprovada e virar `tarefa` (FLUXO).
- **Design:** `docs/gdd/` é a fonte da verdade (D031).

## Em aberto
- [A DEFINIR] **Quem faz o quê:** qual é a parte do John e qual é a do Gabriel daqui pra frente? (até agora o Gabriel conduziu quase tudo nas sessões com o Claude)
- [A DEFINIR] **Prazo / ritmo:** data alvo para o vertical slice (`v0.1.0`)? Ciclos de 2 semanas valem?
- [A DEFINIR] **Call de decisões:** a call semanal de 20 min para ideias está acontecendo? Quando?
- [A DEFINIR] **Escopo do vertical slice:** só Tico (Arandu → Ethera) ou um começo por herói?
- [A DEFINIR] **Build para mostrar:** gerar um `.exe` (precisa baixar os modelos de exportação do Godot, ~1 GB)?
- [A DEFINIR] **Limite do Git LFS grátis** (1 GB de espaço/banda por mês): já tem ~400 MB de arte. Plano se estourar?

## Fase 0 · Setup — praticamente concluída
- [x] Repo, kit, hooks (`commit-msg`, `pre-push`), CI, GUT com testes passando
- [ ] [A DEFINIR] 🅙 John clonou, rodou `tools/preparar.ps1` e fez o primeiro commit?
- [ ] [A DEFINIR] Treino de conflito e Live Share feitos?

## Fase 1 · Ideia e protótipos — concluída na prática
- [x] Decisões de forma do jogo: 3D, 3ª pessoa, luta por turnos com QTE (D018, D022), história da campanha (D013)
- [x] GDD organizado em `docs/gdd/` (este)

## Fase 2 · Vertical slice → `v0.1.0` — em andamento
**Fecha quando:** 1 caminho jogável do começo ao fim (5–10 min) com o loop completo e alguém de fora já jogou.
- [x] Tela inicial, escolha de herói, prólogo, cenas por roteiro
- [x] Arandu (cidade completa) com a cena de abertura do Tico
- [x] Ethera com encontros, arena por turnos com QTE e chefe
- [x] Tico com modelo final, esqueleto e animações
- [x] Namfoodle com modelo final e animações (D032)
- [x] Editor de mapas no jogo
- [x] Ethera com o mesmo cuidado visual de Arandu (D035)
- [x] Sons: música, passos, luta, interface (D034)
- [ ] Tika no esqueleto novo; inimigos com modelo
- [ ] Save/load
- [ ] Playtest com 2–3 pessoas de fora
- [ ] [A DEFINIR] donos de cada tarefa

## Fase 3 · Produção — não começou
- [ ] Começo e cena dos outros 4 heróis (depende dos textos e desenhos)
- [ ] Modelos dos outros 4 heróis (depende dos desenhos)
- [ ] Capítulos dos Astros depois de Ethera
- [ ] Progressão ([03-mecanicas.md](03-mecanicas.md))
- [ ] Música e efeitos; menu de opções
- Regra: feature nova só entra se estiver no GDD.

## Fase 4 · Testes e polimento — não começou
Build fechada para amigos, triagem de bugs, performance, juice (partículas, tremor de tela, sons de UI), acessibilidade (remapear teclas, legendas, tamanho do texto, opção de QTE mais fácil).

## Fase 5 · Lançamento → `v1.0.0` — não começou
Export presets, build pela CI, página (itch.io e/ou Steam) — [A DEFINIR] plataforma e preço em [00-visao-geral.md](00-visao-geral.md).

## Pendências que vieram das conversas
- Confirmar grafias (Chumasso/Chumaço, Namfoodle, Cindralight/Cindralich) e as "asas" da Tika.
- Garras psíquicas do Tico no lugar da Adaga? *(proposta)*
- Gesto de comer sentado na cena do rato.
- Limpeza opcional do histórico do Git (62 MB de texturas que foram fora do LFS no commit `6dd8733`) — só com push forçado, decisão dos dois.
