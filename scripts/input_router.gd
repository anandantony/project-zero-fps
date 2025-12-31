extends Node

enum SprintMode { HOLD, TOGGLE }

# Public state
var move := Vector2.ZERO
var look := Vector2.ZERO
var sprint := false

@export var look_deadzone := 0.05
@export var mouse_sensitivity := 0.006
@export var joystick_sensitivity := 5.0
@export var jump_buffer_time := 0.12      # seconds
@export var sprint_mode_keyboard := SprintMode.HOLD
@export var sprint_mode_gamepad := SprintMode.TOGGLE

# Private state
var _jump_buffer := 0.0
var _sprint_toggled := false
var _last_input_was_gamepad := false

func _unhandled_input(event: InputEvent) -> void:
	# Track last input device
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_last_input_was_gamepad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		_last_input_was_gamepad = false

	# Sprint handling
	if event.is_action_pressed("sprint"):
		_on_sprint_pressed()
	elif event.is_action_released("sprint"):
		_on_sprint_released()

func _process(delta: float) -> void:
	# Movement
	move = Input.get_vector(
		"move_left", "move_right",
		"move_back", "move_forward"
	)
	
	# Sprint state handle
	if move.length() < 0.1 and _get_active_sprint_mode() == SprintMode.TOGGLE:
		reset_sprint()
	
	# Jump buffer (INPUT-side)
	if Input.is_action_just_pressed("jump"):
		_jump_buffer = jump_buffer_time
	else:
		_jump_buffer = max(_jump_buffer - delta, 0.0)

	# Joystick look
	var stick := Input.get_vector(
		"look_left", "look_right",
		"look_up", "look_down"
	)

	if stick.length() > look_deadzone:
		stick *= stick.length()
		look += stick * joystick_sensitivity * delta

func _on_sprint_pressed() -> void:
	match _get_active_sprint_mode():
		SprintMode.HOLD:
			sprint = true
		SprintMode.TOGGLE:
			_sprint_toggled = !_sprint_toggled
			sprint = _sprint_toggled


func _on_sprint_released() -> void:
	if _get_active_sprint_mode() == SprintMode.HOLD:
		sprint = false

func _get_active_sprint_mode() -> SprintMode:
	return sprint_mode_gamepad if _last_input_was_gamepad else sprint_mode_keyboard

func is_mouse_locked() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

func handle_mouse_motion(event: InputEventMouseMotion) -> void:
	look += event.relative * mouse_sensitivity

func consume_look() -> Vector2:
	var l := look
	look = Vector2.ZERO
	return l

func wants_to_jump() -> bool:
	return _jump_buffer > 0.0

func consume_jump() -> void:
	_jump_buffer = 0.0

func _is_gamepad() -> bool:
	return Input.get_connected_joypads().size() > 0

func reset_sprint() -> void:
	_sprint_toggled = false
	sprint = false
