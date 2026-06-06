extends CanvasLayer

@onready var frog_head: AnimatedSprite2D = %FrogHead
@onready var credits: RichTextLabel = %Credits
@onready var menu_theme_audio: AudioStreamPlayer = $Audio/MenuTheme
@onready var menu_in_audio: AudioStreamPlayer = $Audio/MenuIn
@onready var menu_move_audio: AudioStreamPlayer = $Audio/MenuMove
@onready var menu_out_audio: AudioStreamPlayer = $Audio/MenuOut

const main_y_offsets: Array[float] = [
	141.0, # Start
	163.0, # Options
	185.0, # Credits
]

const options_y_offsets: Array[float] = [
	 97.0, # Music Volume
	119.0, # Effects Volume
	141.0, # Language
	163.0, # Back
]

const language_y_offsets: Array[float] = [
	 97.0, # English
	119.0, # Estonian
	141.0, # Finnish
	163.0, # Italian
]

const credits_y_offsets: Array[float] = [
	185.0, # Back
]

var current_menu := 'main' # TODO: use an enum
var selected_index := 0
var selection_tween: Tween

const CREDITS_SPEED := 0.5
var credits_tween: Tween

func _ready() -> void:
	$MainPage.visible = true
	$OptionsPage.visible = false
	$LanguagePage.visible = false
	$CreditsPage.visible = false
	credits.text = FileAccess.open('res://menu/credits.txt', FileAccess.READ).get_as_text() as String
	await get_tree().process_frame
	credits.size.y = credits.get_content_height()
	credits.custom_minimum_size.y = credits.get_content_height()
	resume()

func resume() -> void:
	menu_theme_audio.play()
	frog_head.play('Idle')

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up"):
		menu_move_audio.play()
		_select(selected_index - 1)
	
	elif event.is_action_pressed("ui_down"):
		menu_move_audio.play()
		_select(selected_index + 1)
	
	elif event.is_action_pressed("start"):
		match current_menu:
			'main':
				match selected_index:
					0: _start_game()
					1: _show_options()
					2: _show_credits()
			'options':
				match selected_index:
					0: pass # TODO
					1: pass # TODO
					2: _show_languages()
					3: _hide_options()
			'language':
				_hide_languages()
			'credits':
				_hide_credits()
	
	elif event.is_action_pressed('select'):
		match current_menu:
			'options':
				_hide_options()
			'language':
				_hide_languages()
			'credits':
				_hide_credits()

func _select(index: int, skip_animation: bool = false) -> void:
	var offsets: Array[float]
	if current_menu == 'main':
		offsets = main_y_offsets
	elif current_menu == 'options':
		offsets = options_y_offsets
	elif current_menu == 'language':
		offsets = language_y_offsets
	else:
		offsets = credits_y_offsets
	
	selected_index = (index + offsets.size()) % offsets.size()
	
	if selection_tween:
		selection_tween.stop()
	
	if skip_animation:
		frog_head.global_position.y = offsets[selected_index]
	else:
		selection_tween = create_tween()
		selection_tween.set_ease(Tween.EASE_OUT)
		selection_tween.tween_property(frog_head, 'global_position:y', offsets[selected_index], 0.1)
	
	frog_head.play('Blink')

func _on_frog_head_animation_looped() -> void:
	if frog_head.animation == 'Blink':
		frog_head.play('Idle')

func _start_game() -> void:
	menu_in_audio.play()
	menu_theme_audio.stop()
	# TODO: stop demo playthrough (if we implement it)
	Events.start_requested.emit()

func _show_options() -> void:
	current_menu = 'options'
	$MainPage.visible = false
	$OptionsPage.visible = true
	menu_in_audio.play()
	frog_head.play('Blink')
	_select(-1) # Back

func _hide_options() -> void:
	current_menu = 'main'
	$MainPage.visible = true
	$OptionsPage.visible = false
	menu_out_audio.play()
	frog_head.play('Blink')
	_select(1) # Options

func _show_languages() -> void:
	current_menu = 'language'
	$OptionsPage.visible = false
	$LanguagePage.visible = true
	menu_in_audio.play()
	frog_head.play('Blink')
	match TranslationServer.get_locale():
		'et_EE': _select(1, true)
		'it_IT': _select(2, true)
		'fi_FI': _select(3, true)
		_: _select(0, true)

func _hide_languages() -> void:
	match selected_index:
		0: _select_locale('en_US')
		1: _select_locale('et_EE')
		2: _select_locale('it_IT')
		3: _select_locale('fi_FI')
	
	current_menu = 'options'
	$OptionsPage.visible = true
	$LanguagePage.visible = false
	menu_out_audio.play()
	frog_head.play('Blink')
	_select(2) # Language

func _select_locale(locale: String) -> void:
	TranslationServer.set_locale(locale)
	# TODO: play a success audio sound

func _show_credits() -> void:
	current_menu = 'credits'
	$MainPage.visible = false
	$CreditsPage.visible = true
	menu_in_audio.play()
	frog_head.play('Blink')
	_select(0)
	
	# Scroll 16 pixels at a time to emulate a retro look
	const chunk_size := 16.0
	var iterations := ceilf(credits.get_content_height() / chunk_size)
	credits_tween = create_tween()
	for i in range(iterations):
		credits_tween.tween_property(credits, 'position:y', -i * chunk_size, 0.0)
		credits_tween.tween_interval(CREDITS_SPEED)
	credits_tween.tween_callback(_hide_credits.bind())

func _hide_credits() -> void:
	current_menu = 'main'
	$MainPage.visible = true
	$CreditsPage.visible = false
	menu_out_audio.play()
	frog_head.play('Blink')
	if credits_tween.is_running():
		credits_tween.stop()
	_select(2) # Credits
