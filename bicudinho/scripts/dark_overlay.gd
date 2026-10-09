class_name DarkOverlay
extends ColorRect
## Escuridão da fase noturna ("monitor desligando"): cobre o desktop e o jogo, menos um
## círculo de luz em volta do cursor (a lanterna) e um brilho fraco em volta do bicudinho.
## Fica abaixo das mini-janelas e da barra de tarefas, e não pega cliques.

const SHADER := """
shader_type canvas_item;
uniform vec2 area_size;
uniform vec2 mouse_pos;
uniform vec2 bird_pos;
uniform float mouse_r = 72.0;
uniform float bird_r = 22.0;
uniform float darkness = 0.93;
void fragment() {
	vec2 p = UV * area_size;
	float lm = smoothstep(mouse_r * 0.55, mouse_r, distance(p, mouse_pos));
	float lb = smoothstep(bird_r * 0.4, bird_r, distance(p, bird_pos));
	COLOR = vec4(0.02, 0.03, 0.08, darkness * min(lm, mix(0.55, 1.0, lb)));
}
"""

var bird: Node2D = null
var mouse_radius := 72.0   # raio da lanterna (px)
var bird_radius := 22.0    # brilho em volta do bicudinho (px)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 95   # acima do mundo e da janela; abaixo das mini-janelas (z 100+)
	position = Vector2.ZERO
	size = Vector2(Tuning.SCREEN_W, Tuning.SCREEN_H - Tuning.TASKBAR_H)
	var sh := Shader.new()
	sh.code = SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("area_size", size)
	mat.set_shader_parameter("mouse_r", mouse_radius)
	mat.set_shader_parameter("bird_r", bird_radius)
	mat.set_shader_parameter("darkness", 0.96)
	material = mat


func _process(_delta: float) -> void:
	var mat := material as ShaderMaterial
	mat.set_shader_parameter("mouse_pos", get_global_mouse_position())
	if bird != null:
		mat.set_shader_parameter("bird_pos", bird.global_position + Vector2(0, -7))
