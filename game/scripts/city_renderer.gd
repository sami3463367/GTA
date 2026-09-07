extends Node2D
## Procedural, resolution-independent original city art rendered by Godot.
const World = preload("res://scripts/world_data.gd")
const SURFACE_TEXTURES := {"a5b49e": "grass", "7d9f77": "grass", "8aab80": "grass", "ccd0ba": "paving", "c6c3a4": "paving", "4a6269": "asphalt", "b39c76": "wood", "c6b393": "wood"}
var game: Node2D
var font: Font = ThemeDB.fallback_font
var base := Transform2D.IDENTITY
var visible_area := Rect2()
var art: Dictionary = {}
var ocean: Polygon2D
var water_material: ShaderMaterial
var grading: ColorRect

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	for key in ["asphalt", "grass", "paving", "roof", "wood", "tiles", "palm", "coupe", "player", "npc0", "npc1", "npc2", "speedboat", "helicopter"]:
		art[key] = load("res://assets/art/%s.png" % key)
	ocean = Polygon2D.new()
	ocean.polygon = PackedVector2Array([Vector2(2240, 0), Vector2(3000, 0), Vector2(3000, 2600), Vector2(2240, 2600)])
	ocean.z_index = -1
	water_material = ShaderMaterial.new()
	water_material.shader = preload("res://shaders/coastal_water.gdshader")
	ocean.material = water_material
	add_child(ocean)
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	grading = ColorRect.new()
	grading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grade := ShaderMaterial.new()
	grade.shader = preload("res://shaders/coastal_grade.gdshader")
	grading.material = grade
	layer.add_child(grading)

func texture_box(key: String, p: Vector2, size: Vector2, tint := Color.WHITE) -> void:
	var area := Rect2(p, size).intersection(visible_area)
	if area.has_area():
		draw_texture_rect_region(art[key], area, Rect2(area.position * 2.0, area.size * 2.0), tint, false, false)

func projected_shadow(rect: Rect2, offset: Vector2, opacity := 0.22) -> void:
	# Layered projected silhouettes provide a cheap soft penumbra on mobile GLES.
	var passes := 4 if game.graphics_high else 1
	for i in range(passes):
		var r := rect.grow(float(i) * 1.5)
		var a := r.position
		var b := r.position + Vector2(r.size.x, 0)
		var c := r.end
		var d := r.position + Vector2(0, r.size.y)
		draw_colored_polygon(PackedVector2Array([a, b, b + offset, c + offset, d + offset, d]), Color(0.07, 0.13, 0.24, opacity / passes))


func box(p: Vector2, size: Vector2, color: String) -> void:
	if SURFACE_TEXTURES.has(color):
		texture_box(SURFACE_TEXTURES[color], p, size)
	else:
		draw_rect(Rect2(p, size), Color(color))

func label(value: String, p: Vector2, size := 12, color := "dce4d5") -> void:
	var w := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(font, p - Vector2(w / 2, 0), value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(color))

func _draw() -> void:
	var screen := get_viewport_rect().size
	var zoom: float = clampf(screen.x / 1150, 0.65, 1.6)
	if game.boarded >= 0 and game.fleet[game.boarded].kind == "helicopter" and game.fleet[game.boarded].flying:
		zoom *= 0.77
	if game.room >= 0:
		zoom = minf(screen.x / 790, screen.y / 570)
	base = Transform2D(0, Vector2.ONE * zoom, 0, screen / 2 - game.camera * zoom)
	draw_set_transform_matrix(base)
	ocean.transform = base
	ocean.visible = game.room < 0
	water_material.set_shader_parameter("game_time", game.clock)
	water_material.set_shader_parameter("high_quality", game.graphics_high)
	grading.size = screen
	grading.visible = game.graphics_high
	visible_area = Rect2(game.camera - screen / zoom / 2 - Vector2(100, 100), screen / zoom + Vector2(200, 200))
	if game.room >= 0:
		draw_room()
	else:
		draw_city()
	for shot in game.bullets:
		if shot.room == game.room and shot.roof == game.rooftop:
			draw_line(shot.pos - Vector2(0, 15), shot.pos - Vector2.from_angle(shot.angle) * 15 - Vector2(0, 15), Color("fff1a5"), 3, true)
	if game.gun_cooldown > 0.18:
		draw_circle(game.player - Vector2(0, 15) + Vector2.from_angle(game.heading) * 24, 7, Color("f5cb6b"))
	draw_set_transform_matrix(Transform2D.IDENTITY)

