extends RefCounted

const NAMES = ["绿啤酒瓶", "橙味汽水瓶", "胖肚牛奶瓶", "细颈酱汁瓶", "弹珠汽水瓶", "翻盖玻璃瓶"]
const CONDITION = ["轻污", "重污", "裂瓶"]
const PRICES = [1, 2, 2, 3, 3, 4]
const BUYERS = ["滨河啤酒厂", "南街汽水铺", "晨乳配送站", "老巷酱料厂", "海风汽水厂", "山泉灌装厂"]
const ORDER_LIMIT = [72, 300, 1200, 12000, 48000]
const GLASS = ["446b39", "74aeb2", "a0bec1", "764c2e", "4c9d83", "737847"]
const LABEL = ["ddcb9c", "eb853a", "dbebe7", "e4b26e", "abe0ce", "d1bd8d"]
const MARKS = ["麦 岸", "橙 泡", "晨 乳", "酿 造", "苏 打", "山 泉"]
const BOTTLE_PROFILES = [
	[[0,.038],[.006,.042],[.013,.045],[.021,.045],[.134,.045],[.158,.044],[.179,.038],[.198,.029],[.219,.022],[.245,.018],[.267,.016],[.275,.016],[.278,.020],[.284,.022],[.290,.020],[.291,.015]],
	[[0,.036],[.012,.041],[.040,.045],[.080,.034],[.111,.033],[.166,.046],[.191,.044],[.221,.032],[.249,.021],[.260,.018],[.275,.018],[.28,.019],[.286,.015]],
	[[0,.047],[.012,.052],[.145,.052],[.175,.050],[.196,.044],[.205,.037],[.218,.025],[.231,.027],[.236,.028],[.240,.027],[.242,.022]],
	[[0,.027],[.016,.033],[.169,.033],[.183,.029],[.203,.019],[.224,.014],[.271,.014],[.275,.017],[.284,.018],[.289,.017],[.291,.013]],
	[[0,.037],[.012,.042],[.149,.042],[.170,.037],[.188,.027],[.200,.033],[.216,.032],[.241,.025],[.258,.025],[.266,.029],[.276,.025]],
	[[0,.040],[.013,.044],[.175,.044],[.205,.039],[.219,.030],[.236,.023],[.285,.019],[.301,.021],[.307,.018]],
]
const AREA = ["街边回收点", "街区回收点", "小仓库", "城区回收站", "区域回收中心"]
const EQUIPMENT = ["台式脱标机", "循环洗瓶机", "光学分拣机", "沥干验瓶台", "装箱发货机", "专用清洗工位", "托盘及调度系统", "蒸汽消毒机"]
const COST = [72, 240, 440, 580, 720, 1300, 4300, 380]
const SCRAPERS = [
	{"name":"旧平口刮刀", "price":0, "passes":[2,3], "drag":[119.0,126.0], "glue":[true,true],
		"cue":"scrape_dull", "rattle":.0015, "pieces":5, "shaving":Vector2(.86,.82)},
	{"name":"薄刃钢刮刀", "price":24, "passes":[1,2], "drag":[139.0,104.0], "glue":[false,true],
		"cue":"scrape_steel", "rattle":.00065, "pieces":4, "shaving":Vector2(.87,1.68)},
	{"name":"弧面刮刀", "price":58, "passes":[1,1], "drag":[101.0,116.0], "glue":[false,false],
		"cue":"scrape_curve", "rattle":.0002, "pieces":3, "shaving":Vector2(1.20,2.53)},
	{"name":"弹簧压刮刀", "price":135, "passes":[1,1], "drag":[67.0,79.0], "glue":[false,false],
		"cue":"scrape_spring", "rattle":0.0, "pieces":2, "shaving":Vector2(1.45,3.40)},
]
const STARTER_STOCK = [30,4,2,19,4,1,10,2,0,0,0,0,0,0,0,0,0,0]
const LEGACY_STARTER_STOCK = [10,1,1,6,2,0,3,1,0,0,0,0,0,0,0,0,0,0]
const STARTER_SIZE = 72
const STREET_SIZE = 600
const PALLET_SIZE = 2400
const TRUCK_SIZE = 48000
const LEGACY_TRUCK_SIZE = 19200
const DAY_TRUCKS = 60
const TRUCK_MIX = [24,20,12,10,8,6]
const TRUCK_MIX_TOTAL = 80
const QUEUE_NAMES = ["来料", "待脱标", "待清洗", "待消毒", "待沥干验瓶", "成品筐", "待售区"]
const RAW = 0
const SORTED = 1
const STRIPPED = 2
const WASHED = 3
const SANITIZED = 4
const CLEAN = 5
const FOR_SALE = 6
const PACKER = 4
const SANITIZER = 7
const BENCH_QUEUES = [SANITIZED, WASHED, STRIPPED, SORTED, RAW]
const BATCH_SIZE = [STARTER_SIZE, 200, 600, 2400, 4800]
const PHASE_MULTIPLIERS = [1, 4, 12, 40, 425]

