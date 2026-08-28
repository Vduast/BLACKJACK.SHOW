@tool
class_name RetroPosterizationSimpleEffect
extends RetroBaseEffect

@export_range(0.0, 10.0) var color_factor: float = 4.0

func _get_shader_path() -> String:
	return "res://addons/godot_retro/shaders/compute/posterization_simple.glsl"

func _get_custom_push_constants() -> Array:
	return [
		color_factor,
	]
