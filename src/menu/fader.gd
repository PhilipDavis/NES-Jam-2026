extends Control
class_name  Fader

const FADE_DURATION := 0.8

func _ready() -> void:
	visible = false

func start_dark() -> void:
	var texture := $TextureRect.texture as AtlasTexture
	texture.region.position.x = 48
	visible = true

func fade_in() -> void:
	await _fade(false)

func fade_out() -> void:
	await _fade(true)

func _fade(out: bool) -> void:
	var texture := $TextureRect.texture as AtlasTexture
	texture.region.position.x = 0 if out else 48
	var target = 48 - texture.region.position.x
	var delta = 16 if out else -16
	
	visible = true
	for i in range(3):
		await get_tree().create_timer(FADE_DURATION / 4).timeout
		texture.region.position.x += delta
	await get_tree().create_timer(FADE_DURATION / 4).timeout
	
	Events.fade_completed.emit()
	visible = false
