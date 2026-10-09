extends Node
## Gerenciador de áudio (autoload "Audio"). Pré-carrega os sons e toca por nome:
## Audio.play("sfx_jump"). Som que ainda não existe é ignorado em silêncio.
## A música só começa depois do primeiro clique ou tecla (exigência do navegador).

const SOUNDS := {
	"sfx_jump": "res://sfx/sfx_jump.ogg",
	"sfx_step": "res://sfx/sfx_step.ogg",
	"sfx_dash": "res://sfx/sfx_dash.ogg",
	"sfx_ui_click": "res://sfx/sfx_ui_click.mp3",
	"sfx_ui_hover": "res://sfx/sfx_ui_hover.mp3",
	"sfx_window_limit": "res://sfx/sfx_window_limit.mp3",
	"sfx_win_level": "res://sfx/sfx_win_level.mp3",
	"sfx_death": "res://sfx/sfx_death.wav",
}
const MUSIC := "res://music/music_game.ogg"
const MUSIC_DB := -10.5   # ~30% do volume dos efeitos
const VOICES := 8

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var _music_started := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for key in SOUNDS:
		var path: String = SOUNDS[key]
		if ResourceLoader.exists(path):
			_streams[key] = load(path)
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.volume_db = MUSIC_DB
	_music.finished.connect(_music.play)  # loop, vale para qualquer formato
	add_child(_music)


## Toca um efeito. pitch_jitter varia a altura um pouco (ex.: 0.08 para passos).
func play(sound: String, pitch_jitter := 0.0, volume_db := 0.0) -> void:
	var stream: AudioStream = _streams.get(sound)
	if stream == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


## Para a música (por exemplo, na vitória). `stop()` não dispara o loop.
func stop_music() -> void:
	_music.stop()


## Volta a música do começo, se ela já tinha começado (depois do primeiro clique).
func resume_music() -> void:
	if Progress.music_on and _music_started and _music.stream != null and not _music.playing:
		_music.play()


## Liga ou desliga só a música (os efeitos continuam). A escolha fica salva.
func set_music_on(on: bool) -> void:
	Progress.load_once()
	Progress.music_on = on
	Progress.save()
	if on:
		resume_music()
	else:
		_music.stop()


func is_music_on() -> bool:
	Progress.load_once()
	return Progress.music_on


func toggle_mute() -> void:
	AudioServer.set_bus_mute(0, not is_muted())


func is_muted() -> bool:
	return AudioServer.is_bus_mute(0)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("mute"):
		toggle_mute()
	if not _music_started and (event is InputEventMouseButton or event is InputEventKey) and event.is_pressed():
		_music_started = true
		if ResourceLoader.exists(MUSIC):
			_music.stream = load(MUSIC)
			if is_music_on():
				_music.play()
