class_name PhotoWindow
extends MiniWindow
## Visualizador de foto: mostra uma imagem de res://art/photos/<nome>.jpg (ou .png, .webp)
## com legenda e crédito do autor. Fotos grandes são reduzidas para caber (uma vez, ao abrir).
## Se o arquivo não existe, mostra um quadro cinza com o nome que está faltando.

const PHOTO_DIR := "res://art/photos/"
const PHOTO_EXTS: Array[String] = ["jpg", "jpeg", "png", "webp"]
const MAX_PHOTO := Vector2(240, 150)       # a foto nunca passa disto (só reduz, não amplia)
const MIN_WIDTH := 150.0
const PLACEHOLDER_SIZE := Vector2(200, 120)
const CAPTION_COLOR := Color("2b2b3a")
const CREDIT_COLOR := Color("6a6a7a")

var _photo: Texture2D = null
var _photo_name := ""
var _photo_size := Vector2.ZERO
var _caption := ""
var _credit := ""
var _width := MIN_WIDTH
var _caption_h := 0.0
var _credit_h := 0.0


## Mostra uma foto. Chame depois de pôr a janela na cena; ela redimensiona sozinha.
func show_photo(photo_name: String, caption: String, credit: String, window_title: String) -> void:
	title = window_title
	_photo_name = photo_name
	_caption = caption
	_credit = credit
	_photo = _load_photo(photo_name)
	_photo_size = _photo.get_size() if _photo != null else PLACEHOLDER_SIZE
	_width = maxf(_photo_size.x, MIN_WIDTH)
	var font := ThemeDB.fallback_font
	_caption_h = 0.0
	_credit_h = 0.0
	if caption != "":
		_caption_h = font.get_multiline_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, _width, 8).y
	if credit != "":
		_credit_h = font.get_multiline_string_size(credit, HORIZONTAL_ALIGNMENT_LEFT, _width, 8).y
	var text_h := _caption_h + _credit_h
	if caption != "" and credit != "":
		text_h += 3.0
	size = Vector2(_width + PAD * 2.0, PAD + _photo_size.y + (6.0 + text_h if text_h > 0.0 else 0.0) + PAD)
	queue_redraw()


## Carrega a foto e já a reduz ao tamanho final, para não ficar serrilhada na tela.
func _load_photo(photo_name: String) -> Texture2D:
	for ext: String in PHOTO_EXTS:
		var path := "%s%s.%s" % [PHOTO_DIR, photo_name, ext]
		if not ResourceLoader.exists(path):
			continue
		var tex := load(path) as Texture2D
		if tex == null:
			return null
		var img := tex.get_image()
		if img == null:
			return tex
		if img.is_compressed():
			img.decompress()
		var s := minf(1.0, minf(MAX_PHOTO.x / img.get_width(), MAX_PHOTO.y / img.get_height()))
		if s < 1.0:
			img.resize(maxi(1, roundi(img.get_width() * s)), maxi(1, roundi(img.get_height() * s)),
				Image.INTERPOLATE_LANCZOS)
		return ImageTexture.create_from_image(img)
	return null


func _draw() -> void:
	super._draw()  # moldura, barra de título e botão de fechar da MiniWindow
	var font := ThemeDB.fallback_font
	var x0 := PAD + roundf((_width - _photo_size.x) / 2.0)
	var y0 := TITLE_H + PAD
	if _photo != null:
		draw_texture(_photo, Vector2(x0, y0))
		draw_rect(Rect2(x0 - 1.0, y0 - 1.0, _photo_size.x + 2.0, _photo_size.y + 2.0),
			Color("1c2033"), false, 1.0)
	else:
		draw_rect(Rect2(x0, y0, _photo_size.x, _photo_size.y), Color("c9cbd8"))
		draw_string(font, Vector2(x0, y0 + _photo_size.y / 2.0 - 2.0), "foto não encontrada",
			HORIZONTAL_ALIGNMENT_CENTER, _photo_size.x, 8, CAPTION_COLOR)
		draw_string(font, Vector2(x0, y0 + _photo_size.y / 2.0 + 10.0), _photo_name,
			HORIZONTAL_ALIGNMENT_CENTER, _photo_size.x, 8, CREDIT_COLOR)
	var ty := y0 + _photo_size.y + 6.0
	if _caption != "":
		draw_multiline_string(font, Vector2(PAD, ty + 8.0), _caption,
			HORIZONTAL_ALIGNMENT_LEFT, _width, 8, -1, CAPTION_COLOR)
		ty += _caption_h + 3.0
	if _credit != "":
		draw_multiline_string(font, Vector2(PAD, ty + 8.0), _credit,
			HORIZONTAL_ALIGNMENT_LEFT, _width, 8, -1, CREDIT_COLOR)
