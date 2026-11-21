extends Node3D

const Yard = preload("res://yard.gd")
const Worksite = preload("res://worksite.gd")
const Handwork = preload("res://handwork.gd")
const HeadsUp = preload("res://hud.gd")
const DESK = Vector3(Worksite.STRIP_X,.02,1.27)
const START = Vector3(0,.02,2.72)
const WALK_FOV = 68.0
const DESK_FOV = 62.0
const SCRAPE_FOV = 34.1

var model := Yard.new()
var site := Worksite.new()
var hand := Handwork.new()
var ui := HeadsUp.new()
var player: CharacterBody3D
var camera: Camera3D
var camera_bob: float = 0.0
var working: bool = false
var work_button: MouseButton = MOUSE_BUTTON_NONE
var office: bool = false
var yaw: float = 0.0
var pitch: float = -.21
var elapsed: float = 0.0
var autosave: float = 0.0
var status: String = ""
var status_ttl: float = 0.0
var save_path: String
var is_test: bool
var sources: Dictionary = {}
var players: Array = []
var sounds: int = 0
var context: String = ""
var hand_key: OmniLight3D
var carried_box: Node3D
var scene_loading: bool = false
var journal_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED


func _ready() -> void:
	is_test = "--yard-playtest" in OS.get_cmdline_user_args()
	save_path = ProjectSettings.globalize_path("res://yard-save.json")
	if not OS.has_feature("editor"):
		save_path = OS.get_executable_path().get_base_dir().path_join("yard-save.json")
	var has_save: bool = not is_test and FileAccess.file_exists(save_path)
	if has_save:
		model.restore(JSON.parse_string(FileAccess.get_file_as_string(save_path)))
	add_child(site)
	site.build()
	make_player()
	var overlay := CanvasLayer.new()
	add_child(overlay)
	overlay.add_child(ui)
	ui.build()
	ui.action.connect(on_action)
	hand.sound_requested.connect(play_sound)
	hand.changed.connect(refresh)
	hand.checkpoint.connect(model.advance_held)
	build_sound()
	site.update_site(model,0.0)
	site.update_cart(model,player,working)
	get_tree().auto_accept_quit = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	refresh()
	if not has_save and not is_test:
		show_journal(true)
	fade_in_site()


func fade_in_site() -> void:
	if DisplayServer.get_name() == "headless":
		return
	scene_loading = true
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var curtain := ColorRect.new()
	curtain.color = Color("1a201c")
	curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(curtain)
	# Give the frame buffers and first-use shadows time to fill before revealing the room.
	for frame in 34:
		await RenderingServer.frame_post_draw
	var transition := layer.create_tween()
	transition.tween_property(curtain,"modulate:a",0.0,.18)
	await transition.finished
	layer.queue_free()
	scene_loading = false


func make_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Worker"
	player.floor_snap_length = .25
	add_child(player)
	var collision := CollisionShape3D.new()
	var collider := CapsuleShape3D.new()
	collider.radius = .28
	collider.height = 1.75
	collision.shape = collider
	collision.position.y = .875
	player.add_child(collision)
	player.position = START
	camera = Camera3D.new()
	camera.name = "Eye"
	camera.position.y = 1.60
	camera.rotation.x = pitch
	camera.current = true
	camera.near = .048
	camera.far = 115.0
	camera.fov = WALK_FOV
	player.add_child(camera)
	camera.add_child(hand)
	hand.build(camera,site,site.font)
	carried_box = site.finished_crate(Vector3(0,-.59,-.87),camera)
	carried_box.hide()
	hand_key = OmniLight3D.new()
	hand_key.position = Vector3(.28,.31,-.49)
	hand_key.omni_range = 1.3
	hand_key.light_color = Color("ffe6ca")
	hand_key.light_energy = .47
	hand_key.visible = false
	camera.add_child(hand_key)


