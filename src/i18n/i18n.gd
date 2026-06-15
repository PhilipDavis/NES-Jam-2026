extends Node

func _ready():
	var dir = DirAccess.open('res://i18n')
	for filename in dir.get_files():
		if filename.ends_with('.po'):
			var po_data = load('res://i18n/%s' % filename)
			TranslationServer.add_translation(po_data)
	
	var locale := Settings.get_setting('game', 'locale', OS.get_locale()) as String
	if TranslationServer.has_translation_for_locale(locale, false):
		TranslationServer.set_locale(locale)
	else:
		TranslationServer.set_locale('en_US')
