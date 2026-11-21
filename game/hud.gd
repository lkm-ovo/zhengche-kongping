extends Control

signal action(id: String, value: int)

const Yard = preload("res://yard.gd")
const INK = Color("eee8d7")
const MUTED = Color("b4b9a7")
const ACCENT = Color("efbd79")
const GREEN = Color("a9c39f")
const PANEL = Color("18221fe8")
const PAPER = Color("25322e")
const RULE = Color("45594c")
const EMPTY_SLOT = Color("41524a")
const CARRY_METER_WIDTH = 351.0
const STORY_NAMES = ["收盘之后", "第一笔回款", "会转的旧机器", "货车到站", "账本翻页"]
const STORY_PAGES = [
	"从前下班先看股票，睡前还要看一遍。那天收盘，你终于把交易记录从头加了一次：攒下的工资，亏了 ¥%s。\n\n老周把街角闲着的回收点借给你。他拉开车库滑门，指了指地上的空瓶：“先把这些做完。钱要等人验完货，才算是你的。”",
	"收购商挑出一只酒瓶，划过瓶口，看了看瓶底的水印，才在单子上打勾。\n\n你把第一笔回款抄进账本。数不大，倒是头一回知道每一块钱是从哪儿来的。",
	"二手脱标机启动时咯噔了一下。你把手搭在外壳上，确认它没卡瓶，又伸手把桌上的旧刮刀放回原处。\n\n老周问：“回款都拿去买机器，不心疼？”你说心疼，还是把下一筐推了过去。",
	"货车倒进院子，地磅的数字还在跳。你没催司机，先核来料单，再看水箱和成品筐里还剩多少位置。\n\n账本首页还夹着那张交割单。你想在这一页下面另记一笔：回收站的周转金，也能攒到那个数。",
	"最后一笔结算到账，你在首页记下 ¥%s，旁边没有加号，也没有箭头。\n\n老周问要不要把钱提出来。你留在了站里。明早还得付电费，洗瓶机那只漏水的接头也该换了。你合上账本，去关水。",
]
const STORY_GOALS = [
	"从右侧滑门进车库取瓶，到脱标台刮标签、擦残胶。", "用回款安装台式脱标机。",
	"处理散货和托盘货，接下第一辆满载货车。", "通过出货结算，把站里的周转金攒到目标金额。",
	"回收站照常营业，仍可扩产并挑战区域班次。",
]

var world_view: Control
var office: Control
var office_board: Panel
var market: Panel
var tool_shop: Panel
var tool_wallet: Label
var tool_notice: Label
var tool_buttons: Array[Button] = []
var tool_requirements: Array[Label] = []
var number_font: SystemFont
var site: Label
var objective: Label
var detail: Label
var story_title: Label
var story_hint: Label
var journal: ColorRect
var journal_index: int = 0
var journal_buttons: Array[Button] = []
var journal_title: Label
var journal_page: Label
var journal_goal: Label
var journal_balance: Label
var journal_progress: ColorRect
var journal_close: Button
var money: Label
var outbound: Label
var queue_total: Label
var carry_title: Label
var carry_secondary: Label
var carry_slots: Array[ColorRect] = []
var carry_contents: Label
var helper: Label
var reticle: Label
var target_card: Panel
var target_label: Label
var target_hint: Label
var bottom: Panel
var work_name: Label
var work_action: Label
var work_prompt: Label
var work_percent: Label
var progress: ColorRect
var result: Label
var resumable: Panel
var office_title: Label
var office_detail: Label
var manifest: Label
var notice: Label
var place_order: Button
var bag_upgrade: Button
var bag_caption: Label
var bag_details: Label
var feed: Button
var wash: Button
var sanitize: Button
var inspect: Button
var market_inventory: Label
var market_notice: Label
var market_clock: Label
var buyer_name: Label
var buyer_type: Label
var buyer_demand: Label
var buyer_quantity: Label
var buyer_price: Label
var buyer_total: Label
var pack_for_sale: Button
var unload_finished: Button
var confirm_sale: Button
var wait_market: Button
var auto_sale_button: Button
var auto_sale_hint: Label
var market_stock: Array[Label] = []
var market_prices: Array[Label] = []
var market_remaining: Array[Label] = []
var buyer_buttons: Array[Button] = []
var selected_buyer: int = 0
var order_priority: OptionButton
var speed: Button
var machine_buttons: Array = []
var machine_rows: Array = []
var equipment_notice: Label
var bulk_heading: Label
var amount: Array = []
var sales_rows: Array = []
var hand_active: bool
var hand_cursor: Vector2
var hand_target: Vector2
var focused: bool
var frozen: bool
var scrape_guide: bool


func make_style(base: Color, border: Color = Color.TRANSPARENT, radius: int = 6) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = base
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 11
	style.content_margin_right = 11
	return style


func panel(parent: Control, at: Vector2, dimensions: Vector2, color: Color = PANEL) -> Panel:
	var item := Panel.new()
	item.position = at
	item.size = dimensions
	item.add_theme_stylebox_override("panel", make_style(color, Color("405047cc")))
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(item)
	return item


