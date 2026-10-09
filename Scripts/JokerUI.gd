extends Button
class_name JokerUI

signal joker_selected(nodo_carta: JokerUI)
signal burn_started(nodo_carta: JokerUI)

var mi_efecto: String = ""
var titulo: String = ""
var descripcion: String = ""

# --- VARIABLES DE CONTROL Y ANIMACIÓN (Para JokerHand) ---
var is_burning: bool = false
var is_animating_entrance: bool = false
var is_flipping: bool = false
var is_hovered: bool = false
var is_picked: bool = false

var _target_pos: Vector2 = Vector2.ZERO
var _target_rot: float = 0.0
var _target_scale: float = 1.0
var current_scale: float = 1.0
var flip_scale_x: float = 1.0

func _ready() -> void:
	custom_minimum_size = Vector2(320, 420)
	size = Vector2(320, 420)
	pivot_offset = size * 0.5
	resized.connect(func(): pivot_offset = size * 0.5)

func _process(delta: float) -> void:
	# Si está entrando volando a la pantalla o quemándose, dejamos que el Tween mande
	if is_animating_entrance or is_burning:
		return
		
	# Suavizado de posición (lerp) para que el abanico se mueva con fluidez orgánica
	var dest_pos = _target_pos - pivot_offset
	position = position.lerp(dest_pos, delta * 14.0)
	rotation = lerp_angle(rotation, _target_rot, delta * 14.0)
	
	# Suavizado de escala respetando el giro de la carta
	current_scale = lerp(current_scale, _target_scale, delta * 14.0)
	scale = Vector2(current_scale * flip_scale_x, current_scale)

func setup(effect_id: String, nombre_mostrar: String, desc: String):
	mi_efecto = effect_id
	titulo = nombre_mostrar
	descripcion = desc
	
	text = titulo
	add_theme_font_size_override("font_size", 30)
	add_theme_font_override("font", preload("res://models/tippa.regular.ttf"))
	
	# --- FORZAMOS LETRAS NEGRAS EN TODOS LOS ESTADOS Y 0 BORDE ---
	add_theme_color_override("font_color", Color.BLACK)
	add_theme_color_override("font_hover_color", Color.BLACK)
	add_theme_color_override("font_focus_color", Color.BLACK)
	add_theme_color_override("font_pressed_color", Color.BLACK)
	add_theme_color_override("font_disabled_color", Color.BLACK)
	add_theme_constant_override("outline_size", 0) 
	
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pivot_offset = size * 0.5

func _pressed():
	if can_interact():
		joker_selected.emit(self)

# --- MÉTODOS REQUERIDOS POR JOKERHAND ---

func can_interact() -> bool:
	return not is_burning and not is_animating_entrance and not disabled

func set_pose(target_pos: Vector2, target_rot: float, target_sc: float) -> void:
	_target_pos = target_pos
	_target_rot = target_rot
	_target_scale = target_sc

func set_hover(hovered: bool) -> void:
	is_hovered = hovered

func set_picked(picked: bool) -> void:
	is_picked = picked

func set_dimmed(dimmed: bool) -> void:
	var target_mod = Color(0.45, 0.45, 0.45, 1.0) if dimmed else Color.WHITE
	var tween = create_tween()
	tween.tween_property(self, "modulate", target_mod, 0.2)

## Animación de entrada volando desde fuera de pantalla
func appear(delay: float, start_pos: Vector2, duration: float = 0.7) -> void:
	position = start_pos - pivot_offset
	rotation = deg_to_rad(30.0)
	scale = Vector2.ZERO
	current_scale = 0.0
	is_animating_entrance = true
	
	var tween = create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
		
	tween.tween_property(self, "scale", Vector2(_target_scale, _target_scale), duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "position", _target_pos - pivot_offset, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "rotation", _target_rot, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		current_scale = _target_scale
		is_animating_entrance = false
	)

# --- ANIMACIONES DE GIRO ---

func girar_a_descripcion():
	var tween = create_tween()
	is_flipping = true
	tween.tween_property(self, "flip_scale_x", 0.0, 0.12)
	tween.tween_callback(func(): 
		text = descripcion
		add_theme_font_size_override("font_size", 20)
		add_theme_font_override("font", preload("res://models/heavy-equipment.regular.ttf"))
		add_theme_color_override("font_color", Color.BLACK)
		add_theme_constant_override("outline_size", 0)
	)
	tween.tween_property(self, "flip_scale_x", 1.0, 0.12)
	tween.tween_callback(func(): is_flipping = false)

func girar_a_titulo():
	var tween = create_tween()
	is_flipping = true
	tween.tween_property(self, "flip_scale_x", 0.0, 0.12)
	tween.tween_callback(func(): 
		text = titulo
		add_theme_font_size_override("font_size", 30)
		add_theme_font_override("font", preload("res://models/heavy-equipment.regular.ttf"))
		add_theme_color_override("font_color", Color.BLACK)
		add_theme_constant_override("outline_size", 0)
	)
	tween.tween_property(self, "flip_scale_x", 1.0, 0.12)
	tween.tween_callback(func(): is_flipping = false)

# --- ANIMACIÓN DE QUEMADO LENTO (VFX) ---

func quemar_y_destruir():
	if is_burning:
		return
	is_burning = true
	disabled = true 
	
	# Emitimos la señal avisando a JokerHand que esta carta empezó a arder
	burn_started.emit(self)
	
	var mat = material as ShaderMaterial
	if mat:
		mat = mat.duplicate()
		material = mat
		
		var tween = create_tween()
		tween.tween_property(mat, "shader_parameter/burn_amount", 1.2, 1.5)
		tween.tween_callback(func(): queue_free())
	else:
		print("ERROR VISUAL: No se encontró el ShaderMaterial.")
		queue_free()
