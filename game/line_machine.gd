extends Node3D

const Yard = preload("res://yard.gd")
const Steam = preload("res://steam.gdshader")
const Shapes = preload("res://workshop_shapes.gd")
const DECK = .984
const FINISH_TIME = 1.08
const WIDTHS = [1.44,2.14,1.35,1.88,1.88,1.68,1.89,1.96]
const HEIGHTS = [1.76,1.88,1.66,1.63,2.06,1.86,2.33,1.86]
const PAINT = ["647568","4c6272","414c50","475e64","b17c39","4f727a","ab7d3b","858475"]
const PLATES = [Vector3(-.10,.847,.455),Vector3(-.20,1.641,.410),Vector3(-.155,1.544,.375),
	Vector3(0,.849,.486),Vector3(0,1.900,.234),Vector3(0,1.666,.190),
	Vector3(0,2.164,-.093),Vector3(0,1.657,.382)]

var site
var kind: int
var collision_body: StaticBody3D
var indicator: StandardMaterial3D
var actuator: Node3D
var rotors: Array[Node3D] = []
var effects: Array[MeshInstance3D] = []
var carrier: Node3D
var crate_stock: Array[MeshInstance3D] = []
var work_light: OmniLight3D
var cradle: Node3D
var jaws: Array[Node3D] = []
var trolley: Node3D
var drive_wheel: Node3D
var label_blade: Node3D
var pressure_needle: Node3D
var steel: Material
var paint: Material
var frame: Material
var dark: Material
var clear_guard: StandardMaterial3D
var last_work: int = 0
var finishing: float = 0.0
var active: bool = false
var clock: float = 0.0


func build(index: int, owner_site: Node3D) -> void:
	site = owner_site
	kind = index
	name = Yard.EQUIPMENT[index]
	var width: float = WIDTHS[index]
	var height: float = HEIGHTS[index]
	paint = site.material(PAINT[index],.56,.18)
	steel = site.surface("b7c0bb",false,2)
	frame = site.material("57605d",.48,.43)
	dark = site.material("293231",.82)
	clear_guard = StandardMaterial3D.new()
	clear_guard.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	clear_guard.cull_mode = BaseMaterial3D.CULL_DISABLED
	clear_guard.roughness = .20
	clear_guard.albedo_color = Color(.57,.68,.64,.058)
	build_chassis()
	controls(PLATES[index])
	work_light = OmniLight3D.new()
	work_light.position = Vector3(.09,1.56,.26)
	work_light.omni_range = 1.25
	work_light.light_energy = .38
	work_light.light_color = Color("f6e5c8")
	add_child(work_light)
	build_mechanism()
	collision_body = StaticBody3D.new()
	collision_body.position = Vector3(0,height*.5,0)
	collision_body.collision_layer = 0
	add_child(collision_body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width,height,1.02)
	collision.shape = shape
	collision_body.add_child(collision)
	hide()


func add_pivot(at: Vector3, parent: Node3D) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = at
	parent.add_child(pivot)
	return pivot


func controls(at: Vector3) -> void:
	var length: float = .59 if kind == 6 else .46
	site.rounded(at,Vector3(length,.080,.021),.005,dark,self)
	site.text_at(Yard.EQUIPMENT[kind],at+Vector3(0,0,.013),46,.00122,"e7dfc6",self)
	var panel: Vector3 = at+Vector3(length*.5+.115,0,.006)
	site.rounded(panel,Vector3(.136,.074,.039),.007,frame,self)
	face_disk(panel+Vector3(.036,0,.026),.020,.015,site.material("934b3f",.60),self)
	indicator = StandardMaterial3D.new()
	indicator.emission_enabled = true
	set_indicator(false)
	face_disk(panel+Vector3(-.034,0,.026),.013,.016,indicator,self)


func face_disk(at: Vector3, radius: float, depth: float, material: Material, parent: Node3D) -> MeshInstance3D:
	var disk: MeshInstance3D = site.cylinder(at,radius,depth,material,parent)
	disk.rotation.x = PI*.5
	return disk


