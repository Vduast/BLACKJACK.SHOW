@tool
class_name RetroVhsEffect
extends RetroBaseEffect

@export_range(0.0, 0.04) var tape_wave_amount: float = 0.003
@export_range(0.0, 15.0) var tape_crease_amount: float = 2.5
@export_range(0.0, 5.0) var color_displacement: float = 1.0
@export_range(0.0, 5.0) var lines_velocity: float = 0.1

func _get_shader_path() -> String:
	return "res://addons/godot_retro/shaders/compute/vhs.glsl"

func _get_custom_push_constants() -> Array:
	return [
		tape_wave_amount,
		tape_crease_amount,
		color_displacement,
		lines_velocity,
		0.0,
	]