func _physics_process(delta: float) -> void:
	if working:
		player.velocity = Vector3.ZERO
		return
	var direction: Vector3 = Vector3.ZERO
	if not office and not ui.journal.visible and not scene_loading and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		direction.x = float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
		direction.z = float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	var walk_speed: float = 2.65 if model.pushing_cart else (5.8 if Input.is_physical_key_pressed(KEY_SHIFT) else 3.45)
	var desired: Vector3 = Basis(Vector3.UP,yaw) * direction.normalized() * walk_speed
	player.velocity.x = move_toward(player.velocity.x,desired.x,delta*23.0)
	player.velocity.z = move_toward(player.velocity.z,desired.z,delta*23.0)
	player.velocity.y -= 18.0 * delta
	player.move_and_slide()
	if player.position.y < -2.8:
		player.position = START
		player.velocity = Vector3.ZERO
	var speed_squared: float = player.velocity.x * player.velocity.x + player.velocity.z * player.velocity.z
	if speed_squared > 0.05 and player.is_on_floor():
		camera_bob += delta * (10.7 if speed_squared < 18.0 else 14.1)
	var bob: float = sin(camera_bob) * minf(.025,speed_squared * .004)
	camera.position.y = lerpf(camera.position.y, 1.60 + bob, minf(1.0,delta*13.0))
	camera.rotation.z = lerpf(camera.rotation.z, sin(camera_bob*.5)*minf(.008,speed_squared*.0008), minf(1.0,delta*11.0))


func _process(delta: float) -> void:
	model.advance(delta)
	site.update_site(model,delta)
	site.room.animate(delta,player.position)
	site.update_cart(model,player,working)
	focus_work_area(delta)
	hand.pose(delta)
	update_carried_crate(delta)
	site.show_table_scraper(model.equipped_scraper,not (hand.held and hand.scraper.visible))
	site.animate_wash_area(hand.rinse_flowing(),
		hand.cycle_running and hand.task() == "sanitize",hand.progress,delta)
	hand_key.visible = working and hand.held
	status_ttl = maxf(0.0,status_ttl-delta)
	elapsed += delta
	if elapsed >= .15:
		elapsed = 0.0
		refresh()
	var prompt: String = ""
	var prompt_hint: String = ""
	if not working and not office:
		context = target_under_aim()
		var carrying: bool = model.carry_count() > 0
		if carrying:
			prompt = "已装 %d 只 · 前往脱标台" % model.carry_count()
		if model.transport_crate_count() > 0:
			prompt = "已装 %d 筐成品 · 滑门外右转是收购窗口" % model.transport_crate_count()
		if context == "stock":
			prompt = stock_prompt()
			if model.carry_count() < model.carry_capacity() and model.can_take():
				prompt_hint = "1–6 按瓶型取"
			if carrying:
				prompt_hint += "   ·   R 放回待处理瓶" if not prompt_hint.is_empty() else "R 放回待处理瓶"
		elif context != "":
			var options: Dictionary = {
				"bench":"E   从储物中拿一只处理" if carrying else "先到右侧滑门外的车库取瓶",
				"cart":"E   推小推车  ·  车上 %d 只散瓶 · %d 筐成品" % [model.parked_load.size(),model.cart_crates.size()],
				"clean_crate":crate_prompt(),
				"sale_window":"E   在收购窗口交货与结款", "office":"E   打开站务终端",
				"room_door":"E   关上滑门" if site.room.door_open else "E   打开滑门 · 通往车库",
			}
			if context == "bench":
				if not model.hand_crate.is_empty():
					options.bench = "先把手里的成品筐送到收购窗口"
				elif model.bench_crate.size() == model.crate_capacity():
					options.bench = "成品筐已满 · 对准筐按 E 搬走"
			prompt = options[context]
	ui.update_work(hand,working,Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,prompt,prompt_hint,
		status if status_ttl > 0.0 else "")
	autosave += delta
	if autosave >= 4.0:
		autosave = 0.0
		save()


func stock_prompt() -> String:
	if model.carry_count() >= model.carry_capacity():
		return "已装满 · 去脱标台处理"
	if not model.can_take():
		return "来料区已空"
	if model.carry_capacity() == 1:
		return "E  取一只空瓶"
	return "E  装满    ·    Shift + E  只拿一只"


func update_carried_crate(delta: float) -> void:
	var carrying: bool = not working and not model.hand_crate.is_empty()
	carried_box.visible = carrying
	if carrying:
		carried_box.sync(model.hand_crate,model.crate_capacity())
		var x: float = sin(camera_bob*.5)*.009
		var y: float = -.553+sin(camera_bob)*.008
		carried_box.position = Vector3(x,y,-.89)
	hand.pose_carrying_crate(carried_box.position,carried_box.dimensions.x,carrying,delta)


