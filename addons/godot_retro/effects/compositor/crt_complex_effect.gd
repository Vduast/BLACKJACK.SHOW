@tool
class_name RetroCrtComplexEffect
extends RetroBaseEffect

@export_range(0.0, 8.0) var blur_amount: float = 3.0
@export_range(0.0, 0.6) var signal_quality: float = 0.3
@export_range(0.0, 0.6) var bottom_strenth: float = 0.3

func _get_shader_path() -> String:
	return "res://addons/godot_retro/shaders/compute/crt_complex.glsl"

func _get_custom_push_constants() -> Array:
	return [
		blur_amount,
		signal_quality,
		bottom_strenth,
		0.0,
		0.0,
	]

@export var grain_texture: Texture2D = preload("res://addons/godot_retro/textures/grain.jpg")

var repeat_sampler: RID

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if repeat_sampler.is_valid() and rd:
			rd.free_rid(repeat_sampler)

func _get_extra_uniforms() -> Array:
	var uniforms: Array = []
	if grain_texture and grain_texture.get_rid().is_valid():
		var tex_rd_rid := RenderingServer.texture_get_rd_texture(grain_texture.get_rid())
		if tex_rd_rid.is_valid():
			if not repeat_sampler.is_valid() and rd:
				var sampler_state := RDSamplerState.new()
				sampler_state.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
				sampler_state.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
				sampler_state.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_REPEAT
				sampler_state.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_REPEAT
				repeat_sampler = rd.sampler_create(sampler_state)

			var uniform_sampler := RDUniform.new()
			uniform_sampler.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
			uniform_sampler.binding = 2
			uniform_sampler.add_id(repeat_sampler)
			uniform_sampler.add_id(tex_rd_rid)
			uniforms.append(uniform_sampler)
	return uniforms
