extends CanvasLayer

@onready var ap_bar = $AP_bar
@onready var breath_bar = $Breath_bar
@onready var debug_label = $DebugLabel

func update_ap_bar(current_value, max_value):
	ap_bar.max_value = max_value
	ap_bar.value = current_value

func update_breath_bar(current_value, max_value):
	breath_bar.max_value = max_value
	breath_bar.value = current_value

func update_debug_info(ap, breath, pos_y, target_y):
	var ap_string = "AP: %.2f" % ap
	var breath_string = "Breath: %.2f" % breath
	var pos_string = "Y: %.2f" % pos_y
	var target_string = "Target Y: %.2f" % target_y
	
	# The '\n' character creates a new line.
	debug_label.text = "%s\n%s\n%s\n%s" % [ap_string, breath_string, pos_string, target_string]
