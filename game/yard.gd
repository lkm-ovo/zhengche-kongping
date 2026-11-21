extends RefCounted

const NAMES = ["绿啤酒瓶", "橙味汽水瓶", "胖肚牛奶瓶", "细颈酱汁瓶", "弹珠汽水瓶", "翻盖玻璃瓶"]
const CONDITION = ["轻污", "重污", "裂瓶"]
const BASE_PRICES = [100, 200, 200, 300, 300, 400] # Cents per bottle.
const BUYERS = ["滨河啤酒厂", "南街汽水铺", "晨乳配送站", "老巷酱料厂", "海风汽水厂", "山泉灌装厂"]
const MARKET_DAY_SECONDS = 120.0
const DAILY_DEMAND = [180, 1200, 5000, 75000, 720000]
const BUYER_DEMAND_PERCENT = [120, 110, 90, 80, 70, 60]
const DEMAND_SWING = [0, 8, -5, 11, -8, 4, -3]
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
	{"name":"旧平口刮刀", "price":0, "passes":[10,12], "drag":[180.0,190.0], "wipe_strokes":[5,6],
		"cue":"scrape_dull", "rattle":.0023, "pieces":5, "shaving":Vector2(.86,.82)},
	{"name":"薄刃钢刮刀", "price":24, "passes":[7,9], "drag":[176.0,186.0], "wipe_strokes":[0,3],
		"cue":"scrape_steel", "rattle":.00065, "pieces":4, "shaving":Vector2(.87,1.68)},
	{"name":"弧面刮刀", "price":58, "passes":[5,6], "drag":[174.0,182.0], "wipe_strokes":[0,0],
		"cue":"scrape_curve", "rattle":.0002, "pieces":3, "shaving":Vector2(1.20,2.53)},
	{"name":"弹簧压刮刀", "price":135, "passes":[3,4], "drag":[172.0,178.0], "wipe_strokes":[0,0],
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
const QUEUE_NAMES = ["来料", "待脱标", "待清洗", "待消毒", "待沥干验瓶", "成品库存", "窗口待售"]
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
const STORY_TARGET = 12000
const STORY_TRUCK_PHASE = 3
const BAG_UPGRADE_PHASE = 1
const BAG_CAPACITY = 5
const CART_CAPACITY = 20
const CRATE_CAPACITIES = [4, 8, 12, 16]
const CRATE_COSTS = [0, 0, 65, 140]
const CRATE_PHASES = [0, 0, 1, 2]
const CART_CRATE_LIMIT = 3
enum Story { OPENING, FIRST_SALE, FIRST_MACHINE, FIRST_TRUCK, RECOVERED }

var queues: Array = []
var installed: Array = [false, false, false, false, false, false, false, false]
var sold_by_type: Array = [0, 0, 0, 0, 0, 0]
var credits: int = 0
var credit_cents: int = 0
var market_day: int = 1
var market_elapsed: float = 0.0
var bought_today: Array[int] = [0, 0, 0, 0, 0, 0]
var bought_yesterday: Array[int] = [0, 0, 0, 0, 0, 0]
var story_read: int = -1
var story_recovered: bool = false
var owned_scraper: int = 0
var equipped_scraper: int = 0
var received: int = STARTER_SIZE
var delivered: int = 0
var recycled: int = 0
var phase: int = 0
var priority: int = -1
var held: int = -1
var held_queue: int = RAW
var carried: Array[Vector2i] = []
var bag_upgraded: bool = false
var pushing_cart: bool = false
var parked_load: Array[Vector2i] = []
var crate_level: int = 0
var bench_crate: Array[int] = []
var hand_crate: Array[int] = []
var cart_crates: Array[Array] = []
var parked_at := Vector3.INF
var parked_angle: float = 0.0
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


func story_chapter() -> int:
	if story_recovered:
		return Story.RECOVERED
	if phase >= STORY_TRUCK_PHASE:
		return Story.FIRST_TRUCK
	if installed[0]:
		return Story.FIRST_MACHINE
	if delivered > 0:
		return Story.FIRST_SALE
	return Story.OPENING


func check_story_recovery() -> void:
	if phase >= STORY_TRUCK_PHASE and credits >= STORY_TARGET:
		story_recovered = true


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
	if not installed[0]:
		return false
	for item in range(3 * CONDITION.size()):
		if queues[STRIPPED][item] > 0:
			return true
	return false


func in_yard() -> int:
	return received - delivered - recycled


func cart_unlocked() -> bool:
	return phase >= STORY_TRUCK_PHASE


func bag_capacity() -> int:
	return BAG_CAPACITY if bag_upgraded else 1


func can_upgrade_bag() -> bool:
	return phase >= BAG_UPGRADE_PHASE and not bag_upgraded


func upgrade_bag() -> bool:
	if not can_upgrade_bag():
		return false
	bag_upgraded = true
	return true


func carry_capacity() -> int:
	return CART_CAPACITY if pushing_cart else bag_capacity()


func carry_count() -> int:
	return carried.size()+int(held >= 0)


func push_cart() -> bool:
	if not cart_unlocked() or pushing_cart:
		return false
	if carry_count() + parked_load.size() > CART_CAPACITY:
		return false
	if not hand_crate.is_empty():
		if cart_crates.size() == CART_CRATE_LIMIT:
			return false
		cart_crates.append(hand_crate.duplicate())
		hand_crate.clear()
	carried.append_array(parked_load)
	parked_load.clear()
	pushing_cart = true
	return true


func park_cart(at: Vector3, angle: float) -> void:
	while carry_count() > bag_capacity():
		parked_load.push_front(carried.pop_back())
	parked_at = at
	parked_angle = angle
	pushing_cart = false


func collect(selected: int = -1, limit: int = CART_CAPACITY) -> int:
	var before: int = carried.size()
	var order: Array = item_order(selected)
	for _space in range(mini(limit,carry_capacity()-carry_count())):
		var item: Vector2i = take_from_stock(order,selected)
		if item.x < 0:
			break
		carried.append(item)
	return carried.size()-before


func take_from_stock(order: Array, selected: int) -> Vector2i:
	for queue in BENCH_QUEUES:
		for item in order:
			if selected >= 0 and kind(item) != selected:
				continue
			if queues[queue][item] > 0:
				queues[queue][item] -= 1
				return Vector2i(item, queue)
	return Vector2i(-1, RAW)


func begin_carried() -> bool:
	if held >= 0 or carried.is_empty():
		return false
	var item: Vector2i = carried.pop_front()
	held = item.x
	held_queue = item.y
	return true


func stow_held() -> void:
	if held >= 0:
		carried.push_front(Vector2i(held,held_queue))
		held = -1
		held_queue = RAW


func unload_carried() -> int:
	var returned: int = 0
	for i in range(carried.size()-1,-1,-1):
		var item: Vector2i = carried[i]
		if item.y == CLEAN:
			continue
		queues[item.y][item.x] += 1
		carried.remove_at(i)
		returned += 1
	return returned


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
	elif held_queue == CLEAN and bench_crate.size() < crate_capacity():
		bench_crate.append(held)
	else:
		return false
	held = -1
	held_queue = RAW
	return true


func crate_capacity() -> int:
	return CRATE_CAPACITIES[crate_level]


func upgrade_crate() -> bool:
	var next: int = crate_level + 1
	if next >= CRATE_CAPACITIES.size() or delivered == 0 or phase < CRATE_PHASES[next] or credits < CRATE_COSTS[next]:
		return false
	credits -= CRATE_COSTS[next]
	crate_level = next
	refill_legacy_crate()
	return true


func take_crate() -> bool:
	if held >= 0 or bench_crate.is_empty():
		return false
	if pushing_cart:
		if cart_crates.size() == CART_CRATE_LIMIT:
			return false
		cart_crates.append(bench_crate.duplicate())
	else:
		if not hand_crate.is_empty():
			return false
		hand_crate.assign(bench_crate)
	bench_crate.clear()
	refill_legacy_crate()
	return true


func refill_legacy_crate() -> void:
	# Old manual saves kept finished bottles in the bulk queue.
	if installed[0] or installed[PACKER]:
		return
	for item in item_order():
		if grade(item) == 2:
			continue
		var count: int = mini(crate_capacity() - bench_crate.size(), queues[CLEAN][item])
		for i in count:
			bench_crate.append(item)
		queues[CLEAN][item] -= count
		if bench_crate.size() == crate_capacity():
			break


func transport_crate_count() -> int:
	return cart_crates.size() if pushing_cart else int(not hand_crate.is_empty())


func transport_finished_count() -> int:
	var total: int = hand_crate.size()
	if pushing_cart:
		for cargo in cart_crates:
			total += cargo.size()
	return total


func unload_finished() -> int:
	var count: int = transport_finished_count()
	for item in hand_crate:
		queues[FOR_SALE][item] += 1
	hand_crate.clear()
	if pushing_cart:
		for cargo in cart_crates:
			for item in cargo:
				queues[FOR_SALE][item] += 1
		cart_crates.clear()
	return count


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
	return run_machine(1,STRIPPED,WASHED,BATCH_SIZE[phase],1,false) if installed[0] else 0


func bulk_sanitize() -> int:
	return run_machine(SANITIZER,WASHED,SANITIZED,BATCH_SIZE[phase]) if installed[0] else 0


func bulk_finish() -> int:
	return run_machine(3,SANITIZED,CLEAN,BATCH_SIZE[phase]) if installed[0] else 0


func stage_for_sale() -> int:
	return run_machine(PACKER,CLEAN,FOR_SALE,sum_queue(CLEAN)) if installed[0] else 0


func sale_stock(bottle_type: int) -> int:
	var first: int = bottle_type * CONDITION.size()
	return queues[FOR_SALE][first] + queues[FOR_SALE][first+1]


func normal_demand(bottle_type: int) -> int:
	return DAILY_DEMAND[phase]*BUYER_DEMAND_PERCENT[bottle_type]/100


func demand_swing(bottle_type: int) -> int:
	return DEMAND_SWING[(market_day-1+bottle_type*2)%DEMAND_SWING.size()]


func buyer_quota(bottle_type: int) -> int:
	var normal: int = normal_demand(bottle_type)
	var planned: int = normal*(100+demand_swing(bottle_type))/100
	# Yesterday's deliveries partially cover today's demand.
	return maxi(normal*35/100,planned-bought_yesterday[bottle_type]*55/100)


func buyer_remaining(bottle_type: int) -> int:
	return maxi(0,buyer_quota(bottle_type)-bought_today[bottle_type])


func sale_unit_price(bottle_type: int) -> int:
	var normal: int = normal_demand(bottle_type)
	var stock_discount: int = mini(28,sale_stock(bottle_type)*55/normal)
	var restock_discount: int = mini(11,bought_yesterday[bottle_type]*18/normal)
	# The opening shipment must still fund both the first machine and the thin blade.
	var floor_percent: int = 95 if phase == 0 else 70
	var percent: int = clampi(112+demand_swing(bottle_type)-stock_discount-restock_discount,floor_percent,130)
	return BASE_PRICES[bottle_type]*percent/100


func wallet_cents() -> int:
	return credits*100+credit_cents


func market_seconds_left() -> float:
	return MARKET_DAY_SECONDS-market_elapsed


func turn_market_day() -> void:
	market_day += 1
	market_elapsed = 0.0
	bought_yesterday.assign(bought_today)
	bought_today.fill(0)


func market_wait_available() -> bool:
	for i in NAMES.size():
		if sale_stock(i) > 0 and buyer_remaining(i) == 0:
			return true
	return false


# The quote contains bottle count and total cents.
func sale_quote(bottle_type: int, limit: int = -1) -> Vector2i:
	if bottle_type < 0 or bottle_type >= NAMES.size():
		return Vector2i.ZERO
	var units: int = mini(sale_stock(bottle_type),buyer_remaining(bottle_type))
	if limit >= 0:
		units = mini(units, limit)
	return Vector2i(units,units*sale_unit_price(bottle_type)) if units > 0 else Vector2i.ZERO


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
	bought_today[bottle_type] += quote.x
	var payment: int = credit_cents+quote.y
	credits += payment/100
	credit_cents = payment%100
	check_story_recovery()
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
		0: return delivered > 0 or installed[0]
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
	check_story_recovery()
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
	while elapsed > 0.0:
		var remaining: float = market_seconds_left()
		var step: float = minf(elapsed,remaining)
		advance_operations(step)
		elapsed -= step
		if step == remaining:
			turn_market_day()
		else:
			market_elapsed += step


func advance_operations(elapsed: float) -> void:
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
		"version": 11, "queues": queues, "installed": installed,
		"sold_by_type": sold_by_type, "credits": credits, "received": received,
		"credit_cents": credit_cents, "market_day": market_day, "market_elapsed": market_elapsed,
		"bought_today": bought_today, "bought_yesterday": bought_yesterday,
		"story_read": story_read, "story_recovered": story_recovered,
		"delivered": delivered, "recycled": recycled, "phase": phase,
		"priority": priority, "held": held, "held_queue": held_queue, "trucks": trucks, "clock": clock,
		"carried": carried.map(func(item: Vector2i) -> Array: return [item.x,item.y]), "bag_upgraded": bag_upgraded,
		"pushing_cart": pushing_cart,
		"parked_load": parked_load.map(func(item: Vector2i) -> Array: return [item.x,item.y]),
		"crate_level": crate_level, "bench_crate": bench_crate, "hand_crate": hand_crate, "cart_crates": cart_crates,
		"parked_at": [parked_at.x,parked_at.y,parked_at.z,parked_angle] if parked_at.is_finite() else [],
		"next_truck": next_truck, "day_active": day_active, "day_complete": day_complete,
		"day_base_delivered": day_base_delivered, "day_base_recycled": day_base_recycled, "day_truck_size": day_truck_size,
		"rush": rush, "auto_sales": auto_sales, "owned_scraper": owned_scraper, "equipped_scraper": equipped_scraper,
	}


