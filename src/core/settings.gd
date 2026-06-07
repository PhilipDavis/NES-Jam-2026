extends Node

var settings: Dictionary[String, Variant] = {}

const settings_filename = 'user://options.cfg'

func _ready() -> void:
	_read_settings()

func _make_key(section: String, name: String) -> String:
	assert(not section.contains(':'))
	assert(not name.contains(':'))
	return '%s:%s' % [ section, name ]

func get_setting(section: String, name: String, default_value: Variant = null) -> Variant:
	var key := _make_key(section, name)
	return settings.get(key, default_value)

func set_setting(section: String, name: String, value: Variant) -> void:
	if not settings.has(name) or settings.get(value) != value:
		var key := _make_key(section, name)
		settings[key] = value
		_save_settings()

func _read_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load_encrypted_pass(settings_filename, settings_filename)
	if err != OK:
		print('Failed to read settings')
		return
	
	for section in config.get_sections():
		for name in config.get_section_keys(section):
			var key := _make_key(section, name)
			var value = config.get_value(section, name)
			settings.set(key, value)

func _save_settings() -> void:
	var config := ConfigFile.new()
	for section_and_key in settings:
		var sk = section_and_key.split(':')
		var section = sk[0]
		var key = sk[1]
		config.set_value(section, key, settings[section_and_key])
	
	config.save_encrypted_pass(settings_filename, settings_filename)
