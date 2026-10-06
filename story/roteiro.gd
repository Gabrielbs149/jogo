class_name Roteiro
extends Resource
## Uma cena do jogo escrita como roteiro: do jeito que se escreve a cena, mais alguns comandos entre colchetes.
## Tocada pelo CutscenePlayer (story/cutscene_player.gd). Edite o texto no Inspector.
##
##   Nome: "fala"            caixa de fala (aspas opcionais). Também vale "Nome:" numa linha e a fala entre aspas na de baixo.
##   > texto                 narração no meio da tela, sobre o preto. Linhas ">" seguidas aparecem uma a uma;
##                           linha em branco (ou ">" vazio) espera Espaço/clique e limpa.
##   [tela preta 0.8]        escurece (segundos opcionais; 0 = na hora)      [abre 1.5]  clareia
##   [corta: Plano1]         a câmera pula para o nó Plano1 (Camera3D ou Marker3D na fase)
##   [câmera: Plano2 3]      a câmera desliza até Plano2 em 3 s
##   [som: cidade | legenda] toca assets/sfx/cidade.ogg (ou .wav/.mp3) em laço; sem o arquivo, mostra a legenda
##   [para som]              [legenda: texto] (vazio apaga)                   [pausa 1.5]
##   [mostra: Nó]            [esconde: Nó]      (Nó pode ser caminho: Pao/Inteiro)
##   [anima: Tico sit]       prende o personagem numa animação               [solta: Tico]  volta ao normal
##   [coloca: Tico Marca]    põe o nó no lugar e na direção da Marca         [olha: Tika Tico]  vira um para o outro
##   [na mão: Pao]           prende o nó na mão direita do herói ([na mão: Pao Tico] para escolher quem)
##   [fim]                   termina aqui
##   # ...                   comentário. Qualquer outra linha (direção de cena) é só anotação e não aparece.
## "Tico" (ou o nome do herói que você joga, ou "jogador") é o seu personagem.

@export_multiline var texto: String = ""
