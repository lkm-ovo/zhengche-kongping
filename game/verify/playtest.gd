extends SceneTree

const Yard = preload("res://yard.gd")
const Shapes = preload("res://workshop_shapes.gd")
const Game = preload("res://main.tscn")

var game
var failures: int = 0
var checks: int = 0
var pictures: bool
var preview_dir: String


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	pictures = "--qa-render" in OS.get_cmdline_user_args()
	preview_dir = ProjectSettings.globalize_path("res://../build/preview/")
	game = Game.instantiate()
	root.add_child(game)
	# Camera and gestures are scripted here. Keep native mouse motion out of the render run.
	game.set_process_input(false)
	await process_frame
	await process_frame
	check(game.model.sum_queue(Yard.RAW) == 72, "72-bottle opening")
	check(game.model.available(0) == 36 and game.model.available(1) == 24 and game.model.available(2) == 12, "starter mix 36/24/12")
	check(game.site.garage.count_sign.text == "72 只待取" and game.ui.objective.text.contains("72"),"the garage and HUD show the opening stock")
	check(game.ui.detail.text.contains("刮标签、擦残胶") and game.ui.equipment_notice.visible and
		game.ui.machine_buttons.all(func(item: Button) -> bool: return item.disabled),
		"the opening explains scraping and wiping while all machines are locked")
	check(garage_visible_stock() == 72 and game.site.garage.floor_bodies[0].visible_instance_count == 36 and
		game.site.garage.floor_bodies[1].visible_instance_count == 24 and game.site.garage.floor_bodies[2].visible_instance_count == 12,
		"the floor pile renders each of the 72 starter bottles")
	var top_bottle: Transform3D = game.site.garage.floor_poses[71]
	check(game.site.garage.floor_poses[0].origin.y < .085 and (top_bottle*(Vector3.UP*.143)).y > .28,
		"the starting pile grows upwards from bottles on the floor")
	check(game.ui.carry_title.text.contains("0 / 1") and not game.site.cart.visible,
		"the worker starts with exactly one storage slot and no cart")
	check(game.ui.bag_upgrade.disabled and not game.model.upgrade_bag(),
		"the backpack upgrade is locked until the street shipment arrives")
	check(game.camera.current and game.player is CharacterBody3D, "first-person character and camera")
	while game.scene_loading:
		await process_frame
	await capture("01-worksite")
	await verify_opening_journal()
	verify_opening_machine_lock()
	verify_line_layout()
	await verify_room()
	await verify_sale_window()
	if pictures:
		var initial_z: float = game.player.position.z
		key(KEY_W,true)
		for i in 55:
			await physics_frame
		key(KEY_W,false)
		check(game.player.position.z < initial_z - .7, "W moves the worker")
		check(game.player.position.z > .67, "the workbench has a physical collision")
	aim_at_station("bench")
	check(game.target_under_aim() == "bench", "aim at the physical workbench")
	game.interact()
	check(not game.working and game.model.held < 0, "an empty-handed worker cannot take a bottle at the workbench")
	game.camera.look_at(game.site.targets.stock.position)
	check(game.target_under_aim() != "stock", "the intake cannot be reached from the scraping station")
	await enter_garage()
	check(game.target_under_aim() == "stock", "the intake can be targeted from the garage aisle")
	var aisle: Vector3 = game.player.position
	var garage_center: Vector3 = game.site.garage.FLOOR_CENTER
	game.player.position = Vector3(garage_center.x+2.12,.02,garage_center.z)
	game.camera.look_at(garage_center+Vector3(1.22,.13,0))
	check(game.target_under_aim() == "stock","the bottles are also reachable from the far side of the garage floor")
	game.player.position = Vector3(8.85,.02,1.25)
	game.camera.look_at(game.site.garage.SIGN_CENTER)
	check(game.target_under_aim() == "stock" and game.site.garage.reverse_count_sign.text == game.site.garage.count_sign.text,
		"the back of the stock sign can be aimed at and shows the same inventory")
	game.player.position = aisle
	game.camera.look_at(game.site.garage.FLOOR_CENTER+Vector3.UP*.10)
	if game.target_under_aim() != "stock":
		game.camera.look_at(game.site.targets.stock.position)
	await capture("32-starter-intake")
	game.interact()
	game.interact()
	check(not game.working and not game.hand.held and game.model.carry_count() == 1 and game.model.sum_queue(Yard.RAW) == Yard.STARTER_SIZE-1,
		"E at the intake stores exactly one bottle and leaves the worker free to walk")
	game.site.update_site(game.model,0.0)
	check(game.site.garage.count_sign.text == "71 只待取" and garage_visible_stock() == 71 and game.ui.carry_title.text.contains("1 / 1"),
		"taking a bottle removes one rendered bottle and fills the starter storage")
	check(game.site.garage.floor_kinds[71] == -1,"taking a bottle removes a top slot from the floor pile")
	if pictures:
		game.yaw = PI*.5
		game.player.rotation.y = game.yaw
		game.camera.look_at(game.site.targets.room_door.position)
		key(KEY_W,true)
		for frame in 48:
			await physics_frame
		key(KEY_W,false)
		check(game.player.position.x < 2.20 and game.model.carry_count() == 1,
			"the worker walks back through the sliding door with the bottle in storage")
	aim_at_station("bench")
	game.interact()
	check(game.working and game.hand.held and game.hand.task() == "scrape_label", "a carried beer bottle enters the scraping station")
	if not game.hand.held:
		quit(1)
		return
	var adhesive_strength: float = game.hand.wet_glass.get_shader_parameter("adhesive_strength")
	check(adhesive_strength > 0.0 and game.hand.label_mesh.visible and is_zero_approx(game.hand.label_travel),
		"adhesive is already on the glass beneath the intact label")
	check(game.hand.arms[0].skeleton.find_bone("SleeveUpperArm") >= 0 and
		game.hand.arms[1].skeleton.find_bone("SleeveForearm") >= 0 and
		game.hand.arms[1].hand_mesh.mesh.surface_get_array_len(0) > 5000,
		"both hands load the skinned anatomical mesh")
	await hand_frames(26)
	var frame_size: Vector2 = root.get_visible_rect().size
	var bottle_base: Vector2 = game.camera.unproject_position(game.hand.bottle.global_position)
	var bottle_mouth: Vector2 = game.camera.unproject_position(game.hand.bottle.to_global(Vector3.UP*game.hand.bottle_height()))
	var scrape_target: Vector2 = game.hand.hotspot()
	var label_middle: Vector2 = game.camera.unproject_position(game.hand.to_global(game.hand.scrape_point(.50)))
	check(game.camera.fov < 34.9 and game.camera.rotation.x < -.55 and
		bottle_base.y-bottle_mouth.y > frame_size.y*.74 and bottle_base.y < frame_size.y*.82 and bottle_mouth.y > 12.0,
		"scraping leans in and frames the whole bottle above the work panel")
	check(game.hand.scrape_point(0.0).distance_to(game.hand.scrape_point(1.0)) > .11 and game.hand.aim_radius() > 70.0,
		"the scrape covers a taller band and the pointer has a wider active area")
	check(label_middle.distance_to(frame_size*.5) < frame_size.y*.10 and scrape_target.y < label_middle.y and
		game.hand.cursor.distance_to(scrape_target) < 8.0, "the cursor stays aligned with the top of the wider label during zoom")
	await capture("02-hold",8)
	var resting_edge: Vector3 = game.hand.scraper.transform*Shapes.SCRAPER_EDGE
	game.hand.drag(Vector2(50,40))
	await hand_frames(12)
	check(is_zero_approx(game.hand.progress) and resting_edge.distance_to(game.hand.scraper.transform*Shapes.SCRAPER_EDGE) > .018,
		"moving the mouse with neither button held moves the lifted scraper without removing label")
	work_mouse(MOUSE_BUTTON_LEFT,true)
	check(game.hand.rotating and not game.hand.pressed and is_zero_approx(game.hand.progress), "left mouse turns a bottle during scraping")
	work_mouse(MOUSE_BUTTON_LEFT,false)
	var label_turn: Basis = game.hand.bottle.basis
	var cutting_line: Vector3 = game.hand.scrape_point(.5)
	game.hand.bottle.basis = label_turn*Basis(Vector3.UP,.36)
	check(game.hand.edge_visible() and game.hand.scrape_point(.5).distance_to(cutting_line) < .001,
		"turning the label under the scraper keeps the cutting line clear of the brace")
	game.hand.bottle.basis = label_turn*Basis(Vector3.UP,PI)
	game.hand.cursor = game.hand.hotspot()
	work_mouse(MOUSE_BUTTON_RIGHT,true)
	check(not game.hand.edge_visible() and not game.hand.pressed, "can't scrape a label facing away from the player")
	work_mouse(MOUSE_BUTTON_RIGHT,false)
	game.hand.bottle.basis = label_turn
	game.hand.cursor = game.hand.hotspot()
	work_mouse(MOUSE_BUTTON_RIGHT,true)
	await hand_frames(3)
	check(game.hand.scrape_pressure > 0.0 and game.hand.scrape_pressure < .8,"the blade approaches before it touches the glass")
	var leave := InputEventKey.new()
	leave.physical_keycode = KEY_ESCAPE
	leave.pressed = true
	game._input(leave)
	check(not game.working and not game.hand.pressed and game.work_button == MOUSE_BUTTON_NONE and
		game.model.carried[0].y == Yard.RAW,"Escape releases the active scraper and leaves the unfinished bottle in storage")
	work_mouse(MOUSE_BUTTON_RIGHT,false)
	aim_at_station("bench")
	game.interact()
	var stain_seed: float = game.hand.wet_glass.get_shader_parameter("stain_seed")
	await hand_frames(26)
	game.hand.cursor = game.hand.hotspot()
	work_mouse(MOUSE_BUTTON_RIGHT,true)
	await hand_frames(16)
	var start: Vector3 = game.hand.scraper.transform*Shapes.SCRAPER_EDGE
	var start_height: float = (game.hand.bottle.transform.affine_inverse()*start).y
	check(start.distance_to(game.hand.scrape_point(0.0)) < .004 and game.hand.scraper.visible and
		not game.site.table_scraper.visible,"the handheld scraper rests against the label")
	await capture("14-scraper-on-label")
	check(is_zero_approx(game.hand.progress), "holding the right mouse button without dragging cannot scrape")
	game.hand.drag(Vector2(0,900))
	await hand_frames(3)
	check(game.hand.progress > 0.0 and game.hand.progress < .015, "a fast downward flick only scrapes a tiny section")
	scrape_distance(117)
	check(game.hand.scrape_passes == 10 and game.hand.progress > .06 and game.hand.progress < .075,
		"the starter blade needs ten passes on a paper label")
	await hand_frames(18)
	check(game.ui.work_percent.text.contains("%") and game.ui.work_prompt.text.contains("沿箭头") and (not pictures or game.ui.scrape_guide),
		"scraping shows live progress and a downward drag guide")
	var scraped: Vector3 = game.hand.scraper.transform*Shapes.SCRAPER_EDGE
	var scraped_height: float = (game.hand.bottle.transform.affine_inverse()*scraped).y
	check(start_height-scraped_height > .032 and scraped.distance_to(game.hand.scrape_point(game.hand.stroke_travel)) < .004,
		"the scraper edge slides down against the glass")
	check(game.hand.cursor.distance_to(game.hand.hotspot()) < 1.0, "the scrape cursor follows the blade during the stroke")
	check(game.hand.label_mesh.visible and game.hand.label_material.get_shader_parameter("scraped") > .06 and
		not game.site.label_offcuts.is_empty(),"the scraped band reveals glass and drops small flakes")
	var left: Node3D = game.hand.arms[0]
	var largest_gap: float = 0.0
	var tightest_knuckle: float = INF
	var right: Node3D = game.hand.arms[1]
	var hand_to_handle: Transform3D = game.hand.SCRAPER_MOUNT.affine_inverse()
	var left_to_brace: Transform3D = Transform3D(game.hand.bottle_grip_basis(),game.hand.bottle.position).affine_inverse()*left.transform
	var previous_pad_y: float = INF
	var front_thumb: Vector3 = left_to_brace*left.fingertip_pad(4)
	var left_fingers_wrap: bool = front_thumb.z > .020
	var right_fingers_wrap: bool = true
	var joints_relaxed: bool = true
	for digit in 5:
		var pad: Vector3 = game.hand.bottle.transform.affine_inverse()*(left.transform*left.fingertip_pad(digit))
		largest_gap = maxf(largest_gap,absf(Vector2(pad.x,pad.z).length()-game.hand.wrap_radius(pad.y)))
		for link in [1,2]:
			var joint: Vector3 = left.finger_poses[digit*3+link].origin
			var at: Vector3 = game.hand.bottle.transform.affine_inverse()*(left.transform*joint)
			tightest_knuckle = minf(tightest_knuckle,Vector2(at.x,at.z).length()-game.hand.wrap_radius(at.y))
			var joint_limit: float = deg_to_rad(40.0 if digit == 4 else 70.0 if link == 1 else 46.0)
			for arm in [left,right]:
				var before: Vector3 = arm.finger_poses[digit*3+link-1].basis.y
				var after: Vector3 = arm.finger_poses[digit*3+link].basis.y
				joints_relaxed = joints_relaxed and before.angle_to(after) < joint_limit
		if digit < 4:
			var brace_pad: Vector3 = left_to_brace*left.fingertip_pad(digit)
			left_fingers_wrap = left_fingers_wrap and brace_pad.z < -.025 and brace_pad.y < front_thumb.y
			var tool_pad: Vector3 = hand_to_handle*right.fingertip_pad(digit)
			right_fingers_wrap = right_fingers_wrap and absf(tool_pad.x-.014) < .006 and absf(tool_pad.z) < .012 and tool_pad.y < previous_pad_y
			previous_pad_y = tool_pad.y
	check(largest_gap < .010 and tightest_knuckle > .003, "left fingertips brace the bottle with the knuckles outside the glass")
	check(left_fingers_wrap, "the left thumb sits high on the near side with four fingers around the back")
	var thumb_root: int = left.skeleton.find_bone("Digit4_0")
	var thumb_rest: Quaternion = left.skeleton.get_bone_rest(thumb_root).basis.get_rotation_quaternion()
	var thumb_pose: Quaternion = left.skeleton.get_bone_pose_rotation(thumb_root)
	check(thumb_rest.angle_to(thumb_pose) < deg_to_rad(15.0), "the thumb base stays close to its relaxed angle at the palm")
	check(right_fingers_wrap and (hand_to_handle*right.fingertip_pad(4)).z > .008,
		"the fingers follow the long edge of the scraper handle with the thumb braced on top")
	check(joints_relaxed, "the scrape grip avoids forcing the thumbs or distal joints into a tight curl")
	await capture("03-scrape-label")
	work_mouse(MOUSE_BUTTON_RIGHT,false)
	await hand_frames(13)
	var blade_off: Vector3 = game.hand.scraper.transform*Shapes.SCRAPER_EDGE
	check(game.hand.scrape_pressure == 0.0 and game.hand.label_mesh.visible and game.hand.progress > .06 and blade_off.distance_to(scraped) > .020,
		"letting go lifts the blade and preserves the scraped band")
	game.hand.cursor = game.hand.hotspot()
	work_mouse(MOUSE_BUTTON_RIGHT,true)
	await hand_frames(16)
	var blade_back: Vector3 = game.hand.scraper.transform*Shapes.SCRAPER_EDGE
	check(game.hand.pressed and game.hand.scrape_point(game.hand.stroke_travel).distance_to(blade_back) < .004,
		"scraping resumes at the partially cleared band")
	scrape_distance(245)
	check(game.hand.scrape_between_passes and not game.hand.pressed and is_equal_approx(game.hand.progress,.10),
		"a long stroke stops at the first pass and leaves scraps of label")
	game.hand.drag(Vector2(0,245))
	check(is_equal_approx(game.hand.progress,.10), "the next pass requires a new press")
	await hand_frames(24)
	await capture("26-old-blade-partial-label")
	work_mouse(MOUSE_BUTTON_RIGHT,false)
	scrape_strokes(8)
	check(game.hand.scrape_between_passes and game.hand.label_mesh.visible and is_equal_approx(game.hand.progress,.90),
		"a paper label still needs one more cut after nine complete passes")
	scrape_strokes(1)
	check(game.hand.label_removed and game.hand.task() == "scrub" and game.model.held_queue < Yard.STRIPPED,
		"the old blade leaves adhesive that must be wiped before the checkpoint")
	check(game.hand.view_task() == "scrape_label", "the blade finishes its stroke before wiping")
	await capture("15-scrape-finish",6)
	await hand_frames(14)
	check(not game.hand.label_mesh.visible and not game.hand.scraper.visible and game.site.table_scraper.visible,
		"the label clears and the scraper is back on the bench before wiping")
	check(game.hand.towel.visible and is_equal_approx(game.hand.wet_glass.get_shader_parameter("adhesive_strength"),adhesive_strength) and
		is_equal_approx(game.hand.wet_glass.get_shader_parameter("stain_seed"),stain_seed),
		"the same adhesive stays on the glass when the cloth replaces the blade")
	check(game.camera.fov < 34.9 and game.ui.work_prompt.text.contains("按住左键左右来回擦"),
		"wiping stays zoomed in and teaches the wiping gesture before rinsing")
	await capture("27-wipe-adhesive")
	game.hand.cursor = game.hand.hotspot()
	work_mouse(MOUSE_BUTTON_LEFT,true)
	game.hand.drag(Vector2(0,600))
	await hand_frames(3)
	check(is_zero_approx(game.hand.progress), "holding the cloth still or moving vertically does not wipe adhesive")
	game.hand.drag(Vector2(900,0))
	await hand_frames(3)
	check(game.hand.wipe_stroke == 0 and game.hand.progress > 0.0 and game.hand.progress < .025,
		"a single fast flick barely moves the cloth across the adhesive")
	wipe_distance(17)
	var short_wipe: float = game.hand.progress
	for i in 5:
		wipe_distance(-12)
		wipe_distance(12)
	check(game.hand.wipe_stroke == 0 and is_equal_approx(game.hand.progress,short_wipe),
		"short repeated motions over the same spot do not earn more wipe progress")
	wipe_distance(60)
	wipe_distance(180)
	await hand_frames(2)
	check(game.hand.wipe_strokes == 5 and game.hand.wipe_stroke == 1 and is_equal_approx(game.hand.progress,.20) and
		game.ui.work_percent.text == "擦胶 20%" and game.ui.work_prompt.text.contains("向左擦到边"),
		"the cloth reaches the right edge and the work panel asks the player to reverse")
	work_mouse(MOUSE_BUTTON_LEFT,false)
	game.hand.drag(Vector2(-300,0))
	await hand_frames(2)
	check(is_equal_approx(game.hand.progress,.20), "lifting the cloth preserves the cleaned area")
	game.hand.cursor = game.hand.hotspot()
	work_mouse(MOUSE_BUTTON_LEFT,true)
	wipe_distance(-110)
	wipe_distance(47)
	await hand_frames(4)
	var wipe_coverage: float = game.hand.wet_glass.get_shader_parameter("wipe_coverage")
	check(game.hand.task() == "scrub" and wipe_coverage > .45 and wipe_coverage < .52,
		"the cloth gradually clears the surface according to wiping progress")
	await capture("34-wipe-in-progress")
	wipe_distance(64)
	wipe_distance(-110)
	check(game.hand.task() == "scrub" and game.model.held_queue < Yard.STRIPPED and is_equal_approx(game.hand.progress,.80),
		"four sweeps still leave adhesive and keep the bottle at the raw checkpoint")
	wipe_distance(110)
	work_mouse(MOUSE_BUTTON_LEFT,false)
	check(game.hand.task() == "rinse" and game.hand.surface_wiped, "wiping the adhesive unlocks rinsing")
	check(is_equal_approx(game.hand.wet_glass.get_shader_parameter("wipe_coverage"),1.0),
		"complete wiping leaves the glass clear for rinsing")
	game.interact()
	check(game.model.held_queue == Yard.STRIPPED and game.model.stage_for_sale() == 0,
		"a stripped but unwashed bottle cannot ship")
	game.status_ttl = 0.0
	await verify_manual_wash()
	check(game.camera.fov > 61.5, "the scraping close-up opens back out for the wash and finish stations")
	await capture("04-clean")
	var original_crate: Array[int] = game.model.bench_crate.duplicate()
	game.model.bench_crate.resize(game.model.crate_capacity())
	game.model.bench_crate.fill(0)
	game.interact()
	check(game.working and game.model.held_queue == Yard.CLEAN,"a full crate blocks packing the finished bottle")
	game._input(leave)
	check(not game.working and not game.hand.held and game.camera.fov == game.WALK_FOV and
		game.model.carried.size() == 1 and game.model.carried[0].y == Yard.CLEAN,
		"Escape immediately exits a blocked packing station with the finished bottle")
	var clean_save := Yard.new()
	clean_save.restore(JSON.parse_string(JSON.stringify(game.model.serialize())))
	check(clean_save.carried == game.model.carried and clean_save.unload_carried() == 0 and clean_save.carry_count() == 1,
		"a stowed finished bottle survives reloading and is not put back into raw intake")
	game.model.bench_crate.assign(original_crate)
	aim_at_station("bench")
	game.interact()
	check(game.working and game.hand.done and game.hand.view_task() == "pack", "a stowed finished bottle returns straight to packing")
	game.interact()
	check(not game.working and game.model.carry_count() == 0 and game.model.bench_crate.size() == 1,
		"putting away the washed bottle exits the bench with empty hands")
	var displayed: Node3D = game.site.clean_box.bottles[0]
	check(game.site.clean_box.bottles.size() == 1 and displayed.get_child(0).mesh == game.hand.bottle.get_child(0).mesh,
		"one finished bottle creates exactly one instance of the bottle held by the worker")
	aim_at_station("clean_crate")
	await capture("43-one-finished-bottle")
	await verify_first_crate_trip()
	aim_at_station("bench")
	game.interact()
	check(game.model.carry_count() == 0 and game.model.sum_queue(Yard.RAW) == Yard.STARTER_SIZE-1,
		"E cannot take another bottle without returning to the intake")
	var shown_sleeve: bool = false
	var shown_milk: bool = false
	for i in Yard.STARTER_SIZE-1:
		take_at_stock()
		if game.hand.type == 1 and game.hand.task() == "scrape_label" and not shown_sleeve:
			shown_sleeve = true
			await hand_frames(25)
			await capture("08-sleeve")
			game.hand.cursor = game.hand.hotspot()
			game.hand.press_action()
			await hand_frames(16)
			game.hand.drag(Vector2(83,0))
			check(is_zero_approx(game.hand.progress),"sideways motion does not scrape down the plastic label")
			game.hand.cursor = game.hand.hotspot()
			scrape_distance(124)
			await hand_frames(18)
			check(game.hand.scrape_passes == 12 and game.hand.wipe_strokes == 6 and
				game.hand.progress > .05 and game.hand.progress < .06 and game.hand.scraper.visible,
				"the starter blade needs twelve passes and six wipes for a plastic label")
			await capture("16-scrape-plastic")
			scrape_distance(215)
			scrape_strokes(10)
			check(game.hand.scrape_pass == 11 and not game.hand.label_removed,
				"eleven complete passes still leave plastic on the bottle")
			scrape_strokes(1)
			check(game.hand.label_removed and game.hand.task() == "scrub",
				"the twelfth pass clears plastic and hands off to wiping")
		elif pictures and game.hand.type == 2 and not shown_milk:
			shown_milk = true
			for frame in 25:
				await process_frame
			await capture("09-milk")
		finish_held()
		game.place_bottle()
		if game.model.bench_crate.size() == game.model.crate_capacity():
			deliver_manual_crate()
	deliver_manual_crate()
	check(game.model.sum_queue(Yard.FOR_SALE) == 69 and game.model.recycled == 3, "69 starter bottles carried to the window and three cracked units recycled")
	check(game.site.label_offcuts.size() >= 5 and game.site.label_offcuts.size() <= 24,
		"scraping leaves a bounded pile of fragments on the bench")
	await verify_first_sale()
	check(game.model.story_chapter() == Yard.Story.FIRST_SALE and game.ui.story_hint.text.contains("新章节"),
		"first payout unlocks an unread story chapter")
	check(game.model.unlocked(0) and not game.ui.equipment_notice.visible and not game.model.unlocked(1),
		"first payout opens the tabletop stripper while the later line remains locked")
	var starter_cash: int = game.model.wallet_cents()
	game.show_office(false)
	aim_at_station("clean_crate")
	if pictures:
		var upgrade := InputEventKey.new()
		upgrade.physical_keycode = KEY_F
		upgrade.pressed = true
		game._input(upgrade)
	else:
		game.model.upgrade_crate()
	check(game.model.crate_capacity() == 8 and game.model.wallet_cents() == starter_cash,
		"F upgrades the crate for free after the opening sale without consuming equipment money")
	game.status_ttl = 0.0
	game.on_action("open_tools",0)
	check(game.ui.tool_shop.is_visible_in_tree() and game.ui.tool_buttons[2].disabled,
		"the tool shop shows the upgrade sequence")
	await capture("28-scraper-shop")
	button(game.ui.tool_buttons[1])
	check(game.model.equipped_scraper == 1 and game.model.owned_scraper == 1 and game.model.wallet_cents() == starter_cash-2400,
		"starter sales buy and equip the thin blade for 24")
	check(game.ui.tool_buttons[2].disabled and not game.model.choose_scraper(2),
		"a later purchase cannot consume funds needed to open the next shipment")
	game.on_action("open_operations",0)
	button(game.ui.machine_buttons[0])
	check(game.model.installed[0], "the first tray still funds the first stripper after buying the thin blade")
	check(game.model.story_chapter() == Yard.Story.FIRST_MACHINE, "installing the first machine turns the story page")
	button(game.ui.place_order)
	check(game.model.phase == 1 and game.model.in_yard() == 600, "street restock delivers 600 bottles")
	game.site.update_site(game.model,0.0)
	check(garage_visible_stock() == 600 and game.model.carry_capacity() == 1 and not game.ui.bag_upgrade.disabled,
		"street expansion draws all 600 bottles and unlocks the manual backpack upgrade")
	var street_snapshot: Dictionary = JSON.parse_string(JSON.stringify(game.model.serialize()))
	var bag_save := Yard.new()
	bag_save.restore(street_snapshot)
	check(bag_save.bag_capacity() == 1 and bag_save.can_upgrade_bag(),
		"reloading an unclaimed upgrade keeps the one-bottle backpack")
	street_snapshot.version = 9
	street_snapshot.erase("bag_upgraded")
	bag_save.restore(street_snapshot)
	check(bag_save.bag_capacity() == 5 and not bag_save.can_upgrade_bag(),
		"legacy street saves keep their previously unlocked five slots")
	await capture("47-backpack-upgrade")
	var before_bag_upgrade: int = game.model.wallet_cents()
	button(game.ui.bag_upgrade)
	check(game.model.carry_capacity() == 5 and game.ui.bag_upgrade.disabled and game.ui.carry_title.text.contains("0 / 5") and
		game.model.wallet_cents() == before_bag_upgrade and not game.model.upgrade_bag(),
		"claiming the free upgrade immediately expands the HUD and can only be done once")
	bag_save.restore(JSON.parse_string(JSON.stringify(game.model.serialize())))
	check(bag_save.bag_capacity() == 5 and not bag_save.can_upgrade_bag(),"the claimed backpack upgrade survives reloading")
	game.show_office(false)
	if pictures:
		game.player.position = Vector3(7.70,.02,4.44)
		game.camera.look_at(Vector3(9.76,.43,2.08))
		await capture("35-garage-bulk-piles")
	game.player.position = Vector3(5.15,.02,2.92)
	game.camera.look_at(game.site.garage.SIGN_CENTER)
	check(game.target_under_aim() == "stock" and game.stock_prompt().contains("Shift + E"),
		"the front of the stock sign offers both pickup amounts")
	game.status_ttl = 0.0
	var pickup := InputEventKey.new()
	pickup.physical_keycode = KEY_E
	pickup.pressed = true
	pickup.shift_pressed = true
	if pictures:
		game._input(pickup)
	else:
		game.interact(true)
	check(game.model.carry_count() == 1 and game.model.sum_queue(Yard.RAW) == 599 and
		game.ui.carry_slots[0].color == game.ui.GREEN and game.ui.carry_slots[1].color == game.ui.EMPTY_SLOT and
		game.ui.carry_slots[4].visible and not game.ui.carry_slots[5].visible,
		"Shift+E takes one bottle and fills exactly one of five visible slots")
	await capture("48-garage-pickup")
	pickup.physical_keycode = KEY_2
	if pictures:
		game._input(pickup)
	else:
		game.take_bottle(1,true)
	check(game.model.carry_count() == 2 and game.model.kind(game.model.carried[1].x) == 1,
		"a modified number key takes one bottle of the selected type")
	pickup.physical_keycode = KEY_E
	pickup.shift_pressed = false
	if pictures:
		game._input(pickup)
	else:
		game.interact()
	check(game.model.carry_count() == 5 and game.ui.carry_slots[4].color == game.ui.ACCENT,
		"E fills the remaining slots and the full backpack meter turns amber")
	aim_at_station("bench")
	game.interact()
	check(game.model.carry_count() == 5 and game.model.carried.size() == 4,
		"one trip brings five bottles and the bench removes one at a time")
	scrape_strokes(6)
	check(game.hand.scraper_level == 1 and game.hand.scrape_pass == 6 and game.hand.task() == "scrape_label",
		"the purchased thin blade needs a seventh cut on paper")
	scrape_strokes(1)
	check(game.hand.task() == "rinse" and not game.hand.glue_cleanup,
		"the thin blade skips adhesive cleanup on clean paper")
	finish_held()
	game.place_bottle()
	check(game.model.carry_count() == 4 and game.status.contains("回脱标台"),
		"finishing one bottle leaves the rest in storage for the bench")
	finish_remaining_storage()
	game.show_office(true)
	for i in 3:
		button(game.ui.feed)
		advance_for(game.model,10)
		game.refresh()
		button(game.ui.wash)
		button(game.ui.sanitize)
		button(game.ui.inspect)
		sell_ready_crates()
	check(game.model.in_yard() == 0, "tabletop line and batch work clear the street restock")
	button(game.ui.machine_buttons[1])
	button(game.ui.place_order)
	check(game.model.phase == 2 and game.model.in_yard() == 2400, "warehouse receives 2,400 bottles")
	await verify_later_scrapers()
	verify_type(3)
	for i in 4:
		button(game.ui.feed)
		advance_for(game.model,11)
		game.refresh()
		if not game.ui.wash.disabled:
			button(game.ui.wash)
		button(game.ui.sanitize)
		button(game.ui.inspect)
		sell_ready_crates()
	for i in [2,3,4,5,Yard.SANITIZER]:
		button(game.ui.machine_buttons[i])
	check(game.model.installed[2] and game.model.installed[3] and game.model.installed[4] and game.model.installed[5] and
		game.model.installed[Yard.SANITIZER], "warehouse sales fund the wash-to-shipping equipment")
	game.show_office(true,true)
	button(game.ui.auto_sale_button)
	check(game.model.auto_sales, "player enables order matching, shipping and settlement")
	game.show_office(true)
	advance_for(game.model,22)
	game.refresh()
	check(game.model.in_yard() == 0, "special branch clears sauce bottles")
	button(game.ui.place_order)
	check(game.model.phase == 3 and game.model.in_yard() == 48000, "first 48,000-bottle truck")
	check(game.model.story_chapter() == Yard.Story.FIRST_TRUCK, "the first full truck unlocks the working capital goal")
	await verify_cart()
	await verify_finished_cart()
	verify_type(4)
	verify_type(5)
	sell_ready_crates()
	await capture("05-terminal")
	advance_for(game.model,25)
	game.refresh()
	button(game.ui.machine_buttons[6])
	check(game.model.installed[6], "truck output funds pallet logistics")
	advance_for(game.model,90)
	game.refresh()
	check(game.model.in_yard() == 0, "mixed truck fully processed")
	await verify_ending_journal()
	button(game.ui.place_order)
	check(game.model.phase == 4 and game.model.day_active and game.model.trucks == 1, "regional dispatch starts with the first truck")
	game.show_office(false)
	game.leave_desk()
	game.player.position = Vector3(12.48,.05,-1.26)
	game.player.rotation.y = 0
	game.camera.look_at(Vector3(6.4,1.19,game.site.AUTOMATION_Z))
	advance_for(game.model,45)
	game.site.update_site(game.model,4.0)
	await capture("06-automation")
	await verify_machine_work()
	var restored := Yard.new()
	restored.restore(JSON.parse_string(JSON.stringify(game.model.serialize())))
	check(restored.received == game.model.received and restored.trucks == game.model.trucks and restored.day_active and
		restored.auto_sales and restored.day_truck_size == 48000, "restored mid-shift save with automatic sales and the new truck size")
	advance_for(restored,330)
	check(restored.day_complete and restored.trucks == 60 and restored.in_yard() == 0, "sixty-truck unattended shift finishes after reload")
	check(restored.delivered-restored.day_base_delivered+restored.recycled-restored.day_base_recycled == 2880000,
		"exactly 2,880,000 bottles accounted for")
	check(restored.received == restored.delivered + restored.recycled, "in/out mass balance")
	var actual_queue: int = 0
	for i in Yard.QUEUE_NAMES.size():
		actual_queue += restored.sum_queue(i)
	check(actual_queue == 0 and restored.held < 0, "no bottles left in queues or in hand")
	for type in restored.sold_by_type.size():
		check(restored.sold_by_type[type] > 10000, "bottle type %d has its own commercial output" % type)
	verify_migration()
	verify_unupgraded_bag_cart()
	verify_crate_saves()
	await verify_market()
	verify_legacy_volume()
	verify_story_save()
	verify_garage_maximum()
	verify_scraper_feedback()
	verify_rinse_grips()
	for i in 24:
		await process_frame
	print("PLAYTEST %d passed / %d failed" % [checks - failures,failures])
	quit(0 if failures == 0 else 1)


