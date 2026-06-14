extends Node2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hit_box: Area2D = $HitBox
@onready var collider: CollisionShape2D = $HitBox/CollisionShape2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	collider.disabled = true
	_play_animation('Idle')

func _play_animation(anim: String) -> void:
	if sprite.animation == anim and sprite.is_playing():
		return
	sprite.play(anim)

func _on_hit_box_body_entered(body: Node2D) -> void:
	if body.is_in_group('player'):
		var damage_direction = signf(body.position.x - position.x)
		Events.player_damaged.emit(1, damage_direction)

func _on_animation_looped() -> void:
	match sprite.animation:
		'Idle':
			collider.disabled = false
			_play_animation('Extend')
		
		'Extend':
			_play_animation('Retract')
		
		'Retract':
			collider.disabled = true
			_play_animation('Idle')
