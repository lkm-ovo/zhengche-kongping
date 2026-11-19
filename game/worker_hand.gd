extends Node3D

const Shapes = preload("res://workshop_shapes.gd")
const FIRST_FOREARM_BONE = 16
const SLEEVE_FOREARM = 19
const SLEEVE_UPPER_ARM = 20
const FOREARM_LENGTH = .255
const UPPER_ARM_LENGTH = .304
const FINGERS = 5
const BRUSH_GRIP = Vector3(-.012,.047,-.025)
const PAD_INSET = Vector3(0,-.0035,-.004)

var skeleton: Skeleton3D
var rest_joints: Array = []
var finger_lengths: Array = []
var arm_pins: Array[Vector3] = []
var rest_wrist: Vector3
var poses: Dictionary = {}
var gesture: String = ""
var finger_poses: Array[Transform3D] = []
var hand_mesh: MeshInstance3D
var forearm_rest: Basis


func build(asset: Dictionary, material: Material, fabric: Material) -> void:
	for digit in asset.joints:
		var endpoints: Array[Vector3] = []
		for point in digit:
			endpoints.append(vector(point))
		rest_joints.append(endpoints)
		var lengths: Array[float] = []
		for link in 3:
			lengths.append(endpoints[link].distance_to(endpoints[link+1]))
		finger_lengths.append(lengths)
	for pin in asset.armPins:
		arm_pins.append(vector(pin))
	rest_wrist = vector(asset.wrist)
	skeleton = Skeleton3D.new()
	skeleton.name = "HandRig"
	add_child(skeleton)
	var binding := Skin.new()
	skeleton.add_bone("Palm")
	binding.add_bind(0,Transform3D.IDENTITY)
	for digit in FINGERS:
		for part in 3:
			var id: int = 1+digit*3+part
			bind_bone(id,"Digit%d_%d" % [digit,part],frame(rest_joints[digit][part],rest_joints[digit][part+1]),binding)
	for i in arm_pins.size():
		var axis: Vector3 = rest_wrist-arm_pins[0]
		bind_bone(FIRST_FOREARM_BONE+i,"Forearm%d" % i,frame(arm_pins[i],arm_pins[i]+axis),binding)
	forearm_rest = frame(arm_pins[0],rest_wrist).basis
	var rest_elbow: Vector3 = rest_wrist-forearm_rest.y*FOREARM_LENGTH
	bind_bone(SLEEVE_FOREARM,"SleeveForearm",Transform3D(forearm_rest,rest_elbow),binding)
	bind_bone(SLEEVE_UPPER_ARM,"SleeveUpperArm",
		Transform3D(forearm_rest,rest_elbow-forearm_rest.y*UPPER_ARM_LENGTH),binding)
	var mesh := ArrayMesh.new()
	var buffers: Array = []
	buffers.resize(Mesh.ARRAY_MAX)
	buffers[Mesh.ARRAY_VERTEX] = vectors(asset.positions)
	buffers[Mesh.ARRAY_NORMAL] = vectors(asset.normals)
	var uv := PackedVector2Array()
	var raw_uv: Array = asset.uvs
	for i in range(0,raw_uv.size(),2):
		uv.append(Vector2(raw_uv[i],raw_uv[i+1]))
	buffers[Mesh.ARRAY_TEX_UV] = uv
	buffers[Mesh.ARRAY_INDEX] = PackedInt32Array(asset.indices)
	buffers[Mesh.ARRAY_BONES] = PackedInt32Array(asset.bones)
	buffers[Mesh.ARRAY_WEIGHTS] = PackedFloat32Array(asset.weights)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,buffers)
	hand_mesh = skinned_mesh(mesh,material,binding)
	skinned_mesh(sleeve_mesh(),fabric,binding)


func skinned_mesh(mesh: ArrayMesh, material: Material, binding: Skin) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	part.extra_cull_margin = .65
	add_child(part)
	part.skeleton = part.get_path_to(skeleton)
	part.skin = binding
	return part


