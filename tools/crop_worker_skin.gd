extends SceneTree


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 3:
		printerr("Expected SOURCE.png MESH.json DESTINATION.png")
		quit(1)
		return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	var source: Image = Image.load_from_file(args[0])
	var crop: Array = data.crop
	var left_top := Vector2i(roundi(crop[0]*source.get_width()),roundi(crop[1]*source.get_height()))
	var right_bottom := Vector2i(roundi(crop[2]*source.get_width()),roundi(crop[3]*source.get_height()))
	var hand_atlas: Image = source.get_region(Rect2i(left_top,right_bottom-left_top))
	hand_atlas.convert(Image.FORMAT_RGBA8)
	var dim := Vector2i(hand_atlas.get_width(),hand_atlas.get_height())
	var area: int = dim.x*dim.y
	var mask := PackedByteArray()
	mask.resize(area)
	var scale := Vector2(dim)
	for part in data.hands:
		var uv: Array = part.uvs
		var indices: Array = part.indices
		for i in range(0,indices.size(),3):
			var a: Vector2 = point(uv,int(indices[i]))*scale
			var b: Vector2 = point(uv,int(indices[i+1]))*scale
			var c: Vector2 = point(uv,int(indices[i+2]))*scale
			var box_low := Vector2i(maxi(0,floori(minf(a.x,minf(b.x,c.x)))-3),maxi(0,floori(minf(a.y,minf(b.y,c.y)))-3))
			var box_high := Vector2i(mini(dim.x,ceili(maxf(a.x,maxf(b.x,c.x)))+3),mini(dim.y,ceili(maxf(a.y,maxf(b.y,c.y)))+3))
			for y in range(box_low.y,box_high.y):
				for pixel in range(y*dim.x+box_low.x,y*dim.x+box_high.x):
					mask[pixel] = 1
	var pixels: PackedByteArray = hand_atlas.get_data()
	for i in area:
		if mask[i] == 0:
			pixels[i*4] = 167
			pixels[i*4+1] = 120
			pixels[i*4+2] = 99
	hand_atlas.set_data(dim.x,dim.y,false,Image.FORMAT_RGBA8,pixels)
	quit(hand_atlas.save_png(args[2]))


func point(uv: Array, id: int) -> Vector2:
	return Vector2(uv[id*2],uv[id*2+1])
