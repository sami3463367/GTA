extends Node2D
## Authoritative gameplay shared by native Android and the Godot Web preview.
const World = preload("res://scripts/world_data.gd")
const Rooms = preload("res://scripts/interior_data.gd")
const Narrative = preload("res://scripts/narrative.gd")
const Navigation = preload("res://scripts/city_navigation.gd")
const Renderer = preload("res://scripts/city_renderer.gd")
const Hud = preload("res://scripts/game_hud.gd")
var blocks: Array[Dictionary] = World.buildings()
var fleet: Array[Dictionary] = World.vehicles()
var story: Array[Dictionary] = Narrative.quests()
var cast: Array[Dictionary] = Narrative.characters()
var people: Array[Dictionary] = []
var bullets: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var decals: Array[Dictionary] = []
var player := World.START
var heading := -PI/2
var health := 100.0
var armor := 50.0
var ammo := 30
var reserve := 120
var cash := 0
var chapter := 0
var branch := "careful"
var wanted := 0.0
var boarded := -1
var room := -1
var rooftop := -1
var clock := 0.0
var camera := World.START
var camera_zoom := 1.0
var shake := 0.0
var damage_flash := 0.0
var paused := true
var sprint := false
var fire_held := false
var stick := Vector2.ZERO
var gun_cooldown := 0.0
var reload_timer := 0.0
var save_clock := 0.0
var effect_clock := 0.0
var notice := "Welcome home. Find Mara at the marina cafe."
var notice_time := 0.0
var sound_enabled := true
var graphics_high := true
var player_moving := false
var dialogue: Dictionary = {}
var speaker: Dictionary = {}
var dialogue_age := 0.0
var transition: Dictionary = {}
var door_cooldown := 0.0
var hit_cooldown := 0.0
var roof_alpha: Array[float] = []
var doors: Array[Area2D] = []
var body: CharacterBody2D
var navigation: RefCounted
var renderer: Node2D
var hud: Node2D
var gun_sound: AudioStreamPlayer
var step_sound: AudioStreamPlayer
var vehicle_sound: AudioStreamPlayer
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.seed = 4817
	navigation = Navigation.new(blocks)
	for i in range(blocks.size()):
		roof_alpha.append(1.0)
		if blocks[i].interior:
			var area := Area2D.new()
			area.name = "Entrance_%d" % blocks[i].id
			area.position = blocks[i].door
			area.collision_layer = 0
			area.collision_mask = 1
			var shape := CollisionShape2D.new()
			var rectangle := RectangleShape2D.new()
			rectangle.size = Vector2(44,30)
			shape.shape = rectangle
			area.add_child(shape)
			area.body_entered.connect(func(_other: Node2D): request_enter(i))
			add_child(area)
			doors.append(area)
	for person in cast:
		if person.building >= 0:
			person.pos = blocks[building_index(person.building)].rect.position + person.local
	spawn_population()
	load_game()
	camera = player
	body = CharacterBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6
	shape.shape = circle
	body.add_child(shape)
	body.position = player
	add_child(body)
	renderer = Renderer.new()
	renderer.game = self
	add_child(renderer)
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	hud = Hud.new()
	hud.game = self
	layer.add_child(hud)
	gun_sound = make_audio("res://assets/shot.wav",-14)
	step_sound = make_audio("res://assets/step.wav",-24)
	vehicle_sound = make_audio("res://assets/motor.wav",-26)
	get_tree().auto_accept_quit = false
	get_tree().quit_on_go_back = false

func building_index(id: int) -> int:
	for i in range(blocks.size()):
		if blocks[i].id == id:
			return i
	return -1

func spawn_population() -> void:
	people.clear()
	for i in range(36):
		var point: Vector2 = navigation.nodes[(i*7+5)%navigation.nodes.size()]
		people.append({"pos":point,"angle":0.0,"alive":true,"hp":60.0,"timer":0.0,"path":PackedVector2Array(),"hostile":i<3,"state":"patrol","moving":false,"attack":0.0,"color":[Color("65b6b3"),Color("db8a87"),Color("8896cf")][i%3]})
	for i in range(3,fleet.size()):
		var left := float(80+(i%4)*420)
		var top := float(80+(i%4)*420)
		var route := PackedVector2Array([Vector2(left+16,top+16),Vector2(left+404,top+16),Vector2(left+404,top+404),Vector2(left+16,top+404)])
		fleet[i].route = route
		fleet[i].waypoint = i%4
		fleet[i].pos = route[i%4]
		fleet[i].driver = true

