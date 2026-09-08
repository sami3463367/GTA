extends Node2D
## Asset-only world renderer. Terrain/floors are TileMapLayers; walls, roofs and props are sprites.
const World=preload("res://scripts/world_data.gd")
const Rooms=preload("res://scripts/interior_data.gd")
var game:Node2D
var art:Dictionary={}
var base:=Transform2D.IDENTITY
var world_root:Node2D
var terrain:TileMapLayer
var floor_layer:TileMapLayer
var floor_room:=-2
var roof_sprites:Array[Sprite2D]=[]
var inside_sprites:Array[Dictionary]=[]
var people_sprites:Array[Dictionary]=[]
var fleet_sprites:Array[Dictionary]=[]
var cast_sprites:Array[Dictionary]=[]
var player_visual:Dictionary
var ocean:Polygon2D
var water_material:ShaderMaterial
var grading:ColorRect
var ambient:CanvasModulate
var light_pool:Array[PointLight2D]=[]
var headlamps:Array[PointLight2D]=[]
var indoor_lights:Array[PointLight2D]=[]
var muzzle_light:PointLight2D
var muzzle_time:=0.0
var occluders:Array[LightOccluder2D]=[]
var street_lamps:Array[Vector2]=[]
var particles:Array[CPUParticles2D]=[]
var decal_visuals:Array[Sprite2D]=[]
var tiles:TileSet
var tile_ids:Dictionary={}
var font:Font=preload("res://assets/fonts/HarborSans.ttf")

func _ready() -> void:
	for key in preload("res://scripts/art_registry.gd").KEYS:
		art[key]=load("res://assets/art/"+key+".png")
	world_root=Node2D.new()
	add_child(world_root)
	ambient=CanvasModulate.new()
	add_child(ambient)
	build_tiles()
	build_environment()
	for i in range(game.people.size()):
		people_sprites.append(character_visual("npc%d"%(i%3)))
	for i in range(game.fleet.size()):
		var v:Dictionary=game.fleet[i]
		var key:String={"car":"coupe","boat":"speedboat","helicopter":"helicopter"}[v.kind]
		var shadow:=sprite(key,v.pos,Vector2.ONE*0.3)
		shadow.modulate=Color(0.02,0.04,0.10,0.5)
		var body:=sprite(key,v.pos,Vector2.ONE*0.3)
		body.z_index=2
		var rotor:Sprite2D=null
		if v.kind=="helicopter":
			rotor=sprite("rotor",v.pos,Vector2.ONE*0.48)
			rotor.z_index=5
		fleet_sprites.append({"body":body,"shadow":shadow,"rotor":rotor})
	for npc in game.cast:
		cast_sprites.append(character_visual("npc%d"%cast_sprites.size()))
	player_visual=character_visual("player")
	build_lighting()
	var grade_layer:=CanvasLayer.new()
	grade_layer.layer=1
	add_child(grade_layer)
	grading=ColorRect.new()
	grading.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var material:=ShaderMaterial.new()
	material.shader=preload("res://shaders/coastal_grade.gdshader")
	grading.material=material
	grade_layer.add_child(grading)
	sync_visuals(0)

func sprite(key:String,point:Vector2,scale_value:=Vector2.ONE,parent:Node=null) -> Sprite2D:
	var item:=Sprite2D.new()
	item.texture=art[key]
	item.position=point
	item.scale=scale_value
	item.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	(parent if parent!=null else world_root).add_child(item)
	return item

func placed(key:String,rect:Rect2,parent:Node=null) -> Sprite2D:
	var size:Vector2=art[key].get_size()
	return sprite(key,rect.get_center(),rect.size/size,parent)

func repeating(key:String,rect:Rect2,z:=-3) -> Sprite2D:
	var item:=sprite(key,rect.position)
	item.centered=false
	item.texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED
	item.region_enabled=true
	item.region_rect=Rect2(Vector2.ZERO,rect.size)
	item.z_index=z
	return item

