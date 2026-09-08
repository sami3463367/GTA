extends RefCounted
## Shared furniture layout drives both art and collision. Local coordinates in a 270x260 room.
static func props(building_id: int) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	if building_id == 24:
		items = [
			{"art":"counter","rect":Rect2(27,35,190,42),"solid":true},
			{"art":"table","rect":Rect2(40,130,48,44),"solid":true},
			{"art":"table","rect":Rect2(166,130,48,44),"solid":true},
			{"art":"chair","rect":Rect2(50,111,26,25),"solid":true},
			{"art":"chair","rect":Rect2(50,175,26,25),"solid":true},
			{"art":"chair","rect":Rect2(177,111,26,25),"solid":true},
			{"art":"chair","rect":Rect2(177,175,26,25),"solid":true},
			{"art":"vending","rect":Rect2(219,35,33,59),"solid":true},
			{"art":"plant","rect":Rect2(19,198,26,36),"solid":true}]
	elif building_id == 12:
		items = [
			{"art":"rug","rect":Rect2(56,96,156,106),"solid":false},
			{"art":"desk","rect":Rect2(130,32,99,52),"solid":true},
			{"art":"sofa","rect":Rect2(26,116,72,36),"solid":true},
			{"art":"sofa","rect":Rect2(166,168,72,36),"solid":true},
			{"art":"table","rect":Rect2(113,129,45,40),"solid":true},
			{"art":"vending","rect":Rect2(215,101,32,52),"solid":true},
			{"art":"plant","rect":Rect2(28,43,30,40),"solid":true}]
	else:
		items = [
			{"art":"rug","rect":Rect2(28,127,152,94),"solid":false},
			{"art":"desk","rect":Rect2(138,40,104,57),"solid":true},
			{"art":"sofa","rect":Rect2(34,136,94,44),"solid":true},
			{"art":"counter","rect":Rect2(21,31,94,37),"solid":true},
			{"art":"plant","rect":Rect2(214,196,28,37),"solid":true}]
	return items

static func blockers(building_id: int) -> Array[Rect2]:
	var result: Array[Rect2] = []
	for prop in props(building_id):
		if prop.solid:
			# Match footprint, not the upright sprite's full visual height.
			var r: Rect2 = prop.rect
			result.append(Rect2(r.position + Vector2(3, r.size.y * 0.35), Vector2(r.size.x - 6, r.size.y * 0.65)))
	if building_id != 24:
		result.append(Rect2(20,90,75,8))
	return result
