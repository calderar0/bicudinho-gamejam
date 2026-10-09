extends LevelBase
## Fase 3, Estica. Ensina que o mundo continua fora da janela: esticar revela o resto.
##
## A janela começa mostrando só as colunas 2 a 18 (metade esquerda) e pode esticar até a 37.
## A altura é fixa. O chão fica na linha 18.
##   0-18   chão de partida; o penhasco termina bem na borda direita da janela (no vidro)
##   19-29  rio contínuo, também por baixo da plataforma (só aparece depois de esticar)
##   22-25  plataforma 2 tiles acima do rio: esticando pouco, aparece só um pedaço dela
##          (o "aha": o mundo já estava lá, só estava invisível)
##   30-39  chão do outro lado, com o graveto
## Fora da janela, a saída aparece no desktop como o ícone do brejo, à direita: a pista.


func _setup_level() -> void:
	window_rect = Rect2(32, 48, 272, 272)   # só a metade esquerda
	window_min = Vector2(272, 272)          # não encolhe
	window_max = Vector2(576, 272)          # estica para a direita até a coluna 37
	bird_start = Vector2(72, 288)           # pés sobre o chão (linha 18 do mapa)
	exit_feet = Vector2(552, 288)           # o graveto, no chão do outro lado
	note_text = "O brejo está logo ali, à direita.\nPuxe a borda direita da janela!"
	note_pos = Vector2(360, 40)
	note_size = Vector2(200, 60)
	level_name = "Fase 3: Estica"
	next_level = "res://scenes/level_04.tscn"


func _paint_map(g: Array) -> void:
	paint(g, 0, 18, 18, 19, "#")    # chão de partida, até o penhasco
	paint(g, 19, 18, 29, 19, "~")   # rio contínuo (11 tiles), passando por baixo da plataforma
	paint(g, 22, 16, 25, 17, "#")   # plataforma 2 tiles acima do chão, sobre o rio
	paint(g, 30, 18, 39, 19, "#")   # chão do outro lado
	paint(g, 22, 15, 22, 15, "^")   # lixo no começo da plataforma
	paint(g, 32, 16, 32, 16, "|")   # vidro no chão antes do graveto: pule por cima
