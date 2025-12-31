class_name CameraController
extends Node3D

@export_group("Camera Look", "look")
@export var look_sensitivity: float = 0.006

@export_group("Bob Settings", "bob")
@export var bob_frequency: float = 2.0
@export var bob_amplitude: float = 0.08
@export var bob_strafe_multiplier: float = 0.6

@export_group("FOV Settings", "fov")
@export var fov_base: float = 75.0
@export var fov_walk: float = 77.5
@export var fov_run: float = 90.0

@onready var bob_phase = bob_frequency * PI

var t_bob := 0.0
var bob_offset := Vector3.ZERO
var player: PlayerCharacter
var player_camera: Camera3D

func _ready() -> void:
	player = GameManager.player_character
	_setup.call_deferred()

func _setup() -> void:
	player_camera = player.camera

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			player.rotate_y(-event.relative.x * look_sensitivity)
			player.head_anchor.rotate_x(-event.relative.y * look_sensitivity)
			self.rotation.x = clamp(self.rotation.x, deg_to_rad(-90), deg_to_rad(90))

func _process(_delta: float) -> void:
	global_transform = player.head_anchor.get_global_transform_interpolated()

func _physics_process(delta: float) -> void:
	if player_camera:
		player_camera.transform.origin = _calculate_bob_offset(delta)
		_handle_fov(delta)

func _calculate_bob_offset(delta: float) -> Vector3:
	var speed := player.velocity.length()
	var on_floor := player.is_on_floor()

	# Start fading bob when speed drops below this
	var forward_speed := player.velocity.dot(-player.global_transform.basis.z)
	var strafe_speed := player.velocity.dot(-player.global_transform.basis.x)
	var movement_speed: float = abs(forward_speed) + abs(strafe_speed) * bob_strafe_multiplier
	var bob_strength: float = clamp(movement_speed / player.walk_speed, 0.0, player.sprint_speed / player.walk_speed)

	if on_floor and bob_strength > 0.01:
		t_bob += delta * speed
		var target_offset := _head_bob(t_bob) * bob_strength
		bob_offset = bob_offset.lerp(target_offset, delta * 10.0)
	else:
		# Fully reset when airborne or almost stopped
		t_bob = 0.0
		bob_offset = bob_offset.lerp(Vector3.ZERO, delta * 10.0)
	return bob_offset

func _head_bob(time: float) -> Vector3:
	return Vector3(
		cos(time * bob_frequency * 0.5) * bob_amplitude,
		sin(time * bob_frequency) * bob_amplitude,
		0.0
	)

func _handle_fov(delta: float) -> void:
	var fov_target: float = fov_base
	var local_velocity = Vector3(player.velocity)
	local_velocity.y = 0
	if local_velocity.length() >= player.sprint_speed * 0.75:
		fov_target = fov_run
	elif local_velocity.length() >= player.walk_speed * 0.9:
		fov_target = fov_walk
	player_camera.fov = lerp(player_camera.fov, fov_target, delta * 8.0)
