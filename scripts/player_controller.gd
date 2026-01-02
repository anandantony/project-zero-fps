class_name PlayerCharacter
extends CharacterBody3D

enum MoveState {
	GROUND,
	SPRINT,
	CROUCH,
	SLIDE,
	AIR
}

const CEILING_RAY_OFFSETS := [
	Vector3.ZERO,
	Vector3(0.25, 0, 0),
	Vector3(-0.25, 0, 0),
	Vector3(0, 0, 0.25),
	Vector3(0, 0, -0.25),
]
const HEIGHT_EPSILON := 0.03
const CEILING_CACHE_TIME := 0.1
const SLIDE_GROUND_GRACE := 0.2

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
@export var crouch_transition_speed := 15.0

@export_group("Slide", "slide")
@export var slide_start_speed := 10.0
@export var slide_min_speed := 4.0
@export var slide_friction := 8.0
@export var slide_duration := 1.2
@export var slide_slope_boost := 18.0
@export var slide_max_angle := 40.0
@export var slide_stick_force := 35.0

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
@onready var ground_check: RayCast3D = $GroundCheck
@onready var slide_ray: RayCast3D = %SlideRay

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
var _slide_ground_timer := 0.0
var _cached_max_height := stand_height
var _ceiling_cache_timer := 0.0

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

	# Gravity
	self.velocity.y -= gravity * delta

	var floor_normal := get_floor_normal()
	
	_slide_ground_timer -= delta

	if not _is_grounded():
		# Ignore brief floor loss during slide start / capsule resize
		if _slide_ground_timer <= 0.0 and velocity.y < -1.5:
			previous_ground_state = MoveState.SLIDE
			move_state = MoveState.AIR
		return
	
	# Gravity projected onto slope
	var slope_gravity := Vector3.DOWN - floor_normal * Vector3.DOWN.dot(floor_normal)

	if slope_gravity.length() > 0.001:
		slope_gravity = slope_gravity.normalized()

		var slide_dir := _slide_velocity.normalized()
		var alignment := slope_gravity.dot(slide_dir)
		if _is_grounded():
			var n := get_floor_normal()
			var downhill := slope_gravity.dot(slide_dir)
			if downhill > 0.0:
				self.velocity += -n * slide_stick_force * downhill * delta
		if alignment > 0.0:
			# Downhill acceleration
			_slide_velocity += slope_gravity * slide_slope_boost * alignment * delta
		elif alignment < 0.0:
			# Uphill braking (stronger than normal friction)
			_slide_velocity = _slide_velocity.move_toward(
				Vector3.ZERO,
				slide_friction * (1.0 + -alignment * 2.0) * delta
			)

	# Friction
	_slide_velocity = _slide_velocity.move_toward(Vector3.ZERO, slide_friction * delta)

	self.velocity.x = _slide_velocity.x
	self.velocity.z = _slide_velocity.z

	if _slide_timer <= 0.0 or _slide_velocity.length() < slide_min_speed:
		_exit_slide()

func _exit_slide() -> void:
	self.velocity.x = _slide_velocity.x
	self.velocity.z = _slide_velocity.z

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
	_update_ceiling_cache(delta)
	_update_crouch_visuals(delta)
	
	var forced_crouch := _is_physically_crouched()
	
	match move_state:
		MoveState.GROUND:
			_handle_ground_movement(delta, crouch_speed if forced_crouch else walk_speed)
		MoveState.SPRINT:
			_handle_ground_movement(delta, crouch_speed if forced_crouch else sprint_speed)
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
	# SLIDE owns the state until it exits itself
	if move_state == MoveState.SLIDE:
		if InputRouter.wants_to_jump():
			_handle_jump()
			return
		return
	
	# AIR overrides locomotion, not posture
	if not _is_grounded():
		if move_state == MoveState.SLIDE:
			return # slide decides when to exit
		if move_state != MoveState.AIR:
			previous_ground_state = move_state
		move_state = MoveState.AIR
		return
	
	# Grounded states
	if wants_crouch:
		var wants_slide = (
			move_state == MoveState.SPRINT
			or (
				move_state == MoveState.AIR
				and previous_ground_state == MoveState.SPRINT
			) 
		)
		if wants_slide and _can_slide_on_floor():
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

func _can_slide_on_floor() -> bool:
	if not _is_grounded():
		return false

	if not slide_ray.is_colliding():
		return false

	var n := slide_ray.get_collision_normal()
	var dot := n.dot(Vector3.UP)

	# Reject walls / cliffs
	if dot < 0.2:
		return false

	return true

