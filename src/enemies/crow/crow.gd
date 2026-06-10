@tool
extends Enemy
class_name Crow

@export var attack_damage := 1
@export var facing_direction := 1:
	set(value):
		facing_direction = signf(value)
		if is_node_ready():
			visuals.scale.x = facing_direction

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

const FLIGHT_TIME := 0.8
var flight_time := 0.0

const RECYCLE_TIME := 3.0
var recycle_time := 0.0

# Can remove the enemy when it's guaranteed to be off-screen
const REMOVE_AT_Y_THRESHOLD := 320

func _ready() -> void:
	super._ready()
	add_to_group('enemies')
	facing_direction = facing_direction # Force a visual update
	state = BehaviourState.Idle

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
	pass

func _update_state(delta: float) -> void:
	match state:
		BehaviourState.Idle:
			if idle_time > IDLE_TIME:
				state = BehaviourState.TakingFlight
				_play_animation('TakingFlight')
		
		BehaviourState.TakingFlight:
			pass
		
		BehaviourState.Flying:
			pass
		
		BehaviourState.Attacking:
			pass
		
		BehaviourState.Recycling:
			if recycle_time > RECYCLE_TIME:
				state = BehaviourState.Idle
				# TODO: also need to reset the start position
