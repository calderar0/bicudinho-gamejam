class_name LevelBase
extends Node2D
## Base de todas as fases. Monta o desktop falso, a janela com vidro, o mapa, os ícones
## arrastáveis, o bicudinho, o objetivo (a bicudinha), as janelas de pasta e de foto, a
## vitória, a morte e o mouse.
##
## COMO CRIAR UMA FASE NOVA
##   1. Crie scripts/fase_0N.gd com `extends LevelBase` e escreva só dois métodos:
##        func _setup_level() -> void:   # os dados da fase (veja a lista abaixo)
##        func _paint_map(g: Array) -> void:   # o mapa, com paint(g, x0, y0, x1, y1, "#")
##   2. Crie scenes/level_0N.tscn: um Node2D com esse script no nó raiz.
##   3. Na fase anterior, ponha `next_level = "res://scenes/level_0N.tscn"`.
## Não escreva _ready() na fase (se precisar, chame super._ready() primeiro).
##
## Legenda do mapa (40x21 tiles de 16 px): #  chão   =  plataforma fina   ~  rio   .  vazio
## Regra de ouro: só existe o que está dentro da janela (tiles, ícones, objetivo, bicudinha).

const COLS := 40
const ROWS := 21
const BICUDINHO_SCENE := preload("res://scenes/bicudinho.tscn")
const TASKBAR_TEX := preload("res://art/ui/taskbar.png")
const WALLPAPER_TEX := preload("res://art/ui/wallpaper.png")   # 640x360, a tela toda
const WIN_RESTART_TIME := 2.2   # segundos entre chegar no objetivo e ir para a próxima fase
                                # (dá tempo de ver o graveto voar até a pasta)
## Barra de tarefas: um botão por janela aberta (o jogo e as mini-janelas), com ícone.
const TASK_X := 26.0
const TASK_W := 104.0
const TASK_ICON_PATHS := {
	"game": "res://art/icon_brejo.png", "notepad": "res://art/icon_notepad.png",
	"folder": "res://art/icon_folder.png", "photo": "res://art/icon_viewer.png",
	"ad": "res://art/icon_virus.png", "text": "res://art/icon_file.png",
}

# --- Dados da fase: a fase preenche estes campos em _setup_level() -----------------

## Área interna da janela, em px do desktop. Deixe uma margem de pelo menos
## Tuning.ICON_SIZE + 3 px nos lados onde ficam ícones, senão não dá para largá-los ali.
var window_rect := Rect2(32, 48, 576, 272)
## Tamanho mínimo e máximo da janela. Zero = igual ao window_rect (janela fixa).
var window_min := Vector2.ZERO
var window_max := Vector2.ZERO
## Onde o bicudinho nasce: os pés (o centro da base dele).
var bird_start := Vector2(72, 288)
## Onde fica o objetivo: o centro da base dele, o "chão" em que ele está.
var exit_feet := Vector2(560, 288)
## O que espera na saída:
##   "twig" (o padrão): um graveto. Ele pega e segue para a próxima fase, sem festa.
##   "female": a bicudinha, com os dois felizes (só na última fase).
##   "brejo": o ícone do brejo.
var goal := "twig"
## O ninho final (art/nest.png) atrás da saída: a fase da bicudinha e os créditos.
var with_nest := false
var nest: Nest
## Ícones do desktop (x e y são px do canto superior esquerdo). Cada um é um dicionário:
##   {"type": "folder", "x": 0, "y": 64, "draggable": true, "label": "nome"}
## Tipos: folder, trash, image, file, app, virus, notepad, viewer, help.
## "behind": true -> começa escondido atrás da janela do jogo: não faz parte do mundo, não
## dá para clicar e só aparece o pedaço que a janela não cobre. Quando a janela sai de cima
## dele por inteiro (encolhendo), vira um ícone comum do desktop.
## Duplo clique abre o que o ícone guarda (todos os campos abaixo são opcionais):
##   "contents": [ arquivos ]  -> abre uma janela de pasta com esses arquivos (pode ser [])
##   "photo": "nome"           -> abre uma foto direto (veja arquivos de foto abaixo)
##   "text": "conteúdo"        -> abre um texto direto
## Um arquivo (dentro de "contents") é {"kind": "image", "name": "rio_01.jpg", "photo":
## "rio_01", "caption": "legenda", "credit": "Foto: autor (licença)"} ou
## {"kind": "text", "name": "leia-me.txt", "text": "conteúdo"}.
## As fotos ficam em res://art/photos/<photo>.jpg (ou .png, .webp): reduza antes para no
## máximo uns 480x300 px, para o jogo web não pesar.
var icons_data: Array = []
## Bloco de notas da fase ("" = sem). Abre sozinho se note_open_at_start; para poder abrir de
## novo, ponha um ícone {"type": "notepad", "label": "dica.txt", "draggable": false}.
var note_text := ""
var note_title := "dica.txt"
var note_pos := Vector2(8, 216)
var note_size := Vector2(136, 60)
var note_open_at_start := true
## Nome da fase, na barra de título da janela (antes das penas). Ex.: "Fase 3: Estica".
var level_name := ""
## Antigo texto da barra de tarefas. Não aparece mais: a barra mostra as janelas abertas.
var hint := ""
## Vazio: o texto padrão do objetivo ("Pegou um graveto!" ou "Achou a bicudinha!").
var win_text := ""
## Próxima fase (caminho da cena). Vazio: recomeça esta (ainda não existe a próxima).
var next_level := ""
## A saída que foge: lista de lugares (os pés, como exit_feet) para onde ela pula quando o
## bicudinho chega perto. Ela só vai para um lugar que não esteja inteiro dentro da janela;
## se a janela cobrir todos, ela não tem para onde ir. Vazio = a saída fica parada.
var exit_spots: Array = []
## A base da janela subindo rápido lança o bicudinho (trampolim).
var bottom_launch := false
## O bicudinho anda sozinho e o teclado não faz nada: só o mouse (fase da bicudinha).
var auto_walk := false
## A janela do jogo está travada ("Não respondendo"): só ícones e mini-janelas mexem.
var window_frozen := false
var wallpaper_color := Color("4d8f66")
## Tom aplicado por cima do papel de parede (branco = a imagem como ela é).
var wallpaper_tint := Color.WHITE
var sky_color := Color("a4d8ea")

# --- Estado -------------------------------------------------------------------------

var win: GameWindow
var tiles: TileWorld
var bird: Bicudinho
var icons: Array[DeskIcon] = []
var panes: Array[GlassPane] = []
var exit_icon: DeskIcon
var female: Female
var twig: Twig

