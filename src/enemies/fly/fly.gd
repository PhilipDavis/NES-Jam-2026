extends Enemy
class_name Fly

const SPEED = 16.0
const ACCEL = 8.0

# How many maximum pixels the fly will travel from its start position
@export var wander_distance := 32

var starting_position := Vector2.ZERO

func _ready() -> void:
	super._ready()
	starting_position = position
	add_to_group('enemies')
	Events.enemy_damaged.connect(_on_enemy_damaged)
	_play_animation('Flying')

func _physics_process(delta: float) -> void:
	_update_movement(delta)
	_update_state(delta)

func _update_movement(_delta: float) -> void:
	velocity.x = move_toward(velocity.x, facing_direction * SPEED, ACCEL)
	# TODO: introduce some jitter to the path...
	move_and_slide()

func _update_state(_delta: float) -> void:
	if position.distance_to(starting_position) >= wander_distance and signf(position.x - starting_position.x) == facing_direction:
		facing_direction *= -1
		# TODO: set some y velocity?...

func _on_enemy_damaged(enemy: Enemy, _amount: int, _direction: float) -> void:
	if enemy != self:
		return
	
	Events.player_caught_fly.emit(self)
