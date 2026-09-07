extends RefCounted
## Deterministic city geometry, shared by gameplay and headless tests.
const SIZE := Vector2(3000, 2600)
const COAST := 2240.0
const START := Vector2(2080, 2180)
const PARK := Vector2(1530, 1580)
const SAVE_PATH := "user://story_v1.json"

static func buildings() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var names := ["VERDE RESIDENCES", "OCEANIC BANK", "SOLAR STUDIOS", "THE ARCADE", "HARBOR HOUSE", "MESA HOTEL", "AZURE GALLERY", "PALM MARKET", "CIVIC HALL", "NORTHSTAR", "LUNA LOUNGE", "COAST CLINIC"]
	for row in range(6):
		for col in range(5):
			var id := row * 5 + col
			if id == 18 or id == 23:
				continue
			var pos := Vector2(140 + col * 420, 140 + row * 420)
			var title: String = names[id % names.size()]
			if id == 24:
				title = "MARA'S CAFE"
			if id == 12:
				title = "MERIDIAN HOTEL"
			result.append({"id": id, "rect": Rect2(pos, Vector2(270, 260)), "name": title,
				"door": pos + Vector2(135, 282), "interior": id in [7, 12, 24], "helipad": id == 12})
	return result

static func missions() -> Array[Dictionary]:
	return [
		{"title": "A favor for an old friend", "text": "Meet Mara inside the marina cafe. Follow the gold marker.", "point": Vector2(1955, 2102), "reward": 250},
		{"title": "The waterfront delivery", "text": "Borrow a car. Bring Mara's delivery to Palm Market's loading zone.", "point": Vector2(1040, 920), "reward": 450},
		{"title": "A different perspective", "text": "Take the helicopter from Sunset Park. LAND on Meridian Hotel's rooftop H.", "point": Vector2(1115, 1110), "reward": 700},
		{"title": "Beyond the breakwater", "text": "Board the marina speedboat. Reach the buoy beyond the breakwater.", "point": Vector2(2750, 580), "reward": 900},
		{"title": "The city is yours", "text": "Free roam unlocked. Explore interiors, rooftops and the coast. More chapters to come.", "point": START, "reward": 0}
	]

static func is_water(p: Vector2) -> bool:
	return p.x > COAST and not Rect2(2240, 2060, 240, 80).has_point(p)

static func can_move(p: Vector2, kind: String, blocks: Array[Dictionary]) -> bool:
	if not Rect2(Vector2(20, 20), SIZE - Vector2(40, 40)).has_point(p):
		return false
	if kind == "helicopter":
		return true
	if kind == "boat":
		return p.x > COAST + 25 and is_water(p)
	if is_water(p):
		return false
	var radius := 18.0 if kind == "car" else 9.0
	for block in blocks:
		var bounds: Rect2 = block.rect
		if bounds.grow(radius).has_point(p):
			return false
	return true

static func vehicles() -> Array[Dictionary]:
	var result: Array[Dictionary] = [
		{"kind": "car", "pos": Vector2(2100, 2180), "angle": -PI / 2, "color": Color("e8bc62"), "flying": false},
		{"kind": "helicopter", "pos": PARK, "angle": -PI / 2, "color": Color("e3e9cf"), "flying": false},
		{"kind": "boat", "pos": Vector2(2430, 2190), "angle": -PI / 2, "color": Color("f1efdb"), "flying": false}
	]
	for i in range(16):
		var vertical := i % 2 == 0
		var p := Vector2(500 + 420 * (i % 4), 280 + (i % 5) * 390) if vertical else Vector2(280 + (i % 5) * 350, 500 + 420 * (i % 5))
		result.append({"kind": "car", "pos": p, "angle": PI / 2 if vertical else 0.0, "color": [Color("abc8c3"), Color("d47a60"), Color("cfbd97"), Color("668291")][i % 4], "flying": false})
	return result