func verify_opening_journal() -> void:
	var shortcut := InputEventKey.new()
	shortcut.physical_keycode = KEY_J
	shortcut.pressed = true
	game._input(shortcut)
	check(game.ui.journal.visible and game.model.story_read == Yard.Story.OPENING and
		game.ui.journal_page.text.contains("12,000") and game.ui.journal_buttons[Yard.Story.FIRST_SALE].disabled,
		"J opens the stock loss prologue but keeps later chapters locked")
	game.on_action("journal_chapter",Yard.Story.RECOVERED)
	check(game.ui.journal_index == Yard.Story.OPENING, "a locked chapter cannot be opened")
	shortcut.physical_keycode = KEY_E
	game._input(shortcut)
	check(not game.working and game.model.credits == 0 and game.model.received == 72,
		"reading the prologue does not interact with the bench or change the economy")
	await capture("30-story-opening")
	shortcut.physical_keycode = KEY_ESCAPE
	game._input(shortcut)
	check(not game.ui.journal.visible, "Escape closes the journal")


func verify_ending_journal() -> void:
	check(game.model.story_recovered and game.model.credits >= Yard.STORY_TARGET and
		game.model.story_chapter() == Yard.Story.RECOVERED, "truck sales meet the story goal without charging the balance")
	game.show_journal(true)
	check(game.ui.journal_index == Yard.Story.RECOVERED and game.ui.journal_goal.text.contains("主线完成") and
		game.ui.journal_progress.size.x == 592.0, "the ending is open and its balance goal is complete")
	await capture("31-story-ending")
	button(game.ui.journal_buttons[Yard.Story.OPENING])
	check(game.ui.journal_index == Yard.Story.OPENING and game.model.story_read == Yard.Story.RECOVERED,
		"older pages can be reread without resetting progress")
	button(game.ui.journal_close)
	check(game.office and not game.ui.journal.visible and game.ui.office_board.is_visible_in_tree(),
		"closing the journal restores the station terminal")


