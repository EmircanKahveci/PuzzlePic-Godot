extends Node2D
class_name PuzzlePiece

var row_index = 0
var col_index = 0
var group_id = 0
var target_position = Vector2.ZERO
var shape_points = PackedVector2Array()
var uv_points = PackedVector2Array()
var photo_texture = null
var is_selected = false
var is_hint = false

func configure(row_value, col_value, group_value, target_value, shape_value, uv_value, texture_value):
	row_index = row_value
	col_index = col_value
	group_id = group_value
	target_position = target_value
	shape_points = shape_value
	uv_points = uv_value
	photo_texture = texture_value
	queue_redraw()

func _draw():
	if shape_points.size() < 3:
		return
	var colors = PackedColorArray()
	for _i in range(shape_points.size()):
		colors.append(Color.WHITE)
	if photo_texture != null:
		draw_polygon(shape_points, colors, uv_points, photo_texture)
	else:
		draw_colored_polygon(shape_points, Color(0.35, 0.55, 0.9, 1.0))
	var outline = PackedVector2Array()
	for p in shape_points:
		outline.append(p)
	outline.append(shape_points[0])
	var outline_color = Color(0.06, 0.09, 0.15, 0.88)
	var outline_width = 2.0
	if is_selected:
		outline_color = Color(0.35, 0.72, 1.0, 1.0)
		outline_width = 4.0
	elif is_hint:
		outline_color = Color(1.0, 0.77, 0.18, 1.0)
		outline_width = 5.0
	draw_polyline(outline, outline_color, outline_width, true)

func contains_world_point(world_point):
	if shape_points.size() < 3:
		return false
	return Geometry2D.is_point_in_polygon(to_local(world_point), shape_points)

func set_selected(value):
	is_selected = value
	z_index = 200 if value else group_id % 100
	queue_redraw()

func set_hint(value):
	is_hint = value
	queue_redraw()