func stand(half_width: float, front: float, back: float) -> void:
	for x in [-half_width,half_width]:
		for z in [front,back]:
			site.rounded(Vector3(x,.036,z),Vector3(.16,.026,.142),.006,dark,self)
			site.cylinder(Vector3(x,.086,z),.023,.102,steel,self)
			site.box(Vector3(x,.475,z),Vector3(.074,.754,.074),frame,self)
			site.box(Vector3(x,.817,z),Vector3(.15,.061,.15),paint,self)
		for x_off in [-.023,.023]:
			face_disk(Vector3(x+x_off,.813,front+.080),.010,.009,steel,self)
	for z in [front,back]:
		site.box(Vector3(0,.226,z),Vector3(half_width*2,.054,.055),frame,self)
		site.box(Vector3(0,.856,z),Vector3(half_width*2+.11,.105,.092),paint,self)


func rail(a: Vector3, b: Vector3, section: float, material: Material) -> void:
	var bar: MeshInstance3D = site.box((a+b)*.5,Vector3(section,a.distance_to(b),section),material,self)
	bar.quaternion = Quaternion(Vector3.UP,(b-a).normalized())


func window(at: Vector3, width: float, height: float, trim: Material) -> void:
	var pane: MeshInstance3D = site.box(at,Vector3(width,height,.008),clear_guard,self)
	pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for x in [-width*.5,width*.5]:
		site.box(at+Vector3(x,0,0),Vector3(.024,height+.024,.031),trim,self)
	for y in [-height*.5,height*.5]:
		site.box(at+Vector3(0,y,0),Vector3(width,.025,.028),trim,self)


func motor(at: Vector3, axis: Vector3, length: float, radius: float) -> void:
	var body := add_pivot(at,self)
	body.quaternion = Quaternion(Vector3.UP,axis)
	site.cylinder(Vector3.ZERO,radius,length,frame,body)
	for side in [-1,1]:
		site.cylinder(Vector3.UP*side*length*.44,radius*1.14,.024,paint,body)
	for i in 12:
		var angle: float = i*TAU/12.0
		var fin: MeshInstance3D = site.box(Vector3(sin(angle),0,cos(angle))*radius,
			Vector3(.010,length*.74,.021),frame,body)
		fin.rotation.y = angle
	site.cylinder(Vector3.DOWN*(length*.5+.032),radius*.34,.063,steel,body)
	site.rounded(Vector3(0,.021,radius+.012),Vector3(radius*.97,.078,.042),.005,paint,body)
	for offset in [-.026,.026]:
		site.box(Vector3(radius*.69,offset,-radius*.65),Vector3(.037,.022,.053),steel,body)


func build_chassis() -> void:
	match kind:
		0: stripper_frame()
		1: wash_tunnel()
		2: sorter_bridge()
		3: tilt_frame()
		4: packing_gantry()
		5: service_washer()
		6: pallet_lift()
		Yard.SANITIZER: steam_tunnel()


func stripper_frame() -> void:
	stand(.61,.397,-.407)
	for x in [-.37,.37]:
		site.rounded(Vector3(x,1.199,-.286),Vector3(.103,.714,.157),.013,paint,self)
		rail(Vector3(x,.872,-.355),Vector3(x,1.222,-.186),.048,frame)
		site.box(Vector3(x,1.488,-.179),Vector3(.153,.091,.26),frame,self)
	var casing: Material = site.material("b79b62",.62,.20)
	site.rounded(Vector3(-.012,1.534,-.025),Vector3(.703,.143,.477),.046,casing,self)
	for x in [-.261,.247]:
		for z in [-.173,.156]:
			site.cylinder(Vector3(x,1.609,z),.012,.012,steel,self)
	motor(Vector3(.47,1.545,-.163),Vector3.RIGHT,.261,.092)
	site.rounded(Vector3(.269,1.541,-.163),Vector3(.118,.202,.192),.024,paint,self)
	window(Vector3(.024,1.227,.322),.68,.351,frame)
	for x in [-.317,.367]:
		var cheek: MeshInstance3D = site.box(Vector3(x,1.227,.245),Vector3(.010,.352,.155),clear_guard,self)
		cheek.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var chute: MeshInstance3D = site.rounded(Vector3(.456,1.001,.271),Vector3(.258,.031,.368),.008,steel,self)
	chute.rotation.x = -.22
	site.rounded(Vector3(.454,.741,.273),Vector3(.360,.175,.396),.017,paint,self)
	site.box(Vector3(.454,.758,.478),Vector3(.124,.025,.049),dark,self)


