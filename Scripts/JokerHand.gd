extends Control
class_name JokerHand
## La "mano" de comodines. Es un Control normal (NO un contenedor) para poder
## poner las cartas en abanico, y se crea por código desde tableui.gd:
## no hace falta tocar ninguna escena.
##
## Dónde está todo (1920x1080):
##   - Mano en abanico: esquina inferior derecha (ya no pisa Pedir/Plantarse/Doblar).
##   - Carta elegida: sale de la mano y se muestra grande a la derecha-centro.
##   - Los botones USAR/CANCELAR los coloca tableui.gd justo debajo de esa carta.
## Todo es relativo al tamaño de la ventana y se puede mover con las variables @export.

signal joker_selected(joker: JokerUI)
signal collapsed_changed(collapsed: bool)   # la mano se ocultó o se mostró
signal hand_changed(count: int)             # cambió el número de cartas en la mano

# Tamaño base notablemente mayor (Ancho x Alto)
@export var card_size: Vector2 = Vector2(320, 420)

# Escalas del ciclo visual
@export var rest_scale: float = 0.85      # Tamaño base en reposo en la mano
@export var hover_scale: float = 1.0     # Al pasar el cursor encima
@export var select_scale: float = 1.15     # Vista ampliada al seleccionar para usar

# Distribución del abanico
@export var fan_spacing: float = 200.0     # Separación horizontal amplia entre comodines
@export var fan_angle_deg: float = 8.5     # Inclinación angular
@export var fan_arc: float = 20.0          # Curvatura del abanico

# Desplazamientos al interactuar
@export var hover_lift: float = 110.0      # Altura que sube al resaltar
@export var hover_push: float = 70.0       # Espacio que empuja a las cartas vecinas

# Márgenes respecto al borde de la pantalla (evita que queden fuera del encuadre)
@export var margin_right: float = 110.0
@export var margin_bottom: float = 120.0

@export var showcase_anchor: Vector2 = Vector2(0.73, 0.44)

# --- Ocultar / mostrar la mano ---
@export var collapse_time: float = 0.55      # duración de la animación (s)
@export var collapse_stagger: float = 0.12   # desfase entre cartas (0 = todas a la vez)
@export var collapse_peek: float = 0.0       # px de las cartas que asoman al ocultar (0 = ocultas del todo)

const HIDE_SCALE: float = 0.85    # las cartas se encogen un poco al esconderse
const HIDE_SPREAD: float = 0.55   # y se juntan (0 = no se juntan, 1 = se apilan)

var _cards: Array[JokerUI] = []   # cartas vivas (las que arden ya no están aquí)
var _hovered: JokerUI = null
var _selected: JokerUI = null

var _collapsed: bool = false
var collapse_t: float = 0.0       # 0 = mano abierta, 1 = oculta (el tween lo pasa un poco de 0 o 1 para el rebote)
var _collapse_tween: Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # la mano no bloquea clics de otros botones


func _process(_delta: float) -> void:
	_update_hover()
	_update_targets()


# ---------------------------------------------------------------- API pública

## Agrega una carta ya configurada con setup(). "delay" escalona la entrada.
func add_joker(joker: JokerUI, delay: float = 0.0) -> void:
	_cards.append(joker)
	add_child(joker)
	joker.joker_selected.connect(_on_card_pressed)
	joker.burn_started.connect(_on_card_burn_started)
	joker.tree_exiting.connect(_on_card_gone.bind(joker))
	_update_targets()
	var vp: Vector2 = get_viewport_rect().size
	# Vuelan desde fuera de la pantalla (abajo a la derecha) girando hasta su sitio
	joker.appear(delay, Vector2(vp.x + 120.0, vp.y + 220.0), 0.7)
	joker.mouse_filter = Control.MOUSE_FILTER_IGNORE if _collapsed else Control.MOUSE_FILTER_STOP
	hand_changed.emit(_cards.size())


func clear_hand() -> void:
	for c in _cards:
		if is_instance_valid(c):
			c.queue_free()
	_cards.clear()
	_hovered = null
	_selected = null
	hand_changed.emit(0)


func get_selected() -> JokerUI:
	return _selected if is_instance_valid(_selected) else null


## Centro (en coordenadas de esta mano) donde se muestra la carta elegida.
func get_showcase_center() -> Vector2:
	var vp: Vector2 = get_viewport_rect().size
	return Vector2(vp.x * showcase_anchor.x, vp.y * showcase_anchor.y)


func is_collapsed() -> bool:
	return _collapsed


func get_count() -> int:
	return _cards.size()


## Centro del abanico (en coordenadas de esta mano); tableui.gd lo usa para colocar el botón.
func get_hand_center() -> Vector2:
	return _hand_base()


## ¿Hay cartas todavía volando hacia la mano? (no conviene ocultarla en ese momento)
func is_entering() -> bool:
	for c in _cards:
		if is_instance_valid(c) and c.is_animating_entrance:
			return true
	return false


