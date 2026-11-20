extends Node3D

signal sound_requested(id: String)
signal changed
signal checkpoint(queue: int)

const Yard = preload("res://yard.gd")
const GlassMaterial = preload("res://glass.gdshader")
const PaperMaterial = preload("res://paper.gdshader")
const SkinMaterial = preload("res://skin.gdshader")
const Shapes = preload("res://workshop_shapes.gd")
const WorkerHand = preload("res://worker_hand.gd")
const POSITION = Vector3(-.039, -.210, -.63)
const SCRAPE_LIFT = Vector3(.021,.101,0)
const PINCH_CONTACT = Vector3(-.024,.054,-.030)
const SCRAPE_LABEL = "scrape_label"
const SCRAPE_RELEASE_TIME = .20
const SCRAPE_RESET_TIME = .16
const SCRAPE_SPEED = 95.0
const SCRAPE_TARGET_RADIUS = 76.0
const LABEL_START = -1.13
const LABEL_ARC = 2.48
const LABEL_BOTTOM = .052
const LABEL_TOP = .166
const LABEL_CLEARANCE = .0025
const SCRAPER_MOUNT := Transform3D(Basis(Vector3.BACK,.78),Vector3(-.015,.049,-.042))
# Four finger rows hold MCP, PIP, DIP flexion and splay. Thumb rows hold individual pitch and splay.
const BRACE_FINGERS = [
	[Vector4(15,26,15,-8),Vector4(1,55,38,-1),Vector4(1,58,36,1),Vector4(23,34,14,9)],
	[Vector4(19,35,18,-4),Vector4(9,60,35,5),Vector4(8,58,33,7),Vector4(28,33,12,12)],
]
const BRACE_THUMBS = [
	[Vector2(14,51),Vector2(42,63),Vector2(71,55)],
	[Vector2(20,40),Vector2(36,50),Vector2(68,62)],
]
const RINSE_BRACE_PROFILE = [0,1,0,1,0,0]
const RINSE_GRIP_MOUNTS = [
	Vector3(-.064,.060,-.042),Vector3(-.064,.063,-.0415),Vector3(-.0747,.061,-.0527),
	Vector3(-.0597,.061,-.0358),Vector3(-.0618,.0605,-.0385),Vector3(-.0628,.0605,-.0403),
]
const SCRAPER_FINGERS = [Vector4(13,45,36,32),Vector4(20,66,43,27),Vector4(32,66,43,28),Vector4(56,53,21,18)]
const SCRAPER_THUMB = [Vector2(10,-16),Vector2(11,3),Vector2(0,3)]
const CLOTH_MOUNT := Transform3D(Basis(Vector3.RIGHT,1.22),Vector3(-.011,.045,-.032))
const RIGHT_IDLE = Vector3(.217,-.315,-.52)
const RIGHT_RINSE_REST = Vector3(.245,-.490,-.365)
const VALVE_TOUCH_TIME = .12
const FINGER_LENGTHS = [
	[.027,.020,.016],[.030,.024,.016],[.029,.021,.015],[.022,.017,.013],[.023,.024,.018],
]
const PROFILES = Yard.BOTTLE_PROFILES
const STEPS = [
	[SCRAPE_LABEL], [SCRAPE_LABEL], ["brush"], ["bore"], ["rinse_bead"], ["open", "gasket", "scrub"],
]
const RINSING = ["rinse","rinse_bead"]
const ACTIONS = {
	SCRAPE_LABEL: ["用刮刀刮下标签", "刀口对准标签，按住右键慢慢往下拖", 150.0],
	"brush": ["刷洗瓶肩", "按住左键左右来回刷", 220.0],
	"bore": ["用细刷清理瓶底", "在瓶身按住左键，向上拉细刷", 166.0],
	"rinse_bead": ["倾斜汽水瓶，冲开糖渍", "右键拖到弹珠移开，左键按住冲洗", 1.05],
	"rinse": ["清水冲洗瓶口和瓶内", "按住左键在水槽冲洗，直到水流变清", .76],
	"sanitize": ["放入蒸汽消毒仓", "左键关仓门并启动消毒", 1.18],
	"drain": ["倒置沥干", "左键把瓶口朝下放上沥水架", .60],
	"open": ["掰开锁扣", "左键按瓶盖处的金属扣", 1.0],
	"gasket": ["抽掉旧胶圈", "在开着的瓶口按住左键，向下拉出胶圈", 108.0],
	"close": ["扣好新胶圈", "左键把瓶盖重新扣好", 1.0],
	"scrub": ["擦掉残胶和污渍", "按住左键左右来回擦拭", 163.0],
}

