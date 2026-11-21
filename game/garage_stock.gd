extends Node3D

const Yard = preload("res://yard.gd")
const Shapes = preload("res://workshop_shapes.gd")
const PICK_POINT = Vector3(4.65,.15,1.54)
const FLOOR_CENTER = Vector3(6.08,0,1.54)
const FLOOR_HALF_SIZE = Vector2(1.88,1.56)
const SIGN_CENTER = Vector3(7.96,1.17,1.54)
const SIGN_SIZE = Vector3(1.26,.52,.086)
const FLOOR_CAPACITY = 72
const BULK_PILE_CAPACITY = 960
const INDOOR_PILE_ROWS = [4,3,5,2,6,1,7,0,8,9,10,11,12,13]
const INDOOR_PILES = 56

var count_sign: Label3D
var reverse_count_sign: Label3D
var floor_kinds := PackedInt32Array()
var floor_poses: Array[Transform3D] = []
var floor_bodies: Array[MultiMesh] = []
var floor_labels: Array[MultiMesh] = []
var bulk_full: Array[MultiMesh] = []
var bulk_partial: Array[MultiMesh] = []
var bulk_piles: Array = []
var apron: Node3D
var counts := PackedInt32Array()
var floor_counts := PackedInt32Array()
var pile_starts := PackedInt32Array()
var pile_counts := PackedInt32Array()


func build(site) -> void:
	var paint: Material = site.material("b99456",.94)
	for side in [-1.0,1.0]:
		site.box(FLOOR_CENTER+Vector3(side*FLOOR_HALF_SIZE.x,.012,0),Vector3(.045,.008,3.13),paint,self)
		site.box(FLOOR_CENTER+Vector3(0,.012,side*FLOOR_HALF_SIZE.y),Vector3(3.80,.008,.045),paint,self)
	var sign_board := Node3D.new()
	sign_board.position = SIGN_CENTER
	sign_board.rotation.y = -PI*.5
	add_child(sign_board)
	var steel: Material = site.surface("39463f",false,5)
	for x in [-.55,.55]:
		site.box(Vector3(x,-.59,0),Vector3(.055,1.16,.059),steel,sign_board)
	site.rounded(Vector3.ZERO,SIGN_SIZE,.018,steel,sign_board)
	count_sign = build_sign_face(site,sign_board,0.0,paint)
	reverse_count_sign = build_sign_face(site,sign_board,PI,paint)
	site.lamp(Vector3(5.94,3.06,1.63),"fff0d4",1.06,5.5)
	site.lamp(Vector3(9.05,3.42,2.30),"f0f5e9",.68,7.7)
	build_floor_poses()
	build_bulk_piles(site)
	floor_kinds.resize(FLOOR_CAPACITY)
	floor_kinds.fill(-1)
	floor_counts.resize(Yard.NAMES.size())
	for kind in Yard.NAMES.size():
		var tint: Material = site.bottle_material(kind)
		floor_bodies.append(make_instances(site.stock_meshes[kind],tint,FLOOR_CAPACITY,true))
		floor_labels.append(make_instances(site.stock_labels[kind],site.material(Yard.LABEL[kind],.85),FLOOR_CAPACITY,false))
		floor_bodies[kind].custom_aabb = AABB(FLOOR_CENTER+Vector3(-2.0,0,-1.7),Vector3(4.0,.64,3.4))
		floor_labels[kind].custom_aabb = floor_bodies[kind].custom_aabb


func build_sign_face(site, board: Node3D, rotation_y: float, paint: Material) -> Label3D:
	var face := Node3D.new()
	face.rotation.y = rotation_y
	board.add_child(face)
	var depth: float = SIGN_SIZE.z*.5
	site.box(Vector3(0,-.223,depth),Vector3(1.18,.024,.01),paint,face)
	site.text_at("车库来料区",Vector3(0,.089,depth+.010),54,.0035,"fff3d4",face)
	return site.text_at("",Vector3(0,-.087,depth+.010),44,.0030,"f0c783",face)


func pickup_point(standing_at: Vector3, eye: Vector3, forward: Vector3) -> Vector3:
	var feet: Vector3 = standing_at-FLOOR_CENTER
	var outside := Vector2(maxf(0.0,absf(feet.x)-FLOOR_HALF_SIZE.x),maxf(0.0,absf(feet.z)-FLOOR_HALF_SIZE.y))
	if outside.length_squared() > 1.15*1.15:
		return Vector3.INF
	if absf(forward.x) > .01:
		var sign_distance: float = (SIGN_CENTER.x-eye.x)/forward.x
		var offset: Vector3 = eye+forward*sign_distance-SIGN_CENTER
		if sign_distance > 0.0 and absf(offset.y) <= SIGN_SIZE.y*.5 and absf(offset.z) <= SIGN_SIZE.x*.5:
			return SIGN_CENTER+offset
	if forward.y >= -.10:
		return Vector3.INF
	var point: Vector3 = eye+forward*((.13-eye.y)/forward.y)
	var from_center: Vector3 = point-FLOOR_CENTER
	if absf(from_center.x) > FLOOR_HALF_SIZE.x+.08 or absf(from_center.z) > FLOOR_HALF_SIZE.y+.08:
		return Vector3.INF
	return point


