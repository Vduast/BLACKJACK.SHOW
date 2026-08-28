@tool
class_name RetroDitheringEffect
extends RetroBaseEffect

@export_range(0.0, 10.0) var color_factor: float = 10.0
@export_range(0.0, 0.07) var dithering_strength: float = 0.005

func _get_shader_path() -> String:
	return "res://addons/godot_retro/shaders/compute/dithering.glsl"

func _get_custom_push_constants() -> Array:
	return [
		color_factor,
		dithering_strength,
		0.0,
		0.0,
		0.0,
	]
