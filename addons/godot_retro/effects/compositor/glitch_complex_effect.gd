@tool
class_name RetroGlitchComplexEffect
extends RetroBaseEffect

@export var range: float = 0.03
@export_range(0.0, 250.0) var noise_quality: float = 250.0
@export_range(0.0, 0.05) var noise_intensity: float = 0.005
@export var offset_intensity: float = 0.01
@export_range(0.0, 1.5) var color_offset_intensity: float = 0.3

func _get_shader_path() -> String:
	return "res://addons/godot_retro/shaders/compute/glitch_complex.glsl"

func _get_custom_push_constants() -> Array:
	return [
		range,
		noise_quality,
		noise_intensity,
		offset_intensity,
		color_offset_intensity,
	]
