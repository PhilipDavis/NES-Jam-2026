extends CanvasLayer
class_name Dialog

@export var prince_sprite_frames: SpriteFrames
@export var princess_sprite_frames: SpriteFrames
@export var stork_sprite_frames: SpriteFrames

@onready var dialog_box: DialogBox = $DialogContainer/DialogBox

func perform_dialog(dialog_name: String) -> void:
	visible = true
	Events.dialog_opened.emit()
	set_process_input(true)
	var lines := _read_dialog_file(dialog_name)
	
	for line in lines:
		await _process_line(line)
	
	dialog_box.hide_dialog()
	Events.dialog_closed.emit()

func perform_custom_dialog(raw_text: Array[String]) -> void:
	visible = true
	Events.dialog_opened.emit()
	set_process_input(true)
	
	var text: String = '\n'.join(raw_text.map(tr))
	dialog_box.show_dialog(prince_sprite_frames, text, null)
	await Events.dialog_continued
	
	dialog_box.hide_dialog()
	Events.dialog_closed.emit()

func _read_dialog_file(dialog_name: String) -> PackedStringArray:
	var file := FileAccess.open('res://display/dialog/%s_dialog.txt' % dialog_name, FileAccess.READ)
	var lines := file.get_as_text().split('\n')
	file.close()
	return lines

var line_regex = RegEx.create_from_string('^([a-z]+): (.+)$')
func _parse_line(line: String) -> Array[String]:
	var line_match = line_regex.search(line)
	assert(line_match.get_group_count() == 2, 'Unexpected dialog line: "%s"' % line)
	
	var speaker = line_match.get_string(1)
	var text = line_match.get_string(2)
	return [ speaker, text ]

func _process_line(line: String) -> void:
	if line.length() == 0 or line[0] == '#':
		return
	
	var parsed := _parse_line(line)
	var text := parsed[1]
	
	match parsed[0]:
		'event':
			dialog_box.hide_dialog()
			Events.dialog_event.emit(text)
			await Events.dialog_event_ended
			return
		
		'narrator':
			dialog_box.show_dialog(null, text, null)
		
		'prince':
			dialog_box.show_dialog(prince_sprite_frames, text, null)
		
		'princess':
			dialog_box.show_dialog(princess_sprite_frames, text, null)
		
		'stork':
			dialog_box.show_dialog(null, text, stork_sprite_frames)
	
	await Events.dialog_continued
