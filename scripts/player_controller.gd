class_name PlayerCharacter
extends CharacterBody3D

enum MoveState {
	GROUND,
	SPRINT,
	CROUCH,
	AIR
}

@export_group("Movement")
@export var minimum_air_control_speed := 3.0
@export var walk_speed := 6.0
@export var sprint_speed := 8.5
@export var sprint_strafe_multiplier := 0.85
@export var jump_velocity := 7.0
@export var coyote_time := 0.12   # seconds

@export_group("Crouch Movement")
@export var crouch_speed := 3.0
@export var crouch_height := 1.2
@export var stand_height := 1.8
@export var crouch_camera_offset := -0.6
@export var crouch_transition_speed := 10.0

# Layer Mask Refs
const DEFAULT_LAYER = 1
const VIEW_MODEL_LAYER = 2

# Init variables
@onready var view_model: Node3D = %WorldModel
@onready var camera: Camera3D = %PlayerCamera
@onready var head_anchor: Marker3D = %HeadAnchor
@onready var collider: CollisionShape3D = %Collider
@onready var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8) * 1.75
@onready var _eye_height_local := head_anchor.position.y

# Debug
@onready var debug_label: Label = %DebugLabel

# states
var move_state: MoveState = MoveState.GROUND
var previous_ground_state: MoveState = MoveState.GROUND

var _coyote_timer := 0.0
var _move_input_world := Vector3.ZERO
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
	
	if _move_input_world.length() < 0.01:
		return
	
	var horizontal := Vector3(self.velocity.x, 0, self.velocity.z)
	
	# Direction only (no speed)
	var dir := _move_input_world.normalized()

	# Lock air speed to takeoff speed
	var target := dir * maxf(_air_speed_cap, minimum_air_control_speed)

	horizontal = horizontal.lerp(target, delta * 3.0)

	self.velocity.x = horizontal.x
	self.velocity.z = horizontal.z

func _handle_ground_physics(delta: float, move_speed: float) -> void:
	if _move_input_world.length() == 0:
		self.velocity.x = lerp(self.velocity.x, 0.0, delta * 7.0)
		self.velocity.z = lerp(self.velocity.z, 0.0, delta * 7.0)
		return

	var _basis := global_transform.basis
	var forward := -_basis.z
	var right := _basis.x

	var forward_amount := _move_input_world.dot(forward)
	var strafe_amount := _move_input_world.dot(right)

	var max_forward := move_speed
	var max_strafe := move_speed

	if move_state == MoveState.SPRINT:
		max_strafe *= sprint_strafe_multiplier
		if forward_amount < 0.1:
			max_forward *= sprint_strafe_multiplier

	var desired := forward * forward_amount * max_forward + right * strafe_amount * max_strafe

	self.velocity.x = desired.x
	self.velocity.z = desired.z

func _handle_ground_movement(delta: float, move_speed: float) -> void:
	if InputRouter.wants_to_jump() and _coyote_timer > 0.0:
		_handle_jump()
		return # prevents ground movement this frame
	_handle_ground_physics(delta, move_speed)

func _physics_process(delta: float) -> void:
	_handle_move_input()
	_update_move_state()
	_update_coyote_timer(delta)
	
	match move_state:
		MoveState.GROUND:
			_handle_ground_movement(delta, walk_speed)
		MoveState.SPRINT:
			_handle_ground_movement(delta, sprint_speed)
		MoveState.CROUCH:
			_handle_ground_movement(delta, crouch_speed)
		MoveState.AIR:
			_handle_air_physics(delta)
	
	move_and_slide()

func _process(delta: float) -> void:
	_update_crouch_visuals(delta)
	_debug()

func _update_move_state() -> void:
	# 1. AIR overrides everything
	if not is_on_floor():
		if move_state != MoveState.AIR:
			previous_ground_state = move_state
		move_state = MoveState.AIR
		return

	# 2. Handle crouch input (grounded only)
	if InputRouter.crouch:
		if move_state != MoveState.CROUCH:
			previous_ground_state = move_state
			InputRouter.on_crouch_started()
		move_state = MoveState.CROUCH
		return

	# 3. Attempt to stand up from crouch
	if move_state == MoveState.CROUCH and not InputRouter.crouch:
		if not _can_stand():
			# Forced crouch due to ceiling
			move_state = MoveState.CROUCH
			return
		# Can stand → continue to evaluate next state

	# 4. Determine desired grounded state
	var next_ground_state: MoveState

	if InputRouter.sprint and _move_input_world.length() > 0.1:
		next_ground_state = MoveState.SPRINT
	else:
		next_ground_state = MoveState.GROUND

	# 5. Track previous grounded state changes
	if move_state != MoveState.AIR and move_state != next_ground_state:
		previous_ground_state = move_state

	move_state = next_ground_state

func _update_coyote_timer(delta: float) -> void:
	if move_state == MoveState.AIR:
		_coyote_timer -= delta
	else:
		_coyote_timer = coyote_time

func _handle_move_input() -> void:
	var input_dir = InputRouter.move
	_move_input_world = self.global_transform.basis * Vector3(input_dir.x, 0.0, -input_dir.y)

func _handle_jump() -> void:
	previous_ground_state = move_state # capture intent
	self.velocity.y = jump_velocity
	_air_speed_cap = Vector3(self.velocity.x, 0, self.velocity.z).length()
	_coyote_timer = 0.0
	InputRouter.consume_jump()

func _update_crouch_visuals(delta: float) -> void:
	var shape := collider.shape as CapsuleShape3D

	var target_height := stand_height
	var target_camera_y := _eye_height_local

	if move_state == MoveState.CROUCH:
		target_height = crouch_height
		target_camera_y = _eye_height_local + crouch_camera_offset

	shape.height = lerp(
		shape.height,
		target_height,
		delta * crouch_transition_speed
	)

	var cam_pos := head_anchor.position
	cam_pos.y = lerp(
		cam_pos.y,
		target_camera_y,
		delta * crouch_transition_speed
	)
	head_anchor.position = cam_pos

func _can_stand() -> bool:
	var shape := collider.shape as CapsuleShape3D
	var original_height := shape.height

	shape.height = stand_height
	var can_stand := not test_move(
		global_transform,
		Vector3.UP * (stand_height - shape.height)
	)
	shape.height = original_height

	return can_stand

#debug
func _debug() -> void:
	debug_label.text = "
		state: %s
		prev_ground: %s
		on_floor: %s
	" % [
		MoveState.keys()[move_state],
		MoveState.keys()[previous_ground_state],
		is_on_floor()
	]
