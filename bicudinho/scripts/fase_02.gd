extends LevelBase
## Fase 2, Arrasta. Ensina que ícones do desktop viram chão dentro da janela. Janela fixa.
##
## A janela mostra as colunas 10 a 37 e as linhas 4 a 17. O chão fica na linha 16.
##   10-16  chão de partida
##   17-30  rio de 14 tiles
##   31-37  barranco de 8 tiles de altura com a bicudinha
## Sem ajuda é impossível: pulo + disparada sobe ~9 tiles mas só anda ~7 para o lado,
## e planar ganha distância perdendo altura. Uma pasta no meio do rio, uns 4 tiles
## acima do chão, resolve (com disparadas); duas pastas deixam fácil.
##
## Ícones: fora da janela são só ícones do desktop (com nome embaixo). Dentro da janela
## viram um bloco sólido de Tuning.ICON_SIZE (2x2 tiles). Arrastar solta na grade de 16 px.
## Duplo clique abre: as pastas mostram os arquivos de dentro, e as fotos abrem no visualizador.


func _setup_level() -> void:
	window_rect = Rect2(160, 64, 448, 224)  # janela fixa
	bird_start = Vector2(200, 256)          # pés sobre o chão (linha 16 do mapa)
	exit_feet = Vector2(560, 128)           # a bicudinha espera em cima do barranco (topo em y=128)
	icons_data = [
		{"type": "folder", "x": 16, "y": 32, "label": "fotos_rio", "contents": [
			{"kind": "image", "name": "rio_01.jpg", "photo": "rio_01",
				"caption": "O rio Tietê, onde tudo começa."},
			{"kind": "image", "name": "brejo_01.jpg", "photo": "brejo_01",
				"caption": "O brejo limpo: o lar do bicudinho."},
		]},
		{"type": "trash", "x": 16, "y": 96, "label": "lixeira", "contents": [
			{"kind": "image", "name": "lixo_01.jpg", "photo": "lixo_01",
				"caption": "Lixo no rio: o que sobra da cidade."},
		]},
		{"type": "image", "x": 16, "y": 160, "label": "bicudinho.jpg", "photo": "bicudinho_01",
			"caption": "O bicudinho-do-brejo-paulista."},
		# a dica é um arquivo de texto de verdade: fechou, é só dar duplo clique para abrir de novo
		{"type": "notepad", "x": 72, "y": 32, "draggable": false, "label": "dica.txt"},
	]
	# conteúdo do dica.txt (abre sozinho no início; fecha no X, arrasta pela barra)
	note_text = "Os ícones do desktop viram chão dentro da janela.\nArraste uma pasta!"
	note_pos = Vector2(8, 216)
	note_size = Vector2(136, 60)
	hint = "Mouse: arrastar ícones (duplo clique abre) | Espaço no ar: preparar | ↑ caindo: planar | R: reiniciar"
	# next_level: ainda não existe a fase 3 (a fase 2 recomeça ao vencer)


func _paint_map(g: Array) -> void:
	paint(g, 0, 16, 39, 17, "#")    # chão
	paint(g, 17, 16, 30, 17, "~")   # rio (14 tiles)
	paint(g, 31, 8, 39, 15, "#")    # barranco da bicudinha (8 tiles)
