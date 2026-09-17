extends Node2D

const PieceScene = preload("res://scripts/piece.gd")

var camera
var world_root
var pieces = []
var groups = {}
var grid_size = 6
var rotation_enabled = false
var photo_image = null
var photo_texture = null
var board_size = Vector2(1200, 900)
var board_origin = Vector2(-600, -450)
var table_rect = Rect2(-2200, -1800, 4400, 3600)
var rng = RandomNumberGenerator.new()
var dragged_group = -1
var drag_last_world = Vector2.ZERO
var pan_last_screen = Vector2.ZERO
var mouse_dragging_piece = false
var mouse_panning = false
var touch_points = {}
var touch_piece_index = -1
var pinch_last_distance = 0.0
var pinch_last_mid = Vector2.ZERO
var selected_piece = null
var rotate_button = null
var preview_sprite = null
var preview_timer = null
var hint_timer = null
var status_label = null
var progress_label = null
var file_dialog = null
var grid_option = null
var rotate_check = null
var save_debounce = 0.0
var elapsed_seconds = 0.0
var game_started = false
var current_save_id = ""

func _ready():
	rng.randomize()
	create_world()
	create_ui()
	create_default_image()
	start_new_puzzle()
	set_process(true)

func create_world():
	world_root = Node2D.new()
	world_root.name = "World"
	add_child(world_root)
	camera = Camera2D.new()
	camera.name = "Camera"
	camera.position = Vector2.ZERO
	camera.zoom = Vector2(0.72, 0.72)
	camera.position_smoothing_enabled = false
	add_child(camera)
	camera.make_current()

func create_ui():
	var layer = CanvasLayer.new()
	layer.layer = 20
	add_child(layer)

	var top = PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.custom_minimum_size = Vector2(0, 92)
	layer.add_child(top)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	top.add_child(margin)

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)

	var photo_btn = Button.new()
	photo_btn.text = "Fotoğraf"
	photo_btn.pressed.connect(open_photo_picker)
	row.add_child(photo_btn)

	grid_option = OptionButton.new()
	for n in [4, 6, 8, 10, 12, 15, 20]:
		grid_option.add_item(str(n) + "×" + str(n), n)
	grid_option.select(1)
	grid_option.item_selected.connect(on_grid_selected)
	row.add_child(grid_option)

	rotate_check = CheckButton.new()
	rotate_check.text = "Döndür"
	rotate_check.toggled.connect(on_rotation_toggled)
	row.add_child(rotate_check)

	var hint_btn = Button.new()
	hint_btn.text = "İpucu"
	hint_btn.pressed.connect(show_hint)
	row.add_child(hint_btn)

	var preview_btn = Button.new()
	preview_btn.text = "Önizleme"
	preview_btn.pressed.connect(show_preview)
	row.add_child(preview_btn)

	var reset_btn = Button.new()
	reset_btn.text = "Yeni"
	reset_btn.pressed.connect(start_new_puzzle)
	row.add_child(reset_btn)

	status_label = Label.new()
	status_label.text = "PuzzlePic"
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(status_label)

	progress_label = Label.new()
	progress_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	progress_label.position = Vector2(16, -58)
	progress_label.custom_minimum_size = Vector2(340, 44)
	layer.add_child(progress_label)

	rotate_button = Button.new()
	rotate_button.text = "↻"
	rotate_button.custom_minimum_size = Vector2(72, 72)
	rotate_button.visible = false
	rotate_button.pressed.connect(rotate_selected_group)
	layer.add_child(rotate_button)

	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.use_native_dialog = true
	file_dialog.filters = PackedStringArray(["*.png ; PNG", "*.jpg,*.jpeg ; JPEG", "*.webp ; WebP"])
	file_dialog.file_selected.connect(on_photo_selected)
	layer.add_child(file_dialog)

	preview_timer = Timer.new()
	preview_timer.one_shot = true
	preview_timer.wait_time = 2.2
	preview_timer.timeout.connect(hide_preview)
	add_child(preview_timer)

	hint_timer = Timer.new()
	hint_timer.one_shot = true
	hint_timer.wait_time = 2.0
	hint_timer.timeout.connect(clear_hint)
	add_child(hint_timer)

