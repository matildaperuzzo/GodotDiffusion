extends Node3D

# initialize shader variables
var rd : RenderingDevice = RenderingServer.create_local_rendering_device()
var bindings : Array
var pipeline : RID
var shader : RID
var geo_fmt : RDTextureFormat
var sim_fmt : RDTextureFormat
var sim_array_fmt : RDTextureFormat
var uniform_set : RID
var params_buffer : RID
var params_uniform : RDUniform

# define empty variables for geographical layers and the final simulation array
var heightmap : Image
var heightmap_texture : Texture2D

var river_layer : Image
var sea_layer : Image

var geo_layer : Image
var geo_layers : Array
var geo_layer_texture : ImageTexture
var geo_texture_buffer : RID
var geo_texture_uniform : RDUniform

var simulation_step : Image
var simulation_texture : ImageTexture
var simulation_texture_buffer : RID
var simulation_texture_uniform : RDUniform

var sim_array_uniform : RDUniform

# initialize simulation parameters
var SIM_SIZE : Vector2i
var N_AV : int = 1
var crop : String = "wheat"
var layer_filenames = ["res://Layers/hydro.png","res://Layers/crop.png","res://Layers/temperature.png","res://Layers/precipitation.png","res://Layers/sea.png"]
var heightmap_filename = "res://Layers/heightmap.png"

var frame_count : int = 0
var frame_skip : int = 0
var map_setting : bool = false
var started : bool = false


@export var active_color = Color(0.525,1,0.212,1)
@export var passive_color = Color(0,0,1,1)

const CROPS = {
	"wheat" : {"lats": Vector2(10,65), "lons": Vector2(-20,90), "start": Vector2(43.5000,36.3333)},
	"rice" : {"lats": Vector2(-20,50), "lons": Vector2(60,150), "start": Vector2(121.3500,29.96)},
	"maize" : {"lats": Vector2(0,60), "lons": Vector2(-130,-60), "start": Vector2(-93.21, 15.684)}
}

var lats = Vector2(10,65)
var lons = Vector2(-20,90)
var start = Vector2(43.5000,36.3333)
var start_ind : Vector2

func _on_start():
	N_AV = $Ui.get_UI_N()
	
	simulation_step = Image.create(SIM_SIZE.x, SIM_SIZE.y, false, Image.FORMAT_R8)
	simulation_step.fill(Color(0,0,0,1))
	# Pick random pixel coordinates
	#var rand_x = randi() % SIM_SIZE.x
	#var rand_y = randi() % SIM_SIZE.y
	start_ind = latlon_to_index(start, lats, lons, SIM_SIZE)
	simulation_step = Image.create(SIM_SIZE.x, SIM_SIZE.y, false, Image.FORMAT_R8)
	simulation_step.fill(Color(0,0,0,1))
	# Set that pixel to active
	simulation_step.set_pixel(start_ind[0], start_ind[1], Color(1,1,1,1))
	simulation_texture = ImageTexture.create_from_image(simulation_step)
	$ModelMesh.mesh.material.set_shader_parameter("texture_image", simulation_texture)
	
	if not started:
		set_up_shader()
		rd.submit()
	else:
		_reset_shader()
	started = true

