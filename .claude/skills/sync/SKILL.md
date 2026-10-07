---
name: sync
description: Sincroniza com o GitHub — commita o trabalho atual no padrão do projeto na branch da feature, traz a main atualizada e envia a branch (fluxo D030: branch por feature + PR). Use quando o usuário disser "sincroniza", "sync", "salva e manda", "manda pro git", "commita", "puxa o que ele fez", ou ao terminar uma tarefa.
---

# Sync

0. **Branch.** `git branch --show-current`. Se estiver na `main`, **não commite nela**: proponha um nome `<tipo>/<assunto>` e crie (`git switch -c ...`) antes de seguir (o trabalho não commitado vem junto).
1. **Ver o que tem.** `git status` e `git diff --stat`. Separe o que você fez nesta sessão do que já estava modificado (pode ser trabalho do humano no editor). Se tiver mudança que você não reconhece, mostre a lista e pergunte se entra.
2. **Checar.** `powershell -NoProfile -ExecutionPolicy Bypass -File tools/check.ps1`. Vermelho: conserte antes; nunca commite quebrado.
3. **Commitar por assunto.** Um `git add <arquivos>` + `git commit` para cada assunto, com mensagem `tipo(escopo): descrição` (tipos e exemplos no CLAUDE.md). `.uid`/`.import` novos vão junto do arquivo dono. Nada de `git add -A` às cegas.
4. **Ver o que chegou na main.** `git fetch` e depois `git log --format="%h %an: %s" HEAD..origin/main`.
5. **Atualizar a branch.** `git rebase origin/main` (só se a branch ainda não foi compartilhada com o parceiro; se já foi, `git merge origin/main`). Se parar com CONFLICT, siga a skill `conflito`.
6. **Enviar.** `git push -u origin <branch>` (depois de um rebase numa branch já enviada, NÃO force: use merge). Se ainda não tem PR, ofereça abrir (`gh pr create`). O pre-push roda a checagem de novo; se falhar, conserte e repita (nunca `--no-verify`).
7. **Resumir pro humano**, curto:
   - o que foi enviado (commits);
   - o que chegou do parceiro (lista do passo 4);
   - se chegou mudança numa cena que ele pode estar com aberta no Godot: avise que, quando o Godot perguntar, é para **recarregar** (salvar por cima apaga o trabalho do parceiro).

Sem mensagem clara para algum grupo de mudanças? Proponha uma e siga; o humano corrige depois se quiser (`git commit --amend` só antes do push).
