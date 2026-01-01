class_name PlayerCharacter
extends CharacterBody3D

enum MoveState {
	GROUND,
	SPRINT,
	CROUCH,
	SLIDE,
	AIR
}

@export_group("Movement")
@export var minimum_air_control_speed := 2.0
@export var walk_speed := 6.0
@export var sprint_speed := 8.5
@export var sprint_strafe_multiplier := 0.85
@export var jump_velocity := 7.0
@export var coyote_time := 0.12   # seconds

@export_group("Crouch Movement")
@export var crouch_speed := 3.0
@export var crouch_height := 1.2
@export var stand_height := 1.8
@export var eye_height_stand := 1.8
@export var crouch_camera_offset := -0.6
@export var crouch_transition_speed := 10.0

@export_group("Slide", "slide")
@export var slide_start_speed := 10.0
@export var slide_min_speed := 4.0
@export var slide_friction := 8.0
@export var slide_duration := 3
@export var slide_slope_boost := 18.0

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
var wants_crouch := false

var _coyote_timer := 0.0
var _move_input_world := Vector3.ZERO
var _air_speed_cap := 0.0
var _slide_velocity := Vector3.ZERO
var _slide_timer := 0.0

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

func _handle_slide_physics(delta: float) -> void:
	_slide_timer -= delta

	# Gravity still applies
	self.velocity.y -= gravity * delta

	# Slope acceleration
	var floor_normal := get_floor_normal()
	var downhill := floor_normal.cross(Vector3.UP).cross(floor_normal).normalized()

	var slope_factor: float = clamp(downhill.dot(_slide_velocity.normalized()), -1.0, 1.0)
	_slide_velocity += downhill * slope_factor * slide_slope_boost * delta

	# Friction
	_slide_velocity = _slide_velocity.move_toward(Vector3.ZERO, slide_friction * delta)

	self.velocity.x = _slide_velocity.x
	self.velocity.z = _slide_velocity.z

	# Exit conditions
	if _slide_timer <= 0.0:
		_exit_slide()
	elif _slide_velocity.length() < slide_min_speed:
		_exit_slide()

func _exit_slide() -> void:
	velocity.x = _slide_velocity.x
	velocity.z = _slide_velocity.z

	if wants_crouch:
		move_state = MoveState.CROUCH
	elif InputRouter.sprint and _move_input_world.length() > 0.1:
		move_state = MoveState.SPRINT
	else:
		move_state = MoveState.GROUND

func _handle_ground_movement(delta: float, move_speed: float) -> void:
	if InputRouter.wants_to_jump() and _coyote_timer > 0.0:
		_handle_jump()
		return # prevents ground movement this frame
	_handle_ground_physics(delta, move_speed)

func _physics_process(delta: float) -> void:
	_handle_move_input()
	_update_move_state()
	_update_coyote_timer(delta)
	_update_crouch_visuals(delta)

	match move_state:
		MoveState.GROUND:
			_handle_ground_movement(delta, walk_speed)
		MoveState.SPRINT:
			_handle_ground_movement(delta, sprint_speed)
		MoveState.SLIDE:
			_handle_slide_physics(delta)
		MoveState.CROUCH:
			_handle_ground_movement(delta, crouch_speed)
		MoveState.AIR:
			_handle_air_physics(delta)
	
	move_and_slide()

func _process(_delta: float) -> void:
	_debug()

func _update_move_state() -> void:
	# AIR overrides locomotion, not posture
	if not is_on_floor():
		if move_state != MoveState.AIR:
			previous_ground_state = move_state
		move_state = MoveState.AIR
		return
	
	# SLIDE owns the state until it exits itself
	if move_state == MoveState.SLIDE:
		if InputRouter.wants_to_jump():
			_handle_jump()
			return
		return
	
	# Grounded states
	if wants_crouch:
		var sprint_jump_to_slide = move_state == MoveState.AIR and previous_ground_state == MoveState.SPRINT
		if move_state == MoveState.SPRINT or sprint_jump_to_slide:
			_enter_slide()
			return
		if move_state != MoveState.CROUCH:
			previous_ground_state = move_state
			InputRouter.on_crouch_started()
		move_state = MoveState.CROUCH
		return

	if InputRouter.sprint and _move_input_world.length() > 0.1:
		move_state = MoveState.SPRINT
	else:
		move_state = MoveState.GROUND

func _update_coyote_timer(delta: float) -> void:
	if move_state == MoveState.AIR:
		_coyote_timer -= delta
	else:
		_coyote_timer = coyote_time

func _handle_move_input() -> void:
	var input_dir = InputRouter.move
	_move_input_world = self.global_transform.basis * Vector3(input_dir.x, 0.0, -input_dir.y)
	wants_crouch = InputRouter.crouch

func _handle_jump() -> void:
	previous_ground_state = move_state # capture intent
	self.velocity.y = jump_velocity
	_air_speed_cap = Vector3(self.velocity.x, 0, self.velocity.z).length()
	_coyote_timer = 0.0
	InputRouter.reset_crouch_if_toggled()
	InputRouter.consume_jump()

func _enter_slide() -> void:
	move_state = MoveState.SLIDE
	_slide_timer = slide_duration

	var horizontal := Vector3(velocity.x, 0, velocity.z)
	var dir := horizontal.normalized()
	if dir.length() < 0.1:
		dir = -global_transform.basis.z

	_slide_velocity = dir * max(horizontal.length(), slide_start_speed)

func _update_crouch_visuals(delta: float) -> void:
	var shape := collider.shape as CapsuleShape3D

	# Desired capsule height (intent)
	var desired_height := stand_height
	if wants_crouch:
		desired_height = crouch_height

	# Clamp based on ceiling
	var max_allowed_height := _get_max_stand_height()
	var final_height: float = min(desired_height, max_allowed_height)

	# Smooth capsule resize
	shape.height = lerp(
		shape.height,
		final_height,
		delta * crouch_transition_speed
	)

	# Camera height derived from ACTUAL capsule height
	var target_eye_y := _get_eye_height_for_capsule(shape.height)

	var cam_pos := head_anchor.position
	cam_pos.y = lerp(
		cam_pos.y,
		target_eye_y,
		delta * crouch_transition_speed
	)
	head_anchor.position = cam_pos

func _get_max_stand_height() -> float:
	var shape := collider.shape as CapsuleShape3D
	var original_height := shape.height

	# Try full stand first
	shape.height = stand_height
	if not test_move(global_transform, Vector3.UP * 0.01):
		shape.height = original_height
		return stand_height

	# Binary search for max safe height
	var low := crouch_height
	var high := stand_height
	var best := low

	for i in 5:
		var mid := (low + high) * 0.5
		shape.height = mid

		if test_move(global_transform, Vector3.UP * 0.01):
			high = mid
		else:
			best = mid
			low = mid

	shape.height = original_height
	return best

func _get_eye_height_for_capsule(capsule_height: float) -> float:
	var t := inverse_lerp(crouch_height, stand_height, capsule_height)
	return lerp(
		_eye_height_local + crouch_camera_offset,
		_eye_height_local,
		t
	)

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