var queues: Array = []
var installed: Array = [false, false, false, false, false, false, false, false]
var sold_by_type: Array = [0, 0, 0, 0, 0, 0]
var credits: int = 0
var owned_scraper: int = 0
var equipped_scraper: int = 0
var received: int = STARTER_SIZE
var delivered: int = 0
var recycled: int = 0
var phase: int = 0
var priority: int = -1
var held: int = -1
var held_queue: int = RAW
var trucks: int = 0
var day_active: bool = false
var day_complete: bool = false
var clock: float = 0.0
var next_truck: float = 0.0
var day_base_delivered: int = 0
var day_base_recycled: int = 0
var day_truck_size: int = TRUCK_SIZE
var balances: Array = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var rush: int = 1
var auto_sales: bool = false
var sale_allowance: float = 0.0
var machine_work := PackedInt64Array()


func _init() -> void:
	machine_work.resize(EQUIPMENT.size())
	for i in QUEUE_NAMES.size():
		var queue: Array = []
		queue.resize(NAMES.size() * CONDITION.size())
		queue.fill(0)
		queues.append(queue)
	queues[RAW] = STARTER_STOCK.duplicate()


func kind(item: int) -> int:
	return item / CONDITION.size()


func grade(item: int) -> int:
	return item % CONDITION.size()


func sum_queue(queue: int) -> int:
	var total: int = 0
	for units in queues[queue]:
		total += units
	return total


func available(kind_id: int) -> int:
	var total: int = 0
	for quality in CONDITION.size():
		var item: int = kind_id * CONDITION.size() + quality
		for queue in BENCH_QUEUES:
			total += queues[queue][item]
	return total


func can_take() -> bool:
	for queue in BENCH_QUEUES:
		if sum_queue(queue) > 0:
			return true
	return false


func can_bulk_wash() -> bool:
	for item in range(3 * CONDITION.size()):
		if queues[STRIPPED][item] > 0:
			return true
	return false


func in_yard() -> int:
	return received - delivered - recycled


func take(selected: int = -1) -> Vector2i:
	if held >= 0:
		return Vector2i(held, held_queue)
	for queue in BENCH_QUEUES:
		for item in item_order(selected):
			if selected >= 0 and kind(item) != selected:
				continue
			if queues[queue][item] > 0:
				queues[queue][item] -= 1
				held = item
				held_queue = queue
				return Vector2i(item, queue)
	return Vector2i(-1, RAW)


func return_held() -> void:
	if held >= 0:
		queues[held_queue][held] += 1
		held = -1
		held_queue = RAW


func advance_held(queue: int) -> void:
	if held >= 0:
		held_queue = maxi(held_queue, queue)


func set_down() -> bool:
	if held < 0:
		return false
	if grade(held) == 2:
		recycled += 1
	elif held_queue == CLEAN:
		queues[CLEAN][held] += 1
	else:
		return false
	held = -1
	held_queue = RAW
	return true