## Oculta (true) o muestra (false) la mano con una animación en cascada.
## Con animate = false el cambio es instantáneo.
func set_collapsed(value: bool, animate: bool = true) -> void:
	if value == _collapsed:
		return
	_collapsed = value
	if value:
		deselect()   # una carta elegida vuelve a la mano antes de esconderse
	_apply_input_state()
	if _collapse_tween != null and _collapse_tween.is_valid():
		_collapse_tween.kill()
	var target: float = 1.0 if value else 0.0
	if animate:
		# Ocultar: las cartas caen acelerando (QUAD ease-in) y en cascada.
		# Mostrar: suben pasándose un poco de su sitio y rebotan (BACK ease-out).
		_collapse_tween = create_tween()
		if value:
			_collapse_tween.tween_property(self, "collapse_t", target, collapse_time * 0.8) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		else:
			_collapse_tween.tween_property(self, "collapse_t", target, collapse_time) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		collapse_t = target
	collapsed_changed.emit(value)


func toggle_collapsed() -> void:
	if is_entering():
		return
	# Si aún se está animando, se ignora el clic (evita saltos al cambiar de sentido a medias)
	if _collapse_tween != null and _collapse_tween.is_valid() and _collapse_tween.is_running():
		return
	set_collapsed(not _collapsed)


# Con la mano oculta las cartas no reciben clics.
func _apply_input_state() -> void:
	var f: int = Control.MOUSE_FILTER_IGNORE if _collapsed else Control.MOUSE_FILTER_STOP
	for c in _cards:
		if is_instance_valid(c):
			c.mouse_filter = f


## Saca la carta de la mano, la gira para mostrar la descripción y opaca las demás.
func select(joker: JokerUI) -> void:
	if joker == _selected or _collapsed:
		return
	if _selected != null and is_instance_valid(_selected):
		_selected.girar_a_titulo()
		_selected.set_picked(false)
	_selected = joker
	_selected.girar_a_descripcion()
	_selected.set_picked(true)
	if _hovered != null and is_instance_valid(_hovered):
		_hovered.set_hover(false)
	_hovered = null
	for c in _cards:
		c.set_dimmed(c != joker)
	_reorder()


## La carta elegida vuelve a su lugar en la mano.
func deselect() -> void:
	if _selected != null and is_instance_valid(_selected):
		_selected.girar_a_titulo()
		_selected.set_picked(false)
	_selected = null
	for c in _cards:
		c.set_dimmed(false)
	_reorder()


## Quema la carta elegida; las que quedan se reacomodan solas en el abanico.
func consume_selected() -> void:
	if _selected == null or not is_instance_valid(_selected):
		return
	var j: JokerUI = _selected
	_selected = null
	for c in _cards:
		c.set_dimmed(false)
	j.quemar_y_destruir()   # emite burn_started -> _on_card_burn_started la saca de _cards


# ---------------------------------------------------------------- señales de las cartas

func _on_card_pressed(c) -> void:
	joker_selected.emit(c)


func _on_card_burn_started(c) -> void:
	_cards.erase(c)
	if c == _hovered:
		_hovered = null
	if c == _selected:
		_selected = null
	_reorder()
	hand_changed.emit(_cards.size())


func _on_card_gone(c: JokerUI) -> void:
	var estaba: bool = _cards.has(c)
	_cards.erase(c)
	if c == _hovered:
		_hovered = null
	if c == _selected:
		_selected = null
	if estaba:
		hand_changed.emit(_cards.size())


# ---------------------------------------------------------------- geometría del abanico

func _hand_base() -> Vector2:
	var vp: Vector2 = get_viewport_rect().size
	var half_w: float = (fan_spacing * 2.0 + card_size.x * rest_scale) * 0.5   # ancho de 3 cartas
	return Vector2(vp.x - margin_right - half_w, vp.y - margin_bottom - card_size.y * rest_scale * 0.5)


func _fan_center(i: int, n: int) -> Vector2:
	var t: float = float(i) - float(n - 1) * 0.5     # -1, 0, 1 con 3 cartas
	return _hand_base() + Vector2(t * fan_spacing, t * t * fan_arc)


func _fan_cards() -> Array[JokerUI]:
	var out: Array[JokerUI] = []
	for c in _cards:
		if is_instance_valid(c) and c != _selected:
			out.append(c)
	return out