func wash_tunnel() -> void:
	stand(.93,.373,-.431)
	site.rounded(Vector3(-.283,.564,.009),Vector3(1.315,.533,.802),.025,steel,self)
	site.rounded(Vector3(-.302,.580,.424),Vector3(1.194,.420,.026),.010,paint,self)
	for side in [-1,1]:
		face_disk(Vector3(-.308+side*.494,.608,.446),.017,.011,steel,self)
	site.rounded(Vector3(0,1.616,-.049),Vector3(2.02,.241,.887),.064,steel,self)
	site.rounded(Vector3(0,1.737,-.125),Vector3(1.93,.159,.765),.065,steel,self)
	site.rounded(Vector3(0,1.292,-.450),Vector3(1.98,.629,.074),.010,steel,self)
	site.rounded(Vector3(0,1.038,.397),Vector3(1.98,.119,.089),.013,steel,self)
	for x in [-.939,.939]:
		site.rounded(Vector3(x,1.313,.397),Vector3(.119,.613,.082),.012,steel,self)
		site.box(Vector3(x,1.457,0),Vector3(.083,.086,.714),frame,self)
		for i in 7:
			site.box(Vector3(x,1.397,-.244+i*.082),Vector3(.038,.096,.072),dark,self)
	window(Vector3(-.074,1.302,.420),1.58,.410,dark)
	for x in [-.862,.709]:
		face_disk(Vector3(x,1.486,.441),.012,.012,steel,self)
		face_disk(Vector3(x,1.100,.441),.012,.012,steel,self)
	motor(Vector3(.629,.547,.123),Vector3.RIGHT,.295,.105)
	site.rounded(Vector3(.874,.548,.127),Vector3(.202,.256,.269),.067,paint,self)
	var plumbing := PackedVector3Array([Vector3(.875,.548,.256),Vector3(.875,.548,.387),
		Vector3(.944,.598,.462),Vector3(1.014,.674,.462),Vector3(1.014,1.549,.462),
		Vector3(.952,1.661,.442),Vector3(.865,1.691,.320),Vector3(.865,1.691,.187)])
	site.mesh_at(Shapes.tube(plumbing,.030),Vector3.ZERO,steel,self)
	for y in [.694,1.067,1.441]:
		site.cylinder(Vector3(1.014,y,.462),.047,.030,frame,self)
	var gauge := Vector3(.783,1.595,.478)
	var branch := PackedVector3Array([Vector3(.783,1.550,.465),Vector3(.783,1.506,.465),
		Vector3(.806,1.478,.462),Vector3(1.015,1.478,.462)])
	site.mesh_at(Shapes.tube(branch,.012),Vector3.ZERO,steel,self)
	face_disk(gauge,.058,.031,dark,self)
	face_disk(gauge+Vector3.BACK*.018,.048,.013,site.material("e0d8bd",.64),self)
	pressure_needle = add_pivot(gauge+Vector3(0,0,.027),self)
	site.box(Vector3(0,.018,0),Vector3(.006,.041,.003),site.material("9a4d42",.62),pressure_needle)
	for i in 5:
		var angle: float = -1.2+i*.60
		var tick: MeshInstance3D = site.box(gauge+Vector3(sin(angle)*.037,cos(angle)*.037,.029),Vector3(.004,.010,.003),dark,self)
		tick.rotation.z = -angle


func sorter_bridge() -> void:
	stand(.53,.347,-.348)
	for z in [-.338,.320]:
		site.box(Vector3(-.202,1.225,z),Vector3(.142,.606,.099),paint,self)
		rail(Vector3(.413,.863,z),Vector3(-.198,1.185,z),.042,frame)
	site.rounded(Vector3(-.071,1.544,.003),Vector3(.856,.138,.714),.024,paint,self)
	window(Vector3(-.195,1.198,.372),.287,.283,frame)
	site.rounded(Vector3(-.401,.564,-.048),Vector3(.367,.481,.479),.016,paint,self)
	for y in [.514,.540,.566,.592]:
		site.box(Vector3(-.400,y,.200),Vector3(.251,.010,.012),dark,self)
	var reject: MeshInstance3D = site.rounded(Vector3(.398,.972,-.338),Vector3(.292,.052,.426),.010,steel,self)
	reject.rotation.x = -.27
	for x in [.25,.545]:
		site.box(Vector3(x,1.010,-.342),Vector3(.022,.061,.420),steel,self)


