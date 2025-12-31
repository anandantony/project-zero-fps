class_name CameraController
extends Node3D

@export_group("Camera Look", "look")
@export var look_sensitivity: float = 0.006

@export_group("Bob Settings", "bob")
@export var bob_frequency: float = 2.0
@export var bob_amplitude: float = 0.08

@onready var player_camera: Camera3D = %PlayerCamera

var t_bob: float = 0.0
var player: PlayerCharacter

func _ready() -> void:
	player = GameManager.player_character

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
	# Head bob
	t_bob += delta * player.velocity.length() * float(player.is_on_floor())
	player_camera.transform.origin = _head_bob(t_bob)

func _head_bob(time: float) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * bob_frequency) * bob_amplitude
	pos.x = cos(time * bob_frequency / 2) * bob_amplitude
	return pos
