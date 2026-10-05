# Decisões

Registro curto do que foi decidido e por quê, para os dois humanos e os dois Claudes. Decisão nova vai no topo. Mudou de ideia? Não apague: crie uma nova entrada que "substitui a Dxxx".

Formato: **Dxxx — título** · data · quem · decisão · porquê.

---

**D009: Ritmo lento, focado em história** · 2026-10-04 · Gabriel
Andar 2,4 m/s (Shift = 3,6, passo apressado), aceleração baixa (corpo com peso), pulo de 1 m, câmera mais perto, sobre o ombro e mais suave (FOV 58). A história chega por objetos para examinar e personagens para conversar (`Interactable` + caixa de diálogo com texto letra a letra). O jogador fica parado durante o diálogo.

**D008: Visual em tons de cinza** · 2026-10-04 · Gabriel
Só cinza e preto: do preto até um cinza claro (~80%), sem branco e sem cor. Garantido no motor por `assets/environment/gray_world.tres`: saturação 0 + gradiente de correção (preto → cinza 38% → cinza 80%). Mesmo um asset colorido sai cinza. Para ajustar o contraste do jogo inteiro, mexa nos pontos desse gradiente. Névoa cinza densa faz parte da identidade.

**D007: 3D em terceira pessoa** · 2026-10-04 · Gabriel
Renderer Forward+. Base: `actors/player` (CharacterBody3D + câmera orbital com SpringArm3D) e fase de teste `levels/sandbox` em greybox (CSG + shader de grade de 1 m). Física interpolada ligada (câmera segue a posição interpolada, sem tremer). Controles: WASD/setas + mouse, ou controle (analógicos, A pula, L3 corre).
Pendente: resolução base e plataforma alvo.

**D006: Arquivos grandes no Git LFS** · 2026-10-04 · Gabriel + <AMIGO>
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
