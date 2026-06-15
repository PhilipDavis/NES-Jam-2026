extends StaticBody2D

@onready var sprite := $Door/AnimatedSprite2D
@onready var door := $Door

func _ready() -> void:
	door.hide()
	add_to_group('objects') # So that the tongue attack will trigger an event
	Events.object_damaged.connect(_on_object_damaged)

func _on_object_damaged(object: Node2D, _attack_direction: float) -> void:
	if object == self:
		Events.object_damaged.disconnect(_on_object_damaged)
		_open_door()
	
	# Knock the player backwards to move out of the way of the door
	Events.player_damaged.emit(0, 1.0)

func _open_door() -> void:
	door.show()
	sprite.play('Opening')
	await sprite.animation_finished
	
	# TODO: princess emerges

func _on_door_animation_finished() -> void:
	Events.princess_saved.emit()
