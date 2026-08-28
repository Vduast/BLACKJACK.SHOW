@tool
class_name RetroMonochromeEffect
extends RetroBaseEffect

@export_range(0.0, 3.0) var contrast: float = 1.0
@export_range(-1.0, 1.0) var brightness: float = 0.0

func _get_shader_path() -> String:
	return "res://addons/godot_retro/shaders/compute/monochrome.glsl"

func _get_custom_push_constants() -> Array:
	return [
		contrast,
		brightness,
		0.0,
		0.0,
		0.0,
	]