func draw_city() -> void:
	box(Vector2.ZERO, Vector2(World.COAST, 2600), "a5b49e")
	for x in range(80, 2240, 420):
		box(Vector2(x - 50, 0), Vector2(100, 2600), "ccd0ba")
		box(Vector2(x - 36, 0), Vector2(72, 2600), "4a6269")
		draw_dashed_line(Vector2(x, 0), Vector2(x, 2600), Color("c9c8a890"), 2, 22)
	for y in range(80, 2600, 420):
		box(Vector2(0, y - 50), Vector2(2240, 100), "ccd0ba")
		box(Vector2(0, y - 36), Vector2(2240, 72), "4a6269")
		draw_dashed_line(Vector2(0, y), Vector2(2240, y), Color("c9c8a890"), 2, 22)
		for x in range(80, 2240, 420):
			box(Vector2(x - 36, y - 36), Vector2(72, 72), "4a6269")
			for i in range(-25, 30, 9):
				box(Vector2(x + i, y + 40), Vector2(5, 18), "e6e4cf")
				box(Vector2(x + 40, y + i), Vector2(18, 5), "e6e4cf")
			draw_circle(Vector2(x - 44, y - 44), 4, Color("e5edbb"))
	box(Vector2(2230, 0), Vector2(16, 2600), "ddcfaa")
	box(Vector2(2246, 0), Vector2(5, 2600), "4a7275")
	box(Vector2(2240, 2060), Vector2(240, 80), "b39c76")
	for x in range(2240, 2480, 12):
		draw_line(Vector2(x, 2060), Vector2(x, 2140), Color("8d7b60"))
	for x in range(2270, 2480, 65):
		draw_circle(Vector2(x, 2065), 4, Color("4a6059"))
		draw_circle(Vector2(x, 2135), 4, Color("4a6059"))
	box(Vector2(2240, 2060), Vector2(240, 4), "e1d5b2")
	box(Vector2(2240, 2136), Vector2(240, 4), "e1d5b2")
	draw_park()
	for block in game.blocks:
		if visible_area.intersects(block.rect.grow(90)):
			projected_shadow(block.rect, Vector2(40, 57) + Vector2(0, block.id % 3 * 8), 0.27)
	for block in game.blocks:
		if visible_area.intersects(block.rect):
			draw_building(block)
	for y in range(140, 2550, 110):
		palm(Vector2(2210, y), 0.72)
		for x in range(115, 2100, 420):
			palm(Vector2(x, y), 0.65)
	for y in range(170, 2600, 150):
		box(Vector2(2130, y), Vector2(8, 30), "998266")
		box(Vector2(2141, y), Vector2(3, 30), "d8c49c")
		draw_circle(Vector2(2221, y + 35), 4, Color("eff0c7"))
	label("A Z U R E   B A Y", Vector2(2660, 1500), 25, "97c5bd")
	label("MARINA WALK", Vector2(2350, 2038), 12, "e9dfbf")
	for i in range(game.fleet.size()):
		if i != game.boarded:
			draw_vehicle(game.fleet[i])
	for npc in game.people:
		if npc.alive:
			draw_person(npc.pos, npc.angle, npc.color, false)
	if game.wanted >= 1:
		draw_vehicle(game.police)
	if game.boarded >= 0:
		draw_vehicle(game.fleet[game.boarded])
	else:
		draw_person(game.player, game.heading, Color("e9dcba"), true)
	if game.chapter < 4:
		var target: Vector2 = game.story[game.chapter].point
		draw_circle(target, 26 + sin(game.clock * 3) * 3, Color("dcee9d35"))
		draw_arc(target, 23, 0, TAU, 40, Color("e7edac"), 2, true)
		draw_colored_polygon(PackedVector2Array([target + Vector2(0, -9), target + Vector2(9, 0), target + Vector2(0, 9), target + Vector2(-9, 0)]), Color("edf0b8"))
		label("ROOFTOP LANDING" if game.chapter == 2 else "OBJECTIVE", target + Vector2(0, -34), 10, "f0efc2")
	if game.chapter == 2:
		label("HELICOPTER", World.PARK + Vector2(0, -100), 12, "f1e9bb")
	draw_circle(Vector2(2750, 580), 11, Color("e6c17d"))
	draw_line(Vector2(2750, 580), Vector2(2750, 542), Color("eddbad"), 3)
	box(Vector2(2750, 542), Vector2(22, 13), "dc8863")

