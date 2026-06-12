extends Node3D
class_name Card3D

@onready var mesh = $Mesh
@onready var viewport = $SubViewport
@onready var rank_label_top = $SubViewport/RankLabelTop
@onready var rank_label_bottom = $SubViewport/RankLabelBottom
@onready var symbols_container = $SubViewport/SymbolContainer
@export var color_brillo: Color = Color(1.0, 0.6, 0.1, 1.0)
var card_data: Dictionary

# Referencias para controlar el shader y la textura de ruido
var card_material: ShaderMaterial
var noise_tex: NoiseTexture2D

func _ready():
	
	await get_tree().process_frame
	
	# 1. Preparamos nuestro nuevo Material de Shader
	card_material = ShaderMaterial.new()
	# ¡ASEGÚRATE DE QUE ESTA RUTA SEA CORRECTA PARA TU PROYECTO!
	card_material.shader = load("res://shaders/dissolve_card.gdshader") 
	
	# 2. Le pegamos la imagen 2D calculada al shader
	card_material.set_shader_parameter("albedo_texture", viewport.get_texture())
	
	# 3. Creamos una textura de ruido dinámicamente para el efecto de desintegración
# AGREGA ESTO EN SU LUGAR
	noise_tex = preload("res://Objetos/ruido_desintegracion.tres")
	card_material.set_shader_parameter("noise_texture", noise_tex)
	
	# 4. Estado inicial: Totalmente invisible, borde muy grueso y mucho brillo
	card_material.set_shader_parameter("dissolve_amount", 1.0)
	card_material.set_shader_parameter("edge_thickness", 0.3) 
	card_material.set_shader_parameter("glow_intensity", 8.0) 
	
	card_material.set_shader_parameter("edge_color", color_brillo)
	# 5. Aplicamos el material a la malla 3D de la carta
	mesh.set_surface_override_material(0, card_material)
	
	# 6. Ejecutamos la animación de aparición lenta y brillante
	aparecer()


# --- ANIMACIONES DEL SHADER ---

func aparecer():
	# set_parallel(true) hace que todos los valores se animen al mismo tiempo
	var tween = create_tween().set_parallel(true) 
	
	# TIEMPO DE ANIMACIÓN: 1.5 segundos (Aparición lenta y majestuosa)
	var tiempo = 1.5
	
	# 1. Animamos la materialización (de 1.0 totalmente disuelta a 0.0 sólida)
	tween.tween_method(_set_dissolve, 1.0, 0.0, tiempo).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# 2. Animamos el tamaño del borde brillante (de 0.3 muy grueso a 0.05 fino)
	tween.tween_method(_set_edge_thickness, 0.3, 0.05, tiempo).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# 3. Animamos el brillo (de 8.0 muy intenso a 1.0 normal)
	tween.tween_method(_set_glow_intensity, 8.0, 1.0, tiempo).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func desaparecer():
	if has_node("ExplosionParticulas"):
		$ExplosionParticulas.emitting = true
	var tween = create_tween().set_parallel(true)
	
	# TIEMPO DE ANIMACIÓN: 0.5 segundos (Desaparición rápida para limpiar la mesa rápido)
	var tiempo = 0.5
	
	# Animamos de regreso a invisible
	tween.tween_method(_set_dissolve, 0.0, 1.0, tiempo).set_trans(Tween.TRANS_SINE)
	
	# Engrosamos un poco el borde al desaparecer para darle un "flash"
	tween.tween_method(_set_edge_thickness, 0.05, 0.2, tiempo).set_trans(Tween.TRANS_SINE)
	
	# Cuando terminen ambas animaciones, eliminamos la carta de la memoria de Godot
	tween.chain().tween_callback(self.queue_free)


# Funciones auxiliares para que el Tween de Godot 4 pueda modificar el Shader
func _set_dissolve(value: float):
	if is_instance_valid(card_material):
		card_material.set_shader_parameter("dissolve_amount", value)

func _set_edge_thickness(value: float):
	if is_instance_valid(card_material):
		card_material.set_shader_parameter("edge_thickness", value)

func _set_glow_intensity(value: float):
	if is_instance_valid(card_material):
		card_material.set_shader_parameter("glow_intensity", value)


# --- GENERACIÓN LÓGICA DE LA CARTA (TU CÓDIGO ORIGINAL) ---

func set_card(data: Dictionary):
	card_data = data
	_apply_rank()
	_generate_symbols()

func _apply_rank():
	# Le pasamos el texto a ambas esquinas al mismo tiempo
	if rank_label_top:
		rank_label_top.text = str(card_data["rank"])
	if rank_label_bottom:
		rank_label_bottom.text = str(card_data["rank"])

