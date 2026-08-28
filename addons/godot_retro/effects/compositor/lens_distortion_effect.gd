@tool
class_name RetroLensDistortionEffect
extends RetroBaseEffect

@export_range(-0.05, 0.05) var strength: float = 0.0

func _get_shader_path() -> String:
	return "res://addons/godot_retro/shaders/compute/lens_distortion.glsl"

func _get_custom_push_constants() -> Array:
	return [
		strength,
	]
