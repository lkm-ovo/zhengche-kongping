extends Node3D

const Yard = preload("res://yard.gd")
const Worksite = preload("res://worksite.gd")
const Handwork = preload("res://handwork.gd")
const HeadsUp = preload("res://hud.gd")
const DESK = Vector3(Worksite.STRIP_X,.02,1.27)
const START = Vector3(0,.02,2.72)
const WALK_FOV = 68.0
const DESK_FOV = 62.0
const SCRAPE_FOV = 36.5

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
	var desired: Vector3 = Basis(Vector3.UP,yaw) * direction.normalized() * (5.8 if Input.is_physical_key_pressed(KEY_SHIFT) else 3.45)
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
	focus_work_area(delta)
	hand.pose(delta)
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
	if working:
		prompt = "拿下一只空瓶" if model.can_take() else "来料已处理完 · E 查看成品销售"
	elif not office:
		context = target_under_aim()
		if context != "":
			var options: Dictionary = {
				"bench":"E   拿一只空瓶", "stock":"E   从来料筐取瓶",
				"ship":"E   查看成品销售", "sale_shelf":"E   查看待售区与收购单", "office":"E   打开站务终端",
				"room_door":"E   关上滑门" if site.room.door_open else "E   打开滑门",
			}
			prompt = options[context]
	ui.update_work(hand,working,Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,prompt,
		status if status_ttl > 0.0 else "")
	autosave += delta
	if autosave >= 4.0:
		autosave = 0.0
		save()


func focus_work_area(delta: float) -> void:
	var zoom_blend: float = 1.0-exp(-delta*10.0)
	if not working or not hand.held:
		camera.fov = lerpf(camera.fov,DESK_FOV if working else WALK_FOV,zoom_blend)
		return
	var action: String = hand.view_task()
	var scraping: bool = action == hand.SCRAPE_LABEL
	var station_x: float = site.STRIP_X
	var eye: Vector3 = DESK+Vector3.UP*1.60
	var look := Vector3(site.STRIP_X,1.17,.19)
	if scraping:
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
	camera.fov = lerpf(camera.fov,SCRAPE_FOV if scraping else DESK_FOV,zoom_blend)
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
		var offset: Vector3 = entry.position - camera.global_position
		var distance: float = offset.dot(forward)
		if distance < .20 or distance > entry.reach:
			continue
		var score: float = (offset - forward * distance).length() / entry.radius
		if score < best and target_is_visible(entry.position):
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
		match event.physical_keycode:
			KEY_ESCAPE:
				if office:
					show_office(false)
				elif working:
					leave_desk()
				else:
					Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				get_viewport().set_input_as_handled()
			KEY_TAB:
				show_office(not office)
				get_viewport().set_input_as_handled()
			KEY_E:
				if not office and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
					interact()
					get_viewport().set_input_as_handled()
			KEY_R:
				if working and not office and hand.held:
					if hand.done or hand.quality == 2:
						place_bottle()
					else:
						model.return_held()
						hand.clear()
						tell("已放回当前工序")
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
				if working and not office and not hand.held:
					take_bottle(event.physical_keycode - KEY_1)
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


func interact() -> void:
	if working:
		if not hand.held:
			if model.can_take():
				take_bottle()
			else:
				show_office(true,true)
		elif hand.done or hand.quality == 2:
			place_bottle()
		else:
			tell("清洗、消毒并沥干后才能装筐")
		return
	match target_under_aim():
		"bench","stock": approach_desk()
		"ship","sale_shelf": show_office(true,true)
		"office": show_office(true)
		"room_door":
			if site.room.toggle(player.position):
				play_sound("snap")
			else:
				tell("离开门口再关滑门")


func approach_desk() -> void:
	working = true
	player.velocity = Vector3.ZERO
	player.position = DESK
	yaw = 0.0
	pitch = -.395
	player.rotation = Vector3.ZERO
	camera.rotation = Vector3(pitch,0,0)
	camera.position = Vector3(0,1.60,0)
	take_bottle()


func take_bottle(selected: int = -1) -> void:
	var taken: Vector2i = model.take(selected)
	if taken.x < 0:
		tell("来料筐暂时空了" if selected < 0 else "来料筐里暂时没有" + Yard.NAMES[selected])
		return
	end_work_gesture()
	hand.wrist = Vector3(.21,-.34,-.49)
	hand.load_bottle(taken.x,taken.y,model.equipped_scraper)
	play_sound("take")


func place_bottle() -> void:
	var discard: bool = hand.quality == 2
	if not model.set_down():
		return
	var bottle: Node3D = hand.bottle.duplicate(0)
	site.add_child(bottle)
	bottle.global_transform = hand.bottle.global_transform
	var start: Vector3 = bottle.position
	var destination: Vector3 = site.CLEAN_CRATE+Vector3.UP*.043 if not discard else site.SCRAP_BIN+Vector3(0,.24,.115)
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		bottle.position = start.lerp(destination,t) + Vector3.UP * sin(t*PI)*.07
		bottle.rotation.z = sin(t*PI)*.23,0.0,1.0,.34)
	tween.tween_callback(func() -> void:
		play_sound("scrap" if discard else "glass")
		bottle.queue_free())
	hand.clear()
	tell("已放入成品筐" if not discard else "裂瓶已投入碎玻璃桶")


func leave_desk() -> void:
	end_work_gesture()
	if hand.held and (hand.done or hand.quality == 2):
		place_bottle()
	else:
		model.return_held()
	hand.clear()
	working = false
	pitch = -.17
	camera.rotation.x = pitch
	camera.rotation.y = 0.0
	camera.position = Vector3(0,1.60,0)
	refresh()


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
		"open_sales": show_office(true,true)
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
		"receive":
			if model.receive():
				play_sound("snap")
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
			var packed: int = model.stage_for_sale()
			if packed > 0:
				play_sound("glass")
				ui.select_available_buyer(model)
				tell("已送入待售区 %s 只，选择收购单完成出售。" % ui.comma(packed))
		"select_buyer":
			ui.selected_buyer = value
			refresh()
			return
		"confirm_sale":
			var buyer: int = ui.selected_buyer
			var sale: Vector2i = model.sell_to(buyer)
			if sale.x > 0:
				play_sound("sale")
				ui.select_available_buyer(model)
				tell("已售给%s %s 只 · 到账 ¥ %s" % [Yard.BUYERS[buyer],ui.comma(sale.x),ui.comma(sale.y)])
		"auto_sales":
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
