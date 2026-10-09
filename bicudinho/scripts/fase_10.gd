extends LevelBase
## Fase 10, Cópia. Uma barra de "Copiando arquivos..." é a ponte, e o desktop está bagunçado.
##
## A janela é fixa (colunas 7 a 32). O rio (colunas 13 a 22) tem uma barra de progresso no
## nível do chão que cresce sozinha e vira ponte em ~18 s. Do outro lado, uma pilha de ícones
## (2 de largura, 5 de altura) tampa o caminho até o graveto: é preciso tirar os ícones da
## janela, arrastando para o desktop. O contrário da fase 2: menos é mais.
## Quem não quer esperar a cópia pode usar um ícone da pilha de degrau no rio.

var bridge: ProgressBridge


func _setup_level() -> void:
	window_rect = Rect2(112, 64, 416, 256)
	bird_start = Vector2(136, 288)
	exit_feet = Vector2(496, 288)
	icons_data = []
	var names := ["copia (1).txt", "copia (2).txt", "foto_final.jpg", "foto_final2.jpg",
		"novo.txt", "novo (2).txt", "lixo.zip", "backup.zip", "sem titulo", "sem titulo (2)"]
	var types := ["file", "file", "image", "image", "file", "file", "app", "app", "file", "file"]
	var k := 0
	for col in [400, 432]:
		for row in [128, 160, 192, 224, 256]:
			icons_data.append({"type": types[k], "x": col, "y": row, "label": names[k]})
			k += 1
	level_name = "Fase 10: Cópia"
	next_level = "res://scenes/level_11.tscn"


func _paint_map(g: Array) -> void:
	paint(g, 7, 18, 12, 19, "#")    # chão de partida
	paint(g, 13, 18, 22, 19, "~")   # rio
	paint(g, 23, 18, 39, 19, "#")   # chão do outro lado
	paint(g, 24, 17, 24, 17, "^")   # lixo logo depois da ponte, na frente do muro de ícones


func _ready() -> void:
	super._ready()
	bridge = ProgressBridge.new()
	bridge.setup(Rect2(208, 288, 160, ProgressBridge.H), 18.0)
	add_child(bridge)
	bridge.update_inside(win.rect)


func _on_rect_changed() -> void:
	super._on_rect_changed()
	if bridge != null:
		bridge.update_inside(win.rect)
