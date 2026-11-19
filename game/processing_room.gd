extends Node3D

const DOOR_CENTER = Vector3(2.61,1.17,1.54)
const DOOR_TRAVEL = 1.34
const WEST = -2.65
const EAST = 2.65
const NORTH = -1.48
const SOUTH = 3.45
const HEIGHT = 2.78

var site: Node3D
var door: Node3D
var door_shape: CollisionShape3D
var door_open: bool = false
var slide: float = 0.0
var plaster: Material
var tile: Material
var trim: Material
var metal: Material
var glass: StandardMaterial3D


func build(owner_site: Node3D) -> void:
	site = owner_site
	var wall_finish: ShaderMaterial = site.surface("a7a393")
	wall_finish.set_shader_parameter("coarse",.17)
	wall_finish.set_shader_parameter("grain",.105)
	plaster = wall_finish
	tile = site.surface("5c6b61",false,4)
	trim = site.surface("3c5149",false,5)
	metal = site.surface("939d93",false,2)
	glass = StandardMaterial3D.new()
	glass.albedo_color = Color(.61,.76,.74,.14)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = .23
	glass.metallic = .06
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	var depth: float = SOUTH-NORTH
	var center_z: float = (NORTH+SOUTH)*.5
	site.box(Vector3(0,.003,center_z),Vector3(5.18,.012,depth-.10),site.surface("4b5148",false,3),self)
	site.box(Vector3(0,HEIGHT+.045,center_z),Vector3(5.44,.14,depth+.16),plaster,self,true)
	wall_section(Vector3(WEST,0,center_z),depth,true)
	wall_section(Vector3(0,0,SOUTH),5.39,false)
	# East wall leaves a 1.32 m doorway, measured between the jambs.
	east_segment(NORTH,.88)
	east_segment(2.2,SOUTH)
	site.box(Vector3(EAST,2.52,DOOR_CENTER.z),Vector3(.20,.52,1.32),plaster,self,true)
	make_window()
	make_door()
	make_lighting()
	place_storage()
	place_work_details()


func wall_section(at: Vector3, length: float, side: bool) -> void:
	var dimension := Vector3(length,HEIGHT,.19)
	if side:
		dimension = Vector3(.19,HEIGHT,length)
	site.box(at+Vector3.UP*HEIGHT*.5,dimension,plaster,self,true)
	var inside: float = signf(at.x) if side else signf(at.z)
	var into_room := Vector3(-inside*.106,0,0) if side else Vector3(0,0,-inside*.106)
	var facing := Vector3(.022,.96,length) if side else Vector3(length,.96,.022)
	site.box(at+into_room+Vector3.UP*.48,facing,tile,self)
	var rail := Vector3(.038,.042,length) if side else Vector3(length,.042,.038)
	site.box(at+into_room+Vector3.UP*.98,rail,trim,self)
	site.box(at+into_room+Vector3.UP*.075,rail,trim,self)


func east_segment(from_z: float, to_z: float) -> void:
	wall_section(Vector3(EAST,0,(from_z+to_z)*.5),to_z-from_z,true)


func make_window() -> void:
	const WINDOW_W = 2.64
	const WINDOW_BASE = 1.22
	const WINDOW_TOP = 2.29
	const WINDOW_X = .16
	var cy: float = (WINDOW_BASE+WINDOW_TOP)*.5
	var ht: float = WINDOW_TOP-WINDOW_BASE
	var left: float = WINDOW_X-WINDOW_W*.5
	var right: float = WINDOW_X+WINDOW_W*.5
	wall_section(Vector3((WEST+left)*.5,0,NORTH),left-WEST,false)
	wall_section(Vector3((right+EAST)*.5,0,NORTH),EAST-right,false)
	site.box(Vector3(WINDOW_X,WINDOW_BASE*.5,NORTH),Vector3(WINDOW_W,WINDOW_BASE,.19),plaster,self,true)
	site.box(Vector3(WINDOW_X,(WINDOW_TOP+HEIGHT)*.5,NORTH),Vector3(WINDOW_W,HEIGHT-WINDOW_TOP,.19),plaster,self,true)
	for y in [WINDOW_BASE,WINDOW_TOP]:
		site.box(Vector3(WINDOW_X,y,NORTH),Vector3(WINDOW_W+.10,.070,.235),trim,self)
	for x in [left,WINDOW_X,right]:
		site.box(Vector3(x,cy,NORTH),Vector3(.067,ht,.205),trim,self)
	var pane: MeshInstance3D = site.box(Vector3(WINDOW_X,cy,NORTH),Vector3(WINDOW_W,ht,.018),glass,self,true)
	pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for x in [-.39,.81]:
		var glare := StandardMaterial3D.new()
		glare.albedo_color = Color(.76,.88,.82,.085)
		glare.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var reflection: MeshInstance3D = site.box(Vector3(x,1.83,NORTH+.016),Vector3(.073,.78,.003),glare,self)
		reflection.rotation.z = -.41
		reflection.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	site.box(Vector3(WINDOW_X,WINDOW_BASE-.018,NORTH+.14),Vector3(WINDOW_W+.16,.058,.37),metal,self)


