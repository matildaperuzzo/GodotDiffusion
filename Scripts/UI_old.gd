extends Node2D
var theta = [0.0,0.0,0.0]

func get_UI_theta() -> Array:
	return theta
	
func _setup_UI():
	$UI_av_slider/UI_av_theta.text = "%0.3f"%theta[0]
	$UI_av_slider.value = theta[0]
	$UI_rivers_layer/UI_river_theta.text = "%0.3f"%theta[1]
	$UI_rivers_layer/UI_rivers_slider.value = theta[1]
	$UI_sea_layer/UI_sea_theta.text = "%0.3f"%theta[2]
	$UI_sea_layer/UI_sea_slider.value = theta[2]

func _on_ui_sea_slider_value_changed(value: float) -> void:
	$UI_sea_layer/UI_sea_theta.text = "%0.3f"%value
	if $UI_sea_layer.button_pressed:
		theta[2] = value
	else:
		theta[2] = 0
	get_parent()._update_geo_layer()

func _on_ui_rivers_slider_value_changed(value: float) -> void:
	$UI_rivers_layer/UI_river_theta.text = "%0.3f"%value
	if $UI_rivers_layer.button_pressed:
		theta[1] = value
	else:
		theta[1] = 0
	get_parent()._update_geo_layer()

func _on_ui_av_slider_value_changed(value: float) -> void:
	$UI_av_slider/UI_av_theta.text = "%0.3f"%value	
	theta[0] = value
	get_parent()._update_geo_layer()
	
func _on_ui_river_theta_text_submitted(text: String)  -> void:
	if text.is_valid_float():
		var value = text.to_float()
		$UI_rivers_layer/UI_rivers_slider.value = value
		if $UI_sea_layer.button_pressed:
			theta[2] = value
		else:
			theta[2] = 0
		get_parent()._update_geo_layer()
	else:
		_on_ui_rivers_slider_value_changed($UI_rivers_layer/UI_rivers_slider.value)
		
func _on_ui_sea_theta_text_submitted(text: String) -> void:
	if text.is_valid_float():
		var value = text.to_float()
		$UI_sea_layer/UI_sea_slider.value = value
		if $UI_rivers_layer.button_pressed:
			theta[1] = value
		else:
			theta[1] = 0
		get_parent()._update_geo_layer()
	else:
		_on_ui_rivers_slider_value_changed($UI_sea_layer/UI_sea_slider.value)

func _on_ui_av_theta_text_submitted(text: String) -> void:
	if text.is_valid_float():
		var value = text.to_float()
		$UI_av_slider.value = value
		theta[0] = value
		get_parent()._update_geo_layer()
	else:
		_on_ui_rivers_slider_value_changed($UI_av_slider.value)

func _on_ui_view_toggle_toggled(toggled_on: bool) -> void:
	if toggled_on:
		get_parent().set_geo_view(true)
	else:
		get_parent().set_geo_view(false)

func _on_ui_start_pressed() -> void:
	get_parent()._on_start()

func _on_ui_rivers_layer_pressed() -> void:
	if $UI_rivers_layer.is_pressed():
		theta[1] = $UI_rivers_layer/UI_rivers_slider.value
		get_parent()._update_geo_layer()
	else:
		theta[1] = 0.0
		get_parent()._update_geo_layer()

func _on_ui_sea_layer_pressed() -> void:
	if $UI_sea_layer.is_pressed():
		theta[2] = $UI_sea_layer/UI_sea_slider.value
		get_parent()._update_geo_layer()
	else:
		theta[2] = 0.0
		get_parent()._update_geo_layer()
