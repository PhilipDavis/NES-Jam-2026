extends CharacterBody2D
class_name Player

@onready var visuals: Node2D = $Visuals
@onready var sprite: AnimatedSprite2D = $Visuals/AnimatedSprite2D
@onready var tongue: Tongue = %Tongue
@onready var hit_box: Area2D = %Tongue/HitBox
@onready var on_screen_notifier := $VisibleOnScreenNotifier2D

const SPEED = 128.0
const KNOCKBACK_SPEED := 128.0
const GROUND_ACCEL = 512.0
const GROUND_DECEL = 1024.0
const AIR_ACCEL = 256.0
const AIR_DECEL = 64.0

const FLICKER_DURATION := 1000
const FLICKER_STEP := 200

enum MoveState {
	Ground,
	Air,
	Wall,
	Defeated,
}

var state := MoveState.Air

enum CombatState {
	Idle,
	Attacking,
	Recovering
}

var combat_state := CombatState.Idle

var attack_time := 0.0

const EXTEND_TIME := 0.08
const ACTIVE_TIME := 0.12
const RECOVERY_TIME := 0.15


#
# Jump request buffer
#
var jump_request_time := 0.0
const JUMP_REQUEST_WINDOW := 0.12

#
# Jump commit window
#
var jump_commit_time := 0.0
const JUMP_COMMIT_WINDOW := 0.12

#
# Coyote
#
var ground_coyote_time := 0.0
const GROUND_COYOTE_WINDOW := 0.10

var wall_coyote_time := 0.0
const WALL_COYOTE_WINDOW := 0.10

#
# Wall anticipation
#
var wall_probe_time := 0.0
const WALL_PROBE_PIXELS := 3
const WALL_PROBE_WINDOW := 0.12

var last_wall_normal := Vector2.ZERO

#
# Variable jump
#
var is_jumping := false
var jump_time := 0.0
const MAX_HOLD_TIME := 0.25
const JUMP_VELOCITY = -288.0
const MIN_JUMP := 0.4
const MAX_JUMP := 1.0

#
# Commit state
#
var launch_direction := 0.0
var consecutive_straight_up_wall_jumps := 0

var is_game_on := false
var is_immune := false
var die_direction := 0.0

func _ready() -> void:
	Events.game_started.connect(_on_game_started)
	Events.player_damaged.connect(_on_player_damaged)
	Events.player_health_changed.connect(_on_player_health_changed)
	Events.game_ended.connect(_on_game_ended)
	add_to_group('player')
	reset()

func reset() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	hit_box.collision_layer = 2 # Player
	hit_box.collision_mask = 4 | 8 # Enemies and Objects
	visible = false
	velocity = Vector2.ZERO
	position.y = 80 + 112
	#position = Vector2i(100, -80 + 112) # KILL: position to fast-forward to end of tutorial screen

func _on_game_started() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	is_game_on = true
	
	_play_animation('Idle')
	visible = true

func _on_player_damaged(_damage: int, attack_direction: float) -> void:
	die_direction = attack_direction
	
	# knock the player back in the direction of the attack
	if attack_direction and not is_immune:
		velocity = Vector2(attack_direction * KNOCKBACK_SPEED, -KNOCKBACK_SPEED)
		is_jumping = true
		state = MoveState.Air

func _on_player_health_changed(health: int, was_lost: bool) -> void:
	if health == 0:
		_die()
		return
	
	if was_lost:
		is_immune = true
		await _flicker()
		is_immune = false

func _die() -> void:
	state = MoveState.Defeated
	hit_box.collision_layer = 0
	hit_box.collision_mask = 0
	$Audio/Death.play()

func _flicker() -> void:
	for i in range(0, FLICKER_DURATION / FLICKER_STEP):
		await get_tree().create_timer(FLICKER_STEP / 2000.0).timeout
		sprite.visible = false
		await get_tree().create_timer(FLICKER_STEP / 2000.0).timeout
		sprite.visible = true

func _on_game_ended() -> void:
	is_game_on = false
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF

func _play_animation(anim: String) -> void:
	if sprite.animation == anim and sprite.is_playing():
		return
	sprite.play(anim)
	
	var use_extended_hurt_box = anim == 'Attack' or anim == 'Idle'
	$StandardCollision.disabled = use_extended_hurt_box
	$ExtendedCollision.disabled = not use_extended_hurt_box

