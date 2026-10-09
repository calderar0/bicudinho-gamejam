class_name DeskIcon
extends Node2D
## Ícone do desktop falso. Fora da janela é só um ícone de desktop; dentro dela vira
## plataforma ou parede (colisão sólida). Regra de ouro: os tipos `hide_outside` (saída,
## vírus e app) nem aparecem fora da janela.
##
## O tamanho (Tuning.ICON_SIZE) vale para tudo: desenho, colisão, clique e regras de largar.
##
## Tipos: folder, trash (lixeira), image (foto), file, app, virus, notepad, viewer, help e
## brejo (o objetivo da fase). Duplo clique abre o que o ícone guarda:
##   notepad            -> o bloco de notas da fase
##   com `contents`     -> uma janela de pasta com os arquivos de dentro (folder, trash...)
##   com `file_data`    -> o arquivo direto (uma foto ou um texto)

const COLORS := {
	"folder": Color("f2c14e"),
	"trash": Color("9aa0aa"),
	"file": Color("f4f4ee"),
	"image": Color("5aa9e6"),
	"app": Color("8a8d99"),
	"virus": Color("d9534f"),
	"brejo": Color("4caf6a"),
	"notepad": Color("f6e7b0"),
	"viewer": Color("7fd6d0"),
	"help": Color("b58ee0"),
}

var type := "folder"
var label := ""             # nome embaixo do ícone enquanto está fora da janela
var draggable := true
var solid := true           # o bicudinho colide quando está dentro da janela
var hide_outside := false   # some quando não está inteiro dentro da janela
var inside := false         # está inteiro dentro da janela agora
var dragging := false
var show_art := true        # false: o ícone vale (colisão, regra de ouro) mas não se desenha
## Escondido atrás da janela do jogo: não é do mundo (não colide), não dá para clicar e só
## aparece o pedaço que a janela não cobre. Quando a janela sai de cima dele por inteiro,
## vira um ícone normal do desktop ("behind": true em icons_data).
var behind := false
## Só do desktop (a pasta de gravetos): nunca é chão nem entra no mundo. Se a janela passar
## por cima, fica atrás dela (como "behind"), e volta a ser clicável quando descoberta.
var desktop_only := false
## .exe falso: o duplo clique abre esta cena (uma fase).
var launch := ""
## Ícone só do desktop: a fase pode escondê-lo (os .exe aparecem só com a janela minimizada).
var shown := true
var _cover := Rect2()       # a janela inteira (com moldura), enquanto está atrás dela
## Pasta: true se abre uma janela (mesmo vazia). `contents` são os arquivos de dentro.
var is_container := false
var contents: Array = []
## Arquivo direto: {"kind": "image", "name", "photo", "caption", "credit"} ou {"kind": "text", ...}.
var file_data: Dictionary = {}

var _shape: CollisionShape2D
var _tex: Texture2D = null
var _time := 0.0
var _was_inside := false
var _art_shift_y := 0.0     # sobe a arte pela margem transparente do topo do PNG


func setup(icon_type: String, pos: Vector2, can_drag: bool, icon_label := "") -> void:
	type = icon_type
	label = icon_label
	position = pos
	draggable = can_drag
	solid = type != "brejo"
	hide_outside = type in ["brejo", "app", "virus"]

	var path := "res://art/icon_%s.png" % type
	if ResourceLoader.exists(path):
		_tex = load(path) as Texture2D
		if Tuning.ICON_ART_ALIGN_TOP:
			var used := _tex.get_image().get_used_rect()  # parte do PNG que não é transparente
			_art_shift_y = -float(used.position.y) * Tuning.ICON_SIZE / float(_tex.get_height())

	var body := StaticBody2D.new()
	body.collision_layer = 1   # mundo
	body.collision_mask = 0
	_shape = CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(Tuning.ICON_SIZE, Tuning.ICON_SIZE)
	_shape.shape = rs
	_shape.position = Vector2(Tuning.ICON_SIZE, Tuning.ICON_SIZE) / 2.0
	_shape.disabled = true  # só vira chão quando update_inside diz que está dentro da janela
	body.add_child(_shape)
	add_child(body)


## O que o duplo clique abre: "notepad", "folder", "file", ou "" se não abre nada.
func opens() -> String:
	if launch != "":
		return "launch"
	if type == "notepad":
		return "notepad"
	if is_container:
		return "folder"
	if not file_data.is_empty():
		return "file"
	return ""


func rect() -> Rect2:
	return Rect2(position, Vector2(Tuning.ICON_SIZE, Tuning.ICON_SIZE))


