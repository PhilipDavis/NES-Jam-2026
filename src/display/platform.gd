@tool
extends StaticBody2D
class_name Platform

const min_horizontal_cells := 2
const max_horizontal_cells := 28

enum Type {
	Stone,
	Wood,
}

@export var type := Type.Stone:
	set(value):
		type = value
		_update()

@export var start_visible := true

@export var width_in_cells := 8:
	set(value):
		assert(value % 2 == 0, 'Platform width expected to be a multiple of 2')
		width_in_cells = clampi(value, min_horizontal_cells, max_horizontal_cells)
		_update()

# This is the left side of the platform, not the center!
@export var cell_position := Vector2i.ZERO:
	set(value):
		# Playable screen size is 28x28 cells of 8x8
		cell_position = Vector2i(clampi(value.x, 0, max_horizontal_cells - width_in_cells), clampi(value.y, 0, 27))
		_update()

# For moving platforms
@export var min_position := Vector2i.ZERO
@export var max_position := Vector2i.ZERO

@onready var collision_shape := $CollisionShape2D
@onready var tiles := $TileMapLayer

const my_tile_set_id := 0

const stone_atlas: Array[Vector2i] = [
	# Left Side
	Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4), Vector2i(7, 4), 
	Vector2i(8, 4), Vector2i(9, 4), Vector2i(10, 4), Vector2i(11, 4), Vector2i(12, 4), Vector2i(13, 4),
#
	# Right Side
	Vector2i(0, 5), Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5), Vector2i(4, 5), Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5), 
	Vector2i(8, 5), Vector2i(9, 5), Vector2i(10, 5), Vector2i(11, 5), Vector2i(12, 5), Vector2i(13, 5),
]
const stone_caps_atlas: Dictionary[String, Vector2i] = {
	'left_end_mid': Vector2i(0, 6),
	'left_end_far': Vector2i(1, 6),
	'right_end_far': Vector2i(2, 6),
	'right_end_mid': Vector2i(3, 6),
}

const wood_atlas: Array[Vector2i] = [
	# Left Side
	Vector2i(0, 7),
	Vector2i(1, 7), Vector2i(1, 7), Vector2i(1, 7), Vector2i(1, 7), Vector2i(1, 7), Vector2i(1, 7), Vector2i(1, 7),
	Vector2i(2, 7), Vector2i(2, 7), Vector2i(2, 7), Vector2i(2, 7), Vector2i(2, 7),
	Vector2i(3, 7),
	
	# Right Side
	Vector2i(4, 7),
	Vector2i(4, 7), Vector2i(4, 7), Vector2i(4, 7), Vector2i(4, 7), Vector2i(4, 7), Vector2i(4, 7), Vector2i(4, 7),
	Vector2i(5, 7), Vector2i(5, 7), Vector2i(5, 7), Vector2i(5, 7), Vector2i(5, 7),
	Vector2i(6, 7),
]
const wood_caps_atlas: Dictionary[String, Vector2i] = {
	'left_end_mid': Vector2i(0, 7),
	'left_end_far': Vector2i(0, 7),
	'right_end_far': Vector2i(1, 8),
	'right_end_mid': Vector2i(2, 8),
}
# The anchor connects the platform to the wall
const wood_left_anchor_atlas := Vector2(0, 8)

# The tile set has some left-side tiles
# We flipped them in Alternative Tiles
# for display on the right side
const FLIPPED := 1

func _ready() -> void:
	if start_visible:
		show_platform()
	else:
		hide_platform()
	
	if collision_shape:
		collision_shape.shape = collision_shape.shape.duplicate()
		collision_shape.one_way_collision = type == Type.Wood
	_update()

func show_platform() -> void:
	visible = true
	collision_shape.disabled = false

func hide_platform() -> void:
	visible = false
	collision_shape.disabled = true

func _update() -> void:
	if not is_node_ready():
		return
	
	_update_position()
	_update_appearance()

func _update_position() -> void:
	# Set the collision shape size
	var rect := collision_shape.shape as RectangleShape2D
	rect.size.x = width_in_cells * 8
	rect.size.y = 8
	collision_shape.position.x = rect.size.x / 2.0
	collision_shape.position.y = rect.size.y / 2.0
	
	# Update the pixel position (centered at (0,0))
	position = Vector2(cell_position) * 8.0 - Vector2(112, 112 - 8)

func _update_appearance() -> void:
	# Erase everything and draw the main tiles
	tiles.clear()
	
	# Select which tiles to use based on the platform material type
	var atlas: Array[Vector2i]
	var caps_atlas: Dictionary[String, Vector2i]
	match type:
		Type.Stone:
			atlas = stone_atlas
			caps_atlas = stone_caps_atlas
		Type.Wood:
			atlas = wood_atlas
			caps_atlas = wood_caps_atlas
			
	# Set the tiles on the map based on location on screen.
	# We have to do this carefully because the tile placement
	# affects the perspective (from lines on the tiles)
	for i in range(width_in_cells):
		tiles.set_cell(Vector2(i, 0), my_tile_set_id, atlas[cell_position.x + i])
	
	# Overwrite the left-most tile with an end-cap tile
	var begin := cell_position.x
	if begin >= max_horizontal_cells * 3 / 4.0:
		tiles.set_cell(Vector2(0, 0), my_tile_set_id, caps_atlas.right_end_far, FLIPPED)
	elif begin >= max_horizontal_cells / 2.0:
		tiles.set_cell(Vector2(0, 0), my_tile_set_id, caps_atlas.right_end_mid, FLIPPED)
	elif begin >= max_horizontal_cells / 4.0:
		tiles.set_cell(Vector2(0, 0), my_tile_set_id, caps_atlas.left_end_mid)
	elif begin > 0:
		tiles.set_cell(Vector2(0, 0), my_tile_set_id, caps_atlas.left_end_far)
	
	# Overwrite the right-most tile with an end-cap tile
	var end := cell_position.x + width_in_cells
	if end < max_horizontal_cells / 4.0:
		tiles.set_cell(Vector2(width_in_cells - 1, 0), my_tile_set_id, caps_atlas.right_end_far)
	elif end < max_horizontal_cells / 2.0:
		tiles.set_cell(Vector2(width_in_cells - 1, 0), my_tile_set_id, caps_atlas.right_end_mid)
	elif end < max_horizontal_cells * 3 / 4.0:
		tiles.set_cell(Vector2(width_in_cells - 1, 0), my_tile_set_id, caps_atlas.left_end_mid, FLIPPED)
	elif end < max_horizontal_cells:
		tiles.set_cell(Vector2(width_in_cells - 1, 0), my_tile_set_id, caps_atlas.left_end_far, FLIPPED)
	
	# Draw the tile that anchors the platform to the wall (only applies to wood)
	if type == Type.Wood:
		if begin == 0:
			tiles.set_cell(Vector2(0, 1), my_tile_set_id, wood_left_anchor_atlas)
		if end == max_horizontal_cells:
			tiles.set_cell(Vector2(width_in_cells - 1, 1), my_tile_set_id, wood_left_anchor_atlas, FLIPPED)
