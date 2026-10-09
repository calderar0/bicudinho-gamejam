extends LevelBase
## Cena de teste (teste_janela): janela redimensionável com vidro, mapa, ícones arrastáveis,
## bicudinho e o graveto no fim. Serve para experimentar mecânicas sem mexer nas fases.


func _setup_level() -> void:
	window_rect = Rect2(48, 48, 544, 272)  # deixa 45 px livres de cada lado: cabe um ícone
	window_min = Vector2(160, 112)
	window_max = Vector2(544, 272)
	bird_start = Vector2(72, 288)
	exit_feet = Vector2(560, 288)          # no chão, depois do degrau alto
	win_text = "Fase concluída!"
	icons_data = [
		{"type": "folder", "x": 0, "y": 64, "draggable": true},
		{"type": "folder", "x": 0, "y": 96, "draggable": true},
		{"type": "file", "x": 0, "y": 128, "draggable": true},
		{"type": "notepad", "x": 608, "y": 64, "draggable": false},
		{"type": "virus", "x": 480, "y": 256, "draggable": false},
	]
	note_text = "O poço é largo.\nArraste as pastas para dentro da janela e use como degraus."
	note_title = "notas.txt"
	note_pos = Vector2(400, 60)
	note_size = Vector2(200, 84)
	note_open_at_start = false  # abre com duplo clique no ícone do bloco de notas
	hint = "Espaço no ar: preparar | setas: mirar | segurar ↑ caindo: planar | R: reiniciar | arraste os ícones"


func _paint_map(g: Array) -> void:
	paint(g, 0, 18, 39, 19, "#")    # chão
	paint(g, 12, 18, 20, 19, "~")   # poço de rio (9 tiles: só com a disparada ou com pastas)
	paint(g, 26, 15, 29, 17, "#")   # degrau alto (3 tiles)
	paint(g, 20, 13, 24, 13, "=")   # plataforma fina
	paint(g, 36, 12, 37, 17, "#")   # parede perto da borda direita