func _on_crop_change(crop):
	
	crop = $Ui.get_UI_crop()	
	lats = CROPS[crop]['lats']
	lons = CROPS[crop]['lons']
	start = CROPS[crop]['start']
	start_ind = latlon_to_index(start, lats, lons, SIM_SIZE)

	var theta = $Ui.get_UI_theta()
	geo_layer = Image.new()
	geo_layers = crop_to_latlon_section_multiple(layer_filenames, lats, lons)
	heightmap_texture = load(heightmap_filename) as Texture2D
	heightmap = crop_to_latlon_section(heightmap_texture.get_image(), lats, lons)
	heightmap_texture = ImageTexture.create_from_image(heightmap)
	geo_layer = create_geo_layer(geo_layers, theta)
	SIM_SIZE = Vector2i(geo_layers[0].get_width(), geo_layers[0].get_height())

	geo_layer.convert(Image.FORMAT_RF)
	geo_layer_texture = ImageTexture.create_from_image(geo_layer)
	
	var aspect_ratio = float(geo_layer.get_width())/float(geo_layer.get_height())
	# Set that pixel to active
	simulation_step = Image.create(SIM_SIZE.x, SIM_SIZE.y, false, Image.FORMAT_R8)
	simulation_step.fill(Color(1,1,1,1))
	simulation_step.set_pixel(start_ind[0], start_ind[1], Color(1,1,1,1))
	simulation_texture = ImageTexture.create_from_image(simulation_step)
	
	$ModelMesh.mesh.size = Vector2(1.,1.)
	$ModelMesh.mesh.size.x *= aspect_ratio
	$ModelMesh.mesh.subdivide_width = SIM_SIZE.x / 2
	$ModelMesh.mesh.subdivide_depth = SIM_SIZE.y / 2
	$TerrainMesh.mesh.size = Vector2(1.,1.)
	$TerrainMesh.mesh.size.x *= aspect_ratio
	$TerrainMesh.mesh.subdivide_width = SIM_SIZE.x/2
	$TerrainMesh.mesh.subdivide_depth = SIM_SIZE.y/2
	$ModelMesh.mesh.material.set_shader_parameter("height_layer", heightmap_texture)
	$ModelMesh.mesh.material.set_shader_parameter("active_color", active_color)
	$ModelMesh.mesh.material.set_shader_parameter("passive_color", passive_color)
	$TerrainMesh.mesh.material.set_shader_parameter("height_layer", heightmap_texture)
	
	started = false

func _ready():
	geo_layer = Image.new()
	geo_layers = crop_to_latlon_section_multiple(layer_filenames, lats, lons)
	heightmap_texture = load(heightmap_filename) as Texture2D
	heightmap = crop_to_latlon_section(heightmap_texture.get_image(), lats, lons)
	heightmap_texture = ImageTexture.create_from_image(heightmap)

	#$Ui._setup_UI()
	var theta = $Ui.get_UI_theta()
	geo_layer = create_geo_layer(geo_layers, theta)
	SIM_SIZE = Vector2i(geo_layers[0].get_width(), geo_layers[0].get_height())

	geo_layer.convert(Image.FORMAT_RF)
	geo_layer_texture = ImageTexture.create_from_image(geo_layer)
	
	var aspect_ratio = float(geo_layer.get_width())/float(geo_layer.get_height())
	
	$ModelMesh.mesh.size.x *= aspect_ratio
	$ModelMesh.mesh.subdivide_width = SIM_SIZE.x / 2
	$ModelMesh.mesh.subdivide_depth = SIM_SIZE.y / 2
	$TerrainMesh.mesh.size.x *= aspect_ratio
	$TerrainMesh.mesh.subdivide_width = SIM_SIZE.x/2
	$TerrainMesh.mesh.subdivide_depth = SIM_SIZE.y/2
	$ModelMesh.mesh.material.set_shader_parameter("height_layer", heightmap_texture)
	$ModelMesh.mesh.material.set_shader_parameter("active_color", active_color)
	$ModelMesh.mesh.material.set_shader_parameter("passive_color", passive_color)
	$TerrainMesh.mesh.material.set_shader_parameter("height_layer", heightmap_texture)
	$TerrainMesh.mesh.material.set_shader_parameter("map_view", true)
	
	#var start_pin_scene = preload("res://Assets/pin.tscn")
	
	#var start_pin = start_pin_scene.instantiate()
	#add_child(start_pin)
	#start_ind = latlon_to_index(start, lats, lons, SIM_SIZE)
	#start_pin.get_node("pin_body").position.x = start_ind.x
	#start_pin.get_node("pin_body").position.z = start_ind.y
	
