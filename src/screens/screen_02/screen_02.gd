extends Node2D

@onready var platform := $Platform

func _on_floor_body_entered(body: Node2D) -> void:
	if not body.is_in_group('player'):
		return
	var player := body as Player
	$Floor.monitoring = false
	
	# Prevent the player from being able to drop
	# back down into the tutorial level
	player.global_position.y = platform.global_position.y - 16.0
	player.velocity.y = 0
	platform.show_platform()
	
	# KILL: This ends the game two seconds after arriving in this screen
	await get_tree().create_timer(2.0).timeout
	Events.game_ended.emit()