func label(parent: Control, value: String, at: Vector2, dimensions: Vector2, font_size: int, color: Color = INK, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var item := Label.new()
	item.position = at
	item.size = dimensions
	item.text = value
	item.horizontal_alignment = align
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", color)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(item)
	return item


func button(parent: Control, caption: String, id: String, at: Vector2, dimensions: Vector2, value: int = 0) -> Button:
	var item := Button.new()
	item.position = at
	item.size = dimensions
	item.text = caption
	item.focus_mode = Control.FOCUS_NONE
	item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	item.add_theme_stylebox_override("normal", make_style(Color("35483e"), RULE))
	item.add_theme_stylebox_override("hover", make_style(Color("4b6151"), Color("897650")))
	item.add_theme_stylebox_override("pressed", make_style(Color("695538"), ACCENT))
	item.add_theme_stylebox_override("disabled", make_style(Color("29352f"), Color("394139")))
	item.add_theme_color_override("font_color", INK)
	item.add_theme_color_override("font_disabled_color", Color("9a9c8b"))
	item.add_theme_font_size_override("font_size", 16)
	item.pressed.connect(func() -> void: action.emit(id,value))
	parent.add_child(item)
	return item


func make_theme() -> void:
	var t := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC"])
	t.default_font = font
	t.default_font_size = 16
	t.set_color("font_color", "Label", INK)
	t.set_color("font_color", "OptionButton", INK)
	t.set_stylebox("normal", "OptionButton", make_style(Color("35483e"), RULE))
	t.set_stylebox("hover", "OptionButton", make_style(Color("4b6151"), RULE))
	t.set_stylebox("pressed", "OptionButton", make_style(Color("455649"), ACCENT))
	t.set_stylebox("panel","PopupMenu",make_style(PAPER,RULE))
	t.set_stylebox("hover","PopupMenu",make_style(Color("4b6151"),RULE))
	t.set_color("font_color","PopupMenu",INK)
	theme = t
	number_font = SystemFont.new()
	number_font.font_names = PackedStringArray(["Bahnschrift", "Segoe UI"])


func build() -> void:
	make_theme()
	size = Vector2(1280,800)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	world_view = Control.new()
	world_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(world_view)
	var identity := panel(world_view,Vector2(25,23),Vector2(235,63))
	label(identity,"整车空瓶",Vector2(15,5),Vector2(125,40),25)
	site = label(identity,"街边回收点",Vector2(15,38),Vector2(205,18),13,MUTED)
	var mark := label(identity,"▰",Vector2(185,9),Vector2(36,38),26,ACCENT,HORIZONTAL_ALIGNMENT_RIGHT)
	mark.rotation = -.11
	var assignment := panel(world_view,Vector2(25,97),Vector2(278,95))
	objective = label(assignment,"",Vector2(14,9),Vector2(248,27),17,ACCENT)
	detail = label(assignment,"",Vector2(14,37),Vector2(248,50),14,MUTED)
	detail.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var story_card := panel(world_view,Vector2(25,202),Vector2(278,57))
	story_title = label(story_card,"",Vector2(14,4),Vector2(248,26),16,ACCENT)
	story_hint = label(story_card,"",Vector2(14,30),Vector2(248,21),13,MUTED)
	var scoreboard := panel(world_view,Vector2(880,23),Vector2(375,64))
	money = meter(scoreboard, "资金", 12)
	queue_total = meter(scoreboard, "站内库存", 135)
	outbound = meter(scoreboard, "累计出货", 258)
	var inventory := panel(world_view,Vector2(880,97),Vector2(375,94))
	carry_title = label(inventory,"",Vector2(12,6),Vector2(156,25),17,ACCENT)
	carry_secondary = label(inventory,"",Vector2(168,7),Vector2(195,24),14,MUTED,HORIZONTAL_ALIGNMENT_RIGHT)
	for i in Yard.CART_CAPACITY:
		var slot := ColorRect.new()
		slot.position.y = 35.0
		slot.size.y = 7.0
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inventory.add_child(slot)
		carry_slots.append(slot)
	carry_contents = label(inventory,"",Vector2(12,50),Vector2(351,41),14,INK)
	carry_contents.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	carry_contents.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	reticle = label(world_view,"·",Vector2(626,383),Vector2(28,28),30,INK,HORIZONTAL_ALIGNMENT_CENTER)
	target_card = panel(world_view,Vector2(402,507),Vector2(476,36))
	target_label = label(target_card,"",Vector2(10,4),Vector2(456,27),16,INK,HORIZONTAL_ALIGNMENT_CENTER)
	target_hint = label(target_card,"",Vector2(10,30),Vector2(456,22),14,MUTED,HORIZONTAL_ALIGNMENT_CENTER)
	target_card.hide()
	helper = label(world_view,"WASD 移动    ·    E 交互    ·    Tab 站务    ·    Esc 释放鼠标",
		Vector2(25,754),Vector2(1228,30),15,INK)
	helper.add_theme_color_override("font_shadow_color",Color("17221e"))
	helper.add_theme_constant_override("shadow_offset_y",2)
	bottom = panel(world_view,Vector2(352,653),Vector2(576,97))
	work_name = label(bottom,"",Vector2(16,6),Vector2(400,31),21,INK)
	work_percent = label(bottom,"",Vector2(440,8),Vector2(120,28),16,ACCENT,HORIZONTAL_ALIGNMENT_RIGHT)
	work_action = label(bottom,"",Vector2(16,37),Vector2(542,23),16,ACCENT)
	work_prompt = label(bottom,"",Vector2(16,61),Vector2(542,23),16,INK)
	var track := ColorRect.new()
	track.position = Vector2(16,87)
	track.size = Vector2(544,3)
	track.color = Color("425549")
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(track)
	progress = ColorRect.new()
	progress.position = track.position
	progress.size = Vector2(0,3)
	progress.color = Color("d2a269")
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(progress)
	result = label(world_view,"",Vector2(354,609),Vector2(572,31),16,ACCENT,HORIZONTAL_ALIGNMENT_CENTER)
	result.add_theme_color_override("font_shadow_color",Color("152722"))
	result.add_theme_constant_override("shadow_offset_y",2)
	resumable = panel(world_view,Vector2(435,327),Vector2(410,122))
	label(resumable,"鼠标已释放",Vector2(12,14),Vector2(386,40),25,INK,HORIZONTAL_ALIGNMENT_CENTER)
	label(resumable,"点击画面继续    ·    回收站会继续运转",Vector2(10,61),Vector2(390,32),16,MUTED,HORIZONTAL_ALIGNMENT_CENTER)
	resumable.hide()
	build_office()
	build_journal()


func build_journal() -> void:
	journal = ColorRect.new()
	journal.size = size
	journal.color = Color("111a17ec")
	journal.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(journal)
	var cover := panel(journal,Vector2(182,127),Vector2(916,546),PAPER)
	label(cover,"街边回收点  /  主线故事",Vector2(27,17),Vector2(460,25),14,ACCENT)
	label(cover,"营业簿",Vector2(26,42),Vector2(460,47),34)
	journal_close = button(cover,"合上账本  Esc","close_journal",Vector2(743,31),Vector2(146,37))
	var tabs := panel(cover,Vector2(26,104),Vector2(208,411),Color("1a2722"))
	label(tabs,"章节",Vector2(13,12),Vector2(180,25),15,MUTED)
	for index in STORY_NAMES.size():
		journal_buttons.append(button(tabs,"","journal_chapter",Vector2(12,51+index*48),Vector2(184,39),index))
	var page := panel(cover,Vector2(249,104),Vector2(640,411),Color("2d3d34"))
	journal_title = label(page,"",Vector2(24,14),Vector2(592,38),26)
	journal_page = label(page,"",Vector2(24,68),Vector2(592,220),20,INK)
	journal_page.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	journal_page.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	journal_goal = label(page,"",Vector2(24,285),Vector2(592,47),16,ACCENT)
	journal_goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	journal_balance = label(page,"",Vector2(24,341),Vector2(592,32),17,GREEN)
	var track := ColorRect.new()
	track.position = Vector2(24,381)
	track.size = Vector2(592,5)
	track.color = RULE
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(track)
	journal_progress = ColorRect.new()
	journal_progress.position = track.position
	journal_progress.size = Vector2(0,track.size.y)
	journal_progress.color = GREEN
	journal_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(journal_progress)
	journal.hide()


func update_journal(model) -> void:
	var chapter: int = model.story_chapter()
	for index in journal_buttons.size():
		var unlocked: bool = index <= chapter
		journal_buttons[index].disabled = not unlocked or index == journal_index
		journal_buttons[index].text = "%02d   %s" % [index+1,STORY_NAMES[index] if unlocked else "未解锁"]
		journal_buttons[index].add_theme_color_override("font_disabled_color",ACCENT if index == journal_index else MUTED)
	journal_title.text = STORY_NAMES[journal_index]
	journal_page.text = STORY_PAGES[journal_index]
	if journal_index in [Yard.Story.OPENING,Yard.Story.RECOVERED]:
		journal_page.text = journal_page.text % comma(Yard.STORY_TARGET)
	journal_goal.text = ("主线完成  ·  " if model.story_recovered else "当前目标  ·  ") + STORY_GOALS[chapter]
	if chapter == Yard.Story.OPENING and (not model.bench_crate.is_empty() or model.transport_finished_count() > 0 or model.sum_queue(Yard.FOR_SALE) > 0):
		journal_goal.text = "当前目标  ·  搬起成品筐，到滑门外右侧的窗口交货。"
	journal_balance.text = "周转金已达到目标  ¥ %s" % comma(Yard.STORY_TARGET) if model.story_recovered else (
		"周转金  ¥ %s  /  ¥ %s" % [format_cash(model.wallet_cents()),comma(Yard.STORY_TARGET)])
	journal_progress.size.x = 592.0 if model.story_recovered else 592.0*clampf(float(model.credits)/Yard.STORY_TARGET,0.0,1.0)


func meter(parent: Control, name: String, x: float) -> Label:
	label(parent,name,Vector2(x,7),Vector2(111,20),13,MUTED)
	var value: Label = label(parent,"0",Vector2(x,25),Vector2(112,35),22)
	value.add_theme_font_override("font",number_font)
	return value


func build_office() -> void:
	office = Control.new()
	office.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(office)
	var dim := ColorRect.new()
	dim.size = Vector2(1280,800)
	dim.color = Color("0c1514a8")
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	office.add_child(dim)
	var board := panel(office,Vector2(114,101),Vector2(1052,620),Color("1a2825fa"))
	office_board = board
	label(board,"站务终端",Vector2(25,14),Vector2(240,49),29)
	label(board,"到货、设备与成品发运",Vector2(26,61),Vector2(366,23),15,MUTED)
	var bag_card := panel(board,Vector2(382,16),Vector2(351,68),PAPER)
	bag_caption = label(bag_card,"背包容量",Vector2(12,6),Vector2(188,25),16,INK)
	bag_details = label(bag_card,"",Vector2(12,34),Vector2(188,22),14,MUTED)
	bag_upgrade = button(bag_card,"升级背包","upgrade_bag",Vector2(204,14),Vector2(133,40))
	bag_upgrade.add_theme_stylebox_override("normal",make_style(Color("584833"),Color("bd925f")))
	bag_upgrade.add_theme_stylebox_override("hover",make_style(Color("735938"),ACCENT))
	button(board,"刀具升级","open_tools",Vector2(747,24),Vector2(121,39))
	button(board,"返回现场  Esc","close",Vector2(884,24),Vector2(142,39))
	var left := panel(board,Vector2(23,107),Vector2(280,494),PAPER)
	var center := panel(board,Vector2(319,107),Vector2(385,494),PAPER)
	var right := panel(board,Vector2(720,107),Vector2(307,494),PAPER)
	label(left,"到货与出库",Vector2(14,12),Vector2(248,26),18,ACCENT)
	office_title = label(left,"",Vector2(14,47),Vector2(252,31),22)
	office_detail = label(left,"",Vector2(14,84),Vector2(247,68),15,MUTED)
	office_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	office_detail.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	place_order = button(left,"接下一批货","receive",Vector2(14,158),Vector2(252,43))
	manifest = label(left,"",Vector2(14,216),Vector2(250,59),15,GREEN)
	manifest.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	manifest.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bulk_heading = label(left,"手动批处理",Vector2(14,286),Vector2(250,25),17,ACCENT)
	feed = button(left,"分拣并整筐上料","feed",Vector2(14,315),Vector2(252,30))
	wash = button(left,"批量清洗普通瓶","wash",Vector2(14,350),Vector2(252,30))
	sanitize = button(left,"批量消毒","sanitize",Vector2(14,385),Vector2(252,30))
	inspect = button(left,"批量沥干验瓶","inspect",Vector2(14,420),Vector2(252,30))
	label(left,"收购窗口在滑门外右侧",Vector2(14,455),Vector2(252,30),15,MUTED)
	notice = label(left,"",Vector2(14,266),Vector2(252,19),14,MUTED)
	label(center,"扩建设备",Vector2(14,12),Vector2(354,27),18,ACCENT)
	equipment_notice = label(center,"完成首笔出货后开放设备采购。",Vector2(16,51),Vector2(351,35),16,MUTED)
	var equipment_order: Array = [0,1,Yard.SANITIZER,2,3,4,5,6]
	machine_rows.resize(Yard.EQUIPMENT.size())
	machine_buttons.resize(Yard.EQUIPMENT.size())
	for position_index in equipment_order.size():
		var i: int = equipment_order[position_index]
		var row := panel(center,Vector2(12,47+position_index*54),Vector2(361,48),Color("2d3d34"))
		label(row,Yard.EQUIPMENT[i],Vector2(10,3),Vector2(225,25),16)
		machine_rows[i] = label(row,"",Vector2(10,24),Vector2(225,20),13,MUTED)
		machine_buttons[i] = button(row,"购入","buy",Vector2(242,7),Vector2(108,34),i)
	label(right,"产线库存",Vector2(14,12),Vector2(277,27),18,ACCENT)
	for i in Yard.QUEUE_NAMES.size():
		label(right,Yard.QUEUE_NAMES[i],Vector2(14,44+i*22),Vector2(120,21),15,MUTED)
		amount.append(label(right,"0",Vector2(134,44+i*22),Vector2(159,21),17,INK,HORIZONTAL_ALIGNMENT_RIGHT))
	label(right,"优先瓶型",Vector2(14,210),Vector2(100,24),15)
	order_priority = OptionButton.new()
	order_priority.position = Vector2(108,203)
	order_priority.size = Vector2(185,37)
	order_priority.add_item("按默认顺序",0)
	for i in Yard.NAMES.size():
		order_priority.add_item(Yard.NAMES[i],i+1)
	order_priority.focus_mode = Control.FOCUS_NONE
	order_priority.item_selected.connect(func(index: int) -> void: action.emit("priority",index-1))
	right.add_child(order_priority)
	speed = button(right,"运行速度  ×1","speed",Vector2(14,247),Vector2(279,37))
	label(right,"分瓶型累计出货",Vector2(14,294),Vector2(275,25),17,ACCENT)
	for i in Yard.NAMES.size():
		label(right,Yard.NAMES[i],Vector2(14,326+i*25),Vector2(127,22),14,MUTED)
		sales_rows.append(label(right,"0",Vector2(141,325+i*25),Vector2(152,23),16,INK,HORIZONTAL_ALIGNMENT_RIGHT))
	build_market()
	build_tool_shop()
	office.hide()


func build_tool_shop() -> void:
	tool_shop = panel(office,Vector2(114,101),Vector2(1052,620),Color("1a2825fa"))
	label(tool_shop,"刀具升级",Vector2(25,14),Vector2(280,49),29)
	tool_wallet = label(tool_shop,"",Vector2(26,61),Vector2(678,23),16,MUTED)
	button(tool_shop,"站务终端","open_operations",Vector2(731,24),Vector2(140,39))
	button(tool_shop,"返回现场  Esc","close",Vector2(884,24),Vector2(142,39))
	var tray := panel(tool_shop,Vector2(23,107),Vector2(1004,438),PAPER)
	var descriptions := ["钝刃会跳刀，刮下来是碎屑；补刮后还要擦掉残胶。",
		"薄刃刮纸更利落，削下窄条；塑膜仍需补刮和擦胶。",
		"弧刃贴合瓶身，纸标和塑膜都能成条刮下。",
		"弹簧护座稳住刀口，最短的行程就能刮净。"]
	for i in Yard.SCRAPERS.size():
		var spec: Dictionary = Yard.SCRAPERS[i]
		var row := panel(tray,Vector2(14,14+i*106),Vector2(976,92),Color("2d3d34"))
		label(row,spec.name,Vector2(17,7),Vector2(335,36),21)
		label(row,descriptions[i],Vector2(17,47),Vector2(526,26),15,MUTED)
		label(row,"纸标 %d 道  ·  塑膜 %d 道" % [spec.passes[0],spec.passes[1]],Vector2(497,16),Vector2(245,36),16,GREEN)
		tool_requirements.append(label(row,"",Vector2(657,53),Vector2(151,22),14,ACCENT,HORIZONTAL_ALIGNMENT_RIGHT))
		tool_buttons.append(button(row,"", "choose_scraper",Vector2(833,23),Vector2(126,45),i))
	tool_notice = label(tool_shop,"",Vector2(25,557),Vector2(1001,31),16,GREEN)
	tool_shop.hide()


func show_tools(model) -> void:
	market.hide()
	office_board.hide()
	tool_shop.show()
	update_tool_shop(model,"")


func update_tool_shop(model, status: String) -> void:
	var equipped: String = Yard.SCRAPERS[model.equipped_scraper].name
	tool_wallet.text = "装备  %s     资金  ¥ %s" % [equipped,format_cash(model.wallet_cents())]
	for i in tool_buttons.size():
		var entry: Button = tool_buttons[i]
		var spec: Dictionary = Yard.SCRAPERS[i]
		entry.disabled = not model.can_choose_scraper(i)
		entry.text = "已装备" if i == model.equipped_scraper else "装备" if i <= model.owned_scraper else "¥ %d" % spec.price
		var requirement: String = ""
		if i > model.owned_scraper:
			if i > model.owned_scraper+1:
				requirement = "先购前一把"
			elif i >= 2 and not model.installed[0]:
				requirement = "需安装脱标机"
			elif model.credits < spec.price:
				requirement = "资金不足"
		tool_requirements[i].text = requirement
	tool_notice.text = status if not status.is_empty() else "装备的刮刀会在取下一瓶时使用。"


func build_market() -> void:
	market = panel(office,Vector2(114,101),Vector2(1052,620),Color("1a2825fa"))
	label(market,"成品收购窗口",Vector2(25,14),Vector2(260,49),29)
	market_clock = label(market,"",Vector2(250,27),Vector2(451,32),16,ACCENT)
	market_inventory = label(market,"",Vector2(26,61),Vector2(660,23),16,MUTED)
	button(market,"站务终端","open_operations",Vector2(731,24),Vector2(140,39))
	button(market,"返回现场  Esc","close",Vector2(884,24),Vector2(142,39))
	var orders := panel(market,Vector2(23,107),Vector2(636,494),PAPER)
	var invoice := panel(market,Vector2(675,107),Vector2(352,494),PAPER)
	for heading in [["收购方",19,130],["瓶型",150,112],["单价",267,70],["待售",344,80],["今日还能收",430,90]]:
		label(orders,heading[0],Vector2(heading[1],14),Vector2(heading[2],27),15,ACCENT)
	for i in Yard.BUYERS.size():
		var row := panel(orders,Vector2(12,52+i*56),Vector2(612,48),Color("2d3d34"))
		label(row,Yard.BUYERS[i],Vector2(7,8),Vector2(129,30),16)
		label(row,Yard.NAMES[i],Vector2(138,8),Vector2(116,30),15,MUTED)
		market_prices.append(label(row,"",Vector2(255,8),Vector2(70,30),15))
		market_stock.append(label(row,"",Vector2(332,8),Vector2(82,30),15))
		market_remaining.append(label(row,"",Vector2(418,8),Vector2(93,30),15,GREEN))
		buyer_buttons.append(button(row,"看收购单","select_buyer",Vector2(515,7),Vector2(88,34),i))
	unload_finished = button(orders,"交付搬来的成品筐","unload_finished",Vector2(12,405),Vector2(299,37))
	pack_for_sale = button(orders,"交接批量成品","pack_for_sale",Vector2(323,405),Vector2(301,37))
	market_notice = label(orders,"",Vector2(14,448),Vector2(610,28),15,GREEN)
	label(invoice,"收购单",Vector2(16,14),Vector2(316,29),18,ACCENT)
	buyer_name = label(invoice,"",Vector2(16,51),Vector2(316,35),24)
	buyer_type = label(invoice,"",Vector2(16,92),Vector2(316,25),16,MUTED)
	buyer_demand = label(invoice,"",Vector2(16,122),Vector2(321,25),14,MUTED)
	label(invoice,"本单可成交",Vector2(16,160),Vector2(165,23),15,MUTED)
	buyer_quantity = label(invoice,"",Vector2(175,160),Vector2(158,23),18,INK,HORIZONTAL_ALIGNMENT_RIGHT)
	label(invoice,"单价",Vector2(16,193),Vector2(165,23),15,MUTED)
	buyer_price = label(invoice,"",Vector2(175,193),Vector2(158,23),18,INK,HORIZONTAL_ALIGNMENT_RIGHT)
	label(invoice,"预计入账",Vector2(16,229),Vector2(316,24),16,ACCENT)
	buyer_total = label(invoice,"",Vector2(16,255),Vector2(314,48),31)
	confirm_sale = button(invoice,"确认出售","confirm_sale",Vector2(16,317),Vector2(320,43))
	wait_market = button(invoice,"等到次日收购","wait_market",Vector2(16,369),Vector2(320,35))
	wait_market.tooltip_text = "待售货物遇到收满额度的买家时，可提前换日。"
	auto_sale_button = button(invoice,"开启自动销售","auto_sales",Vector2(16,416),Vector2(320,36))
	auto_sale_hint = label(invoice,"",Vector2(16,460),Vector2(320,23),13,MUTED)
	market.hide()


func select_available_buyer(model) -> void:
	if model.sale_quote(selected_buyer).x > 0:
		return
	for i in Yard.BUYERS.size():
		if model.sale_quote(i).x > 0:
			selected_buyer = i
			return


func show_sales(show_market: bool, model) -> void:
	tool_shop.hide()
	market.visible = show_market
	office_board.visible = not show_market
	if show_market:
		select_available_buyer(model)


func update_market(model, status: String) -> void:
	var packed: int = model.sum_queue(Yard.CLEAN)
	var awaiting: int = model.sum_queue(Yard.FOR_SALE)
	var brought: int = model.transport_finished_count()
	market_clock.text = "第 %d 天   ·   %d 秒后换单" % [model.market_day,ceili(model.market_seconds_left()/model.rush)]
	market_inventory.text = "带来  %s 只     窗口待售  %s 只     资金  ¥ %s" % [comma(brought),comma(awaiting),format_cash(model.wallet_cents())]
	unload_finished.disabled = brought == 0
	unload_finished.text = "卸下 %d 筐 · 共 %d 只" % [model.transport_crate_count(),brought] if brought > 0 else "交付搬来的成品筐"
	pack_for_sale.visible = model.installed[0]
	pack_for_sale.disabled = packed == 0
	pack_for_sale.text = "交接批量成品 · %s 只" % comma(packed) if packed > 0 else "交接批量成品"
	for i in Yard.BUYERS.size():
		market_prices[i].text = "¥ "+format_cash(model.sale_unit_price(i))
		market_stock[i].text = comma(model.sale_stock(i))
		var remaining: int = model.buyer_remaining(i)
		market_remaining[i].text = comma(remaining) if remaining > 0 else "已收满"
		buyer_buttons[i].text = "已选" if i == selected_buyer else "看收购单"
		buyer_buttons[i].disabled = i == selected_buyer
	var quote: Vector2i = model.sale_quote(selected_buyer)
	buyer_name.text = Yard.BUYERS[selected_buyer]
	buyer_type.text = Yard.NAMES[selected_buyer]
	buyer_demand.text = "昨日收购 %s 只   ·   今日计划 %s 只" % [comma(model.bought_yesterday[selected_buyer]),comma(model.buyer_quota(selected_buyer))]
	buyer_quantity.text = comma(quote.x)+" 只"
	buyer_price.text = "¥ %s / 只" % format_cash(model.sale_unit_price(selected_buyer))
	buyer_total.text = "¥ "+format_cash(quote.y)
	confirm_sale.disabled = quote.x == 0
	confirm_sale.text = "确认出售 %s 只" % comma(quote.x) if quote.x > 0 else ("买家今日已收满" if model.buyer_remaining(selected_buyer) == 0 else "暂无可售成品")
	wait_market.disabled = not model.market_wait_available()
	auto_sale_button.disabled = not model.installed[Yard.PACKER]
	auto_sale_button.text = "自动销售已开启 · 点击关闭" if model.auto_sales else "开启自动销售"
	auto_sale_hint.text = "按当前报价结款，收满后等次日" if model.installed[Yard.PACKER] else "安装装箱发货机即可开启自动销售"
	market_notice.text = status if not status.is_empty() else "同类待售货物积得越多，收购价越低。"


func comma(value: int) -> String:
	var digits: String = str(value)
	var index: int = digits.length()-3
	while index > 0:
		digits = digits.insert(index,",")
		index -= 3
	return digits


func format_cash(cents: int) -> String:
	var whole: String = comma(cents/100)
	return whole if cents%100 == 0 else "%s.%02d" % [whole,cents%100]


func update_model(model, status: String) -> void:
	var chapter: int = model.story_chapter()
	story_title.text = "主线  ·  " + STORY_NAMES[chapter]
	story_hint.text = "J 查看新章节" if chapter > model.story_read else "J 翻开营业簿"
	if journal.visible:
		update_journal(model)
	site.text = Yard.AREA[model.phase]
	money.text = "¥ " + format_cash(model.wallet_cents())
	queue_total.text = comma(model.in_yard())
	outbound.text = comma(model.delivered)
	update_inventory(model)
	var next: int = model.next_phase()
	var opportunities: Array = [
		"处理首批空瓶，把成品筐搬到滑门外的收购窗口。",
		"可继续手工处理，也可批量脱标、清洗和出货。",
		"装好产线设备，开启自动销售，接下第一辆混装货车。",
		"车库可推小推车，一趟能装三筐成品。开通专用工位和托盘调度。",
		"接一整天的六十辆货车。整站可自动清洗、消毒和发货。",
	]
	objective.text = ["处理首批 %s 只瓶子" % comma(model.received),"准备接托盘货","打通自动产线","处理第一辆满载货车","区域回收中心"][model.phase]
	detail.text = opportunities[model.phase]
	if chapter == Yard.Story.OPENING:
		detail.text = STORY_GOALS[chapter]
		if model.transport_finished_count() > 0:
			detail.text = "出滑门右转，把成品筐交给收购窗口。"
		elif not model.bench_crate.is_empty():
			detail.text = "对准成品筐按 E 搬起，出滑门右转去收购窗口。"
		elif model.sum_queue(Yard.FOR_SALE) > 0:
			detail.text = "收购窗口有已交付的成品，选择收购单结款。"
	if model.phase == 0 and model.in_yard() == 0:
		objective.text = "首批空瓶已处理"
		detail.text = "在生产终端接下一批散货。" if model.installed[0] else "在生产终端采购台式脱标机，就能接下批散货。"
	if model.day_active:
		objective.text = "无人值守班次运行中"
		detail.text = "货车到站 %d / %d · 每车 %s 只\n已出货 %s 只" % [model.trucks,Yard.DAY_TRUCKS,comma(model.day_truck_size),comma(model.delivered-model.day_base_delivered)]
	if model.day_complete:
		objective.text = "%d 辆满载货车已结清" % Yard.DAY_TRUCKS
		detail.text = "成品 %s 只 · 破损回收 %s 只" % [comma(model.delivered-model.day_base_delivered),comma(model.recycled-model.day_base_recycled)]
	office_title.text = Yard.AREA[model.phase]
	office_detail.text = detail.text
	if model.phase == Yard.BAG_UPGRADE_PHASE and model.can_upgrade_bag():
		detail.text = "按 Tab 打开站务终端，免费升级背包。"
	var incoming: Array = ["首批 %s 只" % comma(Yard.STARTER_SIZE),"街区散货 %s 只" % comma(Yard.STREET_SIZE),
		"一托盘 %s 只" % comma(Yard.PALLET_SIZE),"满载货车 %s 只" % comma(Yard.TRUCK_SIZE),
		"全天 %d 车 · %s 只" % [Yard.DAY_TRUCKS,comma(Yard.DAY_TRUCKS*Yard.TRUCK_SIZE)]]
	place_order.text = ("接货 · " + incoming[next]) if not model.day_active else "全天调度运行中"
	place_order.disabled = not model.can_receive()
	bag_upgrade.disabled = not model.can_upgrade_bag()
	bag_caption.text = "背包容量  %d 只" % model.bag_capacity()
	bag_caption.position.y = 21.0 if model.bag_upgraded else 6.0
	if model.bag_upgraded:
		bag_upgrade.text = "已升级"
		bag_details.text = ""
	elif bag_upgrade.disabled:
		bag_upgrade.text = "升级背包"
		bag_details.text = "街区散货到站后解锁"
	else:
		bag_upgrade.text = "免费升级背包"
		bag_details.text = "升级后可装 %d 只散瓶" % Yard.BAG_CAPACITY
	manifest.text = "累计入库  %s 只\n破损回收  %s 只" % [comma(model.received),comma(model.recycled)]
	if model.day_active:
		manifest.text = "当天到货  %d / %d 车\n当天出货  %s 只" % [model.trucks,Yard.DAY_TRUCKS,comma(model.delivered-model.day_base_delivered)]
	bulk_heading.visible = model.installed[0]
	for command in [feed,wash,sanitize,inspect]:
		command.visible = bulk_heading.visible
	feed.disabled = not model.installed[0] or model.sum_queue(Yard.RAW) == 0
	wash.disabled = not model.can_bulk_wash()
	sanitize.disabled = not model.installed[0] or model.sum_queue(Yard.WASHED) == 0
	inspect.disabled = not model.installed[0] or model.sum_queue(Yard.SANITIZED) == 0
	notice.text = status if status.length() <= 17 else status.substr(0,17)
	var descriptions: Array = ["滚筒稳瓶，刮刀去除纸标和塑膜","喷洗普通瓶与重污瓶","整筐识别瓶型与裂瓶","沥水与在线验瓶","自动送入待售区，可开启自动销售","刷洗、倾斜冲洗与换圈","扩容并自动调入 60 辆货车","清洗后进入封闭蒸汽仓"]
	equipment_notice.visible = not model.unlocked(0)
	for i in machine_buttons.size():
		var item: Button = machine_buttons[i]
		var unlocked: bool = model.unlocked(i)
		item.get_parent().visible = not equipment_notice.visible
		item.text = "运行中" if model.installed[i] else "¥ " + comma(Yard.COST[i]) if unlocked else "未解锁"
		item.disabled = model.installed[i] or model.credits < Yard.COST[i] or not unlocked
		machine_rows[i].text = descriptions[i] if unlocked or model.installed[i] else ["","先安装脱标机","小仓库解锁","小仓库解锁","小仓库解锁","小仓库解锁","城区回收站解锁","小仓库安装洗瓶机后解锁"][i]
	for i in amount.size():
		amount[i].text = comma(model.sum_queue(i)+model.bench_crate.size()) if i == Yard.CLEAN else comma(model.sum_queue(i))
	for i in sales_rows.size():
		sales_rows[i].text = comma(model.sold_by_type[i])
	speed.text = "运行速度  ×%d" % model.rush
	order_priority.select(model.priority+1)
	if market.is_visible_in_tree():
		update_market(model,status)
	if tool_shop.is_visible_in_tree():
		update_tool_shop(model,status)


func update_inventory(model) -> void:
	var mode: String = "小推车" if model.pushing_cart else "背包"
	var count: int = model.carry_count()
	var capacity: int = model.carry_capacity()
	carry_title.text = "%s  %d / %d" % [mode,count,capacity]
	var slot_step: float = minf(52.0,(CARRY_METER_WIDTH+4.0)/capacity)
	var fill: Color = ACCENT if count == capacity else GREEN
	for i in carry_slots.size():
		var slot: ColorRect = carry_slots[i]
		slot.visible = i < capacity
		if slot.visible:
			slot.position.x = 12.0 + i*slot_step
			slot.size.x = slot_step-4.0
			slot.color = fill if i < count else EMPTY_SLOT
	var amounts := PackedInt32Array()
	amounts.resize(Yard.NAMES.size())
	for item in model.carried:
		amounts[model.kind(item.x)] += 1
	if model.held >= 0:
		amounts[model.kind(model.held)] += 1
	var names := PackedStringArray()
	for kind in amounts.size():
		if amounts[kind] > 0:
			names.append("%s ×%d" % [Yard.NAMES[kind],amounts[kind]])
	carry_contents.text = " · ".join(names) if not names.is_empty() else "暂无散瓶"
	carry_secondary.text = ""
	if model.pushing_cart:
		carry_secondary.text = "成品筐 %d / %d   ·   C 停车" % [model.cart_crates.size(),Yard.CART_CRATE_LIMIT]
		if names.is_empty() and not model.cart_crates.is_empty():
			carry_contents.text = "%d 只成品待交付" % model.transport_finished_count()
	elif not model.hand_crate.is_empty():
		carry_secondary.text = "手提成品筐 · %d 只" % model.hand_crate.size()
		if names.is_empty():
			carry_contents.text = "出滑门右转去收购窗口"


func update_work(hand, is_working: bool, captured: bool, prompt: String, prompt_hint: String, info: String) -> void:
	var paperwork: bool = office.visible or journal.visible
	var scraping: bool = is_working and hand.task() == hand.SCRAPE_LABEL
	world_view.visible = not paperwork
	resumable.visible = not paperwork and not captured
	bottom.visible = is_working and captured
	reticle.visible = not is_working and captured
	target_card.visible = not paperwork and not is_working and captured and not prompt.is_empty()
	target_card.size.y = 36.0 if prompt_hint.is_empty() else 58.0
	target_label.text = prompt
	target_hint.text = prompt_hint
	target_hint.visible = not prompt_hint.is_empty()
	result.text = info
	result.visible = captured and not paperwork
	helper.text = ("右键转瓶    ·    左键操作    ·    Esc / S / R 离开操作台"
		if is_working else "WASD 移动    ·    E 交互    ·    Tab 站务    ·    Esc 释放鼠标")
	if scraping:
		helper.text = "按住右键向下刮    ·    按住左键转瓶    ·    Esc / S / R 离开操作台"
	if is_working and hand.held:
		work_name.text = Yard.NAMES[hand.type] + "  ·  " + Yard.CONDITION[hand.quality]
		work_percent.text = "脱标 %d%%" % floori(hand.progress*100.0) if scraping else ""
		progress.size.x = hand.progress * 544.0
		work_action.text = "E 投入碎玻璃桶" if hand.quality == 2 else "E 放进成品筐" if hand.done else hand.ACTIONS[hand.task()][0]
		work_prompt.text = "裂纹沿着瓶身延伸。" if hand.quality == 2 else "已清洗、消毒并沥干" if hand.done else hand.ACTIONS[hand.task()][1]
		if scraping:
			var pass_number: int = hand.scrape_pass if hand.scrape_between_passes else hand.scrape_pass+1
			work_action.text = "%s  ·  第 %d/%d 道" % [Yard.SCRAPERS[hand.scraper_level].name,pass_number,hand.scrape_passes]
			if not hand.edge_visible():
				work_prompt.text = "按住左键转瓶，让标签朝向刮刀"
			elif hand.scrape_between_passes:
				work_prompt.text = "还有残标。松开右键，再按住往下刮"
			elif hand.pressed:
				work_prompt.text = "保持右键，沿箭头慢慢往下拖" if hand.scrape_pressure >= .80 else "保持右键，等刀口贴住标签"
		elif hand.task() == "scrub" and hand.glue_cleanup:
			work_action.text = "用布擦掉残胶"
			work_prompt.text = "对准残胶，按住左键左右来回擦"
		if hand.cycle_running:
			work_prompt.text = "正在蒸汽消毒" if hand.task() == "sanitize" else "正在沥干，余水流入托盘"
	hand_active = is_working and hand.held and not hand.done and hand.quality < 2 and captured and not paperwork and hand.edge_visible()
	if hand_active:
		hand_cursor = hand.cursor
		hand_target = hand.hotspot()
		focused = hand_cursor.distance_to(hand_target) < hand.aim_radius()
		frozen = hand.pressed or hand.cycle_running
		scrape_guide = scraping and not hand.scrape_between_passes and not hand.rotating
	queue_redraw()


func _draw() -> void:
	if not hand_active:
		return
	var col: Color = Color("ffdda1") if focused else Color("ffffffad")
	if not frozen:
		draw_arc(hand_target,12.0,-PI*.80,PI*.48,16,Color("f6be84b0"),1.5,true)
	else:
		draw_circle(hand_target,2.2,Color("efb17d80"))
	if scrape_guide and focused:
		var tip: Vector2 = hand_target+Vector2(29,35)
		draw_polyline(PackedVector2Array([tip+Vector2(-5,-5),tip,tip+Vector2(5,-5)]),ACCENT,2.0,true)
		draw_line(tip-Vector2(0,23),tip,ACCENT,2.0,true)
	draw_circle(hand_cursor,5.4,Color("1a2c2b9c"))
	draw_circle(hand_cursor,2.7,col)