func verify_story_save() -> void:
	var business := Yard.new()
	business.phase = Yard.STORY_TRUCK_PHASE
	business.credits = Yard.STORY_TARGET-1
	business.queues[Yard.FOR_SALE][0] = 1
	check(not business.story_recovered and business.story_chapter() == Yard.Story.FIRST_TRUCK,
		"just below the target does not qualify even with goods waiting to sell")
	var paid: Vector2i = business.sell_to(0)
	check(paid.x == 1 and business.story_recovered and business.wallet_cents() == (Yard.STORY_TARGET-1)*100+paid.y,
		"settling a sale that crosses the target unlocks the story exactly once")
	business.story_read = Yard.Story.RECOVERED
	business.credits = 75
	var saved: Dictionary = JSON.parse_string(JSON.stringify(business.serialize()))
	var restored := Yard.new()
	restored.restore(saved)
	check(restored.story_recovered and restored.story_read == Yard.Story.RECOVERED and restored.credits == 75,
		"the read ending survives reload after the balance falls below the target")
	saved.version = 5
	saved.erase("story_read")
	saved.erase("story_recovered")
	var legacy := Yard.new()
	legacy.restore(saved)
	check(not legacy.story_recovered and legacy.story_read == -1 and legacy.story_chapter() == Yard.Story.FIRST_TRUCK and legacy.credits == 75,
		"a v5 save enters the mainline at its existing progress without losing credits")
	saved.credits = Yard.STORY_TARGET
	legacy.restore(saved)
	check(legacy.story_recovered and legacy.story_chapter() == Yard.Story.RECOVERED,
		"an old save already at the capital goal does not have to earn it again")