func tilt_frame() -> void:
	stand(.807,.428,-.362)
	for x in [-.62,.62]:
		site.rounded(Vector3(x,1.119,-.208),Vector3(.154,.523,.223),.018,paint,self)
		site.rounded(Vector3(x,1.186,-.143),Vector3(.193,.221,.194),.038,steel,self)
		site.rounded(Vector3(x,.946,-.123),Vector3(.331,.077,.457),.011,frame,self)
	var shield := Vector3(0,1.187,.414)
	window(shield,1.13,.296,frame)
	for x in [-.585,.585]:
		rail(Vector3(x,.859,.430),Vector3(x,1.307,.419),.047,paint)
	site.rounded(Vector3(0,.924,-.102),Vector3(1.518,.060,.771),.016,steel,self)
	motor(Vector3(.750,1.255,-.278),Vector3.UP,.171,.084)
	drive_wheel = add_pivot(Vector3(.646,1.187,.009),self)
	face_disk(Vector3.ZERO,.122,.035,paint,drive_wheel)
	face_disk(Vector3(0,0,.023),.036,.024,steel,drive_wheel)
	for i in 8:
		var angle: float = i*TAU/8.0
		face_disk(Vector3(sin(angle)*.083,cos(angle)*.083,.025),.012,.014,steel,drive_wheel)
		site.box(Vector3(sin(angle)*.119,cos(angle)*.119,0),Vector3(.025,.028,.036),frame,drive_wheel).rotation.z = -angle


func packing_gantry() -> void:
	stand(.85,.408,-.370)
	for x in [-.758,.758]:
		for z in [-.349,.286]:
			site.rounded(Vector3(x,1.382,z),Vector3(.097,1.054,.110),.009,paint,self)
			site.box(Vector3(x,1.292,z+.062),Vector3(.026,.793,.017),frame,self)
			rail(Vector3(x,.971,z),Vector3(x*.76,1.307,z),.041,frame)
	site.rounded(Vector3(0,1.892,-.032),Vector3(1.68,.144,.506),.016,paint,self)
	for z in [-.182,.105]:
		rail(Vector3(-.697,1.753,z),Vector3(.697,1.753,z),.034,steel)
	for x in [-.59,.59]:
		window(Vector3(x,1.264,.404),.310,.488,frame)
	for x in [-.74,.74]:
		site.box(Vector3(x,.891,.400),Vector3(.164,.059,.066),dark,self)
	motor(Vector3(-.695,1.994,-.127),Vector3.RIGHT,.210,.070)
	for i in 11:
		var t: float = i/10.0
		var link: MeshInstance3D = site.rounded(Vector3(-.527+t*.626,1.986+.043*sin(t*PI),-.176),
			Vector3(.054,.038,.082),.006,dark,self)
		link.rotation.z = .19*cos(t*PI)


func service_washer() -> void:
	stand(.721,.378,-.412)
	for x in [-.635,.635]:
		site.rounded(Vector3(x,1.292,-.194),Vector3(.150,.756,.367),.016,paint,self)
		site.box(Vector3(x,1.276,.011),Vector3(.095,.647,.038),steel,self)
		window(Vector3(x,1.232,.365),.202,.369,frame)
	site.rounded(Vector3(0,1.649,-.098),Vector3(1.437,.161,.542),.021,paint,self)
	site.rounded(Vector3(-.366,.524,.038),Vector3(.572,.507,.625),.024,paint,self)
	window(Vector3(0,1.249,.374),.897,.361,frame)
	motor(Vector3(.195,1.694,-.104),Vector3.UP,.247,.088)
	var hose := PackedVector3Array([Vector3(-.584,1.343,.036),Vector3(-.554,1.626,.044),Vector3(-.462,1.758,.055),
		Vector3(-.301,1.783,.052),Vector3(-.163,1.746,.036),Vector3(-.093,1.591,-.111)])
	site.mesh_at(Shapes.tube(hose,.027),Vector3.ZERO,dark,self)
	for y in [.514,.542,.570,.598,.626]:
		site.box(Vector3(-.369,y,.360),Vector3(.285,.012,.014),dark,self)