func sleeve_mesh() -> ArrayMesh:
	# Two rolled edges at the cuff and extra loops across the elbow keep the fabric soft when it bends.
	var profile := [[-.752,.063],[-.686,.066],[-.619,.066],[-.558,.064],[-.489,.058],[-.417,.052],[-.335,.047],
		[-.302,.045],[-.284,.043],[-.266,.044],[-.250,.044],[-.233,.042],[-.211,.044],
		[-.177,.045],[-.146,.045],[-.131,.044],[-.125,.046],[-.119,.046],[-.116,.044],
		[-.107,.045],[-.103,.045],[-.099,.042],[-.098,.037]]
	var buffers: Array = Shapes.lathe(profile,30).surface_get_arrays(0)
	var points: PackedVector3Array = buffers[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = buffers[Mesh.ARRAY_NORMAL]
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	for i in points.size():
		var point: Vector3 = points[i]
		var upper: float = 1.0-smoothstep(-FOREARM_LENGTH-.056,-FOREARM_LENGTH+.051,point.y)
		bones.append_array([SLEEVE_FOREARM,SLEEVE_UPPER_ARM,0,0])
		weights.append_array([1.0-upper,upper,0.0,0.0])
		point.x *= 1.025
		point.z *= .935
		points[i] = rest_wrist+forearm_rest*point
		normals[i] = forearm_rest*normals[i]
	buffers[Mesh.ARRAY_VERTEX] = points
	buffers[Mesh.ARRAY_NORMAL] = normals
	buffers[Mesh.ARRAY_BONES] = bones
	buffers[Mesh.ARRAY_WEIGHTS] = weights
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,buffers)
	return mesh


func bind_bone(id: int, name: String, rest: Transform3D, binding: Skin) -> void:
	skeleton.add_bone(name)
	skeleton.set_bone_parent(id,0)
	skeleton.set_bone_rest(id,rest)
	skeleton.set_bone_pose(id,rest)
	binding.add_bind(id,rest.affine_inverse())


func vector(point: Array) -> Vector3:
	return Vector3(point[0],point[1],point[2])


func vectors(values: Array) -> PackedVector3Array:
	var result := PackedVector3Array()
	for i in range(0,values.size(),3):
		result.append(Vector3(values[i],values[i+1],values[i+2]))
	return result


func frame(start: Vector3, end: Vector3) -> Transform3D:
	var forward: Vector3 = (end-start).normalized()
	var guide: Vector3 = Vector3.FORWARD if absf(forward.x) > .95 else Vector3.RIGHT
	var right: Vector3 = guide.slide(forward).normalized()
	return Transform3D(Basis(right,forward,right.cross(forward)),start)


func register_pose(name: String, sketches: Array, pinch: Vector3) -> void:
	var targets: Array[Transform3D] = []
	for digit in FINGERS:
		var rest: Array[Vector3] = rest_joints[digit]
		var sketch: Array[Vector3] = sketches[digit]
		var lengths: Array[float] = finger_lengths[digit]
		var points: Array[Vector3] = [rest[0]]
		for link in 3:
			var direction: Vector3 = (sketch[link+1]-sketch[link]).normalized()
			points.append(points[link]+direction*lengths[link])
		if name in ["pinch","reach"] and digit in [0,4]:
			var aperture: float = .0012 if name == "pinch" else .010
			var gap: float = aperture if digit == 0 else -aperture
			solve_pad(points,lengths,pinch+Vector3(0,gap,.004 if name == "reach" else 0.0))
		elif name == "tool" and digit in [0,1,4]:
			var contact: Vector3 = [Vector3(.003,.014,-.009),Vector3(.008,-.005,-.010),Vector3.ZERO,Vector3.ZERO,Vector3(-.007,.007,.006)][digit]
			solve_finger(points,lengths,BRUSH_GRIP+contact)
		for link in 3:
			targets.append(frame(points[link],points[link+1]))
	poses[name] = targets


func register_grip_pose(name: String, fingers: Array, thumb: Array) -> void:
	var targets: Array[Transform3D] = []
	for digit in FINGERS:
		var joint: Vector3 = rest_joints[digit][0]
		var pitch: float = 0.0
		for link in 3:
			var spread: float
			if digit == 4:
				var thumb_link: Vector2 = thumb[link]
				pitch = deg_to_rad(thumb_link.x)
				spread = deg_to_rad(thumb_link.y)
			else:
				var curl: Vector4 = fingers[digit]
				pitch += deg_to_rad(curl[link])
				spread = deg_to_rad(curl.w)
			var direction := Vector3(sin(spread)*cos(pitch),cos(spread)*cos(pitch),-sin(pitch))
			var end: Vector3 = joint+direction*float(finger_lengths[digit][link])
			targets.append(frame(joint,end))
			joint = end
	poses[name] = targets


