@tool
class_name RetroPosterizationComplexEffect
extends RetroBaseEffect

@export_range(0.0, 255.0) var color_depth: float = 100.0
@export_range(0.0, 50.0) var color_number: float = 20.0

func _get_shader_path() -> String:
	return "res://addons/godot_retro/shaders/compute/posterization_complex.glsl"

func _get_custom_push_constants() -> Array:
	return [
		color_depth,
		color_number,
		0.0,
		0.0,
		0.0,
	]