var camera: Camera3D
var source
var font: Font
var bottle: Node3D
var label_mesh: MeshInstance3D
var label_print: Label3D
var label_material: ShaderMaterial
var cap: Node3D
var marble: MeshInstance3D
var tool: Node3D
var scraper: Node3D
var towel: MeshInstance3D
var stream: MeshInstance3D
var water_drops: Array[MeshInstance3D] = []
var runoff: StandardMaterial3D
var wet_glass: ShaderMaterial
var arms: Array = []
var glass_mats: Array = []
var labels: Array = []
var reel: SphereMesh
var code: int = -1
var type: int = 0
var quality: int = 0
var stages: Array = []
var step: int = 0
var progress: float = 0.0
var held: bool = false
var turned: bool = false
var pressed: bool = false
var cycle_running: bool = false
var washed: bool = false
var cap_opened: bool = false
var gasket_replaced: bool = false
var wetness: float = 0.0
var rotating: bool = false
var done: bool = false
var cursor: Vector2
var wrist: Vector3 = RIGHT_IDLE
var left_grip: Transform3D
var bottle_brace: Transform3D
var left_grip_placed: bool = false
var rotation_goal: float = 0.0
var lean_goal: float = 0.0
var clock: float = 0.0
var last_cue: float = -1.0
var clean_ring: StandardMaterial3D
var dirty_ring: StandardMaterial3D
var gasket_ring: MeshInstance3D
var has_paper: bool = false
var label_removed: bool = false
var scrape_pressure: float = 0.0
var scrape_drag_pending: float = 0.0
var label_travel: float = 0.0
var stroke_travel: float = 0.0
var scrape_release: float = 0.0
var scrape_reset: float = 0.0
var scraper_level: int = 0
var scrape_pass: int = 0
var scrape_passes: int = 2
var scrape_drag_length: float = 0.0
var scrape_between_passes: bool = false
var glue_cleanup: bool = false
var surface_wiped: bool = false
var bottle_sequence: int = 0
var emitted_flakes: int = 0
var lift_from_bench: float = 1.0
var valve_time: float = 0.0


func build(origin: Camera3D, drawing, glyphs: Font) -> void:
	camera = origin
	source = drawing
	font = glyphs
	# Place the palm behind the bottle and roll the left thumb up toward the viewer.
	var finger_axis: Vector3 = Vector3(.86,.33,-.43).normalized()
	var thumb_axis: Vector3 = Vector3(-.20,.93,.34).slide(finger_axis).normalized()
	bottle_brace = Transform3D(Basis(thumb_axis,finger_axis,thumb_axis.cross(finger_axis)),Vector3(-.069,.061,-.045))
	var skin := ShaderMaterial.new()
	skin.shader = SkinMaterial
	skin.set_shader_parameter("skin_atlas",load("res://assets/worker_hands.png"))
	var worker_hands: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/worker_hands.json"))
	var fabric: Material = source.surface("404d41",false,6)
	clean_ring = source.material("b36e51", .68)
	dirty_ring = source.material("60523a", .92)
	reel = SphereMesh.new()
	reel.radial_segments = 12
	reel.rings = 7
	reel.height = 2.0
	reel.radius = 1.0
	for i in Yard.NAMES.size():
		var mat := ShaderMaterial.new()
		mat.shader = GlassMaterial
		mat.set_shader_parameter("glass", Color(Yard.GLASS[i]))
		mat.set_shader_parameter("adhesive_area",Vector4(LABEL_START,LABEL_ARC,LABEL_BOTTOM,LABEL_TOP))
		glass_mats.append(mat)
		var wrap := ShaderMaterial.new()
		wrap.shader = PaperMaterial
		wrap.set_shader_parameter("paper",Color(Yard.LABEL[i]))
		wrap.set_shader_parameter("ink",Color(["536041","8c3f1b","48685c","644324","356c64","645c37"][i]))
		wrap.set_shader_parameter("sleeve",i == 1)
		labels.append(wrap)
	bottle = Node3D.new()
	bottle.position = POSITION
	add_child(bottle)
	for i in 2:
		var arm := WorkerHand.new()
		add_child(arm)
		arm.build(worker_hands.hands[i],skin,fabric)
		for gesture in (["hold"] if i == 0 else ["pinch","tool","reach","rest"]):
			var sketches: Array = []
			for digit in 5:
				sketches.append(finger_joints(i,digit,gesture))
			arm.register_pose(gesture,sketches,PINCH_CONTACT)
		if i == 0:
			for profile in BRACE_FINGERS.size():
				arm.register_grip_pose("brace%d" % profile,BRACE_FINGERS[profile],BRACE_THUMBS[profile])
		else:
			arm.register_grip_pose("scraper",SCRAPER_FINGERS,SCRAPER_THUMB)
		arms.append(arm)
	tool = Node3D.new()
	add_child(tool)
	scraper = source.make_scraper(self)
	scraper.hide()
	source.cylinder(Vector3(0,-.012,0),.008,.112,source.material("b6904d"),tool)
	source.cylinder(Vector3(0,.039,0),.009,.021,source.material("727b70",.44,.3),tool)
	for j in 8:
		sphere(Vector3((j%4-1.5)*.004,.059,j/4*.006-.003), Vector3(.003,.020,.003), source.material("b6ab85"), tool)
	towel = source.rounded(Vector3.ZERO,Vector3(.058,.011,.070),.005,source.surface("b9a98a",false,6),self)
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(.63,.84,.91,.63)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = .17
	stream = source.cylinder(Vector3.ZERO,.0024,1.0,water,self)
	stream.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	runoff = water.duplicate()
	for i in 9:
		water_drops.append(sphere(Vector3.ZERO,Vector3(.0016,.003,.0016),runoff,self))
	clear()


