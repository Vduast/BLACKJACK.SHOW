extends Node3D

@onready var viewport = $SubViewport
@onready var mesh = $MeshInstance3D
@onready var ui_2d = $SubViewport/ScoreBoardUI # Esta es la referencia correcta

func _ready():
	await get_tree().process_frame
	
	var material = StandardMaterial3D.new()
	material.albedo_texture = viewport.get_texture()
	material.emission_enabled = true
	material.emission_texture = viewport.get_texture()
	material.emission_energy_multiplier = 2.0 
	
	mesh.set_surface_override_material(0, material)

# ARREGLADO: Usamos ui_2d en lugar de la variable inexistente
func refresh_board(data: Array, dealer_score: int = 0):
	if is_instance_valid(ui_2d):
		ui_2d.update_data(data, dealer_score)

func show_temporary_status(text: String):
	if is_instance_valid(ui_2d):
		ui_2d.flash_status(text)