func pallet_lift() -> void:
	stand(.837,.382,-.420)
	for x in [-.699,.699]:
		site.rounded(Vector3(x,1.540,-.260),Vector3(.156,1.342,.210),.014,paint,self)
		site.box(Vector3(x,1.541,-.137),Vector3(.056,1.294,.052),steel,self)
		site.box(Vector3(x,1.544,-.103),Vector3(.037,1.216,.016),dark,self)
		for y in [.922,1.626]:
			face_disk(Vector3(x,y,-.081),.067,.032,frame,self)
			face_disk(Vector3(x,y,-.061),.021,.020,steel,self)
		for j in 12:
			site.box(Vector3(x,1.017+j*.044,-.080),Vector3(.043,.017,.022),steel,self)
		window(Vector3(x,1.235,.385),.267,.336,frame)
		rail(Vector3(x,.876,.39),Vector3(x,1.403,.392),.044,paint)
	site.rounded(Vector3(0,2.137,-.258),Vector3(1.586,.162,.302),.018,paint,self)
	rail(Vector3(-.72,2.034,-.213),Vector3(.72,2.034,-.213),.042,steel)
	motor(Vector3(-.619,2.211,-.269),Vector3.RIGHT,.230,.081)
	site.box(Vector3(.701,.557,-.333),Vector3(.353,.093,.216),frame,self)
	site.rounded(Vector3(.582,.556,-.119),Vector3(.385,.462,.399),.015,paint,self)


func steam_tunnel() -> void:
	stand(.857,.391,-.408)
	site.rounded(Vector3(0,.573,-.185),Vector3(1.52,.532,.605),.033,steel,self)
	site.rounded(Vector3(0,1.640,-.063),Vector3(1.835,.310,.859),.115,steel,self)
	site.rounded(Vector3(0,1.609,-.096),Vector3(1.903,.185,.933),.068,steel,self)
	site.rounded(Vector3(0,1.287,-.419),Vector3(1.837,.623,.102),.017,steel,self)
	site.rounded(Vector3(0,1.035,.394),Vector3(1.858,.162,.077),.018,steel,self)
	for x in [-.812,0.0,.812]:
		site.rounded(Vector3(x,1.289,.401),Vector3(.185,.508,.084),.019,steel,self)
	for x in [-.403,.403]:
		porthole(Vector3(x,1.289,.418))
	for x in [-.694,.690]:
		site.cylinder(Vector3(x,1.796,-.156),.062,.090,steel,self)
		site.cylinder(Vector3(x,1.853,-.156),.081,.029,frame,self)


func porthole(at: Vector3) -> void:
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var faces := PackedInt32Array()
	for i in 33:
		var angle: float = i*TAU/32.0
		var direction := Vector3(cos(angle),sin(angle),0)
		var outside: float = minf(.359/maxf(absf(direction.x),.001),.261/maxf(absf(direction.y),.001))
		points.append_array([direction*.197,direction*outside])
		normals.append_array([Vector3.BACK,Vector3.BACK])
		if i > 0:
			var a: int = (i-1)*2
			faces.append_array([a,a+2,a+1,a+1,a+2,a+3])
	site.mesh_at(Shapes.pack(points,normals,faces),at,steel,self)
	var ring := TorusMesh.new()
	ring.inner_radius = .189
	ring.outer_radius = .221
	ring.rings = 32
	ring.ring_segments = 10
	var gasket: MeshInstance3D = site.mesh_at(ring,at+Vector3(0,0,.010),frame,self)
	gasket.rotation.x = PI*.5
	var pane: MeshInstance3D = face_disk(at+Vector3(0,0,-.004),.193,.008,clear_guard,self)
	pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 8:
		var angle: float = i*TAU/8.0
		face_disk(at+Vector3(cos(angle)*.210,sin(angle)*.210,.025),.010,.008,steel,self)


