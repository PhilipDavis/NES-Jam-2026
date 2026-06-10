extends Node

enum State {
	Dormant,
	Recording,
	PlayingBack,
}

@export var state := State.Dormant

var is_game_on := false
var current_frame := 0
var input_history: Array[Dictionary] = []

const history_filename := "user://simulated_player.json"

const actions_to_watch = [
	"attack",
	"jump",
	"ui_left",
	"ui_right",
	"ui_up",
	"ui_down",
]

func _ready() -> void:
	Events.game_started.connect(_on_game_started)
	Events.game_ended.connect(_on_game_ended)

func _on_game_started() -> void:
	is_game_on = true
	current_frame = 0

func _on_game_ended() -> void:
	is_game_on = false
	_save_history()

func _physics_process(delta: float) -> void:
	if not is_game_on or state == State.Dormant:
		return
	
	current_frame += 1
	
	if state == State.Recording:
		_record_current_action()

func _record_current_action() -> void:
	for action in actions_to_watch:
		if Input.is_action_just_pressed(action):
			_record(action, true)
		if Input.is_action_just_released(action):
			_record(action, false)

func _record(action: String, pressed: bool) -> void:
	input_history.append({
		'frame': current_frame,
		'action': action,
		'pressed': pressed,
	})

func _save_history() -> void:
	var json = JSON.stringify(input_history)
	var file = FileAccess.open(history_filename, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open file for writing: %s" % history_filename)
		return
	file.store_string(json)
	file.close()

static func load_history() -> Array[Dictionary]:
	var file := FileAccess.open('res://player/simulated/simulated_events.json', FileAccess.READ)
	if not file:
		return []
	var json := file.get_as_text()
	return JSON.parse_string(json) as Array[Dictionary]
