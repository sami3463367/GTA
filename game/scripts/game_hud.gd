extends Node2D
## Godot-native touch controls and HUD; rendered at a 1280 x 720 design size.
var game: Node2D
var font: Font = ThemeDB.fallback_font
var controls: Array[Button] = []
var menu_controls: Array[Button] = []
var joystick_id := -1
var fire_touch_id := -1
var joystick_center := Vector2(108, 601)
var reset_pending := false
var pause_button: Button
var sound_button: Button
var graphics_button: Button

func panel(rect: Rect2, color := "122a32ee", border := "ffffff20", radius := 8) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color)
	style.border_color = Color(border)
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	draw_style_box(style, rect)

func text(value: String, at: Vector2, size := 14, color := "eff1df") -> void:
	draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(color))

func paragraph(value: String, at: Vector2, width: float, size := 14, color := "b2c4c3", spacing := 22.0) -> void:
	var line := ""
	var y := at.y
	for word in value.split(" "):
		if font.get_string_size(line + word, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and not line.is_empty():
			text(line, Vector2(at.x, y), size, color)
			y += spacing
			line = ""
		line += word + " "
	text(line, Vector2(at.x, y), size, color)

func button(value: String, rect: Rect2, callback: Callable, primary := false) -> Button:
	var b := Button.new()
	b.text = value
	b.position = rect.position
	b.size = rect.size
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_color_override("font_color", Color("213a32") if primary else Color("e6ead7"))
	var style := StyleBoxFlat.new()
	style.bg_color = Color("dcee9d") if primary else Color("18343cef")
	style.border_color = Color("d7e7c870")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	b.add_theme_stylebox_override("normal", style)
	var hover: StyleBoxFlat = style.duplicate()
	hover.bg_color = style.bg_color.lightened(0.12)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.pressed.connect(callback)
	b.focus_mode = Control.FOCUS_NONE
	add_child(b)
	return b

func _ready() -> void:
	pause_button = button("II", Rect2(1210, 24, 44, 42), func(): game.toggle_pause())
	controls.append(button("USE", Rect2(1154, 542, 95, 66), func(): game.interact(), true))
	controls.append(button("LAND", Rect2(1048, 620, 95, 66), func(): game.land()))
	controls.append(button("RUN", Rect2(1154, 620, 95, 66), func(): game.sprint = not game.sprint))
	var fire := button("FIRE", Rect2(1048, 542, 95, 66), func(): pass)
	fire.button_down.connect(func(): game.fire_held = true; game.shoot())
	fire.button_up.connect(func(): game.fire_held = false)
	controls.append(fire)
	menu_controls.append(button("ENTER AZURE HARBOR   >", Rect2(83, 427, 355, 59), func(): game.paused = false; reset_pending = false, true))
	menu_controls.append(button("NEW STORY", Rect2(83, 501, 170, 45), func():
		if reset_pending:
			game.reset_story()
			game.paused = false
			reset_pending = false
		else:
			reset_pending = true
	))
	sound_button = button("SOUND: ON", Rect2(268, 501, 170, 45), func(): game.sound_enabled = not game.sound_enabled; game.save_game())
	menu_controls.append(sound_button)
	graphics_button = button("GFX: HIGH", Rect2(453, 501, 78, 45), func(): game.graphics_high = not game.graphics_high; game.save_game())
	graphics_button.add_theme_font_size_override("font_size", 11)
	menu_controls.append(graphics_button)

func _process(_delta: float) -> void:
	scale = get_viewport_rect().size / Vector2(1280, 720)
	for b in controls:
		b.visible = not game.paused
	for b in menu_controls:
		b.visible = game.paused
	pause_button.visible = not game.paused
	sound_button.text = "SOUND: ON" if game.sound_enabled else "SOUND: OFF"
	graphics_button.text = "GFX: HIGH" if game.graphics_high else "GFX: LITE"
	menu_controls[0].text = "RESUME YOUR STORY   >" if game.clock > 1 else "ENTER AZURE HARBOR   >"
	menu_controls[1].text = "CONFIRM RESET" if reset_pending else "NEW STORY"
	if game.paused:
		fire_touch_id = -1
		joystick_id = -1
		game.stick = Vector2.ZERO

func _input(event: InputEvent) -> void:
	# Handle each real touch independently: steering and firing must work together.
	# Mouse emulation is disabled in project settings to avoid duplicate actions.
	if event is InputEventScreenTouch:
		if not event.pressed and event.index == fire_touch_id:
			fire_touch_id = -1
			game.fire_held = false
		if event.pressed:
			var active_buttons: Array[Button] = []
			active_buttons.assign(menu_controls if game.paused else controls)
			if not game.paused:
				active_buttons.append(pause_button)
			var point: Vector2 = event.position / scale
			for b in active_buttons:
				if Rect2(b.position, b.size).has_point(point):
					if b.text == "FIRE":
						fire_touch_id = event.index
						game.fire_held = true
						game.shoot()
					else:
						b.pressed.emit()
					get_viewport().set_input_as_handled()
					return
	if game.paused:
		return
	if event is InputEventScreenTouch:
		var point: Vector2 = event.position / scale
		if event.pressed and point.distance_to(joystick_center) < 85 and joystick_id < 0:
			joystick_id = event.index
			game.stick = ((point - joystick_center) / 48).limit_length()
		elif not event.pressed and event.index == joystick_id:
			joystick_id = -1
			game.stick = Vector2.ZERO
	if event is InputEventScreenDrag and event.index == joystick_id:
		game.stick = ((event.position / scale - joystick_center) / 48).limit_length()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var point: Vector2 = event.position / scale
		if event.pressed and point.distance_to(joystick_center) < 85:
			joystick_id = -2
		elif not event.pressed and joystick_id == -2:
			joystick_id = -1
			game.stick = Vector2.ZERO
	if event is InputEventMouseMotion and joystick_id == -2:
		game.stick = ((event.position / scale - joystick_center) / 48).limit_length()

func _draw() -> void:
	if game.paused:
		draw_menu()
		return
	text("AH /", Vector2(27, 56), 34, "eef0df")
	text("AZURE HARBOR", Vector2(124, 43), 16)
	text("AN OPEN CITY STORY", Vector2(125, 61), 10, "b2c9c4")
	panel(Rect2(27, 88, 257, 114))
	draw_circle(Vector2(45, 108), 3, Color("dcee9d"))
	var district := "MARINA DISTRICT"
	if game.player.x > 2240:
		district = "AZURE BAY"
	elif game.player.y < 950:
		district = "OLD TOWN"
	elif game.player.y < 1800:
		district = "MIDTOWN"
	if game.room >= 0:
		district = game.blocks[game.room].name
	text(district, Vector2(57, 113), 12)
	var mode := "ON FOOT"
	if game.boarded >= 0:
		mode = game.fleet[game.boarded].kind.to_upper()
	elif game.rooftop >= 0:
		mode = "ROOFTOP"
	elif game.room >= 0:
		mode = "INDOORS"
	text(mode + "  /  $%d" % game.cash, Vector2(45, 140), 11, "aac2bc")
	draw_line(Vector2(44, 153), Vector2(266, 153), Color("ffffff20"))
	text("HEALTH", Vector2(44, 180), 10, "a2bab4")
	draw_rect(Rect2(94, 171, 76, 5), Color("ffffff22"))
	draw_rect(Rect2(94, 171, game.health / 100 * 76, 5), Color("dcee9d"))
	for i in range(5):
		draw_circle(Vector2(190 + i * 16, 174), 4, Color("e5c978") if i < ceili(game.wanted) else Color("7d89704a"))
	panel(Rect2(935, 88, 317, 180))
	draw_line(Vector2(945, 89), Vector2(1242, 89), Color("dcee9d"), 2)
	text("CHAPTER 01 / A FRESH START", Vector2(952, 114), 10, "b8c8b6")
	text(game.story[game.chapter].title, Vector2(952, 144), 18)
	paragraph(game.story[game.chapter].text, Vector2(952, 169), 280, 13, "adc1c0", 20)
	text("FREE ROAM" if game.chapter == 4 else "%d m" % int(game.player.distance_to(game.story[game.chapter].point)), Vector2(952, 250), 12, "dcee9d")
	text("+$%d" % game.story[game.chapter].reward, Vector2(1170, 250), 12, "c5d1bd")
	draw_minimap()
	draw_circle(joystick_center, 65, Color("16353d88"))
	draw_arc(joystick_center, 65, 0, TAU, 64, Color("d8e5c980"), 2, true)
	draw_circle(joystick_center + game.stick * 38, 26, Color("d9e5cd88"))
	text("MOVE", Vector2(87, 694), 10, "d7e1c9")
	if game.sprint:
		text("RUNNING", Vector2(1170, 614), 11, "e0ed9c")
	text("WASD Move   E Use   L Land   Space Fire   Shift Run   Esc Pause", Vector2(302, 699), 11, "c5d5c8")
	text("OFFLINE / LOCAL SAVE", Vector2(532, 28), 10, "d4e6b7")
	if game.notice_time > 0:
		panel(Rect2(310, 576, 660, 82), "112b34f2", "dcee9d66")
		paragraph(game.notice, Vector2(330, 603), 620, 15, "e5e9cc", 23)
	var prompt := ""
	if game.room >= 0:
		prompt = "USE / E: Leave building"
	elif game.rooftop >= 0 and game.boarded < 0:
		prompt = "USE near helicopter or elevator"
	elif game.boarded < 0 and game.nearest_vehicle() >= 0:
		prompt = "USE / E: Enter " + game.fleet[game.nearest_vehicle()].kind
	else:
		for block in game.blocks:
			if game.boarded < 0 and block.interior and game.player.distance_to(block.door) < 65:
				prompt = "USE / E: Enter " + block.name
	if not prompt.is_empty():
		panel(Rect2(420, 509, 440, 40), "122b34e8", "ffffff30")
		text(prompt, Vector2(439, 535), 14, "e4edb3")
	if game.chapter < 4 and game.room < 0:
		var delta: Vector2 = game.story[game.chapter].point - game.player
		if delta.length() > 290:
			var p := Vector2(640, 350) + delta.normalized() * 180
			var a := delta.angle()
			draw_colored_polygon(PackedVector2Array([p + Vector2(11, 0).rotated(a), p + Vector2(-7, -7).rotated(a), p + Vector2(-7, 7).rotated(a)]), Color("e8eeb0"))

func draw_minimap() -> void:
	panel(Rect2(27, 358, 185, 157), "142e37ef", "ffffff40")
	var origin := Vector2(34, 365)
	var ratio := Vector2(171.0 / 3000, 123.0 / 2600)
	draw_rect(Rect2(origin, Vector2(171, 123)), Color("275e6a"))
	draw_rect(Rect2(origin, Vector2(2240 * ratio.x, 123)), Color("86a089"))
	for x in range(80, 2240, 420):
		draw_rect(Rect2(origin + Vector2((x - 35) * ratio.x, 0), Vector2(70 * ratio.x, 123)), Color("435f62"))
	for y in range(80, 2600, 420):
		draw_rect(Rect2(origin + Vector2(0, (y - 35) * ratio.y), Vector2(2240 * ratio.x, 70 * ratio.y)), Color("435f62"))
	for block in game.blocks:
		draw_rect(Rect2(origin + block.rect.position * ratio, block.rect.size * ratio), Color("c4c5a9"))
	for v in game.fleet:
		if v.kind != "car":
			draw_circle(origin + v.pos * ratio, 2, Color("dae9a2"))
	if game.chapter < 4:
		draw_arc(origin + game.story[game.chapter].point * ratio, 5, 0, TAU, 20, Color("f1df90"), 2, true)
	var point: Vector2 = game.blocks[game.room].door if game.room >= 0 else game.player
	draw_circle(origin + point * ratio, 3, Color.WHITE)
	text("N ^", Vector2(37, 505), 10, "dcee9d")
	text("AZURE COAST", Vector2(99, 505), 10, "b1c7bd")

func draw_menu() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("0e202acb"))
	panel(Rect2(45, 42, 496, 627), "10252df5", "a8c6ac30", 14)
	text("AZURE HARBOR / ORIGINAL OPEN CITY", Vector2(83, 99), 12, "dcee9d")
	text("Every city has", Vector2(80, 187), 48)
	text("a second story.", Vector2(80, 245), 48, "dcee9d")
	paragraph("A new arrival. An old debt. A harbor full of possibilities. Make your way from waterfront streets to the gardens above the skyline.", Vector2(83, 289), 390, 16, "adc1c1", 25)
	text("01 EXPLORE   /   02 DRIVE   /   03 TAKE FLIGHT", Vector2(83, 390), 12, "d4dfc8")
	paragraph("Tap USE beside a vehicle or glowing doorway. Fly the helicopter with the joystick; LAND above the hotel's H. Rooftop lift: USE nearby.", Vector2(83, 580), 398, 13, "94b0ae", 20)
	text("OFFLINE NATIVE GAME / ANDROID 10+", Vector2(83, 646), 10, "d0dfae")
	text("AZURE", Vector2(832, 463), 69)
	text("HARBOR", Vector2(832, 529), 69, "dcee9d")
	text("THE COAST IS CALLING.", Vector2(838, 565), 14, "c8d8c5")
	text("COASTAL GRAPHICS UPDATE 0.3 / DEVELOPMENT BUILD", Vector2(794, 663), 10, "b9ccbd")