func _update_targets() -> void:
	var fan: Array[JokerUI] = _fan_cards()
	var n: int = fan.size()
	var hover_idx: int = -1
	if _hovered != null:
		hover_idx = fan.find(_hovered)
	var hide_dy: float = _hidden_offset_y()
	var hb: Vector2 = _hand_base()

	for i in n:
		var t: float = float(i) - float(n - 1) * 0.5
		var center: Vector2 = _fan_center(i, n)
		var rot: float = deg_to_rad(t * fan_angle_deg)
		var sc: float = rest_scale
		if hover_idx >= 0:
			if i == hover_idx:
				center.y -= hover_lift       # sube, se endereza y crece
				rot = 0.0
				sc = hover_scale
			else:
				var d: float = float(i - hover_idx)
				center.x += signf(d) * hover_push / absf(d)   # las vecinas le hacen sitio
		# Ocultar/mostrar: las cartas se juntan, se enderezan, se encogen y bajan (en cascada)
		var lt: float = _local_collapse(i, n)
		var k: float = clampf(lt, 0.0, 1.0)
		center.x = hb.x + (center.x - hb.x) * (1.0 - HIDE_SPREAD * k)
		center.y += hide_dy * lt
		rot *= (1.0 - k)
		sc = lerpf(sc, rest_scale * HIDE_SCALE, k)
		fan[i].set_pose(center, rot, sc)

	if _selected != null and is_instance_valid(_selected):
		_selected.set_pose(get_showcase_center(), 0.0, select_scale)


# Progreso de ocultado de la carta i (0 = en su sitio, 1 = oculta). Cada carta arranca un poco
# después que la anterior; el rebote del tween (collapse_t fuera de 0..1) se suma a todas.
func _local_collapse(i: int, n: int) -> float:
	var base: float
	if n <= 1 or collapse_stagger <= 0.0:
		base = clampf(collapse_t, 0.0, 1.0)
	else:
		var s: float = minf(collapse_stagger, 0.9 / float(n - 1))
		var rank: int = i if _collapsed else (n - 1 - i)   # se ocultan y aparecen de izquierda a derecha
		base = clampf((collapse_t - float(rank) * s) / (1.0 - float(n - 1) * s), 0.0, 1.0)
	return base + minf(collapse_t, 0.0)


# Cuánto hay que bajar las cartas para que queden fuera de la pantalla (o asomando collapse_peek px)
func _hidden_offset_y() -> float:
	var vp: Vector2 = get_viewport_rect().size
	var half_h: float = card_size.y * rest_scale * HIDE_SCALE * 0.5
	var holgura: float = 30.0 if collapse_peek <= 0.0 else 0.0
	return (vp.y - collapse_peek + holgura + half_h) - _hand_base().y


# ---------------------------------------------------------------- hover estable

# El hover NO se decide con el rectángulo de la carta (que se mueve al subir y provoca
# parpadeo), sino con su "casilla" fija en el abanico + un margen de histéresis.

func _slot_rect(i: int, n: int) -> Rect2:
	var c: Vector2 = _fan_center(i, n)
	var sz: Vector2 = card_size * rest_scale
	var r: Rect2 = Rect2(c - sz * 0.5, sz)
	r.position.y -= hover_lift       # la casilla incluye la zona a la que sube la carta
	r.size.y += hover_lift
	return r


func _hover_allowed() -> bool:
	# Si hay otro control encima (p. ej. el menú de pausa) no se debe levantar nada.
	var hc: Control = get_viewport().gui_get_hovered_control()
	if hc == null or hc is JokerUI:
		return true
	return hc.is_ancestor_of(self)   # el Control raíz de la UI sí cuenta como "nada encima"


func _pick_hovered() -> JokerUI:
	var fan: Array[JokerUI] = _fan_cards()
	var n: int = fan.size()
	var mp: Vector2 = get_local_mouse_position()
	var best: JokerUI = null
	var best_d: float = INF
	for i in n:
		var c: JokerUI = fan[i]
		if not c.can_interact():
			continue
		var r: Rect2 = _slot_rect(i, n)
		if c == _hovered:
			r = r.grow(14.0)   # histéresis: cuesta más "soltar" la carta que ya señalas
		if r.has_point(mp):
			var d: float = absf(mp.x - _fan_center(i, n).x)
			if d < best_d:
				best_d = d
				best = c
	return best


func _update_hover() -> void:
	var nuevo: JokerUI = null
	if not _collapsed and collapse_t < 0.05 and _hover_allowed():
		nuevo = _pick_hovered()
	if nuevo == _hovered:
		return
	if _hovered != null and is_instance_valid(_hovered):
		_hovered.set_hover(false)
	_hovered = nuevo
	if _hovered != null:
		_hovered.set_hover(true)
	_reorder()


# El orden de los hijos decide quién se dibuja encima: normales < señalada < elegida
# (z_index no se usa a propósito: taparía el menú de pausa).
func _reorder() -> void:
	var ordered: Array[JokerUI] = []
	for c in _cards:
		if is_instance_valid(c) and c != _hovered and c != _selected:
			ordered.append(c)
	if _hovered != null and is_instance_valid(_hovered) and _hovered != _selected:
		ordered.append(_hovered)
	if _selected != null and is_instance_valid(_selected):
		ordered.append(_selected)
	for i in ordered.size():
		if ordered[i].get_parent() == self:
			move_child(ordered[i], i)
