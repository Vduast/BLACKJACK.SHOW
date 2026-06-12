extends Area3D

@export var viewport: SubViewport
@export var mesh_instance: MeshInstance3D

func _ready():
	if not mesh_instance or not viewport: return
	await get_tree().process_frame
	
	var material = mesh_instance.get_active_material(0)
	if material == null:
		material = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mesh_instance.set_surface_override_material(0, material)
	
	material.albedo_texture = viewport.get_texture()

# --- INPUT DEL RATÓN ---
func _input_event(_camera, event, event_position, _normal, _shape_idx):
	# 1er Escudo: ¿Existen los nodos todavía?
	if not is_instance_valid(mesh_instance) or not is_instance_valid(viewport): return
	
	# 2do Escudo: ¿La escena ya recibió la orden de borrarse por el cambio de escena?
	if self.is_queued_for_deletion() or viewport.is_queued_for_deletion(): return
	
	# 3er Escudo: ¿Siguen conectados al árbol principal?
	if not viewport.is_inside_tree(): return 
	
	if event is InputEventMouse:
		var ev = event.duplicate()
		
		var local_pos = mesh_instance.to_local(event_position)
		var quad_size = mesh_instance.mesh.size
		
		var uv = Vector2(
			(local_pos.x / quad_size.x) + 0.5,
			-(local_pos.y / quad_size.y) + 0.5
		)
		
		var final_pos = uv * Vector2(viewport.size)
		
		ev.position = final_pos
		ev.global_position = final_pos
		
		# Última validación en el milisegundo exacto de la inyección
		if viewport.is_inside_tree() and not viewport.is_queued_for_deletion():
			viewport.push_input(ev)

# --- INPUT DEL TECLADO ---
func _unhandled_input(event):
	if not is_instance_valid(viewport): return
	if self.is_queued_for_deletion() or viewport.is_queued_for_deletion(): return
	if not viewport.is_inside_tree(): return
	
	if event is InputEventKey:
		viewport.push_input(event)