func draw_park() -> void:
	box(Vector2(1395, 1395), Vector2(315, 725), "7d9f77")
	box(Vector2(1420, 1420), Vector2(265, 675), "8aab80")
	box(Vector2(1510, 1400), Vector2(30, 710), "c6c3a4")
	box(Vector2(1400, 1760), Vector2(310, 28), "c6c3a4")
	draw_circle(World.PARK, 77, Color("899c80"))
	draw_arc(World.PARK, 61, 0, TAU, 64, Color("e5dfb6"), 3, true)
	label("H", World.PARK + Vector2(0, 20), 56, "eee7bd")
	label("SUNSET PARK", Vector2(1530, 1725), 13, "3d6656")
	for radius in [61, 49, 32, 12]:
		draw_circle(Vector2(1540, 1960), radius, [Color("ccc9ad"), Color("609c9e"), Color("8cc0b4"), Color("d6dfc6")][[61, 49, 32, 12].find(radius)])
	for y in range(1440, 2090, 110):
		palm(Vector2(1440, y))
		palm(Vector2(1650, y))
		box(Vector2(1467, y), Vector2(12, 36), "c8b68d")

func palm(p: Vector2, size := 1.0) -> void:
	if not visible_area.has_point(p):
		return
	var extent := Vector2(91, 91) * size
	var sway: float = sin(game.clock * 1.4 + p.x * 0.012) * 0.035 if game.graphics_high else 0.0
	# Ground projection and trunk stay fixed; only the leafy canopy sways.
	draw_texture_rect(art["palm"], Rect2(p - extent / 2 + Vector2(16, 24) * size, extent), false, Color(0.06, 0.12, 0.23, 0.22))
	draw_line(p + Vector2(3, 9), p + Vector2(0, -12), Color("765636"), 6 * size, true)
	draw_line(p + Vector2(1, 8), p + Vector2(-2, -12), Color("c39b61"), 2 * size, true)
	draw_set_transform_matrix(base * Transform2D(sway, p + Vector2(0, -12)))
	draw_texture_rect(art["palm"], Rect2(-extent / 2, extent), false)
	draw_set_transform_matrix(base)

func planter(p: Vector2) -> void:
	box(p - Vector2(20, 10), Vector2(40, 20), "d9cfb1")
	box(p - Vector2(17, 7), Vector2(34, 14), "4c6d53")
	for i in range(4):
		draw_circle(p + Vector2(-12 + i * 8, 0), 6, Color("65a747"))

	for i in range(5):
		var bloom := p + Vector2(-13 + i * 6, sin(float(i) * 4 + p.x) * 5)
		draw_circle(bloom + Vector2(1, 1), 3, Color("365132"))
		draw_circle(bloom, 2.4, [Color("f95d85"), Color("ffd361"), Color("c18af0")][i % 3])

