extends Node2D

const LAYERS = [
	{"name": "average", "has_button": true},
	{"name": "rivers", "has_button": true},
	{"name": "crop", "has_button": true},
	{"name": "temperature", "has_button": true},
	{"name": "precipitation", "has_button": true},
	{"name": "sea", "has_button": true},
]

var theta = []
var n_av : int = 1
var crop = 'wheat'

func _ready():
	theta.resize(LAYERS.size())
	_setup_Layers()
	_setup_Crops()
	print(theta)
	
#func _process(delta: float) -> void:
	#print(crop)

func _setup_Crops():

	var group = ButtonGroup.new()
	var wheat_button = Button.new()
	var rice_button = Button.new()
	var maize_button = Button.new()
	
	wheat_button.text = 'Wheat'
	rice_button.text = 'Rice'
	maize_button.text = 'Maize'
	
	for btn in [wheat_button, rice_button, maize_button]:
		btn.toggle_mode = true
		btn.button_group = group
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		btn.connect("pressed", Callable(self, "_on_button_pressed").bind(btn.text))
		$Crops_container.add_child(btn)

func _setup_Layers():
	var ui_container = $LayersUI
	for child in ui_container.get_children():
		child.queue_free()
	
	for i in LAYERS.size():
		var layer = LAYERS[i]
		var name = layer["name"]

		var vbox = VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ui_container.add_child(vbox)
		var button
		if layer["has_button"]:
			button = Button.new()
			button.text = name.capitalize()
			button.toggle_mode = true
			#button.is_pressed() = true
			button.connect("pressed", Callable(self, "_on_layer_pressed").bind(i))
			vbox.add_child(button)

		var slider = HSlider.new()
		slider.min_value = -5
		slider.max_value = 5
		slider.step = 0.05
		slider.value = 0.0
		slider.connect("value_changed", Callable(self, "_on_slider_changed").bind(i))
		vbox.add_child(slider)

		var line_edit = LineEdit.new()
		line_edit.text = "0.000"
		line_edit.size_flags_horizontal = Control.SIZE_SHRINK_END
		line_edit.connect("text_submitted", Callable(self, "_on_text_submitted").bind(i))
		vbox.add_child(line_edit)

		# store references so we can access later
		vbox.set_meta("slider", slider)
		vbox.set_meta("line_edit", line_edit)
		if layer["has_button"]:
			vbox.set_meta("button", button)

		# initial theta
		theta[i] = 0.0

func _on_slider_changed(value: float, idx: int):
	var hbox = $LayersUI.get_child(idx)
	var line_edit = hbox.get_meta("line_edit")
	line_edit.text = "%0.3f" % value

	if LAYERS[idx]["has_button"]:
		var button = hbox.get_meta("button")
		theta[idx] = value if button.is_pressed() else 0.0
	else:
		theta[idx] = value

	get_parent()._update_geo_layer()


func _on_text_submitted(text: String, idx: int):
	if not text.is_valid_float():
		return
	var value = text.to_float()
	var hbox = $LayersUI.get_child(idx)
	var slider = hbox.get_meta("slider")
	slider.value = value  # triggers _on_slider_changed


func _on_layer_pressed(idx: int):
	var hbox = $LayersUI.get_child(idx)
	var button = hbox.get_meta('button')
	var slider = hbox.get_meta("slider")
	theta[idx] = slider.value if button.is_pressed() else 0.0
	get_parent()._update_geo_layer()
	
func _on_button_pressed(btn: String):
	if btn == 'Wheat':
		crop = 'wheat'
	elif btn == 'Rice':
		crop = 'rice'
	elif btn == 'Maize':
		crop = 'maize'
	get_parent()._on_crop_change(crop)

# GET FUNCTIONS

func get_UI_theta() -> Array:
	return theta
	
func get_UI_N() -> int:
	return n_av
	
func get_UI_crop() -> String:
	return crop
	
func _on_ui_start_pressed() -> void:
	get_parent()._on_start()
	
func _on_ui_view_toggle_toggled(toggled_on: bool) -> void:
	if toggled_on:
		get_parent().set_geo_view(true)
	else:
		get_parent().set_geo_view(false)

func _on_v_slider_value_changed(value: float) -> void:
	if value < 1:
		value = 1
	elif value > 100:
		value = 100
	value = int(value)
	$N_avUI/RichTextLabel.text = "Number of averages: " + str("%.0f" % value)
	n_av = value