func verify_opening_machine_lock() -> void:
	var yard := Yard.new()
	yard.credits = Yard.COST[0]
	yard.queues[Yard.STRIPPED][0] = 1
	yard.queues[Yard.WASHED][0] = 1
	yard.queues[Yard.SANITIZED][0] = 1
	check(not yard.buy(0) and not yard.can_bulk_wash() and yard.bulk_wash() == 0 and
		yard.bulk_sanitize() == 0 and yard.bulk_finish() == 0 and yard.credits == Yard.COST[0],
		"opening purchases and bulk work cannot bypass the manual start")


func verify_line_layout() -> void:
	var site: Node3D = game.site
	check(is_equal_approx(site.SANITIZER_TRAY.z,site.COUNTER_Z) and
		is_equal_approx(site.DRAIN_PIN.z,site.COUNTER_Z) and
		is_equal_approx(site.CLEAN_CRATE.z,site.COUNTER_Z),"finishing stations share the same counter depth")
	check(site.targets.stock.position.x > site.room.EAST,"the bottle pickup is outside the manual processing room")
	for i in site.AUTOMATION_ORDER.size():
		var machine: Node3D = site.machines[site.AUTOMATION_ORDER[i]]
		var conveyor: Node3D = site.conveyors[i]
		check(is_equal_approx(machine.position.z,site.AUTOMATION_Z) and
			is_equal_approx(conveyor.position.x,machine.position.x) and
			is_equal_approx(machine.position.x,site.AUTOMATION_X+i*site.AUTOMATION_SPACING),
			"warehouse machine %d sits on its conveyor section" % i)


func verify_machine_work() -> void:
	var site: Node3D = game.site
	for i in site.machines.size():
		check(game.model.machine_work[i] > 0 and site.machines[i].active,
			"warehouse machine %d runs after doing actual work" % i)
	site.line_phase = .74
	site.animate_line(game.model,0.0)
	var stripper = site.machines[0]
	var washer = site.machines[1]
	var rotation_before: float = stripper.rotors[0].rotation.y
	var spray_active: bool = false
	for jet in washer.effects:
		spray_active = spray_active or jet.visible
	var inverted: bool = false
	for bottle in site.glass_on_line:
		inverted = inverted or (bottle.visible and absf(bottle.rotation.z) > 2.8)
	check(stripper.effects[0].visible and stripper.label_blade.position.y < 1.225 and spray_active and inverted,
		"bottles trigger the scraping head, label shavings, spray and inversion inside the machines")
	var drainer = site.machines[3]
	check(absf(drainer.cradle.rotation.z) > 2.8 and absf(drainer.drive_wheel.rotation.z) > 1.0,
		"the drain clamp and its drive turn with the bottle")
	check(site.outbound_cartons[0].visible,"cartons replace loose bottles at the output end")
	game.model.advance(.15)
	site.animate_line(game.model,.15)
	check(not is_equal_approx(rotation_before,stripper.rotors[0].rotation.y) and site.line_phase > .74,
		"live throughput turns the stripping rollers and advances the belt")
	site.line_phase = .61
	site.animate_line(game.model,0.0)
	var packer = site.machines[Yard.PACKER]
	check(packer.jaws[0].rotation.z > .10 and packer.jaws[1].rotation.z < -.10 and
		is_equal_approx(packer.actuator.position.x,packer.trolley.position.x),
		"packing jaws close while the trolley tracks the moving head")
	if pictures:
		game.status_ttl = 0.0
		var shots := [[0,"18-label-machine",.67],[1,"19-wash-machine",.74],[3,"20-drain-machine",.74],
			[4,"21-packing-machine",.61],[2,"22-sorter-bridge",.30],[5,"23-service-washer",.74],
			[Yard.SANITIZER,"24-steam-tunnel",.74],[6,"25-pallet-lift",.68]]
		for shot in shots:
			var machine: Node3D = site.machines[shot[0]]
			game.player.position = machine.position+Vector3(.26,.02,1.93 if shot[0] == 6 else 1.61)
			game.camera.look_at(machine.global_position+Vector3(0,1.30 if shot[0] == 6 else 1.19,0))
			site.line_phase = shot[2]
			site.animate_line(game.model,0.0)
			await capture(shot[1],0)
	var stopped_at: float = site.line_phase
	site.animate_line(game.model,2.0)
	check(not stripper.active and not washer.active and is_equal_approx(site.line_phase,stopped_at),
		"the belt and machinery stop once there is no new work")


