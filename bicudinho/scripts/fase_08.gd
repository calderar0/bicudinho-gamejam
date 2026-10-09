extends LevelBase
## Fase 8, Trampolim. A saída foge, e a moldura da janela vira trampolim.
##
## A janela começa pequena (colunas 2 a 21, linhas 7 a 19) e estica até a tela toda.
## O graveto foge sempre que o bicudinho chega perto: pula para o próximo lugar da lista que
## não esteja inteiro dentro da janela. Esticando a janela até cobrir os três lugares, ele não
## tem para onde ir. O último lugar é uma beirada 10 tiles acima do chão (colunas 24 a 30).
## Para subir: puxe a base da janela para cima, rápido, com ele no chão. O vidro empurra e
## lança (trampolim). Subir a base devagar também serve: o vidro vira chão mais alto e dali
## dá para chegar com pulo e disparada.


func _setup_level() -> void:
	window_rect = Rect2(32, 112, 320, 208)
	window_min = Vector2(256, 160)
	window_max = Vector2(576, 272)
	bird_start = Vector2(72, 288)
	exit_feet = Vector2(296, 288)
	exit_spots = [Vector2(296, 288), Vector2(552, 288), Vector2(440, 128)]
	bottom_launch = true
	level_name = "Fase 8: Trampolim"
	next_level = "res://scenes/level_09.tscn"


func _paint_map(g: Array) -> void:
	paint(g, 0, 18, 39, 19, "#")    # chão
	paint(g, 24, 8, 30, 9, "#")     # beirada alta (10 tiles acima do chão)
