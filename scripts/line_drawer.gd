class_name LineDrawer
extends Node2D

@export var line_width: float = 16.0
@export var line_color: Color = Color(0.12, 0.65, 1.0, 1.0)
@export var min_point_distance: float = 10.0

var is_drawing: bool = false
var can_draw: bool = true
var current_line: Line2D = null

func _input(event: InputEvent) -> void:
	if not can_draw:
		return

	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) \
	or (event is InputEventScreenTouch and event.pressed):
		is_drawing = true
		current_line = Line2D.new()
		current_line.width = line_width
		current_line.default_color = line_color
		current_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		current_line.end_cap_mode = Line2D.LINE_CAP_ROUND
		current_line.joint_mode = Line2D.LINE_JOINT_ROUND
		current_line.antialiased = true
		add_child(current_line)
		current_line.add_point(get_global_mouse_position())

	elif (event is InputEventMouseMotion and is_drawing) \
	or (event is InputEventScreenDrag and is_drawing):
		if current_line != null and current_line.points.size() > 0:
			if current_line.points[-1].distance_to(get_global_mouse_position()) >= min_point_distance:
				current_line.add_point(get_global_mouse_position())

	elif (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed) \
	or (event is InputEventScreenTouch and not event.pressed):
		if is_drawing:
			_finish_drawing()

func _finish_drawing() -> void:
	is_drawing = false
	can_draw = false

	if current_line == null or current_line.points.size() < 2:
		if current_line != null:
			current_line.queue_free()
			current_line = null
		can_draw = true
		return

	var points: PackedVector2Array = current_line.points

	var centroid: Vector2 = Vector2.ZERO
	for pt in points:
		centroid += pt
	centroid /= float(points.size())

	var rigid_body: RigidBody2D = RigidBody2D.new()
	rigid_body.position = centroid
	rigid_body.mass = 4.0
	rigid_body.collision_layer = 1
	rigid_body.collision_mask = 7

	var radius: float = line_width * 0.5
	for i in range(points.size() - 1):
		var p1: Vector2 = points[i] - centroid
		var p2: Vector2 = points[i + 1] - centroid
		var seg: Vector2 = p2 - p1
		var seg_len: float = seg.length()
		if seg_len < 1.0:
			continue

		var col: CollisionShape2D = CollisionShape2D.new()
		var capsule: CapsuleShape2D = CapsuleShape2D.new()
		capsule.radius = radius
		capsule.height = seg_len + (radius * 2.0)
		col.shape = capsule
		col.position = (p1 + p2) * 0.5
		col.rotation = seg.angle() + (PI / 2.0)
		rigid_body.add_child(col)

	var offset_pts: PackedVector2Array = PackedVector2Array()
	for pt in points:
		offset_pts.append(pt - centroid)
	current_line.points = offset_pts
	current_line.position = Vector2.ZERO

	remove_child(current_line)
	rigid_body.add_child(current_line)
	
	var parent_node = get_parent()
	if parent_node != null:
		parent_node.add_child(rigid_body)
		if parent_node.has_method("start_swarm"):
			parent_node.start_swarm()
	else:
		add_child(rigid_body)

	current_line = null