func verify_sale_window() -> void:
	var start: Vector3 = game.player.position
	var look: Vector3 = game.camera.rotation
	aim_at_station("clean_crate")
	await physics_frame
	game.interact()
	check(not game.office and game.model.hand_crate.is_empty() and game.site.clean_box.bottles.is_empty(),
		"the empty bench crate displays no bottles and cannot open the market")
	aim_at_station("sale_window")
	await physics_frame
	await process_frame
	check(game.target_under_aim() == "sale_window" and game.player.position.x > game.site.room.EAST,
		"the physical sales window is outside the processing room")
	game.interact()
	check(game.office and game.ui.market.is_visible_in_tree() and game.ui.unload_finished.disabled,
		"E at the sales window opens the buyer list with no unloaded cargo")
	game.show_office(false)
	game.player.position = Vector3(game.site.TERMINAL_X,.02,1.72)
	game.player.rotation.y = 0.0
	game.camera.look_at(game.site.targets.office.position)
	check(game.target_under_aim() == "office","the counter terminal remains independently reachable from the aisle")
	game.player.position = start
	game.player.rotation.y = 0.0
	game.camera.rotation = look
	await physics_frame


func verify_later_scrapers() -> void:
	game.on_action("open_tools",0)
	button(game.ui.tool_buttons[2])
	game.show_office(false)
	take_at_stock(1)
	game.hand.cursor = game.hand.hotspot()
	game.hand.press_action()
	scrape_distance(85)
	check(game.hand.scraper_level == 2 and game.hand.scrape_passes == 6 and game.hand.task() == "scrape_label" and not game.hand.glue_cleanup,
		"the curved blade clears plastic in six passes without leaving glue")
	var partial_cut: float = game.hand.progress
	game.on_action("open_tools",0)
	button(game.ui.tool_buttons[3])
	check(game.model.equipped_scraper == 3 and game.hand.scraper_level == 2 and partial_cut > .07 and
		is_equal_approx(game.hand.progress,partial_cut),
		"equipping a new blade preserves work on the bottle already in hand")
	var restored := Yard.new()
	restored.restore(JSON.parse_string(JSON.stringify(game.model.serialize())))
	var funds: int = restored.credits
	check(restored.owned_scraper == 3 and restored.equipped_scraper == 3 and restored.choose_scraper(0) and
		restored.choose_scraper(3) and restored.credits == funds,"owned blades and selection survive reload, and switching is free")
	game.show_office(false)
	finish_held()
	game.place_bottle()
	aim_at_station("bench")
	game.interact()
	game.status_ttl = 0.0
	await hand_frames(25)
	await capture("29-spring-scraper")
	scrape_strokes(3)
	check(game.hand.scraper_level == 3 and game.hand.scraper.get_meta("level") == 3 and
		game.hand.scrape_pass == 3 and game.hand.task() == "scrape_label",
		"the spring blade equips on the next bottle and needs a fourth plastic pass")
	scrape_strokes(1)
	check(game.hand.task() == "rinse", "the spring blade clears plastic on the fourth pass and goes straight to rinsing")
	finish_held()
	game.place_bottle()
	finish_remaining_storage()
	game.show_office(true)


func verify_first_sale() -> void:
	aim_at_station("sale_window")
	game.interact()
	check(game.ui.market.is_visible_in_tree(), "the first completed batch is sold at the sales window")
	check(game.model.credits == 0 and game.model.sum_queue(Yard.FOR_SALE) == 69 and game.model.delivered == 0,
		"physical delivery increases sale inventory without paying for it")
	button(game.ui.buyer_buttons[1])
	check(game.ui.selected_buyer == 1 and game.model.sale_quote(1).x == 23 and
		game.ui.buyer_price.text.contains(game.ui.format_cash(game.model.sale_unit_price(1))),"soda buyer quotes all 23 bottles at the displayed market price")
	var waiting := Yard.new()
	waiting.restore(JSON.parse_string(JSON.stringify(game.model.serialize())))
	check(waiting.sum_queue(Yard.FOR_SALE) == 69 and waiting.credits == 0, "unsold stock and money survive reload")
	await capture("13-sales")
	var soda_payment: int = game.model.sale_quote(1).y
	var expected_total: int = soda_payment+game.model.sale_quote(0).y+game.model.sale_quote(2).y
	button(game.ui.confirm_sale)
	check(game.model.wallet_cents() == soda_payment and game.model.delivered == 23 and game.model.sale_stock(0) == 34 and game.model.sale_stock(1) == 0,
		"confirming the soda order settles only its 23 bottles")
	check(game.model.sell_to(1) == Vector2i.ZERO and game.model.wallet_cents() == soda_payment, "a sold order cannot be paid twice")
	sell_ready_crates()
	check(game.model.delivered == 69 and game.model.in_yard() == 0 and game.model.wallet_cents() == expected_total,
		"the starter crate earns the exact proceeds from the three buyers")


func sell_ready_crates() -> void:
	game.show_office(false)
	deliver_manual_crate()
	aim_at_station("sale_window")
	game.interact()
	if not game.ui.pack_for_sale.disabled:
		button(game.ui.pack_for_sale)
	var orders: int = 0
	while not game.ui.confirm_sale.disabled and orders < 20:
		button(game.ui.confirm_sale)
		orders += 1
	game.show_office(true)


func deliver_manual_crate() -> void:
	if game.model.bench_crate.is_empty():
		return
	aim_at_station("clean_crate")
	game.interact()
	aim_at_station("sale_window")
	game.interact()
	button(game.ui.unload_finished)
	game.show_office(false)


func verify_first_crate_trip() -> void:
	game.interact()
	game.update_carried_crate(.02)
	check(game.model.bench_crate.is_empty() and game.model.hand_crate.size() == 1 and game.carried_box.visible,
		"E at the bench picks up a physical crate with its one bottle")
	await enter_garage()
	if pictures:
		game.yaw = PI
		game.player.rotation.y = PI
		game.camera.look_at(game.site.targets.sale_window.position)
		key(KEY_W,true)
		for frame in 34:
			await physics_frame
		key(KEY_W,false)
		check(game.target_under_aim() == "sale_window" and game.model.hand_crate.size() == 1,
			"the worker walks the crate through the sliding door to the sales window")
		await capture("44-carry-to-sales-window")
	else:
		aim_at_station("sale_window")
	game.interact()
	check(game.model.sum_queue(Yard.FOR_SALE) == 0 and not game.ui.unload_finished.disabled,
		"the crate remains in hand until the worker hands it over at the window")
	button(game.ui.unload_finished)
	check(game.model.hand_crate.is_empty() and game.model.sum_queue(Yard.FOR_SALE) == 1 and game.model.credits == 0,
		"handing over the crate moves exactly one bottle to the buyer without settling the sale")
	game.show_office(false)


func verify_manual_wash() -> void:
	await hand_frames(30)
	check(rinse_grip_fits(),"the left hand grips the bottle before the tap opens")
	await capture("36-rinse-ready",0)
	game.hand.cursor = game.hand.hotspot()
	game.hand.press_action()
	await hand_frames(13)
	var right: Node3D = game.hand.arms[1]
	var lever: Vector3 = game.site.wash_valve_tip()
	var gap: float = right.to_global(right.pinch_point()).distance_to(lever)
	check(gap < .012,"right fingertips reach the valve at the start of the wash (%.3f m)" % gap)
	await capture("17-open-faucet",0)
	await hand_frames(20)
	check(game.hand.progress > 0.0 and not game.hand.washed, "washing takes time under the faucet")
	check(game.hand.stream.visible and game.camera.is_position_in_frustum(right.to_global(right.rest_wrist)) == false,
		"the right wrist comes down while water still flows")
	check(rinse_grip_fits(),"the left hand stays on the glass while the bottle is rinsed")
	for arm in game.hand.arms:
		var elbow: Vector3 = arm.skeleton.get_bone_pose_position(arm.SLEEVE_FOREARM)
		var shoulder: Vector3 = arm.skeleton.get_bone_pose_position(arm.SLEEVE_UPPER_ARM)
		check(is_equal_approx(arm.rest_wrist.distance_to(elbow),arm.FOREARM_LENGTH) and
			is_equal_approx(elbow.distance_to(shoulder),arm.UPPER_ARM_LENGTH),"arm segments keep their lengths during rinsing")
	await capture("10-rinse",3)
	game.hand.pose(.8)
	check(game.hand.task() == "sanitize" and game.model.held_queue == Yard.WASHED,
		"washing moves the held bottle to the disinfection stage")
	var waiting := Yard.new()
	waiting.restore(JSON.parse_string(JSON.stringify(game.model.serialize())))
	check(waiting.carry_count() == 1 and waiting.held == -1 and waiting.begin_carried() and waiting.held_queue == Yard.WASHED,
		"loading restores the carried bottle at its disinfection checkpoint")
	var old_save: Dictionary = JSON.parse_string(JSON.stringify(game.model.serialize()))
	old_save.version = 6
	waiting.restore(old_save)
	check(waiting.carry_count() == 0 and waiting.sum_queue(Yard.WASHED) == 1,
		"a version-six in-hand bottle migrates to the garage at the same checkpoint")
	var put_back := InputEventKey.new()
	put_back.physical_keycode = KEY_R
	put_back.pressed = true
	game._input(put_back)
	check(not game.working and game.model.held == -1 and game.model.carried[0].y == Yard.WASHED,
		"stowing a partially processed bottle preserves its stage and leaves the bench")
	aim_at_station("bench")
	game.interact()
	check(game.hand.task() == "sanitize" and game.model.sum_queue(Yard.WASHED) == 0,
		"storage gives back the washed bottle without repeating scraping")
	await hand_frames(30)
	game.hand.cursor = game.hand.hotspot()
	game.hand.press_action()
	game.hand.pressed = false
	game.hand.pose(.43)
	check(game.hand.cycle_running and not game.model.set_down(), "closed-chamber cycle prevents premature crating")
	var fan_angle: float = game.site.chamber_fan.rotation.z
	await hand_frames(10)
	check(game.site.chamber_mist.visible and not is_equal_approx(fan_angle,game.site.chamber_fan.rotation.z),
		"the closed manual chamber turns its fan and injects steam")
	await capture("11-sanitize")
	put_back.physical_keycode = KEY_S
	game._input(put_back)
	check(not game.working and not game.hand.cycle_running and game.model.carried[0].y == Yard.WASHED,
		"S exits immediately during the steam cycle and retains the completed wash")
	if pictures:
		var table_z: float = game.player.position.z
		key(KEY_S,true)
		for frame in 12:
			await physics_frame
		key(KEY_S,false)
		check(game.player.position.z > table_z+.10,"holding S walks the worker backward after leaving")
	aim_at_station("bench")
	game.interact()
	check(game.hand.task() == "sanitize","re-entering after an interrupted steam cycle resumes at disinfection")
	await hand_frames(36)
	game.hand.cursor = game.hand.hotspot()
	game.hand.press_action()
	game.hand.pose(1.20)
	check(game.hand.task() == "drain" and game.model.held_queue == Yard.SANITIZED, "disinfection finishes independently of a held click")
	game.hand.cursor = game.hand.hotspot()
	game.hand.press_action()
	game.hand.pose(.24)
	await capture("12-drain")
	game.hand.pose(.62)
	check(game.hand.done and game.model.held_queue == Yard.CLEAN, "only the drained bottle is eligible for the clean crate")
	await hand_frames(40)
	check(game.hand.view_task() == "pack" and absf(game.player.position.x-game.site.PACK_X) < .025,
		"finishing the bottle moves the worker to the packing end")


