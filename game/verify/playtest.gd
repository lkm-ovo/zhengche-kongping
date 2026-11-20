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
	check(game.site.crate_counts[0].text == "36 只" and game.ui.objective.text.contains("72"),"the room and HUD show the increased intake")
	check(game.camera.current and game.player is CharacterBody3D, "first-person character and camera")
	while game.scene_loading:
		await process_frame
	await capture("01-worksite")
	await verify_opening_journal()
	verify_line_layout()
	await verify_room()
	await verify_sale_shelf()
	if pictures:
		var initial_z: float = game.player.position.z
		key(KEY_W,true)
		for i in 55:
			await physics_frame
		key(KEY_W,false)
		check(game.player.position.z < initial_z - .7, "W moves the worker")
		check(game.player.position.z > .67, "the workbench has a physical collision")
	if game.target_under_aim() != "bench":
		game.player.position = Vector3(game.site.STRIP_X,.02,1.65)
		game.camera.look_at(game.site.targets.bench.position)
	check(game.target_under_aim() == "bench", "aim at the physical workbench")
	game.interact()
	check(game.working and game.hand.held and game.hand.task() == "scrape_label", "interact takes a beer bottle for scraping")
	check(game.hand.arms[0].skeleton.find_bone("SleeveUpperArm") >= 0 and
		game.hand.arms[1].skeleton.find_bone("SleeveForearm") >= 0 and
		game.hand.arms[1].hand_mesh.mesh.surface_get_array_len(0) > 5000,
		"both hands load the skinned anatomical mesh")
	await hand_frames(26)
	var frame_size: Vector2 = root.get_visible_rect().size
	var bottle_base: Vector2 = game.camera.unproject_position(game.hand.bottle.global_position)
	var bottle_mouth: Vector2 = game.camera.unproject_position(game.hand.bottle.to_global(Vector3.UP*game.hand.bottle_height()))
	var scrape_target: Vector2 = game.hand.hotspot()
	check(game.camera.fov < 37.5 and game.camera.rotation.x < -.55 and
		bottle_base.y-bottle_mouth.y > frame_size.y*.68 and bottle_base.y < frame_size.y*.81 and bottle_mouth.y > 0.0,
		"scraping leans in and frames the whole bottle above the work panel")
	check(scrape_target.distance_to(frame_size*.5) < frame_size.y*.10 and game.hand.cursor.distance_to(scrape_target) < 8.0,
		"the label and scrape cursor stay aligned near the center during zoom")
	await capture("02-hold",0)
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
	await hand_frames(13)
	var start: Vector3 = game.hand.scraper.transform*Shapes.SCRAPER_EDGE
	var start_height: float = (game.hand.bottle.transform.affine_inverse()*start).y
	check(start.distance_to(game.hand.scrape_point(0.0)) < .004 and game.hand.scraper.visible and
		not game.site.table_scraper.visible,"the handheld scraper rests against the label")
	await capture("14-scraper-on-label")
	check(is_zero_approx(game.hand.progress), "holding the right mouse button without dragging cannot scrape")
	game.hand.drag(Vector2(0,900))
	await hand_frames(3)
	check(game.hand.progress > 0.0 and game.hand.progress < .015, "a fast downward flick only scrapes a tiny section")
	scrape_distance(77)
	check(game.hand.scrape_passes == 2 and game.hand.progress > .29 and game.hand.progress < .35,
		"the starter blade needs two passes on a paper label")
	await hand_frames(18)
	var scraped: Vector3 = game.hand.scraper.transform*Shapes.SCRAPER_EDGE
	var scraped_height: float = (game.hand.bottle.transform.affine_inverse()*scraped).y
	check(start_height-scraped_height > .032 and scraped.distance_to(game.hand.scrape_point(game.hand.stroke_travel)) < .004,
		"the scraper edge slides down against the glass")
	check(game.hand.cursor.distance_to(game.hand.hotspot()) < 1.0, "the scrape cursor follows the blade during the stroke")
	check(game.hand.label_mesh.visible and game.hand.label_material.get_shader_parameter("scraped") > .29 and
		game.site.label_offcuts.size() >= 2,"the scraped band reveals glass and drops small flakes")
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
	check(game.hand.scrape_pressure == 0.0 and game.hand.label_mesh.visible and game.hand.progress > .29 and blade_off.distance_to(scraped) > .020,
		"letting go lifts the blade and preserves the scraped band")
	game.hand.cursor = game.hand.hotspot()
	work_mouse(MOUSE_BUTTON_RIGHT,true)
	await hand_frames(16)
	var blade_back: Vector3 = game.hand.scraper.transform*Shapes.SCRAPER_EDGE
	check(game.hand.pressed and game.hand.scrape_point(game.hand.stroke_travel).distance_to(blade_back) < .004,
		"scraping resumes at the partially cleared band")
	scrape_distance(245)
	check(game.hand.scrape_between_passes and not game.hand.pressed and is_equal_approx(game.hand.progress,.5),
		"a long stroke stops at the first pass and leaves scraps of label")
	game.hand.drag(Vector2(0,245))
	check(is_equal_approx(game.hand.progress,.5), "the next pass requires a new press")
	await hand_frames(24)
	await capture("26-old-blade-partial-label")
	game.hand.cursor = game.hand.hotspot()
	work_mouse(MOUSE_BUTTON_RIGHT,false)
	work_mouse(MOUSE_BUTTON_RIGHT,true)
	scrape_distance(168)
	work_mouse(MOUSE_BUTTON_RIGHT,false)
	check(game.hand.label_removed and game.hand.task() == "scrub" and game.model.held_queue < Yard.STRIPPED,
		"the old blade leaves adhesive that must be wiped before the checkpoint")
	check(game.hand.view_task() == "scrape_label", "the blade finishes its stroke before wiping")
	await capture("15-scrape-finish",6)
	await hand_frames(14)
	check(not game.hand.label_mesh.visible and not game.hand.scraper.visible and game.site.table_scraper.visible,
		"the label clears and the scraper is back on the bench before wiping")
	check(game.hand.residue.visible and game.hand.towel.visible, "remaining adhesive is visible with the cleaning cloth")
	await capture("27-wipe-adhesive")
	game.hand.cursor = game.hand.hotspot()
	game.hand.press_action()
	game.hand.drag(Vector2(220,0))
	check(game.hand.task() == "rinse" and game.hand.surface_wiped, "wiping the adhesive unlocks rinsing")
	game.interact()
	check(game.model.held_queue == Yard.STRIPPED and game.model.stage_for_sale() == 0,
		"a stripped but unwashed bottle cannot ship")
	game.status_ttl = 0.0
	await verify_manual_wash()
	check(game.camera.fov > 61.5, "the scraping close-up opens back out for the wash and finish stations")
	await capture("04-clean")
	game.place_bottle()
	var shown_sleeve: bool = false
	var shown_milk: bool = false
	for i in Yard.STARTER_SIZE-1:
		game.take_bottle()
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
			scrape_distance(93)
			await hand_frames(18)
			check(game.hand.scrape_passes == 3 and game.hand.progress > .23 and game.hand.progress < .27 and game.hand.scraper.visible,
				"the original blade takes three passes to remove a plastic label")
			await capture("16-scrape-plastic")
		elif pictures and game.hand.type == 2 and not shown_milk:
			shown_milk = true
			for frame in 25:
				await process_frame
			await capture("09-milk")
		finish_held()
		game.place_bottle()
	check(game.model.sum_queue(Yard.CLEAN) == 69 and game.model.recycled == 3, "69 starter bottles cleaned and three cracked units recycled")
	check(game.site.label_offcuts.size() >= 5 and game.site.label_offcuts.size() <= 24,
		"scraping leaves a bounded pile of fragments on the bench")
	await verify_first_sale()
	check(game.model.story_chapter() == Yard.Story.FIRST_SALE and game.ui.story_hint.text.contains("新章节"),
		"first payout unlocks an unread story chapter")
	game.status_ttl = 0.0
	game.on_action("open_tools",0)
	check(game.ui.tool_shop.is_visible_in_tree() and game.ui.tool_buttons[2].disabled,
		"the tool shop shows the upgrade sequence")
	await capture("28-scraper-shop")
	button(game.ui.tool_buttons[1])
	check(game.model.equipped_scraper == 1 and game.model.owned_scraper == 1 and game.model.credits == 80,
		"starter sales buy and equip the thin blade for 24")
	check(game.ui.tool_buttons[2].disabled and not game.model.choose_scraper(2),
		"a later purchase cannot consume funds needed to open the next shipment")
	game.on_action("open_operations",0)
	button(game.ui.machine_buttons[0])
	check(game.model.installed[0], "the first tray still funds the first stripper after buying the thin blade")
	check(game.model.story_chapter() == Yard.Story.FIRST_MACHINE, "installing the first machine turns the story page")
	button(game.ui.place_order)
	check(game.model.phase == 1 and game.model.in_yard() == 600, "street restock delivers 600 bottles")
	game.take_bottle(0)
	game.hand.cursor = game.hand.hotspot()
	game.hand.press_action()
	scrape_distance(150)
	check(game.hand.scraper_level == 1 and game.hand.task() == "rinse" and not game.hand.glue_cleanup,
		"the purchased thin blade clears a clean paper label in one pass")
	finish_held()
	game.place_bottle()
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
	verify_type(4)
	verify_type(5)
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
	verify_legacy_volume()
	verify_story_save()
	verify_scraper_feedback()
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
	check(paid.x == 1 and business.story_recovered and business.credits == Yard.STORY_TARGET-1+paid.y,
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


func verify_line_layout() -> void:
	var site: Node3D = game.site
	check(is_equal_approx(site.SANITIZER_TRAY.z,site.COUNTER_Z) and
		is_equal_approx(site.DRAIN_PIN.z,site.COUNTER_Z) and
		is_equal_approx(site.CLEAN_CRATE.z,site.COUNTER_Z) and
		is_equal_approx(site.SALE_SHELF.z,site.COUNTER_Z),"finishing stations share the same counter depth")
	for part in site.crates_available:
		check(is_equal_approx(part.position.z,site.COUNTER_Z),"each infeed crate is on the work line")
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


func verify_sale_shelf() -> void:
	var start: Vector3 = game.player.position
	var look: Vector3 = game.camera.rotation
	game.player.position = Vector3(game.site.SALE_SHELF.x,.02,1.72)
	game.player.rotation.y = 0.0
	game.camera.look_at(game.site.targets.sale_shelf.position)
	await physics_frame
	await process_frame
	check(game.target_under_aim() == "sale_shelf", "the sales shelf is interactive in the processing room")
	game.interact()
	check(game.office and game.ui.market.is_visible_in_tree(), "E at the shelf opens the buyer list")
	game.show_office(false)
	game.camera.look_at(game.site.targets.office.position)
	check(game.target_under_aim() == "office","the counter terminal remains independently reachable from the aisle")
	game.player.position = start
	game.player.rotation.y = 0.0
	game.camera.rotation = look
	await physics_frame


func verify_later_scrapers() -> void:
	game.on_action("open_tools",0)
	button(game.ui.tool_buttons[2])
	game.on_action("open_operations",0)
	game.take_bottle(1)
	game.hand.cursor = game.hand.hotspot()
	game.hand.press_action()
	scrape_distance(85)
	check(game.hand.scraper_level == 2 and game.hand.scrape_passes == 1 and game.hand.task() == "scrape_label" and not game.hand.glue_cleanup,
		"the curved blade prepares plastic for one clean pass")
	game.on_action("open_tools",0)
	button(game.ui.tool_buttons[3])
	check(game.model.equipped_scraper == 3 and game.hand.scraper_level == 2 and game.hand.progress > .6,
		"equipping a new blade preserves work on the bottle already in hand")
	var restored := Yard.new()
	restored.restore(JSON.parse_string(JSON.stringify(game.model.serialize())))
	var funds: int = restored.credits
	check(restored.owned_scraper == 3 and restored.equipped_scraper == 3 and restored.choose_scraper(0) and
		restored.choose_scraper(3) and restored.credits == funds,"owned blades and selection survive reload, and switching is free")
	game.show_office(false)
	finish_held()
	game.place_bottle()
	game.take_bottle(1)
	game.status_ttl = 0.0
	await hand_frames(25)
	game.hand.cursor = game.hand.hotspot()
	game.hand.press_action()
	await capture("29-spring-scraper")
	scrape_distance(85)
	check(game.hand.scraper_level == 3 and game.hand.scraper.get_meta("level") == 3 and game.hand.task() == "rinse",
		"the spring blade equips on the next bottle and finishes the shorter plastic scrape")
	finish_held()
	game.place_bottle()
	game.show_office(true)


func verify_first_sale() -> void:
	game.interact()
	check(game.ui.market.is_visible_in_tree(), "the first completed batch points to sales")
	check(game.ui.confirm_sale.disabled and game.model.credits == 0, "clean crated stock earns no money before sale")
	button(game.ui.pack_for_sale)
	check(game.model.credits == 0 and game.model.sum_queue(Yard.FOR_SALE) == 69 and game.model.delivered == 0,
		"staging the crate increases sale inventory without cash or delivery")
	button(game.ui.buyer_buttons[1])
	check(game.ui.selected_buyer == 1 and game.model.sale_quote(1) == Vector2i(23,46), "soda buyer quotes 23 bottles at 2 each")
	var waiting := Yard.new()
	waiting.restore(JSON.parse_string(JSON.stringify(game.model.serialize())))
	check(waiting.sum_queue(Yard.FOR_SALE) == 69 and waiting.credits == 0, "unsold stock and money survive reload")
	await capture("13-sales")
	button(game.ui.confirm_sale)
	check(game.model.credits == 46 and game.model.delivered == 23 and game.model.sale_stock(0) == 34 and game.model.sale_stock(1) == 0,
		"confirming the soda order settles only its 23 bottles")
	check(game.model.sell_to(1) == Vector2i.ZERO and game.model.credits == 46, "a sold order cannot be paid twice")
	sell_ready_crates()
	check(game.model.delivered == 69 and game.model.in_yard() == 0 and game.model.credits == 104,
		"the starter crate earns the exact proceeds from the three buyers")


func sell_ready_crates() -> void:
	game.show_office(true,true)
	if not game.ui.pack_for_sale.disabled:
		button(game.ui.pack_for_sale)
	var orders: int = 0
	while not game.ui.confirm_sale.disabled and orders < 20:
		button(game.ui.confirm_sale)
		orders += 1
	game.show_office(true)


func verify_manual_wash() -> void:
	await hand_frames(30)
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
	check(waiting.sum_queue(Yard.WASHED) == 1 and waiting.held == -1, "a washed held bottle resumes at disinfection")
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
	advance_for(migrated,1)
	check(migrated.credits == 23 and migrated.delivered == 3, "v2 migrated stock settles once at the new price")
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
		scrape_distance(60)
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


func scrape_distance(distance: float) -> void:
	game.hand.pose(.09)
	var frames: int = ceili(distance/4.0)
	for i in frames:
		if not game.hand.pressed or game.hand.task() != game.hand.SCRAPE_LABEL:
			return
		game.hand.drag(Vector2(0,distance/frames))
		game.hand.pose(.05)


func finish_held() -> void:
	if not game.hand.held or game.hand.quality == 2:
		return
	var moves: int = 0
	while not game.hand.done and moves < 14:
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
			"brush","scrub": game.hand.drag(Vector2(250,0))
			"bore": game.hand.drag(Vector2(0,-176))
			"rinse","rinse_bead","sanitize","drain": game.hand.pose(game.hand.ACTIONS[task][2]+.05)
		game.hand.pressed = false
	check(game.hand.done,"hand gesture completes " + Yard.NAMES[game.hand.type])


func verify_type(type: int) -> void:
	var pick: Vector2i = game.model.take(type)
	check(pick.x >= 0 and game.model.kind(pick.x) == type,"manually select mixed incoming bottle %d" % type)
	if pick.x < 0:
		return
	game.hand.load_bottle(pick.x,pick.y,game.model.equipped_scraper)
	finish_held()
	game.model.set_down()
	game.hand.clear()


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
