@tool
class_name RetroSharpnessEffect
extends RetroBaseEffect

@export_range(0.0, 4.0) var sharpen_amount: float = 1.0

func _get_shader_path() -> String:
	return "res://addons/godot_retro/shaders/compute/sharpness.glsl"

func _get_custom_push_constants() -> Array:
	return [
		sharpen_amount,
	]
