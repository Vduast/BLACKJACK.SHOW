@tool
class_name RetroGrainComplexEffect
extends RetroBaseEffect

@export var colored: bool = false
@export_range(0.0, 1.3) var color_amount: float = 0.6
@export_range(0.0, 0.07) var grain_amount: float = 0.025
@export_range(1.0, 3.0) var grain_size: float = 1.6
@export_range(0.0, 2.0) var lum_amount: float = 1.3

func _get_shader_path() -> String:
	return "res://addons/godot_retro/shaders/compute/grain_complex.glsl"

func _get_custom_push_constants() -> Array:
	return [
		colored,
		color_amount,
		grain_amount,
		grain_size,
		lum_amount,
	]
