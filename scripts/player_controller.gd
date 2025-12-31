class_name PlayerCharacter
extends CharacterBody3D

@export_group("Movement")
@export var walk_speed := 6.0
@export var sprint_speed := 8.5
@export var jump_velocity := 7.0
@export var auto_b_hop := true

# Layer Mask Refs
const DEFAULT_LAYER = 1
const VIEW_MODEL_LAYER = 2

# Init variables
@onready var view_model: Node3D = %WorldModel
@onready var camera: Camera3D = %PlayerCamera
@onready var head_anchor: Marker3D = %HeadAnchor
@onready var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8) * 1.75
var wish_direction := Vector3.ZERO

func _init() -> void:
	GameManager.player_character = self

func _ready() -> void:
	# set view model objects invisible to camera
	for child: VisualInstance3D in %WorldModel.find_children("*", "VisualInstance3D"):
		child.set_layer_mask_value(DEFAULT_LAYER, false)
		child.set_layer_mask_value(VIEW_MODEL_LAYER, true)
	camera.set_cull_mask_value(VIEW_MODEL_LAYER, false)

func _handle_air_physics(delta: float) -> void:
	self.velocity.y -= gravity * delta
	self.velocity.x = lerp(self.velocity.x, wish_direction.x * get_move_speed(), delta * 2.0)
	self.velocity.z = lerp(self.velocity.z, wish_direction.z * get_move_speed(), delta * 2.0)

func _handle_ground_physics(_delta: float) -> void:
	self.velocity.x = wish_direction.x * get_move_speed()
	self.velocity.z = wish_direction.z * get_move_speed()

func _physics_process(delta: float) -> void:
	var input_dir = Input.get_vector("left", "right", "down", "up").normalized()
	wish_direction = self.global_transform.basis * Vector3(input_dir.x, 0.0, -input_dir.y)
	
	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			self.velocity.y = jump_velocity
		_handle_ground_physics(delta)
	else:
		_handle_air_physics(delta)
	
	move_and_slide()

func _process(_delta: float) -> void:
	pass

func get_move_speed() -> float:
	return sprint_speed if Input.is_action_pressed("sprint") else walk_speed
