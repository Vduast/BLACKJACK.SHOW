extends Node3D
class_name DealerAnim

@onready var anim_tree = $AnimationPlayer/AnimationTree
@onready var right_arm = $BrazoD
@onready var left_arm = $BrazoI

# --- SKELETON REFERENCE ---
@onready var skeleton = $Armature/Skeleton3D 

var rest_pos_r: Vector3
var rest_pos_l: Vector3

# --- HEAD VARIABLES ---
var head_idx: int = -1
var look_target: Node3D = null
var look_weight: float = 0.0

# Adjust this in the Inspector (e.g., 90 or -90 in X) if the model looks at the ceiling
@export var head_correction: Vector3 = Vector3.ZERO 

func _ready():
	rest_pos_r = right_arm.global_position
	rest_pos_l = left_arm.global_position
	anim_tree.active = true
	anim_tree.set("parameters/MezclarHablar/blend_amount", 0.0)
	
	if is_instance_valid(skeleton):
		head_idx = skeleton.find_bone("Bone.003")

func _process(_delta):
	if is_instance_valid(skeleton) and head_idx != -1:
		if is_instance_valid(look_target) and look_weight > 0.0:
			var current_head_pose = skeleton.get_bone_global_pose(head_idx)
			var head_global_pos = skeleton.to_global(current_head_pose.origin)
			
			# Protection against head shrinking
			var original_scale = current_head_pose.basis.get_scale()
			
			var look_transform = Transform3D(Basis(), head_global_pos).looking_at(look_target.global_position, Vector3.UP)
			
			# Apply Blender axis correction
			look_transform.basis = look_transform.basis * Basis.from_euler(Vector3(
				deg_to_rad(head_correction.x),
				deg_to_rad(head_correction.y),
				deg_to_rad(head_correction.z)
			))
			
			var final_pose = skeleton.global_transform.affine_inverse() * look_transform
			final_pose.basis = final_pose.basis.orthonormalized().scaled(original_scale)
			
			skeleton.set_bone_global_pose_override(head_idx, final_pose, look_weight, true)
		
		elif look_weight == 0.0:
			skeleton.set_bone_global_pose_override(head_idx, Transform3D(), 0.0, false)

# --- ARM MOVEMENT ---
func deal_to_position(target_position: Vector3):
	var dist_r = rest_pos_r.distance_to(target_position)
	var dist_l = rest_pos_l.distance_to(target_position)
	
	if dist_r < dist_l:
		_animate_arm("Right", right_arm, rest_pos_r, target_position)
	else:
		_animate_arm("Left", left_arm, rest_pos_l, target_position)

func _animate_arm(side: String, target_node: Node3D, rest_pos: Vector3, final_pos: Vector3):
	var transition_path = "parameters/EstadoDER/transition_request" if side == "Right" else "parameters/EstadoIZQ/transition_request"
	var anim_move = "HandMoveR" if side == "Right" else "HandMoveL"
	var anim_idle = "HandIdleR" if side == "Right" else "HandIdleL"

	anim_tree.set(transition_path, anim_move)
	
	var tween = create_tween()
	tween.tween_property(target_node, "global_position", final_pos, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.1)
	tween.tween_property(target_node, "global_position", rest_pos, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func(): anim_tree.set(transition_path, anim_idle))

func speak(is_active: bool):
	var value = 1.0 if is_active else 0.0
	var tween = create_tween()
	tween.tween_property(anim_tree, "parameters/MezclarHablar/blend_amount", value, 0.2)

# --- LOOK CONTROL ---
func look_at_target(target: Node3D):
	# We look for the active camera in the scene (the player's eyes)
	var camera = get_viewport().get_camera_3d()
	
	# If the camera exists, the target will be the camera; if not, it will be the original target
	var real_target = camera if is_instance_valid(camera) else target
	
	if look_target == real_target: 
		return 
		
	look_target = real_target
	
	if look_weight < 1.0:
		var tween = create_tween()
		tween.tween_property(self, "look_weight", 1.0, 0.5).set_trans(Tween.TRANS_SINE) 

func stop_looking():
	var tween = create_tween()
	tween.tween_property(self, "look_weight", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func(): look_target = null)