func make_audio(path: String,volume: float) -> AudioStreamPlayer:
	var audio := AudioStreamPlayer.new()
	audio.stream = load(path)
	audio.volume_db = volume
	add_child(audio)
	return audio

func notify(message: String,duration := 4.0) -> void:
	notice = message
	notice_time = duration

func toggle_pause() -> void:
	if not dialogue.is_empty():
		close_dialogue()
		return
	paused = not paused
	stick = Vector2.ZERO
	fire_held = false
	if paused:
		save_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		paused = true
		stick = Vector2.ZERO
		fire_held = false
		save_game()
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		toggle_pause()
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
		get_tree().quit()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event.keycode == KEY_ESCAPE:
		toggle_pause()
		return
	if paused:
		return
	if not dialogue.is_empty():
		if event.keycode in [KEY_1,KEY_2,KEY_3]:
			choose_dialogue(event.keycode-KEY_1)
		return
	match event.keycode:
		KEY_E: interact()
		KEY_F: use_vehicle()
		KEY_L: land()
		KEY_R: reload_weapon()
		KEY_SPACE: shoot()

func _process(delta: float) -> void:
	var dt := minf(delta,0.04)
	if not paused:
		update_game(dt)
	if vehicle_sound:
		if boarded >= 0 and not paused and sound_enabled and dialogue.is_empty():
			vehicle_sound.pitch_scale = 0.65 if fleet[boarded].kind == "helicopter" else 1.0
			if not vehicle_sound.playing:
				vehicle_sound.play()
		else:
			vehicle_sound.stop()
	body.position = player
	renderer.queue_redraw()
	hud.queue_redraw()

func update_game(dt: float) -> void:
	clock += dt
	dialogue_age += dt
	gun_cooldown = maxf(0,gun_cooldown-dt)
	notice_time = maxf(0,notice_time-dt)
	door_cooldown = maxf(0,door_cooldown-dt)
	hit_cooldown = maxf(0,hit_cooldown-dt)
	damage_flash = maxf(0,damage_flash-dt*1.8)
	shake = maxf(0,shake-dt*10)
	wanted = maxf(0,wanted-dt*0.022)
	for i in range(roof_alpha.size()):
		var target := 0.0 if room == i and transition.get("kind","") != "exit" else 1.0
		roof_alpha[i] = move_toward(roof_alpha[i],target,dt/0.45)
	update_transition(dt)
	var zoom_target := 2.0 if room>=0 else 0.9 if boarded>=0 else 1.12
	if boarded>=0 and fleet[boarded].kind=="helicopter" and fleet[boarded].flying:
		zoom_target=0.74
	if wanted>1 and room<0:
		zoom_target*=0.94
	camera_zoom=lerpf(camera_zoom,zoom_target,minf(1,dt*4))
	camera=camera.lerp(player,minf(1,dt*8))
	if not dialogue.is_empty():
		player_moving=false
		return
	if reload_timer>0:
		reload_timer=maxf(0,reload_timer-dt)
		if reload_timer==0:
			var amount:=mini(30-ammo,reserve)
			ammo+=amount
			reserve-=amount
	var movement:=stick
	movement.x+=float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
	movement.y+=float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
	movement=movement.limit_length()
	if not transition.is_empty():
		movement=Vector2.ZERO
	player_moving=movement.length()>0.08
	var speed:=175.0 if sprint or Input.is_physical_key_pressed(KEY_SHIFT) else 110.0
	if boarded>=0:
		speed={"car":290.0,"boat":240.0,"helicopter":350.0}[fleet[boarded].kind]
		if fleet[boarded].kind=="helicopter" and not fleet[boarded].flying:
			speed=0
	if player_moving:
		var old_heading:=heading
		heading=lerp_angle(heading,movement.angle(),minf(1,dt*12)) if boarded>=0 else movement.angle()
		var next:=player+movement*speed*dt
		if can_player_move(Vector2(next.x,player.y)):
			player.x=next.x
		if can_player_move(Vector2(player.x,next.y)):
			player.y=next.y
		if boarded>=0:
			fleet[boarded].pos=player
			fleet[boarded].angle=heading
			effect_clock+=dt
			if effect_clock>0.16:
				effect_clock=0
				var kind:String=fleet[boarded].kind
				emit_effect("ripple" if kind=="boat" else "smoke",player-Vector2.from_angle(heading)*29,heading+PI)
				if kind=="car" and absf(angle_difference(old_heading,heading))>0.06:
					decals.append({"kind":"skid","pos":player,"angle":heading,"life":28.0,"room":-1})
		else:
			effect_clock+=dt
			if effect_clock>0.32 and sound_enabled:
				step_sound.play()
				effect_clock=0
	if fire_held or Input.is_physical_key_pressed(KEY_SPACE):
		shoot()
	check_doors()
	update_people(dt)
	update_traffic(dt)
	update_bullets(dt)
	for i in range(decals.size()-1,-1,-1):
		decals[i].life-=dt
		if decals[i].life<=0:
			decals.remove_at(i)
	while decals.size()>96:
		decals.pop_front()
	if health<=0:
		health=100
		armor=25
		cash=maxi(0,cash-100)
		wanted=0
		boarded=-1
		room=-1
		rooftop=-1
		transition.clear()
		player=World.START
		roof_alpha.fill(1.0)
		ammo=30
		reserve=maxi(60,reserve)
		notify("Coast Clinic: you're safe. Medical care cost $100.",6)
	if story[chapter].kind=="boat" and boarded>=0 and fleet[boarded].kind=="boat" and player.distance_to(story[chapter].point)<100:
		advance_story()
		notify("The reporter has the ledger and flight log. The harbor has a future.",8)
	save_clock+=dt
	if save_clock>15:
		save_clock=0
		save_game()

