extends SceneTree
const World = preload("res://scripts/world_data.gd")
var failures := 0
var checks := 0
var backup := ""
var had_save := false

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
	else:
		print("PASS: " + message)

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	var blocks := World.buildings()
	check(blocks.size() == 28, "28 city buildings generated")
	check(World.can_move(World.START, "foot", blocks), "spawn on accessible land")
	check(not World.can_move(Vector2(200, 200), "foot", blocks), "buildings block walking")
	check(not World.can_move(Vector2(200, 200), "car", blocks), "buildings block cars")
	check(World.can_move(Vector2(200, 200), "helicopter", blocks), "helicopters pass above roofs")
	check(not World.can_move(Vector2(2600, 1000), "foot", blocks), "ocean blocks walking")
	check(World.can_move(Vector2(2600, 1000), "boat", blocks), "boat moves through sea")
	check(not World.can_move(World.START, "boat", blocks), "boat cannot drive on land")
	check(World.can_move(Vector2(2430, 2125), "foot", blocks), "dock is walkable")
	check(not World.can_move(Vector2(2430, 2125), "boat", blocks), "dock blocks boats")
	check(World.can_move(World.PARK, "foot", blocks), "helicopter pad accessible")
	for kind in ["foot", "car", "helicopter", "boat"]:
		check(not World.can_move(Vector2(-10, 100), kind, blocks), "map bounds: " + kind)
	for block in blocks:
		check(World.can_move(block.door, "foot", blocks), "entrance accessible: " + block.name)
	had_save = FileAccess.file_exists(World.SAVE_PATH)
	if had_save:
		backup = FileAccess.get_file_as_string(World.SAVE_PATH)
		DirAccess.remove_absolute(World.SAVE_PATH)
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.paused = false
	scene.player = Vector2(1955, 2102)
	scene.interact()
	check(scene.room >= 0 and scene.blocks[scene.room].id == 24, "enter cafe")
	check(scene.chapter == 1 and scene.cash == 250, "Mara starts story")
	check(not scene.can_player_move(Vector2(110, 165)), "interior counter collision")
	scene.interact()
	check(scene.room == -1, "exit cafe")
	scene.player = Vector2(2100, 2180)
	scene.interact()
	check(scene.boarded == 0, "enter car")
	scene.player = Vector2(1040, 920)
	scene.fleet[0].pos = scene.player
	scene.update_game(0.016)
	check(scene.chapter == 2 and scene.cash == 700, "complete car delivery")
	scene.interact()
	check(scene.boarded == -1, "exit car")
	scene.player = World.PARK
	scene.interact()
	check(scene.boarded == 1 and scene.fleet[1].flying, "take off in helicopter")
	scene.interact()
	check(scene.boarded == 1, "cannot exit in midair")
	scene.player = Vector2(100, 100)
	scene.land()
	check(scene.fleet[1].flying, "unsafe landing rejected")
	scene.player = Vector2(1115, 1110)
	scene.land()
	check(scene.rooftop >= 0 and not scene.fleet[1].flying, "land on hotel rooftop")
	check(scene.chapter == 3 and scene.cash == 1400, "complete rooftop mission")
	scene.interact()
	check(scene.boarded == -1 and scene.rooftop >= 0, "walk on rooftop")
	check(not scene.can_player_move(Vector2(500, 500)), "cannot walk off rooftop")
	scene.player = scene.blocks[scene.rooftop].rect.position + Vector2(35, 40)
	scene.interact()
	check(scene.rooftop == -1, "elevator to street")
	check(scene.nearest_vehicle() != 1, "cannot enter roof helicopter from street")
	scene.interact()
	check(scene.room >= 0, "enter hotel lobby")
	scene.land()
	check(scene.rooftop >= 0 and scene.room == -1, "lobby elevator reaches rooftop")
	scene.player = scene.blocks[scene.rooftop].rect.position + Vector2(35, 40)
	scene.interact()
	scene.player = Vector2(2430, 2135)
	scene.interact()
	check(scene.boarded == 2, "board boat from dock")
	scene.player = Vector2(2750, 580)
	scene.fleet[2].pos = scene.player
	scene.interact()
	check(scene.boarded == 2, "cannot exit boat at open sea")
	scene.update_game(0.016)
	check(scene.chapter == 4 and scene.cash == 2300, "complete introductory chapter")
	check(scene.save_game(), "atomic local save succeeds")
	scene.chapter = 0
	scene.load_game()
	check(scene.chapter == 4, "progress restored")
	check(World.can_move(scene.player, "foot", blocks), "sea save restores safe ground")
	scene.boarded = -1
	scene.shoot()
	check(scene.bullets.size() == 1 and scene.wanted > 0, "gunfire and alert")
	scene.health = 0
	scene.update_game(0.016)
	check(scene.health == 100 and scene.player == World.START, "health recovery")
	var steer := InputEventScreenTouch.new()
	steer.index = 0
	steer.pressed = true
	steer.position = Vector2(150, 601) * scene.hud.scale
	scene.hud._input(steer)
	var fire := InputEventScreenTouch.new()
	fire.index = 1
	fire.pressed = true
	fire.position = Vector2(1090, 568) * scene.hud.scale
	scene.hud._input(fire)
	check(scene.stick.x > 0 and scene.fire_held, "independent multitouch steering and firing")
	fire.pressed = false
	scene.hud._input(fire)
	check(not scene.fire_held and scene.stick.x > 0, "releasing fire preserves steering")
	steer.pressed = false
	scene.hud._input(steer)
	check(scene.stick == Vector2.ZERO, "joystick release clears movement")
	scene.paused = true
	var resume := InputEventScreenTouch.new()
	resume.index = 0
	resume.pressed = true
	resume.position = Vector2(180, 455) * scene.hud.scale
	scene.hud._input(resume)
	check(not scene.paused, "native touch menu resumes game")
	check(scene.renderer.art.size() == 14, "all bundled graphics textures loaded")
	check(scene.renderer.art["player"].get_size() == Vector2(512, 1280), "eight-direction character animation atlas")
	check(scene.renderer.water_material.shader != null and scene.renderer.grading.material != null, "native water and grade shaders assigned")
	scene.graphics_high = false
	scene.save_game()
	scene.graphics_high = true
	scene.load_game()
	check(not scene.graphics_high, "graphics preference survives offline save/load")
	scene.graphics_high = true
	var file := FileAccess.open(World.SAVE_PATH, FileAccess.WRITE)
	file.store_string('{"version":1,"chapter":"bad"}')
	file.close()
	scene.load_game()
	check(scene.health == 100, "corrupt save ignored safely")
	if had_save:
		file = FileAccess.open(World.SAVE_PATH, FileAccess.WRITE)
		file.store_string(backup)
		file.close()
	else:
		DirAccess.remove_absolute(World.SAVE_PATH)
	scene.queue_free()
	await process_frame
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
