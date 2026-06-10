extends Resource
class_name Difficulty

# How many lives the player has when the game starts
@export var starting_lives: int

# Aggressive spider will immediately attack towards the
# player when the player is above or below the spider
@export var aggressive_spider: bool

# How many hits it takes to kill a spider
@export var spider_health: int = 3

# Fearless rats don't get surprised when they see the player.
# (i.e. they will chase immediately without first jumping)
@export var fearless_rats: bool

# How many pixels per second the rat moves in Chase mode
@export var rat_chase_speed: float = 192.0

# TODO: speeds of various things
# TODO: time limit?
# TODO: quantity of enemies per screen?
# TODO: 