func check_doors() -> void:
	if not transition.is_empty() or door_cooldown>0 or boarded>=0 or rooftop>=0:
		return
	if room>=0:
		var local:Vector2=player-blocks[room].rect.position
		if local.y>239 and absf(local.x-135)<23:
			request_exit()
	else:
		for i in range(blocks.size()):
			if blocks[i].interior and Rect2(blocks[i].door-Vector2(22,15),Vector2(44,30)).has_point(player):
				request_enter(i)
				return

func request_enter(index: int) -> void:
	if paused or room>=0 or rooftop>=0 or boarded>=0 or door_cooldown>0 or not transition.is_empty() or not dialogue.is_empty():
		return
	if index<0 or index>=blocks.size() or not blocks[index].interior:
		return
	if player.distance_to(blocks[index].door)>45:
		return
	room=index
	player=blocks[index].rect.position+Vector2(135,233)
	roof_alpha[index]=1.0
	transition={"kind":"enter","time":0.0,"duration":0.46}
	door_cooldown=0.8
	notify("%s · walk up to your contact to talk." % blocks[index].name)

func request_exit() -> void:
	if room<0 or not transition.is_empty():
		return
	close_dialogue()
	transition={"kind":"exit","time":0.0,"duration":0.46,"index":room}

func update_transition(dt: float) -> void:
	if transition.is_empty():
		return
	transition.time+=dt
	if transition.kind in ["board","disembark"]:
		player=transition.from.lerp(transition.to,smoothstep(0,1,transition.time/transition.duration))
	if transition.time<transition.duration:
		return
	match transition.kind:
		"exit":
			var index:int=transition.index
			roof_alpha[index]=1.0
			player=blocks[index].door+Vector2(0,30)
			room=-1
			door_cooldown=0.8
			notify("Back on the street.")
		"board":
			boarded=transition.index
			fleet[boarded].driver=false
			player=fleet[boarded].pos
			if fleet[boarded].kind=="helicopter":
				fleet[boarded].flying=true
				fleet[boarded].roof=-1
				rooftop=-1
		"disembark":
			boarded=-1
			player=transition.to
	transition.clear()

func interior_visible(index: int) -> bool:
	return room==index

func can_player_move(point:Vector2) -> bool:
	if room>=0:
		var local:Vector2=point-blocks[room].rect.position
		if not Rect2(17,17,236,228).has_point(local):
			return false
		for r in Rooms.blockers(blocks[room].id):
			if r.grow(6).has_point(local):
				return false
		return true
	if rooftop>=0 and (boarded<0 or not fleet[boarded].flying):
		return blocks[rooftop].rect.grow(-15).has_point(point)
	return World.can_move(point,fleet[boarded].kind if boarded>=0 else "foot",blocks)

func objective_point() -> Vector2:
	var quest:Dictionary=story[chapter]
	if quest.building>=0 and room==building_index(quest.building):
		for npc in cast:
			if npc.id==quest.npc:
				return npc.pos
	return quest.point

