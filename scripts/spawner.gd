extends Marker3D

@export var scene: PackedScene

func _ready() -> void:
	if scene and scene.can_instantiate():
		_instantiate_scene.call_deferred()

func _instantiate_scene():
	var node: Node = scene.instantiate()
	add_sibling(node)
	if node is Node3D:
		node.set_global_position(self.global_position)
		node.set_rotation(self.rotation)