func create_default_image():
	photo_image = Image.create(1200, 800, false, Image.FORMAT_RGBA8)
	for y in range(800):
		for x in range(1200):
			var fx = float(x) / 1200.0
			var fy = float(y) / 800.0
			var c = Color(0.12 + fx * 0.25, 0.28 + fy * 0.30, 0.58 + fx * 0.22, 1.0)
			photo_image.set_pixel(x, y, c)
	photo_texture = ImageTexture.create_from_image(photo_image)

func _process(delta):
	if game_started:
		elapsed_seconds += delta
		save_debounce += delta
		if save_debounce >= 4.0:
			save_debounce = 0.0
			save_current_state()
	update_progress_label()
	update_rotate_button_position()

func _draw():
	draw_rect(table_rect, Color(0.07, 0.09, 0.12, 1.0), true)
	var step = 160
	var x = int(table_rect.position.x)
	while x <= int(table_rect.end.x):
		draw_line(Vector2(x, table_rect.position.y), Vector2(x, table_rect.end.y), Color(1,1,1,0.022), 1.0)
		x += step
	var y = int(table_rect.position.y)
	while y <= int(table_rect.end.y):
		draw_line(Vector2(table_rect.position.x, y), Vector2(table_rect.end.x, y), Color(1,1,1,0.022), 1.0)
		y += step
	var frame = Rect2(board_origin, board_size)
	draw_rect(frame.grow(8), Color(0.14, 0.19, 0.25, 0.8), true)
	draw_rect(frame, Color(0.58, 0.72, 0.88, 0.9), false, 5.0)

func open_photo_picker():
	file_dialog.popup_centered_ratio(0.88)

func on_photo_selected(path):
	var image = Image.new()
	var err = image.load(path)
	if err != OK:
		status_label.text = "Fotoğraf açılamadı"
		return
	if image.get_width() < 32 or image.get_height() < 32:
		status_label.text = "Fotoğraf çok küçük"
		return
	photo_image = image
	photo_texture = ImageTexture.create_from_image(photo_image)
	status_label.text = "Fotoğraf yüklendi"
	start_new_puzzle()

func on_grid_selected(index):
	grid_size = grid_option.get_item_id(index)
	start_new_puzzle()

func on_rotation_toggled(value):
	rotation_enabled = value
	start_new_puzzle()

func start_new_puzzle():
	clear_pieces()
	current_save_id = str(Time.get_unix_time_from_system())
	elapsed_seconds = 0.0
	game_started = true
	calculate_board_size()
	generate_pieces()
	camera.position = Vector2.ZERO
	var fit = min(880.0 / max(board_size.x, 1.0), 1180.0 / max(board_size.y, 1.0))
	fit = clamp(fit, 0.28, 1.05)
	camera.zoom = Vector2(fit, fit)
	queue_redraw()
	status_label.text = str(grid_size * grid_size) + " parça"
	save_current_state()

func calculate_board_size():
	var iw = float(photo_image.get_width())
	var ih = float(photo_image.get_height())
	var max_side = 1640.0
	if iw >= ih:
		board_size.x = max_side
		board_size.y = max_side * ih / iw
	else:
		board_size.y = max_side
		board_size.x = max_side * iw / ih
	board_origin = -board_size * 0.5
	var mx = board_size.x * 0.92 + 980.0
	var my = board_size.y * 0.92 + 980.0
	table_rect = Rect2(-mx, -my, mx * 2.0, my * 2.0)