var _restarting := false
var _won := false
var _won_time := 0.0   # segundos desde a vitória (o texto entra com um pulinho)
var _drag_icon: DeskIcon = null
var _drag_offset := Vector2.ZERO
var _drag_origin := Vector2.ZERO
var _start_menu: StartMenu
var _overlay: Node2D   # desenha a sombra de onde o ícone vai cair
## Janelas de interface (bloco de notas, pastas, foto, texto). A última está por cima.
var _windows: Array[MiniWindow] = []
## Mini-janela em que o bicudinho pisou por último (ele desenha logo acima dela), ou null.
var _bird_window: MiniWindow = null
var _notepad: MiniWindow = null
var _viewer: PhotoWindow = null
var _text_window: MiniWindow = null
var _folder_windows: Dictionary = {}   # DeskIcon -> FolderWindow
var _task_icons: Dictionary = {}
var _cursor_shape := -1

# --- Coleção de gravetos: uma foto por fase vencida, na pasta "gravetos" do desktop ------

## Número da fase -> [pedaço do nome do arquivo, nome da fase]. A foto é art/photos/graveto_NN.
const TWIG_NAMES := {
	1: ["brejo", "Fase 1: Brejo"], 2: ["arrasta", "Fase 2: Arrasta"], 3: ["estica", "Fase 3: Estica"],
	4: ["corta", "Fase 4: Corta"], 5: ["esconde", "Fase 5: Esconde"], 6: ["notas", "Fase 6: Notas"],
	7: ["enquadra", "Fase 7: Enquadra"], 8: ["trampolim", "Fase 8: Trampolim"],
	9: ["cidade", "Fase 9: Cidade"], 10: ["copia", "Fase 10: Cópia"], 11: ["noite", "Fase 11: Noite"],
}
## Onde fica a pasta de gravetos. Zero = acha sozinho um canto livre do desktop.
var twig_folder_pos := Vector2.ZERO
## Onde ficam as pastas "fotos" e "trabalho" ({"fotos": Vector2(...)}); sem = acha sozinho.
var desktop_folder_pos := {}
## A pasta "fotos": as fotos do começo do jogo.
const PHOTOS_FILES := [
	{"kind": "image", "name": "rio_01.jpg", "photo": "rio_01", "caption": "O rio Tietê, onde tudo começa."},
	{"kind": "image", "name": "rio_02.jpg", "photo": "rio_02", "caption": "O Tietê mais adiante."},
	{"kind": "image", "name": "brejo_01.jpg", "photo": "brejo_01", "caption": "O brejo limpo: o lar do bicudinho."},
	{"kind": "image", "name": "lixo_01.jpg", "photo": "lixo_01", "caption": "Lixo no rio: o que sobra da cidade."},
	{"kind": "image", "name": "bicudinho.jpg", "photo": "bicudinho_01", "caption": "O bicudinho-do-brejo-paulista."},
]
## A pasta "créditos": quem fez o jogo e o material de terceiros (veja CREDITS.md).
const CREDIT_FILES := [
	{"kind": "text", "name": "equipe.txt", "text": "Bicudinho, feito para a GameRex 2026.\n\nLetícia Akemi Ikemoto\nArte e Game Design\n\nFelipe Calderaro\nProgramação e Game Design\n\nBianca Valenciani\nEfeitos Sonoros e Game Design"},
	{"kind": "text", "name": "terceiros.txt", "text": "Arte da interface: DampSquib (Computer Icons Asset Pack).\n\nSons: matthewvakaliuk73627, 47313572 e soundshelfstudio (Pixabay); Tuudurt (CC0); heyheytheree (CC BY 4.0).\n\nMúsica: hmmm101, Pixel Song #10 (CC0).\n\nInteligência artificial: usamos IA (Claude, da Anthropic) para ajudar no código. Na arte, só o fundo e as plataformas das fases foram feitos com IA."},
]
## Os textos sobre o bicudinho: cada um fica solto no desktop de uma fase (loose_doc) e,
## lido uma vez, entra na pasta "trabalho" de todas as fases (fica salvo).
const DOCS := {
	"bicudinho": {"kind": "text", "name": "bicudinho.txt", "text": "Bicudinho-do-brejo-paulista\n(Formicivora paludicola)\n\nUm passarinho pequeno que só existe no estado de São Paulo. Foi descrito pela ciência em 2013.\n\nVive em brejos com taboa, nas várzeas do alto rio Tietê e do rio Paraíba do Sul, perto da cidade.\n\nEstá criticamente ameaçado de extinção: os brejos somem com aterros, represas, queimadas e o crescimento da cidade.\n\nCuidar dos brejos é cuidar dele."},
	"ninho": {"kind": "text", "name": "ninho.txt", "text": "Por que gravetos?\n\nO bicudinho está montando um ninho para a bicudinha. Cada graveto que ele pega no fim de uma fase vai para a pasta \"gravetos\".\n\nO caminho é longo: começa no brejo limpo e vai seguindo o Tietê até a cidade, onde o rio fica sujo e tudo é vidro e barulho.\n\nQuando o ninho estiver pronto, ele vai atrás dela."},
	"diario": {"kind": "text", "name": "diario.txt", "text": "Diário do bicudinho\n\nDia 1. Achei o primeiro graveto perto de casa. O brejo cheira a chuva.\n\nDia 3. A janela era pequena demais. Esticando, o mundo apareceu: ele já estava lá.\n\nDia 9. A cidade não para de piscar \"VOCÊ GANHOU!\". Eu só queria um graveto.\n\nDia 11. Noite. Alguém lá fora acendeu uma luz para mim. Obrigado."},
	"nome": {"kind": "text", "name": "nome.txt", "text": "O que quer dizer o nome?\n\nFormicivora: \"que come formigas\". É o grupo dos papa-formigas.\n\npaludicola: \"que mora no pântano\", ou seja, no brejo.\n\nE \"bicudinho\" é o jeito carinhoso de chamar um passarinho pequeno, de bico fino."},
	"comida": {"kind": "text", "name": "comida.txt", "text": "O que ele come\n\nInsetos e outros bichinhos pequenos, como aranhas, que ele procura no meio da taboa e do capim do brejo.\n\nEle costuma ficar escondido na vegetação do brejo, por isso é difícil de ver."},
	"como_ajudar": {"kind": "text", "name": "como_ajudar.txt", "text": "Como ajudar o bicudinho\n\n- Não jogue lixo nos rios e córregos.\n- Brejo não é terreno vazio: não aterre nem drene.\n- Fogo no mato destrói o brejo: nada de queimadas.\n- Apoie quem protege as várzeas do Tietê.\n\nSem brejo, não tem bicudinho."},
}
## Ordem dos textos dentro da pasta.
const DOC_ORDER := ["bicudinho", "ninho", "nome", "comida", "como_ajudar", "diario"]
var twig_folder: DeskIcon
var work_folder: DeskIcon
## O texto solto no desktop desta fase (uma chave de DOCS), ou "" para nenhum.
var loose_doc := ""
## A janela do jogo está minimizada: o mundo some e só fica o desktop.
var _minimized := false
## Nós do mundo que somem ao minimizar (a fase pode acrescentar os seus, como a ponte).
var world_nodes: Array[Node] = []
const HUB_SCENE := "res://scenes/desktop.tscn"
## "Janela" longe da tela: usada para atualizar os ícones do desktop com a janela minimizada.
const NO_WINDOW := Rect2(-9999, -9999, 0, 0)
## O desktop principal (os .exe das fases): sem janela do jogo, nem botão dela na barra.
var is_hub := false
## Trava todos os ícones da fase no lugar (só nos créditos, onde a ponte de nomes é a cena).
var lock_icons := false
## Os .exe das fases liberadas: no desktop principal sempre; nas fases, só minimizado.
var exe_icons: Array[DeskIcon] = []
const EXES := {
	1: "1 brejo.exe", 2: "2 arrasta.exe", 3: "3 estica.exe", 4: "4 corta.exe",
	5: "5 esconde.exe", 6: "6 notas.exe", 7: "7 enquadra.exe", 8: "8 trampolim.exe",
	9: "9 cidade.exe", 10: "10 copia.exe", 11: "11 noite.exe", 12: "12 bicudinha.exe",
}


