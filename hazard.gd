extends RigidBody2D

@export var speed: float = 150.0
@export var direction: Vector2 = Vector2.LEFT
@export var ap_damage: float = 35.0
@export var push_force: float = 300.0
@export_group("Homing Properties") # This creates a nice category in the Inspector
## How strongly the hazard pulls towards the monk. 0 = no homing, 1 = very strong.
@export var homing_strength: float = 0.2
## The distance at which the hazard will start to notice and track the monk.
@export var detection_radius: float = 400.0
@export_group("Visuals")
## How fast the hazard spins, in degrees per second. Can be negative for opposite spin.
@export var rotation_speed: float = 90.0


# This variable will hold a reference to the monk node.
var target = null

var has_been_hit = false # Prevents the hazard from hitting multiple times.

func _ready():
	linear_velocity = direction * speed
	# Find the player in the scene tree and store a reference to it.
	target = get_tree().get_first_node_in_group("player")
	# Randomize the rotation speed between -180 and 180 degrees/sec
	rotation_speed = randf_range(-180.0, 180.0)

func _on_screen_exited():
	# Only count as "avoided" if the hazard has not already hit the player.
	if not has_been_hit:
		ScoreManager.hazards_avoided += 1
	
	# The queue_free() is now redundant because this function is only
	# called by the VisibleOnScreenNotifier2D right before it should be deleted.
	# However, keeping it is safe.
	queue_free()

# This is the NEW function connected to the RigidBody2D's signal.
func _on_body_entered(body):
	# If we've already hit something, do nothing.
	if has_been_hit:
		return

	# Check if the body we hit is the Monk.
	if body.has_method("take_hit"):
		has_been_hit = true # Mark as hit
		var push_direction = -direction
		body.take_hit(ap_damage, push_direction, push_force)
		
		# Start the disintegration effect instead of just disappearing.
		disintegrate()

func disintegrate():
	# 1. Stop its movement.
	linear_velocity = Vector2.ZERO
	
	# 2. Call our new function DEFERRED to safely disable collision.
	call_deferred("disable_collision")
	
	# 3. Create a Tween to handle the fade-out animation.
	var tween = create_tween()
	tween.tween_property($Sprite2D, "modulate:a", 0.0, 0.5)
	
	# 4. Once the tween animation is finished, delete the hazard.
	await tween.finished
	queue_free()

# This is our new helper function that will be called at a safe time.
func disable_collision():
	$CollisionShape2D.disabled = true

func _physics_process(delta: float):
	# First, check if we have a valid target. If not, do nothing.
	if not is_instance_valid(target):
		return
		
	# Calculate the distance to the target.
	var distance_to_target = global_position.distance_to(target.global_position)
	
	# Only apply homing logic if the target is within the detection radius.
	if distance_to_target < detection_radius:
		# 1. Get the direction vector pointing from us to the target.
		var direction_to_target = (target.global_position - global_position).normalized()
		
		# 2. Calculate the "desired" velocity if we were to go straight at the target.
		var desired_velocity = direction_to_target * speed
		
		# 3. This is the magic! Smoothly interpolate our current velocity towards the desired one.
		# The 'homing_strength' variable controls how fast this happens.
		linear_velocity = linear_velocity.lerp(desired_velocity, homing_strength * delta)
		
		# 4. (Optional but recommended) Ensure the speed stays constant after turning.
		# Lerping can sometimes slow down the vector, so we re-normalize and set the speed.
		linear_velocity = linear_velocity.normalized() * speed
		
	# Apply rotation
	rotation_degrees += rotation_speed * delta
