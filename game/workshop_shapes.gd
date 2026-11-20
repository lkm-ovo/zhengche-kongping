extends RefCounted

const SCRAPER_EDGE = Vector3(0,.088,0)


static func rounded_box(size: Vector3, radius: float) -> ArrayMesh:
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var faces := PackedInt32Array()
	var half: Vector3 = size * .5
	radius = minf(radius,minf(half.x, minf(half.y, half.z))*.97)
	var inner: Vector3 = half-Vector3.ONE*radius
	for side in 6:
		var a: int = side/2
		var u: int = (a+1)%3
		var v: int = (a+2)%3
		var flip: float = -1.0 if side%2 == 0 else 1.0
		var scan_u: Array = edge_steps(half[u],radius)
		var scan_v: Array = edge_steps(half[v],radius)
		var first: int = points.size()
		for j in scan_v.size():
			for i in scan_u.size():
				var raw := Vector3.ZERO
				raw[a] = half[a]*flip
				raw[u] = scan_u[i]*flip
				raw[v] = scan_v[j]
				var flat: Vector3 = raw.clamp(-inner,inner)
				var normal: Vector3 = (raw-flat).normalized()
				points.append(flat + normal*radius)
				normals.append(normal)
				if j > 0 and i > 0:
					var lower: int = first + j*scan_u.size()+i
					var upper: int = lower-scan_u.size()
					faces.append_array(PackedInt32Array([upper-1,lower-1,upper,upper,lower-1,lower]))
	return pack(points,normals,faces)


static func edge_steps(half: float, radius: float) -> Array:
	return [-half,-half+radius*.17,-half+radius*.48,-half+radius,half-radius,half-radius*.48,half-radius*.17,half]


static func lathe(profile: Array, segments: int, start: float = -PI, arc: float = TAU) -> ArrayMesh:
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var faces := PackedInt32Array()
	for row in profile.size():
		var current: Array = profile[row]
		var before: Array = profile[maxi(0,row-1)]
		var after: Array = profile[mini(profile.size()-1,row+1)]
		var tilt: float = (before[1]-after[1])/maxf(.001,after[0]-before[0])
		for col in segments+1:
			var u: float = float(col)/segments
			var angle: float = start+u*arc
			var radial := Vector3(sin(angle),0,cos(angle))
			points.append(radial*float(current[1])+Vector3.UP*float(current[0]))
			normals.append((radial+Vector3.UP*tilt).normalized())
			uv.append(Vector2(u,float(row)/(profile.size()-1)))
			if row > 0 and col > 0:
				var lower: int = row*(segments+1)+col
				var upper: int = lower-segments-1
				faces.append_array(PackedInt32Array([upper-1,lower-1,upper,upper,lower-1,lower]))
	return pack(points,normals,faces,uv)


static func radius_at(profile: Array, height: float) -> float:
	for row in range(1,profile.size()):
		var lower: Array = profile[row-1]
		var upper: Array = profile[row]
		if height <= upper[0]:
			var fraction: float = inverse_lerp(lower[0],upper[0],height)
			return lerpf(lower[1],upper[1],clampf(fraction,0.0,1.0))
	return float(profile.back()[1])


static func label_profile(profile: Array, bottom: float = .067, top: float = .148, clearance: float = .00135) -> Array:
	var rows: Array = [[bottom,radius_at(profile,bottom)+clearance]]
	for row in profile:
		if row[0] > bottom and row[0] < top:
			rows.append([row[0],row[1]+clearance])
	rows.append([top,radius_at(profile,top)+clearance])
	return rows


static func scraper_blade(width_scale: float = 1.0, curvature: float = 0.0) -> ArrayMesh:
	var points := PackedVector3Array([
		Vector3(-.013,.024,.003),Vector3(.013,.024,.003),Vector3(-.033,.079,.003),Vector3(.033,.079,.003),
		Vector3(-.033,SCRAPER_EDGE.y,0),Vector3(.033,SCRAPER_EDGE.y,0),
		Vector3(-.013,.024,-.003),Vector3(.013,.024,-.003),Vector3(-.033,.079,-.003),Vector3(.033,.079,-.003)])
	var normals := PackedVector3Array([Vector3.BACK,Vector3.BACK,Vector3.BACK,Vector3.BACK,
		Vector3.UP,Vector3.UP,Vector3.FORWARD,Vector3.FORWARD,Vector3.FORWARD,Vector3.FORWARD])
	if curvature > 0.0:
		# Middle vertices keep the cutting point fixed while the two wings follow the bottle.
		points.append_array([Vector3(0,.079,.003),SCRAPER_EDGE,Vector3(0,.079,-.003)])
		normals.append_array([Vector3.BACK,Vector3.UP,Vector3.FORWARD])
		for i in points.size():
			points[i].z -= curvature*pow(absf(points[i].x)/.033,2.0)*smoothstep(.025,.079,points[i].y)
			points[i].x *= width_scale
		return pack(points,normals,PackedInt32Array([0,2,10,0,10,1,1,10,3,2,4,11,2,11,10,10,11,5,10,5,3,
			6,12,8,6,7,12,7,9,12,8,12,11,8,11,4,12,9,5,12,5,11,0,6,2,6,8,2,2,8,4,1,3,7,7,3,9,3,5,9]))
	for i in points.size():
		points[i].x *= width_scale
	return pack(points,normals,PackedInt32Array([0,2,1,1,2,3,2,4,3,3,4,5,
		6,7,8,7,9,8,8,9,4,9,5,4,0,6,2,6,8,2,2,8,4,1,3,7,7,3,9,3,5,9]))