func _enter_slide() -> void:
	previous_ground_state = MoveState.SPRINT
	move_state = MoveState.SLIDE
	_slide_timer = slide_duration
	_slide_ground_timer = SLIDE_GROUND_GRACE
	
	var horizontal := Vector3(velocity.x, 0, velocity.z)
	var dir := horizontal.normalized()
	if dir.length() < 0.1:
		dir = -global_transform.basis.z

	_slide_velocity = dir * max(horizontal.length(), slide_start_speed)

func _update_ceiling_cache(delta: float) -> void:
	_ceiling_cache_timer -= delta
	if _ceiling_cache_timer > 0.0:
		return

	_ceiling_cache_timer = CEILING_CACHE_TIME
	_cached_max_height = _get_max_stand_height()

func _update_crouch_visuals(delta: float) -> void:
	var shape := collider.shape as CapsuleShape3D

	var desired_height := crouch_height if wants_crouch else stand_height

	var old_height := shape.height
	var max_growth := _cached_max_height

	var target_height: float = min(desired_height, max_growth)
	
	if wants_crouch:
		# Only allow shrinking
		target_height = min(target_height, old_height)
	else:
		# Only allow growth
		target_height = max(target_height, old_height)
	
	if abs(target_height - old_height) < HEIGHT_EPSILON:
		target_height = old_height

	# IMPORTANT: never overshoot available space
	var new_height := move_toward(
		old_height,
		target_height,
		delta * crouch_transition_speed
	)

	shape.height = new_height

	# Anchor bottom
	var half_delta := (new_height - old_height) * 0.5
	global_position.y -= half_delta

	# Camera follows actual capsule
	var target_eye_y := _get_eye_height_for_capsule(new_height)
	head_anchor.position.y = lerp(
		head_anchor.position.y,
		target_eye_y,
		delta * crouch_transition_speed
	)

func _get_eye_height_for_capsule(capsule_height: float) -> float:
	var t := inverse_lerp(crouch_height, stand_height, capsule_height)
	return lerp(
		_eye_height_local + crouch_camera_offset,
		_eye_height_local,
		t
	)

func _get_max_stand_height() -> float:
	var ray_limit := _raycast_ceiling_height()

	# Fast path
	if ray_limit >= stand_height and _can_grow_to_height(stand_height):
		return stand_height

	# Binary refine
	var low := crouch_height
	var high := ray_limit
	var best := low

	for i in 6:
		var mid := (low + high) * 0.5
		if _can_grow_to_height(mid):
			best = mid
			low = mid
		else:
			high = mid

	return best

func _can_grow_to_height(target_height: float) -> bool:
	var current_height := (collider.shape as CapsuleShape3D).height
	if target_height <= current_height:
		return true

	var delta := target_height - current_height
	var motion := Vector3.UP * (delta * 0.5)

	var collision := move_and_collide(motion, true)

	if collision:
		# Only block if it's a ceiling
		if collision.get_normal().dot(Vector3.DOWN) > 0.6:
			return false

	return true

func _raycast_ceiling_height() -> float:
	var space := get_world_3d().direct_space_state
	var origin := global_position

	var best_height := stand_height

	for offset in CEILING_RAY_OFFSETS:
		var from: Vector3= origin + offset + Vector3.UP * crouch_height * 0.5
		var to: Vector3 = origin + offset + Vector3.UP * stand_height

		var query := PhysicsRayQueryParameters3D.create(from, to)
		query.exclude = [self]
		query.collision_mask = collision_mask

		var hit := space.intersect_ray(query)

		if hit:
			var ceiling_distance: float = hit.position.y - origin.y
			var allowed := ceiling_distance - 0.5
			best_height = min(best_height, allowed)

	return clamp(best_height, crouch_height, stand_height)

func _is_grounded() -> bool:
	return is_on_floor() or ground_check.is_colliding()

func _is_physically_crouched() -> bool:
	return _cached_max_height < stand_height - HEIGHT_EPSILON

#debug
func _debug() -> void:
	debug_label.text = "
		state: %s
		prev_ground: %s
		on_floor: %s
		ground_check: %s
		head_anchor.position: %v
		shape.height: %f
	" % [
		MoveState.keys()[move_state],
		MoveState.keys()[previous_ground_state],
		_is_grounded(),
		ground_check.is_colliding(),
		head_anchor.position,
		collider.shape.height
	]
