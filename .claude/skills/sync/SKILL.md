---
name: sync
description: Sincroniza com o GitHub — puxa o que o parceiro mandou, commita o trabalho atual no padrão do projeto e envia. Use quando o usuário disser "sincroniza", "sync", "salva e manda", "manda pro git", "commita", "puxa o que ele fez", ou ao terminar uma tarefa.
---

# Sync

1. **Ver o que tem.** `git status` e `git diff --stat`. Separe o que você fez nesta sessão do que já estava modificado (pode ser trabalho do humano no editor). Se tiver mudança que você não reconhece, mostre a lista e pergunte se entra.
2. **Checar.** `powershell -NoProfile -ExecutionPolicy Bypass -File tools/check.ps1`. Vermelho: conserte antes; nunca commite quebrado.
3. **Commitar por assunto.** Um `git add <arquivos>` + `git commit` para cada assunto, com mensagem `tipo(escopo): descrição` (tipos e exemplos no CLAUDE.md). `.uid`/`.import` novos vão junto do arquivo dono. Nada de `git add -A` às cegas.
4. **Ver o que vai chegar.** `git fetch` e depois `git log --format="%h %an: %s" HEAD..@{u}`.
5. **Puxar.** `git pull --rebase` (o autostash já está ligado). Se parar com CONFLICT, siga a skill `conflito`.
6. **Enviar.** `git push`. O pre-push roda a checagem de novo; se falhar, conserte e repita (nunca `--no-verify`).
7. **Resumir pro humano**, curto:
   - o que foi enviado (commits);
   - o que chegou do parceiro (lista do passo 4);
   - se chegou mudança numa cena que ele pode estar com aberta no Godot: avise que, quando o Godot perguntar, é para **recarregar** (salvar por cima apaga o trabalho do parceiro).

Sem mensagem clara para algum grupo de mudanças? Proponha uma e siga; o humano corrige depois se quiser (`git commit --amend` só antes do push).
