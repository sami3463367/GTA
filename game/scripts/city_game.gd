extends Node2D
## Native Godot gameplay. No networking, WebView, or external runtime assets.
const World = preload("res://scripts/world_data.gd")
const Renderer = preload("res://scripts/city_renderer.gd")
const Hud = preload("res://scripts/game_hud.gd")
var blocks: Array[Dictionary] = World.buildings()
var fleet: Array[Dictionary] = World.vehicles()
var story: Array[Dictionary] = World.missions()
var people: Array[Dictionary] = []
var bullets: Array[Dictionary] = []
var player := World.START
var heading := -PI / 2
var health := 100.0
var cash := 0
var chapter := 0
var wanted := 0.0
var boarded := -1
var room := -1
var rooftop := -1
var clock := 0.0
var camera := World.START
var paused := true
var sprint := false
var fire_held := false
var stick := Vector2.ZERO
var gun_cooldown := 0.0
var save_clock := 0.0
var step_clock := 0.0
var notice := "Welcome to Azure Harbor. A new city. An old friend."
var notice_time := 0.0
var sound_enabled := true
var police := {"kind": "car", "pos": Vector2(2180, 1760), "angle": 0.0, "color": Color("e0e7de"), "flying": false, "police": true}
var renderer: Node2D
var hud: Node2D
var gun_sound: AudioStreamPlayer
var step_sound: AudioStreamPlayer
var vehicle_sound: AudioStreamPlayer
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.seed = 4817
	for i in range(60):
		people.append({"pos": Vector2(110 + (i % 5) * 420, 140 + (i / 5) * 170), "angle": rng.randf() * TAU, "timer": rng.randf_range(1, 4), "alive": true, "color": [Color("c9836a"), Color("d4c59f"), Color("749a86"), Color("809bbb")][i % 4]})
	load_game()
	camera = player
	renderer = Renderer.new()
	renderer.game = self
	add_child(renderer)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	hud.game = self
	layer.add_child(hud)
	gun_sound = make_audio("res://assets/shot.wav", -14)
	step_sound = make_audio("res://assets/step.wav", -23)
	vehicle_sound = make_audio("res://assets/motor.wav", -25)
	get_tree().auto_accept_quit = false

func make_audio(path: String, volume: float) -> AudioStreamPlayer:
	var audio := AudioStreamPlayer.new()
	audio.stream = load(path)
	audio.volume_db = volume
	add_child(audio)
	return audio

func notify(message: String, duration := 4.0) -> void:
	notice = message
	notice_time = duration

func toggle_pause() -> void:
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
	if paused:
		return
	match event.keycode:
		KEY_E: interact()
		KEY_L: land()
		KEY_SPACE: shoot()

func _process(delta: float) -> void:
	var dt := minf(delta, 0.04)
	if not paused:
		update_game(dt)
	if vehicle_sound:
		if boarded >= 0 and not paused and sound_enabled:
			vehicle_sound.pitch_scale = 0.65 if fleet[boarded].kind == "helicopter" else 1.0
			if not vehicle_sound.playing:
				vehicle_sound.play()
		else:
			vehicle_sound.stop()
	renderer.queue_redraw()
	hud.queue_redraw()

func update_game(dt: float) -> void:
	clock += dt
	gun_cooldown = maxf(0, gun_cooldown - dt)
	notice_time = maxf(0, notice_time - dt)
	wanted = maxf(0, wanted - dt * 0.035)
	save_clock += dt
	if save_clock > 15:
		save_clock = 0
		save_game()
	var movement := stick
	movement.x += float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
	movement.y += float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
	movement = movement.limit_length()
	var speed := 175.0 if sprint or Input.is_physical_key_pressed(KEY_SHIFT) else 110.0
	if boarded >= 0:
		speed = {"car": 300.0, "boat": 250.0, "helicopter": 360.0}[fleet[boarded].kind]
		if fleet[boarded].kind == "helicopter" and not fleet[boarded].flying:
			speed = 0
	if movement.length() > 0.08:
		heading = movement.angle()
		var next := player + movement * speed * dt
		if can_player_move(Vector2(next.x, player.y)):
			player.x = next.x
		if can_player_move(Vector2(player.x, next.y)):
			player.y = next.y
		if boarded >= 0:
			fleet[boarded].pos = player
			fleet[boarded].angle = heading
		else:
			step_clock += dt
			if step_clock > 0.32 and sound_enabled:
				step_sound.play()
				step_clock = 0
	if fire_held or Input.is_physical_key_pressed(KEY_SPACE):
		shoot()
	update_people(dt)
	update_bullets(dt)
	update_police(dt)
	if health <= 0:
		health = 100
		cash = maxi(0, cash - 100)
		wanted = 0
		boarded = -1
		room = -1
		rooftop = -1
		player = World.START
		notify("Coast Clinic: you are safe. Medical care cost $100.", 6)
	if chapter == 1 and boarded >= 0 and fleet[boarded].kind == "car" and player.distance_to(story[1].point) < 85:
		advance_story()
	if chapter == 3 and boarded >= 0 and fleet[boarded].kind == "boat" and player.distance_to(story[3].point) < 100:
		advance_story()
	var target := Vector2(350, 300) if room >= 0 else player
	camera = camera.lerp(target, minf(1, dt * 7))