func build_mechanism() -> void:
	actuator = add_pivot(Vector3.ZERO,self)
	var rubber: Material = site.material("3b5551",.88)
	var bronze: Material = site.material("978367",.54,.25)
	match kind:
		0:
			site.rounded(Vector3(0,1.451,-.082),Vector3(.572,.061,.394),.011,frame,self)
			for side in [-1,1]:
				var roller: Node3D = make_roller(Vector3(side*.049,1.155,side*.134),.088,.273,rubber,bronze)
				site.cylinder(Vector3(0,.199,0),.024,.154,steel,roller)
				site.cylinder(Vector3(0,.274,0),.046,.041,steel,roller)
			for x in [.216,.292]:
				site.cylinder(Vector3(x,1.372,.092),.011,.220,steel,self)
			site.rounded(Vector3(.254,1.488,.091),Vector3(.145,.074,.096),.012,frame,self)
			label_blade = add_pivot(Vector3(.237,1.252,.089),self)
			var head: Node3D = add_pivot(Vector3.ZERO,label_blade)
			head.rotation = Vector3(.43,0,PI)
			site.rounded(Vector3.ZERO,Vector3(.103,.059,.049),.008,bronze,head)
			site.mesh_at(Shapes.scraper_blade(),Vector3.ZERO,steel,head)
			for i in 3:
				effects.append(site.mesh_at(Shapes.paper_chip(Vector2(.021+i*.005,.026+i*.004)),
					Vector3.ZERO,site.material("d6bc8e",.91),self))
		1,5:
			for x in [-.51,.51]:
				site.cylinder(Vector3(x,1.292,-.272),.028,.536,steel,self)
			site.box(Vector3(0,1.489,-.11),Vector3(1.26,.074,.17),steel,actuator)
			var water := StandardMaterial3D.new()
			water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			water.albedo_color = Color(.46,.72,.80,.69)
			water.emission_enabled = true
			water.emission = Color("315377")
			for x in [-.37,0.0,.37]:
				var pipe: MeshInstance3D = site.cylinder(Vector3(x,1.448,-.038),.019,.23,steel,actuator)
				pipe.rotation.x = PI*.37
				site.cylinder(Vector3(x,1.382,.055),.026,.039,bronze,actuator)
				for ray in 3:
					effects.append(site.cylinder(Vector3(x+(ray-1)*.014,1.25,.055+(ray-1)*.014),.0038,.239,water,actuator))
			if kind == 5:
				var brush: Node3D = make_roller(Vector3(.195,1.174,-.104),.074,.248,bronze,rubber)
				site.cylinder(Vector3(0,.285,0),.019,.298,steel,brush)
		2:
			for z in [-.24,.24]:
				site.box(Vector3(-.201,1.247,z),Vector3(.094,.514,.076),frame,self)
			site.rounded(Vector3(-.201,1.473,0),Vector3(.164,.122,.526),.008,frame,self)
			site.rounded(Vector3(-.201,1.397,0),Vector3(.086,.033,.24),.004,dark,self)
			for z in [-.178,.183]:
				site.rounded(Vector3(-.197,1.282,z),Vector3(.111,.084,.082),.008,paint,self)
				face_disk(Vector3(-.197,1.280,z-.041 if z > 0 else z+.041),.027,.012,dark,self)
			var scan := StandardMaterial3D.new()
			scan.albedo_color = Color("66b5ad")
			scan.emission_enabled = true
			scan.emission = Color("4ca9a2")
			scan.emission_energy_multiplier = .70
			effects.append(site.box(Vector3(-.201,1.323,0),Vector3(.022,.006,.22),scan,self))
			site.rounded(Vector3(.312,1.128,-.24),Vector3(.219,.087,.185),.009,frame,self)
			site.rounded(Vector3(.312,1.142,-.155),Vector3(.162,.038,.224),.007,bronze,actuator)
		3:
			var shaft: MeshInstance3D = site.cylinder(Vector3(0,1.185,-.146),.034,1.31,steel,self)
			shaft.rotation.z = PI*.5
			cradle = add_pivot(Vector3(0,1.125,-.143),actuator)
			face_disk(Vector3.ZERO,.079,.041,paint,cradle)
			for y in [-.062,.041]:
				site.rounded(Vector3(0,y,.021),Vector3(.157,.034,.057),.009,steel,cradle)
				for x in [-.055,.055]:
					site.rounded(Vector3(x,y,.094),Vector3(.029,.034,.143),.006,steel,cradle)
					site.rounded(Vector3(x*.90,y,.158),Vector3(.019,.048,.030),.006,rubber,cradle)
			site.box(Vector3(0,1.070,.181),Vector3(.85,.024,.116),steel,self)
			for i in 3:
				effects.append(site.cylinder(Vector3.ZERO,.0032,.023,site.material("80a9aa",.24),self))
		4:
			trolley = add_pivot(Vector3.ZERO,self)
			site.rounded(Vector3(0,1.740,-.035),Vector3(.500,.105,.366),.012,frame,trolley)
			for x in [-.172,.172]:
				site.cylinder(Vector3(x,1.617,-.105),.034,.232,steel,trolley)
				site.cylinder(Vector3(x,1.513,-.105),.017,.266,steel,actuator)
			site.box(Vector3(0,1.39,-.099),Vector3(.79,.048,.292),steel,actuator)
			for x in [-.22,0.0,.22]:
				site.rounded(Vector3(x,1.355,-.083),Vector3(.134,.057,.112),.008,frame,actuator)
				for side in [-1,1]:
					var jaw := add_pivot(Vector3(x+side*.049,1.343,-.083),actuator)
					jaws.append(jaw)
					face_disk(Vector3(0,-.006,.067),.013,.012,steel,jaw)
					site.rounded(Vector3(0,-.039,0),Vector3(.020,.097,.078),.004,steel,jaw)
					site.box(Vector3(-side*.008,-.078,.005),Vector3(.035,.024,.059),rubber,jaw)
			carrier = add_pivot(Vector3(.1,DECK,-.225),self)
			var crate_node: Node3D = site.crate(Vector3.ZERO,"9c794e",carrier,Vector3(.63,.152,.32))
			crate_stock = site.fill_crate_samples(crate_node)
		6:
			for x in [-.643,.643]:
				site.rounded(Vector3(x,1.228,-.144),Vector3(.139,.335,.137),.012,paint,actuator)
				site.rounded(Vector3(x*.71,1.005,-.122),Vector3(.095,.051,.605),.010,frame,actuator)
			site.rounded(Vector3(0,1.004,-.197),Vector3(1.21,.069,.51),.009,steel,actuator)
			for i in 6:
				site.box(Vector3(0,1.037,-.416+i*.083),Vector3(1.18,.027,.062),site.material("8d7653",.79),actuator)
			for x in [-.271,.271]:
				site.crate(Vector3(x,1.043,-.20),"9b7852",actuator,Vector3(.49,.191,.341))
		Yard.SANITIZER:
			var steam := ShaderMaterial.new()
			steam.shader = Steam
			var cloud := SphereMesh.new()
			cloud.radial_segments = 12
			cloud.rings = 6
			for x in [-.54,0.0,.54]:
				var pipe: MeshInstance3D = site.cylinder(Vector3(x,1.356,-.156),.026,.36,steel,self)
				pipe.rotation.x = PI*.5
				site.cylinder(Vector3(x,1.326,.005),.032,.068,bronze,self)
			for i in 7:
				effects.append(site.mesh_at(cloud,Vector3.ZERO,steam,self))
	for effect in effects:
		effect.hide()
		effect.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func make_roller(at: Vector3, radius: float, height: float, rubber: Material, ribs: Material) -> Node3D:
	var roller := add_pivot(at,actuator)
	rotors.append(roller)
	site.cylinder(Vector3.ZERO,radius,height,rubber,roller)
	for i in 11:
		var angle: float = i*TAU/11.0
		var rib: MeshInstance3D = site.box(Vector3(sin(angle),0,cos(angle))*radius,
			Vector3(.010,height*.923,.014),ribs,roller)
		rib.rotation.y = angle
	return roller