func _process(delta):
	if started:
		rd.sync()
		var output = rd.texture_get_data(simulation_texture_buffer, 0)
		simulation_step.set_data(SIM_SIZE.x,SIM_SIZE.y, false, Image.FORMAT_R8, output)
		simulation_texture.update(simulation_step)
		_update_shader()
	
	#print(latlon_to_index(CROPS[crop]['start'], CROPS[crop]['lats'], CROPS[crop]['lons'], SIM_SIZE))
	#print(start_ind)
	#print(SIM_SIZE)
		
func set_up_shader():
	var shader_file := load("res://ComputeShaders/diffusion_sim.glsl")
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	shader = rd.shader_create_from_spirv(shader_spirv)
	geo_fmt = RDTextureFormat.new()
	geo_fmt.width = SIM_SIZE.x
	geo_fmt.height = SIM_SIZE.y
	geo_fmt.format = RenderingDevice.DATA_FORMAT_R32_SFLOAT
	geo_fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	
	var geo_view := RDTextureView.new()
	geo_texture_buffer = rd.texture_create(geo_fmt, geo_view, [geo_layer.get_data()])
	geo_texture_uniform = _generate_uniforms(geo_texture_buffer, RenderingDevice.UNIFORM_TYPE_IMAGE, 0)
	
	sim_fmt = RDTextureFormat.new()
	sim_fmt.width = SIM_SIZE.x
	sim_fmt.height = SIM_SIZE.y
	sim_fmt.format = RenderingDevice.DATA_FORMAT_R8_UNORM
	sim_fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	
	var sim_view := RDTextureView.new()
	simulation_texture_buffer = rd.texture_create(sim_fmt, sim_view, [simulation_step.get_data()])
	simulation_texture_uniform = _generate_uniforms(simulation_texture_buffer, RenderingDevice.UNIFORM_TYPE_IMAGE, 1)
	
	params_buffer = _generate_parameter_buffer()
	params_uniform = _generate_uniforms(params_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 2)
	
	sim_array_fmt = RDTextureFormat.new()
	sim_array_fmt.texture_type = RenderingDevice.TEXTURE_TYPE_2D_ARRAY
	sim_array_fmt.width = simulation_step.get_width()
	sim_array_fmt.height = simulation_step.get_height()
	sim_array_fmt.depth = 1
	sim_array_fmt.array_layers = N_AV
	sim_array_fmt.format = RenderingDevice.DATA_FORMAT_R8_UNORM
	sim_array_fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	
	var sim_array_view := RDTextureView.new()
	var layers = []
	for i in N_AV:
		layers.append(simulation_step.get_data())

	var sim_array = rd.texture_create(sim_array_fmt, sim_array_view, layers)
	sim_array_uniform = _generate_uniforms(sim_array, RenderingDevice.UNIFORM_TYPE_IMAGE, 3)
	
	uniform_set = rd.uniform_set_create([geo_texture_uniform, simulation_texture_uniform, params_uniform, sim_array_uniform], shader, 0)
	
	# Create a compute pipeline
	pipeline = rd.compute_pipeline_create(shader)
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)

	rd.compute_list_dispatch(compute_list, ceil(SIM_SIZE.x / 16.0), ceil(SIM_SIZE.y / 16.0), N_AV)
	rd.compute_list_end()

	