func item_order(preferred: int = -2) -> Array:
	var order: Array = []
	if preferred == -2:
		preferred = priority
	var first: int = preferred if preferred >= 0 else 0
	for offset in NAMES.size():
		var type: int = (first + offset) % NAMES.size()
		for quality in CONDITION.size():
			order.append(type * CONDITION.size() + quality)
	return order


func bulk_feed() -> int:
	return run_machine(2,RAW,SORTED,BATCH_SIZE[phase])


func bulk_wash() -> int:
	return run_machine(1,STRIPPED,WASHED,BATCH_SIZE[phase],1,false)


func bulk_sanitize() -> int:
	return run_machine(SANITIZER,WASHED,SANITIZED,BATCH_SIZE[phase])


func bulk_finish() -> int:
	return run_machine(3,SANITIZED,CLEAN,BATCH_SIZE[phase])


func stage_for_sale() -> int:
	return run_machine(PACKER,CLEAN,FOR_SALE,sum_queue(CLEAN))


func sale_stock(bottle_type: int) -> int:
	var first: int = bottle_type * CONDITION.size()
	return queues[FOR_SALE][first] + queues[FOR_SALE][first+1]


func sale_quote(bottle_type: int, limit: int = -1) -> Vector2i:
	if bottle_type < 0 or bottle_type >= NAMES.size():
		return Vector2i.ZERO
	var units: int = mini(sale_stock(bottle_type), ORDER_LIMIT[phase])
	if limit >= 0:
		units = mini(units, limit)
	return Vector2i(units, units*PRICES[bottle_type])


func sell_to(bottle_type: int, limit: int = -1) -> Vector2i:
	var quote: Vector2i = sale_quote(bottle_type,limit)
	if quote.x == 0:
		return quote
	var first: int = bottle_type*CONDITION.size()
	var regular: int = mini(quote.x,queues[FOR_SALE][first])
	queues[FOR_SALE][first] -= regular
	queues[FOR_SALE][first+1] -= quote.x-regular
	delivered += quote.x
	if installed[6]:
		machine_work[6] += quote.x
	sold_by_type[bottle_type] += quote.x
	credits += quote.y
	return quote


func enable_auto_sales(enabled: bool) -> void:
	auto_sales = enabled and installed[PACKER]
	sale_allowance = 0.0


func automatic_sales(elapsed: float, multiplier: int) -> void:
	if not auto_sales or not installed[PACKER]:
		return
	sale_allowance += 9*multiplier*elapsed
	var budget: int = int(sale_allowance)
	sale_allowance -= budget
	var first: int = maxi(priority,0)
	for offset in NAMES.size():
		if budget == 0:
			break
		budget -= sell_to((first+offset)%NAMES.size(),budget).x


func buy(index: int) -> bool:
	if installed[index] or credits < COST[index] or not unlocked(index):
		return false
	credits -= COST[index]
	installed[index] = true
	return true


func can_choose_scraper(index: int) -> bool:
	if index < 0 or index >= SCRAPERS.size() or index == equipped_scraper:
		return false
	return index <= owned_scraper or (index == owned_scraper+1 and (index < 2 or installed[0]) and credits >= SCRAPERS[index].price)


func choose_scraper(index: int) -> bool:
	if not can_choose_scraper(index):
		return false
	if index > owned_scraper:
		credits -= int(SCRAPERS[index].price)
		owned_scraper = index
	equipped_scraper = index
	return true


func unlocked(index: int) -> bool:
	match index:
		0: return true
		1: return installed[0]
		2, 3, 4: return phase >= 2
		5: return phase >= 2 and installed[1]
		6: return phase >= 3 and installed[4]
		SANITIZER: return phase >= 2 and installed[1]
	return false


func next_phase() -> int:
	match phase:
		0: return 1 if installed[0] else 0
		1: return 2 if installed[1] and delivered >= 120 else 1
		2: return 3 if installed[2] and installed[3] and installed[4] and installed[SANITIZER] else 2
		3: return 4 if installed[5] and installed[6] else 3
	return 4


func can_receive() -> bool:
	return not day_active and in_yard() == 0 and (phase > 0 or installed[0])