func set_indicator(running: bool) -> void:
	var color := Color("83c38c" if running else "ac8b55")
	indicator.albedo_color = color
	indicator.emission = color
	indicator.emission_energy_multiplier = .90 if running else .24


func update_work(installed: bool, handled: int, delta: float) -> bool:
	if visible != installed:
		visible = installed
		collision_body.collision_layer = 1 if installed else 0
	finishing = FINISH_TIME if handled > last_work else maxf(0.0,finishing-delta)
	last_work = handled
	var running: bool = installed and finishing > 0.0
	if active != running:
		active = running
		set_indicator(active)
		work_light.light_energy = .72 if active else .38
	return active


func tilt_at(x: float) -> float:
	return PI*smoothstep(-.67,-.22,x)*(1.0-smoothstep(.24,.67,x))


func transfer_at(x: float) -> float:
	return smoothstep(-.16,.31,x)


func update_bottle(bottle: Node3D, x: float, half_height: float) -> void:
	if not active:
		return
	if kind == 3:
		var angle: float = tilt_at(x)
		bottle.rotation.z = -angle
		bottle.position += (Vector3.UP-bottle.basis.y)*half_height
		bottle.position.y += .102*angle/PI
	elif kind == Yard.PACKER:
		var transfer: float = transfer_at(x)
		bottle.position.y += .177*sin(transfer*PI)+.028*transfer
		bottle.position.z -= .225*transfer