func draw_building(b: Dictionary) -> void:
	var p: Vector2 = b.rect.position
	var size: Vector2 = b.rect.size
	var color: String = ["e7b383", "71bba9", "e48f78", "81afd0"][b.id % 4]
	box(p + Vector2(17, 22), size, "17303844")
	box(p - Vector2(5, 5), size + Vector2(10, 15), "9aa79b")
	box(p + Vector2(0, 12), size, color)
	for x in range(12, 260, 27):
		box(p + Vector2(x, 261), Vector2(15, 7), "506b73")
	box(p, size - Vector2(0, 8), "e2d8c2")
	box(p + Vector2(9, 9), size - Vector2(18, 27), color)
	box(p + Vector2(17, 17), size - Vector2(34, 43), "778e87")
	texture_box("tiles" if b.id % 4 == 3 and not b.helipad else "roof", p + Vector2(22, 22), size - Vector2(44, 53))
	# Ambient contact shading at the parapet, crisp sun-facing top and left edges.
	for inset in range(4):
		draw_rect(Rect2(p + Vector2(19 + inset, 19 + inset), size - Vector2(38 + inset * 2, 47 + inset * 2)), Color(0.14, 0.19, 0.25, 0.13 - inset * 0.025), false, 2)
	draw_line(p, p + Vector2(size.x, 0), Color("fff0ce"), 3, true)
	draw_line(p, p + Vector2(0, size.y - 8), Color("fff0ce"), 2, true)
	if b.helipad:
		draw_circle(p + Vector2(135, 130), 79, Color("526f6b"))
		draw_arc(p + Vector2(135, 130), 66, 0, TAU, 64, Color("dae0ae"), 3, true)
		label("H", p + Vector2(135, 153), 64, "e7e8be")
		box(p + Vector2(20, 20), Vector2(32, 38), "dbd2b7")
		label("LIFT", p + Vector2(36, 44), 10, "425f59")
		for y in [85, 195]:
			planter(p + Vector2(225, y))
		for y in [100, 140, 180]:
			box(p + Vector2(20, y), Vector2(23, 28), "e4d7b4")
			box(p + Vector2(23, y + 3), Vector2(17, 7), "92af9a")
		label("MERIDIAN SKY GARDEN", p + Vector2(135, 229), 10, "e8e5c7")
	elif b.id % 5 == 0:
		box(p + Vector2(47, 50), Vector2(170, 100), "e0d7b9")
		box(p + Vector2(54, 57), Vector2(156, 86), "21abbd")
		for y in range(64, 140, 15):
			draw_line(p + Vector2(58, y), p + Vector2(206, y), Color("bafae29a"), 2)
		for i in range(8):
			var pool_y: float = 65 + i * 9
			for j in range(6):
				var pool_x: float = 62 + j * 24
				draw_arc(p + Vector2(pool_x, pool_y), 9 + sin(game.clock + i) * 2, 0.1, 2.6, 8, Color("c2fce76b"), 1, true)
		for x in [65, 110, 155, 200]:
			box(p + Vector2(x, 170), Vector2(19, 32), "e5d5b0")
			box(p + Vector2(x + 2, 172), Vector2(15, 8), "bc9875")
		planter(p + Vector2(60, 220))
		planter(p + Vector2(209, 220))
	else:
		box(p + Vector2(30, 32), Vector2(68, 46), "b9c2b2")
		box(p + Vector2(34, 36), Vector2(60, 38), "677e77")
		for x in [49, 78]:
			draw_circle(p + Vector2(x, 55), 12, Color("506b69"))
			draw_circle(p + Vector2(x, 55), 7, Color("889e92"))
		box(p + Vector2(130, 35), Vector2(95, 48), "506e7d")
		for x in range(131, 225, 24):
			draw_line(p + Vector2(x, 35), p + Vector2(x, 83), Color("9cb7bb"))
		draw_line(p + Vector2(130, 59), p + Vector2(225, 59), Color("9cb7bb"))
		planter(p + Vector2(53, 202))
		planter(p + Vector2(214, 202))
		draw_circle(p + Vector2(145, 160), 23, Color("e5c99b"))
		draw_line(p + Vector2(122, 160), p + Vector2(168, 160), Color("c0a47b"))
		draw_line(p + Vector2(145, 137), p + Vector2(145, 183), Color("c0a47b"))
		for x in [112, 160]:
			box(p + Vector2(x, 187), Vector2(22, 10), "ddd6b9")
	box(p + Vector2(0, 252), Vector2(270, 18), color)
	for x in range(12, 265, 26):
		box(p + Vector2(x, 255), Vector2(16, 12), "354c64")
		box(p + Vector2(x + 2, 256), Vector2(12, 4), "86c9d2")
		draw_line(p + Vector2(x + 7, 255), p + Vector2(x + 7, 267), Color("e6d5b4"), 1)
	box(p + Vector2(40, 239), Vector2(190, 20), "304e51")
	label(b.name, p + Vector2(135, 253), 10, "e4dcc0")
	if b.interior:
		projected_shadow(Rect2(p + Vector2(102, 259), Vector2(66, 13)), Vector2(5, 8), 0.25)
		for i in range(6):
			box(p + Vector2(102 + i * 11, 259), Vector2(11, 13), "fff0cd" if i % 2 == 0 else "e76665")
		box(p + Vector2(106, 272), Vector2(58, 3), "563c4277")
		draw_circle(b.door, 14, Color("dceda13a"))
		label("E", b.door + Vector2(0, 5), 13, "edf0c1")

func draw_vehicle(v: Dictionary) -> void:
	if not visible_area.has_point(v.pos):
		return
	var transform := Transform2D(float(v.angle), Vector2(v.pos))
	draw_set_transform_matrix(base * transform)
	if v.kind == "car":
		draw_texture_rect(art["coupe"], Rect2(-28, -12, 66, 33), false, Color(0.05, 0.11, 0.19, 0.30))
		draw_texture_rect(art["coupe"], Rect2(-32, -16, 64, 32), false, v.color.lightened(0.12))
		if v.get("police", false):
			box(Vector2(-3, -10), Vector2(6, 10), "5b9fe0" if sin(game.clock * 12) > 0 else "b7c8ce")
			box(Vector2(-3, 0), Vector2(6, 10), "e5675c" if sin(game.clock * 12) < 0 else "b7c8ce")
	elif v.kind == "boat":
		if game.boarded >= 0 and game.fleet[game.boarded] == v and game.player_moving:
			draw_colored_polygon(PackedVector2Array([Vector2(-25, -12), Vector2(-90, -32), Vector2(-66, 0), Vector2(-90, 32), Vector2(-25, 12)]), Color("b7e6df66"))
		draw_texture_rect(art["speedboat"], Rect2(-46, -23, 92, 46), false)
	else:
		draw_texture_rect(art["helicopter"], Rect2(-65, -15, 119, 67), false, Color(0.03, 0.11, 0.20, 0.25))
		draw_texture_rect(art["helicopter"], Rect2(-82, -33.5, 119, 67), false)
		if v.flying:
			draw_circle(Vector2.ZERO, 59, Color("1d41491a"))
			draw_arc(Vector2.ZERO, 57, 0, TAU, 48, Color("a5c4ba25"), 3, true)
		var spin: float = game.clock * 28 if v.flying else 0.0
		draw_set_transform_matrix(base * transform * Transform2D(spin, Vector2.ZERO))
		box(Vector2(-59, -3), Vector2(118, 6), "2c4b4ccd")
		box(Vector2(-3, -59), Vector2(6, 118), "2c4b4ccd")
		draw_circle(Vector2.ZERO, 5, Color("e8e4be"))
	draw_set_transform_matrix(base)