func _physics_process(delta: float) -> void:
	if not is_game_on:
		return
	
	var input_dir := _handle_input()
	_update_facing(input_dir)
	_update_timers(delta, input_dir)
	_handle_combat_input(input_dir)
	_update_combat(delta)
	_handle_movement(delta, input_dir)
	_update_state(input_dir)

func _handle_input() -> float:
	if state == MoveState.Defeated:
		return 0.0
	
	if Input.is_action_just_pressed("jump"):
		jump_request_time = JUMP_REQUEST_WINDOW
	return Input.get_axis("ui_left", "ui_right")

func _update_facing(input_dir: float) -> void:
	if input_dir != 0.0 and combat_state == CombatState.Idle:
		visuals.scale.x = signf(input_dir)

func _handle_movement(delta: float, input_dir: float) -> void:
	# Apply gravity
	if state != MoveState.Ground:
		velocity += get_gravity() * delta
	
	# Check if we need to initiate a jump
	if jump_request_time > 0.0:
		_resolve_jump()
	
	_apply_commit_window(delta)
	_apply_horizontal_movement(delta, input_dir)
	_handle_jump_release(delta)
	
	move_and_slide()

func _update_timers(delta: float, input_dir: float) -> void:
	jump_request_time = max(jump_request_time - delta, 0.0)
	jump_commit_time = max(jump_commit_time - delta, 0.0)
	
	if state == MoveState.Ground:
		ground_coyote_time = GROUND_COYOTE_WINDOW
	else:
		ground_coyote_time = max(ground_coyote_time - delta, 0.0)
	
	if state == MoveState.Wall:
		wall_coyote_time = WALL_COYOTE_WINDOW
		last_wall_normal = get_wall_normal()
	else:
		wall_coyote_time = max(wall_coyote_time - delta, 0.0)
	
	_update_wall_probe(delta, input_dir)

func _resolve_jump() -> void:
	if is_jumping or state == MoveState.Defeated:
		return
	
	if is_on_floor() and Input.is_action_pressed("ui_down"):
		_do_fall_through()
		return
	
	# If we were just on a wall or we are about
	# to hit a wall, allow the jump to happen
	if wall_coyote_time > 0.0 or wall_probe_time > 0.0:
		if not is_on_floor():
			_do_wall_jump(last_wall_normal)
			return
	
	if ground_coyote_time > 0.0:
		_do_ground_jump()

func _do_wall_jump(normal: Vector2) -> void:
	launch_direction = normal.x
	velocity.x = launch_direction * SPEED
	velocity.y = JUMP_VELOCITY
	visuals.scale.x = normal.x
	is_jumping = true
	jump_time = 0.0
	jump_request_time = 0.0
	jump_commit_time = JUMP_COMMIT_WINDOW
	wall_coyote_time = 0.0
	wall_probe_time = 0.0
	$Audio/Jump.play()
	_play_animation('WallJump')
	Events.player_jumped.emit(true)

func _do_ground_jump() -> void:
	velocity.y = JUMP_VELOCITY
	launch_direction = sign(velocity.x)
	is_jumping = true
	jump_time = 0.0
	jump_request_time = 0.0
	jump_commit_time = JUMP_COMMIT_WINDOW
	$Audio/Jump.play()
	_play_animation('GroundJump')
	Events.player_jumped.emit(false)

func _do_fall_through() -> void:
	var platform := get_last_slide_collision().get_collider() as StaticBody2D
	if not platform:
		return
	var collision_shape := platform.get_node('CollisionShape2D') as CollisionShape2D
	if not collision_shape:
		return
	if not collision_shape.one_way_collision:
		return
	
	velocity.y = 0
	launch_direction = 0.0
	is_jumping = true
	jump_time = 0.0
	jump_commit_time = 0.0 # Cannot change direction
	_play_animation('Falling')
	# Don't play jump sound or emit jump event (because we're falling)
	
	add_collision_exception_with(platform)
	await get_tree().create_timer(0.2).timeout
	remove_collision_exception_with(platform)

func _apply_commit_window(input_dir: float) -> void:
	if state == MoveState.Defeated:
		return
	
	if jump_commit_time <= 0.0:
		if velocity.y > 0:
			_play_animation('Falling')
		return
	
	if input_dir:
		launch_direction = input_dir
		jump_commit_time = 0.0