func clear_pieces():
	for p in pieces:
		if is_instance_valid(p):
			p.queue_free()
	pieces.clear()
	groups.clear()
	selected_piece = null
	dragged_group = -1
	if preview_sprite != null and is_instance_valid(preview_sprite):
		preview_sprite.queue_free()
	preview_sprite = null

func generate_pieces():
	var right_edges = []
	var bottom_edges = []
	for r in range(grid_size):
		var right_row = []
		var bottom_row = []
		for c in range(grid_size):
			right_row.append(0 if c == grid_size - 1 else (1 if rng.randi_range(0,1) == 1 else -1))
			bottom_row.append(0 if r == grid_size - 1 else (1 if rng.randi_range(0,1) == 1 else -1))
		right_edges.append(right_row)
		bottom_edges.append(bottom_row)

	var cell_w = board_size.x / float(grid_size)
	var cell_h = board_size.y / float(grid_size)
	var total = grid_size * grid_size
	for r in range(grid_size):
		for c in range(grid_size):
			var top_sign = 0 if r == 0 else -bottom_edges[r - 1][c]
			var right_sign = right_edges[r][c]
			var bottom_sign = bottom_edges[r][c]
			var left_sign = 0 if c == 0 else -right_edges[r][c - 1]
			var shape = create_piece_shape(cell_w, cell_h, top_sign, right_sign, bottom_sign, left_sign)
			var target = board_origin + Vector2(c * cell_w, r * cell_h)
			var uv = PackedVector2Array()
			for local_p in shape:
				var src = target - board_origin + local_p
				uv.append(Vector2(src.x / board_size.x, src.y / board_size.y))
			var piece = PieceScene.new()
			var id = r * grid_size + c
			piece.configure(r, c, id, target, shape, uv, photo_texture)
			piece.position = scatter_position(id, total, cell_w, cell_h)
			if rotation_enabled:
				piece.rotation_degrees = [0.0, 90.0, 180.0, 270.0][rng.randi_range(0,3)]
			world_root.add_child(piece)
			pieces.append(piece)
			groups[id] = [piece]

func create_piece_shape(w, h, top_sign, right_sign, bottom_sign, left_sign):
	var pts = PackedVector2Array()
	append_edge(pts, Vector2(0,0), Vector2(w,0), Vector2(0,-1), top_sign, min(w,h) * 0.22)
	append_edge(pts, Vector2(w,0), Vector2(w,h), Vector2(1,0), right_sign, min(w,h) * 0.22, true)
	append_edge(pts, Vector2(w,h), Vector2(0,h), Vector2(0,1), bottom_sign, min(w,h) * 0.22, true)
	append_edge(pts, Vector2(0,h), Vector2(0,0), Vector2(-1,0), left_sign, min(w,h) * 0.22, true)
	return pts

func append_edge(arr, start, finish, normal, sign_value, depth, skip_first=false):
	var samples = [0.0, 0.24, 0.32, 0.37, 0.42, 0.50, 0.58, 0.63, 0.68, 0.76, 1.0]
	var amps = [0.0, 0.0, 0.0, 0.38, 0.86, 1.0, 0.86, 0.38, 0.0, 0.0, 0.0]
	for i in range(samples.size()):
		if skip_first and i == 0:
			continue
		var t = samples[i]
		var base = start.lerp(finish, t)
		var offset = normal * depth * float(sign_value) * amps[i]
		arr.append(base + offset)

func scatter_position(index, total, cell_w, cell_h):
	var side = index % 4
	var gap = max(cell_w, cell_h) * 1.15 + 70.0
	var jitter = Vector2(rng.randf_range(-55,55), rng.randf_range(-55,55))
	if side == 0:
		return Vector2(rng.randf_range(board_origin.x, board_origin.x + board_size.x - cell_w), board_origin.y - gap - rng.randf_range(0, 480)) + jitter
	elif side == 1:
		return Vector2(board_origin.x + board_size.x + gap + rng.randf_range(0, 520), rng.randf_range(board_origin.y, board_origin.y + board_size.y - cell_h)) + jitter
	elif side == 2:
		return Vector2(rng.randf_range(board_origin.x, board_origin.x + board_size.x - cell_w), board_origin.y + board_size.y + gap + rng.randf_range(0, 480)) + jitter
	return Vector2(board_origin.x - gap - rng.randf_range(0, 520), rng.randf_range(board_origin.y, board_origin.y + board_size.y - cell_h)) + jitter

