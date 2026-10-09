class_name DeskIcon
extends Node2D
## Ícone do desktop falso. Fora da janela é só um ícone de desktop; dentro dela vira
## plataforma ou parede (colisão sólida). Regra de ouro: os tipos `hide_outside` (saída,
## vírus e app) nem aparecem fora da janela.
##
## O tamanho (Tuning.ICON_SIZE) vale para tudo: desenho, colisão, clique e regras de largar.
##
## Tipos: folder, file, image (arrastáveis), app (fixo), virus (some se for cortado),
## brejo (a saída da fase), notepad, viewer, help.

const COLORS := {
	"folder": Color("f2c14e"),
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
var draggable := true
var solid := true           # o bicudinho colide quando está dentro da janela
var hide_outside := false   # some quando não está inteiro dentro da janela
var inside := false         # está inteiro dentro da janela agora
var dragging := false
var show_art := true        # false: o ícone vale (colisão, regra de ouro) mas não se desenha

var _shape: CollisionShape2D
var _tex: Texture2D = null
var _time := 0.0
var _was_inside := false
var _art_shift_y := 0.0     # sobe a arte pela margem transparente do topo do PNG


func setup(icon_type: String, pos: Vector2, can_drag: bool) -> void:
	type = icon_type
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
	body.add_child(_shape)
	add_child(body)


## "notepad" se o duplo clique abre o bloco de notas, senão "".
## (viewer e help abrem a mini-janela de imagem no passo 5.)
func opens() -> String:
	if type == "notepad":
		return "notepad"
	return ""


func rect() -> Rect2:
	return Rect2(position, Vector2(Tuning.ICON_SIZE, Tuning.ICON_SIZE))


## Chamado quando a janela muda ou o ícone é largado: liga ou desliga a colisão e a
## visibilidade conforme o ícone esteja inteiro dentro da janela.
func update_inside(interior: Rect2) -> void:
	inside = interior.encloses(rect()) and not dragging
	_shape.set_deferred("disabled", not (inside and solid))
	var was_visible := visible
	visible = inside or dragging or not hide_outside
	if type == "virus" and _was_inside and was_visible and not visible:
		Audio.play("sfx_icon_vanish")  # some em silêncio até o som existir
	_was_inside = inside


func _process(delta: float) -> void:
	_time += delta
	if type == "brejo" and visible and show_art:
		queue_redraw()  # o brilho pulsa


func _draw() -> void:
	if not show_art:
		return
	var s := Tuning.ICON_SIZE
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