func make_door() -> void:
	for z in [.86,2.22]:
		site.box(Vector3(EAST,1.10,z),Vector3(.235,2.20,.064),trim,self)
	site.box(Vector3(EAST,2.22,1.54),Vector3(.24,.082,1.43),trim,self)
	site.box(Vector3(2.535,2.30,2.17),Vector3(.16,.083,2.72),metal,self)
	site.box(Vector3(EAST,.014,1.54),Vector3(.30,.028,1.31),metal,self)
	door = Node3D.new()
	door.position = Vector3(2.53,0,1.54)
	add_child(door)
	site.box(Vector3(0,.53,0),Vector3(.085,1.05,1.32),tile,door)
	site.box(Vector3(0,2.14,0),Vector3(.088,.11,1.32),trim,door)
	site.box(Vector3(0,1.08,0),Vector3(.095,.058,1.32),trim,door)
	for z in [-.634,.634]:
		site.box(Vector3(0,1.56,z),Vector3(.082,1.13,.055),trim,door)
	var pane: MeshInstance3D = site.box(Vector3(0,1.602,0),Vector3(.013,1.05,1.20),glass,door)
	pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for x in [-.079,.079]:
		site.box(Vector3(x,1.12,-.43),Vector3(.045,.215,.054),metal,door)
		site.box(Vector3(x*.74,1.18,-.43),Vector3(.10,.026,.057),metal,door)
		site.box(Vector3(x*.74,1.05,-.43),Vector3(.10,.026,.057),metal,door)
		site.box(Vector3(x*.84,.71,0),Vector3(.018,.065,1.18),metal,door)
	var body := StaticBody3D.new()
	body.position = Vector3(2.58,1.09,1.54)
	add_child(body)
	door_shape = CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(.105,2.19,1.30)
	door_shape.shape = shape
	body.add_child(door_shape)
	door_sign("仓库及卸货区",Vector3(2.51,2.49,1.54),-PI*.5)
	door_sign("旧瓶处理室",Vector3(2.79,2.49,1.54),PI*.5)
	site.target("room_door","处理室滑门",DOOR_CENTER,.67,2.35)


func door_sign(words: String, at: Vector3, turn: float) -> void:
	var front := Vector3(sin(turn),0,0)
	site.box(at-front*.013,Vector3(.036,.23,1.15),trim,self)
	var title: Label3D = site.text_at(words,at+front*.014,52,.0027,"eddebc",self)
	title.rotation.y = turn


func make_lighting() -> void:
	var housing: Material = site.material("79796c",.60)
	var tube := StandardMaterial3D.new()
	tube.albedo_color = Color("dedbc4")
	tube.emission_enabled = true
	tube.emission = Color("fbe5ba")
	tube.emission_energy_multiplier = .64
	for position_z in [.19,2.67]:
		site.box(Vector3(0,2.713,position_z),Vector3(1.23,.06,.34),housing,self)
		site.box(Vector3(0,2.672,position_z),Vector3(1.11,.038,.255),tube,self)
		var task_side: bool = position_z < 1.0
		site.lamp(Vector3(0,2.60,position_z),"ffe9d1" if task_side else "e0e8e1",.77 if task_side else .60,4.1)
	site.lamp(Vector3(.18,1.92,NORTH+.274),"d5e4ee",.24,2.7)
	for z in [-.98,-.08,.82,1.72,2.62]:
		site.box(Vector3(-2.42,2.56,z),Vector3(.087,.055,.042),metal,self)
	var line: MeshInstance3D = site.cylinder(Vector3(-2.43,2.56,.82),.019,4.1,metal,self)
	line.rotation.x = PI*.5