func _unhandled_input(event):
	if event is InputEventMouseButton:
		handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		handle_mouse_motion(event)
	elif event is InputEventScreenTouch:
		handle_touch(event)
	elif event is InputEventScreenDrag:
		handle_drag(event)
	elif event is InputEventMagnifyGesture:
		var factor = clamp(event.factor, 0.8, 1.25)
		set_camera_zoom(camera.zoom.x * factor, event.position)
	elif event is InputEventPanGesture:
		camera.position += event.delta / camera.zoom.x

func handle_mouse_button(event):
	if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		set_camera_zoom(camera.zoom.x * 1.12, event.position)
		return
	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		set_camera_zoom(camera.zoom.x / 1.12, event.position)
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		var world_pos = screen_to_world(event.position)
		var piece = pick_piece(world_pos)
		if piece != null:
			select_piece(piece)
			begin_group_drag(piece.group_id, world_pos)
			mouse_dragging_piece = true
		else:
			mouse_panning = true
			pan_last_screen = event.position
	else:
		if mouse_dragging_piece:
			end_group_drag()
		mouse_dragging_piece = false
		mouse_panning = false

func handle_mouse_motion(event):
	if mouse_dragging_piece and dragged_group >= 0:
		var world_pos = screen_to_world(event.position)
		move_dragged_group(world_pos - drag_last_world)
		drag_last_world = world_pos
	elif mouse_panning:
		var delta_screen = event.position - pan_last_screen
		camera.position -= delta_screen / camera.zoom.x
		pan_last_screen = event.position

func handle_touch(event):
	if event.pressed:
		touch_points[event.index] = event.position
		if touch_points.size() == 1:
			var world_pos = screen_to_world(event.position)
			var piece = pick_piece(world_pos)
			if piece != null:
				select_piece(piece)
				begin_group_drag(piece.group_id, world_pos)
				touch_piece_index = event.index
			else:
				touch_piece_index = -1
				pan_last_screen = event.position
		elif touch_points.size() == 2:
			if dragged_group >= 0:
				end_group_drag(false)
			var keys = touch_points.keys()
			var a = touch_points[keys[0]]
			var b = touch_points[keys[1]]
			pinch_last_distance = a.distance_to(b)
			pinch_last_mid = (a + b) * 0.5
	else:
		touch_points.erase(event.index)
		if event.index == touch_piece_index and dragged_group >= 0:
			end_group_drag()
			touch_piece_index = -1
		if touch_points.size() < 2:
			pinch_last_distance = 0.0

func handle_drag(event):
	touch_points[event.index] = event.position
	if touch_points.size() >= 2:
		var keys = touch_points.keys()
		var a = touch_points[keys[0]]
		var b = touch_points[keys[1]]
		var dist = max(a.distance_to(b), 1.0)
		var mid = (a + b) * 0.5
		if pinch_last_distance > 0.0:
			var factor = dist / pinch_last_distance
			set_camera_zoom(camera.zoom.x * factor, mid)
			camera.position -= (mid - pinch_last_mid) / camera.zoom.x
		pinch_last_distance = dist
		pinch_last_mid = mid
		return
	if event.index == touch_piece_index and dragged_group >= 0:
		var world_pos = screen_to_world(event.position)
		move_dragged_group(world_pos - drag_last_world)
		drag_last_world = world_pos
	else:
		camera.position -= event.relative / camera.zoom.x

