extends Node2D

@onready var world: Node2D = %World
@onready var camera: Camera2D = %World/Camera2D
@onready var player: Player = %World/Player

const SCREEN_HEIGHT := 224.0
const WORLD_OFFSET := 120.0
const CHUNK_SIZE := 16.0 # Move in 16-pixels chunks to force a more-retro look
const TRANSITION_SPEED = 360.0 # ~2/3 of a second
const STARTING_LIFE := 3

var is_clock_running := false
var game_time := 0.0
var current_health := 0

var is_camera_moving := false
var current_screen_index := -1

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Events.start_requested.connect(_on_start_requested)
	Events.player_entered_screen.connect(_on_player_entered_screen)
	Events.player_damaged.connect(_on_player_damaged)
	Events.player_death_finished.connect(_on_player_death_finished)
	Events.game_ended.connect(_on_game_ended)
	Events.tutorial_step_completed.connect(_on_tutorial_step_completed)
	
	# Darken the screen
	$FaderContainer/Fader.start_dark()
	
	_show_menu()

func _show_menu() -> void:
	world.visible = false
	$HUD.visible = false
	$Menu.visible = true
	world.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF

	$Menu.set_process_input(true)
	$Menu.resume()
	
	# Reveal the menu
	$FaderContainer/Fader.fade_in()

func _on_start_requested() -> void:
	# Darken the screen
	await $FaderContainer/Fader.fade_out()

	$Menu.set_process_input(false)
	
	# Swap out the menu for the World and HUD
	$Menu.visible = false
	$HUD.visible = true
	world.visible = true
	
	# Setup the initial game state
	camera.global_position.y = WORLD_OFFSET
	current_screen_index = -1
	current_health = STARTING_LIFE
	Events.player_entered_screen.emit(0)
	Events.player_health_changed.emit(STARTING_LIFE, false)
	Events.time_changed.emit(0.0)
	is_clock_running = true
	game_time = 0.0
	
	# Start playing!
	Events.game_started.emit()
	world.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	await $FaderContainer/Fader.fade_in()

func _on_game_ended() -> void:
	is_clock_running = false
	# TODO: some kind of death animation / screen
	
	await $FaderContainer/Fader.fade_out()
	world.reset()
	_show_menu()

func _physics_process(delta: float) -> void:
	if not is_clock_running:
		return
	
	# Stop processing screen transitions if the player is dead
	if player.state == Player.MoveState.Defeated:
		return
	
	var screen_index = floori(-(player.position.y - WORLD_OFFSET) / SCREEN_HEIGHT)
	if screen_index < 0:
		return
	if screen_index != current_screen_index:
		Events.player_entered_screen.emit(screen_index)

func _process(delta: float) -> void:
	_time_tick(delta)

func _time_tick(delta: float) -> void:
	if not is_clock_running:
		return
	
	# Pause the clock while we transition between screens
	if is_camera_moving:
		return
	
	var last_game_time_floor = floorf(game_time)
	game_time += delta
	var game_time_floor = floorf(game_time)
	if game_time_floor > last_game_time_floor:
		Events.time_changed.emit(game_time_floor)

func _on_player_damaged(damage: int, attack_direction: float) -> void:
	if player.is_immune:
		return
	
	# Don't take damage in the tutorial screen
	if current_screen_index == 0:
		# But mimic health lost to cause the immune animation
		Events.player_health_changed.emit(current_health, true)
	else:
		current_health -= damage
		Events.player_health_changed.emit(current_health, true)

func _on_player_death_finished() -> void:
	# TODO: fade out or something... You Died text, etc..
	Events.game_ended.emit()

func _on_player_entered_screen(index: int) -> void:
	_transition_to_screen(index)

func _transition_to_screen(index: int) -> void:
	# Bail out if we're already in this screen
	if index == current_screen_index:
		return
	# Also bail out if the game is just starting
	elif current_screen_index == -1:
		current_screen_index = index
		return
	# Also bail out if we're already transitioning
	if is_camera_moving:
		return
	
	var old_screen_index = current_screen_index
	current_screen_index = index
	
	Events.screen_transition_started.emit(old_screen_index)
	is_camera_moving = true
	world.set_physics_process(false)
	world.set_process_input(false)
	
	var chunk_count = SCREEN_HEIGHT / CHUNK_SIZE
	var chunk_time = (CHUNK_SIZE - 1) / TRANSITION_SPEED
	var direction = -1 if index > old_screen_index else 1
	
	# Animate the screen to slide in chunks to try
	# to make the transition feel more retro.
	# In retrospect, I don't think this was worth it...
	# the chunk_time is too short
	var tween := create_tween()
	var y = camera.global_position.y
	for i in range(chunk_count):
		y += CHUNK_SIZE * direction
		tween.tween_property(camera, 'global_position:y', y, 0.0)
		if i < chunk_count - 1:
			tween.tween_interval(chunk_time)
	await tween.finished

	world.set_physics_process(true)
	world.set_process_input(true)
	
	is_camera_moving = false
	Events.screen_transition_ended.emit(current_screen_index)

func _on_tutorial_step_completed(name: String) -> void:
	Settings.set_setting('tutorial', name, true)
