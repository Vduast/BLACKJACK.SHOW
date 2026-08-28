@tool
@icon("res://addons/godot_retro/icon.png")
class_name RetroBaseEffect
extends CompositorEffect

var rd: RenderingDevice
var shader: RID
var pipeline: RID
var sampler: RID

var copy_shader: RID
var copy_pipeline: RID

# We use an internal dictionary to cache temp textures per view to handle stereo rendering
var temp_textures: Dictionary = {}

func _init() -> void:
	effect_callback_type = CompositorEffect.EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	rd = RenderingServer.get_rendering_device()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if shader.is_valid() and rd:
			rd.free_rid(shader)
		if pipeline.is_valid() and rd:
			rd.free_rid(pipeline)
		if copy_shader.is_valid() and rd:
			rd.free_rid(copy_shader)
		if copy_pipeline.is_valid() and rd:
			rd.free_rid(copy_pipeline)
		if sampler.is_valid() and rd:
			rd.free_rid(sampler)
		for tex in temp_textures.values():
			if rd and tex.is_valid():
				rd.free_rid(tex)

# To be overridden by child classes
func _get_shader_path() -> String:
	return ""

# To be overridden by child classes
# Return an array of floats or ints. Colors/Vectors should be split into individual floats.
func _get_custom_push_constants() -> Array:
	return []

# To be overridden by child classes
func _get_extra_uniforms() -> Array:
	return []

func _render_callback(p_effect_callback_type: int, p_render_data: RenderData) -> void:
	if not rd or p_effect_callback_type != CompositorEffect.EFFECT_CALLBACK_TYPE_POST_TRANSPARENT:
		return

	if not shader.is_valid():
		var path := _get_shader_path()
		if path.is_empty():
			return
		var shader_file := load(path)
		if not shader_file:
			return
		shader = rd.shader_create_from_spirv(shader_file.get_spirv())
		if not shader.is_valid():
			return
		pipeline = rd.compute_pipeline_create(shader)

	if not copy_shader.is_valid():
		var copy_shader_file := load("res://addons/godot_retro/shaders/compute/copy.glsl")
		if copy_shader_file:
			copy_shader = rd.shader_create_from_spirv(copy_shader_file.get_spirv())
			if copy_shader.is_valid():
				copy_pipeline = rd.compute_pipeline_create(copy_shader)

	if not sampler.is_valid():
		var sampler_state := RDSamplerState.new()
		sampler_state.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
		sampler_state.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
		sampler_state.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
		sampler_state.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
		sampler = rd.sampler_create(sampler_state)

	var scene_buffers: RenderSceneBuffersRD = p_render_data.get_render_scene_buffers()
	if not scene_buffers:
		return

	var size := scene_buffers.get_internal_size()
	if size.x == 0 or size.y == 0:
		return

	var x_groups := (size.x - 1) / 8 + 1
	var y_groups := (size.y - 1) / 8 + 1
	
	var custom_push_constants := _get_custom_push_constants()
	var byte_array := PackedByteArray()
	byte_array.resize(12 + custom_push_constants.size() * 4)
	byte_array.encode_float(0, size.x)
	byte_array.encode_float(4, size.y)
	byte_array.encode_float(8, float(Time.get_ticks_msec()) / 1000.0)
	
	for i in range(custom_push_constants.size()):
		var val = custom_push_constants[i]
		if typeof(val) == TYPE_INT or typeof(val) == TYPE_BOOL:
			byte_array.encode_s32(12 + i * 4, int(val))
		else:
			byte_array.encode_float(12 + i * 4, float(val))

	for view in range(scene_buffers.get_view_count()):
		var color_image := scene_buffers.get_color_layer(view)
		var tex_format := rd.texture_get_format(color_image)
		
		var temp_tex: RID
		if temp_textures.has(view):
			temp_tex = temp_textures[view]
			if rd.texture_get_format(temp_tex).width != tex_format.width or rd.texture_get_format(temp_tex).height != tex_format.height:
				rd.free_rid(temp_tex)
				temp_tex = RID()

		if not temp_tex.is_valid():
			tex_format.usage_bits |= RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
			temp_tex = rd.texture_create(tex_format, RDTextureView.new())
			temp_textures[view] = temp_tex

		if copy_pipeline.is_valid():
			var copy_uniform_image := RDUniform.new()
			copy_uniform_image.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
			copy_uniform_image.binding = 0
			copy_uniform_image.add_id(temp_tex)

			var copy_uniform_sampler := RDUniform.new()
			copy_uniform_sampler.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
			copy_uniform_sampler.binding = 1
			copy_uniform_sampler.add_id(sampler)
			copy_uniform_sampler.add_id(color_image)

			var copy_uniform_set := rd.uniform_set_create([copy_uniform_image, copy_uniform_sampler], copy_shader, 0)
			
			var copy_list := rd.compute_list_begin()
			rd.compute_list_bind_compute_pipeline(copy_list, copy_pipeline)
			rd.compute_list_bind_uniform_set(copy_list, copy_uniform_set, 0)
			rd.compute_list_dispatch(copy_list, x_groups, y_groups, 1)
			rd.compute_list_end()
			
			if copy_uniform_set.is_valid():
				rd.free_rid(copy_uniform_set)

		var uniform_image := RDUniform.new()
		uniform_image.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		uniform_image.binding = 0
		uniform_image.add_id(color_image)

		var uniform_sampler := RDUniform.new()
		uniform_sampler.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
		uniform_sampler.binding = 1
		uniform_sampler.add_id(sampler)
		uniform_sampler.add_id(temp_tex)

		var uniforms: Array[RDUniform] = [uniform_image, uniform_sampler]
		var extra_uniforms: Array = _get_extra_uniforms()
		for u in extra_uniforms:
			uniforms.append(u)

		var uniform_set := rd.uniform_set_create(uniforms, shader, 0)

		var compute_list := rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
		rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
		if byte_array.size() > 0:
			rd.compute_list_set_push_constant(compute_list, byte_array, byte_array.size())
		rd.compute_list_dispatch(compute_list, x_groups, y_groups, 1)
		rd.compute_list_end()

		if uniform_set.is_valid():
			rd.free_rid(uniform_set)
