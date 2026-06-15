extends Node2D

@onready var world: Node2D = %World
@onready var camera: Camera2D = %World/Camera2D
@onready var player: Player = %World/Player
@onready var music: Music = $Music

const SCREEN_HEIGHT := 224.0
const WORLD_OFFSET := 120.0
const CHUNK_SIZE := 16.0 # Move in 16-pixels chunks to force a more-retro look
const TRANSITION_SPEED = 360.0 # ~2/3 of a second

var is_clock_running := false
var game_time := 0.0
var current_health := 0

var is_camera_moving := false
var initial_screen_index := 0
var current_screen_index := -1
var game_options: GameOptions

func _ready() -> void:
	$PauseMenu.visible = false
	%Dialog.visible = false
	
	Events.start_requested.connect(_on_start_requested)
	Events.player_entered_screen.connect(_on_player_entered_screen)
	Events.player_damaged.connect(_on_player_damaged)
	Events.player_caught_fly.connect(_on_player_caught_fly)
	Events.player_death_finished.connect(_on_player_death_finished)
	Events.game_paused.connect(_on_game_paused)
	Events.game_resumed.connect(_on_game_resumed)
	Events.princess_saved.connect(_on_princess_saved)
	Events.game_ended.connect(_on_game_ended)
	Events.tutorial_step_completed.connect(_on_tutorial_step_completed)
	Events.dialog_opened.connect(_on_dialog_opened)
	Events.dialog_closed.connect(_on_dialog_closed)
	
	# Darken the screen
	$FaderContainer/Fader.start_dark()
	
	_show_menu.call_deferred()

func _show_menu(show_credits: bool = false) -> void:
	$PauseMenu.reset()
	world.visible = false
	$HUD.visible = false
	$Menu.visible = true
	$Menu.start_demo.call_deferred()
	
	$Menu.set_process_input(true)
	$Menu.resume(show_credits)
	
	# Reveal the menu
	$FaderContainer/Fader.fade_in()

func _on_start_requested(go: GameOptions) -> void:
	$Menu.set_process_input(false)
	game_options = go
	is_clock_running = false
	
	var input_strategy: InputStrategy
	if game_options.demo_mode:
		var history: Array[Dictionary] = []
		for v in SimulatedPlayer.load_history():
			history.append(v as Dictionary)
		input_strategy = SimulatedInputStrategy.new(history)
	else:
		input_strategy = RealInputStrategy.new()
	
	world.visible = false
	world.set_process(false)
	if not game_options.demo_mode:
		# Darken the screen
		$FaderContainer/Fader.fade_out()
		await Events.fade_completed
		$HUD.visible = false
		$FaderContainer/Fader.start_dark()
		music.play(Music.Song.Boss)
	
	# Setup the initial game state
	await world.reset(input_strategy, initial_screen_index)
	initial_screen_index = world.get_screen_index(game_options.starting_level)
	camera.global_position.y = WORLD_OFFSET
	current_screen_index = -1
	current_health = Settings.difficulty.starting_lives
	Events.player_entered_screen.emit(initial_screen_index)
	Events.player_health_changed.emit(current_health, false)
	Events.time_changed.emit(0.0)
	world.visible = true
	game_time = 0.0
	
	if game_options.demo_mode:
		$DemoFaderContainer/Fader.fade_in()
	else:
		$Menu.hide()
		$FaderContainer/Fader.fade_in()
	
	await Events.fade_completed
	player.position = Vector2i(0, 94)
	player.scale.x = 1.0
	player.show()
	player.set_process(true)
	
	# Play the Intro dialog # TODO: add option to allow it to be turned off
	if not game_options.demo_mode:
		await %Dialog.perform_dialog('intro')
		Settings.set_setting('dialog', 'seen_intro', true)
	
	if game_options.demo_mode:
		$Menu.set_process_input(true) # Resume input from menu
	else:
		# Show the HUD now that the Intro is over
		$HUD.visible = true
		music.play(Music.Song.Standard)
	
	# Start playing!
	Events.game_started.emit()
	is_clock_running = true

