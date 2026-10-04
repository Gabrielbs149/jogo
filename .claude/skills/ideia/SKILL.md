---
name: ideia
description: Registra uma ideia do jogo como issue no GitHub (label "ideia") para os dois verem e discutirem. Use quando o usuário disser "anota essa ideia", "tive uma ideia", "registra isso como ideia", "/ideia ...".
---

# Registrar ideia

1. Reescreva a ideia de forma clara, **sem inventar** o que ele não disse. Só pergunte se faltar o essencial para entender.
2. Procure duplicata: `gh issue list --label ideia --state all --search "<2-3 palavras-chave>"`. Se já existir parecida, mostre e pergunte se vira comentário naquela.
3. Crie a issue:
   ```
   gh issue create --label ideia --title "[Ideia] <resumo em até 8 palavras>" --body "<corpo>"
   ```
   Corpo com as seções do template: **A ideia** · **Por que deixa o jogo melhor** · **Referências** · **Tamanho estimado** (Pequena/Média/Grande/Não sei). Deixe em branco o que ele não falou.
4. Devolva o link. **Não implemente nada:** ideia só vira código depois de aprovada na call e virar issue `tarefa`.
