extends Button
class_name JokerUI

signal joker_selected(nodo_carta)

var mi_efecto: String = ""
var titulo: String = ""
var descripcion: String = ""

func setup(effect_id: String, nombre_mostrar: String, desc: String):
	mi_efecto = effect_id
	titulo = nombre_mostrar
	descripcion = desc
	
	text = titulo
	add_theme_font_size_override("font_size", 30)
	add_theme_font_override("font", preload("res://models/tippa.regular.ttf"))
	
	# --- FORZAMOS LETRAS NEGRAS EN TODOS LOS ESTADOS Y 0 BORDE ---
	add_theme_color_override("font_color", Color.BLACK)
	add_theme_color_override("font_hover_color", Color.BLACK)   # Al pasar el ratón
	add_theme_color_override("font_focus_color", Color.BLACK)   # Al seleccionarlo
	add_theme_color_override("font_pressed_color", Color.BLACK) # Al hacer clic
	add_theme_color_override("font_disabled_color", Color.BLACK)# Al estar desactivado
	add_theme_constant_override("outline_size", 0) 
	
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pivot_offset = Vector2(70, 90)

func _pressed():
	joker_selected.emit(self)

# --- ANIMACIONES DE GIRO ---

func girar_a_descripcion():
	var tween = create_tween()
	tween.tween_property(self, "scale:x", 0.0, 0.15)
	tween.tween_callback(func(): 
		text = descripcion
		add_theme_font_size_override("font_size", 20)
		add_theme_font_override("font", preload("res://models/heavy-equipment.regular.ttf"))
		
		# Mantenemos las letras negras y sin borde al girar
		add_theme_color_override("font_color", Color.BLACK)
		add_theme_constant_override("outline_size", 0)
	)
	tween.tween_property(self, "scale:x", 1.0, 0.15)

func girar_a_titulo():
	var tween = create_tween()
	tween.tween_property(self, "scale:x", 0.0, 0.15)
	tween.tween_callback(func(): 
		text = titulo
		add_theme_font_size_override("font_size", 30)
		add_theme_font_override("font", preload("res://models/heavy-equipment.regular.ttf"))
		
		# Mantenemos las letras negras y sin borde al girar
		add_theme_color_override("font_color", Color.BLACK)
		add_theme_constant_override("outline_size", 0)
	)
	tween.tween_property(self, "scale:x", 1.0, 0.15)

# --- ANIMACIÓN DE QUEMADO LENTO (VFX) ---
func quemar_y_destruir():
	disabled = true 
	
	var mat = material as ShaderMaterial
	if mat:
		# Duplicamos para que solo esta carta se queme
		mat = mat.duplicate()
		material = mat
		
		var tween = create_tween()
		# --- QUEMADO MÁS LENTO: 1.5 Segundos ---
		tween.tween_property(mat, "shader_parameter/burn_amount", 1.2, 1.5)
		tween.tween_callback(func(): queue_free())
	else:
		print("ERROR VISUAL: No se encontró el ShaderMaterial.")
		queue_free()