## A fase sobrescreve: preenche os campos acima.
func _setup_level() -> void:
	pass


## A fase sobrescreve: pinta o mapa com paint(g, x0, y0, x1, y1, "#").
func _paint_map(_g: Array) -> void:
	pass


func _ready() -> void:
	_setup_level()
	if window_min == Vector2.ZERO:
		window_min = window_rect.size
	if window_max == Vector2.ZERO:
		window_max = window_rect.size

	win = GameWindow.new()
	win.process_physics_priority = -10  # a janela se move antes do bicudinho
	win.setup(window_rect, window_min, window_max)
	win.frozen = window_frozen
	win.title_text = level_name
	for k in TASK_ICON_PATHS:
		if ResourceLoader.exists(TASK_ICON_PATHS[k]):
			_task_icons[k] = load(TASK_ICON_PATHS[k])

	tiles = TileWorld.new()
	tiles.setup(_build_map())
	add_child(tiles)

	for spot in tiles.glass_spots:
		var pane := GlassPane.new()
		pane.position = spot
		add_child(pane)
		panes.append(pane)

	for entry: Dictionary in icons_data:
		_add_icon_from_data(entry)

	_add_desktop_folders()
	_add_loose_doc()
	_add_exe_icons()

	var s := Tuning.ICON_SIZE
	exit_icon = _add_icon("brejo", Vector2(exit_feet.x - s / 2.0, exit_feet.y - s), false, "brejo")
	# o graveto ou a bicudinha É o destino: a árvore não se desenha, mas o ícone continua
	# valendo (chegar nele vence, e some se a janela o cortar)
	if goal == "female":
		female = Female.new()
		female.position = exit_feet
		add_child(female)
		exit_icon.show_art = false
	elif goal == "twig":
		twig = Twig.new()
		twig.position = exit_feet
		add_child(twig)
		exit_icon.show_art = false

	if with_nest:
		nest = Nest.new()
		nest.position = exit_feet
		add_child(nest)
		if female != null:
			move_child(nest, female.get_index())   # atrás da bicudinha (e do bicudinho, que vem depois)
		exit_icon.show_art = false
		world_nodes.append(nest)

	bird = BICUDINHO_SCENE.instantiate() as Bicudinho
	bird.position = bird_start
	bird.auto_walk = auto_walk
	bird.launch_enabled = bottom_launch
	bird.hazard_check = Callable(tiles, "hazard_hit")
	bird.died.connect(_on_bird_died)
	bird.glass_hit.connect(win.add_crack)  # a batida no vidro desenha uma rachadura
	bird.lives_changed.connect(win.set_lives)  # penas na barra de título da janela
	win.set_lives(bird.lives)
	add_child(bird)
	if female != null:
		female.target = bird  # a bicudinha sempre encara o bicudinho

	add_child(win)  # a moldura e o vidro desenham por cima do mundo

	_overlay = Node2D.new()
	_overlay.z_index = 19  # acima do vidro, abaixo do ícone na mão (z 20)
	_overlay.draw.connect(_draw_drop_shadow)
	add_child(_overlay)

	_start_menu = StartMenu.new()
	add_child(_start_menu)  # o menu fica acima de tudo e pega o clique primeiro

	if note_text != "":
		_notepad = MiniWindow.new()
		_notepad.title = note_title
		_notepad.text = note_text
		_notepad.size = note_size
		_notepad.position = note_pos
		_register_window(_notepad)
		_notepad.visible = note_open_at_start

	win.rect_changed.connect(_on_rect_changed)
	win.hit_limit.connect(Audio.play.bind("sfx_window_limit"))
	win.button_pressed.connect(_on_window_button)
	world_nodes.append_array([tiles, bird, win])
	world_nodes.append_array(panes)
	if twig != null:
		world_nodes.append(twig)
	if female != null:
		world_nodes.append(female)
	_on_rect_changed()
	Audio.resume_music()  # a vitória para a música; ao recomeçar, ela volta


# --- Mapa ---------------------------------------------------------------------------

func _build_map() -> PackedStringArray:
	var g: Array = []
	for y in ROWS:
		var row: Array = []
		row.resize(COLS)
		row.fill(".")
		g.append(row)
	_paint_map(g)
	var rows := PackedStringArray()
	for row in g:
		rows.append("".join(row))
	return rows


## Pinta um retângulo de tiles (colunas x0..x1, linhas y0..y1, inclusive) com o caractere ch.
func paint(g: Array, x0: int, y0: int, x1: int, y1: int, ch: String) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			g[y][x] = ch


# --- Ícones -------------------------------------------------------------------------

func _add_icon(type: String, pos: Vector2, can_drag: bool, label := "") -> DeskIcon:
	var ic := DeskIcon.new()
	ic.setup(type, pos, can_drag, label)
	add_child(ic)
	icons.append(ic)
	return ic


