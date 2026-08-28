@tool
class_name RetroColorCorrectionEffect
extends RetroBaseEffect

@export var shadows: Color = Color(0, 0, 0, 1)
@export var midtones: Color = Color(0, 0, 0, 1)
@export var hilights: Color = Color(0, 0, 0, 1)

func _get_shader_path() -> String:
	return "res://addons/godot_retro/shaders/compute/color_correction.glsl"

func _get_custom_push_constants() -> Array:
	return [
		0.0,
		shadows.r, shadows.g, shadows.b, shadows.a,
		midtones.r, midtones.g, midtones.b, midtones.a,
		hilights.r, hilights.g, hilights.b, hilights.a,
	]