func capsule(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(14)
	return style

func draw_person(p: Vector2, angle: float, color: Color, is_player: bool) -> void:
	if not visible_area.has_point(p):
		return
	# Upright eight-direction characters, feet anchored to gameplay/collision position.
	var direction := int(round(fposmod(angle, TAU) / (TAU / 8))) % 8
	var moving: bool = game.player_moving if is_player else not game.paused
	var frame := int(game.clock * (9 if is_player else 5)) % 4 if moving else 0
	var key := "player" if is_player else "npc%d" % (int(color.r * 255) % 3)
	draw_set_transform_matrix(base * Transform2D(0, Vector2(1.0, 0.43), 0, p + Vector2(6, 3)))
	draw_circle(Vector2.ZERO, 13, Color("152a4645"))
	draw_set_transform_matrix(base)
	draw_texture_rect_region(art[key], Rect2(p - Vector2(16, 36.5), Vector2(32, 40)), Rect2(frame * 128, direction * 160, 128, 160))
	if is_player:
		var hand := p + Vector2(0, -15)
		var muzzle := hand + Vector2.from_angle(angle) * 17
		draw_line(hand, muzzle, Color("202c3c"), 3, true)
		draw_line(hand + Vector2(-1, -1), muzzle + Vector2(-1, -1), Color("8b9ba4"), 1, true)

func draw_room() -> void:
	box(Vector2(-2000, -2000), Vector2(5000, 5000), "122b35")
	box(Vector2(43, 68), Vector2(620, 450), "203638")
	texture_box("wood", Vector2(50, 75), Vector2(600, 430), Color("edce9d"))
	for x in range(50, 650, 35):
		draw_line(Vector2(x, 75), Vector2(x, 505), Color("ad9a7d"))
	box(Vector2(50, 75), Vector2(600, 25), "e6d9be")
	box(Vector2(50, 75), Vector2(15, 430), "dcd0b5")
	box(Vector2(635, 75), Vector2(15, 430), "dcd0b5")
	for x in range(100, 620, 125):
		box(Vector2(x, 82), Vector2(80, 10), "55929a")
		box(Vector2(x, 99), Vector2(80, 4), "f1e7cd")
	label(game.blocks[game.room].name, Vector2(350, 135), 20, "426157")
	box(Vector2(100, 155), Vector2(500, 42), "596e5a")
	box(Vector2(105, 155), Vector2(490, 12), "e4cba0")
	for i in range(6):
		draw_circle(Vector2(130 + i * 80, 220), 11, Color("66856f"))
		box(Vector2(115 + i * 80, 169), Vector2(12, 12), "dce2c8")
	for x in [160, 330, 500]:
		for y in [300, 400]:
			draw_circle(Vector2(x, y), 29, Color("9b805d"))
			draw_circle(Vector2(x, y), 25, Color("e6cfa3"))
			draw_circle(Vector2(x, y - 40), 11, Color("62867a"))
			draw_circle(Vector2(x, y + 40), 11, Color("62867a"))
			draw_circle(Vector2(x, y), 6, Color("78945f"))
	planter(Vector2(85, 455))
	planter(Vector2(615, 455))
	box(Vector2(305, 489), Vector2(90, 16), "d9e7a0")
	label("EXIT / USE", Vector2(350, 482), 11, "476458")
	if game.blocks[game.room].helipad:
		label("ROOFTOP ELEVATOR / LAND", Vector2(350, 252), 12, "476458")
	draw_person(Vector2(350, 178), PI / 2, Color("b97155"), false)
	draw_person(game.player, game.heading, Color("e9dcba"), true)
