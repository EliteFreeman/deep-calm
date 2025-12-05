extends Control

@onready var time_label = $TimeLabel
@onready var hazards_label = $HazardsLabel

func _ready():
	# Format the time to show only one decimal place.
	time_label.text = "Time Survived: %.1f s" % ScoreManager.time_survived
	hazards_label.text = "Hazards Avoided: %d" % ScoreManager.hazards_avoided

func _on_button_pressed() -> void:
	ScoreManager.reset_scores()
	get_tree().change_scene_to_file("res://main.tscn")