## Cria um ícone a partir de uma entrada de icons_data (inclui o que ele abre).
func _add_icon_from_data(entry: Dictionary) -> void:
	var label := str(entry.get("label", ""))
	var ic := _add_icon(str(entry.type), Vector2(float(entry.x), float(entry.y)),
		not lock_icons, label)  # todo ícone pode ser movido (o "draggable" antigo não vale mais)
	ic.behind = bool(entry.get("behind", false))
	ic.launch = str(entry.get("launch", ""))
	if ic.launch != "":
		ic.hide_outside = false  # .exe de fase: sempre à vista no desktop, nunca vira chão
		ic.desktop_only = true
		ic.solid = false
	if entry.has("contents"):
		ic.is_container = true
		ic.contents = entry.contents
	elif entry.has("photo"):
		ic.file_data = {"kind": "image", "name": label, "photo": entry.photo,
			"caption": entry.get("caption", ""), "credit": entry.get("credit", "")}
	elif entry.has("text"):
		ic.file_data = {"kind": "text", "name": label, "text": entry.text}


func _on_rect_changed() -> void:
	tiles.set_interior(win.rect)
	for pane in panes:
		pane.update_inside(win.rect)
	if Tuning.ICON_PUSH_OUT:
		_push_icons_out()
	for ic in icons:
		ic.update_inside(win.rect)
	_refresh_exit()
	bird.enforce_inside(win.rect)
	queue_redraw()


## O objetivo segue a regra de ouro: dentro da janela é o graveto (ou a bicudinha); fora, o
## ícone do brejo no desktop, como pista de para onde ir.
func _refresh_exit() -> void:
	exit_icon.update_inside(win.rect)
	if female != null:
		female.visible = exit_icon.inside
	if twig != null:
		twig.visible = exit_icon.inside
	if nest != null:
		nest.visible = exit_icon.inside and not _minimized
	if goal != "brejo" or with_nest:
		exit_icon.hide_outside = false
		exit_icon.show_art = not exit_icon.inside
		exit_icon.visible = true
		exit_icon.queue_redraw()


## Muda a saída de lugar (pés em feet), levando junto o graveto ou a bicudinha.
func move_exit(feet: Vector2) -> void:
	exit_feet = feet
	var s := Tuning.ICON_SIZE
	exit_icon.position = Vector2(feet.x - s / 2.0, feet.y - s)
	if twig != null:
		twig.position = feet
	if female != null:
		female.position = feet
	_refresh_exit()


## A saída que foge: o bicudinho chegou perto? Ela pula para o próximo lugar da lista que não
## esteja inteiro dentro da janela. Se não houver nenhum, fica (foi cercada).
func _flee_exit() -> void:
	if exit_spots.is_empty() or not exit_icon.inside:
		return
	if not bird.box_rect().grow(Tuning.EXIT_FLEE_DIST).intersects(exit_icon.rect()):
		return
	var s := Tuning.ICON_SIZE
	var cur := exit_spots.find(exit_feet)
	for k in range(1, exit_spots.size() + 1):
		var spot: Vector2 = exit_spots[(cur + k) % exit_spots.size()]
		if spot == exit_feet:
			continue
		if not win.rect.encloses(Rect2(spot.x - s / 2.0, spot.y - s, s, s)):
			move_exit(spot)
			Audio.play("sfx_ui_hover", 0.0, -2.0)  # "pulou!"
			return


func _icon_at(m: Vector2) -> DeskIcon:
	for i in range(icons.size() - 1, -1, -1):
		var ic := icons[i]
		if ic.visible and not ic.behind and ic.rect().has_point(m):
			return ic
	return null


func _start_icon_drag(ic: DeskIcon, m: Vector2) -> void:
	_drag_icon = ic
	_drag_offset = m - ic.position
	_drag_origin = ic.position
	ic.dragging = true
	ic.z_index = 20  # acima do vidro enquanto está na mão
	ic.update_inside(win.rect)  # solta a colisão enquanto segura
	Audio.play("sfx_ui_click", 0.05, -6.0)


## Onde o ícone cairia: encaixado na grade de 16 px e dentro da tela.
func _snap_drop(pos: Vector2) -> Vector2:
	var s := Tuning.SNAP
	var max_x := floorf((Tuning.SCREEN_W - Tuning.ICON_SIZE) / s) * s
	var max_y := floorf((Tuning.SCREEN_H - Tuning.TASKBAR_H - Tuning.ICON_SIZE) / s) * s
	return Vector2(
		clampf(snappedf(pos.x, s), 0.0, max_x),
		clampf(snappedf(pos.y, s), 0.0, max_y))


func _end_icon_drag() -> void:
	var ic := _drag_icon
	_drag_icon = null
	var p := _snap_drop(ic.position)
	ic.dragging = false
	ic.z_index = 0
	if p == _drag_origin or _drop_valid(ic, p):
		ic.position = p
		Audio.play("sfx_ui_click", 0.05, -3.0)
	else:
		ic.position = _drag_origin  # lugar proibido: o ícone volta
		Audio.play("sfx_window_limit")
	ic.update_inside(win.rect)
	_overlay.queue_redraw()


## Não pode ser largado na borda da janela, sobre o bicudinho, dentro de terra, sobre o
## objetivo ou sobre outro ícone.
func _drop_valid(ic: DeskIcon, p: Vector2) -> bool:
	var r := Rect2(p, Vector2(Tuning.ICON_SIZE, Tuning.ICON_SIZE))
	if (_minimized or ic.desktop_only) and win.outer_rect().intersects(r):
		return false  # é o lugar da janela minimizada
	var fully_inside := win.rect.encloses(r)
	if not fully_inside and win.outer_rect().intersects(r):
		return false  # meio dentro, meio fora: na moldura da janela
	if fully_inside:
		if bird.box_rect().intersects(r) or r.intersects(exit_icon.rect()):
			return false
		if tiles.solid_overlaps(r):
			return false
		for pane in panes:
			if not pane.broken and pane.rect().intersects(r):
				return false
	for other in icons:
		if other != ic and other.rect().intersects(r):
			return false
	return true


