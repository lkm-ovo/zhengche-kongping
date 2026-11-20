extends Node3D

const Yard = preload("res://yard.gd")
const Surface = preload("res://surface.gdshader")
const ProcessingRoom = preload("res://processing_room.gd")
const Shapes = preload("res://workshop_shapes.gd")
const Steam = preload("res://steam.gdshader")
const Paper = preload("res://paper.gdshader")
const LineMachine = preload("res://line_machine.gd")
const GarageStock = preload("res://garage_stock.gd")
const FinishedCrate = preload("res://finished_crate.gd")
const Glass = preload("res://glass.gdshader")
const COUNTER_Z = -.20
const COUNTER_TOP = .935
const COUNTER_FRONT = .54
const STRIP_X = -1.15
const RINSE_X = -.33
const STEAM_X = .39
const DRAIN_X = 1.015
const PACK_X = 1.58
const TERMINAL_X = 2.23
const FAUCET = Vector3(RINSE_X+.010,1.207,COUNTER_Z-.091)
const FAUCET_VALVE = Vector3(RINSE_X+.116,1.055,COUNTER_Z-.248)
const SANITIZER_TRAY = Vector3(STEAM_X,.970,COUNTER_Z)
const DRAIN_PIN = Vector3(DRAIN_X,1.017,COUNTER_Z)
const CLEAN_CRATE = Vector3(PACK_X,COUNTER_TOP,COUNTER_Z)
const SALE_BOOTH = Vector3(3.99,0,5.48)
const SCRAP_BIN = Vector3(-1.59,0,.535)
const STATIONS = [[STRIP_X,"脱标"],[RINSE_X,"冲洗"],
	[STEAM_X,"消毒"],[DRAIN_X,"沥干"],[PACK_X,"装筐"],[TERMINAL_X,"站务"]]
const AUTOMATION_X = -10.36
const AUTOMATION_Z = -5.40
const AUTOMATION_SPACING = 2.96
const AUTOMATION_ORDER = [2,0,1,5,Yard.SANITIZER,3,4,6]
const CART_HOME = Vector3(5.56,.014,3.74)

var font: SystemFont
var targets: Dictionary = {}
var steam_door: Node3D
var steam_display: Label3D
var steam_lamp: StandardMaterial3D
var chamber_mist: Node3D
var chamber_fan: Node3D
var chamber_light: OmniLight3D
var faucet_valve: MeshInstance3D
var cabinet_closed: float = 0.0
var room := ProcessingRoom.new()
var garage := GarageStock.new()
var machines: Array[LineMachine] = []
var conveyors: Array = []
var glass_on_line: Array[Node3D] = []
var line_labels: Array[MeshInstance3D] = []
var line_bottle_heights := PackedFloat32Array()
var outbound_cartons: Array[Node3D] = []
var machine_offsets := PackedFloat32Array()
var display_crates: Array = []
var cart: Node3D
var cart_basket: Node3D
var cart_crate_deck: MeshInstance3D
var cart_crate_posts: Node3D
var cart_crate_rack: Node3D
var cart_boxes: Array[FinishedCrate] = []
var cart_bottles: Array[MeshInstance3D] = []
var inbound_truck: Node3D
var queued_trucks: Array = []
var yard_pallets: Array = []
var outgoing_pallets: Array = []
var clean_box: FinishedCrate
var window_count: Label3D
var line_phase: float = 0.0
var truck_position: float = 19.0
var truck_timer: float = 0.0
var truck_count: int = 0
var mat_cache: Dictionary = {}
var rounded_cache: Dictionary = {}
var stock_meshes: Array = []
var stock_labels: Array = []
var bottle_bodies: Array[Mesh] = []
var bottle_rims: Array[Mesh] = []
var finished_glass: Array[ShaderMaterial] = []
var bottle_detail_mesh := SphereMesh.new()
var label_offcuts: Array[MeshInstance3D] = []
var table_scraper: Node3D
var table_scraper_level: int = -1


func material(code: String, rough: float = 0.74, metal: float = 0.0) -> StandardMaterial3D:
	var key: String = "%s/%s/%s" % [code, rough, metal]
	if not mat_cache.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(code)
		m.roughness = rough
		m.metallic = metal
		mat_cache[key] = m
	return mat_cache[key]


