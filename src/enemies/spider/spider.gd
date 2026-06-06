extends Enemy
class_name Spider

@onready var player_above_left_check: RayCast2D = $PlayerAboveLeftCheck
@onready var player_above_right_check: RayCast2D = $PlayerAboveRightCheck
@onready var player_below_left_check: RayCast2D = $PlayerBelowLeftCheck
@onready var player_below_right_check: RayCast2D = $PlayerBelowRightCheck
@onready var drag_line: Sprite2D = $Visuals/DragLine

const ACCEL := 512.0
const DECEL := 256.0
const AIR_ACCEL := 256.0
const PATROL_SPEED := 64.0
const ATTACK_SPEED := 1024.0
const RETREAT_SPEED := 512.0
const DIE_SPEED := 128.0
const REMOVE_AT_Y_THRESHOLD := 320

enum BehaviorState {
	Wait,
	Patrol,
	Attack,
	Retreat,
	Defeated,
}

var behavior_state := BehaviorState.Wait
var direction := 0.0
var wait_time := 0.0
const WAIT_THRESHOLD := 1.0 # How long to pause before resuming another behaviour state
var retreat_time := 0.0
const RETREAT_THRESHOLD := 2.0
var health_remaining := 3
var origin := Vector2.ZERO

func _ready() -> void:
	origin = position
	set_drag_line_length(0)
	player_above_left_check.force_raycast_update()
	player_above_right_check.force_raycast_update()
	player_below_left_check.force_raycast_update()
	player_below_right_check.force_raycast_update()
	add_to_group('enemies')
	Events.enemy_damaged.connect(_on_enemy_damaged)
	_play_animation('Idle')

func set_drag_line_length(length: float) -> void:
	drag_line.region_rect.size.y = roundf(length)
	drag_line.position.y = roundf(-8.0 - length / 2.0)

func _physics_process(delta: float) -> void:
	_update_timers(delta)
	_update_movement(delta)
	_update_state(delta)

func _process(delta: float) -> void:
	set_drag_line_length(position.y - origin.y)

func _update_timers(delta: float) -> void:
	match behavior_state:
		BehaviorState.Wait:
			wait_time += delta

func _update_movement(delta: float) -> void:
	match behavior_state:
		BehaviorState.Wait:
			velocity.y = move_toward(velocity.y, 0, DECEL * delta)
		
		BehaviorState.Patrol:
			velocity.y = move_toward(velocity.y, PATROL_SPEED * direction, ACCEL * delta)
		
		BehaviorState.Attack:
			velocity.y = move_toward(velocity.y, ATTACK_SPEED * direction, ACCEL * delta)
		
		BehaviorState.Retreat:
			velocity.y = move_toward(velocity.y, RETREAT_SPEED * -1.0, ACCEL * delta)
		
		BehaviorState.Defeated:
			velocity += get_gravity() * delta
	
	move_and_slide()
	position.y = maxf(position.y, origin.y)


func _attack_player() -> bool:
	# HACK: The first screen loads before the player... so can't get the player reference in _ready()
	if not player:
		player = get_tree().get_first_node_in_group('player') as Player
	
	var is_player_above = \
		(player_above_left_check.is_colliding() and player_above_left_check.get_collider() == player) or \
		(player_above_right_check.is_colliding() and player_above_right_check.get_collider() == player)
	
	var is_player_below = \
		(player_below_left_check.is_colliding() and player_below_left_check.get_collider() == player) or \
		(player_below_right_check.is_colliding() and player_below_right_check.get_collider() == player)
	
	if not is_player_above and not is_player_below:
		return false
		
	behavior_state = BehaviorState.Attack
	direction = -1.0 if is_player_above else 1.0
	if signf(velocity.y) != direction:
		velocity.y = 0.0 # Rapid stop if the spider is moving away from the player
	_play_animation('Attack')
	return true

func _update_state(delta: float) -> void:
	match behavior_state:
		BehaviorState.Wait:
			if _attack_player():
				pass
			elif wait_time >= WAIT_THRESHOLD:
				behavior_state = BehaviorState.Patrol
				direction = 1.0 if position.y <= origin.y else -1.0
				_play_animation('Crawl')
		
		BehaviorState.Patrol:
			if _attack_player():
				pass
			elif is_on_floor() or position.y <= origin.y:
				behavior_state = BehaviorState.Wait
				velocity.y = 0.0
				wait_time = 0.0
				direction = 0.0
				_play_animation('Idle')
		
		BehaviorState.Attack:
			if (position.y <= origin.y and direction <= 0.0) or (is_on_floor() and direction >= 0.0):
				behavior_state = BehaviorState.Wait
				wait_time = 0.0
				_play_animation('Idle')
		
		BehaviorState.Retreat:
			if retreat_time >= RETREAT_THRESHOLD:
				behavior_state = BehaviorState.Wait
				wait_time = 0.0
				_play_animation('Idle')
		
		BehaviorState.Defeated: # This is a terminal state
			# Reduce horizontal die velocity to 0
			velocity.x = move_toward(velocity.x, 0, DECEL * delta)
			
			# Rotate sideways as they fall
			visuals.global_rotation_degrees = move_toward(visuals.global_rotation_degrees, 90 * die_direction, AIR_ACCEL * delta)
			
			# Remove once the enemy is off screen
			if position.y > REMOVE_AT_Y_THRESHOLD:
				queue_free()

func _on_enemy_damaged(enemy: Enemy, amount: int, direction: float) -> void:
	if enemy != self:
		return
	
	health_remaining -= amount
	if health_remaining > 0:
		return
	
	# Don't collide with anything anymore... just fall offscreen
	behavior_state = BehaviorState.Defeated
	drag_line.visible = false
	_play_animation('Defeated')
	collision_layer = 0
	collision_mask = 0
	player_above_left_check.enabled = false
	player_above_right_check.enabled = false
	player_below_left_check.enabled = false
	player_below_right_check.enabled = false
	
	# Give the enemy some initial upward velocity in the given direction
	velocity = Vector2(direction * DIE_SPEED, -DIE_SPEED)
	
	die_direction = direction
