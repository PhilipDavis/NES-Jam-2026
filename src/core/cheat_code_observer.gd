extends Node
class_name CheatCodeObserver

const cheat_codes: Dictionary[String, Array] = {
	'invicibility': [ 'select', 'A', 'A', 'A', 'select', 'ui_up', 'ui_up', 'ui_up', 'start' ],
	'warp_to_boss_level': [ 'select', 'A', 'B', 'A', 'B', 'select', 'ui_up', 'ui_up', 'ui_up', 'start' ],
}

var action_queue: Array[String] = []
var longest_cheat_code: int

func _ready() -> void:
	var max_length := 0
	for sequence in cheat_codes.values():
		max_length = max(max_length, sequence.size())

func notify(action: String) -> void:
	action_queue.push_back(action)
	if action_queue.size() > longest_cheat_code:
		action_queue.pop_front()
	
	# Iterate through the cheat codes, comparing the current
	# action queue to the cheat code sequences. 
	for cheat_code_name in cheat_codes.keys():
		var sequence := cheat_codes[cheat_code_name]
		if sequence.size() > action_queue.size():
			continue
		# Only consider the tail end of the action queue
		var offset := action_queue.size() - sequence.size()
		var found := true
		for i in range(sequence.size()):
			if action_queue[i] != sequence[i]:
				found = false
				break
		if found:
			print('Cheat code %s' % cheat_code_name)
			action_queue.clear()
			Events.cheat_code_entered.emit(cheat_code_name)
			return
