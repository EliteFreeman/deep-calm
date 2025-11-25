extends Node2D

@onready var monk = $Monk

@export var top_safe_zone_fraction: float = 1.0 / 6.0 
@export var swipe_ap_cost: float = 40.0
@export var swipe_push_force: float = 500.0
@export var swipe_radius: float = 150.0

const HAZARD_SCENE = preload("res://hazard.tscn")

# This variable will track if our current drag started on the monk.
var is_monk_drag: bool = false
var swipe_start_position: Vector2

func _input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			swipe_start_position = event.position # Record start position for swipe direction
			if is_mouse_over_monk(event.position):
				is_monk_drag = true
				monk.start_drag()
			else:
				is_monk_drag = false
				monk.drain_ap_on_swipe(swipe_ap_cost)
		else: # On mouse release
			# Was this a swipe? (Not a monk drag and not a simple click)
			if not is_monk_drag and event.position.distance_to(swipe_start_position) > 10:
				apply_swipe_push(swipe_start_position, event.position)
			
			# Always stop dragging the monk on release, if we were dragging him.
			if is_monk_drag:
				monk.stop_drag()
			
			# Reset the drag flag regardless.
			is_monk_drag = false
			
func apply_swipe_push(start_pos, end_pos):
	var swipe_vector = end_pos - start_pos
	var swipe_direction = swipe_vector.normalized()
	var swipe_midpoint = (start_pos + end_pos) / 2
	
	# Find all bodies within the swipe radius
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = swipe_radius
	query.shape = circle_shape
	query.transform = Transform2D(0, swipe_midpoint)
	query.collision_mask = 2 # Only check for things on the "hazards" physics layer
	
	var results = space_state.intersect_shape(query)
	
	for result in results:
		var body = result.collider
		# Check if the body is a RigidBody2D
		if body is RigidBody2D:
			# Apply a directional force!
			body.apply_central_impulse(swipe_direction * swipe_push_force)

# This helper function checks if the mouse is over the monk's collision shape.
func is_mouse_over_monk(mouse_position: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = mouse_position
	query.collision_mask = 1 # Only check for things on the "player" physics layer
	
	var result = space_state.intersect_point(query)
	
	if not result.is_empty():
		if result[0].collider == monk:
			return true
	
	return false


func _on_hazard_spawner_timeout():
	# Create a new instance of our hazard scene.
	var new_hazard = HAZARD_SCENE.instantiate()
	
	# Get the size of the game window.
	var screen_size = get_viewport_rect().size
	var safe_zone_height = screen_size.y * top_safe_zone_fraction
	
	# --- Choose a random spawn edge ---
	# 0 = Right, 1 = Left, 2 = Bottom, 3 = Top (but respecting safe zone)
	var spawn_edge = randi_range(0, 3) 
	
	var spawn_position = Vector2.ZERO
	var travel_direction = Vector2.ZERO
	
	match spawn_edge:
		0: # Spawn on the Right edge
			spawn_position.x = screen_size.x + 50
			spawn_position.y = randf_range(safe_zone_height, screen_size.y)
			travel_direction = Vector2.LEFT
		1: # Spawn on the Left edge
			spawn_position.x = -50
			spawn_position.y = randf_range(safe_zone_height, screen_size.y)
			travel_direction = Vector2.RIGHT
		2: # Spawn on the Bottom edge
			spawn_position.x = randf_range(0, screen_size.x)
			spawn_position.y = screen_size.y + 50
			travel_direction = Vector2.UP
		3: # Spawn on the Top edge (below the safe zone)
			spawn_position.x = randf_range(0, screen_size.x)
			spawn_position.y = safe_zone_height - 50 # Spawn just above the safe line
			travel_direction = Vector2.DOWN
			
	# Apply the calculated position and direction to the new hazard
	new_hazard.position = spawn_position
	new_hazard.direction = travel_direction # We set the direction property on the hazard
	
	# Add the hazard to the game.
	add_child(new_hazard)
