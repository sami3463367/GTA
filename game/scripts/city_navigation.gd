extends RefCounted
## Explicit sidewalk graph, not random obstacle sliding. Edges cross at street corners.
const World = preload("res://scripts/world_data.gd")
var graph := AStar2D.new()
var nodes: Array[Vector2] = []
var blocks: Array[Dictionary]

func _init(city: Array[Dictionary]) -> void:
	blocks = city
	var xs: Array[float] = []
	var ys: Array[float] = []
	for i in range(7):
		for side in [-48,48]:
			var v := float(80 + i * 420 + side)
			if v < 2220:
				xs.append(v)
			if v < 2580:
				ys.append(v)
	xs.sort()
	ys.sort()
	var lookup := {}
	for y in range(ys.size()):
		for x in range(xs.size()):
			var p := Vector2(xs[x],ys[y])
			if World.can_move(p,"foot",blocks):
				var id := nodes.size()
				nodes.append(p)
				graph.add_point(id,p)
				lookup[Vector2i(x,y)] = id
	for cell in lookup:
		for offset in [Vector2i.RIGHT,Vector2i.DOWN]:
			var neighbor: Vector2i = cell + offset
			if lookup.has(neighbor):
				graph.connect_points(lookup[cell],lookup[neighbor])

func path(from: Vector2, to: Vector2) -> PackedVector2Array:
	if nodes.is_empty():
		return PackedVector2Array()
	return graph.get_point_path(graph.get_closest_point(from),graph.get_closest_point(to))

func line_clear(from: Vector2,to: Vector2) -> bool:
	var bounds := Rect2(from,Vector2.ZERO).expand(to).grow(0.1)
	for block in blocks:
		var r: Rect2 = block.rect
		if not r.intersects(bounds):
			continue
		if r.has_point(from) or r.has_point(to):
			return false
		var corners := [r.position,r.position+Vector2(r.size.x,0),r.end,r.position+Vector2(0,r.size.y)]
		for i in range(4):
			if Geometry2D.segment_intersects_segment(from,to,corners[i],corners[(i+1)%4]) != null:
				return false
	return true

func cover(from: Vector2, threat: Vector2) -> Vector2:
	var best := from
	var score := INF
	for p in nodes:
		var distance := p.distance_to(threat)
		if distance > 110 and distance < 360 and not line_clear(p,threat):
			var candidate := p.distance_to(from)
			if candidate < score:
				score = candidate
				best = p
	return best