func sphere(at: Vector3, dimensions: Vector3, mat: Material, parent: Node3D) -> MeshInstance3D:
	var node: MeshInstance3D = source.mesh_at(reel, at, mat, parent)
	node.scale = dimensions
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


func load_bottle(item: int, from_queue: int, selected_scraper: int = 0) -> void:
	for child in bottle.get_children():
		bottle.remove_child(child)
		child.queue_free()
	code = item
	type = item / 3
	quality = item % 3
	if scraper_level != selected_scraper:
		scraper.hide()
		scraper.queue_free()
		scraper_level = selected_scraper
		scraper = source.make_scraper(self,scraper_level)
	var tool_profile: Dictionary = Yard.SCRAPERS[scraper_level]
	var material_index: int = int(type == 1)
	scrape_passes = tool_profile.passes[material_index]
	scrape_drag_length = tool_profile.drag[material_index]
	glue_cleanup = type <= 1 and from_queue < Yard.STRIPPED and tool_profile.glue[material_index]
	set_work_steps(from_queue)
	step = 0
	progress = 0.0
	pressed = false
	cycle_running = false
	washed = from_queue >= Yard.WASHED
	wetness = .74 if washed else 0.0
	cap_opened = type == 5 and washed
	gasket_replaced = cap_opened
	rotating = false
	done = false
	turned = false
	rotation_goal = -.08
	lean_goal = 0.0
	lift_from_bench = 0.0
	bottle.position = POSITION + Vector3(-.061,-.117,.05)
	bottle.rotation = Vector3(.03,.11,-.08)
	scrape_pressure = 0.0
	scrape_drag_pending = 0.0
	label_travel = 0.0
	stroke_travel = 0.0
	scrape_release = 0.0
	scrape_reset = 0.0
	scrape_pass = 0
	scrape_between_passes = false
	surface_wiped = false
	emitted_flakes = 0
	scraper.hide()
	left_grip_placed = false
	for arm in arms:
		arm.gesture = ""
	label_removed = from_queue >= Yard.STRIPPED and type <= 1
	has_paper = type <= 1
	marble = null
	gasket_ring = null
	var glass: ShaderMaterial = glass_mats[type].duplicate()
	wet_glass = glass
	bottle_sequence += 1
	glass.set_shader_parameter("scuff",.73 if quality > 0 else .34)
	glass.set_shader_parameter("wetness",wetness)
	glass.set_shader_parameter("stain_seed",float((bottle_sequence*17+item*7)%97)*.19)
	glass.set_shader_parameter("adhesive_strength",.84 if glue_cleanup else 0.0)
	glass.set_shader_parameter("grime_strength",.70 if quality == 1 else (.26 if not has_paper else 0.0))
	source.build_bottle_body(type,glass,bottle)
	label_material = labels[type].duplicate() as ShaderMaterial
	label_material.set_shader_parameter("scrape_passes",scrape_passes)
	label_material.set_shader_parameter("label_band",Vector2(LABEL_BOTTOM,LABEL_TOP))
	label_material.set_shader_parameter("adhesion_threshold",.51 if scraper_level == 0 else .62)
	var rows: Array = label_rows()
	label_mesh = source.mesh_at(Shapes.lathe(rows,36,LABEL_START,LABEL_ARC),Vector3.ZERO,label_material,bottle)
	# The thin wrap sits against the glass and does not need its own shadow caster.
	label_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var print_radius: float = Shapes.radius_at(PROFILES[type],.114)+LABEL_CLEARANCE+.001
	label_print = source.text_at(Yard.MARKS[type],Vector3(0,.114,print_radius),42,.0006,"494331",bottle)
	label_print.modulate.a = .9
	if quality == 2:
		paint_crack(float(rows[0][1]))
	if type == 4:
		marble = source.build_bottle_marble(bottle,glass_mats[type])
	cap = Node3D.new()
	bottle.add_child(cap)
	if type == 5:
		gasket_ring = source.build_bottle_closure(cap,bottle,dirty_ring)
	held = true
	bottle.show()
	show()
	update_art()
	cursor = hotspot()
	changed.emit()