func verify_migration() -> void:
	var old_yard := Yard.new()
	for queue in old_yard.queues:
		queue.fill(0)
	old_yard.queues[Yard.WASHED][0] = 2
	old_yard.queues[Yard.CLEAN][0] = 1
	old_yard.received = 5
	old_yard.delivered = 2
	old_yard.phase = 3
	old_yard.credits = 14
	old_yard.installed.fill(true)
	var old_data: Dictionary = old_yard.serialize()
	old_data.version = 1
	old_data.queues.remove_at(Yard.FOR_SALE)
	old_data.queues.remove_at(Yard.SANITIZED)
	old_data.installed.remove_at(Yard.SANITIZER)
	old_data.erase("held_queue")
	var migrated := Yard.new()
	migrated.restore(JSON.parse_string(JSON.stringify(old_data)))
	check(migrated.credits == 14 and migrated.delivered == 2 and migrated.sum_queue(Yard.CLEAN) == 1 and
		migrated.sum_queue(Yard.WASHED) == 2 and migrated.installed[Yard.SANITIZER] and migrated.auto_sales,
		"v1 saves keep their sold stock and machine access while washed stock enters disinfection")
	advance_for(migrated,1)
	check(migrated.delivered == 5 and migrated.in_yard() == 0, "a migrated automated line clears its original stock")
	var prior := Yard.new()
	for queue in prior.queues:
		queue.fill(0)
	prior.queues[Yard.CLEAN][0] = 3
	prior.credits = 20
	prior.received = 3
	prior.phase = 3
	prior.installed[Yard.PACKER] = true
	var prior_data: Dictionary = prior.serialize().duplicate(true)
	prior_data.version = 2
	prior_data.queues.remove_at(Yard.FOR_SALE)
	prior_data.erase("auto_sales")
	migrated.restore(JSON.parse_string(JSON.stringify(prior_data)))
	check(migrated.credits == 20 and migrated.sum_queue(Yard.CLEAN) == 3 and migrated.auto_sales,
		"v2 clean inventory remains unsold until the migrated sales step runs")
	var expected_cash: int = 2000+3*migrated.sale_unit_price(0)
	advance_for(migrated,1)
	check(migrated.wallet_cents() == expected_cash and migrated.delivered == 3, "v2 migrated stock settles once at the new price")
	var version_three: Dictionary = JSON.parse_string(JSON.stringify(prior.serialize()))
	version_three.version = 3
	version_three.erase("owned_scraper")
	version_three.erase("equipped_scraper")
	migrated = Yard.new()
	migrated.restore(version_three)
	check(migrated.credits == prior.credits and migrated.owned_scraper == 0 and migrated.equipped_scraper == 0,
		"a v3 save gains the starter blade with its funds intact")


func verify_legacy_volume() -> void:
	var old: Dictionary = Yard.new().serialize().duplicate(true)
	old.version = 4
	old.erase("day_truck_size")
	old.queues[Yard.RAW] = Yard.LEGACY_STARTER_STOCK.duplicate()
	old.queues[Yard.RAW][0] -= 6
	old.received = 24
	old.delivered = 6
	old.sold_by_type[0] = 6
	old.owned_scraper = 1
	old.equipped_scraper = 1
	var migrated := Yard.new()
	migrated.restore(old)
	check(migrated.received == 72 and migrated.sum_queue(Yard.RAW) == 66 and migrated.delivered == 6 and
		migrated.credits == 0 and migrated.equipped_scraper == 1,"unfinished old starters get 48 extra bottles and keep prior sales and tools")
	migrated.restore(migrated.serialize().duplicate(true))
	check(migrated.received == 72 and migrated.sum_queue(Yard.RAW) == 66,"the starter top-up is applied once")
	old.queues[Yard.RAW].fill(0)
	old.delivered = 23
	old.recycled = 1
	old.credits = 80
	migrated.restore(old)
	check(migrated.in_yard() == 0 and migrated.credits == 80,"an old starter that already funded the machine stays complete")
	old.phase = 4
	old.installed.fill(true)
	old.auto_sales = true
	old.day_active = true
	old.trucks = 59
	old.received = 59*Yard.LEGACY_TRUCK_SIZE
	old.delivered = old.received-1
	old.next_truck = 0.0
	migrated.restore(old)
	check(migrated.day_truck_size == 19200,"an ongoing old shift keeps its scheduled truck size")
	advance_for(migrated,10)
	check(migrated.day_complete and migrated.received == 1152000 and migrated.in_yard() == 0,
		"the old shift closes with exactly its original volume")
	check(migrated.receive() and migrated.day_truck_size == 48000 and migrated.in_yard() == 48000,
		"the next shift switches to the larger trucks")


func verify_room() -> void:
	var body: CharacterBody3D = game.player
	var initial: Vector3 = body.position
	game.yaw = -PI*.5
	game.pitch = -.06
	body.position = Vector3(1.52,.02,1.54)
	body.rotation.y = game.yaw
	game.camera.rotation.x = game.pitch
	await physics_frame
	await physics_frame
	var test_from := Transform3D(Basis.IDENTITY,Vector3(1.52,.03,1.54))
	check(body.test_move(test_from,Vector3(1.7,0,0)), "closed door is a physical barrier")
	check(game.target_under_aim() == "room_door", "slide door can be targeted from inside")
	game.interact()
	for i in 30:
		await physics_frame
	check(game.site.room.door_open and game.site.room.door_shape.disabled, "door finishes opening after E")
	check(not body.test_move(test_from,Vector3(1.7,0,0)), "open doorway fits the first-person player")
	check(not game.site.room.toggle(Vector3(2.61,0,1.54)), "door cannot close on a worker in the opening")
	if pictures:
		key(KEY_W,true)
		for i in 38:
			await physics_frame
		key(KEY_W,false)
		check(body.position.x > 3.30, "walk through the door into the warehouse")
		body.position = Vector3(4.99,.03,2.05)
		body.rotation.y = 1.80
		game.camera.rotation.x = -.14
		await capture("07-room-entrance")
	body.position = Vector3(3.48,.02,1.54)
	body.rotation.y = PI*.5
	game.camera.rotation.x = -.1
	await physics_frame
	check(game.target_under_aim() == "room_door", "door can be targeted from the warehouse")
	game.interact()
	for i in 30:
		await physics_frame
	check(not game.site.room.door_open and not game.site.room.door_shape.disabled, "door closes from the warehouse side")
	if pictures:
		game.interact()
		for i in 30:
			await physics_frame
		game.yaw = PI*.5
		key(KEY_W,true)
		for i in 38:
			await physics_frame
		key(KEY_W,false)
		check(body.position.x < 2.08, "walk back from the warehouse through the reopened door")
		game.site.room.toggle(body.position)
		for i in 30:
			await physics_frame
	body.position = initial
	body.velocity = Vector3.ZERO
	game.yaw = 0.0
	game.pitch = -.21
	body.rotation.y = game.yaw
	game.camera.rotation.x = game.pitch
	await physics_frame


