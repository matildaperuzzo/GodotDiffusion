extends Node2D
# Called when the node enters the scene tree for the first time.
func _ready():
	$progress.value = 100
	$Resources.show()
	$progress.show()
	$GameOver.hide()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _change_resource_value(value):
	$progress.value = value
	
func _game_over():
	$Resources.hide()
	$progress.hide()
	$GameOver.show()
