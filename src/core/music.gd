extends Node
class_name Music

@onready var standard_music: AudioStreamPlayer = $Standard
@onready var boss_music: AudioStreamPlayer = $Boss

enum Song {
	Standard,
	Boss,
}

func play(song: Song) -> void:
	match song:
		Song.Standard:
			if boss_music.playing:
				_fade_out(boss_music)
				_fade_in(standard_music)
			else:
				standard_music.volume_db = 0.0
				standard_music.play()
		
		Song.Boss:
			if standard_music.playing:
				_fade_in(boss_music)
				_fade_out(standard_music)
			else:
				boss_music.volume_db = 0.0
				boss_music.play()

func stop() -> void:
	_fade_out(standard_music, 1.0)
	_fade_out(boss_music, 1.0)

func _fade_in(player: AudioStreamPlayer, duration := 2.0):
	if player.playing:
		return
	player.volume_db = -80.0
	player.playing = true
	var tween = get_tree().create_tween()
	tween.tween_property(player, "volume_db", 0.0, duration)

func _fade_out(player: AudioStreamPlayer, duration := 2.0):
	if not player.playing:
		return
	var tween = get_tree().create_tween()
	tween.tween_property(player, "volume_db", -80.0, duration)
	tween.tween_callback(player.stop)
