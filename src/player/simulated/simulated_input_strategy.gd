extends InputStrategy
class_name SimulatedInputStrategy

var current_frame := 0
var input_history: Array[Dictionary] = []
var is_pressed: Dictionary[String, bool] = {}

func _init(history: Array[Dictionary]):
	input_history = history

func advance_frame() -> void:
	current_frame += 1
	_update_state()

func _remove_expired_events() -> void:
	while input_history.size():
		var next_event := input_history[0]
		if next_event.frame >= current_frame:
			return
		input_history.pop_front()

func _update_state() -> void:
	_remove_expired_events()
	
	var index := 0
	while input_history.size() > index:
		var event := input_history[index]
		if event.frame > current_frame:
			return
		is_pressed[event.action] = event.pressed
		index += 1

func get_axis(left_action: String, right_action: String) -> float:
	if is_pressed.get(left_action, false):
		return -1.0
	elif is_pressed.get(right_action, false):
		return 1.0
	return 0.0

func is_action_pressed(action: String) -> bool:
	return is_pressed.get(action, false)

func is_action_just_pressed(action: String) -> bool:
	_remove_expired_events()
	
	var index = 0
	while input_history.size() > index:
		# Bail out if the next event hasn't happened yet
		var event := input_history[index]
		if event.frame > current_frame:
			return false
		
		if event.action == action and event.pressed:
			return true
		
		index += 1
	
	return false

func is_action_just_released(action: String) -> bool:
	_remove_expired_events()
	
	var index = 0
	while input_history.size() > index:
		# Bail out if the next event hasn't happened yet
		var event := input_history[index]
		if event.frame > current_frame:
			return false
		
		if event.action == action and not event.pressed:
			return true
		
		index += 1
	
	return false