func receive() -> bool:
	if not can_receive():
		return false
	phase = next_phase()
	if phase < 4:
		manifest(phase, 0)
	else:
		day_active = true
		day_complete = false
		trucks = 0
		day_truck_size = TRUCK_SIZE
		next_truck = clock
		day_base_delivered = delivered
		day_base_recycled = recycled
		arrive()
	return true


func arrive() -> void:
	manifest(3,trucks,day_truck_size)
	trucks += 1
	next_truck += 2.15


func manifest(size_index: int, truck_number: int, truck_size: int = TRUCK_SIZE) -> void:
	var mix: Array = [300,200,100,0,0,0] if size_index == 1 else [780,660,480,480,0,0]
	if size_index == 3:
		var share: int = truck_size/TRUCK_MIX_TOTAL
		mix = TRUCK_MIX.map(func(part: int) -> int: return part*share)
		if truck_number%3 == 1:
			mix[0] -= 4*share
			mix[3] += 4*share
		elif truck_number%3 == 2:
			mix[1] -= 3*share
			mix[5] += 3*share
	for i in mix.size():
		var count: int = mix[i]
		var heavy: int = count * (2 if i == 3 else 1) / 8
		var crack: int = count / 48
		queues[RAW][i * 3] += count - heavy - crack
		queues[RAW][i * 3 + 1] += heavy
		queues[RAW][i * 3 + 2] += crack
		received += count


# The wash lines share an output buffer. Mode 1 handles regular bottles and
# mode 2 handles hot washing, tilted rinsing and replacement gaskets.
func move(source: int, target: int, limit: int, mode: int = 0, charge_effort: bool = true) -> int:
	var remaining: int = limit
	for item in item_order():
		if remaining <= 0:
			break
		var special: bool = kind(item) >= 3
		if (mode == 1 and special) or (mode == 2 and not special):
			continue
		var in_slot: int = queues[source][item]
		if in_slot <= 0:
			continue
		var effort: int = 2 if charge_effort and source == STRIPPED and (grade(item) == 1 or kind(item) == 2) else 1
		var units: int = mini(in_slot, remaining / effort)
		queues[source][item] -= units
		remaining -= units * effort
		if grade(item) == 2:
			recycled += units
		else:
			queues[target][item] += units
	return limit - remaining


func advance(delta: float) -> void:
	var elapsed: float = delta * rush
	clock += elapsed
	if day_active and trucks < DAY_TRUCKS and clock >= next_truck:
		while trucks < DAY_TRUCKS and clock >= next_truck:
			arrive()
	var capacity_scale: int = 170 if phase == 4 and day_truck_size == LEGACY_TRUCK_SIZE else PHASE_MULTIPLIERS[phase]
	var multiplier: int = capacity_scale*(4 if installed[6] else 1)
	drive(0, 2, RAW, SORTED, 14, multiplier, elapsed)
	drive(1, 0, SORTED, STRIPPED, 12, multiplier, elapsed)
	drive(2, 1, STRIPPED, WASHED, 11, multiplier, elapsed, 1)
	drive(3, 5, STRIPPED, WASHED, 7, multiplier, elapsed, 2)
	drive(4, SANITIZER, WASHED, SANITIZED, 10, multiplier, elapsed)
	drive(5, 3, SANITIZED, CLEAN, 16, multiplier, elapsed)
	drive(6, PACKER, CLEAN, FOR_SALE, 9, multiplier, elapsed)
	automatic_sales(elapsed,multiplier)
	if day_active and trucks == DAY_TRUCKS and in_yard() == 0:
		day_active = false
		day_complete = true


func drive(slot: int, equipment: int, source: int, target: int, rate: int, scale: int, elapsed: float, mode: int = 0) -> void:
	if not installed[equipment]:
		return
	balances[slot] += rate * scale * elapsed
	var budget: int = int(balances[slot])
	if budget == 0:
		return
	balances[slot] -= budget
	var used: int = run_machine(equipment,source,target,budget,mode)
	# Preserve a single unit of work for a heavy bottle on a very small tick.
	if source == STRIPPED and budget == 1 and used == 0:
		balances[slot] += 1.0


