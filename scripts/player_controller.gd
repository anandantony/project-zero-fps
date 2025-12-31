class_name PlayerCharacter
extends CharacterBody3D

@export_group("Movement")
@export var minimum_air_control_speed := 3.0
@export var walk_speed := 6.0
@export var sprint_speed := 8.5
@export var sprint_strafe_multiplier := 0.85
@export var jump_velocity := 7.0
@export var coyote_time := 0.12   # seconds

# Layer Mask Refs
const DEFAULT_LAYER = 1
const VIEW_MODEL_LAYER = 2

# Init variables
@onready var view_model: Node3D = %WorldModel
@onready var camera: Camera3D = %PlayerCamera
@onready var head_anchor: Marker3D = %HeadAnchor
@onready var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8) * 1.75

var _coyote_timer := 0.0
var _wish_direction := Vector3.ZERO
var _air_speed_cap := 0.0

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
	
	var horizontal := Vector3(velocity.x, 0, velocity.z)
	
	# Direction only (no speed)
	var dir := _wish_direction.normalized()

	# Lock air speed to takeoff speed
	var target := dir * maxf(_air_speed_cap, minimum_air_control_speed)

	horizontal = horizontal.lerp(target, delta * 3.0)

	self.velocity.x = horizontal.x
	self.velocity.z = horizontal.z

func _handle_ground_physics(delta: float) -> void:
	if _wish_direction.length() == 0:
		velocity.x = lerp(velocity.x, 0.0, delta * 7.0)
		velocity.z = lerp(velocity.z, 0.0, delta * 7.0)
		return

	var _basis := global_transform.basis

	var forward := -_basis.z
	var right := _basis.x

	var forward_amount := _wish_direction.dot(forward)
	var strafe_amount := _wish_direction.dot(right)

	var max_forward := get_move_speed()
	var max_strafe := get_move_speed()

	if InputRouter.sprint:
		max_strafe *= sprint_strafe_multiplier
		if forward_amount < 0.1:
			max_forward *= sprint_strafe_multiplier

	var desired := forward * forward_amount * max_forward + right * strafe_amount * max_strafe
	self.velocity.x = desired.x
	self.velocity.z = desired.z

func _physics_process(delta: float) -> void:
	_handle_move()
	
	if is_on_floor():
		_coyote_timer = coyote_time
		if InputRouter.wants_to_jump() and _coyote_timer > 0.0:
			_handle_jump()
		_handle_ground_physics(delta)
	else:
		_coyote_timer -= delta
		_handle_air_physics(delta)
	
	move_and_slide()

func _handle_move() -> void:
	var input_dir = InputRouter.move
	_wish_direction = self.global_transform.basis * Vector3(input_dir.x, 0.0, -input_dir.y)

func _handle_jump() -> void:
	self.velocity.y = jump_velocity
	_air_speed_cap = Vector3(velocity.x, 0, velocity.z).length()
	_coyote_timer = 0.0
	InputRouter.consume_jump()

func get_move_speed() -> float:
	return sprint_speed if InputRouter.sprint else walk_speed