func animate(delta: float, bottle_x: float, speed: float) -> void:
	if not visible:
		return
	if active:
		clock = fposmod(clock+delta*speed,TAU*128.0)
	var contact: float = 1.0-smoothstep(.14,.47,absf(bottle_x)) if active else 0.0
	for i in rotors.size():
		rotors[i].rotation.y = fposmod(clock*(16.0 if i == 0 else -16.0),TAU)
	match kind:
		0:
			for i in rotors.size():
				rotors[i].position.z = (2*i-1)*(.134-.009*contact)
			var stroke: float = smoothstep(.10,.313,bottle_x)*(1.0-smoothstep(.37,.51,bottle_x)) if active else 0.0
			label_blade.position = Vector3(.24,1.252-.088*stroke,.089-.010*stroke)
			for i in effects.size():
				var flake: MeshInstance3D = effects[i]
				var travel: float = smoothstep(.13+i*.025,.48+i*.025,bottle_x)
				flake.visible = active and bottle_x > .14+i*.025 and bottle_x < .52+i*.025
				flake.position = Vector3(.260+travel*.196,1.159-travel*.142,.074+travel*(.154+i*.026))
				flake.rotation = Vector3(travel*2.1,i*.41,travel*3.6+i*.89)
		1,5:
			actuator.position.y = -.055*contact
			if is_instance_valid(pressure_needle):
				var pressure: float = -1.11+1.84*float(active)+sin(clock*4.0)*.092*contact
				pressure_needle.rotation.z = move_toward(pressure_needle.rotation.z,pressure,delta*3.6)
			for i in effects.size():
				var jet: MeshInstance3D = effects[i]
				var nozzle: float = (i/3-1)*.37
				var difference: float = bottle_x-nozzle
				jet.visible = active and absf(difference) < .31
				if jet.visible:
					var spread: float = i%3-1
					var start := Vector3(nozzle+spread*.014,1.363,.055+spread*.014)
					var end := Vector3(nozzle+difference*.83+spread*.016,
						1.085+.045*sin(clock*38.0+i*1.12),.024+spread*.025)
					var stream: Vector3 = start-end
					jet.position = (start+end)*.5
					jet.quaternion = Quaternion(Vector3.UP,stream.normalized())
					jet.scale.y = stream.length()/.239
		2:
			effects[0].visible = active and absf(bottle_x+.20) < .135
			actuator.position.z = .138*(1.0-smoothstep(.055,.21,absf(bottle_x-.312))) if active else 0.0
		3:
			var angle: float = tilt_at(bottle_x) if active else 0.0
			actuator.position.x = clampf(bottle_x,-.44,.44) if active else 0.0
			actuator.position.y = .092*angle/PI
			cradle.rotation.z = -angle
			drive_wheel.rotation.z = -angle*1.36
			for i in effects.size():
				var drip: MeshInstance3D = effects[i]
				drip.visible = angle > 2.65
				drip.position = Vector3(actuator.position.x,DECK+.101-fposmod(clock*.54+i*.025,.065),.034)
		4:
			var transfer: float = transfer_at(bottle_x) if active else 0.0
			actuator.position = Vector3(clampf(bottle_x,-.36,.36) if active else 0.0,
				.177*sin(transfer*PI)+.028*transfer-.018*contact,.080-.225*transfer)
			trolley.position.x = actuator.position.x
			trolley.position.z = actuator.position.z
			var closed: float = smoothstep(.02,.22,transfer)*(1.0-smoothstep(.75,.97,transfer))
			for i in jaws.size():
				var side: float = 2*(i%2)-1
				jaws[i].rotation.z = side*lerpf(.29,-.20,closed)
			carrier.position.x = .12+.26*clampf(bottle_x,-.62,.62) if active else .12
			for i in crate_stock.size():
				crate_stock[i].visible = active and i < (3 if transfer > .57 else 2)
		6:
			actuator.position.y = .145*contact
		Yard.SANITIZER:
			for i in effects.size():
				var puff: MeshInstance3D = effects[i]
				var rise: float = fposmod(clock*1.56+i*.239,1.0)
				puff.visible = active and absf(bottle_x) < .83
				puff.position = Vector3((i-3)*.176+sin(clock*2.9+i)*.045,DECK+.027+rise*.34,-.049+cos(i*2.8+rise)*.046)
				puff.scale = Vector3(.156,.115,.148)*(.43+rise*.99)