func _generate_symbols():
	for child in symbols_container.get_children():
		child.queue_free()

	var suit_map = {
		"hearts": preload("res://textures/suits/hearts.png"),
		"diamonds": preload("res://textures/suits/diamonds.png"),
		"clubs": preload("res://textures/suits/clubs.png"),
		"spades": preload("res://textures/suits/spades.png")
	}
	
	if not suit_map.has(card_data["suit"]): return
	var suit_texture = suit_map[card_data["suit"]]
	var count = card_data["value"]
	if card_data["rank"] in ["J","Q","K","A", "10"]: count = 1

	var positions = _get_symbol_positions(count)

	# Obtenemos el centro del viewport en píxeles
	var center = Vector2(viewport.size.x / 2.0, viewport.size.y / 2.0)

	for pos in positions:
		var symbol = TextureRect.new()
		symbol.texture = suit_texture
		symbol.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		
		# Tamaño del símbolo en píxeles
		var symbol_size = 60 
		symbol.size = Vector2(symbol_size, symbol_size)
		symbol.pivot_offset = symbol.size / 2.0
		
		# Posicionamos el símbolo centrándolo en la carta + posición matemática
		symbol.position = center + pos - symbol.pivot_offset
		
		symbols_container.add_child(symbol)

func _get_symbol_positions(count: int) -> Array:
	var pos = []
	# Dimensiones en PÍXELES.
	var h = 150
	var v = 200
	
	match count:
		1:
			pos = [Vector2(0, 0)]
		2:
			pos = [Vector2(0, 0.15 * v), Vector2(0, -0.15 * v)]
		3:
			pos = [Vector2(0, 0.2 * v), Vector2(0, 0), Vector2(0, -0.2 * v)]
		4:
			pos = [
				Vector2(-0.4 * h, 0.2 * v), Vector2(0.4 * h, 0.2 * v),
				Vector2(-0.4 * h, -0.2 * v), Vector2(0.4 * h, -0.2 * v)
			]
		5:
			pos = [
				Vector2(-0.4 * h, 0.2 * v), Vector2(0.4 * h, 0.2 * v),
				Vector2(0, 0),
				Vector2(-0.4 * h, -0.2 * v), Vector2(0.4 * h, -0.2 * v)
			]
		6:
			pos = [
				Vector2(-0.4 * h, 0.3 * v), Vector2(0.4 * h, 0.3 * v),
				Vector2(-0.4 * h, 0), Vector2(0.4 * h, 0),
				Vector2(-0.4 * h, -0.3 * v), Vector2(0.4 * h, -0.3 * v)
			]
		7:
			pos = [
				Vector2(0, 0.45 * v),
				Vector2(-0.4 * h, 0.3 * v), Vector2(0.4 * h, 0.3 * v),
				Vector2(-0.4 * h, 0), Vector2(0.4 * h, 0),
				Vector2(-0.4 * h, -0.3 * v), Vector2(0.4 * h, -0.3 * v)
			]
		8:
			pos = [
				Vector2(-0.4 * h, 0.45 * v), Vector2(0.4 * h, 0.45 * v),
				Vector2(-0.4 * h, 0.3 * v), Vector2(0.4 * h, 0.3 * v),
				Vector2(-0.4 * h, -0.3 * v), Vector2(0.4 * h, -0.3 * v),
				Vector2(-0.4 * h, -0.45 * v), Vector2(0.4 * h, -0.45 * v)
			]
		9:
			pos = [
				Vector2(-0.4 * h, 0.45 * v), Vector2(0, 0.45 * v), Vector2(0.4 * h, 0.45 * v),
				Vector2(-0.4 * h, 0), Vector2(0, 0), Vector2(0.4 * h, 0),
				Vector2(-0.4 * h, -0.45 * v), Vector2(0, -0.45 * v), Vector2(0.4 * h, -0.45 * v)
			]
		10:
			pos = [
				Vector2(-0.4 * h, 0.45 * v), Vector2(0.4 * h, 0.45 * v),
				Vector2(-0.4 * h, 0.3 * v), Vector2(0.4 * h, 0.3 * v),
				Vector2(-0.4 * h, 0), Vector2(0.4 * h, 0),
				Vector2(-0.4 * h, -0.3 * v), Vector2(0.4 * h, -0.3 * v),
				Vector2(-0.4 * h, -0.45 * v), Vector2(0.4 * h, -0.45 * v)
			]

	return pos
