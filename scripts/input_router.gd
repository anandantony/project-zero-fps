extends Node

# Public state
var move := Vector2.ZERO
var look := Vector2.ZERO
var sprint := false
var toggle_sprint := false

@export var look_deadzone := 0.05
@export var mouse_sensitivity := 0.006
@export var joystick_sensitivity := 5.0
@export var jump_buffer_time := 0.12      # seconds

# Private state
var _jump_buffer := 0.0

func _process(delta: float) -> void:
	# Movement
	move = Input.get_vector(
		"move_left", "move_right",
		"move_back", "move_forward"
	)

	# Buttons
	sprint = Input.is_action_pressed("sprint")
	
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