func set_work_steps(from_queue: int) -> void:
	stages = []
	if from_queue < Yard.WASHED:
		stages = STEPS[type].duplicate()
		if from_queue >= Yard.STRIPPED and type <= 1:
			stages.clear()
		if (quality == 1 or glue_cleanup) and "scrub" not in stages:
			stages.append("scrub")
		if stages.is_empty() or stages.back() != "rinse_bead":
			stages.append("rinse")
	if from_queue < Yard.SANITIZED:
		stages.append("sanitize")
	stages.append("drain")
	if type == 5:
		stages.append("close")


func label_rows() -> Array:
	return Shapes.label_profile(PROFILES[type],LABEL_BOTTOM,LABEL_TOP,LABEL_CLEARANCE)


func wrap_radius(height: float) -> float:
	return Shapes.radius_at(PROFILES[type],height)+.00135


func paint_crack(radius: float) -> void:
	var mark: Material = source.material("e0dac0")
	var points: Array = [
		Vector3(-.010,.017,radius),Vector3(.004,.046,radius),
		Vector3(-.002,.061,radius),Vector3(.017,.093,radius),
		Vector3(.009,.136,radius),Vector3(.025,.170,radius-.006),
	]
	for i in range(1,points.size()):
		var part := sphere(Vector3.ZERO,Vector3.ONE,mark,bottle)
		span(part, points[i-1], points[i], .0012)


func task() -> String:
	if done or quality == 2 or not held:
		return ""
	return stages[step]


func view_task() -> String:
	if scrape_release > 0.0:
		return SCRAPE_LABEL
	return "pack" if held and done else task()


func rinse_flowing() -> bool:
	return pressed and task() in RINSING and valve_time >= VALVE_TOUCH_TIME


func hotspot() -> Vector2:
	var y: float = .112
	var action: String = task()
	if action in RINSING:
		return camera.unproject_position(source.FAUCET+Vector3.DOWN*.056)
	if action == "sanitize":
		return camera.unproject_position(source.SANITIZER_TRAY+Vector3(0,.166,.17))
	if action == "drain":
		return camera.unproject_position(source.DRAIN_PIN+Vector3.UP*.075)
	if action in ["open","gasket","close"]:
		y = float(PROFILES[type].back()[0]) - .017
	elif action == "brush":
		y = .170
	if action == SCRAPE_LABEL:
		return camera.unproject_position(to_global(scrape_point(0.0 if scrape_between_passes else stroke_travel)))
	return camera.unproject_position(bottle.to_global(Vector3(.005,y,.039)))


func bottle_surface(profile: int, angle: float, height: float, clearance: float) -> Vector3:
	var radius: float = Shapes.radius_at(PROFILES[profile],height)+clearance
	return Vector3(sin(angle)*radius,height,cos(angle)*radius)


func bottle_grip_basis() -> Basis:
	# Follow the lean of the bottle while letting the glass turn within the left grip.
	var up: Vector3 = bottle.basis.y.normalized()
	var right: Vector3 = Vector3.RIGHT.slide(up).normalized()
	return Basis(right,up,right.cross(up))


func scrape_angle(amount: float) -> float:
	# Keep the cutting line on the right of the brace while the bottle turns in the hand.
	var angle: float = .83-amount*.11-scrape_pass*.025
	var direction: Vector3 = bottle.basis.inverse()*bottle_grip_basis()*Vector3(sin(angle),0,cos(angle))
	return atan2(direction.x,direction.z)


func scrape_point(amount: float, clearance: float = .0024) -> Vector3:
	return bottle.transform*bottle_surface(type,scrape_angle(amount),lerpf(LABEL_TOP,LABEL_BOTTOM,amount),clearance)


func scraper_basis() -> Basis:
	var angle: float = scrape_angle(stroke_travel)
	var normal: Vector3 = bottle.basis*Vector3(sin(angle),0,cos(angle))
	var tangent: Vector3 = bottle.basis.y.cross(normal)
	var edge: Vector3 = (tangent*.80+bottle.basis.y*.60).normalized()
	var along: Vector3 = ((bottle.basis.y*.80-tangent*.60)*.90-normal*.435).normalized()
	return Basis(edge,along,edge.cross(along)).orthonormalized()


func edge_visible() -> bool:
	if task() != SCRAPE_LABEL:
		return true
	var angle: float = scrape_angle(.5)
	return angle > LABEL_START+.06 and angle < LABEL_START+LABEL_ARC-.06


func aim_radius() -> float:
	return SCRAPE_TARGET_RADIUS if task() == SCRAPE_LABEL else 105.0


