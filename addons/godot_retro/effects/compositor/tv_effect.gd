@tool
class_name RetroTvEffect
extends RetroBaseEffect

@export_range(0.0, 1.0) var vert_jerk_opt: float = 0.2
@export_range(0.0, 1.0) var vert_movement_opt: float = 0.0
@export_range(0.0, 5.0) var bottom_static_opt: float = 0.0
@export_range(0.0, 1.5) var bottom_static_strength: float = 0.7
@export_range(0.0, 6.0) var scalines_opt: float = 0.8
@export_range(0.0, 2.0) var rgb_offset_opt: float = 0.2
@export_range(0.0, 5.0) var horz_fuzz_opt: float = 0.15

func _get_shader_path() -> String:
	return "res://addons/godot_retro/shaders/compute/tv.glsl"

func _get_custom_push_constants() -> Array:
	return [
		vert_jerk_opt,
		vert_movement_opt,
		bottom_static_opt,
		bottom_static_strength,
		scalines_opt,
		rgb_offset_opt,
		horz_fuzz_opt,
		0.0,
		0.0,
	]