func build_tiles() -> void:
	tiles=TileSet.new()
	tiles.tile_size=Vector2i(16,16)
	for key in ["grass","asphalt","paving","wood","floor_pattern","concrete"]:
		var source:=TileSetAtlasSource.new()
		source.texture=art[key]
		source.texture_region_size=Vector2i(16,16)
		for y in range(16):
			for x in range(16):
				source.create_tile(Vector2i(x,y))
		tile_ids[key]=tiles.add_source(source)
	terrain=TileMapLayer.new()
	terrain.name="TexturedCityTileMap"
	terrain.tile_set=tiles
	terrain.z_index=-8
	world_root.add_child(terrain)
	for y in range(163):
		for x in range(141):
			var point:=Vector2(x*16+8,y*16+8)
			if point.x>2240 or point.y>2600:
				continue
			var dx:=absf(fposmod(point.x-80+210,420)-210)
			var dy:=absf(fposmod(point.y-80+210,420)-210)
			var key:="asphalt" if minf(dx,dy)<36 else "paving" if minf(dx,dy)<53 else "grass"
			terrain.set_cell(Vector2i(x,y),tile_ids[key],Vector2i(x%16,y%16))
	floor_layer=TileMapLayer.new()
	floor_layer.name="InteriorFloorTileMap"
	floor_layer.tile_set=tiles
	floor_layer.z_index=-5
	world_root.add_child(floor_layer)

func build_environment() -> void:
	ocean=Polygon2D.new()
	ocean.polygon=PackedVector2Array([Vector2(2238,0),Vector2(3000,0),Vector2(3000,2600),Vector2(2238,2600)])
	ocean.z_index=-10
	water_material=ShaderMaterial.new()
	water_material.shader=preload("res://shaders/coastal_water.gdshader")
	ocean.material=water_material
	world_root.add_child(ocean)
	for x in range(80,2240,420):
		for side in [-43,39]:
			repeating("curb",Rect2(x+side,0,4,2600),-6)
		for y in range(0,2600,128):
			var lane:=placed("lane",Rect2(x-16,y,32,128))
			lane.rotation=PI/2
			lane.z_index=-5
	for y in range(80,2600,420):
		for side in [-43,39]:
			repeating("curb",Rect2(0,y+side,2240,4),-6)
		for x in range(0,2240,128):
			placed("lane",Rect2(x,y-16,128,32)).z_index=-5
		for x in range(80,2240,420):
			placed("crosswalk",Rect2(x-34,y+35,68,24)).z_index=-4
			var crossing:=placed("crosswalk",Rect2(x+25,y-34,68,24))
			crossing.rotation=PI/2
			crossing.z_index=-4
	for i in range(game.blocks.size()):
		var b:Dictionary=game.blocks[i]
		var p:Vector2=b.rect.position
		# Offset silhouettes underneath every building give height even with lighting off.
		var shadow:=placed("building_%d"%(b.id%4),Rect2(p+Vector2(25,36),Vector2(282,288)))
		shadow.modulate=Color(0.03,0.06,0.12,0.35)
		shadow.z_index=-2
		var roof:=placed("building_%d"%(b.id%4),Rect2(p,Vector2(270,280)))
		roof.name="OpaqueRoof_%d"%b.id
		roof.z_index=1
		roof_sprites.append(roof)
		# Child props follow roof opacity and never reveal the interior underneath.
		if b.helipad:
			placed("helipad",Rect2(Vector2(-87,-97),Vector2(174,174)),roof)
		var label:=Label.new()
		label.text=b.name
		label.position=Vector2(-122,97)
		label.size=Vector2(244,18)
		label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_override("font",font)
		label.add_theme_font_size_override("font_size",10)
		label.add_theme_color_override("font_color",Color("f2e9c5"))
		label.add_theme_color_override("font_shadow_color",Color("183442"))
		label.add_theme_constant_override("shadow_offset_x",1)
		label.add_theme_constant_override("shadow_offset_y",1)
		roof.add_child(label)
		if b.interior:
			var wall:=placed("wall_frame",b.rect)
			inside_sprites.append({"node":wall,"building":i})
			for prop in Rooms.props(b.id):
				var item:=placed("prop_"+prop.art,Rect2(p+prop.rect.position,prop.rect.size))
				inside_sprites.append({"node":item,"building":i})
			if b.id!=24:
				var divider:=placed("divider",Rect2(p+Vector2(20,90),Vector2(75,8)))
				inside_sprites.append({"node":divider,"building":i})
			for local in [Vector2(58,34),Vector2(204,34),Vector2(135,187)]:
				var lamp:=sprite("prop_lamp",p+local,Vector2.ONE*0.34)
				inside_sprites.append({"node":lamp,"building":i})
			# Soft window shafts are textured, not filled polygons.
			for wx in [60,132,210]:
				var shaft:=sprite("beam",p+Vector2(wx,53),Vector2(0.35,0.19))
				shaft.rotation=PI/2
				shaft.modulate=Color(1,0.86,0.62,0.24)
				inside_sprites.append({"node":shaft,"building":i})
	for x in range(115,2240,420):
		for y in range(140,2550,140):
			var point:=Vector2(x,y)
			var shadow:=sprite("palm",point+Vector2(14,19),Vector2.ONE*0.21)
			shadow.modulate=Color(0.03,0.06,0.1,0.28)
			shadow.z_index=-2
			sprite("palm",point-Vector2(0,10),Vector2.ONE*0.22).z_index=2
	for y in range(180,2500,250):
		for x in [122,2188]:
			var point:=Vector2(x,y)
			street_lamps.append(point)
			sprite("prop_lamp",point,Vector2.ONE*0.23).z_index=2
		placed("prop_bin",Rect2(2140,y+45,17,22))
	for y in [570,1410,2250]:
		placed("prop_busstop",Rect2(1850,y,95,42))
	for point in [Vector2(2150,2040),Vector2(1670,1390),Vector2(120,2280)]:
		placed("prop_barrier",Rect2(point,Vector2(70,19)))
	for point in [Vector2(2100,2170),Vector2(930,850),Vector2(504,780),Vector2(1350,2010)]:
		placed("oil",Rect2(point-Vector2(24,16),Vector2(60,36))).z_index=-4
	repeating("wood",Rect2(2240,2060,240,80),-4)
	repeating("curb",Rect2(2230,0,10,2600),-5)
	placed("helipad",Rect2(World.PARK-Vector2(65,65),Vector2(130,130))).z_index=-3
	for local in [Vector2(1440,1470),Vector2(1670,1590),Vector2(1450,1950)]:
		sprite("prop_plant",local,Vector2.ONE*0.6)

