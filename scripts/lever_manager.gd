extends Node2D

@export var countdown_time: float = 8.0
@export var bee_count: int = 14
@export var line_width: float = 18.0
@export var line_color: Color = Color(0.12, 0.65, 1.0, 1.0)
@export var min_point_dist: float = 8.0

var is_drawing: bool = false
var can_draw: bool = true
var game_active: bool = false
var game_over: bool = false
var time_left: float = 8.0

var current_line: Line2D = null
var bees: Array[CharacterBody2D] = []

func _ready() -> void:
	time_left = countdown_time
	var status = get_node_or_null("UI/StatusLabel")
	if status:
		status.text = "Draw to protect the target!"
		status.modulate = Color.WHITE

func _process(delta: float) -> void:
	if not game_active or game_over:
		return

	time_left -= delta
	var timer_lbl = get_node_or_null("UI/TimerLabel")
	if timer_lbl:
		timer_lbl.text = "Survive: %.1fs" % maxf(time_left, 0.0)

	if time_left <= 0.0:
		_level_cleared()

func _physics_process(delta: float) -> void:
	if not game_active or game_over:
		return

	var target = get_node_or_null("Target")
	if target == null:
		return

	var target_pos: Vector2 = target.global_position

	# Organic Swarm AI (Seeking + Swarm Separation + Buzzing)
	for i in range(bees.size()):
		var bee: CharacterBody2D = bees[i]
		if not is_instance_valid(bee):
			continue

		# 1. Target Attraction
		var to_target: Vector2 = (target_pos - bee.global_position).normalized()
		var desired_vel: Vector2 = to_target * 320.0

		# 2. Separation Force (Prevents bees from clumping together)
		var separation: Vector2 = Vector2.ZERO
		for j in range(bees.size()):
			if i != j and is_instance_valid(bees[j]):
				var dist: float = bee.global_position.distance_to(bees[j].global_position)
				if dist < 45.0 and dist > 0.0:
					separation += (bee.global_position - bees[j].global_position).normalized() * (45.0 - dist) * 8.0

		# 3. Organic Buzz Wobble
		var seed_val: float = float(bee.get_instance_id())
		var wobble: Vector2 = Vector2(-to_target.y, to_target.x) * sin((Time.get_ticks_msec() * 0.009) + seed_val) * 70.0

		desired_vel += separation + wobble
		bee.velocity = bee.velocity.move_toward(desired_vel, 650.0 * delta)

		# Rotate bee towards its movement direction
		if bee.velocity.length() > 20.0:
			bee.rotation = bee.velocity.angle()

		# Wing Flapping Animation
		var wing_l = bee.get_node_or_null("WingL")
		var wing_r = bee.get_node_or_null("WingR")
		var flap = sin(Time.get_ticks_msec() * 0.04 + seed_val) * 0.4
		if wing_l: wing_l.rotation = flap
		if wing_r: wing_r.rotation = -flap

		bee.move_and_slide()

		# Physical impulse against drawn barrier & victory/defeat check
		for c_idx in range(bee.get_slide_collision_count()):
			var col: KinematicCollision2D = bee.get_slide_collision(c_idx)
			var collider: Object = col.get_collider()
			if collider is RigidBody2D and collider != target:
				collider.apply_impulse(-col.get_normal() * 30.0, col.get_position() - collider.global_position)
			elif collider == target:
				_target_stung()

func _input(event: InputEvent) -> void:
	# Strictly reject drawing if game started or stroke already finished
	if not can_draw or game_active or game_over:
		return

	# Start Stroke
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

	# Drag Stroke
	elif (event is InputEventMouseMotion and is_drawing) \
	or (event is InputEventScreenDrag and is_drawing):
		if current_line and current_line.points.size() > 0:
			if current_line.points[-1].distance_to(get_global_mouse_position()) >= min_point_dist:
				current_line.add_point(get_global_mouse_position())

	# Release Stroke -> Lock input, convert to physics, spawn bees
	elif (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed) \
	or (event is InputEventScreenTouch and not event.pressed):
		if is_drawing:
			is_drawing = false
			can_draw = false # Lock out any second line drawing
			_convert_line_and_spawn()