func surface(code: String, is_wood: bool = false, finish: int = 0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = Surface
	m.set_shader_parameter("tint", Color(code))
	m.set_shader_parameter("coarse", 0.31 if is_wood else 0.27)
	m.set_shader_parameter("grain", 0.20)
	m.set_shader_parameter("finish", 1 if is_wood else finish)
	return m


func mesh_at(source: Mesh, at: Vector3, mat: Material, parent: Node3D = self) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.mesh = source
	item.material_override = mat
	item.position = at
	parent.add_child(item)
	return item


func box(at: Vector3, size: Vector3, mat: Material, parent: Node3D = self, solid: bool = false) -> MeshInstance3D:
	var source := BoxMesh.new()
	source.size = size
	var item := mesh_at(source, at, mat, parent)
	if solid:
		fix_collision(item,size)
	return item


func rounded(at: Vector3, size: Vector3, radius: float, mat: Material, parent: Node3D = self, solid: bool = false) -> MeshInstance3D:
	var key: String = "%s/%s" % [size,radius]
	if not rounded_cache.has(key):
		rounded_cache[key] = Shapes.rounded_box(size,radius)
	var item := mesh_at(rounded_cache[key],at,mat,parent)
	if solid:
		fix_collision(item,size)
	return item


func fix_collision(item: Node3D, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	item.add_child(body)
	body.add_child(collision)


func cylinder(at: Vector3, radius: float, height: float, mat: Material, parent: Node3D = self) -> MeshInstance3D:
	var source := CylinderMesh.new()
	source.top_radius = radius
	source.bottom_radius = radius
	source.height = height
	source.radial_segments = 16
	return mesh_at(source, at, mat, parent)


func text_at(value: String, at: Vector3, size: int, scale_px: float, color: String, parent: Node3D = self) -> Label3D:
	var label := Label3D.new()
	label.text = value
	label.position = at
	label.font = font
	label.font_size = size
	label.pixel_size = scale_px
	label.outline_size = 0
	label.modulate = Color(color)
	label.no_depth_test = false
	parent.add_child(label)
	return label


func target(id: String, label: String, at: Vector3, radius: float, reach: float = 2.65) -> void:
	targets[id] = {"label": label, "position": at, "radius": radius, "reach": reach}


func build() -> void:
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC"])
	bottle_detail_mesh.radial_segments = 12
	bottle_detail_mesh.rings = 7
	bottle_detail_mesh.height = 2.0
	bottle_detail_mesh.radius = 1.0
	for i in Yard.NAMES.size():
		var profile: Array = [[0.0,0.0]] + Yard.BOTTLE_PROFILES[i]
		var rim: Array = profile.back()
		profile.append_array([[rim[0],rim[1]*.72],[rim[0]-.012,rim[1]*.66],[rim[0]-.012,0.0]])
		stock_meshes.append(Shapes.lathe(profile,19))
		stock_labels.append(Shapes.lathe(Shapes.label_profile(Yard.BOTTLE_PROFILES[i],.067,.13),16,-.88,3.6))
		bottle_bodies.append(Shapes.lathe(Yard.BOTTLE_PROFILES[i],56))
		var top: float = rim[0]
		var lip: float = rim[1]
		bottle_rims.append(Shapes.lathe([[top-.034,lip*.71],[top-.009,lip*.71],[top-.002,lip*.79],[top,lip]],42))
		var glass := ShaderMaterial.new()
		glass.shader = Glass
		glass.set_shader_parameter("glass",Color(Yard.GLASS[i]))
		finished_glass.append(glass)
	var env := WorldEnvironment.new()
	var settings := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("657b8e")
	sky_mat.sky_horizon_color = Color("d5b394")
	sky_mat.ground_horizon_color = Color("ab927c")
	sky_mat.ground_bottom_color = Color("353a39")
	sky.sky_material = sky_mat
	settings.background_mode = Environment.BG_SKY
	settings.sky = sky
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("c6d7eb")
	settings.ambient_light_energy = 0.48
	settings.tonemap_mode = Environment.TONE_MAPPER_AGX
	settings.tonemap_exposure = 1.12
	settings.fog_enabled = true
	settings.fog_light_color = Color("b5a394")
	settings.fog_density = 0.006
	env.environment = settings
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-34, -42, 0)
	sun.light_color = Color("ffe1b8")
	sun.light_energy = 1.02
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 45
	add_child(sun)
	var concrete := surface("686b63")
	var outside := surface("555950")
	var wall := material("797e70")
	var steel := material("3b504b", 0.49, 0.18)
	var dark := material("222e2a")
	var roof := material("4b534e")
	var trim := material("64776c")
	var yellow := material("c18739")
	var wood := surface("755b3e", true)
	box(Vector3(0, -0.14, -2), Vector3(28, 0.28, 24), concrete, self, true)
	box(Vector3(0, -0.20, -26), Vector3(48, 0.28, 26), outside, self, true)
	box(Vector3(0, -0.20, 16), Vector3(48, 0.28, 15), outside, self, true)
	box(Vector3(-14.1, -0.18, -1.5), Vector3(0.35, 0.35, 24), dark, self, true)
	box(Vector3(14.1, -0.18, -1.5), Vector3(0.35, 0.35, 24), dark, self, true)
	for x in [-14.0, 14.0]:
		box(Vector3(x, 2.65, -2), Vector3(0.32, 5.3, 24), wall, self, true)
		box(Vector3(x - sign(x) * .18, .58, -2), Vector3(.045, 1.12, 24), trim)
		for i in 8:
			box(Vector3(x - sign(x) * 0.28, 2.9, -12 + i * 3.0), Vector3(.34, 5.8, .28), steel)
	for x in [-9.5, 9.5]:
		box(Vector3(x, 2.68, -13.8), Vector3(9.0, 5.36, .32), wall, self, true)
		box(Vector3(x, 1.03, -13.61), Vector3(8.95, 1.94, .02), trim)
		box(Vector3(x, 2.1, 9.95), Vector3(9.0, 4.2, .32), wall, self, true)
		for rib in 22:
			var rib_at := Vector3(x-4.28+rib*.40,3.45,-13.60)
			box(rib_at,Vector3(.035,3.45,.06),roof)
		box(Vector3(x,1.98,-13.54),Vector3(8.95,.085,.068),steel)
	for z in [-6.8, 3.0]:
		var pipe := cylinder(Vector3(0,4.57,z),.075,27.5,trim)
		pipe.rotation.z = PI/2.0
		for i in 8:
			box(Vector3(i*3.6-12.6,4.88,z),Vector3(.041,.56,.05),steel)
	box(Vector3(0, 5.58, -2), Vector3(28.4, .33, 24.4), roof)
	for i in 8:
		var z: float = -12.0 + i * 3.03
		box(Vector3(0, 5.19, z), Vector3(28, .28, .32), steel)
		for x in [-7.6, 0, 7.6]:
			box(Vector3(x, 4.95, z), Vector3(.22, .28, .12), dark)
			box(Vector3(x, 4.78, z), Vector3(1.9, .08, .22), material("d0c6a3"))
			if i % 2 == 0 and (absf(x) > 1.0 or absf(z) > 3.2):
				lamp(Vector3(x, 4.62, z), "f0e2ce", .79, 7.3)
	for x in [-5.0, 5.0]:
		box(Vector3(x, 2.6, -13.75), Vector3(.34, 5.2, .45), steel)
		box(Vector3(x, .72, -13.43), Vector3(.38, 1.44, .30), yellow)
		hazards(Vector3(x, .16, -13.24), .34, 4)
	box(Vector3(0, 4.78, -13.74), Vector3(10.1, .78, .42), steel)
	text_at("回  收  码  头", Vector3(0, 4.78, -13.5), 70, .009, "e4d5b0")
	for i in 16:
		var z: float = -13.0 + i * 1.42
		for x in [-9.2, 9.2]:
			box(Vector3(x, .005, z), Vector3(.075, .012, .82), yellow)
	for i in 12:
		box(Vector3(-12.0 + i * 2.15, .004, -12.7), Vector3(.95, .011, .09), yellow)
	for i in 7:
		var x: float = -12.1 + i * 4.0
		box(Vector3(x, .002, -2), Vector3(.023, .007, 23.2), dark)
	for i in 5:
		var z: float = -12.0 + i * 5.2
		box(Vector3(0, .002, z), Vector3(27.2, .007, .018), dark)

	add_child(room)
	room.build(self)
	add_child(garage)
	garage.build(self)
	target("stock","车库来料区",GarageStock.PICK_POINT,1.05,3.85)
	build_cart()
	build_sale_window()
	hand_line(wood,steel)
	bench(Vector3(-5.3, 0, -.8), wood, steel)
	shelf(Vector3(-6.0, 0, -2.2))
	shelf(Vector3(-11.8, 0, -2.6))
	shelf(Vector3(9.6, 0, -11.8))
	var wall_sign := box(Vector3(8.1,3.13,-13.39),Vector3(3.1,.95,.09),steel)
	text_at("轻放玻璃   ·   废料分类",Vector3(8.1,3.26,-13.31),49,.004,"e6c892")
	text_at("整托进站由码头接收",Vector3(8.1,2.98,-13.31),43,.0032,"d8decc")
	wall_sign.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	machines.resize(Yard.EQUIPMENT.size())
	machine_offsets.resize(machines.size())
	for i in AUTOMATION_ORDER.size():
		var x: float = AUTOMATION_X+i*AUTOMATION_SPACING
		var index: int = AUTOMATION_ORDER[i]
		var equipment := LineMachine.new()
		equipment.position = Vector3(x,0,AUTOMATION_Z)
		add_child(equipment)
		equipment.build(index,self)
		machines[index] = equipment
		conveyor(Vector3(x,.84,AUTOMATION_Z),AUTOMATION_SPACING,i)
	for i in 2:
		var carton := crate(Vector3.ZERO,"9f794e",self,Vector3(.52,.17,.35))
		for j in 3:
			tiny_bottle(carton,Vector3((j-1)*.145,.032,0),(i+j)%3).hide()
		carton.hide()
		outbound_cartons.append(carton)
	for i in 20:
		var x: float = -10.0 - (i % 4) * 0.83
		var z: float = -7.1 - (i / 4) * 1.0
		var stack := Node3D.new()
		stack.position = Vector3(x, 0, z)
		add_child(stack)
		pallet(Vector3.ZERO, stack, 3 + i % 2)
		yard_pallets.append(stack)
	for i in 8:
		var stack := Node3D.new()
		stack.position = Vector3(3.72+(i%4)*1.03,0,-8.0-(i/4)*1.37)
		add_child(stack)
		pallet(Vector3.ZERO,stack,3 if i%3 == 0 else 4)
		outgoing_pallets.append(stack)
	outdoor()


func lamp(at: Vector3, color: String, energy: float, distance: float, shadows: bool = false) -> void:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = Color(color)
	light.light_energy = energy
	light.omni_range = distance
	light.omni_attenuation = 1.0
	light.shadow_enabled = shadows
	add_child(light)


func work_light(at: Vector3) -> void:
	var light := SpotLight3D.new()
	light.position = at
	light.rotation.x = -1.90
	light.light_color = Color("ffecd1")
	light.light_energy = .68
	light.spot_angle = 68.0
	light.spot_range = 2.3
	light.spot_angle_attenuation = .55
	add_child(light)


func drop_label_shavings(paper: Material, edge: Vector3, count: int, shape: Vector2) -> void:
	for i in count:
		var spread: float = (label_offcuts.size()+i)*2.39+edge.y*7.1
		var end := to_global(Vector3(STRIP_X-.15+sin(spread)*.109,COUNTER_TOP+.019,COUNTER_Z+.24+cos(spread)*.073))
		var size := Vector2(.014+absf(cos(spread))*.012,.011+absf(sin(spread))*.016)*shape
		var flake := mesh_at(Shapes.paper_chip(size),Vector3.ZERO,paper)
		flake.global_position = edge
		flake.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		label_offcuts.append(flake)
		if label_offcuts.size() > 24:
			var oldest: MeshInstance3D = label_offcuts.pop_front()
			oldest.queue_free()
		var falling := flake.create_tween()
		falling.tween_method(func(amount: float) -> void:
			flake.global_position = edge.lerp(end,amount)+Vector3(sin(spread)*.034,.021,.110)*sin(amount*PI)
			flake.rotation = Vector3(-PI*.5*amount,spread*amount,(1.0-amount)*spread),0.0,1.0,.28+i*.047)


func make_scraper(parent: Node3D, level: int = 0) -> Node3D:
	var scraper := Node3D.new()
	parent.add_child(scraper)
	var steel: Material = surface(["777367","b7c3c0","c4cbc1","afbdb8"][level],false,5 if level == 0 else 2)
	var handle: Material = material(["554435","386365","36584d","744a2e"][level],.76)
	var sleeve_color: Material = material(["655c4c","667a7a","738074","9c7b51"][level],.56,.27)
	scraper.set_meta("level",level)
	mesh_at(Shapes.scraper_blade([.80,.86,1.04,1.13][level],[0.0,0.0,.010,.013][level]),Vector3.ZERO,steel,scraper)
	rounded(Vector3(0,-.017,0),Vector3(.028,.088,.020),.009,handle,scraper)
	rounded(Vector3(0,.025,0),Vector3(.029,.016,.018),.004,sleeve_color,scraper)
	for y in [-.039,-.026,-.013,-.001]:
		rounded(Vector3(0,y,.008),Vector3(.023,.004,.008),.002,sleeve_color,scraper)
	if level == 0:
		for x in [-.012,.014]:
			var rivet := cylinder(Vector3(x,.052,.004),.0026,.002,sleeve_color,scraper)
			rivet.rotation.x = PI*.5
	elif level == 3:
		for x in [-.017,.017]:
			cylinder(Vector3(x,.040,.007),.0024,.032,steel,scraper)
			var helix := PackedVector3Array()
			for i in 27:
				var amount: float = i/26.0
				var angle: float = amount*TAU*4.0
				helix.append(Vector3(x+.005*cos(angle),.025+amount*.029,.007+.005*sin(angle)))
			mesh_at(Shapes.tube(helix,.0013),Vector3.ZERO,sleeve_color,scraper)
	return scraper


func show_table_scraper(level: int, shown: bool) -> void:
	if table_scraper_level != level:
		if is_instance_valid(table_scraper):
			table_scraper.hide()
			table_scraper.queue_free()
		table_scraper = make_scraper(self,level)
		table_scraper.position = Vector3(STRIP_X+.235,.958,COUNTER_Z+.180)
		table_scraper.basis = Basis(Vector3.UP,.34)*Basis(Vector3.RIGHT,-PI*.5)
		table_scraper_level = level
	table_scraper.visible = shown


func hazards(at: Vector3, width: float, count: int) -> void:
	for i in count:
		var stripe := box(at + Vector3(0, i * .20, 0), Vector3(width, .095, .014), material("2d3028"))
		stripe.rotation.z = -.40


func bench(at: Vector3, wood: Material, steel: Material) -> void:
	rounded(at+Vector3(0,.88,0),Vector3(2.94,.11,1.08),.008,wood,self,true)
	rounded(at+Vector3(-.15,.942,.12),Vector3(1.18,.015,.64),.005,surface("354b40",false,3))
	box(at + Vector3(0, .29, -.02), Vector3(2.73, .051, .87), steel)
	for x in [-1.34, 1.34]:
		for z in [-.45, .45]:
			box(at + Vector3(x, .43, z), Vector3(.085, .86, .08), steel, self, true)
		box(at + Vector3(x, .72, 0), Vector3(.073, .07, .91), steel)


func hand_line(wood: Material, steel: Material) -> void:
	var left_edge: float = RINSE_X-.255
	var right_edge: float = RINSE_X+.255
	var panels := [[-2.51,left_edge,-.66,COUNTER_FRONT],[right_edge,2.51,-.66,COUNTER_FRONT],
		[left_edge,right_edge,-.66,COUNTER_Z-.191],[left_edge,right_edge,COUNTER_Z+.192,COUNTER_FRONT]]
	for panel in panels:
		var center := Vector3((panel[0]+panel[1])*.5,COUNTER_TOP-.055,(panel[2]+panel[3])*.5)
		rounded(center,Vector3(panel[1]-panel[0],.11,panel[3]-panel[2]),.006,wood,self,true)
	box(Vector3(0,.775,COUNTER_FRONT-.045),Vector3(4.97,.096,.041),steel)
	for x in [-2.43,-1.67,-.674,-.009,.706,1.32,1.89,2.43]:
		for z in [-.60,.49]:
			box(Vector3(x,.414,z),Vector3(.059,.83,.064),steel,self,true)
	for z in [-.59,.47]:
		box(Vector3(0,.224,z),Vector3(4.90,.053,.056),steel)

	var plate: Material = material("303f37",.72)
	var tape: Material = material("b29459",.93)
	box(Vector3(0,.014,1.055),Vector3(4.78,.006,.014),tape)
	for i in STATIONS.size():
		var x: float = STATIONS[i][0]
		rounded(Vector3(x,.874,COUNTER_FRONT+.005),Vector3(.285,.084,.014),.004,plate)
		text_at(STATIONS[i][1],Vector3(x,.872,COUNTER_FRONT+.014),45,.00175,"e7ddbc")
		if i < STATIONS.size()-1:
			var midpoint: float = (x+float(STATIONS[i+1][0]))*.5
			for side in [-1,1]:
				var arrow := box(Vector3(midpoint-.032,.015,1.055+side*.030),Vector3(.089,.006,.015),tape)
				arrow.rotation.y = side*.70

	clean_box = finished_crate(CLEAN_CRATE,self)
	recycle_bin(SCRAP_BIN)
	strip_tools()
	bench_sink()
	bench_sanitation()
	kiosk(Vector3(TERMINAL_X,COUNTER_TOP,COUNTER_Z-.265))
	target("bench","手工脱标台",Vector3(STRIP_X,COUNTER_TOP+.06,.24),.47)
	target("clean_crate","成品筐",CLEAN_CRATE+Vector3.UP*.14,.26)


func bench_sink() -> void:
	var silver := surface("a2a8a2",false,2)
	var dark := material("243637")
	var at := Vector3(RINSE_X,0,COUNTER_Z)
	mesh_at(Shapes.sink(),at+Vector3.UP*COUNTER_TOP,silver)
	var drain := at+Vector3(.020,.825,-.039)
	cylinder(drain,.029,.005,silver)
	for i in 6:
		var angle: float = i*TAU/6.0
		cylinder(drain+Vector3(cos(angle)*.017,.0035,sin(angle)*.017),.0035,.0015,dark)
	cylinder(drain+Vector3.UP*.0035,.0033,.0016,dark)
	var overflow := rounded(at+Vector3(0,.896,-.153),Vector3(.049,.012,.005),.002,dark)
	overflow.rotation.x = -.4
	var faucet := PackedVector3Array([
		Vector3(.010,.947,-.251),Vector3(.010,1.059,-.251),Vector3(.010,1.207,-.251),
		Vector3(.010,1.259,-.229),Vector3(.010,1.275,-.178),
		Vector3(.010,1.251,-.114),Vector3(.010,1.218,-.091),
	])
	mesh_at(Shapes.tube(faucet,.0145),at,silver)
	cylinder(at+Vector3(.010,.946,-.251),.039,.014,silver)
	cylinder(FAUCET+Vector3.UP*.011,.018,.017,silver)
	cylinder(FAUCET+Vector3.UP*.002,.010,.004,dark)
	cylinder(at+Vector3(.085,1.0,-.251),.020,.105,silver)
	faucet_valve = rounded(FAUCET_VALVE,Vector3(.091,.012,.023),.005,silver)
	var drain_pipe := PackedVector3Array([
		Vector3(.020,.82,-.039),Vector3(.020,.50,-.039),Vector3(.020,.42,-.089),
		Vector3(.020,.40,-.189),Vector3(.020,.47,-.299),Vector3(.020,.48,-.629),
	])
	mesh_at(Shapes.tube(drain_pipe,.027),at,material("7b817c",.6,.08))
	cylinder(at+Vector3(.020,.786,-.039),.038,.047,material("737975",.6))


func strip_tools() -> void:
	var at := Vector3(STRIP_X,0,0)
	var mat_front := at+Vector3(0,0,COUNTER_Z)
	rounded(mat_front+Vector3.UP*.941,Vector3(.766,.014,.676),.005,surface("354b40",false,3))
	var shade: Material = surface("3a4640",false,5)
	for x in [-.37,.37]:
		box(at+Vector3(x,1.29,-.592),Vector3(.049,.73,.050),shade)
	var diffuser := material("c9c1a3",.57).duplicate() as StandardMaterial3D
	diffuser.emission_enabled = true
	diffuser.emission = Color("ffead0")
	diffuser.emission_energy_multiplier = .72
	rounded(at+Vector3(0,1.665,-.50),Vector3(.835,.057,.211),.010,shade)
	rounded(at+Vector3(0,1.632,-.479),Vector3(.744,.019,.163),.007,diffuser)
	work_light(at+Vector3(0,1.61,-.40))
	var fabric: Material = surface("b1a589",false,6)
	var cloth := rounded(mat_front+Vector3(-.250,.958,.142),Vector3(.147,.017,.142),.006,fabric)
	cloth.rotation.y = -.26
	var fold := rounded(mat_front+Vector3(-.265,.968,.181),Vector3(.117,.018,.065),.005,surface("a09576",false,6))
	fold.rotation.y = -.28
	show_table_scraper(0,true)
	var brush := cylinder(at+Vector3(-.158,.953,-.378),.012,.204,surface("926f46",true))
	brush.rotation.z = PI*.5
	rounded(at+Vector3(-.027,.953,-.378),Vector3(.081,.019,.041),.004,material("7b6547",.82))
	for i in 9:
		var density: Material = material(["b09763","a99060","cbb184"][i%3],.96)
		for j in 4:
			var bristle := cylinder(at+Vector3(-.061+i*.0085,.968,-.394+j*.0107),.0018,.013+float((i+j)%3)*.002,density)
			bristle.rotation.z = (j-1.5)*.11


func bench_sanitation() -> void:
	var steel: Material = surface("989e96",false,2)
	var gasket: Material = material("29312e",.83)
	var frame: Material = surface("596a61",false,5)
	var base: Vector3 = SANITIZER_TRAY-Vector3.UP*.990
	for dx in [-.225,.225]:
		rounded(base+Vector3(dx,1.15,0),Vector3(.055,.39,.45),.008,steel)
	rounded(base+Vector3(0,.977,0),Vector3(.50,.037,.45),.007,steel)
	rounded(base+Vector3(0,1.366,0),Vector3(.50,.067,.45),.008,frame)
	box(base+Vector3(0,1.153,-.223),Vector3(.44,.35,.027),gasket)
	for i in 8:
		box(base+Vector3(-.17+i*.049,.998,.008),Vector3(.008,.006,.34),steel)
	var fan_back := cylinder(base+Vector3(.100,1.213,-.203),.060,.017,frame)
	fan_back.rotation.x = PI*.5
	chamber_fan = Node3D.new()
	chamber_fan.position = base+Vector3(.100,1.213,-.188)
	add_child(chamber_fan)
	var hub := cylinder(Vector3.ZERO,.012,.016,steel,chamber_fan)
	hub.rotation.x = PI*.5
	for i in 5:
		var angle: float = i*TAU/5.0
		var blade := rounded(Vector3(sin(angle),cos(angle),0)*.031,Vector3(.018,.043,.008),.004,steel,chamber_fan)
		blade.rotation.z = -.26-angle
	for i in 5:
		var offset: float = (i-2)*.019
		var span: float = sqrt(.058*.058-offset*offset)*2.0
		rounded(base+Vector3(.100+offset,1.213,-.172),Vector3(.003,span,.005),.001,frame)
	for y in [-.043,.043]:
		rounded(base+Vector3(.100,1.213+y,-.172),Vector3(.076,.003,.005),.001,frame)
	for x in [-.142,.142]:
		var pipe := cylinder(base+Vector3(x,1.025,-.083),.008,.208,steel)
		pipe.rotation.x = PI*.5
		cylinder(base+Vector3(x,1.039,.006),.016,.022,steel)
	chamber_light = OmniLight3D.new()
	chamber_light.position = base+Vector3(0,1.298,.124)
	chamber_light.light_color = Color("f8dea8")
	chamber_light.omni_range = .46
	chamber_light.light_energy = .10
	add_child(chamber_light)
	steam_door = Node3D.new()
	steam_door.position = base+Vector3(.220,1.157,.227)
	steam_door.rotation.y = 1.72
	add_child(steam_door)
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(.39,.58,.54,.32)
	glass.roughness = .28
	for y in [-.17,.17]:
		rounded(Vector3(-.222,y,0),Vector3(.444,.034,.032),.004,steel,steam_door)
	for x in [-.424,-.013]:
		rounded(Vector3(x,0,0),Vector3(.032,.345,.032),.004,steel,steam_door)
	var pane := box(Vector3(-.222,0,.002),Vector3(.395,.315,.008),glass,steam_door)
	pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rounded(Vector3(-.401,.006,.032),Vector3(.026,.109,.032),.008,gasket,steam_door)
	for y in [-.108,.108]:
		cylinder(base+Vector3(.218,1.157+y,.247),.012,.048,steel)
	var plate := rounded(base+Vector3(-.104,1.367,.230),Vector3(.241,.043,.015),.005,gasket)
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	text_at("蒸汽消毒仓",base+Vector3(-.104,1.367,.241),36,.00095,"e6ddbe")
	rounded(base+Vector3(.132,1.369,.231),Vector3(.153,.044,.017),.005,gasket)
	steam_display = text_at("待机",base+Vector3(.112,1.369,.243),35,.00084,"c8dbc2")
	steam_lamp = StandardMaterial3D.new()
	steam_lamp.emission_enabled = true
	rounded(base+Vector3(.187,1.370,.245),Vector3(.017,.016,.009),.004,steam_lamp)
	steam_lamp.albedo_color = Color("779c6d")
	steam_lamp.emission = steam_lamp.albedo_color
	chamber_mist = Node3D.new()
	chamber_mist.position = base
	add_child(chamber_mist)
	var vapor := ShaderMaterial.new()
	vapor.shader = Steam
	var bubble := SphereMesh.new()
	bubble.radial_segments = 14
	bubble.rings = 7
	for i in 5:
		var mist := mesh_at(bubble,Vector3.ZERO,vapor,chamber_mist)
		mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chamber_mist.hide()
	var rack: Vector3 = DRAIN_PIN-Vector3.UP*.062
	rounded(rack,Vector3(.525,.030,.342),.006,gasket)
	for i in 5:
		var pin: Vector3 = rack+Vector3((i-2)*.105,.038,0)
		cylinder(pin,.005,.062,steel)
		var bar := cylinder(pin+Vector3(0,-.030,0),.0048,.267,steel)
		bar.rotation.x = PI*.5
	text_at("沥水架",rack+Vector3(0,.006,.175),44,.00142,"e1dbc2")


func wash_valve_tip() -> Vector3:
	return faucet_valve.to_global(Vector3(.037,.006,.002))


func animate_wash_area(flowing: bool, running: bool, progress: float, delta: float) -> void:
	faucet_valve.rotation.z = move_toward(faucet_valve.rotation.z,.31 if flowing else 0.0,delta*3.4)
	cabinet_closed = move_toward(cabinet_closed,1.0 if running else 0.0,delta*7.8)
	steam_door.rotation.y = (1.0-smoothstep(0.0,1.0,cabinet_closed))*1.72
	var state: String = "运行中" if running else "待机"
	if steam_display.text != state:
		steam_display.text = state
		steam_lamp.albedo_color = Color("d89647" if running else "779c6d")
		steam_lamp.emission = steam_lamp.albedo_color
	chamber_light.light_energy = move_toward(chamber_light.light_energy,.50 if running else .10,delta*2.6)
	if running:
		chamber_fan.rotation.z = fposmod(chamber_fan.rotation.z+delta*20.0,TAU)
	chamber_mist.visible = running and cabinet_closed > .91 and progress > .19
	if chamber_mist.visible:
		for i in chamber_mist.get_child_count():
			var phase: float = fposmod(progress*1.25+i*.195,1.0)
			var puff: Node3D = chamber_mist.get_child(i)
			var nozzle: float = -.142 if i%2 == 0 else .142
			puff.position = Vector3(nozzle*(1.0-phase*.69)+sin(phase*4.3+i)*.037,1.04+phase*.252,.015-phase*.085)
			puff.scale = Vector3(.060,.042,.052)*(.45+phase*1.32)


func crate(at: Vector3, color: String, parent: Node3D = self, dimensions: Vector3 = Vector3(.56, .26, .43)) -> Node3D:
	var base := Node3D.new()
	base.position = at
	parent.add_child(base)
	var m := material(color)
	box(Vector3(0, .015, 0), Vector3(dimensions.x, .03, dimensions.z), m, base)
	for z in [-dimensions.z * .5, dimensions.z * .5]:
		for y in [.048, dimensions.y * .65, dimensions.y - .018]:
			box(Vector3(0, y, z), Vector3(dimensions.x, .032, .024), m, base)
	for x in [-dimensions.x * .5, dimensions.x * .5]:
		box(Vector3(x, dimensions.y * .5, 0), Vector3(.021, dimensions.y, dimensions.z), m, base)
	for j in 5:
		for z in [-dimensions.z * .5, dimensions.z * .5]:
			box(Vector3(dimensions.x * (-.49 + j * .245), dimensions.y * .5, z),
				Vector3(.021, dimensions.y, .029), m, base)
	return base


func build_cart() -> void:
	cart = Node3D.new()
	cart.position = CART_HOME
	add_child(cart)
	var steel: Material = surface("56685e",false,5)
	var rubber: Material = material("282c28",.90)
	rounded(Vector3(0,.238,0),Vector3(.64,.07,.63),.014,steel,cart)
	cart_basket = crate(Vector3(0,.275,-.013),"806748",cart,Vector3(.57,.17,.49))
	for x in [-.28,.28]:
		box(Vector3(x,.518,.277),Vector3(.035,.52,.042),steel,cart).rotation.x = .16
		for z in [-.205,.211]:
			var wheel: MeshInstance3D = cylinder(Vector3(x,.103,z),.102,.052,rubber,cart)
			wheel.rotation.z = PI*.5
			cylinder(Vector3(x,.103,z),.050,.061,steel,cart).rotation.z = PI*.5
	rounded(Vector3(0,.779,.318),Vector3(.621,.046,.046),.016,rubber,cart)
	for i in Yard.CART_CAPACITY:
		var slot := Vector3((i%5-2)*.106,.031,(i/5-1.5)*.109)
		var bottle: MeshInstance3D = mesh_at(stock_meshes[0],slot,bottle_material(0),cart_basket)
		bottle.hide()
		cart_bottles.append(bottle)
	cart_crate_deck = rounded(Vector3.ZERO,Vector3(1.12,.042,.57),.01,steel,cart)
	cart_crate_posts = Node3D.new()
	cart.add_child(cart_crate_posts)
	for x in [-.307,.307]:
		for z in [-.244,.244]:
			box(Vector3(x,.432,z),Vector3(.033,.32,.032),steel,cart_crate_posts)
	cart_crate_rack = Node3D.new()
	cart.add_child(cart_crate_rack)
	rounded(Vector3(0,.364,0),Vector3(.55,.032,.56),.008,steel,cart_crate_rack)
	for x in [-.257,.257]:
		for z in [-.263,.263]:
			box(Vector3(x,.181,z),Vector3(.026,.362,.026),steel,cart_crate_rack)
	for i in Yard.CART_CRATE_LIMIT:
		cart_boxes.append(finished_crate(Vector3.ZERO,cart))
	cart.hide()


func update_cart(model, worker: CharacterBody3D, working: bool) -> void:
	cart.visible = model.cart_unlocked()
	if not cart.visible:
		targets.erase("cart")
		return
	if model.pushing_cart:
		targets.erase("cart")
		if not working:
			var center: Vector3 = worker.position+Vector3.UP*.39
			var forward: Vector3 = -worker.global_basis.z
			var query := PhysicsRayQueryParameters3D.create(center,center+forward*1.12,1,[worker.get_rid()])
			var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
			var distance: float = .84 if hit.is_empty() else maxf(.29,center.distance_to(hit.position)-.30)
			cart.position = Vector3(center.x,.014,center.z)+forward*distance
			cart.rotation.y = worker.rotation.y
	else:
		if model.parked_at.is_finite():
			cart.position = model.parked_at
			cart.rotation.y = model.parked_angle
		if not targets.has("cart"):
			target("cart","小推车",cart.position+Vector3.UP*.42,.40,1.85)
	var cargo: Array[Vector2i] = model.carried if model.pushing_cart else model.parked_load
	var count: int = model.cart_crates.size()
	cart_basket.visible = count == 0 or not cargo.is_empty()
	var deck_y: float = .61 if not cargo.is_empty() else .275
	cart_crate_deck.visible = count > 0
	cart_crate_posts.visible = count > 0 and not cargo.is_empty()
	cart_crate_deck.position = Vector3(0,deck_y-.021,-.025)
	cart_crate_rack.visible = count == Yard.CART_CRATE_LIMIT
	cart_crate_rack.position = Vector3(-.278,deck_y,-.025)
	for i in cart_boxes.size():
		var loaded: bool = i < count
		var cargo_box: FinishedCrate = cart_boxes[i]
		cargo_box.visible = loaded
		if loaded:
			cargo_box.sync(model.cart_crates[i],model.crate_capacity())
			cargo_box.position = Vector3(-.278 if i != 1 else .278,deck_y+(.38 if i == 2 else 0.0),-.025)
	for index in cart_bottles.size():
		var bottle: MeshInstance3D = cart_bottles[index]
		bottle.visible = index < cargo.size()
		if bottle.visible:
			var kind: int = model.kind(cargo[index].x)
			if bottle.mesh != stock_meshes[kind]:
				bottle.mesh = stock_meshes[kind]
				bottle.material_override = bottle_material(kind)


func bottle_material(kind: int) -> Material:
	return material(["395139","89a8a4","848f88","5b4025","557e65","5c5e3b"][kind],.20,.11)


func tiny_bottle(parent: Node3D, at: Vector3, kind: int) -> MeshInstance3D:
	mesh_at(stock_meshes[kind],at,bottle_material(kind),parent)
	var top: Array = Yard.BOTTLE_PROFILES[kind].back()
	cylinder(at+Vector3(0,top[0]-.010,0),float(top[1])*.89,.007,material("26352b",.64),parent)
	var paper: MeshInstance3D = mesh_at(stock_labels[kind],at,material(Yard.LABEL[kind],.85),parent)
	if kind == 5:
		cylinder(at+Vector3(0,top[0]+.008,0),.023,.013,material("c8c0a8",.37),parent)
	return paper


func fill_crate_samples(parent: Node3D) -> Array[MeshInstance3D]:
	var slots: Array[MeshInstance3D] = []
	for i in 6:
		var at := Vector3(-.142+float(i%3)*.142,.030,-.071+float(i/3)*.142)
		var item := mesh_at(stock_meshes[0],at,bottle_material(0),parent)
		item.hide()
		slots.append(item)
	return slots


func build_bottle_body(kind: int, glass: Material, root: Node3D) -> void:
	var profile: Array = Yard.BOTTLE_PROFILES[kind]
	var rim: Array = profile.back()
	mesh_at(bottle_bodies[kind],Vector3.ZERO,glass,root)
	mesh_at(bottle_rims[kind],Vector3.ZERO,material(Yard.GLASS[kind],.17,.13),root)
	cylinder(Vector3(0,rim[0]-.034,0),rim[1]*.71,.0035,material("22281b",.47,.05),root)
	cylinder(Vector3(0,.005,0),float(profile[0][1])*.93,.008,glass,root)


func build_finished_bottle(kind: int, root: Node3D) -> void:
	build_bottle_body(kind,finished_glass[kind],root)
	if kind == 4:
		build_bottle_marble(root,finished_glass[kind])
	elif kind == 5:
		var closure := Node3D.new()
		root.add_child(closure)
		build_bottle_closure(closure,root,material("b36e51",.68))


func bottle_detail(at: Vector3, dimensions: Vector3, finish: Material, parent: Node3D) -> MeshInstance3D:
	var part := mesh_at(bottle_detail_mesh,at,finish,parent)
	part.scale = dimensions
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return part


func build_bottle_marble(root: Node3D, glass: Material) -> MeshInstance3D:
	var bead := bottle_detail(Vector3(0,.214,.025),Vector3.ONE*.014,material("c3ceae",.15,.3),root)
	for z in [-.023,.023]:
		bottle_detail(Vector3(0,.208,z),Vector3(.036,.006,.005),glass,root)
	return bead


func build_bottle_closure(closure: Node3D, root: Node3D, seal: Material) -> MeshInstance3D:
	var top: float = Yard.BOTTLE_PROFILES[5].back()[0]
	closure.position = Vector3(0,top,-.017)
	cylinder(Vector3(0,.012,.017),.030,.015,material("d0c5a9",.38),closure)
	var gasket := cylinder(Vector3(0,.003,.017),.023,.007,seal,closure)
	var wire: Material = material("a8b2aa",.26,.7)
	for x in [-.026,.026]:
		var from := Vector3(x,.009,.01)
		var to := Vector3(x,-.047,.032)
		var arm := bottle_detail((from+to)*.5,Vector3(.0025,from.distance_to(to)*.5+.000675,.00205),wire,closure)
		arm.quaternion = Quaternion(Vector3.UP,(to-from).normalized())
		bottle_detail(Vector3(x,top-.041,.033),Vector3(.007,.006,.004),wire,root)
	box(Vector3(0,-.038,.046),Vector3(.049,.013,.009),wire,closure)
	return gasket


func finished_crate(at: Vector3, parent: Node3D) -> FinishedCrate:
	var result := FinishedCrate.new()
	result.position = at
	parent.add_child(result)
	result.build(self)
	return result


func build_sale_window() -> void:
	var booth := Node3D.new()
	booth.position = SALE_BOOTH
	booth.rotation.y = PI
	add_child(booth)
	var plaster: Material = surface("a5a391")
	var trim: Material = surface("3c544c",false,5)
	var counter: Material = surface("96744e",true)
	box(Vector3(0,.52,.02),Vector3(1.88,1.04,.18),plaster,booth,true)
	box(Vector3(0,1.18,-.94),Vector3(1.89,2.36,.14),plaster,booth,true)
	for x in [-.95,.95]:
		box(Vector3(x,1.18,-.46),Vector3(.14,2.36,1.09),plaster,booth,true)
		box(Vector3(x,1.57,.065),Vector3(.09,.95,.13),trim,booth)
	rounded(Vector3(0,1.059,.062),Vector3(2.03,.084,.67),.012,counter,booth,true)
	box(Vector3(0,2.17,.018),Vector3(2.05,.33,.162),trim,booth,true)
	box(Vector3(0,2.37,-.35),Vector3(2.24,.13,1.57),trim,booth,true)
	text_at("成品收购窗口",Vector3(0,2.17,.110),67,.0045,"eee4c6",booth)
	box(Vector3(-.51,1.151,.13),Vector3(.59,.105,.40),trim,booth)
	rounded(Vector3(-.51,1.21,.13),Vector3(.59,.026,.40),.006,material("9aa99c",.4,.34),booth)
	box(Vector3(.45,1.43,-.833),Vector3(.66,.29,.051),trim,booth)
	window_count = text_at("",Vector3(.45,1.43,-.798),48,.0027,"e9dfbb",booth)
	var warm := material("e1d3a7")
	box(Vector3(0,1.982,-.29),Vector3(.88,.039,.11),warm,booth)
	lamp(booth.to_global(Vector3(0,1.93,-.26)),"ffe9bd",.74,3.1)
	for x in [-.86,.86]:
		box(booth.to_global(Vector3(x,.012,1.04)),Vector3(.045,.01,.88),material("b99456"))
	target("sale_window","成品收购窗口",booth.to_global(Vector3(0,1.49,.20)),.56,2.55)


func recycle_bin(at: Vector3) -> void:
	var shell: Material = surface("424b43",false,5)
	var profile: Array = [
		[.012,.200],[.016,.212],[.027,.218],[.313,.233],[.346,.237],[.353,.248],
		[.363,.249],[.368,.235],[.362,.224],[.339,.225],[.292,.215],[.041,.204],
	]
	mesh_at(Shapes.lathe(profile,42),at,shell)
	cylinder(at+Vector3.UP*.033,.205,.009,material("26312c",.88))
	var rim := material("687067",.50,.13)
	for x in [-.227,.227]:
		rounded(at+Vector3(x,.291,0),Vector3(.048,.034,.137),.011,rim)
	rounded(at+Vector3(0,.196,.228),Vector3(.266,.103,.008),.003,material("b1a995",.85))
	text_at("碎玻璃",at+Vector3(0,.201,.233),48,.0016,"3e483d")


func shelf(at: Vector3) -> void:
	var frame := material("465b50")
	for x in [-1.45, 1.45]:
		for z in [-.46, .46]:
			box(at + Vector3(x, 1.25, z), Vector3(.075, 2.50, .075), frame)
	for level in 3:
		var y: float = .3 + level * .83
		box(at + Vector3(0, y, 0), Vector3(2.95, .085, .98), frame, self, true)
		for i in 4:
			crate(at + Vector3(-.99 + i * .66, y + .047, .11), ["887342", "4b5c4e", "6c7549"][i % 3])
	text_at("周 转 筐", at + Vector3(0, 2.62, .50), 48, .004, "d0c6a5")


func kiosk(at: Vector3) -> void:
	var frame := material("435851")
	box(at+Vector3(0,.014,0),Vector3(.244,.028,.135),frame)
	box(at+Vector3(0,.176,0),Vector3(.062,.34,.054),frame)
	var screen := rounded(at+Vector3(0,.424,0),Vector3(.477,.286,.052),.009,material("1c2c2a"))
	box(at+Vector3(0,.424,.030),Vector3(.416,.230,.011),material("5b9677"))
	text_at("站务终端",at+Vector3(0,.458,.038),50,.0018,"e3e6ba")
	text_at("采购 · 到货",at+Vector3(0,.376,.039),46,.0010,"e3e6ba")
	screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	target("office","站务终端",at+Vector3(0,.427,.051),.156,3.0)


func conveyor(at: Vector3, length: float, index: int) -> void:
	var group := Node3D.new()
	group.position = at
	add_child(group)
	conveyors.append(group)
	var base := material("43524d")
	box(Vector3.ZERO, Vector3(length,.13,.76), base, group)
	for z in [-.36,.36]:
		box(Vector3(0,.092,z), Vector3(length,.049,.035), material("968962"), group)
	for j in int(length * 9):
		var roller := cylinder(Vector3(-length / 2.0 + (j + .5) / 9.0, .105, 0), .039, .64,
			material("71817a", .38, .33), group)
		roller.rotation.x = PI / 2.0
	for x in [-length*.3,length*.3]:
		for z in [-.28,.28]:
			box(Vector3(x,-.42,z), Vector3(.052,.82,.055), base, group)
	for j in 3:
		var bottle := Node3D.new()
		add_child(bottle)
		bottle.hide()
		var kind: int = (index+j)%Yard.NAMES.size()
		glass_on_line.append(bottle)
		var label := tiny_bottle(bottle,Vector3.ZERO,kind)
		var coating := ShaderMaterial.new()
		coating.shader = Paper
		coating.set_shader_parameter("paper",Color(Yard.LABEL[kind]))
		coating.set_shader_parameter("ink",Color(Yard.LABEL[kind]).darkened(.25))
		coating.set_shader_parameter("sleeve",kind == 1)
		label.material_override = coating
		line_labels.append(label)
		line_bottle_heights.append(Yard.BOTTLE_PROFILES[kind].back()[0]*.5)


func pallet(at: Vector3, parent: Node3D, tiers: int) -> void:
	var wood := material("8a6e4a")
	for i in 5:
		box(at + Vector3(-.36 + i * .18, .10, 0), Vector3(.135, .064, .95), wood, parent)
	for z in [-.35, 0, .35]:
		box(at + Vector3(0, .045, z), Vector3(.91, .065, .09), wood, parent)
	for i in tiers:
		for z in [-.22, .22]:
			# Closed crates keep hundreds of visible pallets affordable.
			var crate_at: Vector3 = at + Vector3(0,.23 + i*.24,z)
			box(crate_at, Vector3(.86,.22,.41), material(["8f754b","676f4b","526854"][i%3]),parent)
			box(crate_at + Vector3(0,.072,.211), Vector3(.76,.024,.015), wood,parent)


func outdoor() -> void:
	var brick := material("746d5d")
	var dark := material("333d39")
	var veget := material("5b6d56")
	for i in 13:
		var x: float = -24 + i * 4.0
		box(Vector3(x,1.78,-36.4), Vector3(3.7, 3.55,4.2), brick)
		box(Vector3(x,.6,-34.24), Vector3(3.55, 1.2,.12), dark)
		box(Vector3(x,3.63,-36.4), Vector3(3.95,.15,4.55), dark)
		if i % 2 == 0:
			box(Vector3(x,3.8,-38.2), Vector3(2.2,1.7,1.6), veget)
	for sign_x in [-1.0, 1.0]:
		for i in 14:
			box(Vector3(sign_x * 18,.58,-13.6-i*1.6),Vector3(.1,1.2,.08),dark)
		box(Vector3(sign_x * 18,.91,-24),Vector3(.043,.06,22),dark)
		box(Vector3(sign_x * 18,.37,-24),Vector3(.043,.06,22),dark)
		box(Vector3(sign_x * 6,.006,-20),Vector3(.065,.012,11),material("bf985c"))
	for i in 8:
		box(Vector3(-4.2 + i * 1.2,.008,-17),Vector3(.66,.013,.083),material("c29a5d"))
	inbound_truck = Node3D.new()
	add_child(inbound_truck)
	var mint := material("7f9c89")
	var truck_dark := material("293632")
	var trailer := material("a2a190")
	box(Vector3(-.56,1.80,0),Vector3(7.8,2.34,2.55),trailer,inbound_truck)
	box(Vector3(-.56,.56,0),Vector3(7.86,.18,2.54),truck_dark,inbound_truck)
	box(Vector3(4.19,1.33,0),Vector3(1.68,1.61,2.43),mint,inbound_truck)
	box(Vector3(4.62,1.73,0),Vector3(.86,.58,2.455),material("495b64",.22,.2),inbound_truck)
	box(Vector3(4.91,1.78,0),Vector3(.17,.50,2.13),material("556c75",.21,.2),inbound_truck)
	box(Vector3(5.02,.91,0),Vector3(.24,.27,2.51),truck_dark,inbound_truck)
	for i in 4:
		for z in [-1.23,1.23]:
			var wheel := cylinder(Vector3([-3.64,-2.58,3.1,4.35][i],.44,z),.44,.28,truck_dark,inbound_truck)
			wheel.rotation.x = PI / 2.0
			var hub := cylinder(Vector3(wheel.position.x,.44,z + sign(z)*.145),.225,.04,trailer,inbound_truck)
			hub.rotation.x = PI / 2.0
	for i in 11:
		box(Vector3(-4.33 + i * .72, 1.78, 1.281),Vector3(.027,2.16,.031),trailer,inbound_truck)
	box(Vector3(-.56,1.78,1.294),Vector3(5.3,.83,.021),material("4c655a"),inbound_truck)
	text_at("旧 玻 璃 回 收",Vector3(-.55,1.80,1.325),68,.009,"e5dec7",inbound_truck)
	inbound_truck.position = Vector3(21,0,-17.7)
	inbound_truck.visible = false
	for i in 3:
		var truck: Node3D = inbound_truck.duplicate()
		add_child(truck)
		truck.position = Vector3(-11.6+i*11.6,0,-23.4-i*3.2)
		queued_trucks.append(truck)
	text_at("卸货区",Vector3(-6.7,2.2,-14.0),58,.007,"edc78e").rotation.y = PI


func animate_line(model, delta: float) -> void:
	var moving: bool = false
	for i in machines.size():
		moving = machines[i].update_work(model.installed[i],model.machine_work[i],delta) or moving
	var belt_visible: bool = model.installed[0] and model.phase >= 1
	for conveyor_part in conveyors:
		conveyor_part.visible = belt_visible
	var speed: float = 1.18 if model.rush > 1 else .79
	var length: float = AUTOMATION_SPACING*AUTOMATION_ORDER.size()
	if moving and belt_visible:
		line_phase = fposmod(line_phase+delta*speed,length)
	machine_offsets.fill(INF)
	for i in glass_on_line.size():
		var bottle: Node3D = glass_on_line[i]
		var distance: float = fposmod(line_phase+float(i)*length/glass_on_line.size(),length)
		var column: int = int(distance/AUTOMATION_SPACING)
		var index: int = AUTOMATION_ORDER[column]
		var machine: LineMachine = machines[index]
		var x: float = distance-(column+.5)*AUTOMATION_SPACING
		var packed: bool = machines[Yard.PACKER].visible and (index == 6 or (index == Yard.PACKER and x > .33))
		bottle.visible = moving and belt_visible and machine.visible and not packed
		if moving and machine.visible and absf(x) < absf(machine_offsets[index]):
			machine_offsets[index] = x
		if not bottle.visible:
			continue
		bottle.position = Vector3(machine.position.x+x,LineMachine.DECK,AUTOMATION_Z)
		bottle.rotation.z = 0.0
		var from_scraper: float = bottle.position.x-machines[0].position.x
		line_labels[i].visible = from_scraper < .34
		if line_labels[i].visible:
			line_labels[i].material_override.set_shader_parameter("scraped",smoothstep(.10,.34,from_scraper))
		machine.update_bottle(bottle,x,line_bottle_heights[i])
	var carton_start: float = machines[Yard.PACKER].position.x+.62
	var carton_run: float = machines[6].position.x+AUTOMATION_SPACING*.5-carton_start
	for i in outbound_cartons.size():
		var carton: Node3D = outbound_cartons[i]
		carton.visible = belt_visible and (machines[Yard.PACKER].active or machines[6].active) and (i == 0 or machines[6].visible)
		if carton.visible:
			var length_out: float = carton_run if machines[6].visible else AUTOMATION_SPACING*.5-.72
			var along: float = fposmod(line_phase+i*.5*length_out,length_out)
			carton.position = Vector3(carton_start+along,LineMachine.DECK,AUTOMATION_Z)
	for i in machines.size():
		machines[i].animate(delta,machine_offsets[i],speed/.79)


func update_site(model, delta: float) -> void:
	animate_line(model,delta)
	clean_box.sync(model.bench_crate,model.crate_capacity())
	targets.clean_crate.position.z = CLEAN_CRATE.z+clean_box.dimensions.z*.5
	window_count.text = "待售  %d 只" % model.sum_queue(Yard.FOR_SALE)
	garage.sync(model)
	for i in yard_pallets.size():
		yard_pallets[i].visible = model.phase >= 2 and i < ceili(float(model.in_yard())/Yard.PALLET_SIZE)
	for i in outgoing_pallets.size():
		outgoing_pallets[i].visible = model.phase >= 3 and i < model.delivered/Yard.PALLET_SIZE
	for i in queued_trucks.size():
		queued_trucks[i].visible = model.day_active and model.trucks >= (i + 1) * 4
	if model.phase >= 3 and (model.in_yard() > 0 or model.trucks > truck_count):
		inbound_truck.visible = true
		truck_timer = 4.0
		truck_count = model.trucks
	else:
		truck_timer -= delta
	var goal: float = .0 if truck_timer > 0.0 else -21.0
	truck_position = move_toward(truck_position, goal, delta * 4.8)
	if truck_timer <= 0.0 and truck_position <= -20.9:
		inbound_truck.visible = false
		truck_position = 21.0
	inbound_truck.position.x = truck_position