func build_floor_poses() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 43071
	var layers := [Vector2i(4,7),Vector2i(3,7),Vector2i(3,5),Vector2i(2,4)]
	for height in layers.size():
		var center: Vector3 = FLOOR_CENTER+Vector3(-.25+sin(height*2.4)*.065,.058+height*.086,cos(height*2.1)*.055)
		var angle: float = [-.17,1.37,.31,1.73][height]
		for spot in layer_spots(layers[height],.29,.111):
			var offset: Vector2 = spot.rotated(angle)
			if height == 0 and offset.length_squared() > .18:
				offset *= random.randf_range(1.03,1.24)
			var at := center+Vector3(offset.x+random.randf_range(-.071,.071),random.randf_range(-.006,.012),
				offset.y+random.randf_range(-.068,.068))
			var yaw: float = angle+random.randf_range(-.62,.62)+(PI if random.randi_range(0,1) == 1 else 0.0)
			var tilt: float = random.randf_range(1.16,1.82) if height > 0 else random.randf_range(1.47,1.62)
			floor_poses.append(bottle_pose(at,yaw,tilt,random.randf_range(-PI,PI)))


func layer_spots(dimensions: Vector2i, length_pitch: float, width_pitch: float) -> Array[Vector2]:
	var spots: Array[Vector2] = []
	for x in dimensions.x:
		for z in dimensions.y:
			spots.append(Vector2((x-(dimensions.x-1)*.5)*length_pitch,(z-(dimensions.y-1)*.5)*width_pitch))
	spots.sort_custom(func(a: Vector2,b: Vector2) -> bool: return a.length_squared() < b.length_squared())
	return spots


func bottle_pose(center: Vector3, yaw: float, tilt: float, roll: float) -> Transform3D:
	var axis := Vector3(cos(yaw)*sin(tilt),cos(tilt),sin(yaw)*sin(tilt))
	var rotation: Basis = Basis(Quaternion(Vector3.UP,axis))*Basis(Vector3.UP,roll)
	return Transform3D(rotation,center-axis*.143)


func make_instances(shape: Mesh, material: Material, capacity: int, casts_shadow: bool) -> MultiMesh:
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = shape
	batch.instance_count = capacity
	batch.visible_instance_count = 0
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = batch
	instance.material_override = material
	if not casts_shadow:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return batch


func build_bulk_piles(site) -> void:
	apron = site.box(Vector3(49,-.14,-45),Vector3(70,.28,114),site.surface("676861"),self,true)
	apron.hide()
	var poses: Array[Transform3D] = build_bulk_poses()
	pile_starts.resize(Yard.NAMES.size())
	pile_starts.fill(-1)
	pile_counts.resize(Yard.NAMES.size())
	for kind in Yard.NAMES.size():
		var profile: Array = Yard.BOTTLE_PROFILES[kind]
		var height: float = profile.back()[0]
		var reduced: Array = [[0.0,0.0]]
		for fraction in [0.0,.09,.54,.69,.86,1.0]:
			var y: float = fraction*height
			reduced.append([y,Shapes.radius_at(profile,y)])
		reduced.append([height-.011,0.0])
		var mesh: ArrayMesh = Shapes.lathe(reduced,6)
		mesh.surface_set_material(0,site.bottle_material(kind))
		var full := MultiMesh.new()
		var partial := MultiMesh.new()
		for batch in [full,partial]:
			batch.mesh = mesh
			batch.transform_format = MultiMesh.TRANSFORM_3D
			batch.instance_count = BULK_PILE_CAPACITY
			batch.custom_aabb = AABB(Vector3(-.72,0,-.75),Vector3(1.44,2.72,1.50))
		for slot in poses.size():
			full.set_instance_transform(slot,poses[slot])
			partial.set_instance_transform(slot,poses[slot])
		bulk_full.append(full)
		bulk_partial.append(partial)
		bulk_piles.append([])


