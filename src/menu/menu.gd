extends CanvasLayer

@onready var frog_head: AnimatedSprite2D = %FrogHead
@onready var credits: RichTextLabel = %Credits
@onready var menu_theme_audio: AudioStreamPlayer = $Audio/MenuTheme
@onready var menu_in_audio: AudioStreamPlayer = $Audio/MenuIn
@onready var menu_move_audio: AudioStreamPlayer = $Audio/MenuMove
@onready var menu_out_audio: AudioStreamPlayer = $Audio/MenuOut

var credits_source: String

const main_y_offsets: Array[float] = [
	141.0, # Start
	163.0, # Options
	185.0, # Credits
]

const options_y_offsets: Array[float] = [
	 75.0, # Music Volume
	 97.0, # Effects Volume
	119.0, # Language
	141.0, # Difficulty
	163.0, # Back
]

const language_y_offsets: Array[float] = [
	 75.0, # English
	 97.0, # Estonian
	119.0, # Spanish
	141.0, # Finnish
	163.0, # Italian
]

const credits_y_offsets: Array[float] = [
	185.0, # Back
]

const DEFAULT_DIFFICULTY = 'Normal'
const difficulty_levels := [ 'Normal', 'Hard' ] # TODO: add easy and nightmare
var difficulty_colors: Dictionary[String, Color] = {
	'Easy': Color.from_rgba8(113, 243, 65),
	'Normal': Color.from_rgba8(255, 255, 255),
	'Hard': Color.from_rgba8(162, 113, 255),
	'Nightmare': Color.from_rgba8(178, 16, 48),
}
var current_difficulty := DEFAULT_DIFFICULTY

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
	_load_difficulty()
	credits_source = FileAccess.open('res://menu/credits.txt', FileAccess.READ).get_as_text() as String
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
					3: _select_next_difficulty()
					4: _hide_options()
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

func start_demo() -> void:
	SimulatedPlayer.state = SimulatedPlayer.State.Dormant
	Events.start_requested.emit(true)

func _start_game() -> void:
	menu_in_audio.play()
	menu_theme_audio.stop()
	
	if OS.is_debug_build():
		SimulatedPlayer.state = SimulatedPlayer.State.Recording
	
	Events.start_requested.emit(false)

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
		'es_ES': _select(2, true)
		'it_IT': _select(3, true)
		'fi_FI': _select(4, true)
		_: _select(0, true)

func _hide_languages() -> void:
	match selected_index:
		0: _select_locale('en_US')
		1: _select_locale('et_EE')
		2: _select_locale('es_ES')
		3: _select_locale('it_IT')
		4: _select_locale('fi_FI')
	
	current_menu = 'options'
	$OptionsPage.visible = true
	$LanguagePage.visible = false
	menu_out_audio.play()
	frog_head.play('Blink')
	_select(2) # Language

func _select_locale(locale: String) -> void:
	TranslationServer.set_locale(locale)
	Settings.set_setting('game', 'locale', locale)
	_update_difficulty()
	# TODO: play a success audio sound

func _select_next_difficulty() -> void:
	var previous_difficulty = Settings.get_setting('game', 'difficulty', DEFAULT_DIFFICULTY)
	var previous_index = difficulty_levels.find(previous_difficulty)
	assert(previous_index >= 0)
	var new_index = (previous_index + 1) % difficulty_levels.size()
	current_difficulty = difficulty_levels[new_index]
	Settings.set_setting('game', 'difficulty', current_difficulty)
	_update_difficulty()

func _load_difficulty() -> void:
	current_difficulty = Settings.get_setting('game', 'difficulty', DEFAULT_DIFFICULTY)
	_update_difficulty()

func _update_difficulty() -> void:
	var index = difficulty_levels.find(current_difficulty)
	assert(index >= 0)
	%DifficultyValue.text = tr(current_difficulty, 'difficulty level')
	%DifficultyValue.modulate = difficulty_colors[current_difficulty]

func _prepare_credits() -> void:
	credits.text = _translate(credits_source)
	await get_tree().process_frame
	credits.size.y = credits.get_content_height()
	credits.custom_minimum_size.y = credits.size.y

func _translate(text: String) -> String:
	var regex := RegEx.create_from_string('^(\\[.+?\\])?(.+?)(\\[.+?\\])?$')
	
	var lines := text.split('\n')
	var translated_lines: Array[String]
	for line in lines:
		var m := regex.search(line)
		if m:
			var translated_line := ''
			for i in range(1, m.get_group_count() + 1):
				var s = m.get_string(i)
				translated_line += tr(s)
			translated_lines.append(translated_line)
		else:
			translated_lines.append(line)
	return '\n'.join(translated_lines)

func _show_credits() -> void:
	await _prepare_credits()
	
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
