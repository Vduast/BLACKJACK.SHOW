@tool
class_name RetroBlurEffect
extends RetroBaseEffect

@export_range(0.0, 1.5) var amount: float = 0.5

func _get_shader_path() -> String:
	return "res://addons/godot_retro/shaders/compute/blur.glsl"

func _get_custom_push_constants() -> Array:
	return [
		amount,
	]