func screen_to_world(screen_pos):
	var viewport_size = get_viewport_rect().size
	return camera.position + (screen_pos - viewport_size * 0.5) / camera.zoom.x

func set_camera_zoom(value, screen_anchor):
	var before = screen_to_world(screen_anchor)
	var z = clamp(value, 0.22, 2.6)
	camera.zoom = Vector2(z, z)
	var after = screen_to_world(screen_anchor)
	camera.position += before - after

func pick_piece(world_pos):
	var best = null
	var best_z = -999999
	for piece in pieces:
		if is_instance_valid(piece) and piece.contains_world_point(world_pos):
			if piece.z_index >= best_z:
				best = piece
				best_z = piece.z_index
	return best

func select_piece(piece):
	if selected_piece != null and is_instance_valid(selected_piece):
		for member in groups.get(selected_piece.group_id, []):
			member.set_selected(false)
	selected_piece = piece
	if selected_piece != null:
		for member in groups.get(selected_piece.group_id, []):
			member.set_selected(true)

func begin_group_drag(group_value, world_pos):
	dragged_group = group_value
	drag_last_world = world_pos
	for p in groups.get(dragged_group, []):
		p.z_index = 300

func move_dragged_group(delta_world):
	for p in groups.get(dragged_group, []):
		p.position += delta_world

func end_group_drag(try_snap=true):
	if dragged_group < 0:
		return
	var old_group = dragged_group
	if try_snap:
		attempt_snap(old_group)
	for p in groups.get(old_group, []):
		p.z_index = 200 if p.is_selected else p.group_id % 100
	dragged_group = -1
	save_current_state()

func attempt_snap(group_value):
	if not groups.has(group_value):
		return
	var source_members = groups[group_value].duplicate()
	for source in source_members:
		for dir in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var nr = source.row_index + dir.y
			var nc = source.col_index + dir.x
			if nr < 0 or nc < 0 or nr >= grid_size or nc >= grid_size:
				continue
			var neighbor = pieces[nr * grid_size + nc]
			if neighbor.group_id == group_value:
				continue
			if angle_difference(source.rotation_degrees, neighbor.rotation_degrees) > 0.5:
				continue
			var cell_w = board_size.x / float(grid_size)
			var cell_h = board_size.y / float(grid_size)
			var desired_local = Vector2(dir.x * cell_w, dir.y * cell_h).rotated(deg_to_rad(source.rotation_degrees))
			var current_delta = neighbor.position - source.position
			var error = current_delta - desired_local
			var threshold = min(cell_w, cell_h) * 0.34
			if error.length() <= threshold:
				for p in groups[group_value]:
					p.position += error
				merge_groups(group_value, neighbor.group_id)
				attempt_snap(group_value)
				return

func merge_groups(keep_id, merge_id):
	if keep_id == merge_id or not groups.has(keep_id) or not groups.has(merge_id):
		return
	var merged_members = groups[merge_id]
	for p in merged_members:
		p.group_id = keep_id
		groups[keep_id].append(p)
	groups.erase(merge_id)
	if selected_piece != null:
		select_piece(selected_piece)
	if groups.size() == 1:
		complete_puzzle()

func angle_difference(a, b):
	var d = fmod(abs(a - b), 360.0)
	return min(d, 360.0 - d)

func rotate_selected_group():
	if not rotation_enabled or selected_piece == null:
		return
	var gid = selected_piece.group_id
	var members = groups.get(gid, [])
	if members.is_empty():
		return
	var pivot = Vector2.ZERO
	for p in members:
		pivot += p.position
	pivot /= float(members.size())
	for p in members:
		var offset = p.position - pivot
		p.position = pivot + offset.rotated(PI * 0.5)
		p.rotation_degrees = fmod(p.rotation_degrees + 90.0, 360.0)
	save_current_state()