func _reset_shader():
	rd.sync()
	var geo_view := RDTextureView.new()
	geo_texture_buffer = rd.texture_create(geo_fmt, geo_view, [geo_layer.get_data()])
	geo_texture_uniform = _generate_uniforms(geo_texture_buffer, RenderingDevice.UNIFORM_TYPE_IMAGE, 0)
	
	var sim_view := RDTextureView.new()
	simulation_texture_buffer = rd.texture_create(sim_fmt, sim_view, [simulation_step.get_data()])
	simulation_texture_uniform = _generate_uniforms(simulation_texture_buffer, RenderingDevice.UNIFORM_TYPE_IMAGE, 1)

	sim_array_fmt = RDTextureFormat.new()
	sim_array_fmt.texture_type = RenderingDevice.TEXTURE_TYPE_2D_ARRAY
	sim_array_fmt.width = simulation_step.get_width()
	sim_array_fmt.height = simulation_step.get_height()
	sim_array_fmt.depth = 1
	sim_array_fmt.array_layers = N_AV
	sim_array_fmt.format = RenderingDevice.DATA_FORMAT_R8_UNORM
	sim_array_fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	
	var sim_array_view := RDTextureView.new()
	var layers = []
	for i in N_AV:
		layers.append(simulation_step.get_data())

	var sim_array = rd.texture_create(sim_array_fmt, sim_array_view, layers)
	sim_array_uniform = _generate_uniforms(sim_array, RenderingDevice.UNIFORM_TYPE_IMAGE, 3)
	
	uniform_set = rd.uniform_set_create([geo_texture_uniform, simulation_texture_uniform, params_uniform, sim_array_uniform], shader, 0)
	
	# Create a compute pipeline
	pipeline = rd.compute_pipeline_create(shader)
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)

	rd.compute_list_dispatch(compute_list, ceil(SIM_SIZE.x / 16.0), ceil(SIM_SIZE.y / 16.0), N_AV)
	rd.compute_list_end()
	rd.submit()
	
func _update_shader():
	rd.free_rid(simulation_texture_buffer)
	var sim_view := RDTextureView.new()
	simulation_texture_buffer = rd.texture_create(sim_fmt, sim_view, [simulation_step.get_data()])
	simulation_texture_uniform = _generate_uniforms(simulation_texture_buffer, RenderingDevice.UNIFORM_TYPE_IMAGE, 1)
	
	rd.free_rid(params_buffer)
	params_buffer = _generate_parameter_buffer()
	params_uniform.clear_ids()
	params_uniform.add_id(params_buffer)
	
	uniform_set = rd.uniform_set_create([geo_texture_uniform, simulation_texture_uniform, params_uniform, sim_array_uniform], shader, 0)
	
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_dispatch(compute_list, ceil(SIM_SIZE.x / 32.0), ceil(SIM_SIZE.y / 32.0), N_AV)
	rd.compute_list_end()
	rd.submit()
	
func _generate_uniforms(data_buffer, type, binding):
	var data_uniform = RDUniform.new()
	data_uniform.uniform_type = type
	data_uniform.binding = binding
	data_uniform.add_id(data_buffer)
	return data_uniform
	
func _generate_parameter_buffer():
	var params_buffer_bytes : PackedByteArray = PackedFloat32Array(
		[randi()
		]).to_byte_array()
	return rd.storage_buffer_create(params_buffer_bytes.size(), params_buffer_bytes)
	
func _exit_tree():
	rd.sync()
	rd.free_rid(geo_layer)
	rd.free_rid(uniform_set)
	rd.free_rid(geo_texture_buffer)
	rd.free_rid(pipeline)
	rd.free_rid(shader)
	rd.free()
	
func _update_geo_layer():
	var theta = $Ui.get_UI_theta()
	if geo_layers.size() == 0:
		return
	var new_geo = create_geo_layer(geo_layers, theta)
	SIM_SIZE = Vector2i(new_geo.get_width(),new_geo.get_height())
	
	geo_layer.set_data(SIM_SIZE.x,SIM_SIZE.y, false, Image.FORMAT_R8, new_geo.get_data())
	geo_layer.convert(Image.FORMAT_RF)
	geo_layer_texture = ImageTexture.create_from_image(geo_layer)
	print(geo_layer.get_pixel(100,100))
	if $Ui/UI_view_toggle.button_pressed:
		$ModelMesh.mesh.material.set_shader_parameter("height_layer", geo_layer_texture)
		$TerrainMesh.mesh.material.set_shader_parameter("height_layer", geo_layer_texture)
	

func set_geo_view(ans : bool) -> void:
	if ans == false and map_setting == false:
		return
	elif ans == true and map_setting == true:
		return
	elif ans == false and map_setting == true:
		$ModelMesh.mesh.material.set_shader_parameter("height_layer", heightmap_texture)
		$TerrainMesh.mesh.material.set_shader_parameter("height_layer", heightmap_texture)
		$TerrainMesh.mesh.material.set_shader_parameter("map_view", true)
		map_setting = false
	elif ans == true and map_setting == false:
		$ModelMesh.mesh.material.set_shader_parameter("height_layer", geo_layer_texture)
		$TerrainMesh.mesh.material.set_shader_parameter("height_layer", geo_layer_texture)
		$TerrainMesh.mesh.material.set_shader_parameter("map_view", false)
		map_setting = true
		
