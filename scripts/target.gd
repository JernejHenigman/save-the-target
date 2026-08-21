class_name Target
extends RigidBody2D

signal stung

@export var max_health: float = 100.0
var current_health: float = 100.0
var is_alive: bool = true

func _ready() -> void:
	current_health = max_health
	contact_monitor = true
	max_contacts_reported = 8
	lock_rotation = true # Keeps the target upright on its pedestal
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not is_alive:
		return
	if body.is_in_group("bees"):
		take_damage(35.0)

func take_damage(amount: float) -> void:
	if not is_alive:
		return
	current_health -= amount
	
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate", Color.RED, 0.05)
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)

	if current_health <= 0.0:
		is_alive = false
		stung.emit()
