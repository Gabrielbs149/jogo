<#
"Botão de sincronizar": puxa o que o parceiro mandou e, se tiver mensagem, commita e manda o seu.
  tools\sync.ps1                                  -> puxa (e pergunta se quer mandar o que você mudou)
  tools\sync.ps1 "feat(player): adiciona pulo"    -> commita tudo, puxa e manda
O sync.cmd na raiz chama este script (dá para usar com duplo clique).
#>
param([string]$Mensagem = '')

$raiz = Split-Path $PSScriptRoot -Parent
Set-Location $raiz

function Sair([string]$texto) {
    Write-Host $texto -ForegroundColor Red
    exit 1
}

# Conflito pendente de uma sync anterior?
$gitDir = (git rev-parse --git-dir).Trim()
if ((Test-Path "$gitDir/rebase-merge") -or (Test-Path "$gitDir/rebase-apply") -or (Test-Path "$gitDir/MERGE_HEAD")) {
    Sair "Tem um conflito pendente da última sync. Peça pro Claude: 'resolve o conflito'. (Para desfazer o pull: git rebase --abort)"
}

$mudancas = git status --porcelain
if ($mudancas -and -not $Mensagem) {
    Write-Host "Você tem mudanças que ainda não foram enviadas:" -ForegroundColor Yellow
    git status --short
    try {
        $Mensagem = Read-Host "Mensagem do commit (ex: feat(player): adiciona pulo) [Enter = só puxar, sem enviar]"
    } catch {
        $Mensagem = ''
    }
}

if ($mudancas -and $Mensagem) {
    git add -A
    git commit -m $Mensagem
    if ($LASTEXITCODE -ne 0) { Sair "Commit recusado (motivo acima). Nada foi perdido." }
}

Write-Host "Buscando o que o parceiro mandou..."
git fetch --quiet
if ($LASTEXITCODE -ne 0) { Sair "Não consegui falar com o GitHub (internet? login? tente: gh auth status)." }

$upstream = git rev-parse --abbrev-ref '@{u}' 2>$null
if ($upstream) {
    $chegando = git log --format='%h %an: %s' 'HEAD..@{u}'
    git pull --rebase --autostash --quiet
    if ($LASTEXITCODE -ne 0) {
        Write-Host "CONFLITO nestes arquivos:" -ForegroundColor Red
        git diff --name-only --diff-filter=U | ForEach-Object { Write-Host "  $_" }
        Sair "Nada foi perdido. Peça pro Claude: 'resolve o conflito'. (Para desfazer o pull: git rebase --abort)"
    }
    if ($chegando) {
        Write-Host "Chegou do parceiro:" -ForegroundColor Cyan
        $chegando | ForEach-Object { Write-Host "  $_" }
    } else {
        Write-Host "Nada novo do parceiro."
    }
    $naoEnviados = [int](git rev-list --count '@{u}..HEAD')
} else {
    $naoEnviados = 1  # branch nova, ainda não existe no GitHub
}

if ($naoEnviados -gt 0) {
    Write-Host "Enviando (a checagem roda antes)..."
    if ($upstream) { git push } else { git push -u origin HEAD }
    if ($LASTEXITCODE -ne 0) { Sair "Push falhou (motivo acima). Seus commits estão salvos aqui, nada foi perdido." }
    Write-Host "Enviado." -ForegroundColor Green
} elseif ($mudancas -and -not $Mensagem) {
    Write-Host "Suas mudanças continuam aqui, só não foram enviadas."
}

Write-Host "Se o Godot estiver aberto e perguntar se quer recarregar arquivos: RELOAD." -ForegroundColor Yellow
exit 0