func can_player_move(point: Vector2) -> bool:
	if room >= 0:
		if not Rect2(68, 108, 564, 376).has_point(point):
			return false
		# Solid reception counter and tables, with generous walking aisles.
		if Rect2(95, 150, 510, 48).grow(8).has_point(point):
			return false
		for x in [160, 330, 500]:
			for y in [300, 400]:
				if point.distance_to(Vector2(x, y)) < 33:
					return false
		return true
	if rooftop >= 0 and (boarded < 0 or not fleet[boarded].flying):
		return blocks[rooftop].rect.grow(-15).has_point(point)
	return World.can_move(point, fleet[boarded].kind if boarded >= 0 else "foot", blocks)

func nearest_vehicle() -> int:
	var closest := -1
	var distance := 76.0
	for i in range(fleet.size()):
		var v: Dictionary = fleet[i]
		if v.get("roof", -1) != rooftop or room >= 0:
			continue
		var d := player.distance_to(v.pos)
		if d < distance:
			closest = i
			distance = d
	return closest

func interact() -> void:
	if paused:
		return
	if boarded >= 0:
		var v: Dictionary = fleet[boarded]
		if v.kind == "helicopter" and v.flying:
			notify("Land on the hotel's H or Sunset Park before stepping out.")
			return
		var found := false
		for i in range(16):
			var exit_point: Vector2 = v.pos + Vector2.from_angle(i * TAU / 16) * 65
			if (rooftop >= 0 and blocks[rooftop].rect.grow(-15).has_point(exit_point)) or (rooftop < 0 and World.can_move(exit_point, "foot", blocks)):
				player = exit_point
				found = true
				break
		if not found:
			notify("Move closer to an open sidewalk or the marina dock to exit.")
			return
		boarded = -1
		notify("Back on foot.")
		return
	if room >= 0:
		player = blocks[room].door
		room = -1
		notify("Back on the street.")
		return
	if rooftop >= 0 and player.distance_to(blocks[rooftop].rect.position + Vector2(35, 40)) < 60:
		player = blocks[rooftop].door
		rooftop = -1
		notify("Elevator to street level.")
		return
	var nearby := nearest_vehicle()
	if nearby >= 0:
		boarded = nearby
		player = fleet[boarded].pos
		if fleet[boarded].kind == "helicopter":
			fleet[boarded].flying = true
			fleet[boarded].roof = -1
			rooftop = -1
			notify("Airborne. Steer, then LAND over a marked helipad.")
		else:
			notify("Aboard the %s. USE to exit when stopped near land." % fleet[boarded].kind)
		return
	if rooftop < 0:
		for i in range(blocks.size()):
			if blocks[i].interior and player.distance_to(blocks[i].door) < 65:
				room = i
				player = Vector2(350, 468)
				if blocks[i].id == 24:
					notify("MARA: Welcome home. Take my delivery to Palm Market. Then visit Meridian by air.", 9)
					if chapter == 0:
						advance_story(false)
				elif blocks[i].id == 12:
					notify("Meridian Hotel. LAND / L takes the elevator to our rooftop garden.", 6)
				else:
					notify("Palm Market. A little quiet away from the city.")
				return
	notify("Walk closer to a vehicle, glowing doorway, or rooftop elevator.")

func land() -> void:
	if paused:
		return
	if room >= 0 and blocks[room].helipad:
		rooftop = room
		room = -1
		player = blocks[rooftop].rect.position + Vector2(35, 65)
		notify("The rooftop garden. USE beside the elevator to return downstairs.", 6)
		return
	if boarded < 0 or fleet[boarded].kind != "helicopter":
		notify("LAND controls the helicopter, or the elevator inside Meridian Hotel.")
		return
	if not fleet[boarded].flying:
		fleet[boarded].flying = true
		fleet[boarded].roof = -1
		rooftop = -1
		notify("Taking off.")
		return
	for i in range(blocks.size()):
		if blocks[i].helipad and player.distance_to(blocks[i].rect.get_center()) < 80:
			player = blocks[i].rect.get_center()
			fleet[boarded].pos = player
			fleet[boarded].flying = false
			fleet[boarded].roof = i
			rooftop = i
			notify("Rooftop landing complete. USE to step into the garden.")
			if chapter == 2:
				advance_story()
			return
	if player.distance_to(World.PARK) < 85:
		fleet[boarded].flying = false
		fleet[boarded].roof = -1
		rooftop = -1
		notify("Landed at Sunset Park.")
	else:
		notify("Not a safe landing zone. Find the hotel's H or Sunset Park.")

