# Decisões

Registro curto do que foi decidido e por quê, para os dois humanos e os dois Claudes. Decisão nova vai no topo. Mudou de ideia? Não apague: crie uma nova entrada que "substitui a Dxxx".

Formato: **Dxxx — título** · data · quem · decisão · porquê.

---

**D007: 2D ou 3D** · pendente · decidir na Fase 1, depois dos protótipos.
Junto: renderer (Compatibility para 2D leve/web; Forward+ para 3D), resolução base e plataforma alvo.

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