func solve_pad(points: Array[Vector3], lengths: Array[float], pad: Vector3) -> void:
	for pass_index in 5:
		var tip: Basis = frame(points[2],points[3]).basis
		solve_finger(points,lengths,pad-tip*PAD_INSET)


func solve_finger(points: Array[Vector3], lengths: Array[float], target: Vector3) -> void:
	var base: Vector3 = points[0]
	var max_reach: float = lengths[0]+lengths[1]+lengths[2]-.0008
	if target.distance_to(base)>max_reach:
		target = base+(target-base).normalized()*max_reach
	for pass_index in 12:
		points[3] = target
		for i in range(2,-1,-1):
			points[i] = points[i+1]+(points[i]-points[i+1]).normalized()*lengths[i]
		points[0] = base
		for i in 3:
			points[i+1] = points[i]+(points[i+1]-points[i]).normalized()*lengths[i]


func animate_fingers(pose_name: String, delta: float) -> void:
	var target: Array[Transform3D] = poses[pose_name]
	if gesture.is_empty():
		finger_poses = target.duplicate()
	gesture = pose_name
	var blend: float = 1.0-exp(-delta*34.0)
	for digit in FINGERS:
		var joint: Vector3 = rest_joints[digit][0]
		for link in 3:
			var i: int = digit*3+link
			var current: Basis = finger_poses[i].basis.slerp(target[i].basis,blend).orthonormalized()
			finger_poses[i] = Transform3D(current,joint)
			skeleton.set_bone_pose(i+1,finger_poses[i])
			joint += current.y*float(finger_lengths[digit][link])


func fingertip_pad(digit: int) -> Vector3:
	var i: int = digit*3+2
	return finger_poses[i]*(Vector3.UP*float(finger_lengths[digit][2])+PAD_INSET)


func pinch_point() -> Vector3:
	return (fingertip_pad(0)+fingertip_pad(4))*.5


func pose_arm(shoulder_at: Vector3, elbow_hint: Vector3) -> void:
	var shoulder: Vector3 = transform.affine_inverse()*shoulder_at
	var reach: Vector3 = rest_wrist-shoulder
	var axis: Vector3 = reach.normalized()
	var distance: float = clampf(reach.length(),.10,UPPER_ARM_LENGTH+FOREARM_LENGTH-.016)
	# Shift the shoulder into long reaches so neither segment stretches.
	shoulder = rest_wrist-axis*distance
	var along: float = (distance*distance+UPPER_ARM_LENGTH*UPPER_ARM_LENGTH-FOREARM_LENGTH*FOREARM_LENGTH)/(2.0*distance)
	var bend: float = sqrt(maxf(0.0,UPPER_ARM_LENGTH*UPPER_ARM_LENGTH-along*along))
	var pole: Vector3 = (basis.inverse()*elbow_hint).slide(axis).normalized()
	var elbow: Vector3 = shoulder+axis*along+pole*bend
	var lower: Basis = Basis(Quaternion(forearm_rest.y,(rest_wrist-elbow).normalized()))*forearm_rest
	var upper: Basis = Basis(Quaternion(lower.y,(elbow-shoulder).normalized()))*lower
	skeleton.set_bone_pose(SLEEVE_FOREARM,Transform3D(lower,elbow))
	skeleton.set_bone_pose(SLEEVE_UPPER_ARM,Transform3D(upper,shoulder))
	for i in arm_pins.size():
		var length: float = arm_pins[i].distance_to(rest_wrist)
		var at: Vector3 = rest_wrist-lower.y*length
		var blend: float = .54*(1.0-smoothstep(.025,.104,length))
		at = at.lerp(arm_pins[i],blend)
		skeleton.set_bone_pose(FIRST_FOREARM_BONE+i,Transform3D(lower.slerp(forearm_rest,blend),at))