func shoot() -> void:
	if paused or boarded >= 0 or gun_cooldown > 0:
		return
	gun_cooldown = 0.24
	bullets.append({"pos": player + Vector2.from_angle(heading) * 20, "angle": heading, "life": 0.7, "room": room, "roof": rooftop})
	wanted = minf(5, wanted + 0.16)
	if sound_enabled:
		gun_sound.play()

func update_people(dt: float) -> void:
	for npc in people:
		npc.timer -= dt
		if npc.timer <= 0:
			npc.alive = true
			npc.angle = rng.randf() * TAU
			npc.timer = rng.randf_range(2, 5)
		if not npc.alive:
			continue
		var speed := 65.0 if wanted > 0.5 and player.distance_to(npc.pos) < 180 else 24.0
		if speed > 24:
			npc.angle = (npc.pos - player).angle()
		var next: Vector2 = npc.pos + Vector2.from_angle(npc.angle) * speed * dt
		if World.can_move(next, "foot", blocks):
			npc.pos = next
		else:
			npc.angle += PI / 2

func update_bullets(dt: float) -> void:
	for i in range(bullets.size() - 1, -1, -1):
		var shot: Dictionary = bullets[i]
		shot.life -= dt
		shot.pos += Vector2.from_angle(shot.angle) * 650 * dt
		if shot.room < 0 and shot.roof < 0:
			for b in blocks:
				if b.rect.has_point(shot.pos):
					shot.life = 0
			for npc in people:
				if npc.alive and npc.pos.distance_to(shot.pos) < 18:
					npc.alive = false
					npc.timer = 15
					shot.life = 0
					wanted = minf(5, wanted + 1)
					notify("Civilian harmed. Police alert increased.")
		if shot.life <= 0:
			bullets.remove_at(i)

func update_police(dt: float) -> void:
	if wanted < 1 or room >= 0 or rooftop >= 0 or World.is_water(player):
		return
	if boarded >= 0 and fleet[boarded].kind == "helicopter":
		return
	var direction: Vector2 = (player - police.pos).normalized()
	police.angle = direction.angle()
	var next: Vector2 = police.pos + direction * 135 * dt
	# Axis sliding keeps this simple pursuit agent from crossing buildings.
	if World.can_move(Vector2(next.x, police.pos.y), "car", blocks):
		police.pos.x = next.x
	if World.can_move(Vector2(police.pos.x, next.y), "car", blocks):
		police.pos.y = next.y
	if player.distance_to(police.pos) < 140:
		health -= dt * 10

func advance_story(show_message := true) -> void:
	cash += story[chapter].reward
	if show_message:
		notify("Objective complete. +$%d" % story[chapter].reward)
	chapter = mini(chapter + 1, story.size() - 1)
	save_game()

func save_game() -> bool:
	# Store a safe on-foot location, not a stranded flight/sea/interior position.
	var safe := player
	if room >= 0 or rooftop >= 0 or not World.can_move(safe, "foot", blocks):
		safe = World.START
	var data := {"version": 1, "chapter": chapter, "cash": cash, "health": health, "x": safe.x, "y": safe.y, "sound": sound_enabled}
	var temporary := World.SAVE_PATH + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	return DirAccess.rename_absolute(temporary, World.SAVE_PATH) == OK

func load_game() -> void:
	if not FileAccess.file_exists(World.SAVE_PATH):
		return
	var file := FileAccess.open(World.SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	if not data is Dictionary or data.get("version", 0) != 1:
		return
	for field in ["chapter", "cash", "health", "x", "y"]:
		if not data.get(field) is float and not data.get(field) is int:
			return
		if not is_finite(float(data[field])):
			return
	chapter = clampi(int(data.chapter), 0, story.size() - 1)
	cash = clampi(int(data.cash), 0, 99999999)
	health = clampf(float(data.health), 20, 100)
	var point := Vector2(data.x, data.y)
	if World.can_move(point, "foot", blocks):
		player = point
	sound_enabled = data.get("sound", true) == true

func reset_story() -> void:
	player = World.START
	camera = player
	chapter = 0
	cash = 0
	health = 100
	wanted = 0
	room = -1
	rooftop = -1
	boarded = -1
	fleet = World.vehicles()
	bullets.clear()
	save_game()
	notify("A new arrival. A fresh start.")