func run_machine(equipment: int, source: int, target: int, limit: int, mode: int = 0, charge_effort: bool = true) -> int:
	var handled: int = move(source,target,limit,mode,charge_effort)
	if installed[equipment]:
		machine_work[equipment] += handled
	return handled


func serialize() -> Dictionary:
	return {
		"version": 5, "queues": queues, "installed": installed,
		"sold_by_type": sold_by_type, "credits": credits, "received": received,
		"delivered": delivered, "recycled": recycled, "phase": phase,
		"priority": priority, "held": held, "held_queue": held_queue, "trucks": trucks, "clock": clock,
		"next_truck": next_truck, "day_active": day_active, "day_complete": day_complete,
		"day_base_delivered": day_base_delivered, "day_base_recycled": day_base_recycled, "day_truck_size": day_truck_size,
		"rush": rush, "auto_sales": auto_sales, "owned_scraper": owned_scraper, "equipped_scraper": equipped_scraper,
	}


func restore(data: Variant) -> void:
	if not data is Dictionary:
		return
	var version: int = int(data.get("version", 0))
	if version not in [1,2,3,4,5]:
		return
	var legacy: bool = version == 1
	var expected_queues: int = QUEUE_NAMES.size()-int(version < 3)-int(legacy)
	if not data.get("queues") is Array or data.queues.size() != expected_queues:
		return
	if not data.get("installed") is Array or data.installed.size() != EQUIPMENT.size() - int(legacy):
		return
	if not data.get("sold_by_type") is Array or data.sold_by_type.size() != NAMES.size():
		return
	for queue in data.queues:
		if not queue is Array or queue.size() != NAMES.size() * CONDITION.size():
			return
	for i in data.queues.size():
		var mapped: int = CLEAN if legacy and i == 4 else i
		for j in queues[mapped].size():
			queues[mapped][j] = int(data.queues[i][j])
	installed = data.installed.duplicate()
	if legacy:
		queues[SANITIZED].fill(0)
		installed.append(bool(installed[3]) or int(data.phase) >= 3)
	if version < 3:
		queues[FOR_SALE].fill(0)
	for i in sold_by_type.size():
		sold_by_type[i] = int(data.sold_by_type[i])
	credits = int(data.credits)
	owned_scraper = clampi(int(data.get("owned_scraper",0)),0,SCRAPERS.size()-1) if version >= 4 else 0
	equipped_scraper = clampi(int(data.get("equipped_scraper",0)),0,owned_scraper) if version >= 4 else 0
	received = int(data.received)
	delivered = int(data.delivered)
	recycled = int(data.recycled)
	phase = int(data.phase)
	priority = int(data.priority)
	held = int(data.held)
	held_queue = clampi(int(data.get("held_queue", RAW)), RAW, CLEAN)
	trucks = int(data.trucks)
	clock = float(data.clock)
	next_truck = float(data.next_truck)
	day_active = data.day_active
	day_complete = data.day_complete
	day_base_delivered = int(data.day_base_delivered)
	day_base_recycled = int(data.day_base_recycled)
	day_truck_size = TRUCK_SIZE
	if version >= 5:
		if int(data.get("day_truck_size",TRUCK_SIZE)) == LEGACY_TRUCK_SIZE:
			day_truck_size = LEGACY_TRUCK_SIZE
	elif day_active or day_complete:
		day_truck_size = LEGACY_TRUCK_SIZE
	rush = int(data.rush)
	enable_auto_sales(bool(installed[PACKER]) if version < 3 else bool(data.get("auto_sales",false)))
	return_held()
	if version < 5 and phase == 0 and received == 24 and not installed[0] and (in_yard() > 0 or credits < COST[0]):
		for item in STARTER_STOCK.size():
			queues[RAW][item] += STARTER_STOCK[item]-LEGACY_STARTER_STOCK[item]
		received = STARTER_SIZE