## A janela não engole ícone: se uma borda passa por cima de um ícone arrastável (metade
## dentro, metade fora), ele é empurrado para fora, para o lado mais próximo que esteja livre.
## Ícones inteiros dentro ou inteiros fora não se mexem.
func _push_icons_out() -> void:
	var outer := win.outer_rect()
	var s := Tuning.ICON_SIZE
	for ic in icons:
		if not ic.draggable or ic.dragging or ic.behind or ic.desktop_only:
			continue  # escondido ou só do desktop: fica onde está (a janela passa por cima)
		var r := ic.rect()
		if win.rect.encloses(r) or not outer.intersects(r):
			continue
		var candidates: Array[Vector2] = [
			Vector2(outer.position.x - s, r.position.y),  # para a esquerda
			Vector2(outer.end.x, r.position.y),           # para a direita
			Vector2(r.position.x, outer.position.y - s),  # para cima
			Vector2(r.position.x, outer.end.y),           # para baixo
		]
		var best := Vector2.ZERO
		var best_dist := INF
		for c in candidates:
			if _spot_free(ic, c) and c.distance_to(ic.position) < best_dist:
				best = c
				best_dist = c.distance_to(ic.position)
		if best_dist < INF:
			ic.position = best


## O ícone cabe em p: dentro da área do desktop e sem encostar em outro ícone.
func _spot_free(ic: DeskIcon, p: Vector2) -> bool:
	var s := Tuning.ICON_SIZE
	var r := Rect2(p, Vector2(s, s))
	if r.position.x < 0.0 or r.position.y < 0.0 \
			or r.end.x > Tuning.SCREEN_W or r.end.y > Tuning.SCREEN_H - Tuning.TASKBAR_H:
		return false
	for other in icons:
		if other != ic and other.rect().intersects(r):
			return false
	return true


## A sombra de onde o ícone vai cair: verde pode largar, vermelho não.
func _draw_drop_shadow() -> void:
	if _drag_icon == null:
		return
	var p := _snap_drop(_drag_icon.position)
	var ok := p == _drag_origin or _drop_valid(_drag_icon, p)
	var shadow := Color(0.3, 1, 0.4, 0.45) if ok else Color(1, 0.3, 0.3, 0.45)
	_overlay.draw_rect(Rect2(p, Vector2(Tuning.ICON_SIZE, Tuning.ICON_SIZE)), shadow)


# --- Janelas de interface: notas, pastas, fotos e textos ----------------------------

## Põe a janela na cena e na lista (por cima das outras). O menu Iniciar continua no topo.
func _register_window(w: MiniWindow) -> void:
	_windows.append(w)
	add_child(w)
	_keep_menu_on_top()
	_restack()


func _keep_menu_on_top() -> void:
	if _start_menu != null:
		move_child(_start_menu, get_child_count() - 1)


## Traz a janela para a frente de todas as outras.
func _raise(w: MiniWindow) -> void:
	_windows.erase(w)
	_windows.append(w)
	move_child(w, get_child_count() - 1)
	_keep_menu_on_top()
	_restack()


## Empilha as mini-janelas de 2 em 2 no z (100, 102, 104...): o vão entre elas é onde o
## bicudinho entra quando está em cima de uma (veja _update_bird_layer).
func _restack() -> void:
	for i in _windows.size():
		_windows[i].z_index = 100 + 2 * i
	_update_bird_layer()


## O bicudinho fica atrás das mini-janelas, como o resto do jogo. Só quando pisa no topo de
## uma ele passa a desenhar logo acima dela (e abaixo das que estão por cima dela). Continua
## assim no ar até pousar em outra coisa.
func _update_bird_layer() -> void:
	if bird == null:
		return
	if bird.is_on_floor():
		_bird_window = null
		for i in bird.get_slide_collision_count():
			var col := bird.get_slide_collision(i)
			if col.get_normal().y > -0.5:
				continue
			for w in _windows:
				if col.get_collider() == w.platform_body:
					_bird_window = w
	if _bird_window != null and not _bird_window.visible:
		_bird_window = null
	bird.z_index = _bird_window.z_index + 1 if _bird_window != null else 0


## A janela aberta que está por cima, ou null.
func _top_window() -> MiniWindow:
	for i in range(_windows.size() - 1, -1, -1):
		if _windows[i].visible:
			return _windows[i]
	return null


## Cascata: cada janela aberta nova aparece um pouco mais abaixo e à direita.
func _place_window(w: MiniWindow) -> void:
	var open_count := 0
	for other in _windows:
		if other != w and other.visible:
			open_count += 1
	var o := w.outer_rect().size
	var pos := Vector2(200, 70) + Vector2(18, 16) * open_count
	pos.x = clampf(pos.x, 0.0, Tuning.SCREEN_W - o.x)
	pos.y = clampf(pos.y, 0.0, Tuning.SCREEN_H - Tuning.TASKBAR_H - o.y)
	w.position = pos


func _open_icon(ic: DeskIcon) -> void:
	match ic.opens():
		"launch":
			Audio.play("sfx_window_open")
			get_tree().change_scene_to_file(ic.launch)
		"notepad":
			_open_notepad()
		"folder":
			_open_folder(ic)
		"file":
			_open_file(ic.file_data)
			if ic.doc_key != "":
				_unlock_doc(ic.doc_key)


func _open_notepad() -> void:
	if _notepad == null:
		return
	_notepad.open()
	_raise(_notepad)
	Audio.play("sfx_window_open")


func _open_folder(ic: DeskIcon) -> void:
	var fw: FolderWindow = _folder_windows.get(ic)
	if fw == null:
		fw = FolderWindow.new()
		fw.file_opened.connect(_open_file)
		_register_window(fw)
		fw.setup_files(ic.label if ic.label != "" else "pasta", ic.contents)
		_place_window(fw)
		_folder_windows[ic] = fw
	fw.open()
	_raise(fw)
	Audio.play("sfx_window_open")


## Abre um arquivo (de uma pasta ou de um ícone direto): foto no visualizador, texto no bloco.
func _open_file(file: Dictionary) -> void:
	match str(file.get("kind", "image")):
		"image":
			_open_photo(file)
		"text":
			_open_text(file)


func _open_photo(file: Dictionary) -> void:
	var first := _viewer == null
	if first:
		_viewer = PhotoWindow.new()
		_register_window(_viewer)
	_viewer.show_photo(str(file.get("photo", "")), str(file.get("caption", "")),
		str(file.get("credit", "")), str(file.get("name", "foto")))
	if first or not _viewer.visible:
		_place_window(_viewer)
	_viewer.open()
	_raise(_viewer)
	Audio.play("sfx_window_open")