func _convert_line_and_spawn() -> void:
	if not current_line or current_line.points.size() < 2:
		can_draw = true
		if current_line:
			current_line.queue_free()
			current_line = null
		return

	var pts: PackedVector2Array = current_line.points
	var centroid: Vector2 = Vector2.ZERO
	for p in pts:
		centroid += p
	centroid /= float(pts.size())

	# Rigid Body Creation
	var body: RigidBody2D = RigidBody2D.new()
	body.position = centroid
	body.mass = 4.0
	body.collision_layer = 1
	body.collision_mask = 7

	# Build hollow capsule colliders per segment
	var radius: float = line_width * 0.5
	for i in range(pts.size() - 1):
		var p1: Vector2 = pts[i] - centroid
		var p2: Vector2 = pts[i + 1] - centroid
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
		body.add_child(col)

	# Reparent line under physics body
	var offset_pts: PackedVector2Array = PackedVector2Array()
	for p in pts:
		offset_pts.append(p - centroid)
	current_line.points = offset_pts
	current_line.position = Vector2.ZERO

	remove_child(current_line)
	body.add_child(current_line)
	add_child(body)
	current_line = null

	# Trigger Swarm State
	game_active = true
	var status = get_node_or_null("UI/StatusLabel")
	if status:
		status.text = "BEES ATTACKING!"
		status.modulate = Color(1.0, 0.85, 0.1)

	_spawn_large_bees()

func _spawn_large_bees() -> void:
	var hive = get_node_or_null("HiveMarker")
	var origin: Vector2 = hive.global_position if hive else Vector2(540, 300)

	for i in range(bee_count):
		var bee: CharacterBody2D = CharacterBody2D.new()
		bee.collision_layer = 4
		bee.collision_mask = 3
		bee.position = origin + Vector2(randf_range(-50, 50), randf_range(-30, 30))

		# 1. Large Yellow Bee Body (2.5x larger)
		var body_vis: Polygon2D = Polygon2D.new()
		body_vis.color = Color(1.0, 0.82, 0.0) # Golden Yellow
		body_vis.polygon = PackedVector2Array([
			Vector2(-22, -14), Vector2(18, 0), Vector2(-22, 14), Vector2(-28, 0)
		])
		bee.add_child(body_vis)

		# 2. Black Stripes
		var stripe: Polygon2D = Polygon2D.new()
		stripe.color = Color(0.12, 0.12, 0.12)
		stripe.polygon = PackedVector2Array([
			Vector2(-10, -13), Vector2(-2, -10), Vector2(-2, 10), Vector2(-10, 13)
		])
		bee.add_child(stripe)

		# 3. Black Stinger
		var stinger: Polygon2D = Polygon2D.new()
		stinger.color = Color(0.1, 0.1, 0.1)
		stinger.polygon = PackedVector2Array([
			Vector2(-28, 0), Vector2(-36, -3), Vector2(-36, 3)
		])
		bee.add_child(stinger)

		# 4. Animated Translucent Wings
		var wing_l: Polygon2D = Polygon2D.new()
		wing_l.name = "WingL"
		wing_l.color = Color(0.9, 0.95, 1.0, 0.75)
		wing_l.polygon = PackedVector2Array([Vector2(-4, -6), Vector2(-12, -26), Vector2(6, -18)])
		bee.add_child(wing_l)

		var wing_r: Polygon2D = Polygon2D.new()
		wing_r.name = "WingR"
		wing_r.color = Color(0.9, 0.95, 1.0, 0.75)
		wing_r.polygon = PackedVector2Array([Vector2(-4, 6), Vector2(-12, 26), Vector2(6, 18)])
		bee.add_child(wing_r)

		# 5. Physics Collision Shape
		var col: CollisionShape2D = CollisionShape2D.new()
		var circle: CircleShape2D = CircleShape2D.new()
		circle.radius = 18.0
		col.shape = circle
		bee.add_child(col)

		add_child(bee)
		bees.append(bee)

func _target_stung() -> void:
	if game_over:
		return
	game_over = true
	game_active = false
	var status = get_node_or_null("UI/StatusLabel")
	if status:
		status.text = "DEFEAT! Target Stung."
		status.modulate = Color.RED

func _level_cleared() -> void:
	game_over = true
	game_active = false
	var status = get_node_or_null("UI/StatusLabel")
	if status:
		status.text = "VICTORY! Level Cleared!"
		status.modulate = Color.GREEN