func place_storage() -> void:
	var locker: Material = site.surface("516259",false,5)
	var dark: Material = site.material("303e39")
	var handle: Material = site.material("a8a890",.52,.25)
	var at := Vector3(-2.08,0,1.67)
	site.rounded(at+Vector3(0,.85,0),Vector3(.73,1.70,.75),.013,locker,self,true)
	for z in [-.181,.181]:
		site.rounded(at+Vector3(.374,.85,z),Vector3(.032,1.55,.342),.008,locker,self)
		for y in [1.42,1.47,1.52]:
			site.box(at+Vector3(.392,y,z),Vector3(.013,.012,.19),dark,self)
		site.rounded(at+Vector3(.404,.91,z+.10),Vector3(.036,.18,.025),.006,handle,self)
	site.crate(Vector3(-2.05,1.70,1.68),"7b7251",self,Vector3(.54,.21,.47))
	for x in [-2.02,-1.69,-1.36]:
		site.rounded(Vector3(x,1.84,SOUTH-.115),Vector3(.036,.051,.058),.006,metal,self)
		site.rounded(Vector3(x,1.836,SOUTH-.160),Vector3(.035,.028,.074),.006,metal,self)
	var towel: MeshInstance3D = site.rounded(Vector3(-1.69,1.62,SOUTH-.16),Vector3(.25,.40,.021),.008,site.surface("867b61",false,6),self)
	towel.rotation.z = .071
	site.rounded(Vector3(-1.62,1.608,SOUTH-.175),Vector3(.141,.432,.025),.008,site.surface("9c9076",false,6),self)
	for i in 2:
		var y: float = 1.27+i*.43
		site.box(Vector3(-2.29,y,.62),Vector3(.60,.047,.66),trim,self,true)
		for z in [.40,.83]:
			site.box(Vector3(-2.43,y-.12,z),Vector3(.18,.23,.049),metal,self)
	site.crate(Vector3(-2.27,1.295,.63),"645e44",self,Vector3(.41,.23,.50))
	for j in 3:
		var at_jar := Vector3(-2.28,1.735,.42+j*.205)
		var jar: Material = site.material(["b1a777","828e74","a2875f"][j],.38)
		site.cylinder(at_jar+Vector3.UP*.105,.062,.21,jar,self)
		site.cylinder(at_jar+Vector3.UP*.219,.068,.022,handle,self)
	var mat: Material = site.surface("333d36")
	site.box(Vector3(1.52,.021,2.73),Vector3(1.21,.036,.63),mat,self)
	for j in 9:
		site.box(Vector3(1.52,.040,2.445+j*.072),Vector3(1.16,.004,.017),trim,self)


func place_work_details() -> void:
	var panel: Material = site.material("6f796d")
	var white: Material = site.material("d1ccba")
	for j in 15:
		var x: float = -2.45+j*.35
		for row in 4:
			site.rounded(Vector3(x,.17+row*.278,NORTH+.112),Vector3(.344,.273,.029),.0038,tile,self)
	site.box(Vector3(.16,2.49,NORTH+.132),Vector3(1.66,.238,.055),trim,self)
	site.text_at("旧 瓶 处 理 室",Vector3(.16,2.49,NORTH+.167),58,.0031,"ede0c2",self)
	var board_z: float = NORTH+.158
	site.box(Vector3(-1.86,1.81,board_z),Vector3(.79,.61,.038),panel,self)
	site.box(Vector3(-1.86,1.82,board_z+.024),Vector3(.68,.52,.019),white,self)
	site.text_at("当班处理顺序",Vector3(-1.86,1.989,board_z+.038),46,.0014,"3c4d40",self)
	site.text_at("脱标 · 清洗 · 消毒 · 沥干",Vector3(-1.86,1.849,board_z+.038),46,.00117,"3c4d40",self)
	site.text_at("裂瓶放入碎玻璃桶",Vector3(-1.86,1.702,board_z+.038),46,.0010,"715f46",self)
	for x in [-2.14,-1.57]:
		site.box(Vector3(x,2.066,board_z+.041),Vector3(.045,.022,.011),metal,self)
	var copper: Material = site.material("6b5540",.57,.57)
	for x in [site.RINSE_X-.065,site.RINSE_X+.095]:
		site.cylinder(Vector3(x,.41,NORTH+.139),.012,.78,copper,self)
		var feed: MeshInstance3D = site.cylinder(Vector3(x,.78,-.91),.012,.87,copper,self)
		feed.rotation.x = PI*.5
		site.rounded(Vector3(x,.33,NORTH+.142),Vector3(.08,.034,.048),.005,metal,self)
	site.box(Vector3(1.92,1.235,NORTH+.118),Vector3(.25,.15,.057),panel,self)
	for x in [1.863,1.977]:
		site.box(Vector3(x,1.24,NORTH+.151),Vector3(.039,.064,.012),white,self)


func toggle(worker_position: Vector3) -> bool:
	if door_open and in_doorway(worker_position):
		return false
	door_open = not door_open
	return true


func in_doorway(worker_position: Vector3) -> bool:
	return absf(worker_position.x - DOOR_CENTER.x) < .46 and absf(worker_position.z - DOOR_CENTER.z) < .88


func animate(delta: float, worker_position: Vector3) -> void:
	if not door_open and slide >= .84 and in_doorway(worker_position):
		door_open = true
	var goal: float = 1.0 if door_open else 0.0
	if goal == slide:
		return
	slide = move_toward(slide,goal,delta*3.05)
	door.position.z = DOOR_CENTER.z + smoothstep(0.0,1.0,slide)*DOOR_TRAVEL
	var clear_aperture: bool = slide >= .84
	if clear_aperture != door_shape.disabled:
		door_shape.set_deferred("disabled",clear_aperture)
