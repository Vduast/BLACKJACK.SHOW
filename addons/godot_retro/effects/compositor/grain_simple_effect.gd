@tool
class_name RetroGrainSimpleEffect
extends RetroBaseEffect

@export_range(0.0, 0.1) var amount: float = 0.05

func _get_shader_path() -> String:
	return "res://addons/godot_retro/shaders/compute/grain_simple.glsl"

func _get_custom_push_constants() -> Array:
	return [
		amount,
	]