## Chamado quando a janela muda ou o ícone é largado: liga ou desliga a colisão e a
## visibilidade conforme o ícone esteja inteiro dentro da janela.
func update_inside(interior: Rect2) -> void:
	if desktop_only:
		var gt := Tuning.GLASS_THICKNESS
		_cover = Rect2(interior.position - Vector2(gt, Tuning.TITLEBAR_H),
			interior.size + Vector2(gt * 2.0, gt + Tuning.TITLEBAR_H))
		behind = _cover.intersects(rect()) and not dragging
		inside = false
		_shape.set_deferred("disabled", true)
		visible = shown
		queue_redraw()
		return
	if behind:
		var g := Tuning.GLASS_THICKNESS
		var t := Tuning.TITLEBAR_H
		_cover = Rect2(interior.position - Vector2(g, t), interior.size + Vector2(g * 2.0, g + t))
		if _cover.intersects(rect()):
			inside = false
			_shape.set_deferred("disabled", true)
			visible = true
			queue_redraw()
			return
		behind = false  # a janela saiu de cima: agora é um ícone do desktop como os outros
	inside = interior.encloses(rect()) and not dragging
	_shape.set_deferred("disabled", not (inside and solid))
	var was_visible := visible
	visible = inside or dragging or not hide_outside
	if type == "virus" and _was_inside and was_visible and not visible:
		Audio.play("sfx_icon_vanish")  # some em silêncio até o som existir
	_was_inside = inside
	queue_redraw()  # o nome só aparece fora da janela e quando não está na mão


func _process(delta: float) -> void:
	_time += delta
	if type == "brejo" and visible and show_art:
		queue_redraw()  # o brilho pulsa


func _draw() -> void:
	if not show_art:
		return
	var s := Tuning.ICON_SIZE
	if behind:
		_draw_peek(s)
		return
	if _tex != null:
		draw_texture_rect(_tex, Rect2(0, _art_shift_y, s, s), false)
	else:
		var c: Color = COLORS.get(type, Color.WHITE)
		if not draggable and type != "brejo":
			c = c.darkened(0.15)
		draw_rect(Rect2(0, 0, s, s), c.darkened(0.45))
		draw_rect(Rect2(1, 1, s - 2.0, s - 2.0), c)
		if type == "folder":
			draw_rect(Rect2(2, 2, s * 0.45, 4), c.lightened(0.25))
		if draggable:
			draw_rect(Rect2(s - 5.0, s - 5.0, 3, 3), Color(1, 1, 1, 0.9))  # dá para arrastar
	if type == "brejo":
		var pulse := 0.5 + 0.5 * sin(_time * 4.0)
		draw_rect(Rect2(-1, -1, s + 2.0, s + 2.0), Color(1, 1, 0.6, 0.35 + 0.4 * pulse), false, 1.0)
	if label != "" and not inside and not dragging:
		_draw_label()


## Nome embaixo do ícone, como num desktop de verdade.
func _draw_label() -> void:
	var font := ThemeDB.fallback_font
	var at := Vector2(Tuning.ICON_SIZE / 2.0 - 32.0, Tuning.ICON_SIZE + 9.0)
	draw_string(font, at + Vector2(1, 1), label, HORIZONTAL_ALIGNMENT_CENTER, 64, 8, Color(0, 0, 0, 0.6))
	draw_string(font, at, label, HORIZONTAL_ALIGNMENT_CENTER, 64, 8, Color("f2f1ed"))


## Atrás da janela: desenha só a faixa do ícone que a janela não cobre (o maior pedaço que
## sobra à esquerda, à direita, em cima ou embaixo dela).
func _draw_peek(s: float) -> void:
	var c := Rect2(_cover.position - position, _cover.size)   # a janela, em coordenadas locais
	var strips: Array[Rect2] = [
		Rect2(0, 0, clampf(c.position.x, 0.0, s), s),
		Rect2(clampf(c.end.x, 0.0, s), 0, s - clampf(c.end.x, 0.0, s), s),
		Rect2(0, 0, s, clampf(c.position.y, 0.0, s)),
		Rect2(0, clampf(c.end.y, 0.0, s), s, s - clampf(c.end.y, 0.0, s)),
	]
	var best := Rect2()
	for r in strips:
		if r.get_area() > best.get_area():
			best = r
	if not best.has_area():
		return
	if _tex != null:
		var k := _tex.get_size() / s
		var art := Rect2(best.position - Vector2(0, _art_shift_y), best.size)  # a arte sobe pelo topo vazio
		draw_texture_rect_region(_tex, best, Rect2(art.position * k, art.size * k))
	else:
		draw_rect(best, COLORS.get(type, Color.WHITE))
