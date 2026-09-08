class_name AudioPool
extends RefCounted

## Pool de reproductores de audio reutilizable (round-robin) para reproducir
## varios efectos de sonido simultáneos sin cortar el anterior.
##
## Funciona con AudioStreamPlayer, AudioStreamPlayer2D o AudioStreamPlayer3D
## (los tres exponen los mismos métodos: play/stop/stream/pitch_scale),
## por eso se guardan como Node en vez de un tipo específico.
##
## USO:
##   var sfx := AudioPool.new()
##   func _ready():
##       sfx.setup(sfx_player_node, 3)   # el nodo YA presente en la escena
##   ...
##       sfx.play(snd_deal)              # en cualquier parte del script

var _pool: Array[Node] = []
var _index: int = 0

## template: un AudioStreamPlayer / AudioStreamPlayer2D / AudioStreamPlayer3D
## YA presente en la escena (con su bus configurado).
## pool_size: cuántas voces simultáneas quieres (se duplica el template pool_size - 1 veces).
func setup(template: Node, pool_size: int = 3) -> void:
	_pool.clear()
	_index = 0
	if not is_instance_valid(template):
		push_warning("AudioPool.setup: el nodo template no es válido.")
		return
	if not (template is AudioStreamPlayer or template is AudioStreamPlayer2D or template is AudioStreamPlayer3D):
		push_warning("AudioPool.setup: el nodo template debe ser AudioStreamPlayer, AudioStreamPlayer2D o AudioStreamPlayer3D.")
		return

	_pool.append(template)
	var parent := template.get_parent()
	for i in range(pool_size - 1):
		var extra := template.duplicate()
		if is_instance_valid(parent):
			parent.add_child(extra)
		_pool.append(extra)

## Reproduce un sonido usando la siguiente voz libre del pool.
func play(stream: AudioStream, randomize_pitch: bool = true) -> void:
	if stream == null or _pool.is_empty():
		return

	var player: Node = _pool[_index]
	player.stop()
	player.stream = stream
	player.pitch_scale = randf_range(0.85, 1.15) if randomize_pitch else 1.0
	player.play()
	_index = (_index + 1) % _pool.size()