func _on_game_paused() -> void:
	is_clock_running = false
	get_tree().paused = true
	$PauseMenu.reset()
	$PauseMenu.visible = true

func _on_game_resumed() -> void:
	$PauseMenu.visible = false
	get_tree().paused = false
	is_clock_running = true

func _on_princess_saved() -> void:
	is_clock_running = false
	
	# Check the current time against the previous best time
	var difficulty := Settings.get_setting('game', 'difficulty', 'Normal') as String
	var best_time := Settings.get_setting('difficulty_%s' % difficulty, 'best_time', -1) as int
	if game_time < best_time or best_time == -1:
		best_time = game_time
		# Save the new best time (but only if no cheat codes were used)
		if not game_options.invincible and game_options.starting_level == 'screen_01':
			Settings.set_setting('difficulty_%s' % difficulty, 'best_time', game_time)
	
	await %Dialog.perform_dialog('finale')
	
	var lines: Array[String] = [
		'You Finished In',
		Utils.format_time(game_time),
		'Your Personal Best',
		Utils.format_time(best_time),
	]
	await %Dialog.perform_custom_dialog(lines)
	
	Events.game_ended.emit(true)

func _on_game_ended(show_credits: bool) -> void:
	is_clock_running = false
	$PauseMenu.visible = false
	get_tree().paused = false

	# TODO: some kind of death animation / screen (if not showing credits)
	
	if game_options.demo_mode:
		await $DemoFaderContainer/Fader.fade_out()
	else:
		music.stop()
		await $FaderContainer/Fader.fade_out()
	
	world.tear_down()
	
	if game_options.demo_mode:
		await get_tree().create_timer(2.0).timeout
		$Menu.start_demo.call_deferred()
	else:
		_show_menu(show_credits)

func _physics_process(_delta: float) -> void:
	if not is_clock_running:
		return
	
	# Stop processing screen transitions if the player is dead
	if player.state == Player.MoveState.Defeated:
		return
	
	var player_offset := 0 # TODO: Tweak to improve the screen transition to reduce the amount of thrashing
	var screen_index = floori(-(player.position.y + player_offset - WORLD_OFFSET) / SCREEN_HEIGHT) + initial_screen_index
	if screen_index < initial_screen_index:
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

func _on_player_damaged(damage: int, _attack_direction: float) -> void:
	if player.is_immune:
		return
	
	# Don't take damage if the player is invincible
	if not game_options.invincible:
		current_health -= damage
	
	Events.player_health_changed.emit(current_health, true)

func _on_player_caught_fly(fly: Fly) -> void:
	var new_health = min(current_health + 1, Settings.difficulty.max_lives)
	if new_health > current_health:
		current_health = new_health
		Events.player_health_changed.emit(current_health, false)
	
	# TODO: make an eating sound
	fly.queue_free()

func _on_player_death_finished() -> void:
	# TODO: fade out or something... You Died text, etc..
	Events.game_ended.emit(false)

func _on_player_entered_screen(index: int) -> void:
	_transition_to_screen(index)

func _transition_to_screen(index: int) -> void:
	# Bail out if we're already in this screen
	if index == current_screen_index:
		return
	
	# Check if we need to start the boss sequence
	if not game_options.demo_mode and world.is_final_screen(index):
		music.play(Music.Song.Boss)
		%Dialog.perform_dialog('found_princess')
	
	# Also bail out if the game is just starting
	if current_screen_index == -1:
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

func _on_tutorial_step_completed(step_name: String) -> void:
	if game_options.demo_mode:
		return
	Settings.set_setting('tutorial', step_name, true)

func _on_dialog_opened() -> void:
	is_clock_running = false
	world.set_process_input(false)
	player.set_process_input(false)

func _on_dialog_closed() -> void:
	is_clock_running = true
	world.set_process_input(true)
	if player.visible:
		player.set_process_input(true)
