extends InputStrategy
class_name RealInputStrategy

func advance_frame() -> void:
	pass

func is_action_just_pressed(action: String) -> bool:
	return Input.is_action_just_pressed(action)

func is_action_just_released(action: String) -> bool:
	return Input.is_action_just_released(action)

func is_action_pressed(action: String) -> bool:
	return Input.is_action_pressed(action)

func get_axis(left_action: String, right_action: String) -> float:
	return Input.get_axis(left_action, right_action)
