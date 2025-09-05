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
var heightmap_texture : ImageTexture

var river_layer : Image
var sea_layer : Image

var geo_layer : Image
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
var N_AV : int = 100

var frame_count : int = 0
var frame_skip : int = 0

@export var active_color = Color(0.525,1,0.212,1)
@export var passive_color = Color(0,0,1,1)

var lats = Vector2(10,65)
var lons = Vector2(-20,90)

func _ready():

	geo_layer = Image.new()
	var layer_filenames = ["res://Layers/sea.png","res://Layers/hydro.png"]
	var heightmap_filename = "res://Layers/heightmap.png"
	var theta = [-1.411, -1.116, 1.445]
	
	var layers = crop_to_latlon_section_multiple(layer_filenames, heightmap_filename, lats, lons)
	heightmap = layers[layers.size() - 1]
	var geo_layers : Array
	for l in range(layers.size()-1):
		geo_layers.append(layers[l])
	geo_layer = create_geo_layer(geo_layers, theta)
	SIM_SIZE = Vector2i(layers[0].get_width(), layers[0].get_height())
	geo_layer.convert(Image.FORMAT_RF)
	
	var aspect_ratio = float(geo_layer.get_width())/float(geo_layer.get_height())
	
	$ModelMesh.mesh.size.x *= aspect_ratio
	$ModelMesh.mesh.subdivide_width = SIM_SIZE.x / 2
	$ModelMesh.mesh.subdivide_depth = SIM_SIZE.y / 2
	$TerrainMesh.mesh.size.x *= aspect_ratio
	$TerrainMesh.mesh.subdivide_width = SIM_SIZE.x/2
	$TerrainMesh.mesh.subdivide_depth = SIM_SIZE.y/2
	#$TerrainMesh.position.y =- 0.00001;

	
	simulation_step = Image.create(SIM_SIZE.x, SIM_SIZE.y, false, Image.FORMAT_R8)

	simulation_step.fill(Color(0,0,0,1))
	# Pick random pixel coordinates
	var rand_x = randi() % SIM_SIZE.x
	var rand_y = randi() % SIM_SIZE.y

	# Set that pixel to active
	simulation_step.set_pixel(rand_x, rand_y, Color(1,1,1,1))
	
	simulation_texture = ImageTexture.create_from_image(simulation_step)
	geo_layer_texture = ImageTexture.create_from_image(geo_layer)
	
	var heightmap_file = load("res://Layers/heightmap.png") as Texture2D
	#heightmap = Image.create(heightmap_file.get_width(),heightmap_file.get_height(), false, Image.FORMAT_R8)
	heightmap = heightmap_file.get_image()

	var cropped_img = crop_to_latlon_section(heightmap, lats, lons)
	heightmap_texture = ImageTexture.create_from_image(cropped_img)
	
	$ModelMesh.mesh.material.set_shader_parameter("texture_image", simulation_texture)
	$ModelMesh.mesh.material.set_shader_parameter("height_layer", heightmap_texture)
	$ModelMesh.mesh.material.set_shader_parameter("active_color", active_color)
	$ModelMesh.mesh.material.set_shader_parameter("passive_color", passive_color)
	
	$TerrainMesh.mesh.material.set_shader_parameter("height_layer", heightmap_texture)
	
	set_up_shader()
	rd.submit()
	
func _process(delta):
	
	if frame_count < frame_skip:
		frame_skip += 1
	else:
		rd.sync()
		var output = rd.texture_get_data(simulation_texture_buffer, 0)
		simulation_step.set_data(SIM_SIZE.x,SIM_SIZE.y, false, Image.FORMAT_R8, output)
		simulation_texture.update(simulation_step)
		_update_shader()
		frame_count = 0
	

func set_up_shader():
	var shader_file := load("res://diffusion_sim.glsl")
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
	
func crop_to_latlon_section(img: Image, lats: Vector2, lons: Vector2) -> Image:
	var width = img.get_width()
	var height = img.get_height()

	# Convert lat/lon → pixel coords
	var x0 = int(((lons.x + 180.0) / 360.0) * width)
	var x1 = int(((lons.y + 180.0) / 360.0) * width)
	var y0 = int(((90.0 - lats.y) / 180.0) * height)  # top
	var y1 = int(((90.0 - lats.x) / 180.0) * height)  # bottom

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

func crop_to_latlon_section_multiple(img_paths: Array, heightmap_path : String , lats: Vector2, lons: Vector2) -> Array:
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
	var heightmap_tex = load(heightmap_path) as Texture2D
	if heightmap_tex == null:
		push_warning("Failed to load: %s:" %heightmap_path)
	img.append(heightmap_tex.get_image())
		
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
