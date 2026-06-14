extends Control
class_name DialogBox

@onready var left_portrait: AnimatedSprite2D = %LeftPortrait
@onready var right_portrait: AnimatedSprite2D = %RightPortrait
@onready var dialog_text: RichTextLabel = %DialogText

# Characters per second
const DIALOG_SPEED := 16.0
const NARRATOR_SPEED := 32.0

var is_open := false
var tween: Tween

func _ready() -> void:
	set_process_input(false)
	# TODO: collapse to 0 size
	pass

func show_dialog(left_sprite_frames: SpriteFrames, raw_text: String, right_sprite_frames: SpriteFrames) -> void:
	var text = tr(raw_text, 'dialog')
	dialog_text.text = text
	dialog_text.visible_characters = 0
	set_process_input(true)
	
	# TODO: grow in size if not yet open
	show()
	
	left_portrait.sprite_frames = left_sprite_frames
	if left_sprite_frames:
		%LeftPortraitWrapper.custom_minimum_size.x = 32
	else:
		%LeftPortraitWrapper.custom_minimum_size.x = 0
	
	right_portrait.sprite_frames = right_sprite_frames
	if right_sprite_frames:
		%RightPortraitWrapper.custom_minimum_size.x = 32
	else:
		%RightPortraitWrapper.custom_minimum_size.x = 0
	
	var is_narrator = not left_sprite_frames and not right_sprite_frames
	dialog_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if is_narrator else HORIZONTAL_ALIGNMENT_LEFT
	
	_play_animation('Speaking')
	
	var speed := NARRATOR_SPEED if is_narrator else DIALOG_SPEED
	var duration := text.length() / speed
	tween = create_tween()
	tween.tween_property(dialog_text, 'visible_characters', text.length(), duration)
	await tween.finished
	tween = null
	
	_play_animation('Idle')

func _play_animation(anim: String) -> void:
	if left_portrait.sprite_frames:
		assert(left_portrait.sprite_frames.has_animation(anim))
		left_portrait.play(anim)
	
	elif right_portrait.sprite_frames:
		assert(right_portrait.sprite_frames.has_animation(anim))
		right_portrait.play(anim)

func hide_dialog() -> void:
	# TODO: animate the window closing
	is_open = false
	set_process_input(false)
	hide()

func _input(event: InputEvent) -> void:
	# Watch for A / Start button to continue
	if event.is_action_released('continue'):
		# Show all characters if Continue is pressed
		if tween and tween.is_running():
			tween.stop()
			_play_animation('Idle')
			await get_tree().process_frame
			dialog_text.visible_ratio = 1.0
		else:
			Events.dialog_continued.emit()
