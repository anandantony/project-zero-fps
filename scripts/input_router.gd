extends Node

# Public state
var move := Vector2.ZERO
var look := Vector2.ZERO
var jump_pressed := false
var sprint := false

@export var look_deadzone := 0.05
@export var mouse_sensitivity := 0.006
@export var joystick_sensitivity := 5.0

func _process(delta: float) -> void:
	# Movement
	move = Input.get_vector(
		"move_left", "move_right",
		"move_back", "move_forward"
	).normalized()

	# Buttons
	jump_pressed = Input.is_action_just_pressed("jump")
	sprint = Input.is_action_pressed("sprint")

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
