# Decisões

Registro curto do que foi decidido e por quê, para os dois humanos e os dois Claudes. Decisão nova vai no topo. Mudou de ideia? Não apague: crie uma nova entrada que "substitui a Dxxx".

Formato: **Dxxx — título** · data · quem · decisão · porquê.

---

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