func press_action() -> void:
	if not held or done or quality == 2 or cycle_running or not edge_visible():
		return
	if cursor.distance_to(hotspot()) > aim_radius():
		return
	if task() == "rinse_bead" and not turned:
		return
	scrape_release = 0.0
	if task() == SCRAPE_LABEL:
		scrape_reset = 0.0
		scrape_between_passes = false
	if task() in ["sanitize","drain"]:
		cycle_running = true
		sound_requested.emit("snap" if task() == "sanitize" else "glass")
		return
	if not pressed and task() in RINSING:
		valve_time = 0.0
	pressed = true
	last_cue = -1.0
	if task() in ["open","close"]:
		sound_requested.emit("snap")
		gain(1.0)


func release_action() -> void:
	pressed = false
	scrape_drag_pending = 0.0


func drag(relative: Vector2) -> void:
	if not held or cycle_running:
		return
	var bounds: Vector2 = get_viewport().get_visible_rect().size
	if rotating:
		rotation_goal = wrapf(rotation_goal + relative.x * .013, -PI, PI)
		if task() == "rinse_bead":
			lean_goal = clampf(lean_goal + absf(relative.x) * .012, 0.0, .90)
			if lean_goal > .53 and not turned:
				turned = true
				sound_requested.emit("glass")
		cursor = hotspot()
		return
	cursor = (cursor + relative * .70).clamp(Vector2(24,24),bounds - Vector2(24,24))
	if not pressed or done:
		return
	var action: String = task()
	var amount: float = 0.0
	match action:
		SCRAPE_LABEL:
			scrape_drag_pending += maxf(0.0,relative.y-.25*absf(relative.x))
			return
		"gasket": amount = maxf(0.0, relative.y - .18 * absf(relative.x))
		"brush","scrub": amount = maxf(0.0, absf(relative.x) - .6 * absf(relative.y))
		"bore": amount = maxf(0.0, -relative.y - .4 * absf(relative.x))
	if amount > 0.0:
		if clock - last_cue > .11:
			last_cue = clock
			var cue: String = "paper" if action == "gasket" else "brush"
			sound_requested.emit(cue)
		gain(amount)


func advance_scrape(delta: float) -> void:
	# Consume only this frame's movement. A fast flick cannot preload a full stroke.
	var amount: float = minf(scrape_drag_pending,SCRAPE_SPEED*minf(delta,.05))
	scrape_drag_pending = 0.0
	if amount <= 0.0 or not pressed or scrape_pressure < .80:
		return
	if clock-last_cue > .11:
		last_cue = clock
		sound_requested.emit(Yard.SCRAPERS[scraper_level].cue)
	var end_of_pass: float = float(scrape_pass+1)/scrape_passes
	gain(amount*ACTIONS[SCRAPE_LABEL][2]/(scrape_drag_length*scrape_passes),end_of_pass)
	if task() == SCRAPE_LABEL and is_equal_approx(progress,end_of_pass):
		progress = end_of_pass
		scrape_pass += 1
		scrape_between_passes = true
		scrape_reset = SCRAPE_RESET_TIME
		release_action()
		cursor = hotspot()


func gain(amount: float, limit: float = 1.0) -> void:
	var action: String = task()
	if action.is_empty():
		return
	progress = minf(limit,progress+amount/ACTIONS[action][2])
	if progress >= 1.0:
		pressed = false
		cycle_running = false
		if action == SCRAPE_LABEL:
			scrape_release = SCRAPE_RELEASE_TIME
			label_removed = true
			if not glue_cleanup:
				checkpoint.emit(Yard.STRIPPED)
		elif action == "scrub":
			surface_wiped = true
			if glue_cleanup:
				glue_cleanup = false
				checkpoint.emit(Yard.STRIPPED)
		elif action == "open":
			cap_opened = true
		elif action == "gasket":
			gasket_replaced = true
		elif action == "close":
			cap_opened = false
		elif action in RINSING and stages[step+1] == "sanitize":
			washed = true
			checkpoint.emit(Yard.WASHED)
		elif action == "sanitize":
			checkpoint.emit(Yard.SANITIZED)
			sound_requested.emit("snap")
		step += 1
		if step >= stages.size():
			done = true
			checkpoint.emit(Yard.CLEAN)
			sound_requested.emit("glass")
		else:
			progress = 0.0
			cursor = hotspot()
	changed.emit()