func _apply_horizontal_movement(delta: float, input_dir: float) -> void:
	match state:
		MoveState.Air:
			if input_dir:
				if combat_state == CombatState.Idle:
					velocity.x = move_toward(velocity.x, input_dir * SPEED, AIR_ACCEL * delta)
			else:
				velocity.x = move_toward(velocity.x, 0, AIR_DECEL * delta)
				if abs(velocity.x) < 2.0:
					velocity.x = 0.0
		
		MoveState.Defeated: # This is a terminal state
			# Reduce horizontal die velocity to 0
			velocity.x = move_toward(velocity.x, 0, AIR_DECEL * delta)
				
			# Rotate sideways as they fall
			visuals.global_rotation_degrees = move_toward(visuals.global_rotation_degrees, 90 * die_direction, AIR_ACCEL * delta)
			
			# Notify once the enemy is off screen
			if not on_screen_notifier.is_on_screen():
				Events.player_death_finished.emit()
		
		_:
			if input_dir:
				if combat_state == CombatState.Idle:
					velocity.x = move_toward(velocity.x, input_dir * SPEED, GROUND_ACCEL * delta)
			else:
				velocity.x = move_toward(velocity.x, 0, GROUND_DECEL * delta)
				if abs(velocity.x) < 2.0:
					velocity.x = 0.0
	
	assert(abs(velocity.x) <= SPEED)
	velocity.x = clampf(velocity.x, -SPEED, SPEED) # Just in case

func _handle_jump_release(delta: float) -> void:
	if state == MoveState.Defeated:
		return
	
	if is_jumping:
		jump_time += delta
	
	# Holding the jump button longer will produce a stronger jump
	if Input.is_action_just_released("jump") and velocity.y < 0:
		var t := clampf(jump_time / MAX_HOLD_TIME, 0.0, 1.0)
		velocity.y *= lerpf(MIN_JUMP, MAX_JUMP, t)
		is_jumping = false

func _update_state(input_dir: float) -> void:
	if is_on_floor():
		if state != MoveState.Ground:
			$Audio/Landing.play()
			_play_animation('Idle')
			velocity.x /= 2.0 # Immediately cut velocity in half to greatly slow down
			is_jumping = false
			Events.player_landed.emit()
		elif input_dir:
			_play_animation('Hop')
		else:
			_play_animation('Idle')
		state = MoveState.Ground
		consecutive_straight_up_wall_jumps = 0
	elif is_on_wall():
		state = MoveState.Wall
	else:
		state = MoveState.Air

func _update_wall_probe(delta: float, input_dir: float) -> void:
	if not input_dir:
		wall_probe_time = max(wall_probe_time - delta, 0.0)
		return
	
	# Test if we're getting close to a wall
	var space := get_world_2d().direct_space_state
	var look_ahead := Vector2(input_dir * WALL_PROBE_PIXELS, 0)
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + look_ahead)
	var result := space.intersect_ray(query)
	if result:
		last_wall_normal = result.normal
		wall_probe_time = WALL_PROBE_WINDOW
	else:
		wall_probe_time = max(wall_probe_time - delta, 0.0)

func _update_combat(delta: float) -> void:
	if combat_state == CombatState.Idle:
		return
	
	attack_time += delta
	assert(visuals.scale.x != 0.0)
	
	if attack_time < EXTEND_TIME:
		combat_state = CombatState.Attacking
		_apply_tongue_extend(attack_time / EXTEND_TIME)
	
	elif attack_time < EXTEND_TIME + ACTIVE_TIME:
		combat_state = CombatState.Attacking
		_apply_tongue_full()
	
	elif attack_time < EXTEND_TIME + ACTIVE_TIME + RECOVERY_TIME:
		combat_state = CombatState.Recovering
		_apply_tongue_retract((attack_time - EXTEND_TIME - ACTIVE_TIME) / RECOVERY_TIME)
	
	else:
		_end_attack()

func _handle_combat_input(_input_dir: float) -> void:
	if state == MoveState.Defeated:
		return
	
	if Input.is_action_just_pressed("attack"):
		if combat_state == CombatState.Idle:
			combat_state = CombatState.Attacking
			attack_time = 0.0
			$Audio/Attack.play()
			Events.player_attacked.emit()

func _apply_tongue_extend(t: float) -> void:
	tongue.change_size(t)

func _apply_tongue_full() -> void:
	tongue.change_size(1.0)

func _apply_tongue_retract(t: float) -> void:
	tongue.change_size(1.0 - t)

func _end_attack() -> void:
	combat_state = CombatState.Idle
	attack_time = 0.0
	tongue.change_size(0.0)
