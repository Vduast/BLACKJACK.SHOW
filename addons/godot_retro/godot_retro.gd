@tool
extends EditorPlugin

var icon_cache: Texture2D

"""
func _enter_tree() -> void:
	icon_cache = get_editor_interface().get_base_control().get_theme_icon("CompositorEffect", "EditorIcons")
	add_custom_type("RetroBlurEffect", "CompositorEffect", preload("res://addons/godot_retro/effects/compositor/blur_effect.gd"), icon_cache)
	add_custom_type("RetroColorCorrectionEffect", "CompositorEffect", preload("res://addons/godot_retro/effects/compositor/color_correction_effect.gd"), icon_cache)
	add_custom_type("RetroCrtBasicEffect", "CompositorEffect", preload("res://addons/godot_retro/effects/compositor/crt_basic_effect.gd"), icon_cache)
	add_custom_type("RetroCrtComplexEffect", "CompositorEffect", preload("res://addons/godot_retro/effects/compositor/crt_complex_effect.gd"), icon_cache)
	add_custom_type("RetroDitheringEffect", "CompositorEffect", preload("res://addons/godot_retro/effects/compositor/dithering_effect.gd"), icon_cache)
	add_custom_type("RetroGlitchComplexEffect", "CompositorEffect", preload("res://addons/godot_retro/effects/compositor/glitch_complex_effect.gd"), icon_cache)
	add_custom_type("RetroGlitchSimpleEffect", "CompositorEffect", preload("res://addons/godot_retro/effects/compositor/glitch_simple_effect.gd"), icon_cache)
	add_custom_type("RetroGrainComplexEffect", "CompositorEffect", preload("res://addons/godot_retro/effects/compositor/grain_complex_effect.gd"), icon_cache)
	add_custom_type("RetroGrainSimpleEffect", "CompositorEffect", preload("res://addons/godot_retro/effects/compositor/grain_simple_effect.gd"), icon_cache)
	add_custom_type("RetroLensDistortionEffect", "CompositorEffect", preload("res://addons/godot_retro/effects/compositor/lens_distortion_effect.gd"), icon_cache)
	add_custom_type("RetroMonochromeEffect", "CompositorEffect", preload("res://addons/godot_retro/effects/compositor/monochrome_effect.gd"), icon_cache)
	add_custom_type("RetroPosterizationComplexEffect", "CompositorEffect", preload("res://addons/godot_retro/effects/compositor/posterization_complex_effect.gd"), icon_cache)
	add_custom_type("RetroPosterizationSimpleEffect", "CompositorEffect", preload("res://addons/godot_retro/effects/compositor/posterization_simple_effect.gd"), icon_cache)
	add_custom_type("RetroSharpnessEffect", "CompositorEffect", preload("res://addons/godot_retro/effects/compositor/sharpness_effect.gd"), icon_cache)
	add_custom_type("RetroTvEffect", "CompositorEffect", preload("res://addons/godot_retro/effects/compositor/tv_effect.gd"), icon_cache)
	add_custom_type("RetroVhsEffect", "CompositorEffect", preload("res://addons/godot_retro/effects/compositor/vhs_effect.gd"), icon_cache)
	add_custom_type("RetroVhsPauseEffect", "CompositorEffect", preload("res://addons/godot_retro/effects/compositor/vhs_pause_effect.gd"), icon_cache)

func _exit_tree() -> void:
	remove_custom_type("RetroBlurEffect")
	remove_custom_type("RetroColorCorrectionEffect")
	remove_custom_type("RetroCrtBasicEffect")
	remove_custom_type("RetroCrtComplexEffect")
	remove_custom_type("RetroDitheringEffect")
	remove_custom_type("RetroGlitchComplexEffect")
	remove_custom_type("RetroGlitchSimpleEffect")
	remove_custom_type("RetroGrainComplexEffect")
	remove_custom_type("RetroGrainSimpleEffect")
	remove_custom_type("RetroLensDistortionEffect")
	remove_custom_type("RetroMonochromeEffect")
	remove_custom_type("RetroPosterizationComplexEffect")
	remove_custom_type("RetroPosterizationSimpleEffect")
	remove_custom_type("RetroSharpnessEffect")
	remove_custom_type("RetroTvEffect")
	remove_custom_type("RetroVhsEffect")
	remove_custom_type("RetroVhsPauseEffect")
"""
