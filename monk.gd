extends CharacterBody2D

# --- AURA POWER VARIABLES ---
@export_range(0, 100) var current_ap: float = 100.0
@export var max_ap: float = 100.0
@export var ap_regen_rate: float = 5.0 # AP per second during peace.
@export var ap_drag_drain_rate: float = 15.0 # AP per second while dragging.
@export var sink_curve_power: float = 1.5 # Higher number = less sinking until AP is very low.

# --- MOVEMENT VARIABLES ---
@export var resting_y_position: float = 300.0
@export var max_sink_depth: float = 900.0 # How far down the Monk goes at 0 AP.
var is_dragging: bool = false
var target_y_position: float

func _ready():
	global_position.y = resting_y_position
	target_y_position = resting_y_position

func _physics_process(delta: float):
	if is_dragging:
		# --- DRAGGING LOGIC ---
		global_position = get_global_mouse_position()
		target_y_position = global_position.y
		current_ap -= ap_drag_drain_rate * delta
		current_ap = clamp(current_ap, 0, max_ap)
	else:
		# --- PEACE LOGIC ---
		current_ap += ap_regen_rate * delta
		# Clamping the AP lower limit
		current_ap = clamp(current_ap, 0, max_ap)
		# Calculate the target Y position based on current AP.
		# remap() is a function that converts a value from one range to another.
		# At 100 AP, target is resting_y. At 0 AP, target is max_sink_depth.
	
		var ap_percent = current_ap / max_ap  
		var curved_ap_percent = pow(ap_percent, sink_curve_power)
		
		target_y_position = remap(curved_ap_percent, 0.0, 1.0, max_sink_depth, resting_y_position)
		
		# Smoothly move towards the calculated target Y.
		global_position.y = lerp(global_position.y, target_y_position, 0.05)

	# --- UNIVERSAL LOGIC ---
	current_ap = clamp(current_ap, 0, max_ap)
	
	#DEBUG INFORMATION
	var ap_string = "AP: %.2f" % current_ap
	var pos_string = "Current Y: %.2f" % global_position.y
	var target_string = "Target Y: %.2f" % target_y_position
	
	# Print all the formatted strings to the console on one line.
	print(ap_string, " | ", pos_string, " | ", target_string)
	
func start_drag():
	is_dragging = true

func stop_drag():
	is_dragging = false

# This function is now called by Main.gd to DRAIN AP on a swipe.
func drain_ap_on_swipe(amount: float):
	current_ap -= amount

# This function is called by other objects (like hazards).
func take_hit(ap_damage: float, _push_direction: Vector2, _push_force: float):
	# We only drain the AP. We ignore the push direction and force.
	current_ap -= ap_damage
