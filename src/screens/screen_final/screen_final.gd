extends Node2D

@onready var princess: Princess = $Princess
@onready var prince: Player = get_tree().get_nodes_in_group('player')[0] as Player

func _ready() -> void:
	Events.dialog_event.connect(_on_dialog_event)

func _on_dialog_event(event_name: String) -> void:
	match event_name:
		'kiss':
			await _move_princess_to_prince()
			await _kiss()
			Events.dialog_event_ended.emit()
		
		'transform':
			await _transform_prince()
			Events.dialog_event_ended.emit()

func _move_princess_to_prince() -> void:
	princess.play_animation('Hop')
	
	prince.visuals.scale.x = -1.0 # Make sure he's facing the princess
	
	# Take the position of the Prince minus half the width
	# of the player minus half the width of the Princess.
	var target_x = prince.global_position.x - 8.0 - 8.0 - 1.0
	
	# Hop to the Prince
	var tween = create_tween()
	tween.tween_property(princess, 'global_position:x', target_x, 3.0)
	await tween.finished

func _kiss() -> void:
	# Put both frogs in kissy pose
	princess.play_animation('Kiss')
	prince._play_animation('Kiss')
	
	# Wait for the heart to animate up
	await princess.play_heart_animation()
	
	princess.play_animation('Idle')
	prince._play_animation('Idle')

func _transform_prince() -> void:
	prince.curse()
	await Events.player_transformed
