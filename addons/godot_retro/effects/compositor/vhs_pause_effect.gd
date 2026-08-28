@tool
class_name RetroVhsPauseEffect
extends RetroBaseEffect

@export_range(1.0, 500.0) var shake_amount_x: float = 250.0
@export_range(1.0, 500.0) var shake_amount_y: float = 40.0
@export_range(0.0, 50.0) var white_hlines: float = 50.0
@export_range(0.0, 80.0) var white_vlines: float = 80.0

func _get_shader_path() -> String:
	return "res://addons/godot_retro/shaders/compute/vhs_pause.glsl"

func _get_custom_push_constants() -> Array:
	return [
		shake_amount_x,
		shake_amount_y,
		white_hlines,
		white_vlines,
		0.0,
	]