func crate_prompt() -> String:
	var count: int = model.bench_crate.size()
	var capacity: int = model.crate_capacity()
	var prompt: String = "成品筐 %d / %d" % [count,capacity]
	if count > 0:
		if model.pushing_cart:
			prompt += " · E 装上推车 %d / %d" % [model.cart_crates.size(),Yard.CART_CRATE_LIMIT]
		else:
			prompt += " · E 搬筐"
	var next: int = model.crate_level+1
	if next < Yard.CRATE_CAPACITIES.size():
		if model.delivered == 0:
			prompt += " · 首次出货后可升到 8 只"
		elif model.phase < Yard.CRATE_PHASES[next]:
			prompt += " · %s解锁 %d 只" % [Yard.AREA[Yard.CRATE_PHASES[next]],Yard.CRATE_CAPACITIES[next]]
		else:
			var cost: String = " ¥%d" % Yard.CRATE_COSTS[next] if Yard.CRATE_COSTS[next] > 0 else " 免费"
			prompt += " · F 升到 %d 只%s" % [Yard.CRATE_CAPACITIES[next],cost]
	return prompt


func focus_work_area(delta: float) -> void:
	var zoom_blend: float = 1.0-exp(-delta*10.0)
	if not working or not hand.held:
		camera.fov = lerpf(camera.fov,DESK_FOV if working else WALK_FOV,zoom_blend)
		return
	var action: String = hand.view_task()
	var close_up: bool = action == hand.SCRAPE_LABEL or (action == "scrub" and hand.glue_cleanup)
	var station_x: float = site.STRIP_X
	var eye: Vector3 = DESK+Vector3.UP*1.60
	var look := Vector3(site.STRIP_X,1.17,.19)
	if close_up:
		eye = DESK+Vector3(0,1.55,-.16)
		look = Vector3(site.STRIP_X,1.08,.42)
	elif action in hand.RINSING:
		station_x = site.RINSE_X
		eye = site.FAUCET+Vector3(-.070,.283,.621)
		look = site.FAUCET+Vector3.DOWN*.17
	elif action == "sanitize":
		station_x = site.STEAM_X
		eye = site.SANITIZER_TRAY+Vector3(-.145,.51,1.00)
		look = site.SANITIZER_TRAY+Vector3.UP*.17
	elif action == "drain":
		station_x = site.DRAIN_X
		eye = site.DRAIN_PIN+Vector3(0,.49,1.05)
		look = site.DRAIN_PIN+Vector3.UP*.11
	elif action in ["close","pack"]:
		station_x = site.PACK_X
		eye = site.CLEAN_CRATE+Vector3(0,.635,1.36)
		look = site.CLEAN_CRATE+Vector3(0,.19,.39)
	var current_hotspot: Vector2 = hand.hotspot()
	var previous_eye: Vector3 = camera.global_position
	var bottle_world: Transform3D = hand.bottle.global_transform
	var weight: float = 1.0-exp(-delta*11.0)
	var travel: float = minf(delta*4.4,previous_eye.distance_to(eye)*weight)
	player.position.x = move_toward(player.position.x,station_x,delta*3.2)
	camera.global_position = previous_eye.move_toward(eye,travel)
	var aim: Basis = Transform3D(Basis.IDENTITY,eye).looking_at(look).basis
	camera.quaternion = camera.quaternion.slerp(aim.get_rotation_quaternion(),weight)
	camera.fov = lerpf(camera.fov,SCRAPE_FOV if close_up else DESK_FOV,zoom_blend)
	if hand.cycle_running and action in ["sanitize","drain"]:
		hand.bottle.global_transform = bottle_world
	if hand.cursor.distance_to(current_hotspot) < 105.0:
		hand.cursor += hand.hotspot()-current_hotspot


