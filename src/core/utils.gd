extends Node

func format_time(total_seconds: int) -> String:
	var seconds := total_seconds % 60
	var minutes := mini((total_seconds - seconds) / 60, 999)
	return "%d:%02d" % [ minutes, seconds ]