func pose(delta: float) -> void:
	if not held:
		return
	clock += delta
	if pressed and task() in RINSING:
		valve_time += delta
		if rinse_flowing() and clock - last_cue > .14:
			sound_requested.emit("water")
			last_cue = clock
		wetness = move_toward(wetness,1.0,delta*1.8)
		gain(delta)
	elif cycle_running:
		if task() == "drain":
			wetness = move_toward(wetness,0.0,delta*1.9)
		gain(delta)
	var bob: float = sin(clock*2.15) * .002
	var center_before: Vector2 = hotspot()
	lift_from_bench = minf(1.0,lift_from_bench + delta*4.8)
	var remaining_lift: float = 1.0-smoothstep(0.0,1.0,lift_from_bench)
	scrape_release = maxf(0.0,scrape_release-delta)
	scrape_reset = maxf(0.0,scrape_reset-delta)
	var action: String = view_task()
	var scraping: bool = action == SCRAPE_LABEL
	var rinsing: bool = action in RINSING
	var previous_bottle_basis: Basis = bottle_grip_basis() if rinsing else Basis.IDENTITY
	var on_glass: bool = scraping and (pressed or scrape_release > .055 or scrape_reset > .076)
	scrape_pressure = move_toward(scrape_pressure,1.0 if on_glass else 0.0,delta*10.0)
	if scraping:
		advance_scrape(delta)
	if scraping and (not pressed or scrape_pressure >= .53):
		var travel_blend: float = 1.0-exp(-delta*25.0)
		label_travel = lerpf(label_travel,1.0 if label_removed else progress,travel_blend)
		var stroke_end: float = 1.0 if label_removed or scrape_reset > 0.0 else clampf(progress*scrape_passes-scrape_pass,0.0,1.0)
		stroke_travel = lerpf(stroke_travel,stroke_end,travel_blend)
	var tension: float = scrape_pressure*sin(stroke_travel*PI)
	var goal: Vector3 = POSITION+Vector3(0,bob,0)+Vector3(-.061,-.117,.05)*remaining_lift
	goal += Vector3(.001,-.004,-.004)*tension
	var turn := Basis.from_euler(Vector3(.03-.026*tension,rotation_goal,-.08-.048*tension))
	if scraping or (action == "scrub" and glue_cleanup):
		goal += SCRAPE_LIFT
	elif rinsing:
		var roll: float = -lean_goal*.83 if action == "rinse_bead" else -.10
		var world_pose := Basis.from_euler(Vector3(.03,rotation_goal,roll))
		turn = global_basis.inverse()*world_pose
		goal = to_local(source.FAUCET+Vector3.DOWN*.066)-turn*Vector3.UP*bottle_height()
	elif action == "sanitize":
		turn = global_basis.inverse()*Basis.IDENTITY
		goal = to_local(source.SANITIZER_TRAY+Vector3(0,.010,0 if cycle_running else .32))
	elif action == "drain" and cycle_running:
		turn = global_basis.inverse()*Basis(Vector3.FORWARD,PI)
		goal = to_local(source.DRAIN_PIN)-turn*Vector3.UP*bottle_height()
	var blend: float = 1.0-exp(-delta*13.5)
	bottle.position = bottle.position.lerp(goal,blend)
	bottle.quaternion = bottle.quaternion.slerp(turn.get_rotation_quaternion(),blend)
	if rotating or (scraping and pressed) or (remaining_lift > 0.0 and not pressed and cursor.distance_to(center_before) < 19.0):
		cursor = hotspot()
	elif scraping and cursor.distance_to(center_before) < 105.0:
		cursor += hotspot()-center_before
	var brush_active: bool = action in ["brush","bore","scrub"]
	var spot: Vector2 = hotspot()
	var reach: Vector2 = ((cursor - spot) * .00053).clamp(Vector2(-.10,-.10),Vector2(.10,.12))
	var lift: float = .107
	if action in ["open","gasket","close"]:
		lift = .235
	var close_at: Vector3 = bottle.position + Vector3(.105 + reach.x*.38,lift - reach.y*.72,.066)
	var is_near: bool = pressed or (cursor.distance_to(spot) < 75 and not done and edge_visible())
	var pinching: bool = pressed and action == "gasket"
	var opening_valve: bool = false
	var idle: Vector3 = RIGHT_IDLE
	var right_rotation := Vector3(.34,.46,1.03 + reach.x)
	if scraping:
		is_near = not rotating
	elif rinsing:
		opening_valve = pressed and valve_time < .27
		is_near = opening_valve
		idle = RIGHT_RINSE_REST
		right_rotation = Vector3(-.51,.31,.48) if opening_valve else Vector3(.03,.12,.32)
	var right_arm: Node3D = arms[1]
	var turn_speed: float = 1.0-exp(-delta*24.0)
	var right_turn: Quaternion = (scraper_basis()*SCRAPER_MOUNT.basis.inverse()).get_rotation_quaternion() if scraping else Quaternion.from_euler(right_rotation)
	right_arm.quaternion = right_arm.quaternion.slerp(right_turn,turn_speed)
	var finger_pose: String = "pinch" if pinching or opening_valve else "tool" if brush_active else "reach" if is_near else "rest"
	if scraping:
		finger_pose = "scraper"
	right_arm.animate_fingers(finger_pose,delta)
	if scraping and is_near:
		var clearance: float = lerpf(.035,.0024,smoothstep(0.0,.88,scrape_pressure))
		if pressed:
			clearance += Yard.SCRAPERS[scraper_level].rattle*pow(maxf(0.0,sin(stroke_travel*73.0)),4.0)
		var tip: Vector3 = scrape_point(stroke_travel,clearance)
		if not on_glass:
			tip += Vector3(reach.x,-reach.y,0)*(1.0-scrape_pressure)
		close_at = tip-right_arm.basis*(SCRAPER_MOUNT*Shapes.SCRAPER_EDGE)
	elif action == "scrub" and glue_cleanup:
		var wipe_at: Vector3 = bottle.transform*Vector3(.019+reach.x*.44,.111,.051 if pressed else .073)
		close_at = wipe_at-right_arm.basis*CLOTH_MOUNT.origin
	elif opening_valve:
		var lever: Vector3 = to_local(source.wash_valve_tip())
		close_at = lever-right_arm.basis*right_arm.pinch_point()
	var reach_speed: float = 29.0 if opening_valve else 16.0
	wrist = wrist.lerp(close_at if is_near else idle,1.0-exp(-delta*reach_speed))
	if scraping and is_near:
		wrist = wrist.lerp(close_at,smoothstep(.46,.88,scrape_pressure))
	right_arm.position = wrist
	scraper.visible = scraping
	scraper.transform = right_arm.transform*SCRAPER_MOUNT
	if scraping:
		var profile: Dictionary = Yard.SCRAPERS[scraper_level]
		var max_flakes: int = profile.pieces+2*(scrape_passes-1)
		var flakes: int = mini(max_flakes,int(label_travel*max_flakes+.15))
		if flakes > emitted_flakes:
			source.drop_label_shavings(labels[type],scraper.to_global(Shapes.SCRAPER_EDGE),flakes-emitted_flakes,profile.shaving)
			emitted_flakes = flakes
	var body_radius: float = Shapes.radius_at(PROFILES[type],.064)
	var left_goal := Transform3D(Basis.from_euler(Vector3(-.21,-.72,-.93+bottle.rotation.z*.42)),
		bottle.position+Vector3(-.063-(body_radius-.045)*.80,.035,.029))
	var left_target := Transform3D(left_goal.basis,left_goal.origin-bottle.position)
	var left_finger_pose: String = "hold"
	if scraping or rinsing:
		var profile: int = RINSE_BRACE_PROFILE[type] if rinsing else type
		var mount: Transform3D = bottle_brace
		var grip_basis: Basis = bottle_grip_basis()
		if rinsing:
			mount.origin = RINSE_GRIP_MOUNTS[type]
			if left_grip_placed:
				# Carry the current grip with the bottle before blending in the new pose.
				left_grip = Transform3D(grip_basis*previous_bottle_basis.inverse(),Vector3.ZERO)*left_grip
		left_target = Transform3D(grip_basis,Vector3.ZERO)*mount
		left_finger_pose = "brace%d" % profile
	left_grip = left_grip.interpolate_with(left_target,blend) if left_grip_placed and not scraping else left_target
	left_grip_placed = true
	arms[0].transform = Transform3D(left_grip.basis,bottle.position+left_grip.origin)
	arms[0].animate_fingers(left_finger_pose,delta)
	var deposited: bool = cycle_running and progress > .16
	var up: Vector3 = global_basis.inverse()*Vector3.UP
	var forward: Vector3 = Vector3.FORWARD.slide(up).normalized()
	var right: Vector3 = forward.cross(up)
	for i in arms.size():
		arms[i].visible = not deposited
		if not deposited:
			var side: Vector3 = right*(1.0 if i == 1 else -1.0)
			var shoulder: Vector3 = side*.175-up*.223-forward*.095
			var elbow_hint: Vector3 = -up+side*.32-forward*.35
			arms[i].pose_arm(shoulder,elbow_hint)
	tool.visible = brush_active and action != "scrub"
	tool.transform = arms[1].transform * Transform3D(Basis.from_euler(Vector3(-.16,-.42,-.49+reach.x*3.8)),Vector3(-.012,.043,-.023))
	towel.visible = action == "scrub"
	towel.transform = right_arm.transform*CLOTH_MOUNT
	show_water(action)
	wet_glass.set_shader_parameter("wetness",wetness)
	update_art()