func target_under_aim() -> String:
	var forward: Vector3 = -camera.global_basis.z
	var best: float = 1.0
	var choice: String = ""
	for id in site.targets:
		var entry: Dictionary = site.targets[id]
		var point: Vector3 = entry.position
		if id == "stock":
			point = site.garage.pickup_point(player.position,camera.global_position,forward)
			if not point.is_finite():
				continue
		var offset: Vector3 = point - camera.global_position
		var distance: float = offset.dot(forward)
		if distance < .20 or distance > entry.reach:
			continue
		var score: float = .15 if id == "stock" else (offset - forward * distance).length() / entry.radius
		if score < best and target_is_visible(point):
			best = score
			choice = id
	return choice


func target_is_visible(point: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(camera.global_position,point,1,[player.get_rid()])
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or (hit.position as Vector3).distance_to(point) < .15


func _input(event: InputEvent) -> void:
	if scene_loading:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_J or (ui.journal.visible and event.physical_keycode == KEY_ESCAPE):
			show_journal(not ui.journal.visible)
			get_viewport().set_input_as_handled()
			return
	if ui.journal.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if working and not office and event.physical_keycode in [KEY_ESCAPE,KEY_R,KEY_S]:
			leave_desk()
			get_viewport().set_input_as_handled()
			return
		match event.physical_keycode:
			KEY_ESCAPE:
				if office:
					show_office(false)
				else:
					Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				get_viewport().set_input_as_handled()
			KEY_TAB:
				show_office(not office)
				get_viewport().set_input_as_handled()
			KEY_E:
				if not office and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
					interact(event.shift_pressed)
					get_viewport().set_input_as_handled()
			KEY_F:
				if not office and not working and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and target_under_aim() == "clean_crate":
					if model.upgrade_crate():
						play_sound("snap")
						tell("成品筐已升级 · 每筐 %d 只" % model.crate_capacity())
						save()
					elif model.crate_level+1 < Yard.CRATE_CAPACITIES.size() and model.delivered == 0:
						tell("完成首次出货后可免费升到八只")
					elif model.crate_level+1 < Yard.CRATE_CAPACITIES.size() and model.phase >= Yard.CRATE_PHASES[model.crate_level+1]:
						tell("资金不足，先去收购窗口卖瓶")
					get_viewport().set_input_as_handled()
			KEY_R:
				if not office and model.carry_count() > 0:
					if target_under_aim() == "stock":
						var returned: int = model.unload_carried()
						tell("已把 %d 只放回来料区" % returned if returned > 0 else "成品请带回操作台装筐")
					else:
						tell("到车库来料区按 R 放回瓶子")
					get_viewport().set_input_as_handled()
			KEY_C:
				if not office and not working and model.pushing_cart:
					park_cart()
					get_viewport().set_input_as_handled()
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
				if not working and not office and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and target_under_aim() == "stock":
					take_bottle(event.physical_keycode - KEY_1,event.shift_pressed)
					get_viewport().set_input_as_handled()
	if office:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		if working:
			hand.drag(event.relative)
		else:
			yaw = wrapf(yaw - event.screen_relative.x * .00255,-PI,PI)
			pitch = clampf(pitch - event.screen_relative.y * .00255,-1.32,1.32)
			player.rotation.y = yaw
			camera.rotation.x = pitch
	if working and event is InputEventMouseButton:
		work_gesture(event.button_index,event.pressed)


func work_gesture(button: MouseButton, down: bool) -> void:
	if button not in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
		return
	if not down:
		if work_button == button:
			end_work_gesture()
			if hand.scrape_between_passes and button == MOUSE_BUTTON_RIGHT:
				hand.cursor = hand.hotspot()
		return
	if not hand.held:
		return
	end_work_gesture()
	work_button = button
	var scrape: bool = hand.task() == hand.SCRAPE_LABEL
	hand.rotating = button == (MOUSE_BUTTON_LEFT if scrape else MOUSE_BUTTON_RIGHT)
	if not hand.rotating:
		hand.press_action()


func end_work_gesture() -> void:
	work_button = MOUSE_BUTTON_NONE
	hand.release_action()
	hand.rotating = false


func interact(single_bottle: bool = false) -> void:
	if working:
		if hand.done or hand.quality == 2:
			place_bottle()
		return
	match target_under_aim():
		"stock": take_bottle(-1,single_bottle)
		"cart":
			if not model.push_cart():
				var over: int = model.carry_count() + model.parked_load.size() - Yard.CART_CAPACITY
				if over > 0:
					tell("推车装不下 · 先处理或放回 %d 只散瓶" % over)
				else:
					tell("车上已有三筐，先把手里的这筐送到收购窗口")
				return
			site.update_cart(model,player,working)
			tell("开始推车 · 可装 %d 只散瓶和三筐成品 · C 停车" % Yard.CART_CAPACITY)
		"clean_crate":
			if model.take_crate():
				play_sound("take")
				tell("成品已装上车 %d / %d" % [model.cart_crates.size(),Yard.CART_CRATE_LIMIT] if model.pushing_cart else "已搬起成品筐 · 滑门外右转去收购窗口")
				save()
			elif model.bench_crate.is_empty():
				tell("筐里还没有成品瓶")
			else:
				tell("推车已装满三筐" if model.pushing_cart else "先把手里的这筐送到收购窗口")
		"bench":
			if not model.carried.is_empty():
				approach_desk()
			else:
				tell("从右侧滑门进车库取瓶")
		"sale_window": show_office(true,true)
		"office": show_office(true)
		"room_door":
			if site.room.toggle(player.position):
				status_ttl = 0.0
				play_sound("snap")
			else:
				tell("离开门口再关滑门")


func approach_desk() -> void:
	if not model.hand_crate.is_empty():
		tell("先把手里的成品筐送到收购窗口")
		return
	if not model.carried.is_empty() and model.bench_crate.size() == model.crate_capacity() and model.grade(model.carried.front().x) != 2:
		tell("成品筐已满 · 对准筐按 E 搬走，再处理下一只")
		return
	if not model.begin_carried():
		return
	working = true
	player.velocity = Vector3.ZERO
	player.position = DESK
	yaw = 0.0
	pitch = -.395
	player.rotation = Vector3.ZERO
	camera.rotation = Vector3(pitch,0,0)
	camera.position = Vector3(0,1.60,0)
	status_ttl = 0.0
	hand.wrist = Vector3(.21,-.34,-.49)
	hand.load_bottle(model.held,model.held_queue,model.equipped_scraper)


func take_bottle(selected: int = -1, single_bottle: bool = false) -> void:
	if model.carry_count() >= model.carry_capacity():
		tell("已装满，前往脱标台处理")
		return
	var taken: int = model.collect(selected,1 if single_bottle else model.carry_capacity())
	if taken == 0:
		tell("来料区暂时空了" if selected < 0 else "来料区暂时没有" + Yard.NAMES[selected])
		return
	play_sound("take")
	tell("已取 %d 只散瓶" % taken)


func park_cart() -> void:
	model.park_cart(site.cart.position,site.cart.rotation.y)
	site.update_cart(model,player,working)
	tell("已停车 · 车上保留 %d 只散瓶和 %d 筐成品" % [model.parked_load.size(),model.cart_crates.size()])


func place_bottle() -> void:
	var discard: bool = hand.quality == 2
	if not model.set_down():
		tell("成品筐已满")
		return
	if discard:
		var bottle: Node3D = hand.bottle.duplicate(0)
		site.add_child(bottle)
		bottle.global_transform = hand.bottle.global_transform
		var start: Vector3 = bottle.position
		var destination: Vector3 = site.SCRAP_BIN+Vector3(0,.24,.115)
		var tween := create_tween()
		tween.tween_method(func(t: float) -> void:
			bottle.position = start.lerp(destination,t) + Vector3.UP * sin(t*PI)*.07
			bottle.rotation.z = sin(t*PI)*.23,0.0,1.0,.34)
		tween.tween_callback(func() -> void:
			play_sound("scrap")
			bottle.queue_free())
	else:
		site.clean_box.sync(model.bench_crate,model.crate_capacity())
		play_sound("glass")
	end_desk()
	var result: String = "裂瓶已投入碎玻璃桶" if discard else "已放入成品筐 %d / %d" % [model.bench_crate.size(),model.crate_capacity()]
	var next: String = "对准成品筐按 E 搬去收购窗口"
	if model.bench_crate.size() == model.crate_capacity():
		next = "筐满了 · 对准筐按 E 搬走"
	elif model.carry_count() > 0:
		next = "回脱标台处理下一只"
	elif model.can_take():
		next = "回车库取下一批"
	tell(result + " · " + next)


func leave_desk() -> void:
	if not working:
		return
	model.stow_held()
	end_desk()
	tell("已离开操作台 · 瓶子收回随身储物")
	save()


func end_desk() -> void:
	end_work_gesture()
	hand.clear()
	if not working:
		return
	working = false
	pitch = -.17
	camera.fov = WALK_FOV
	camera.rotation = Vector3(pitch,0,0)
	camera.position = Vector3(0,1.60,0)


func show_office(open: bool, sales: bool = false) -> void:
	end_work_gesture()
	office = open
	ui.office.visible = open
	ui.show_sales(open and sales,model)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED
	refresh()


func show_journal(open: bool) -> void:
	if ui.journal.visible == open:
		return
	end_work_gesture()
	ui.journal.visible = open
	if open:
		journal_mouse_mode = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		read_journal(model.story_chapter())
	else:
		Input.mouse_mode = journal_mouse_mode
		refresh()
		save()


func read_journal(chapter: int) -> void:
	if ui.journal.visible and chapter >= 0 and chapter <= model.story_chapter():
		ui.journal_index = chapter
		model.story_read = maxi(model.story_read,chapter)
		refresh()


func on_action(id: String, value: int) -> void:
	match id:
		"close_journal":
			show_journal(false)
			return
		"journal_chapter":
			read_journal(value)
			return
		"close": show_office(false)
		"open_operations": show_office(true)
		"open_tools":
			show_office(true)
			ui.show_tools(model)
		"choose_scraper":
			var purchasing: bool = value > model.owned_scraper
			if model.choose_scraper(value):
				play_sound("snap")
				var name: String = Yard.SCRAPERS[value].name
				tell(("已购入并装备" if purchasing else "已装备") + name + ("，下一瓶生效" if hand.held else ""))
		"upgrade_bag":
			if not ui.office_board.is_visible_in_tree() or not model.upgrade_bag():
				return
			play_sound("snap")
			tell("背包已升级 · 可带 %d 只散瓶" % model.bag_capacity())
		"receive":
			if model.receive():
				play_sound("snap")
				if model.phase == Yard.BAG_UPGRADE_PHASE and model.can_upgrade_bag():
					tell("街区散货已入库 · 可升级背包")
				else:
					tell("货车已开始进站" if model.phase >= 3 else "这一批来料已入库")
		"buy":
			if model.buy(value):
				play_sound("snap")
				tell(Yard.EQUIPMENT[value] + "已安装")
		"feed":
			if model.installed[0]:
				tell("已分拣上料 %s 只" % ui.comma(model.bulk_feed()))
		"wash":
			tell("已清洗 %s 只" % ui.comma(model.bulk_wash()))
		"sanitize":
			tell("已消毒 %s 只" % ui.comma(model.bulk_sanitize()))
		"inspect":
			tell("已沥干验瓶 %s 只" % ui.comma(model.bulk_finish()))
		"pack_for_sale":
			if not ui.market.is_visible_in_tree():
				return
			var packed: int = model.stage_for_sale()
			if packed > 0:
				play_sound("glass")
				ui.select_available_buyer(model)
				tell("已交接批量成品 %s 只，请选择收购单。" % ui.comma(packed))
		"unload_finished":
			if not ui.market.is_visible_in_tree():
				return
			var unloaded: int = model.unload_finished()
			if unloaded > 0:
				play_sound("glass")
				ui.select_available_buyer(model)
				tell("窗口已收下 %s 只，确认出售后结款。" % ui.comma(unloaded))
		"select_buyer":
			ui.selected_buyer = value
			refresh()
			return
		"confirm_sale":
			if not ui.market.is_visible_in_tree():
				return
			var buyer: int = ui.selected_buyer
			var sale: Vector2i = model.sell_to(buyer)
			if sale.x > 0:
				play_sound("sale")
				ui.select_available_buyer(model)
				tell("已售给%s %s 只 · 到账 ¥ %s" % [Yard.BUYERS[buyer],ui.comma(sale.x),ui.format_cash(sale.y)])
		"wait_market":
			if not ui.market.is_visible_in_tree() or not model.market_wait_available():
				return
			model.turn_market_day()
			ui.select_available_buyer(model)
			tell("进入收购第 %d 天，报价和额度已更新" % model.market_day)
		"auto_sales":
			if not ui.market.is_visible_in_tree():
				return
			model.enable_auto_sales(not model.auto_sales)
			tell("已开启自动接单、出货和结款" if model.auto_sales else "自动销售已关闭")
		"priority":
			model.priority = value
		"speed":
			model.rush = {1:4,4:12,12:1}[model.rush]
	refresh()
	save()


func refresh() -> void:
	ui.update_model(model,status if status_ttl > 0.0 else "")


func tell(message: String) -> void:
	status = message
	status_ttl = 2.5
	refresh()


func save() -> void:
	if is_test or save_path.is_empty():
		return
	var temporary: String = save_path.get_basename() + ".tmp"
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(model.serialize()))
	file.close()
	DirAccess.rename_absolute(temporary,save_path)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save()
		get_tree().quit()