func character_visual(key:String) -> Dictionary:
	var shadow:=sprite("light",Vector2.ZERO,Vector2(0.115,0.045))
	shadow.modulate=Color(0.015,0.035,0.07,0.65)
	shadow.z_index=-1
	var body:=sprite(key,Vector2.ZERO,Vector2.ONE*0.25)
	body.centered=false
	body.offset=Vector2(-64,-146)
	body.region_enabled=true
	body.region_rect=Rect2(0,0,128,160)
	body.z_index=2
	return {"body":body,"shadow":shadow}

func set_character(visual:Dictionary,point:Vector2,angle:float,moving:bool,visible_value:bool,inside:=false) -> void:
	visual.body.visible=visible_value
	visual.shadow.visible=visible_value
	visual.body.position=point
	visual.shadow.position=point+Vector2(4,3)
	var direction:=int(round(fposmod(angle,TAU)/(TAU/8)))%8
	var frame:=int(game.clock*8)%4 if moving else 0
	visual.body.region_rect=Rect2(frame*128,direction*160,128,160)
	visual.body.z_index=0 if inside else 4

func make_light(texture:String,energy:float) -> PointLight2D:
	var light:=PointLight2D.new()
	light.texture=art[texture]
	light.energy=energy
	light.texture_scale=0.8
	light.height=25
	light.shadow_filter=Light2D.SHADOW_FILTER_PCF5
	world_root.add_child(light)
	return light

func build_lighting() -> void:
	for i in range(12):
		light_pool.append(make_light("light",1.0))
	for i in range(2):
		var light:=make_light("beam",1.3)
		light.offset=Vector2(100,0)
		headlamps.append(light)
	for i in range(3):
		var light:=make_light("light",1.1)
		light.color=Color("ffdcab")
		indoor_lights.append(light)
	muzzle_light=make_light("light",2.0)
	muzzle_light.color=Color("ffd68a")
	muzzle_light.texture_scale=0.35
	muzzle_light.visible=false
	for b in game.blocks:
		var shape:=OccluderPolygon2D.new()
		var r:Rect2=b.rect
		shape.polygon=PackedVector2Array([r.position,r.position+Vector2(r.size.x,0),r.end,r.position+Vector2(0,r.size.y)])
		var occluder:=LightOccluder2D.new()
		occluder.occluder=shape
		world_root.add_child(occluder)
		occluders.append(occluder)

