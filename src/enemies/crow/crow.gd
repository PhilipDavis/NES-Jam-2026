@tool
extends Enemy
class_name Crow

@onready var down_attack_collider := %DownAttackCollider
@onready var diagonal_attack_collider := %DiagonalAttackCollider

const TAKE_FLIGHT_SPEED := -64.0
const ACCEL := 256.0
const DECEL := 128.0

var start_position := Vector2.ZERO

enum BehaviourState {
	Idle,
	TakingFlight,
	Flying,
	Attacking,
	Recycling,
}

var state := BehaviourState.Idle:
	set(value):
		state = value
		match value:
			BehaviourState.Idle:
				_play_animation('Idle')
				idle_time = 0.0


const IDLE_TIME := 2.0
var idle_time := 0.0

const FLIGHT_TIME := 1.0
var flight_time := 0.0

const RECYCLE_TIME := 2.0
var recycle_time := 0.0

# Can remove the enemy when it's guaranteed to be off-screen
const REMOVE_AT_Y_THRESHOLD := 264

func _ready() -> void:
	super._ready()
	add_to_group('enemies')
	facing_direction = facing_direction # Force a visual update
	state = BehaviourState.Idle
	
	# Capture the current position and use for future resets
	start_position = position

func _physics_process(delta: float) -> void:
	_update_timers(delta)
	_update_movement(delta)
	_update_state(delta)

func _update_timers(delta: float) -> void:
	match state:
		BehaviourState.Idle:
			idle_time += delta
		BehaviourState.Flying:
			flight_time += delta
		BehaviourState.Recycling:
			recycle_time += delta

func _update_movement(delta: float) -> void:
	match state:
		BehaviourState.Attacking:
			velocity.y = move_toward(velocity.y, Settings.difficulty.crow_attack_speed, ACCEL * delta)
			velocity.x = move_toward(velocity.x, Settings.difficulty.crow_attack_speed * facing_direction, ACCEL * delta)
		
		BehaviourState.TakingFlight:
			velocity.y = move_toward(velocity.y, 0, DECEL * delta)
	
	move_and_slide()

func _update_state(_delta: float) -> void:
	match state:
		BehaviourState.Idle:
			if idle_time > IDLE_TIME:
				state = BehaviourState.TakingFlight
				_play_animation('TakeFlight')
				velocity.y = TAKE_FLIGHT_SPEED
		
		BehaviourState.TakingFlight:
			# The transition out of this state happens when the TakeFlight animation completes
			pass
		
		BehaviourState.Flying:
			if flight_time >= FLIGHT_TIME:
				state = BehaviourState.Attacking
				_play_animation('AttackDiagonal') # TODO: set direction to left/right and maybe use AttackDiagonal
				diagonal_attack_collider.disabled = false
		
		BehaviourState.Attacking:
			if position.y >= REMOVE_AT_Y_THRESHOLD:
				state = BehaviourState.Recycling
				visible = false
		
		BehaviourState.Recycling:
			if recycle_time > RECYCLE_TIME:
				_play_animation('Idle')
				idle_time = 0.0
				state = BehaviourState.Idle
				velocity = Vector2.ZERO
				visible = true
				position = start_position

func _on_animation_looped() -> void:
	if sprite.animation == 'TakeFlight':
		state = BehaviourState.Flying
		flight_time = 0.0
		_play_animation('Flying')


func _on_hit_box_body_entered(body: Node2D) -> void:
	if body.is_in_group('player'):
		var attack_direction = signf(body.position.x - position.x)
		Events.player_damaged.emit(attack_damage, attack_direction)