func build_sound() -> void:
	var durations: Dictionary = {"glass":.27,"take":.11,"paper":.16,"brush":.14,"water":.18,"snap":.16,"scrap":.32,"sale":.27,
		"scrape_dull":.12,"scrape_steel":.10,"scrape_curve":.13,"scrape_spring":.10}
	for id in durations:
		var sound := AudioStreamWAV.new()
		sound.format = AudioStreamWAV.FORMAT_16_BITS
		sound.mix_rate = 24000
		var samples := PackedByteArray()
		var count: int = int(durations[id] * sound.mix_rate)
		samples.resize(count * 2)
		var rng := RandomNumberGenerator.new()
		rng.seed = 23064 + id.hash()
		var filtered: float = 0.0
		for i in count:
			var t: float = float(i) / sound.mix_rate
			var x: float = rng.randf_range(-1.0,1.0)
			filtered = lerp(filtered,x,.19)
			var onset: float = minf(1.0,t/.002)
			var tail: float = minf(1.0,(durations[id]-t)/.023)
			var envelope: float = onset*exp(-t*(14.0 if id in ["glass","scrap"] else 28.0))*tail
			var sample: float = 0.0
			match id:
				"glass","take","scrap":
					sample = .54*sin(TAU*1731*t) + .26*sin(TAU*2678*t) + .15*sin(TAU*3287*t)
					sample += (.25 if id == "scrap" else .085)*x
				"snap":
					sample = .65*x + .22*sin(TAU*390*t)
				"sale":
					var pitch_hz: float = 830.0 if t < .069 else 1245.0
					sample = .55*sin(TAU*pitch_hz*t)+.11*sin(TAU*pitch_hz*2.0*t)
				"water":
					sample = .31*x + filtered*.51
				"brush":
					sample = .44*x + .45*filtered
				"scrape_dull":
					sample = (.42*x+.50*filtered+.18*sin(TAU*810*t))*(.60+.40*cos(TAU*93*t))
				"scrape_steel":
					sample = .58*x+.19*filtered+.19*sin(TAU*2170*t)*exp(-45.0*t)
				"scrape_curve":
					sample = (.20*x+.72*filtered+.06*sin(TAU*1070*t))*smoothstep(0.0,.012,t)
				"scrape_spring":
					sample = .24*x+.39*filtered+.48*sin(TAU*1570*t)*exp(-122.0*t)
				"paper":
					sample = (.46*x+.43*filtered) * (0.55+0.45*sin(TAU*91*t))
			samples.encode_s16(i*2,int(clampf(sample*envelope,-1.0,1.0)*32767.0))
		sound.data = samples
		sources[id] = sound
	for i in 7:
		var stream := AudioStreamPlayer.new()
		add_child(stream)
		players.append(stream)


func play_sound(id: String) -> void:
	if DisplayServer.get_name() == "headless" or not sources.has(id):
		return
	var stream: AudioStreamPlayer = players[sounds % players.size()]
	sounds += 1
	stream.stream = sources[id]
	stream.pitch_scale = randf_range(.91,1.10)
	stream.volume_db = -15.0 if id in ["brush","water","paper"] or id.begins_with("scrape_") else -13.0
	stream.play()
