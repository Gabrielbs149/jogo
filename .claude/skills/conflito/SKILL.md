---
name: conflito
description: Resolve conflito de Git (rebase/merge parado) no projeto Godot sem perder o trabalho de ninguém. Use quando um sync/pull parar com CONFLICT, quando o git status mostrar "both modified"/"Unmerged paths", ou quando o usuário disser "deu conflito".
---

# Resolver conflito

**Atenção ao lado:** no `pull --rebase`, **`HEAD`/`--ours` = o remoto (o que o parceiro mandou)** e **`--theirs` = o seu commit** sendo reaplicado. É o contrário do que parece. O `merge.conflictStyle` é `zdiff3`, então o bloco `|||||||` mostra a versão original, antes dos dois mexerem.

1. **Mapear.** `git status` lista os arquivos em conflito. Para cada um, entenda a intenção dos dois lados:
   - do parceiro: `git log --oneline -3 HEAD -- <arquivo>`;
   - seu: `git log --oneline -3 REBASE_HEAD -- <arquivo>` (ou o commit indicado na mensagem do rebase).
2. **Resolver por tipo:**
   - **`.gd`, `.md`, `.json`, `.cfg`:** junte as duas intenções. Nunca apague a lógica do outro para a sua caber. Se forem incompatíveis (mesma função, comportamentos opostos), **pare** e mostre as duas versões para o humano decidir.
   - **`.tscn`, `.tres`:** o arquivo é feito de blocos `[ext_resource]`, `[sub_resource]`, `[node]` e `[connection]`. Junte os blocos dos dois lados. Cada `id` precisa ser único: se colidir, renumere o seu e atualize os `ExtResource("id")`/`SubResource("id")` que apontam para ele. Um nó com o mesmo `name` + `parent` só pode existir uma vez. Se ficar complexo (muitos blocos mexidos dos dois lados), fique com a versão do parceiro (`git checkout --ours <arquivo>`) e liste para o humano **exatamente** o que ele precisa refazer no editor.
   - **`project.godot`:** junte as chaves. Em `[autoload]` e `[input]`, mantenha as entradas dos dois.
   - **`.uid`, `.import`:** fique com o do remoto (`git checkout --ours <arquivo>`).
   - **Binário** (png, wav, aseprite...): não dá para juntar. Pergunte ao humano qual versão fica; a outra pode ser salva como `nome_v2.ext`.
3. **Limpar.** Nenhum `<<<<<<<`, `|||||||`, `=======` ou `>>>>>>>` pode sobrar: `git diff --check`.
4. **Checar.** `powershell -NoProfile -ExecutionPolicy Bypass -File tools/check.ps1` verde.
5. **Continuar.** `git add <arquivos>` e `GIT_EDITOR=true git rebase --continue`. Se parar de novo no próximo commit, repita.
6. **Travou ou ficou confuso?** `git rebase --abort` volta tudo para antes do pull, sem perder nada. Explique ao humano e peça ajuda; não force.
7. **Contar ao humano** o que foi juntado, o que ficou de qual lado e o que ele deve abrir no editor para conferir.
