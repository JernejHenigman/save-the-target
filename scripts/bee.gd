class_name Bee
extends CharacterBody2D

@export var max_speed: float = 340.0
@export var steer_force: float = 450.0

var target_node: Node2D = null
var current_velocity: Vector2 = Vector2.ZERO
var buzz_offset: float = 0.0

func _ready() -> void:
	add_to_group("bees")
	buzz_offset = randf() * 100.0

func _physics_process(delta: float) -> void:
	if target_node == null or not is_instance_valid(target_node):
		return

	# 1. Target Tracking Vector
	var direction: Vector2 = (target_node.global_position - global_position).normalized()
	
	# 2. Add organic buzzing oscillation
	buzz_offset += delta * 10.0
	var wobble: Vector2 = Vector2(-direction.y, direction.x) * sin(buzz_offset) * 80.0
	var desired_velocity: Vector2 = (direction * max_speed) + wobble

	# 3. Steering force application
	var steering: Vector2 = desired_velocity - current_velocity
	steering = steering.limit_length(steer_force * delta)
	current_velocity = (current_velocity + steering).limit_length(max_speed)
	
	velocity = current_velocity
	
	if velocity.length() > 10.0:
		rotation = velocity.angle()

	# Move and bounce/slide against barriers
	move_and_slide()

	# Push on physical bodies when colliding
	for i in range(get_slide_collision_count()):
		var col: KinematicCollision2D = get_slide_collision(i)
		var collider: Object = col.get_collider()
		if collider is RigidBody2D:
			collider.apply_impulse(-col.get_normal() * 20.0, col.get_position() - collider.global_position)
		if collider is Target:
			collider.take_damage(25.0)