func _open_text(file: Dictionary) -> void:
	var first := _text_window == null
	if first:
		_text_window = MiniWindow.new()
		_register_window(_text_window)
	var text := str(file.get("text", ""))
	_text_window.title = str(file.get("name", "texto.txt"))
	_text_window.text = text
	var text_h := ThemeDB.fallback_font.get_multiline_string_size(
		text, HORIZONTAL_ALIGNMENT_LEFT, 188.0, 8).y
	_text_window.size = Vector2(200, maxf(50.0, text_h + MiniWindow.PAD * 2.0 + 6.0))
	if first or not _text_window.visible:
		_place_window(_text_window)
	_text_window.open()
	_raise(_text_window)
	Audio.play("sfx_window_open")


# --- Objetivo, vitória e morte ----------------------------------------------------------

func _physics_process(_delta: float) -> void:
	for w in _windows:
		w.update_platform(win.rect)  # o topo das mini-janelas é plataforma
	_update_bird_layer()
	if _won or _restarting or bird.dead or _minimized:
		return
	_flee_exit()
	# o objetivo só existe quando está inteiro dentro da janela
	if exit_icon.inside and bird.box_rect().intersects(exit_icon.rect()):
		_win_level()


func _win_level() -> void:
	_won = true
	if _level_number() > 0:
		Progress.beat(_level_number())  # libera o .exe da próxima fase no desktop
	if female != null:
		bird.celebrate()  # última fase: para e fica feliz
		female.set_happy(true)  # ela também fica feliz e solta um coração
	else:
		bird.celebrate(false)  # pega o graveto e para, sem festa
		if twig != null:
			_collect_twig()
			Fx.twig_get(twig.global_position + Vector2(0, -16))
			var to := Vector2.INF
			if twig_folder != null:
				to = twig_folder.position + Vector2(Tuning.ICON_SIZE, Tuning.ICON_SIZE) / 2.0 + Vector2(0, 16)
				twig.arrived.connect(_on_twig_arrived)
			twig.pick_up(to)
	Audio.stop_music()
	Audio.play("sfx_win_level", 0.0, Tuning.WIN_VOLUME_DB)
	queue_redraw()
	await get_tree().create_timer(WIN_RESTART_TIME).timeout
	if next_level != "":
		get_tree().change_scene_to_file(next_level)
	else:
		get_tree().reload_current_scene()  # sem próxima fase ainda: recomeça


func _on_bird_died(_cause: String) -> void:
	if _restarting or _won:
		return
	_restarting = true
	await get_tree().create_timer(Tuning.DEATH_RESTART_TIME).timeout
	get_tree().reload_current_scene()


# --- Mouse e teclado --------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()
		return
	if event.is_action_pressed("ui_cancel"):
		var top := _top_window()
		if top != null:
			top.close()  # Esc fecha a janela de cima (o menu Iniciar já consumiu o Esc dele)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var m := get_global_mouse_position()
		if event.pressed and _press_taskbar(m):
			return
		if not event.pressed:
			win.release_button(m)
			for w in _windows:
				var was_dragging := w.is_dragging()
				w.handle_release(m)
				# o topo virou chão em cima do bicudinho: lugar proibido, a janela volta
				if was_dragging and w.platform_rect(win.rect).intersects(bird.box_rect()):
					w.position = w.drag_start
					Audio.play("sfx_window_limit")
			return
		# ordem de prioridade: janelas de interface (a de cima primeiro), botões da janela do
		# jogo, ícones, bordas da janela do jogo
		for i in range(_windows.size() - 1, -1, -1):
			var w := _windows[i]
			if w.handle_press(m):
				_raise(w)
				return
		var btn := win.button_at(m) if not _minimized else -1
		if btn != -1:
			win.press_button(btn)
			Audio.play("sfx_ui_click")
			return
		var ic := _icon_at(m)
		if ic != null:
			if event.double_click and ic.opens() != "":
				_open_icon(ic)
			elif ic.draggable:
				_start_icon_drag(ic, m)
			return
		var sides := win.side_at(m) if not _minimized else 0
		if sides != 0:
			win.begin_resize(sides, m)
			Audio.play("sfx_ui_click", 0.05, -6.0)
		elif not _minimized and win.title_at(m):
			win.begin_resize(GameWindow.MOVE, m)  # arrasta a janela inteira


## Botões da janela do jogo: só de enfeite por enquanto. Fechar o jogo "não pode".
func _on_window_button(btn: int) -> void:
	match btn:
		GameWindow.BTN_CLOSE:
			get_tree().change_scene_to_file(HUB_SCENE)  # fecha a fase: volta para o desktop
		GameWindow.BTN_MINIMIZE:
			set_minimized(true)
		_:
			Audio.play("sfx_window_limit")


## Minimiza (o mundo some, o desktop fica) ou restaura a janela do jogo. O botão da fase na
## barra de tarefas também faz isso.
func set_minimized(on: bool, silent := false) -> void:
	if _minimized == on:
		return
	_minimized = on
	if on and win.drag_sides != 0:
		win.end_resize()
	for n in world_nodes:
		if is_instance_valid(n):
			n.visible = not on
			n.process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT
	for ic in icons:
		if ic.inside:
			ic.visible = not on
	exit_icon.visible = not on and exit_icon.visible
	for ic in exe_icons:
		ic.shown = on or is_hub
	if on:
		# minimizada, a janela não cobre nada: os ícones do desktop aparecem inteiros
		for ic in icons:
			if ic.desktop_only:
				ic.update_inside(NO_WINDOW)
	if not on:
		_on_rect_changed()
	if not silent:
		Audio.play("sfx_ui_click", 0.05, -6.0)


## Algum elemento de interface (menu Iniciar aberto ou janela) está sob o ponto m?
## Aí a janela do jogo e os ícones que ficam por baixo não reagem (nem o cursor muda).
func _ui_covers(m: Vector2) -> bool:
	if _start_menu.is_open:
		var menu := Rect2(
			Vector2(2, Tuning.SCREEN_H - Tuning.TASKBAR_H - StartMenu.MENU_SIZE.y),
			StartMenu.MENU_SIZE)
		if menu.has_point(m):
			return true
	for w in _windows:
		if w.visible and w.outer_rect().has_point(m):
			return true
	return false


func _process(delta: float) -> void:
	if _won:
		_won_time += delta
	queue_redraw()  # a barra de tarefas acompanha as janelas que abrem e fecham
	var m := get_global_mouse_position()
	# arrastos por polling: continuam mesmo se o mouse passar por outro nó
	if _drag_icon != null:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_drag_icon.position = m - _drag_offset
			_overlay.queue_redraw()
		else:
			_end_icon_drag()
	elif win.drag_sides != 0:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			win.update_resize(m)
		else:
			win.end_resize()
	for w in _windows:
		if not w.visible:
			continue
		if w.is_dragging() and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			w.handle_release(m)
		if w.handle_motion(m):
			Audio.play("sfx_ui_hover", 0.05, -4.0)
	# botões da janela: sem hover quando algo da interface está por cima
	if win.update_hover(Vector2(-100, -100) if _ui_covers(m) else m):
		Audio.play("sfx_ui_hover", 0.05, -4.0)
	_update_cursor(m)


