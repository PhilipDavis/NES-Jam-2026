extends Node2D

@onready var screen_container: Node2D = $ScreenContainer
@onready var player: Player = $Player

var screen_list: Array[String] = []
var screen_map: Dictionary[String, PackedScene] = {}
var screen_name_by_index: Dictionary[int, String] = {}
var screen_index_by_name: Dictionary[String, int] = {}
var is_loaded_by_index: Dictionary[int, bool] = {}
var next_y_offset := 0.0

func _ready() -> void:
	Events.player_entered_screen.connect(_on_player_entered_screen)
	_load_screen_metadata()

func get_screen_index(screen_name: String) -> int:
	return screen_index_by_name.get(screen_name, 0)

func tear_down() -> void:
	# Discard all the loaded screens
	for screen in screen_container.get_children():
		screen_container.remove_child(screen)
		screen.queue_free()
	
	# Reset the data structures
	next_y_offset = 0.0
	screen_map.clear()
	is_loaded_by_index.clear()

func reset(input_strategy: InputStrategy, starting_index: int) -> void:
	tear_down()
	await _preload_screen(starting_index)
	player.reset(input_strategy)

func _on_player_entered_screen(index: int) -> void:
	# When player enters a screen, load that screen and preload the following screen
	_load_screen(index)
	_preload_screen(index + 1)

func _preload_screen(index: int) -> void:
	# Bail out if the given screen doesn't exist (e.g. we're at the final screen already)
	if index >= screen_name_by_index.size():
		return
	
	# Find the screen name and bail out if we've already loaded it
	var screen_name := screen_name_by_index[index]
	if screen_map.has(screen_name):
		return
	
	# Load the screen in the background
	var resource_name = 'res://screens/%s/%s.tscn' % [ screen_name, screen_name ]
	ResourceLoader.load_threaded_request(resource_name)
	for i in range(11):
		if ResourceLoader.load_threaded_get_status(resource_name) == ResourceLoader.THREAD_LOAD_LOADED:
			break
		
		# Bail after ten failed attempts
		if i >= 10:
			print('Failed to load scene ', resource_name)
			get_tree().quit(1)
		await get_tree().create_timer(1.0).timeout
	
	var scene := ResourceLoader.load_threaded_get(resource_name) as PackedScene
	screen_map[screen_name] = scene

func _load_screen(index: int) -> void:
	assert(index <= screen_name_by_index.size())
	
	# Bail out if we've already loaded it
	if is_loaded_by_index.has(index):
		return
	
	if not screen_name_by_index.has(index):
		# No more screens!
		Events.game_ended.emit()
		return
	
	# Instantiate the screen and at it to the top of the growing tower
	var screen_name := screen_name_by_index[index]
	var scene := screen_map.get(screen_name) as PackedScene
	
	# HACK: There is a bug with screen loading (when not starting at the
	# beginning screen) and I don't have time to fix it... So just force-
	# load the screen if it hasn't been loaded yet.
	if not scene:
		await _preload_screen(index)
		scene = screen_map.get(screen_name) as PackedScene
	
	var screen := scene.instantiate() as Node2D
	screen.global_position.y = next_y_offset
	$ScreenContainer.add_child(screen)
	
	# Update the next offset for the next screen
	var background := screen.get_node('Background')
	assert(background.has_method('get_rect'))
	next_y_offset -= background.get_rect().size.y
	
	# Notify that the screen has loaded.
	# Enemies will listen for this to know when to activate.
	# We do this outside of the standard _ready() processing
	# because the enemies are marked as @tool and they were
	# moving prematurely.
	# TODO: must be a way to fix/improve this and remove this hack
	is_loaded_by_index[index] = true
	Events.screen_ready.emit(screen)

func _load_screen_metadata() -> void:
	var file := FileAccess.open('res://screens/screen_layout.txt', FileAccess.READ)
	var list = file.get_as_text().split('\n')
	file.close()
	
	# Screens are top down but we need to add them bottom up
	list.reverse()
	
	var index := 0
	for screen_name in list:
		# Ignore comments and empty(ish) lines
		if screen_name.begins_with('#'):
			continue
		elif screen_name.length() <= 1:
			continue
		
		var scene := load('res://screens/%s/%s.tscn' % [ screen_name, screen_name ])
		if not scene:
			print('Failed to load screen: ', screen_name)
		
		screen_list.append(screen_name)
		screen_name_by_index[index] = screen_name
		screen_index_by_name[screen_name] = index
		index += 1