func bottle_height() -> float:
	return float(PROFILES[type].back()[0])


func show_water(action: String) -> void:
	var mouth: Vector3 = bottle.transform*(Vector3.UP*bottle_height())
	var tap: Vector3 = to_local(source.FAUCET)
	var flowing: bool = rinse_flowing() and action in RINSING and tap.distance_to(mouth) < .24
	var draining: bool = cycle_running and action == "drain" and progress > .20
	stream.visible = flowing
	var clear_water := Color(.63,.84,.91,.63)
	runoff.albedo_color = Color(.60,.48,.31,.75).lerp(clear_water,smoothstep(.24,.87,progress)) if flowing else clear_water
	if flowing:
		stream.position = (tap+mouth)*.5
		stream.quaternion = Quaternion(Vector3.UP,(tap-mouth).normalized())
		stream.scale.y = tap.distance_to(mouth)
	var down: Vector3 = global_basis.inverse()*Vector3.DOWN
	for i in water_drops.size():
		var drop: MeshInstance3D = water_drops[i]
		drop.visible = flowing or draining
		if drop.visible:
			var phase_fraction: float = fposmod(clock*(5.0 if flowing else 3.4)+i*.137,1.0)
			var spread: float = .045 if flowing else .012
			drop.position = mouth+down*(.016+phase_fraction*phase_fraction*.086)
			drop.position += Vector3(sin(i*3.1)*spread*phase_fraction,0,cos(i*2.3)*spread*phase_fraction)


