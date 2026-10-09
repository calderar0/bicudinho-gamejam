class_name FolderWindow
extends MiniWindow
## Janela de pasta: lista os arquivos de dentro como ícones com nome. Um clique seleciona e
## o duplo clique abre o arquivo: o pai escuta o sinal `file_opened` e abre o visualizador.
##
## Cada arquivo é um dicionário: {"kind": "image" ou "text", "name": "rio_01.jpg", ...} com
## os dados que o visualizador precisa ("photo", "caption", "credit" ou "text").

signal file_opened(file: Dictionary)

const CELL := Vector2(64, 64)   # ícone + nome em até 2 linhas
const ICON := 32.0
const MAX_COLS := 4
const MIN_WIDTH := 130.0
const DOUBLE_CLICK_MS := 400
const SELECT_COLOR := Color("3a4a8a")
const LABEL_COLOR := Color("2b2b3a")

var files: Array = []

var _cols := 1
var _selected := -1
var _last_click_ms := 0
var _icon_cache: Dictionary = {}


## Define o nome da pasta e o que tem dentro, e ajusta o tamanho da janela.
func setup_files(folder_title: String, file_list: Array) -> void:
	title = folder_title
	files = file_list
	var n := files.size()
	_cols = clampi(n, 1, MAX_COLS)
	var rows := maxi(1, ceili(float(n) / float(_cols)))
	size = Vector2(maxf(_cols * CELL.x + PAD * 2.0, MIN_WIDTH), rows * CELL.y + PAD * 2.0)
	_selected = -1
	queue_redraw()


func open() -> void:
	_selected = -1
	super.open()


## Retângulo do arquivo i, em coordenadas da janela (para desenhar).
func _local_rect(i: int) -> Rect2:
	return Rect2(
		PAD + (i % _cols) * CELL.x,
		TITLE_H + PAD + floorf(float(i) / float(_cols)) * CELL.y,
		CELL.x, CELL.y)


## Arquivo sob o ponto p (coordenadas do desktop), ou -1.
func _file_at(p: Vector2) -> int:
	for i in files.size():
		var r := _local_rect(i)
		r.position += position
		if r.has_point(p):
			return i
	return -1


func handle_press(p: Vector2) -> bool:
	if not visible or not outer_rect().has_point(p):
		return false
	var i := _file_at(p)
	if i != -1 and not _close_rect().has_point(p):
		var now := Time.get_ticks_msec()
		if i == _selected and now - _last_click_ms <= DOUBLE_CLICK_MS:
			_last_click_ms = 0
			file_opened.emit(files[i])
		else:
			_selected = i
			_last_click_ms = now
		queue_redraw()
		return true
	_selected = -1  # clicou na barra ou no fundo: tira a seleção
	return super.handle_press(p)


func _icon_tex(kind: String) -> Texture2D:
	var art := "icon_image" if kind == "image" else "icon_file"
	if _icon_cache.has(art):
		return _icon_cache[art]
	var path := "res://art/%s.png" % art
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path) as Texture2D
	_icon_cache[art] = t
	return t


func _draw() -> void:
	super._draw()  # moldura, barra de título e botão de fechar da MiniWindow
	var font := ThemeDB.fallback_font
	if files.is_empty():
		draw_string(font, Vector2(PAD, TITLE_H + PAD + 20.0), "(pasta vazia)",
			HORIZONTAL_ALIGNMENT_LEFT, size.x - PAD * 2.0, 8, Color("6a6a7a"))
		return
	for i in files.size():
		var f: Dictionary = files[i]
		var r := _local_rect(i)
		var selected := i == _selected
		if selected:
			draw_rect(Rect2(r.position + Vector2(2, 0), r.size - Vector2(4, 2)), SELECT_COLOR)
		var tex := _icon_tex(str(f.get("kind", "image")))
		var at := r.position + Vector2((CELL.x - ICON) / 2.0, 2.0)
		if tex != null:
			draw_texture_rect(tex, Rect2(at, Vector2(ICON, ICON)), false)
		else:
			draw_rect(Rect2(at, Vector2(ICON, ICON)), Color("8a8d99"))
		# nome em até 2 linhas, quebrando no meio da palavra se precisar (nomes_com_underline)
		draw_multiline_string(font, r.position + Vector2(2, 45), str(f.get("name", "arquivo")),
			HORIZONTAL_ALIGNMENT_CENTER, CELL.x - 4.0, 8, 2, Color.WHITE if selected else LABEL_COLOR,
			TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_GRAPHEME_BOUND)