func key(code: Key, down: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = down
	Input.parse_input_event(ev)


func aim_at_station(id: String) -> void:
	var target: Vector3 = game.site.targets[id].position
	if id == "stock":
		game.player.position = Vector3(3.82,.02,target.z)
	elif id == "sale_window":
		game.player.position = Vector3(target.x,.02,target.z-1.37)
	elif id == "cart":
		game.player.position = Vector3(target.x,.02,target.z)+game.site.cart.basis.z*.95
	else:
		game.player.position = Vector3(target.x,.02,1.47)
	var turn: float = PI if id == "sale_window" else 0.0
	if id == "cart":
		turn = game.site.cart.rotation.y
	game.player.rotation = Vector3(0,turn,0)
	game.player.velocity = Vector3.ZERO
	game.camera.look_at(target)


func take_at_stock(selected: int = -1) -> void:
	aim_at_station("stock")
	if selected < 0:
		game.interact()
	else:
		game.take_bottle(selected)
	aim_at_station("bench")
	game.interact()


func enter_garage() -> void:
	game.player.position = Vector3(1.54,.02,1.54)
	game.player.velocity = Vector3.ZERO
	game.yaw = -PI*.5
	game.player.rotation.y = game.yaw
	game.camera.look_at(game.site.targets.room_door.position)
	if not game.site.room.door_open:
		game.interact()
		for frame in 32:
			await physics_frame
	check(game.site.room.door_open and game.site.room.door_shape.disabled,"E opens the physical garage doorway")
	if pictures:
		key(KEY_W,true)
		for frame in (58 if game.model.pushing_cart else 45):
			await physics_frame
		key(KEY_W,false)
		check(game.player.position.x > 3.45,"W walks through the garage doorway to the bottle pile")
		game.camera.look_at(game.site.targets.stock.position)
	else:
		aim_at_station("stock")


func garage_visible_stock() -> int:
	var total: int = 0
	for batch in game.site.garage.floor_bodies:
		total += batch.visible_instance_count
	for group in game.site.garage.bulk_piles:
		for pile in group:
			if pile.visible:
				var batch: MultiMesh = pile.multimesh
				total += batch.visible_instance_count if batch.visible_instance_count >= 0 else batch.instance_count
	return total


func verify_cart() -> void:
	game.site.update_site(game.model,0.0)
	check(garage_visible_stock() == 48000,"the garage draws every bottle from a full truck")
	game.show_office(false)
	game.site.update_cart(game.model,game.player,false)
	aim_at_station("cart")
	check(game.target_under_aim() == "cart","the first full truck unlocks a real cart in the garage")
	game.interact()
	check(game.model.pushing_cart and game.model.carry_capacity() == 20,"E takes hold of the twenty-bottle cart")
	aim_at_station("stock")
	game.interact()
	game.site.update_cart(game.model,game.player,false)
	game.site.update_site(game.model,0.0)
	check(game.model.carry_count() == 20 and garage_visible_stock() == 47980 and
		game.site.cart_bottles.all(func(bottle: MeshInstance3D) -> bool: return bottle.visible),
		"loading a cart moves all twenty bottle visuals from the garage into the cart")
	var restored := Yard.new()
	restored.restore(JSON.parse_string(JSON.stringify(game.model.serialize())))
	check(restored.pushing_cart and restored.carry_count() == 20 and restored.carry_capacity() == 20,
		"loaded cart and contents survive saving and loading")
	game.status_ttl = 0.0
	game.camera.look_at(game.site.cart.position+Vector3.UP*.35)
	await capture("33-garage-cart")
	if pictures:
		game.yaw = -PI*.5
		game.player.rotation.y = game.yaw
		var previous: Vector3 = game.site.cart.position
		key(KEY_W,true)
		for frame in 19:
			await physics_frame
		key(KEY_W,false)
		check(game.site.cart.position.distance_to(previous) > .45 and game.model.carry_count() == 20,
			"the loaded cart follows the worker through the garage")
	game.park_cart()
	check(not game.model.pushing_cart and game.model.carry_count() == 5 and game.model.parked_load.size() == 15,
		"parking leaves the extra fifteen bottles on the cart")
	restored.restore(JSON.parse_string(JSON.stringify(game.model.serialize())))
	check(restored.parked_load.size() == 15 and restored.parked_at.is_equal_approx(game.site.cart.position),
		"parked cargo and cart position survive saving and loading")
	aim_at_station("cart")
	game.interact()
	check(game.model.pushing_cart and game.model.carry_count() == 20,"pushing the cart again recovers its cargo")
	aim_at_station("stock")
	var put_back := InputEventKey.new()
	put_back.physical_keycode = KEY_R
	put_back.pressed = true
	game._input(put_back)
	check(game.model.carry_count() == 0,"R at the garage unloads the cart into the intake")
	game.park_cart()
	check(not game.model.pushing_cart and game.model.carry_capacity() == 5,"an empty cart can be parked")
	game.show_office(true)


func verify_unupgraded_bag_cart() -> void:
	var transport := Yard.new()
	transport.phase = Yard.STORY_TRUCK_PHASE
	check(transport.push_cart() and transport.collect() == Yard.CART_CAPACITY,
		"a full cart can be used even before claiming the backpack upgrade")
	transport.park_cart(Vector3.ZERO,0.0)
	check(transport.carry_count() == 1 and transport.parked_load.size() == 19,
		"parking with the starting backpack leaves nineteen bottles on the cart")
	check(transport.upgrade_bag() and transport.collect() == 4,
		"the backpack can still be upgraded with cargo on the parked cart")
	var restored := Yard.new()
	restored.restore(JSON.parse_string(JSON.stringify(transport.serialize())))
	check(not restored.push_cart() and restored.carry_count() == 5 and restored.parked_load.size() == 19,
		"a reloaded cart keeps its entire cargo and rejects excess bottles without moving them")
	check(restored.unload_carried() == 5 and restored.push_cart() and restored.carry_count() == 19 and restored.collect() == 1,
		"putting the carried bottles back allows safe pickup and refill of the parked cart")


func verify_finished_cart() -> void:
	var business: RefCounted = game.model
	var transport := Yard.new()
	transport.phase = 3
	transport.delivered = 1
	transport.credits = 205
	for level in range(1,Yard.CRATE_CAPACITIES.size()):
		check(transport.upgrade_crate() and transport.crate_capacity() == Yard.CRATE_CAPACITIES[level],
			"finished crate upgrades to %d slots" % Yard.CRATE_CAPACITIES[level])
	game.model = transport
	game.show_office(false)
	game.site.update_cart(transport,game.player,false)
	aim_at_station("cart")
	game.interact()
	check(transport.pushing_cart,"the unlocked cart can pick up finished crates")
	for i in Yard.CART_CRATE_LIMIT+1:
		fill_finished_crate(transport,i*3)
		aim_at_station("clean_crate")
		game.interact()
	game.site.update_cart(transport,game.player,false)
	check(transport.cart_crates.size() == 3 and transport.transport_finished_count() == 48 and
		transport.bench_crate.size() == 16 and game.site.cart_boxes.all(func(cargo: Node3D) -> bool: return cargo.visible and cargo.bottles.size() == 16),
		"the cart carries three visible 16-bottle crates and leaves the fourth at the bench")
	await enter_garage()
	if pictures:
		game.yaw = PI
		game.player.rotation.y = PI
		game.camera.look_at(game.site.targets.sale_window.position)
		key(KEY_W,true)
		for frame in 40:
			await physics_frame
		key(KEY_W,false)
		check(game.target_under_aim() == "sale_window" and transport.transport_finished_count() == 48,
			"the full cart can be pushed through the doorway to the sales window")
	else:
		aim_at_station("sale_window")
	game.site.update_cart(transport,game.player,false)
	game.park_cart()
	game.player.position = game.site.cart.position+Vector3(1.28,.006,-1.55)
	game.camera.look_at(game.site.cart.position+Vector3.UP*.56)
	game.status_ttl = 0.0
	await capture("45-three-crates-on-cart")
	var restored := Yard.new()
	restored.restore(JSON.parse_string(JSON.stringify(transport.serialize())))
	check(restored.cart_crates == transport.cart_crates and restored.bench_crate == transport.bench_crate and
		not restored.pushing_cart and restored.get("crate_level") == 3 and restored.unload_finished() == 0,
		"parked crates and the 16-slot upgrade survive reload and must be brought to the window")
	aim_at_station("cart")
	game.interact()
	aim_at_station("sale_window")
	game.interact()
	button(game.ui.unload_finished)
	check(transport.cart_crates.is_empty() and transport.sum_queue(Yard.FOR_SALE) == 48 and transport.bench_crate.size() == 16,
		"the window takes all three loaded crates and leaves the batch still at the bench alone")
	game.on_action("select_buyer",0)
	var payout: int = transport.sale_quote(0).y
	button(game.ui.confirm_sale)
	check(transport.delivered == 17 and transport.wallet_cents() == payout and transport.sale_stock(1) == 16,
		"the window pays for exactly the chosen bottle type from the three crates")
	game.model = business
	game.site.update_site(business,0)
	game.site.update_cart(business,game.player,false)
	game.show_office(true)


func fill_finished_crate(model, code: int) -> void:
	for i in model.crate_capacity():
		model.held = code
		model.held_queue = Yard.CLEAN
		model.set_down()
	model.held = code
	model.held_queue = Yard.CLEAN
	check(not model.set_down(),"the full crate rejects an extra bottle")
	model.held = -1
	model.held_queue = Yard.RAW


func verify_crate_saves() -> void:
	var old := Yard.new()
	old.queues[Yard.CLEAN][0] = 7
	old.received += 7
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(old.serialize()))
	snapshot.version = 7
	var upgraded := Yard.new()
	upgraded.restore(snapshot)
	check(upgraded.bench_crate.size() == 4 and upgraded.sum_queue(Yard.CLEAN) == 3 and upgraded.stage_for_sale() == 0,
		"a v7 manual save puts four actual bottles in the crate and preserves the remaining three")
	check(upgraded.take_crate() and not upgraded.take_crate() and upgraded.hand_crate.size() == 4 and upgraded.bench_crate.size() == 3,
		"one person carries one crate and the remaining legacy stock refills the bench")
	var restored := Yard.new()
	restored.restore(JSON.parse_string(JSON.stringify(upgraded.serialize())))
	check(restored.hand_crate == upgraded.hand_crate and restored.bench_crate == upgraded.bench_crate and restored.in_yard() == upgraded.in_yard(),
		"handheld and workbench crates survive serialization with no change in total bottles")


