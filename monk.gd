extends CharacterBody2D
signal ap_changed(current_ap, max_ap)
signal breath_changed(current_breath, max_breath)
signal drag_exhausted


var screen_bounds_min: Vector2
var screen_bounds_max: Vector2

@export_group("Movement")
## The margin from the screen edge the monk cannot cross.
@export var screen_margin: float = 20.0

# --- Stiffness / Floppiness ---
## Softness of joints when composed (0 is perfectly stiff).
@export var stiff_joint_softness: float = 0.0
## Softness of joints when struggling (higher is floppier).
@export var floppy_joint_softness: float = 0.5

@export_group("Ragdoll Physics")
@export var composure_threshold_percent: float = 40.0

# --- JOINTS ---
var joints = []

# --- Muscle Strength ---
## How strongly joints correct themselves when composed (0 to 0.9).
@export_range(0.0, 0.9, 0.01) var composed_joint_bias: float = 0.5
## How strongly joints correct themselves when struggling (lower is weaker).
@export_range(0.0, 0.9, 0.01) var struggling_joint_bias: float = 0.1

# --- AURA POWER VARIABLES ---
@export_range(0, 100) var current_ap: float = 100.0:
	set(value):
		current_ap = clamp(value, 0, max_ap)
		ap_changed.emit(current_ap, max_ap)

@onready var ragdoll_torso = $MonkRagdoll
@export var max_ap: float = 100.0
@export var ap_regen_rate: float = 5.0 # AP per second during peace.
@export var ap_drag_drain_rate: float = 15.0 # AP per second while dragging.
@export var sink_curve_power: float = 1.5 # Higher number = less sinking until AP is very low.
@export var drag_lockout_threshold: float = 20.0
@export var drag_recovery_threshold: float = 50.0
var ui = null # This will be set by Main.gd

# --- BREATH (HP) VARIABLES ---
@export_group("Breath (HP)")
@export_range(0, 100) var current_breath: float = 100.0:
	set(value):
		current_breath = clamp(value, 0, max_breath)
		breath_changed.emit(current_breath, max_breath)
@export var max_breath: float = 100.0
@export var breath_loss_rate: float = 10.0
@export var breath_regen_rate: float = 20.0
var is_burned_out: bool = false

# --- MOVEMENT VARIABLES ---
@export var resting_y_position: float = 300.0
@export var max_sink_depth: float = 900.0 # How far down the Monk goes at 0 AP.
var is_dragging: bool = false
var target_y_position: float

## The Y-coordinate below which the Monk starts to lose breath.
@export var breath_line_y: float = 426.0 # (1280 / 3)

func _ready():
	global_position.y = resting_y_position
	target_y_position = resting_y_position
	
	# --- NEW CODE TO GET SCREEN BOUNDS ---
	var screen_rect = get_viewport_rect()
	screen_bounds_min = screen_rect.position + Vector2(screen_margin, screen_margin)
	screen_bounds_max = screen_rect.end - Vector2(screen_margin, screen_margin)

func _physics_process(delta: float):
	# --- BLOCK 1: AURA POWER (AP) & MOVEMENT LOGIC ---
	if is_dragging:
		# First, check if our current AP is already too low to continue dragging.
		if current_ap < drag_lockout_threshold:
			is_burned_out = true
			stop_drag()
			drag_exhausted.emit()
		# If our AP is high enough, THEN we can perform the drag logic for this frame.
		else:
			# We now move the frozen kinematic body directly.
			ragdoll_torso.global_position = get_global_mouse_position()
			# Keep the "ghost" position in sync with the puppet.
			self.global_position = ragdoll_torso.global_position
			
			self.global_position.x = clamp(self.global_position.x, screen_bounds_min.x, screen_bounds_max.x)
			self.global_position.y = clamp(self.global_position.y, screen_bounds_min.y, screen_bounds_max.y)
			ragdoll_torso.global_position = self.global_position
			
			# Drain AP as the cost of this frame's drag.
			self.current_ap -= ap_drag_drain_rate * delta
	else:
		# --- PEACE LOGIC ---
		self.current_ap += ap_regen_rate * delta
		
		# Calculate the target Y position based on the Monk's current AP.
		var ap_percent = current_ap / max_ap
		var curved_ap_percent = pow(ap_percent, sink_curve_power)
		target_y_position = remap(curved_ap_percent, 0.0, 1.0, max_sink_depth, resting_y_position)
		
		# Smoothly move towards the target Y.
		global_position.y = lerp(global_position.y, target_y_position, 0.05)

	# --- BLOCK 2: BREATH (HP) LOGIC ---
	# This block runs every frame, regardless of dragging state.
	if global_position.y > breath_line_y:
		self.current_breath -= breath_loss_rate * delta
	else:
		self.current_breath += breath_regen_rate * delta
	
	# Check for Game Over
	if current_breath <= 0:
		game_over()
	
	# =======================================================================
	# START of the block to add/replace
	# =======================================================================
	# --- BLOCK 3: RAGDOLL STIFFNESS & MUSCLE LOGIC ---
	#var breath_percent = (current_breath / max_breath) * 100.0
	#var target_softness = stiff_joint_softness
	#var target_bias = composed_joint_bias
#
	## Check if the Monk is struggling.
	#if breath_percent < composure_threshold_percent:
		#target_softness = floppy_joint_softness
		#target_bias = struggling_joint_bias
#
	## Apply the new values to all joints.
	#for joint in joints:
		## Lerp the softness for a smooth transition to floppiness
		#joint.softness = lerp(joint.softness, target_softness, 0.1)
		#
		## Lerp the bias for a smooth transition of muscle strength
		#joint.bias = lerp(joint.bias, target_bias, 0.1)
	# =======================================================================
	# END of the block to add/replace
	# =======================================================================

	# --- BLOCK 4: RAGDOLL PUPPETING ---
	# After all calculations, update the ragdoll torso's position to match
	# the invisible "ghost" Monk's position, but only if not being hit.
	if ragdoll_torso.freeze == true and not is_dragging:
		ragdoll_torso.global_position = self.global_position

	# --- BLOCK 5: DEBUG REPORTING ---
	if ui != null:
		ui.update_debug_info(current_ap, current_breath, global_position.y, target_y_position)
	
	if not is_dragging:
		ragdoll_torso.global_position = self.global_position


func is_grabbable() -> bool:
	if is_burned_out:
		if current_ap >= drag_recovery_threshold:
			is_burned_out = false
			return true
		else:
			return false
	else:
		# The monk can only be grabbed if his AP is above the lockout threshold.
		return current_ap > drag_lockout_threshold

func start_drag():
	is_dragging = true
	# To drag, we keep it frozen, but switch the mode to Kinematic
	# so our script has full control over its position.
	ragdoll_torso.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC

func stop_drag():
	is_dragging = false
	# When we stop dragging, we switch it back to a Static anchor.
	ragdoll_torso.freeze_mode = RigidBody2D.FREEZE_MODE_STATIC

# This function is now called by Main.gd to DRAIN AP on a swipe.
func drain_ap_on_swipe(amount: float):
	current_ap -= amount

# This function is called by other objects (like hazards).
func take_hit(ap_damage: float, _push_direction: Vector2, _push_force: float):
	# We only drain AP now. No physics forces are applied to the ragdoll.
	self.current_ap -= ap_damage

func game_over():
	# Print a clear message to the console for debugging.
	print("GAME OVER - Player ran out of breath.")
	
	# Pause the entire game. This freezes all physics and player input.
	get_tree().change_scene_to_file("res://main_menu.tscn")

func find_joints():
	joints = get_tree().get_nodes_in_group("ragdoll_joints")
