@tool
class_name RetroCrtBasicEffect
extends RetroBaseEffect

@export_range(0.0, 1.0) var bleeding: float = 0.5
@export_range(0.0, 1.0) var fringing: float = 0.5
@export_range(0.0, 1.0) var scanline: float = 0.5

func _get_shader_path() -> String:
	return "res://addons/godot_retro/shaders/compute/crt_basic.glsl"

func _get_custom_push_constants() -> Array:
	return [
		bleeding,
		fringing,
		scanline,
		0.0,
		0.0,
	]