func verify_market() -> void:
	var sample := Yard.new()
	sample.phase = 1
	sample.queues[Yard.FOR_SALE][0] = 20
	var scarce_price: int = sample.sale_unit_price(0)
	var quota: int = sample.buyer_quota(0)
	sample.queues[Yard.FOR_SALE][0] = quota+501
	check(sample.sale_unit_price(0) < scarce_price and sample.sale_quote(0).x == quota,
		"larger offered supply lowers the price while the daily intake caps the quote")
	var small_sale: Vector2i = sample.sell_to(0,7)
	var bulk_sale: Vector2i = sample.sell_to(0)
	check(small_sale.x+bulk_sale.x == quota and sample.sale_quote(0) == Vector2i.ZERO and sample.sale_stock(0) == 501
		and sample.wallet_cents() == small_sale.y+bulk_sale.y,"repeated orders share one quota and preserve the exact cents received")
	sample.market_elapsed = Yard.MARKET_DAY_SECONDS-.25
	var restored := Yard.new()
	var saved: Dictionary = JSON.parse_string(JSON.stringify(sample.serialize()))
	restored.restore(saved)
	check(restored.buyer_remaining(0) == 0 and restored.market_wait_available()
		and is_equal_approx(restored.market_seconds_left(),.25) and restored.wallet_cents() == sample.wallet_cents(),
		"reloading preserves exhausted quotas, market time and fractional cash")
	restored.advance(.5)
	var quiet := Yard.new()
	quiet.phase = sample.phase
	quiet.turn_market_day()
	check(restored.market_day == 2 and is_equal_approx(restored.market_elapsed,.25) and restored.bought_yesterday[0] == quota
		and restored.buyer_quota(0) < quota and restored.buyer_quota(0) < quiet.buyer_quota(0)
		and restored.buyer_quota(1) == quiet.buyer_quota(1), "heavy purchases cut the next day's demand for that buyer alone")
	saved.version = 8
	quiet.restore(saved)
	check(quiet.market_day == 1 and quiet.buyer_remaining(0) == quota and quiet.credit_cents == 0 and quiet.credits == sample.credits,
		"v8 saves keep the existing balance and start with fresh market quotas")

	var regional := Yard.new()
	regional.phase = 4
	regional.installed[Yard.PACKER] = true
	regional.queues[Yard.FOR_SALE][0] = 1300001
	regional.queues[Yard.FOR_SALE][3] = 123456
	var regional_quota: int = regional.buyer_quota(0)
	var exact: Vector2i = regional.sale_quote(0)
	check(exact.x > 480000 and regional.sell_to(0) == exact and regional.wallet_cents() == exact.y,
		"a late-game buyer settles a single order of hundreds of thousands of bottles")
	regional.enable_auto_sales(true)
	regional.automatic_sales(1.0,1700)
	check(regional.bought_today[0] == regional_quota and regional.bought_today[1] == 15300,
		"automatic sales respect an exhausted quota and move to the next buyer")
	var active: RefCounted = game.model
	game.model = regional
	game.show_office(false)
	aim_at_station("sale_window")
	game.interact()
	game.on_action("select_buyer",0)
	check(game.ui.market_remaining[0].text == "已收满" and game.ui.confirm_sale.disabled and not game.ui.wait_market.disabled,
		"the sales window shows which buyer has reached its daily limit")
	regional.enable_auto_sales(false)
	button(game.ui.wait_market)
	check(regional.market_day == 2 and regional.buyer_quota(0) < regional_quota and not game.ui.confirm_sale.disabled,
		"waiting for tomorrow refreshes the window and makes the remaining stock sellable at a lower quota")
	await capture("46-market-next-day")
	game.model = active
	game.show_office(false)


func verify_garage_maximum() -> void:
	var regional := Yard.new()
	regional.queues[Yard.RAW].fill(0)
	regional.received = 0
	regional.phase = 4
	for truck in Yard.DAY_TRUCKS:
		regional.manifest(3,truck)
	game.site.garage.sync(regional)
	check(garage_visible_stock() == Yard.DAY_TRUCKS*Yard.TRUCK_SIZE,
		"the regional overflow piles allocate exactly one instance for every waiting bottle")
	regional.queues[Yard.RAW].fill(0)
	regional.queues[Yard.RAW][0] = 1
	game.site.garage.sync(regional)
	check(garage_visible_stock() == 1 and game.site.garage.floor_kinds[0] == 0 and game.site.garage.floor_kinds[1] == -1,
		"the last bottle is placed on the floor after the piles shrink")
	game.site.garage.sync(game.model)


func work_mouse(button: MouseButton, down: bool) -> void:
	if DisplayServer.get_name() == "headless":
		game.work_gesture(button,down)
		return
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = down
	game._input(event)


func verify_scraper_feedback() -> void:
	var cues: Array[String] = []
	var record := func(id: String) -> void: cues.append(id)
	game.hand.sound_requested.connect(record)
	var waveforms: Array[PackedByteArray] = []
	var previous_cut: float = 0.0
	for level in Yard.SCRAPERS.size():
		var spec: Dictionary = Yard.SCRAPERS[level]
		game.hand.load_bottle(3,Yard.RAW,level)
		game.hand.pose(.25)
		game.hand.cursor = game.hand.hotspot()
		cues.clear()
		game.hand.drag(Vector2(0,70))
		game.hand.cursor = game.hand.hotspot()
		game.hand.press_action()
		game.hand.pose(.10)
		check(cues.is_empty() and is_zero_approx(game.hand.progress),"blade %d is silent until actually cutting" % level)
		scrape_distance(80)
		var sound: AudioStreamWAV = game.sources.get(spec.cue)
		check(not cues.is_empty() and cues.all(func(id: String) -> bool: return id == spec.cue) and
			sound != null and not sound.data.is_empty() and not waveforms.has(sound.data),"blade %d cuts with a distinct sound" % level)
		if sound != null:
			waveforms.append(sound.data)
		var cut: float = game.hand.progress
		check(cut > previous_cut and cut < 1.0 and game.hand.emitted_flakes > 0,
			"blade %d shows shavings and cuts more plastic over the same drag" % level)
		previous_cut = cut
		game.hand.clear()
	game.hand.sound_requested.disconnect(record)


func verify_rinse_grips() -> void:
	game.working = true
	for kind in Yard.NAMES.size():
		game.hand.load_bottle(kind*Yard.CONDITION.size(),Yard.STRIPPED)
		game.hand.step = game.hand.stages.find("rinse_bead" if kind == 4 else "rinse")
		for frame in 32:
			game.focus_work_area(1.0/60.0)
			game.hand.pose(1.0/60.0)
		check(rinse_grip_fits(),"the rinse grip fits %s" % Yard.NAMES[kind])
		game.hand.rotating = true
		game.hand.drag(Vector2(64,0))
		for frame in 20:
			game.hand.pose(1.0/60.0)
		check(rinse_grip_fits(),"the rinse grip follows %s while turning" % Yard.NAMES[kind])
		game.hand.clear()
	game.working = false


func rinse_grip_fits() -> bool:
	var hand: Node3D = game.hand.arms[0]
	var profile: Array = Yard.BOTTLE_PROFILES[game.hand.type]
	var to_bottle: Transform3D = game.hand.bottle.transform.affine_inverse()*hand.transform
	for digit in 5:
		var pad: Vector3 = to_bottle*hand.fingertip_pad(digit)
		var gap: float = Vector2(pad.x,pad.z).length()-Shapes.radius_at(profile,pad.y)
		if gap < -.004 or gap > .0105:
			return false
		for joint_index in [1,2]:
			var joint: Vector3 = to_bottle*hand.finger_poses[digit*3+joint_index].origin
			if Vector2(joint.x,joint.z).length()-Shapes.radius_at(profile,joint.y) < .002:
				return false
	return true


func scrape_distance(distance: float) -> void:
	game.hand.pose(.09)
	var frames: int = ceili(distance/4.0)
	for i in frames:
		if not game.hand.pressed or game.hand.task() != game.hand.SCRAPE_LABEL:
			return
		game.hand.drag(Vector2(0,distance/frames))
		game.hand.pose(.05)


func scrape_strokes(count: int) -> void:
	for i in count:
		if game.hand.task() != game.hand.SCRAPE_LABEL:
			return
		game.hand.cursor = game.hand.hotspot()
		work_mouse(MOUSE_BUTTON_RIGHT,true)
		scrape_distance(game.hand.scrape_drag_length+8.0)
		work_mouse(MOUSE_BUTTON_RIGHT,false)


func wipe_distance(distance: float) -> void:
	var frames: int = ceili(absf(distance)/3.0)
	for i in frames:
		if not game.hand.pressed or game.hand.task() != "scrub":
			return
		game.hand.drag(Vector2(distance/frames,0))
		game.hand.pose(1.0/60.0)


func finish_held() -> void:
	if not game.hand.held or game.hand.quality == 2:
		return
	var moves: int = 0
	var max_moves: int = game.hand.stages.size()+game.hand.scrape_passes
	while not game.hand.done and moves < max_moves:
		moves += 1
		game.hand.cursor = game.hand.hotspot()
		var task: String = game.hand.task()
		if task == "rinse_bead":
			game.hand.rotating = true
			game.hand.drag(Vector2(82,0))
			game.hand.rotating = false
		game.hand.press_action()
		match task:
			"scrape_label": scrape_distance(215)
			"gasket": game.hand.drag(Vector2(0,175))
			"brush": game.hand.drag(Vector2(250,0))
			"scrub":
				if game.hand.glue_cleanup:
					for i in game.hand.wipe_strokes:
						var direction: float = -1.0 if game.hand.wipe_direction < 0.0 else 1.0
						wipe_distance(direction*(2.0*game.hand.WIPE_HALF_WIDTH+6.0))
				else:
					game.hand.drag(Vector2(250,0))
			"bore": game.hand.drag(Vector2(0,-176))
			"rinse","rinse_bead","sanitize","drain": game.hand.pose(game.hand.ACTIONS[task][2]+.05)
		game.hand.pressed = false
	check(game.hand.done,"hand gesture completes " + Yard.NAMES[game.hand.type])


func verify_type(type: int) -> void:
	var collected: int = game.model.collect(type)
	var began: bool = game.model.begin_carried()
	check(collected > 0 and began and game.model.kind(game.model.held) == type,"manually select mixed incoming bottle %d" % type)
	if not began:
		return
	game.hand.load_bottle(game.model.held,game.model.held_queue,game.model.equipped_scraper)
	finish_held()
	game.model.set_down()
	game.model.unload_carried()
	game.hand.clear()


func finish_remaining_storage() -> void:
	while not game.model.carried.is_empty():
		if game.model.bench_crate.size() == game.model.crate_capacity():
			deliver_manual_crate()
		aim_at_station("bench")
		game.interact()
		if not game.hand.held:
			check(false,"the bench accesses the next stored bottle")
			return
		finish_held()
		game.place_bottle()
		if game.hand.held:
			return


func button(node: Button) -> void:
	check(not node.disabled,"enabled terminal command: "+node.text)
	if not node.disabled:
		node.pressed.emit()


func advance_for(model, seconds: int) -> void:
	for i in seconds * 20:
		model.advance(.05)


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS  " if ok else "FAIL  ") + label)


func hand_frames(count: int) -> void:
	for i in count:
		await process_frame


func capture(label: String, settle_frames: int = 16) -> void:
	if not pictures:
		return
	await hand_frames(settle_frames)
	await RenderingServer.frame_post_draw
	var path: String = preview_dir.path_join(label+".png")
	check(root.get_texture().get_image().save_png(path) == OK, "saved render "+label)
