extends CanvasLayer

@onready var frog_head: AnimatedSprite2D = %FrogHead
@onready var menu_in_audio: AudioStreamPlayer = $Audio/MenuIn
@onready var menu_move_audio: AudioStreamPlayer = $Audio/MenuMove
@onready var menu_out_audio: AudioStreamPlayer = $Audio/MenuOut

const pause_y_offsets: Array[float] = [
	16.0, # Resume
	38.0, # Quit
]

var selected_index := 0
var selection_tween: Tween

func reset() -> void:
	visible = false
	_select(0, true)
	frog_head.play('Idle')
	if selection_tween:
		selection_tween.stop()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up"):
		menu_move_audio.play()
		_select(selected_index - 1)
	
	elif event.is_action_pressed("ui_down"):
		menu_move_audio.play()
		_select(selected_index + 1)
	
	elif event.is_action_pressed('select'):
		Events.game_resumed.emit()
	
	elif event.is_action_pressed('start'):
		match selected_index:
			0: Events.game_resumed.emit()
			1: Events.game_ended.emit()

func _select(index: int, skip_animation: bool = false) -> void:
	selected_index = (index + pause_y_offsets.size()) % pause_y_offsets.size()
	
	if selection_tween:
		selection_tween.stop()
	
	if skip_animation:
		frog_head.position.y = pause_y_offsets[selected_index]
	else:
		selection_tween = create_tween()
		selection_tween.set_ease(Tween.EASE_OUT)
		selection_tween.tween_property(frog_head, 'position:y', pause_y_offsets[selected_index], 0.1)
	
	if not skip_animation:
		frog_head.play('Blink')

func _on_frog_head_animation_looped() -> void:
	if frog_head.animation == 'Blink':
		frog_head.play('Idle')