func crop_to_latlon_section(img: Image, latitudes: Vector2, longitudes: Vector2) -> Image:
	var width = img.get_width()
	var height = img.get_height()

	# Convert lat/lon → pixel coords
	var x0 = int(((longitudes.x + 180.0) / 360.0) * width)
	var x1 = int(((longitudes.y + 180.0) / 360.0) * width)
	var y0 = int(((90.0 - latitudes.y) / 180.0) * height)  # top
	var y1 = int(((90.0 - latitudes.x) / 180.0) * height)  # bottom

	var sub_width = x1 - x0
	var sub_height = y1 - y0

	# Create new image
	var cropped = Image.create(sub_width, sub_height, false, Image.FORMAT_R8)
	#img.lock()
	#cropped.lock()
	for y in range(sub_height):
		for x in range(sub_width):
			var col = img.get_pixel(x0 + x, y0 + y)
			cropped.set_pixel(x, y, col)
	#img.unlock()
	#cropped.unlock()
	return cropped

func crop_to_latlon_section_multiple(img_paths: Array, lats: Vector2, lons: Vector2) -> Array:
	var img : Array
	var cropped : Array
	
	var img_length = img_paths.size()
	for layer in range(img_length):
		var path = img_paths[layer]
		var tex = load(path) as Texture2D
		if tex == null:
			push_warning("Failed to load: %s:" %path)
			continue
		img.append(tex.get_image())
		
	var width = img[0].get_width()
	var height = img[0].get_height()

	# Convert lat/lon → pixel coords
	var x0 = int(((lons.x + 180.0) / 360.0) * width)
	var x1 = int(((lons.y + 180.0) / 360.0) * width)
	var y0 = int(((90.0 - lats.y) / 180.0) * height)  # top
	var y1 = int(((90.0 - lats.x) / 180.0) * height)  # bottom

	var sub_width = x1 - x0
	var sub_height = y1 - y0

	# Create new image
	for layer in range(img.size()):
		cropped.append(Image.create(sub_width, sub_height, false, Image.FORMAT_R8))

	for y in range(sub_height):
		for x in range(sub_width):
			for layer in range(img.size()):
				var col =  img[layer].get_pixel(x + x0, y + y0)
				cropped[layer].set_pixel(x,y,col)
	return cropped
	
func create_geo_layer(layers : Array, thetas : Array) -> Image:
	if layers.size() != thetas.size()-1:
		push_error('Number of thetas must be img_paths.size() + 1')
	var width = layers[0].get_width()
	var height = layers[0].get_height()
	var geolayer = Image.create(width,height,false,Image.FORMAT_R8)
	for y in range(height):
		for x in range(width):
			var col = thetas[0]
			for layer in range(layers.size()):
				col += layers[layer].get_pixel(x,y).r*thetas[layer+1]*50.
			col = 1./(1. + exp(-col))
			geolayer.set_pixel(x,y,Color(col,0,0,1))
	return geolayer

func latlon_to_index(coords: Vector2, lats: Vector2, lons: Vector2, size : Vector2i) -> Vector2i:
	# Normalize lon to [0, 1]
	var x_norm = (coords[0] - lons[0]) / (lons[1] - lons[0])
	# Normalize lat to [0, 1] (flip so lat_max → row=0)
	var y_norm = (coords[1] - lats[0]) / (lats[1] - lats[0])

	# Scale to matrix indices
	var i = int(round(x_norm * (size[0] - 1)))
	var j = size[1] - int(round(y_norm * (size[1] - 1)))

	# Clamp to valid indices
	i = clamp(i, 0, size[0] - 1)
	j = clamp(j, 0, size[1] - 1)

	return Vector2i(i, j)
