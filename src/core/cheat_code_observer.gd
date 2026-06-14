extends Node
class_name CheatCodeObserver

enum CheatCode {
	Invincibility,
	WarpToBossLevel,
}

const cheat_codes: Dictionary[CheatCode, Array] = {
	CheatCode.Invincibility: [ 'select', 'A', 'B', 'B', 'A', 'select' ],
	CheatCode.WarpToBossLevel: [ 'select', 'A', 'B', 'A', 'B', 'select', 'ui_up', 'ui_up', 'ui_up', 'start' ],
}

var action_queue: Array[String] = []
var longest_cheat_code_sequence: int

func _init() -> void:
	for sequence in cheat_codes.values():
		longest_cheat_code_sequence = max(longest_cheat_code_sequence, sequence.size())

func notify(action: String) -> void:
	action_queue.push_back(action)
	if action_queue.size() > longest_cheat_code_sequence:
		action_queue.pop_front()
	
	# Iterate through the cheat codes, comparing the current
	# action queue to the cheat code sequences. 
	for cheat_code in cheat_codes.keys():
		var sequence := cheat_codes[cheat_code]
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
			action_queue.clear()
			Events.cheat_code_entered.emit(cheat_code)
			return