func restore(data: Variant) -> void:
	if not data is Dictionary:
		return
	var version: int = int(data.get("version", 0))
	if version < 1 or version > 11:
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
	credit_cents = clampi(int(data.get("credit_cents",0)),0,99) if version >= 9 else 0
	market_day = maxi(1,int(data.get("market_day",1))) if version >= 9 else 1
	market_elapsed = clampf(float(data.get("market_elapsed",0.0)),0.0,MARKET_DAY_SECONDS) if version >= 9 else 0.0
	bought_today.fill(0)
	bought_yesterday.fill(0)
	if version >= 9:
		read_market_purchases(data.get("bought_today"),bought_today)
		read_market_purchases(data.get("bought_yesterday"),bought_yesterday)
	owned_scraper = clampi(int(data.get("owned_scraper",0)),0,SCRAPERS.size()-1) if version >= 4 else 0
	equipped_scraper = clampi(int(data.get("equipped_scraper",0)),0,owned_scraper) if version >= 4 else 0
	received = int(data.received)
	delivered = int(data.delivered)
	recycled = int(data.recycled)
	phase = int(data.phase)
	# Earlier saves expanded the bag automatically when the street shipment arrived.
	bag_upgraded = phase >= BAG_UPGRADE_PHASE and (version < 10 or bool(data.get("bag_upgraded",false)))
	story_recovered = bool(data.get("story_recovered",false))
	check_story_recovery()
	story_read = clampi(int(data.get("story_read",-1)),-1,story_chapter())
	priority = int(data.priority)
	held = int(data.held)
	held_queue = clampi(int(data.get("held_queue", RAW)), RAW, CLEAN)
	carried = read_transport(data.get("carried",[]) if version >= 7 else [])
	parked_load = read_transport(data.get("parked_load",[]) if version >= 7 else [])
	pushing_cart = cart_unlocked() and version >= 7 and bool(data.get("pushing_cart",false))
	crate_level = clampi(int(data.get("crate_level",0)),0,CRATE_CAPACITIES.size()-1) if version >= 8 else 0
	bench_crate = read_crate(data.get("bench_crate",[]) if version >= 8 else [])
	hand_crate = read_crate(data.get("hand_crate",[]) if version >= 8 else [])
	cart_crates.clear()
	var stored_crates: Variant = data.get("cart_crates",[])
	if version >= 8 and cart_unlocked() and stored_crates is Array:
		for stored in stored_crates:
			var cargo: Array[int] = read_crate(stored)
			if not cargo.is_empty():
				if cart_crates.size() < CART_CRATE_LIMIT:
					cart_crates.append(cargo)
				else:
					for item in cargo:
						queues[CLEAN][item] += 1
	parked_at = Vector3.INF
	parked_angle = 0.0
	var parked: Variant = data.get("parked_at",[])
	if cart_unlocked() and version >= 7 and parked is Array and parked.size() == 4:
		parked_at = Vector3(float(parked[0]),float(parked[1]),float(parked[2]))
		parked_angle = float(parked[3])
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
	if version >= 7:
		if held_queue == CLEAN and version < 11:
			if not set_down():
				return_held()
		else:
			stow_held()
		while carried.size() > carry_capacity():
			var item: Vector2i = carried.pop_back()
			queues[item.y][item.x] += 1
		# The cart may have been parked before the bag was upgraded.
		var parked_capacity: int = CART_CAPACITY-1 if cart_unlocked() and not pushing_cart else 0
		while parked_load.size() > parked_capacity:
			var item: Vector2i = parked_load.pop_back()
			queues[item.y][item.x] += 1
	else:
		return_held()
	refill_legacy_crate()
	if version < 5 and phase == 0 and received == 24 and not installed[0] and (in_yard() > 0 or credits < COST[0]):
		for item in STARTER_STOCK.size():
			queues[RAW][item] += STARTER_STOCK[item]-LEGACY_STARTER_STOCK[item]
		received = STARTER_SIZE


func read_transport(stored: Variant) -> Array[Vector2i]:
	var items: Array[Vector2i] = []
	if stored is Array:
		for pair in stored:
			if pair is Array and pair.size() == 2:
				var item := Vector2i(int(pair[0]),int(pair[1]))
				if item.x >= 0 and item.x < NAMES.size()*CONDITION.size() and item.y >= RAW and item.y <= CLEAN:
					items.append(item)
	return items


func read_market_purchases(stored: Variant, purchases: Array[int]) -> void:
	if stored is Array and stored.size() == purchases.size():
		for i in purchases.size():
			purchases[i] = maxi(0,int(stored[i]))


func read_crate(stored: Variant) -> Array[int]:
	var items: Array[int] = []
	if stored is Array:
		for value in stored:
			var item: int = int(value)
			if item >= 0 and item < NAMES.size()*CONDITION.size() and grade(item) < 2:
				if items.size() < crate_capacity():
					items.append(item)
				else:
					queues[CLEAN][item] += 1
	return items