func nearest_npc() -> Dictionary:
	if boarded>=0 or rooftop>=0:
		return {}
	for npc in cast:
		if (npc.building<0 and room<0) or (room>=0 and blocks[room].id==npc.building):
			if player.distance_to(npc.pos)<55:
				return npc
	return {}

func interact() -> void:
	if paused or not transition.is_empty():
		return
	if not dialogue.is_empty():
		return
	var npc:=nearest_npc()
	if not npc.is_empty():
		speaker=npc
		dialogue=Narrative.dialogue(npc.id,chapter,branch)
		dialogue_age=0
		stick=Vector2.ZERO
		fire_held=false
		return
	if room>=0:
		if player.distance_to(blocks[room].rect.position+Vector2(135,242))<58:
			request_exit()
		else:
			notify("Approach your contact to talk, or the south doorway to leave.")
		return
	if rooftop>=0 and player.distance_to(blocks[rooftop].rect.position+Vector2(35,40))<55:
		player=blocks[rooftop].door+Vector2(0,30)
		rooftop=-1
		door_cooldown=0.8
		return
	for i in range(blocks.size()):
		if blocks[i].interior and player.distance_to(blocks[i].door)<45:
			request_enter(i)
			return
	notify("Approach a contact to TALK. Use the vehicle icon or F to enter a vehicle.")

func choose_dialogue(index:int) -> void:
	if dialogue.is_empty() or index<0 or index>=dialogue.choices.size():
		return
	var choice:Dictionary=dialogue.choices[index]
	if choice.has("next"):
		dialogue=Narrative.branch_node(choice.next)
		dialogue_age=0
		return
	if choice.get("action","")=="complete" and story[chapter].npc==speaker.id and story[chapter].kind in ["talk","delivery"]:
		branch=choice.get("flag",branch)
		advance_story()
	close_dialogue()

func close_dialogue() -> void:
	dialogue.clear()
	speaker.clear()
	stick=Vector2.ZERO
	fire_held=false

func nearest_vehicle() -> int:
	var best:=-1
	var distance:=76.0
	if room>=0:
		return best
	for i in range(fleet.size()):
		if fleet[i].get("roof",-1)!=rooftop:
			continue
		var d:float=player.distance_to(fleet[i].pos)
		if d<distance:
			best=i
			distance=d
	return best

func use_vehicle() -> void:
	if paused or not transition.is_empty() or not dialogue.is_empty() or room>=0:
		return
	if boarded>=0:
		var v:Dictionary=fleet[boarded]
		if v.kind=="helicopter" and v.flying:
			notify("Land on a helipad before stepping out.")
			return
		for i in range(16):
			var p:Vector2=v.pos+Vector2.from_angle(i*TAU/16)*62
			if (rooftop>=0 and blocks[rooftop].rect.grow(-15).has_point(p)) or (rooftop<0 and World.can_move(p,"foot",blocks)):
				transition={"kind":"disembark","from":player,"to":p,"time":0.0,"duration":0.2}
				return
		notify("Move beside the dock or a clear sidewalk to exit safely.")
		return
	var index:=nearest_vehicle()
	if index>=0:
		fleet[index].driver=false
		transition={"kind":"board","index":index,"from":player,"to":fleet[index].pos,"time":0.0,"duration":0.2}
	else:
		notify("Get closer to a car, boat or helicopter.")

func land() -> void:
	if paused or not transition.is_empty() or not dialogue.is_empty():
		return
	if room>=0 and blocks[room].helipad:
		rooftop=room
		room=-1
		roof_alpha[rooftop]=1.0
		player=blocks[rooftop].rect.position+Vector2(35,65)
		return
	if boarded<0 or fleet[boarded].kind!="helicopter":
		notify("LAND: helicopter pads, or Meridian's indoor rooftop elevator.")
		return
	if not fleet[boarded].flying:
		fleet[boarded].flying=true
		fleet[boarded].roof=-1
		rooftop=-1
		return
	for i in range(blocks.size()):
		if blocks[i].helipad and player.distance_to(blocks[i].rect.get_center())<80:
			player=blocks[i].rect.get_center()
			fleet[boarded].pos=player
			fleet[boarded].flying=false
			fleet[boarded].roof=i
			rooftop=i
			if story[chapter].kind=="land":
				advance_story()
				notify("The rooftop contact hands you the flight log. Return to Inez.",6)
			return
	if player.distance_to(World.PARK)<85:
		fleet[boarded].flying=false
		fleet[boarded].roof=-1
		rooftop=-1
	else:
		notify("Unsafe landing. Use Meridian's H or the Sunset Park pad.")