func build_bulk_poses() -> Array[Transform3D]:
	var random := RandomNumberGenerator.new()
	random.seed = 64983
	var poses: Array[Transform3D] = []
	var layer: int = 0
	while poses.size() < BULK_PILE_CAPACITY:
		var angle: float = (PI*.5 if layer%2 == 1 else 0.0)+random.randf_range(-.19,.19)
		var dimensions := Vector2i(4 if layer < 20 else 3,maxi(5,12-layer/4))
		for spot in layer_spots(dimensions,.298,.105):
			var offset: Vector2 = spot.rotated(angle)
			var at := Vector3(offset.x+random.randf_range(-.027,.027),.056+layer*.086+random.randf_range(-.004,.013),
				offset.y+random.randf_range(-.026,.026))
			var yaw: float = angle+random.randf_range(-.35,.35)+(PI if random.randi_range(0,1) == 1 else 0.0)
			poses.append(bottle_pose(at,yaw,random.randf_range(1.47,1.64),random.randf_range(-PI,PI)))
			if poses.size() == BULK_PILE_CAPACITY:
				break
		layer += 1
	return poses


func sync(model) -> void:
	var available := PackedInt32Array()
	for kind in Yard.NAMES.size():
		available.append(model.available(kind))
	if counts == available:
		return
	counts = available
	var total: int = 0
	for amount in counts:
		total += amount
	sync_floor(total)
	sync_bulk_piles()
	count_sign.text = "%d 只待取" % total
	reverse_count_sign.text = count_sign.text


func sync_floor(total: int) -> void:
	var occupied: int = mini(total,FLOOR_CAPACITY)
	floor_counts.fill(0)
	var open_slots := PackedInt32Array()
	var remaining_total: int = total
	for slot in range(occupied,FLOOR_CAPACITY):
		floor_kinds[slot] = -1
	for slot in occupied:
		var kind: int = floor_kinds[slot]
		if kind >= 0 and floor_counts[kind] < counts[kind]:
			floor_counts[kind] += 1
			remaining_total -= 1
		else:
			floor_kinds[slot] = -1
			open_slots.append(slot)
	for slot in open_slots:
		var draw: int = ((slot+19)*2654435761)%remaining_total
		for kind in Yard.NAMES.size():
			draw -= counts[kind]-floor_counts[kind]
			if draw < 0:
				floor_kinds[slot] = kind
				floor_counts[kind] += 1
				remaining_total -= 1
				break
	var drawn := PackedInt32Array()
	drawn.resize(Yard.NAMES.size())
	for slot in occupied:
		var kind: int = floor_kinds[slot]
		if kind >= 0:
			var pose: Transform3D = floor_poses[slot]
			floor_bodies[kind].set_instance_transform(drawn[kind],pose)
			floor_labels[kind].set_instance_transform(drawn[kind],pose)
			drawn[kind] += 1
	for kind in Yard.NAMES.size():
		floor_bodies[kind].visible_instance_count = drawn[kind]
		floor_labels[kind].visible_instance_count = drawn[kind]


func sync_bulk_piles() -> void:
	var next_slot: int = 0
	for kind in Yard.NAMES.size():
		var units: int = counts[kind]-floor_counts[kind]
		var needed: int = (units+BULK_PILE_CAPACITY-1)/BULK_PILE_CAPACITY
		var partial: int = units%BULK_PILE_CAPACITY
		var group: Array = bulk_piles[kind]
		if needed != pile_counts[kind] or next_slot != pile_starts[kind]:
			while group.size() < needed:
				group.append(make_bulk_pile())
			for index in maxi(needed,pile_counts[kind]):
				var pile: MultiMeshInstance3D = group[index]
				pile.visible = index < needed
				if pile.visible:
					pile.position = bulk_pile_position(next_slot+index)
					pile.rotation.y = sin((next_slot+index)*2.4)*.055
					pile.multimesh = bulk_full[kind]
			pile_starts[kind] = next_slot
			pile_counts[kind] = needed
		if needed > 0:
			var last: MultiMeshInstance3D = group[needed-1]
			bulk_partial[kind].visible_instance_count = partial
			last.multimesh = bulk_partial[kind] if partial > 0 else bulk_full[kind]
		next_slot += needed
	apron.visible = next_slot > INDOOR_PILES


func make_bulk_pile() -> MultiMeshInstance3D:
	var pile := MultiMeshInstance3D.new()
	pile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pile.visibility_range_end = 46.0
	add_child(pile)
	return pile


func bulk_pile_position(index: int) -> Vector3:
	if index < INDOOR_PILES:
		var row: int = INDOOR_PILE_ROWS[index/4]
		return Vector3(8.72+(index%4)*1.36,.014,8.0-row*1.48)
	var outside: int = index-INDOOR_PILES
	var row: int = outside/46
	return Vector3(15.62+(outside%46)*1.44,.014,8.5-row*1.53)
