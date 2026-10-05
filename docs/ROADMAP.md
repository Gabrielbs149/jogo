# Roadmap

Cada fase tem um critério de saída ("fecha quando..."). As tarefas viram issues no board; este arquivo é o mapa. Fechou uma fase: atualiza aqui e cria a tag.

**Divisão:** vocês querem mexer em tudo junto, então a divisão é **por tarefa**, não por área fixa. Toda tarefa tem **um dono da vez** (o assignee da issue), mas os dois podem tocar em tudo. As marcações abaixo são sugestões de quem puxa:
🅖 Gabriel · 🅐 John · 🅖🅐 juntos (call + Live Share)

---

## Fase 0: Setup (1–2 dias)
**Fecha quando:** os dois já deram push, o CI está verde e fizeram o treino de conflito.
- [ ] 🅖 Criar o repo, copiar o kit, primeiro commit, convidar o 🅐, criar as labels e o board (`docs/SETUP.md`)
- [ ] 🅐 Clonar, rodar `tools/preparar.ps1`, abrir no Godot, primeiro commit
- [ ] 🅖 Instalar o GUT e fazer 1 teste de exemplo passar no CI
- [ ] 🅖🅐 Treino: conflito proposital + Live Share + uma ideia registrada pelo Claude
- [ ] 🅐 (opcional) Webhook do GitHub no Discord

## Fase 1: Ideia e protótipos de 1 dia (1–2 semanas)
**Fecha quando:** existe o GDD v1 de uma página e a decisão 2D/3D está registrada.
- [ ] 🅖🅐 Brain dump: cada um abre pelo menos 5 issues `ideia`, sem filtro
- [ ] 🅖🅐 Call de corte, escolhendo 2–3 ideias com este filtro:
  - Duas pessoas fazem em 6–12 meses?
  - Qual é o verbo principal (pular, atirar, conversar, construir...)?
  - É divertido nos primeiros 30 segundos?
- [ ] 🅖 Protótipo A e 🅐 protótipo B: até 1 dia cada, em `prototypes/<nome>/`, com quadradinhos no lugar da arte. Só a mecânica central.
- [ ] 🅖🅐 Jogar os protótipos e escolher (ou fundir)
- [ ] 🅐 Escrever o `docs/GDD.md` v1 (o Claude ajuda)
- [ ] 🅖 Registrar em `docs/DECISOES.md`: 2D/3D, renderer, resolução, plataforma alvo
- [ ] 🅖 Apagar os protótipos que não vingaram (o Git guarda o histórico)

## Fase 2: Vertical slice (3–6 semanas) → tag `v0.1.0`
**Fecha quando:** existe 1 fase jogável do começo ao fim (5–10 min) com o loop completo e arte provisória, e alguém de fora já jogou.
- [ ] 🅖 Arquitetura base: autoloads (`Events`, `Game`, `Save`), input map (teclado + controle), troca de cena com fade, pausa
- [ ] 🅐 Personagem principal: movimento, câmera e animação provisória. É o "feel", então itere bastante.
- [ ] 🅖 Sistema central do jogo (combate, puzzle, diálogo... depende da ideia)
- [ ] 🅐 Montar a fase no editor com as cenas que já existem
- [ ] 🅖🅐 HUD + menu principal + game over
- [ ] 🅖 Testes da lógica (dano, save, regras)
- [ ] 🅖🅐 Playtest com 2–3 amigos; tudo que aparecer vira issue

## Fase 3: Produção (meses) → uma tag `v0.x` por ciclo
**Fecha quando:** o conteúdo do GDD está todo no jogo.
- Ciclos de 2 semanas. No começo, cada um puxa suas issues do board. No fim: build, jogam juntos e criam a tag.
- [ ] 🅖🅐 Pipeline de arte definido (tamanho/escala dos sprites, paleta, export do Aseprite/Blender) → `DECISOES.md`
- [ ] Conteúdo (fases, inimigos, NPCs, história) em paralelo, cada um na sua pasta (menos conflito)
- [ ] Áudio: música, efeitos e menu de opções (volume, tela, controles)
- [ ] Save/load completo
- Regra: feature nova só entra se estiver no GDD. Ideia nova vai pro board, não direto pro código.

## Fase 4: Testes e polimento (3–6 semanas)
**Fecha quando:** não sobra nenhum bug bloqueante e pelo menos 5 pessoas de fora jogaram até o fim.
- [ ] Build fechada no itch.io (página restrita) para amigos testarem
- [ ] Label `bug` + triagem semanal (bloqueante / importante / depois)
- [ ] Performance (Profiler do Godot), PC fraco, resolução/tela cheia, controle
- [ ] Juice: partículas, screen shake, sons de UI, transições
- [ ] Acessibilidade básica: remapear teclas, legendas, tamanho do texto

## Fase 5: Lançamento → tag `v1.0.0`
**Fecha quando:** o jogo está no ar.
- [ ] Export presets commitados (Windows; Linux/Web se fizer sentido)
- [ ] CI gera a build na tag e publica no itch.io (butler)
- [ ] Página no itch.io (grátis) e/ou na Steam (taxa Steam Direct de US$ 100 por jogo)
- [ ] Capa, trailer de 30–60 s, gifs, press kit
- [ ] Patch 1.0.1 já planejado para a semana seguinte (sempre aparece bug)