static func paper_chip(size: Vector2) -> ArrayMesh:
	var points := PackedVector3Array([Vector3(-.45,-.31,0),Vector3(.20,-.49,.08),
		Vector3(.46,-.06,.13),Vector3(.29,.48,.08),Vector3(-.35,.39,0)])
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	for i in points.size():
		var point: Vector3 = points[i]
		uv.append(Vector2(point.x+.5,point.y+.5))
		points[i] = point*Vector3(size.x,size.y,size.x)
		normals.append(Vector3.BACK)
	return pack(points,normals,PackedInt32Array([0,2,1,0,3,2,0,4,3]),uv)


static func sink() -> ArrayMesh:
	# Bowl, shoulder, rolled lip and the exposed edge of the stamped rim.
	var rings: Array = [
		[.005,.005,.002,-.113,1.00],[.315,.207,.036,-.113,1.00],
		[.411,.270,.045,-.106,.88],[.457,.313,.055,-.085,.56],
		[.494,.346,.053,-.023,.39],[.518,.373,.048,.008,.72],
		[.548,.389,.049,.014,.97],[.582,.418,.047,.013,.97],
		[.592,.426,.052,.003,.54],[.588,.422,.047,-.011,-.52],
	]
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var faces := PackedInt32Array()
	var steps: int = 7
	var count: int = steps*4+1
	for j in rings.size():
		var row: Array = rings[j]
		for i in count:
			var index: int = i % (count-1)
			var corner: int = index / steps
			var angle: float = (corner+float(index%steps)/(steps-1))*PI*.5
			var direction := Vector2(cos(angle),sin(angle))
			var cx: float = row[0]*.5 - row[2]
			var cz: float = row[1]*.5 - row[2]
			var center := Vector2(cx if corner == 0 or corner == 3 else -cx,cz if corner < 2 else -cz)
			var rim: Vector2 = center+direction*float(row[2])
			var slope: float = sqrt(1.0-float(row[4])*float(row[4]))
			if j < 7:
				slope = -slope
			points.append(Vector3(rim.x,row[3],rim.y))
			normals.append(Vector3(direction.x*slope,row[4],direction.y*slope))
			if j > 0 and i > 0:
				var lower: int = j*count+i
				var upper: int = lower-count
				faces.append_array(PackedInt32Array([upper-1,lower-1,lower,upper-1,lower,upper]))
	return pack(points,normals,faces)


static func tube(route: PackedVector3Array, radius: float, sides: int = 14) -> ArrayMesh:
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var faces := PackedInt32Array()
	var sections: int = (route.size()-1)*4
	for row in sections+1:
		var section: int = mini(row/4,route.size()-2)
		var t: float = float(row-section*4)*.25
		var a: Vector3 = route[section]
		var b: Vector3 = route[section+1]
		var previous: Vector3 = route[maxi(0,section-1)]
		var next: Vector3 = route[mini(route.size()-1,section+2)]
		var at: Vector3 = a.cubic_interpolate(b,previous,next,t)
		var direction: Vector3 = (a.cubic_interpolate(b,previous,next,t+.003)-at).normalized()
		var reference: Vector3 = Vector3.RIGHT if absf(direction.x) < .9 else Vector3.FORWARD
		var n: Vector3 = reference.slide(direction).normalized()
		var m: Vector3 = direction.cross(n)
		for col in sides+1:
			var angle: float = float(col)*TAU/sides
			var normal: Vector3 = n*cos(angle)+m*sin(angle)
			points.append(at+normal*radius)
			normals.append(normal)
			if row > 0 and col > 0:
				var lower: int = row*(sides+1)+col
				var upper: int = lower-sides-1
				faces.append_array(PackedInt32Array([upper-1,lower-1,upper,upper,lower-1,lower]))
	return pack(points,normals,faces)


static func pack(points: PackedVector3Array, normals: PackedVector3Array, faces: PackedInt32Array, uv: PackedVector2Array = PackedVector2Array()) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = faces
	if not uv.is_empty():
		arrays[Mesh.ARRAY_TEX_UV] = uv
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return result
