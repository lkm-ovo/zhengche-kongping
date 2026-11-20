extends Node3D

const Yard = preload("res://yard.gd")
const SLOT_SPACING = .122
const HEIGHT = .176

var site: Node3D
var shell: Node3D
var count_label: Label3D
var columns: int = 2
var dimensions := Vector3(.284,HEIGHT,.284)
var bottles: Array[Node3D] = []
var shown: Array[int] = []
var capacity: int = 0


func build(owner_site: Node3D) -> void:
	site = owner_site
	count_label = site.text_at("",Vector3.ZERO,42,.0011,"e2e9d6",self)


func sync(items: Array, limit: int) -> void:
	if capacity == limit and shown == items:
		return
	if capacity != limit:
		resize_crate(limit)
	for i in range(items.size(),bottles.size()):
		remove_child(bottles[i])
		bottles[i].queue_free()
	bottles.resize(items.size())
	for i in items.size():
		var kind: int = items[i] / Yard.CONDITION.size()
		if bottles[i] == null or shown[i] / Yard.CONDITION.size() != kind:
			if bottles[i] != null:
				remove_child(bottles[i])
				bottles[i].queue_free()
			var bottle := Node3D.new()
			add_child(bottle)
			site.build_finished_bottle(kind,bottle)
			bottles[i] = bottle
		var row: int = i / columns
		bottles[i].position = Vector3((i%columns-(columns-1)*.5)*SLOT_SPACING,.031,
			((limit/columns-1)*.5-row)*SLOT_SPACING)
	shown.assign(items)
	count_label.text = "成品  %d / %d" % [items.size(),limit]


func resize_crate(limit: int) -> void:
	capacity = limit
	columns = 2 if limit == Yard.CRATE_CAPACITIES[0] else 4
	dimensions.x = columns*SLOT_SPACING+.04
	dimensions.z = (limit/columns)*SLOT_SPACING+.04
	if is_instance_valid(shell):
		remove_child(shell)
		shell.queue_free()
	shell = site.crate(Vector3.ZERO,"397263",self,dimensions)
	for x in [-1.0,1.0]:
		site.rounded(Vector3(x*dimensions.x*.5,.154,.046),Vector3(.037,.037,.108),
			.009,site.material("253e36"),shell)
	site.rounded(Vector3(0,.105,dimensions.z*.5+.013),Vector3(.19,.049,.014),
		.006,site.material("26443a"),shell)
	count_label.position = Vector3(0,.105,dimensions.z*.5+.022)