func reload_weapon() -> void:
	if reload_timer<=0 and ammo<30 and reserve>0 and not paused and dialogue.is_empty():
		reload_timer=0.95

func shoot() -> void:
	if paused or boarded>=0 or gun_cooldown>0 or reload_timer>0 or not dialogue.is_empty() or not transition.is_empty():
		return
	if ammo<=0:
		reload_weapon()
		return
	ammo-=1
	gun_cooldown=0.22
	bullets.append({"pos":player+Vector2.from_angle(heading)*20,"angle":heading,"life":0.7,"room":room,"roof":rooftop,"owner":"player"})
	wanted=minf(5,wanted+0.18)
	shake=maxf(shake,1.5)
	emit_effect("spark",player-Vector2(0,16)+Vector2.from_angle(heading)*19,heading)
	if sound_enabled:
		gun_sound.play()

func emit_effect(kind:String,point:Vector2,angle:=0.0) -> void:
	if effects.size()<50:
		effects.append({"kind":kind,"pos":point,"angle":angle,"room":room})

func apply_damage(amount:float) -> void:
	if hit_cooldown>0 or not dialogue.is_empty():
		return
	hit_cooldown=0.3
	var absorbed:=minf(armor,amount*0.65)
	armor-=absorbed
	health-=amount-absorbed
	damage_flash=0.8
	shake=5
	emit_effect("hit",player-Vector2(0,13))

func update_people(dt:float) -> void:
	for npc in people:
		npc.timer-=dt
		npc.attack=maxf(0,npc.attack-dt)
		if not npc.alive:
			if npc.timer<=0:
				npc.alive=true
				npc.hp=60
			else:
				continue
		var aggressive:bool=npc.hostile and wanted>=1 and room<0 and rooftop<0 and not World.is_water(player)
		var distance:float=npc.pos.distance_to(player)
		if aggressive and distance<280 and navigation.line_clear(npc.pos,player):
			npc.state="attack"
			npc.angle=(player-npc.pos).angle()
			if npc.attack<=0:
				npc.attack=1.25
				bullets.append({"pos":npc.pos+Vector2.from_angle(npc.angle)*19,"angle":npc.angle,"life":0.65,"room":-1,"roof":-1,"owner":"hostile"})
				emit_effect("spark",npc.pos-Vector2(0,16),npc.angle)
		if npc.timer<=0 or npc.path.is_empty():
			npc.timer=1.4+rng.randf()*1.8
			var target:Vector2=navigation.nodes[rng.randi_range(0,navigation.nodes.size()-1)]
			if aggressive:
				npc.state="chase"
				target=player
				if npc.hp<35 or (distance<250 and int(clock)%6<2):
					target=navigation.cover(npc.pos,player)
					npc.state="cover"
			elif wanted>0.5 and distance<200:
				npc.state="flee"
				target=npc.pos+(npc.pos-player).normalized()*300
			else:
				npc.state="patrol"
			npc.path=navigation.path(npc.pos,target)
			if not npc.path.is_empty() and npc.pos.distance_to(npc.path[0])<8:
				npc.path.remove_at(0)
		npc.moving=false
		if not npc.path.is_empty() and not (aggressive and npc.state=="attack" and npc.hp>=35):
			var direction:Vector2=npc.path[0]-npc.pos
			if direction.length()<5:
				npc.path.remove_at(0)
			else:
				var speed:=72.0 if aggressive or npc.state=="flee" else 29.0
				var next:Vector2=npc.pos+direction.normalized()*minf(speed*dt,direction.length())
				if World.can_move(next,"foot",blocks):
					npc.pos=next
					npc.angle=direction.angle()
					npc.moving=true

func update_traffic(dt:float) -> void:
	for i in range(3,fleet.size()):
		var v:Dictionary=fleet[i]
		if not v.get("driver",false) or i==boarded:
			continue
		var goal:Vector2=v.route[v.waypoint]
		var direction:Vector2=goal-v.pos
		if direction.length()<5:
			v.waypoint=(v.waypoint+1)%4
			continue
		var blocked:=false
		for j in range(fleet.size()):
			if j!=i and v.pos.distance_to(fleet[j].pos)<53 and direction.normalized().dot((fleet[j].pos-v.pos).normalized())>0.8:
				blocked=true
		if blocked:
			continue
		var next:Vector2=v.pos+direction.normalized()*minf(95*dt,direction.length())
		if World.can_move(next,"car",blocks):
			v.pos=next
			v.angle=lerp_angle(v.angle,direction.angle(),minf(1,dt*7))
		if boarded<0 and room<0 and rooftop<0 and player.distance_to(v.pos)<19:
			apply_damage(16)

