extends Node2D

@onready var floor_platform := $FloorPlatform

func _on_floor_body_entered(body: Node2D) -> void:
	if not body.is_in_group('player'):
		return
	var player := body as Player
	_solidify_floor.call_deferred(player)

func _solidify_floor(player: Player) -> void:
	$EntryArea.monitoring = false
	
	# Prevent the player from being able to drop
	# back down into the tutorial level
	player.global_position.y = floor_platform.global_position.y - 16.0
	player.velocity.y = -32.0
	floor_platform.show_platform()
