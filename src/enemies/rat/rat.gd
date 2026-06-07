@tool
extends Enemy
class_name Rat

@export var attack_damage := 1
@export var facing_direction := 1:
	set(value):
		facing_direction = signf(value)
		if is_node_ready():
			visuals.scale.x = facing_direction

@onready var ground_check: RayCast2D = $Visuals/GroundCheck
@onready var wall_check: RayCast2D = $Visuals/WallCheck
@onready var player_check: RayCast2D = $Visuals/PlayerCheck

const PATROL_SPEED := 64.0
const SURPRISE_JUMP_SPEED := -64.0
const CHASE_SPEED := 192.0
const DIE_SPEED := 128.0
const GROUND_ACCEL := 512.0
const GROUND_DECEL := 1024.0
const AIR_ACCEL := 256.0
const AIR_DECEL := 64.0
const VISION_RANGE := 128.0 # Half the screen width

# Can remove the enemy when it's guaranteed to be off-screen
const REMOVE_AT_Y_THRESHOLD := 320

enum MoveState {
	Ground,
	Air,
}

var move_state := MoveState.Ground
var state_speed := 0.0

enum BehaviorState {
	Patrol,
	Paused, # e.g. when turning around, impeded, etc.
	Surprised, # Just saw the player and is about to chase
	Chase,
	Defeated,
	# TODO: different enemies might have different move states
}

var behavior_state := BehaviorState.Patrol
var paused_time := 0.0
const PAUSE_TIME := 0.8 # How long to pause before resuming another behaviour state
var surprised_time := 0.0
const SURPRISE_TIME := 0.2 # How long to pause after seeing the player and starting the attack behaviour
var chase_ending_time := 0.0
const CHASE_END_TIME := 2.0 # How long to stop chasing after losing sight of player

enum CombatState {
	Idle,
	Attacking,
	Recovering,
}

var combat_state := CombatState.Idle

var resume_direction := -1.0

func _ready() -> void:
	super._ready()
	ground_check.force_raycast_update()
	wall_check.force_raycast_update()
	player_check.force_raycast_update()
	add_to_group('enemies')
	Events.enemy_damaged.connect(_on_enemy_damaged)
	facing_direction = facing_direction # Force a visual update
	_play_animation('Patrol')

func _physics_process(delta: float) -> void:
	_update_timers(delta)
	_update_movement(delta)
	_update_state(delta)

func _update_movement(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	match behavior_state:
		BehaviorState.Patrol:
			velocity.x = move_toward(velocity.x, facing_direction * PATROL_SPEED, GROUND_ACCEL * delta)
		
		BehaviorState.Paused:
			velocity.x = move_toward(velocity.x, 0.0, GROUND_DECEL * delta)
		
		BehaviorState.Surprised:
			velocity.x = move_toward(velocity.x, 0.0, GROUND_DECEL * delta)
		
		BehaviorState.Chase:
			velocity.x = move_toward(velocity.x, facing_direction * CHASE_SPEED, GROUND_ACCEL * delta)
	
	move_and_slide()

func _update_timers(delta: float) -> void:
	match behavior_state:
		BehaviorState.Paused:
			paused_time += delta
		BehaviorState.Surprised:
			surprised_time += delta
		BehaviorState.Chase:
			chase_ending_time += delta

func _update_state(delta: float) -> void:
	match move_state:
		MoveState.Air:
			if is_on_floor():
				move_state = MoveState.Ground
	
	match behavior_state:
		BehaviorState.Patrol:
			if wall_check.is_colliding():
				# Turn around immediately at a wall
				facing_direction *= -1
			elif not ground_check.is_colliding():
				# Pause at the end of a platform, then turn around
				behavior_state = BehaviorState.Paused
				_play_animation('Paused')
				resume_direction = -facing_direction
				paused_time = 0.0
			elif _can_see_player():
				behavior_state = BehaviorState.Surprised
				surprised_time = 0.0
				velocity.y = SURPRISE_JUMP_SPEED
				_play_animation('Surprised')
		
		BehaviorState.Paused:
			if paused_time >= PAUSE_TIME:
				if _can_see_player():
					behavior_state = BehaviorState.Chase
					_play_animation('Chase')
				else:
					behavior_state = BehaviorState.Patrol
					_play_animation('Patrol')
					facing_direction = resume_direction
		
		BehaviorState.Surprised:
			if surprised_time >= SURPRISE_TIME:
				behavior_state = BehaviorState.Chase
				_play_animation('Chase')
		
		BehaviorState.Chase:
			if not ground_check.is_colliding():
				# Pause at the end of a platform, then turn around
				behavior_state = BehaviorState.Paused
				_play_animation('ChasePaused')
				resume_direction = facing_direction # maintain the same direction for now
				velocity.x /= 4 # Cut velocity quickly or else will run off the platform
				paused_time = 0.0
			elif _can_see_player():
				chase_ending_time = 0.0
			elif chase_ending_time >= CHASE_END_TIME:
				behavior_state = BehaviorState.Paused
				_play_animation('Paused')
				resume_direction = -facing_direction
				paused_time = 0.0
		
		BehaviorState.Defeated: # This is a terminal state
			# Reduce horizontal die velocity to 0
			velocity.x = move_toward(velocity.x, 0, AIR_DECEL * delta)
			if abs(velocity.x) < 2.0:
				velocity.x = 0.0
			
			# Rotate sideways as they fall
			visuals.global_rotation_degrees = move_toward(visuals.global_rotation_degrees, 90 * die_direction, AIR_ACCEL * delta)
			
			# Remove once the enemy is off screen
			if position.y > REMOVE_AT_Y_THRESHOLD:
				queue_free()

func _can_see_player() -> bool:
	if not player:
		player = get_tree().get_first_node_in_group('player') as Player
		if not player: return false
	return player_check.is_colliding() and player_check.get_collider() == player

func _on_enemy_damaged(enemy: Enemy, amount: int, direction: float) -> void:
	if enemy != self:
		return
	
	# Don't collide with anything anymore... just fall offscreen
	behavior_state = BehaviorState.Defeated
	_play_animation('Defeated')
	collision_layer = 0
	collision_mask = 0
	ground_check.enabled = false
	wall_check.enabled = false
	player_check.enabled = false
	
	# Give the enemy some initial upward velocity in the given direction
	velocity = Vector2(direction * DIE_SPEED, -DIE_SPEED)
	
	die_direction = direction

func _on_hit_box_body_entered(body: Node2D) -> void:
	if body.is_in_group('player'):
		var attack_direction = signf(body.position.x - position.x)
		Events.player_damaged.emit(attack_damage, attack_direction)