func update_lights() -> void:
	var daylight:=clampf((cos(game.clock/180.0*TAU)+1.0)/2.0,0,1)
	ambient.color=Color("263952").lerp(Color("f8efd8"),daylight)
	if game.room>=0:
		ambient.color=Color("6a6868")
	water_material.set_shader_parameter("ambient_level",lerpf(0.24,1.0,daylight))
	var nearby:Array[Vector2]=[]
	for p in street_lamps:
		if p.distance_to(game.camera)<650:
			nearby.append(p)
	nearby.sort_custom(func(a:Vector2,b:Vector2):return a.distance_squared_to(game.camera)<b.distance_squared_to(game.camera))
	for i in range(light_pool.size()):
		var light:=light_pool[i]
		light.visible=i<nearby.size() and game.room<0 and daylight<0.7
		if light.visible:
			light.position=nearby[i]
			light.energy=lerpf(1.25,0.35,daylight)
			light.shadow_enabled=game.graphics_high and i<4
	for i in range(indoor_lights.size()):
		var light:=indoor_lights[i]
		light.visible=game.room>=0
		if light.visible:
			light.position=game.blocks[game.room].rect.position+[Vector2(58,46),Vector2(204,46),Vector2(135,185)][i]
			light.energy=1.0
	for i in range(headlamps.size()):
		var light:=headlamps[i]
		light.visible=game.boarded>=0 and game.fleet[game.boarded].kind=="car" and game.room<0
		if light.visible:
			light.position=game.player+Vector2(26,-8 if i==0 else 8).rotated(game.heading)
			light.rotation=game.heading
			light.energy=0.65 if daylight>0.7 else 1.4
			light.shadow_enabled=game.graphics_high
	for i in range(occluders.size()):
		occluders[i].visible=game.room!=i

func emit_particle(event:Dictionary) -> void:
	var kind:String=event.kind
	var effect:=CPUParticles2D.new()
	effect.texture=art[kind]
	effect.position=event.pos
	effect.local_coords=true
	effect.one_shot=true
	effect.amount=1 if kind=="ripple" else 8
	effect.explosiveness=1.0
	effect.lifetime=1.1 if kind in ["smoke","ripple"] else 0.28
	effect.direction=Vector2.from_angle(event.angle)
	effect.spread=30
	effect.gravity=Vector2.ZERO
	effect.initial_velocity_min=8 if kind in ["smoke","ripple"] else 35
	effect.initial_velocity_max=24 if kind in ["smoke","ripple"] else 100
	effect.scale_amount_min=0.07 if kind=="spark" else 0.12
	effect.scale_amount_max=0.13 if kind=="spark" else 0.25
	var scale_curve:=Curve.new()
	scale_curve.add_point(Vector2(0,0.3))
	scale_curve.add_point(Vector2(1,1.8 if kind=="ripple" else 1.0))
	effect.scale_amount_curve=scale_curve
	var ramp:=Gradient.new()
	ramp.set_color(0,Color(1,1,1,0.8))
	ramp.set_color(1,Color(1,1,1,0))
	effect.color_ramp=ramp
	effect.z_index=0 if event.room>=0 else 3
	effect.set_meta("room",event.room)
	world_root.add_child(effect)
	particles.append(effect)
	effect.finished.connect(func():particles.erase(effect);effect.queue_free())
	effect.emitting=true
	if kind=="spark":
		muzzle_light.position=event.pos
		muzzle_light.visible=true
		muzzle_time=0.08