func update_bullets(dt:float) -> void:
	for i in range(bullets.size()-1,-1,-1):
		var shot:Dictionary=bullets[i]
		shot.life-=dt
		var old:Vector2=shot.pos
		shot.pos+=Vector2.from_angle(shot.angle)*620*dt
		if shot.room<0 and shot.roof<0:
			if not navigation.line_clear(old,shot.pos):
				shot.life=0
			if shot.life>0 and shot.owner=="player":
				for npc in people:
					if npc.alive and npc.pos.distance_to(shot.pos)<16:
						npc.hp-=35
						shot.life=0
						emit_effect("hit",npc.pos-Vector2(0,14))
						decals.append({"kind":"hit","pos":npc.pos,"angle":0.0,"life":10.0,"room":-1})
						wanted=minf(5,wanted+0.6)
						if npc.hp<=0:
							npc.alive=false
							npc.timer=25
						break
		if shot.room>=0:
			var p:Vector2=shot.pos-blocks[shot.room].rect.position
			if not Rect2(15,15,240,230).has_point(p):
				shot.life=0
			for r in Rooms.blockers(blocks[shot.room].id):
				if r.has_point(p):
					shot.life=0
		if shot.owner=="hostile" and shot.life>0 and shot.room==room and rooftop<0 and shot.pos.distance_to(player)<16:
			apply_damage(14)
			shot.life=0
		if shot.life<=0:
			bullets.remove_at(i)

func advance_story() -> void:
	if chapter>=story.size()-1:
		return
	cash+=story[chapter].reward
	chapter+=1
	notify("Objective complete · "+story[chapter].title,5)
	save_game()

func save_game() -> bool:
	var safe:=player
	if room>=0 or rooftop>=0 or not World.can_move(safe,"foot",blocks):
		safe=World.START
	var data:={"version":2,"chapter":chapter,"cash":cash,"health":health,"armor":armor,"ammo":ammo,"reserve":reserve,"branch":branch,"x":safe.x,"y":safe.y,"sound":sound_enabled,"graphics_high":graphics_high,"clock":clock}
	var file:=FileAccess.open(World.SAVE_PATH+".tmp",FileAccess.WRITE)
	if file==null:
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	return DirAccess.rename_absolute(World.SAVE_PATH+".tmp",World.SAVE_PATH)==OK

func load_game() -> void:
	if not FileAccess.file_exists(World.SAVE_PATH):
		return
	var data=JSON.parse_string(FileAccess.get_file_as_string(World.SAVE_PATH))
	if not data is Dictionary or data.get("version",0) not in [1,2]:
		return
	for field in ["chapter","cash","health","x","y"]:
		if not data.get(field) is float and not data.get(field) is int:
			return
		if not is_finite(float(data[field])):
			return
	chapter=clampi(int(data.chapter),0,6)
	if data.version==1:
		chapter=[0,1,3,5,6][clampi(chapter,0,4)]
	cash=clampi(int(data.cash),0,99999999)
	health=clampf(float(data.health),20,100)
	player=Vector2(data.x,data.y) if World.can_move(Vector2(data.x,data.y),"foot",blocks) else World.START
	sound_enabled=data.get("sound",true)==true
	graphics_high=data.get("graphics_high",true)==true
	branch=str(data.get("branch","careful"))
	for field in ["armor","ammo","reserve","clock"]:
		var value=data.get(field)
		if (value is float or value is int) and is_finite(float(value)):
			match field:
				"armor":armor=clampf(value,0,100)
				"ammo":ammo=clampi(value,0,30)
				"reserve":reserve=clampi(value,0,999)
				"clock":clock=fposmod(float(value),180)

func reset_story() -> void:
	player=World.START
	camera=player
	chapter=0
	cash=0
	health=100
	armor=50
	ammo=30
	reserve=120
	wanted=0
	room=-1
	rooftop=-1
	boarded=-1
	transition.clear()
	close_dialogue()
	roof_alpha.fill(1.0)
	fleet=World.vehicles()
	spawn_population()
	bullets.clear()
	decals.clear()
	clock=0
	save_game()
