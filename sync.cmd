@echo off
rem Sincroniza com o GitHub. Duplo clique: puxa o do parceiro e pergunta se quer mandar o seu.
rem Pelo terminal: sync "feat(player): adiciona pulo"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\sync.ps1" %*
if "%~1"=="" pause
