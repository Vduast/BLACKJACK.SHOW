extends CanvasLayer

@onready var fade_rect: ColorRect = $FadeRect
const FADE_TIME := 0.5

func _ready():
	
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Arranca en negro y hace fade in al iniciar el juego
	fade_rect.modulate.a = 1.0
	fade_in()

func fade_in() -> void:
	var tween := create_tween()
	tween.tween_property(fade_rect, "modulate:a", 0.0, FADE_TIME)

func fade_to_scene(scene_path: String) -> void:
	# Fade out
	var tween := create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, FADE_TIME)
	await tween.finished

	# Cambiar de escena
	get_tree().change_scene_to_file(scene_path)

	# Fade in
	fade_in()
