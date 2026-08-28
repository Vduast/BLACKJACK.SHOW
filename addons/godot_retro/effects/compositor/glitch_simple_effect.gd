@tool
class_name RetroGlitchSimpleEffect
extends RetroBaseEffect

@export_range(0.2, 1.0) var scan_line_jitter: float = 0.25
@export_range(0.0, 1.0) var vertical_jump: float = 0.01
@export_range(0.0, 1.0) var horizontal_shake: float = 0.0
@export_range(0.0, 1.0) var color_drift: float = 0.02

func _get_shader_path() -> String:
	return "res://addons/godot_retro/shaders/compute/glitch_simple.glsl"

func _get_custom_push_constants() -> Array:
	return [
		scan_line_jitter,
		vertical_jump,
		horizontal_shake,
		color_drift,
		0.0,
	]
