extends Enemy
class_name Snake

const ATTACK_SPEED := 256.0
const ACCEL := 64.0

enum BehaviourState {
	Idle,
	Shaking,
	Peeking,
	Spitting,
	BreakingFree,
	Slithering,
	Lunging,
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

# Can remove the enemy when it's guaranteed to be off-screen
const REMOVE_AT_Y_THRESHOLD := 320

func _ready() -> void:
	super._ready()
	add_to_group('enemies')
	facing_direction = facing_direction # Force a visual update
	state = BehaviourState.Idle

# TODO
