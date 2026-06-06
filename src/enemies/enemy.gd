extends CharacterBody2D
class_name Enemy

@onready var visuals: Node2D = $Visuals
@onready var sprite: AnimatedSprite2D = $Visuals/AnimatedSprite2D

# Note: this @onready does nothing because the screen (with enemies) loads before the player
@onready var player := get_tree().get_first_node_in_group('player') as Player

var die_direction := 0.0

func _play_animation(anim: String) -> void:
	if sprite.animation == anim and sprite.is_playing():
		return
	sprite.play(anim)