func _update_cursor(m: Vector2) -> void:
	var shape := Input.CURSOR_ARROW
	if _drag_icon != null:
		shape = Input.CURSOR_DRAG
	elif _ui_covers(m):
		shape = Input.CURSOR_ARROW  # por cima do menu ou de uma janela: cursor normal
	else:
		var ic := _icon_at(m)
		if ic != null:
			if ic.draggable or ic.opens() != "":
				shape = Input.CURSOR_POINTING_HAND
		else:
			var sides := win.drag_sides if win.drag_sides != 0 else (0 if _minimized else win.side_at(m))
			if sides != 0:
				var h := sides & (GameWindow.L | GameWindow.R)
				var v := sides & (GameWindow.T | GameWindow.B)
				if h != 0 and v != 0:
					var same := (h == GameWindow.L) == (v == GameWindow.T)
					shape = Input.CURSOR_FDIAGSIZE if same else Input.CURSOR_BDIAGSIZE
				elif h != 0:
					shape = Input.CURSOR_HSIZE
				else:
					shape = Input.CURSOR_VSIZE
	if win.drag_sides == GameWindow.MOVE:
		shape = Input.CURSOR_MOVE
	if shape != _cursor_shape:
		_cursor_shape = shape
		Input.set_default_cursor_shape(shape)


# --- Fundo: desktop falso -----------------------------------------------------------

func _draw() -> void:
	var area := Rect2(0, 0, Tuning.SCREEN_W, Tuning.SCREEN_H - Tuning.TASKBAR_H)
	draw_rect(area, wallpaper_color)
	draw_texture_rect(WALLPAPER_TEX, Rect2(0, 0, Tuning.SCREEN_W, Tuning.SCREEN_H), false, wallpaper_tint)
	if not _minimized:
		draw_rect(win.rect, sky_color)  # o céu só existe dentro da janela
	draw_texture_rect(TASKBAR_TEX, Rect2(0, Tuning.SCREEN_H - Tuning.TASKBAR_H, Tuning.SCREEN_W, Tuning.TASKBAR_H), false)
	_draw_taskbar()
	var text := win_text
	if text == "":
		if goal == "female":
			text = "Achou a bicudinha!"
		else:
			text = "Pegou um graveto!"
	if _won:
		# entra com um pulinho: cresce passando do tamanho e volta (ease out back)
		var t := clampf(_won_time / 0.35, 0.0, 1.0)
		var k := 1.0 + 2.7 * pow(t - 1.0, 3.0) + 1.7 * pow(t - 1.0, 2.0)
		var c := Vector2(win.rect.get_center().x, win.rect.get_center().y - 44.0)
		draw_set_transform(c, 0.0, Vector2(k, k))
		var font := ThemeDB.fallback_font
		var w := win.rect.size.x
		draw_string(font, Vector2(-w / 2.0 + 1, 7), text, HORIZONTAL_ALIGNMENT_CENTER, w, 18, Color(1, 1, 1, 0.8))
		draw_string(font, Vector2(-w / 2.0, 6), text, HORIZONTAL_ALIGNMENT_CENTER, w, 18, Color("2f3a8f"))
		draw_set_transform(Vector2.ZERO)


# --- Barra de tarefas: as janelas abertas -------------------------------------------

## Um item por janela aberta: [nome, chave do ícone, a mini-janela (null = a do jogo)].
func _taskbar_items() -> Array:
	var items: Array = []
	if not is_hub:
		items.append([level_name if level_name != "" else "Bicudinho", "game", null])
	for w in _windows:
		if not w.visible:
			continue
		var kind := "text"
		if w == _notepad:
			kind = "notepad"
		elif w is FolderWindow:
			kind = "folder"
		elif w is PhotoWindow:
			kind = "photo"
		elif w is AdWindow:
			kind = "ad"
		items.append([w.title, kind, w])
	return items


func _task_rect(i: int, count: int) -> Rect2:
	var w := minf(TASK_W, (Tuning.SCREEN_W - TASK_X - 4.0) / maxi(count, 1) - 2.0)
	return Rect2(TASK_X + i * (w + 2.0), Tuning.SCREEN_H - Tuning.TASKBAR_H + 2.0, w, Tuning.TASKBAR_H - 4.0)


## Clique num botão da barra: a mini-janela vem para a frente; a do jogo minimiza ou volta.
## (A música liga e desliga pelo menu Iniciar.)
func _press_taskbar(m: Vector2) -> bool:
	var items := _taskbar_items()
	for i in items.size():
		if _task_rect(i, items.size()).has_point(m):
			var w: MiniWindow = items[i][2]
			if w != null:
				_raise(w)
				Audio.play("sfx_ui_click", 0.05, -6.0)
			else:
				set_minimized(not _minimized)
			return true
	return false


func _draw_taskbar() -> void:
	var items := _taskbar_items()
	var top := _top_window()
	var font := ThemeDB.fallback_font
	for i in items.size():
		var r := _task_rect(i, items.size())
		var active: bool = items[i][2] == top and top != null
		if items[i][2] == null:
			active = not _minimized and top == null  # a janela do jogo, quando está à frente
		# botão em relevo (afundado quando é a janela da frente)
		draw_rect(r, Color("4a55a8") if active else Color("3a4596"))
		draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), Color(0, 0, 0, 0.5) if active else Color(1, 1, 1, 0.35))
		draw_rect(Rect2(r.position.x, r.end.y - 1, r.size.x, 1), Color(1, 1, 1, 0.25) if active else Color(0, 0, 0, 0.5))
		var tex: Texture2D = _task_icons.get(items[i][1])
		var x := r.position.x + 3.0
		if tex != null:
			draw_texture_rect(tex, Rect2(x, r.position.y + 1, 14, 14), false)
			x += 17.0
		draw_string(font, Vector2(x, r.end.y - 4), str(items[i][0]), HORIZONTAL_ALIGNMENT_LEFT,
			r.end.x - x - 3.0, 8, Color("f2f1ed"))


# --- Pasta de gravetos -----------------------------------------------------------------

