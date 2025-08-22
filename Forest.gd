extends Node3D

var positions = PackedVector3Array()
var positions_array : Array
var tree_nodes = Array()
var connection_nodes = Array()
var connections : Array
var glowRing : Area3D
var connectionNode : PackedScene
var connectionsNum = 0


var tree_out_pos : Vector3
var tree_out : int = 0
var tree_in_pos : Vector3
var tree_in : int
var treeCentered = false

var tot_resources = 113
var resource_left = tot_resources

# Called when the node enters the scene tree for the first time.
func _ready():
	load_data()
	var myNode = preload("res://Assets/Level_1/Scenes/Tree1.tscn")
	var scale_factor = $Terrain/Terrain.mesh.size
	
	for i in range(len(positions_array)):
		var position = Vector3(positions_array[i][0],positions_array[i][1],positions_array[i][2])

		var tree1 = myNode.instantiate()
		tree1.name ="Tree"+str(i)
		add_child(tree1)
		tree1.global_position = Vector3(position[0]*scale_factor.x,position[1],position[2]*scale_factor.y)
		tree1.global_position -= Vector3(scale_factor.x/2, 0, scale_factor.y/2)
		tree_nodes.append(tree1)
		positions.append(tree1.global_position)
	
	print(positions[tree_out])
	tree_out_pos = positions[tree_out]
	$GlowRing.position = positions[tree_out]
	$GlowRing.position.y = 5
	$Camera3D._move_camera(positions[tree_out])
	connectionNode = preload("res://Assets/Scenes_general/Connection.tscn")

func _process(delta):
	
	_update_dev()
	
	if Input.is_action_just_pressed("ui_accept") and treeCentered:
		tree_in_pos =  Vector3($GlowRing.position.x,0,$GlowRing.position.z)
		tree_in = positions.find(tree_in_pos,0)
		
		if _can_connect(tree_in, tree_out):
			# Establish connection between trees
			var new_connection = connectionNode.instantiate()
			connection_nodes.append(new_connection)
			new_connection.set_start_end_points(tree_out_pos,tree_in_pos)
			add_child(new_connection)
			connection_nodes.append(new_connection)
			
			# Update trees
			tree_nodes[tree_out].add_connection(connectionsNum, "out")
			tree_nodes[tree_in].add_connection(connectionsNum, "in")
			connectionsNum += 1
			
			# Update UI
			resource_left -= tree_in_pos.distance_to(tree_out_pos)
			$UI._change_resource_value(resource_left*100/tot_resources)
			
			# Move camera
			var displacement = tree_in_pos-tree_out_pos
			$Camera3D._move_camera(displacement)
			
			tree_out = tree_in
			tree_out_pos = tree_in_pos
			
		# add movement without connection 
		# only move if tree has a connection already
		
		# add connection severing

		
	if _is_game_over(connections):
		$UI._game_over()

	
func sum(arr:Array):
	var result = 0
	for i in arr:
		if not is_nan(i):
			result+=i
	return result

func _is_game_over(mat):
	for row in mat:
		if sum(row) == 0:
			return false
	return true
	
func _can_connect(tree_in : int, tree_out : int):
	var trees_can_connect = tree_nodes[tree_in]._can_connect("in") && tree_nodes[tree_out]._can_connect("out")
	var env_can_connect = $Terrain._can_connect(tree_in, tree_out)
	var enough_resource = resource_left > positions[tree_in].distance_to(positions[tree_out])
	
	return (trees_can_connect && env_can_connect && enough_resource)
	
func _update_dev():
	var nwln = "\n"
	var txt = "treeCentered: " + str(treeCentered) + nwln
	txt += "connectionsNum: " + str(connectionsNum) + nwln
	txt += "centerPoint: " + str(positions[tree_out]) + nwln
	txt += "tree_out: " + str(tree_out) + " tree_in: " + str(tree_in) + nwln 
	txt += "glowRing pos: " + str($GlowRing.position)
	$DevNotes/Notes.text = txt

func readJSON(json_file_path):
	var file = FileAccess.open(json_file_path, FileAccess.READ)
	var content = file.get_as_text()
	var json = JSON.new()
	var finish = json.parse_string(content)
	return finish

func load_data():
	var content = readJSON("res://Assets/Level_1/Scripts/Data/tree_positions.json")
	if content:
		positions_array = content["tree_positions"]
		connections = content["connection_matrix"]
	else:
		print("Error parsing JSON")

func _on_glow_ring_ring_locked(lock_condition):
	treeCentered = lock_condition
