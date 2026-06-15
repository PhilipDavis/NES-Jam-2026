extends Node2D
class_name Tongue

@onready var sprite = $Sprite2D
@onready var hit_box = $HitBox
@onready var collision_shape = $HitBox/CollisionShape2D

const FULL_LENGTH := 32.0
const TONGUE_OFFSET_X := 4.0

func _ready() -> void:
	collision_shape.shape = collision_shape.shape.duplicate()
	change_size(0.0)

func change_size(amount: float) -> void:
	var width := roundf(FULL_LENGTH * amount)
	sprite.region_rect.size.x = width
	var shape := collision_shape.shape as RectangleShape2D
	collision_shape.position.x = floorf(TONGUE_OFFSET_X + width / 2.0)
	shape.size.x = width
	hit_box.monitoring = amount > 0.0

func _on_hit_box_body_entered(body: Node2D) -> void:
	if body.is_in_group('enemies'):
		var enemy := body as Enemy
		Events.enemy_damaged.emit(enemy, 1, get_parent().scale.x)
	elif body.is_in_group('objects'):
		# Bail out if the frog is on the left side of the cage
		if global_position.x < body.global_position.x:
			return
		# Bail out if the frog is too high
		if global_position.y < body.global_position.y - 24:
			return
		Events.object_damaged.emit(body, get_parent().scale.x)