func sync_visuals(dt:float) -> void:
	if world_root==null:
		return
	var screen:=get_viewport_rect().size
	var zoom:float=screen.x/1280.0*game.camera_zoom
	var shake_offset:Vector2=Vector2(sin(game.clock*77),cos(game.clock*91))*game.shake
	base=Transform2D(0,Vector2.ONE*zoom,0,screen/2-game.camera*zoom+shake_offset)
	world_root.transform=base
	grading.size=screen
	grading.visible=game.graphics_high
	water_material.set_shader_parameter("game_time",game.clock)
	water_material.set_shader_parameter("high_quality",game.graphics_high)
	if floor_room!=game.room:
		floor_room=game.room
		floor_layer.clear()
		if game.room>=0:
			var b:Dictionary=game.blocks[game.room]
			var r:Rect2=b.rect.grow(-10)
			var key:="floor_pattern" if b.id==12 else "wood" if b.id==24 else "concrete"
			for y in range(int(r.position.y/16),int(r.end.y/16)+1):
				for x in range(int(r.position.x/16),int(r.end.x/16)+1):
					floor_layer.set_cell(Vector2i(x,y),tile_ids[key],Vector2i(x%16,y%16))
	floor_layer.visible=game.room>=0
	for i in range(roof_sprites.size()):
		roof_sprites[i].modulate.a=game.roof_alpha[i]
	for item in inside_sprites:
		item.node.visible=game.interior_visible(item.building)
	for i in range(people_sprites.size()):
		var npc:Dictionary=game.people[i]
		set_character(people_sprites[i],npc.pos,npc.angle,npc.moving,npc.alive)
	for i in range(cast_sprites.size()):
		var npc:Dictionary=game.cast[i]
		var visible_value:bool=(npc.building<0) or game.room==game.building_index(npc.building)
		set_character(cast_sprites[i],npc.pos,PI/2,false,visible_value,npc.building>=0)
	set_character(player_visual,game.player,game.heading,game.player_moving or game.transition.get("kind","") in ["board","disembark"],game.boarded<0 or game.transition.get("kind","")=="disembark",game.room>=0)
	for i in range(fleet_sprites.size()):
		var v:Dictionary=game.fleet[i]
		var pair:Dictionary=fleet_sprites[i]
		var scale_value:=0.27 if v.kind=="car" else 0.36 if v.kind=="boat" else 0.37
		pair.body.position=v.pos
		pair.body.rotation=v.angle
		pair.body.scale=Vector2.ONE*scale_value
		pair.body.offset=Vector2(-62,0) if v.kind=="helicopter" else Vector2.ZERO
		pair.body.modulate=v.color.lightened(0.1) if v.kind=="car" else Color.WHITE
		pair.shadow.position=v.pos+Vector2(15,22) if v.kind=="helicopter" and v.flying else v.pos+Vector2(5,8)
		pair.shadow.scale=pair.body.scale
		pair.shadow.rotation=v.angle
		pair.shadow.offset=pair.body.offset
		pair.body.z_index=4 if v.kind=="helicopter" else 2
		pair.shadow.z_index=2 if v.get("roof",-1)>=0 else -1
		if pair.rotor!=null:
			pair.rotor.position=v.pos
			pair.rotor.rotation=v.angle+(game.clock*28 if v.flying else 0)
	for event in game.effects:
		emit_particle(event)
	game.effects.clear()
	for particle in particles:
		particle.visible=(particle.get_meta("room")==game.room)
	muzzle_time=maxf(0,muzzle_time-dt)
	muzzle_light.visible=muzzle_time>0
	update_lights()
	while decal_visuals.size()<game.decals.size():
		var item:=sprite("skid",Vector2.ZERO)
		item.z_index=-3
		decal_visuals.append(item)
	for i in range(decal_visuals.size()):
		var item:=decal_visuals[i]
		item.visible=i<game.decals.size()
		if item.visible:
			var decal:Dictionary=game.decals[i]
			item.texture=art[decal.kind]
			item.position=decal.pos
			item.rotation=decal.angle+PI/2
			item.scale=Vector2.ONE*0.48
			item.modulate.a=minf(1,decal.life/4)

func _process(dt:float) -> void:
	sync_visuals(dt)
	queue_redraw()

func _draw() -> void:
	if world_root==null:
		return
	# Textured projectile streaks and waypoint art; no raw terrain/floor/wall shapes.
	draw_set_transform_matrix(base)
	for shot in game.bullets:
		if shot.room==game.room and shot.roof==game.rooftop:
			draw_texture_rect(art["spark"],Rect2(shot.pos-Vector2(9,22),Vector2(18,13)),false)
	if game.chapter<game.story.size()-1:
		var point:Vector2=game.objective_point()
		draw_texture_rect(art["ripple"],Rect2(point-Vector2(27,27),Vector2(54,54)),false,Color("e5d78c"))
		draw_texture_rect(art["icon_waypoint"],Rect2(point-Vector2(10,10),Vector2(20,20)),false,Color("efd6a1"))
	draw_set_transform_matrix(Transform2D.IDENTITY)