func update_rotate_button_position():
	if rotate_button == null:
		return
	rotate_button.visible = rotation_enabled and selected_piece != null and is_instance_valid(selected_piece)
	if not rotate_button.visible:
		return
	var viewport_size = get_viewport_rect().size
	var screen = (selected_piece.global_position - camera.position) * camera.zoom.x + viewport_size * 0.5
	rotate_button.position = Vector2(clamp(screen.x + 54.0, 8.0, viewport_size.x - 80.0), clamp(screen.y - 92.0, 100.0, viewport_size.y - 82.0))

func show_hint():
	clear_hint()
	if selected_piece == null:
		status_label.text = "Önce bir parça seç"
		return
	var dirs = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	for dir in dirs:
		var nr = selected_piece.row_index + dir.y
		var nc = selected_piece.col_index + dir.x
		if nr >= 0 and nc >= 0 and nr < grid_size and nc < grid_size:
			var n = pieces[nr * grid_size + nc]
			if n.group_id != selected_piece.group_id:
				n.set_hint(true)
				hint_timer.start()
				status_label.text = "Komşu parça vurgulandı"
				return
	status_label.text = "Bu grubun açık komşusu kalmadı"

func clear_hint():
	for p in pieces:
		if is_instance_valid(p):
			p.set_hint(false)

func show_preview():
	hide_preview()
	preview_sprite = Sprite2D.new()
	preview_sprite.texture = photo_texture
	preview_sprite.position = Vector2.ZERO
	var texture_size = photo_texture.get_size()
	preview_sprite.scale = Vector2(board_size.x / texture_size.x, board_size.y / texture_size.y)
	preview_sprite.modulate = Color(1,1,1,0.36)
	preview_sprite.z_index = 500
	world_root.add_child(preview_sprite)
	preview_timer.start()

func hide_preview():
	if preview_sprite != null and is_instance_valid(preview_sprite):
		preview_sprite.queue_free()
	preview_sprite = null

func complete_puzzle():
	game_started = false
	status_label.text = "Tamamlandı!"
	var only_id = groups.keys()[0]
	var members = groups[only_id]
	if members.is_empty():
		return
	var reference = members[0]
	var current_angle = deg_to_rad(reference.rotation_degrees)
	var reference_pos = reference.position
	for p in members:
		var relative = p.position - reference_pos
		p.position = reference.target_position + relative.rotated(-current_angle)
		p.rotation_degrees = 0.0
	var final_offset = reference.target_position - reference.position
	for p in members:
		p.position += final_offset
	save_current_state()

func update_progress_label():
	if progress_label == null:
		return
	var total = max(pieces.size(), 1)
	var connected = total - max(groups.size() - 1, 0)
	var pct = int(round(float(connected) / float(total) * 100.0))
	var minutes = int(elapsed_seconds / 60.0)
	var seconds = int(elapsed_seconds) % 60
	progress_label.text = str(pct) + "%   •   " + str(minutes).pad_zeros(2) + ":" + str(seconds).pad_zeros(2) + "   •   Gruplar: " + str(groups.size())

func save_current_state():
	if pieces.is_empty():
		return
	var user_dir = DirAccess.open("user://")
	if user_dir != null:
		user_dir.make_dir_recursive("puzzlepic")
	var data = {
		"version": 1,
		"grid": grid_size,
		"rotation_enabled": rotation_enabled,
		"elapsed": elapsed_seconds,
		"camera_x": camera.position.x,
		"camera_y": camera.position.y,
		"camera_zoom": camera.zoom.x,
		"pieces": []
	}
	for p in pieces:
		data["pieces"].append({
			"row": p.row_index,
			"col": p.col_index,
			"group": p.group_id,
			"x": p.position.x,
			"y": p.position.y,
			"rot": p.rotation_degrees
		})
	var file = FileAccess.open("user://puzzlepic/autosave.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data))
	if photo_image != null:
		photo_image.save_png("user://puzzlepic/photo.png")
