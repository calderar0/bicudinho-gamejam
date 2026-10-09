extends LevelBase
## Fase 9, Cidade. A janela do jogo travou ("Não respondendo") e os anúncios não param.
##
## A janela não mexe. Só dá para usar os ícones e as mini-janelas. Do chão de partida até a
## beirada do graveto tem um rio largo. A cada poucos segundos abre um anúncio ("VOCÊ
## GANHOU!") num dos lugares da lista: o topo dele é plataforma, mas ele some sozinho. Os
## lugares formam uma escada sobre o rio. Os que atrapalham, é só fechar (X ou Esc).
## As pastas do desktop também servem de degrau, como na fase 2.

const AD_SPOTS := [
	Vector2(176, 240), Vector2(256, 212), Vector2(336, 184), Vector2(408, 168),
	Vector2(300, 120), Vector2(140, 150), Vector2(380, 248),
]
const AD_SIZE := Vector2(112, 36)
const AD_EVERY := 1.8      # segundos entre um anúncio e outro
const AD_LIFE := 7.0       # quanto tempo cada um fica aberto
const HEADLINES := ["VOCÊ GANHOU!", "CLIQUE AQUI!", "OFERTA!!!", "PRÊMIO!", "SÓ HOJE!"]

var _ads: Array[AdWindow] = []
var _next_ad := 0.6


func _setup_level() -> void:
	window_rect = Rect2(112, 64, 416, 256)
	window_frozen = true
	bird_start = Vector2(136, 288)
	exit_feet = Vector2(496, 160)
	icons_data = [
		{"type": "folder", "x": 32, "y": 96, "label": "fotos"},
		{"type": "folder", "x": 32, "y": 176, "label": "trabalho"},
		{"type": "trash", "x": 576, "y": 96, "label": "lixeira", "draggable": false, "contents": []},
	]
	wallpaper_color = Color("56677a")
	wallpaper_tint = Color(0.72, 0.76, 0.84)   # cidade: céu cinzento
	sky_color = Color("b9c6d3")
	level_name = "Fase 9: Cidade"
	next_level = "res://scenes/level_10.tscn"


func _paint_map(g: Array) -> void:
	paint(g, 7, 18, 11, 19, "#")    # chão de partida
	paint(g, 12, 18, 32, 19, "~")   # rio largo
	paint(g, 28, 10, 32, 11, "#")   # beirada do graveto


func _ready() -> void:
	super._ready()
	for i in 4:
		var ad := AdWindow.new()
		ad.title = "Parabéns!!!"
		ad.size = AD_SIZE
		_register_window(ad)
		ad.visible = false
		_ads.append(ad)


func _process(delta: float) -> void:
	super._process(delta)
	if _won or _restarting:
		return
	_next_ad -= delta
	if _next_ad > 0.0:
		return
	_next_ad = AD_EVERY
	var free := _ads.filter(func(a: AdWindow) -> bool: return not a.visible)
	if free.is_empty():
		return
	# um lugar livre: sem outro anúncio aberto e sem cair em cima do bicudinho
	var spots := AD_SPOTS.duplicate()
	spots.shuffle()
	for spot: Vector2 in spots:
		var r := Rect2(spot, AD_SIZE + Vector2(0, MiniWindow.TITLE_H))
		if r.grow(4.0).intersects(bird.box_rect()):
			continue
		var taken := false
		for a in _ads:
			if a.visible and a.outer_rect().intersects(r):
				taken = true
		if taken:
			continue
		var ad: AdWindow = free[0]
		ad.show_ad(spot, AD_LIFE, HEADLINES.pick_random())
		_raise(ad)
		Audio.play("sfx_window_open")
		return