## O número desta fase, tirado do nome da cena (level_07.tscn -> 7). 0 = não é uma fase.
func _level_number() -> int:
	var f := scene_file_path.get_file()
	if not f.begins_with("level_"):
		return 0
	return f.trim_prefix("level_").get_basename().to_int()


## As fotos da pasta: um graveto por fase vencida, em ordem.
func _twig_files() -> Array:
	var files: Array = []
	var nums := Progress.collected.duplicate()
	nums.sort()
	for n: int in nums:
		if TWIG_NAMES.has(n):
			files.append({"kind": "image", "name": "graveto_%s.png" % TWIG_NAMES[n][0],
				"photo": "graveto_%02d" % n, "caption": "Pego na %s." % TWIG_NAMES[n][1]})
	return files


## Um canto livre do desktop para um ícone: fora da janela, longe dos outros ícones e da dica.
## Sem lugar livre, fica atrás da janela (só espiando), em alturas diferentes.
func _free_desktop_spot(fallback_index: int) -> Vector2:
	var outer := win.outer_rect().grow(4.0)
	var note := Rect2(note_pos, note_size + Vector2(0, MiniWindow.TITLE_H)) if note_text != "" else Rect2()
	for x in [8.0, 600.0]:
		for y in [288.0, 240.0, 192.0, 144.0, 96.0, 48.0, 8.0]:
			var r := Rect2(x, y, Tuning.ICON_SIZE, Tuning.ICON_SIZE + 12.0)  # + o nome embaixo
			if r.intersects(outer) or r.intersects(note):
				continue
			var free := true
			for ic in icons:
				if ic.rect().grow(8.0).intersects(r):
					free = false
			if free:
				return Vector2(x, y)
	# sem canto livre: a primeira casa livre da grade (pode ficar atrás da janela, espiando)
	for i in 40:
		if not _slot_taken(desktop_slot(i)):
			return desktop_slot(i)
	return Vector2(8, 288 - 56 * fallback_index)


## As pastas que existem em todas as fases: "gravetos" (a coleção), "fotos" e "trabalho".
## São só do desktop (nunca viram chão). Se a fase já tem uma pasta com o mesmo nome (como os
## degraus da fase 9), ela é usada no lugar e só ganha o conteúdo.
func _add_desktop_folders() -> void:
	Progress.load_once()
	var defs := [
		["gravetos", _twig_files(), twig_folder_pos],
		["fotos", PHOTOS_FILES, desktop_folder_pos.get("fotos", Vector2.ZERO)],
		["trabalho", _work_files(), desktop_folder_pos.get("trabalho", Vector2.ZERO)],
		["créditos", CREDIT_FILES, desktop_folder_pos.get("créditos", Vector2.ZERO)],
	]
	for k in defs.size():
		var label: String = defs[k][0]
		var existing: DeskIcon = null
		for ic in icons:
			if ic.label == label:
				existing = ic
		var ic := existing
		if ic == null:
			var pos: Vector2 = defs[k][2]
			if pos == Vector2.ZERO:
				pos = _free_desktop_spot(k)
			ic = _add_icon("folder", pos, true, label)
			ic.desktop_only = true
			ic.solid = false
		ic.is_container = true
		ic.contents = defs[k][1]
		if label == "gravetos":
			twig_folder = ic
		elif label == "trabalho":
			work_folder = ic


## Pegou o graveto desta fase: entra na coleção (e na pasta, já aberta ou não).
func _collect_twig() -> void:
	var n := _level_number()
	if n == 0 or not Progress.add(n):
		return
	twig_folder.contents = _twig_files()
	var fw: FolderWindow = _folder_windows.get(twig_folder)
	if fw != null:
		fw.setup_files("gravetos", twig_folder.contents)


# --- Os .exe das fases -------------------------------------------------------------------

## Casa n da grade do desktop (colunas de 5, de cima para baixo, da esquerda para a direita).
func desktop_slot(i: int) -> Vector2:
	return Vector2(16 + (i / 5) * 80, 16 + (i % 5) * 64)


## Um .exe por fase liberada (e o dos créditos depois da 12), nas primeiras casas livres.
func _add_exe_icons() -> void:
	var entries: Array = []
	for n in EXES:
		if Progress.unlocked(n):
			entries.append([EXES[n], "res://scenes/level_%02d.tscn" % n])
	if Progress.beaten.has(12):
		entries.append(["creditos.exe", "res://scenes/creditos.tscn"])
	var slot := 0
	for e in entries:
		var pos := desktop_slot(slot)
		while slot < 40 and _slot_taken(pos):
			slot += 1
			pos = desktop_slot(slot)
		slot += 1
		var ic := _add_icon("app", pos, true, e[0])
		ic.launch = e[1]
		ic.hide_outside = false
		ic.desktop_only = true
		ic.solid = false
		ic.shown = is_hub
		exe_icons.append(ic)


func _slot_taken(pos: Vector2) -> bool:
	var r := Rect2(pos, Vector2(Tuning.ICON_SIZE, Tuning.ICON_SIZE + 12.0))
	for ic in icons:
		if ic.rect().grow(6.0).intersects(r):
			return true
	return false


# --- Textos soltos (desbloqueiam a pasta "trabalho") -----------------------------------

func _work_files() -> Array:
	Progress.load_once()
	var files: Array = []
	for k: String in DOC_ORDER:
		if Progress.docs.has(k):
			files.append(DOCS[k])
	return files


## O .txt solto desta fase, num canto livre do desktop (só do desktop, nunca vira chão).
func _add_loose_doc() -> void:
	if loose_doc == "" or not DOCS.has(loose_doc):
		return
	var doc: Dictionary = DOCS[loose_doc]
	var ic := _add_icon("file", _free_desktop_spot(3), true, doc.name)
	ic.desktop_only = true
	ic.solid = false
	ic.file_data = doc
	ic.doc_key = loose_doc


## Leu um texto solto: ele entra na pasta "trabalho" (já aberta ou não).
func _unlock_doc(key: String) -> void:
	if not Progress.unlock_doc(key) or work_folder == null:
		return
	work_folder.contents = _work_files()
	var fw: FolderWindow = _folder_windows.get(work_folder)
	if fw != null:
		fw.setup_files(work_folder.label, work_folder.contents)


## O graveto chegou voando na pasta: ela dá um pulinho e solta faíscas.
func _on_twig_arrived() -> void:
	if twig_folder == null:
		return
	twig_folder.bounce()
	Fx.sparkle(twig_folder.position + Vector2(Tuning.ICON_SIZE / 2.0, Tuning.ICON_SIZE / 2.0), 16, 0.7)
	Audio.play("sfx_ui_hover", 0.0, -2.0)