func span(node: MeshInstance3D, a: Vector3, b: Vector3, radius: float) -> void:
	var direction: Vector3 = (b-a).normalized()
	node.position = (a+b)*.5
	node.quaternion = Quaternion(Vector3.UP,direction)
	node.scale = Vector3(radius,a.distance_to(b)*.5 + radius*.27,radius*.82)


func finger_joints(hand_index: int, finger: int, gesture: String) -> Array[Vector3]:
	if gesture in ["pinch","reach"]:
		if finger == 0:
			return [Vector3(-.025,.041,.001),Vector3(-.031,.063,.002),Vector3(-.033,.074,-.016),Vector3(-.024,.064,-.030)]
		if finger == 4:
			return [Vector3(-.026,.005,-.005),Vector3(-.042,.020,-.023),Vector3(-.035,.040,-.044),Vector3(-.024,.052,-.033)]
	var thumb: bool = finger == 4
	var side: float = -1.0 if hand_index == 0 else 1.0
	var a := Vector3((finger-1.5)*.0165*side,.041+[.001,.003,.001,-.005,0.0][finger],.001)
	if thumb:
		a = Vector3(side*-.024,.005,-.003)
	var curl_amount: float = {"hold":1.0,"pinch":1.12,"tool":1.32,"reach":.39,"rest":.54}[gesture]
	var tucked: bool = gesture in ["pinch","reach"] and finger in [1,2,3]
	var joints: Array[Vector3] = [a]
	var lengths: Array = FINGER_LENGTHS[finger]
	for j in lengths.size():
		var bend: float = curl_amount*(j+1)*.66
		var spread: float = (finger-1.4)*.073*side
		if tucked:
			bend = [.76,1.76,2.43][j]+.10*(finger-1)+(.21 if gesture == "pinch" else 0.0)
			spread = [-.15,-.115,0.0][j]
		var direction := Vector3(spread,cos(bend),-sin(bend))
		if thumb:
			var across: float = [-.48,-.01,.46][j]
			direction = Vector3(side*across,.73,-(.43+curl_amount*.22))
		a += direction.normalized()*lengths[j]
		joints.append(a)
	return joints


func update_art() -> void:
	label_mesh.visible = has_paper and (not label_removed or (scrape_release > 0.0 and label_travel < .995))
	label_material.set_shader_parameter("scraped",label_travel)
	var lettering_cut: float = label_travel*scrape_passes
	label_print.visible = label_mesh.visible and lettering_cut < .52
	label_print.modulate.a = .90*(1.0-smoothstep(.32,.52,lettering_cut))
	var action: String = task()
	var wipe: float = 1.0 if washed or surface_wiped else (progress if action == "scrub" else 0.0)
	wet_glass.set_shader_parameter("wipe_coverage",wipe)
	if is_instance_valid(marble):
		marble.position.x = -lean_goal * .027
	if type == 5:
		cap.rotation.x = lerp_angle(cap.rotation.x,-1.78 if cap_opened else 0.0,.25)
		if gasket_replaced:
			gasket_ring.material_override = clean_ring
		gasket_ring.visible = action != "gasket" or progress < .38


func clear() -> void:
	held = false
	release_action()
	rotating = false
	cycle_running = false
	visible = false
	bottle.hide()
	tool.hide()
	scraper.hide()
	towel.hide()
	stream.hide()
	for drop in water_drops:
		drop.hide()


func pose_carrying_crate(crate_position: Vector3, width: float, carrying: bool, delta: float) -> void:
	if held:
		return
	visible = carrying
	if not carrying:
		return
	for i in arms.size():
		var side: float = -1.0 if i == 0 else 1.0
		var arm: Node3D = arms[i]
		arm.show()
		arm.rotation = Vector3(-.83,side*.78,-side*.86)
		arm.position = crate_position+Vector3(side*(width*.5+.030),.080,.107)
		arm.animate_fingers("hold" if i == 0 else "rest",delta)
		arm.pose_arm(Vector3(side*.175,-.239,.092),Vector3(side*.36,-.55,.03))
