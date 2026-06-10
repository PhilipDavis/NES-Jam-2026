@abstract extends Node
class_name InputStrategy

@abstract func advance_frame() -> void
@abstract func is_action_just_pressed(action: String) -> bool
@abstract func is_action_just_released(action: String) -> bool
@abstract func is_action_pressed(action: String) -> bool
@abstract func get_axis(left_action: String, right_action: String) -> float
