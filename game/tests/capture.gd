extends SceneTree
var game:Node2D
var output:=""
func _initialize() -> void:
	call_deferred("run")
func capture(name:String) -> void:
	game.renderer.sync_visuals(0.02)
	game.renderer.queue_redraw()
	game.hud.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png(output.path_join(name+".png"))!=OK:
		push_error("Native capture failed: "+name)
		quit(1)
func settle(seconds:=0.65) -> void:
	for i in range(int(seconds/0.05)+1):game.update_game(0.05)
	game.camera=game.player
func run() -> void:
	output=ProjectSettings.globalize_path("res://").path_join("../artifacts")
	DirAccess.make_dir_recursive_absolute(output)
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.reset_story()
	await capture("native-menu")
	game.paused=false
	game.camera_zoom=1.12
	await capture("native-city")
	var cafe:int=game.building_index(24)
	game.player=game.blocks[cafe].door+Vector2(0,20)
	game.camera=game.player
	await capture("native-roof-closed")
	game.player=game.blocks[cafe].door
	game.request_enter(cafe)
	game.update_game(0.2)
	await capture("native-roof-fading")
	settle()
	game.camera=game.blocks[cafe].rect.get_center()
	game.camera_zoom=2.0
	await capture("native-interior")
	game.player=game.cast[0].pos+Vector2(0,30)
	game.interact()
	game.dialogue_age=10
	await capture("native-dialogue")
	game.close_dialogue()
	game.request_exit()
	settle()
	await capture("native-roof-restored")
	game.player=WorldStart()
	game.clock=90
	game.camera=game.player
	game.camera_zoom=1.0
	game.use_vehicle()
	settle(0.3)
	await capture("native-night")
	game.graphics_high=false
	await capture("native-city-lite")
	game.graphics_high=true
	game.boarded=-1
	game.player=Vector2(1530,1580)
	game.use_vehicle()
	settle(0.3)
	game.player=Vector2(1115,1110)
	game.land()
	game.use_vehicle()
	settle(0.3)
	game.clock=12
	await capture("native-rooftop")
	print("Native UI, interior, roof transition and lighting captures complete.")
	quit(0)
func WorldStart() -> Vector2:
	return Vector2(2100,2180)
