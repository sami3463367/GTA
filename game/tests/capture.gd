extends SceneTree
## Native rendered smoke test, run under Xvfb on CI. Screenshots are build artifacts.
var game: Node2D
var output := ""

func _initialize() -> void:
	call_deferred("capture_views")

func capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var result := image.save_png(output.path_join(name + ".png"))
	if result != OK:
		push_error("Could not save native screenshot: " + name)
		quit(1)

func capture_views() -> void:
	output = ProjectSettings.globalize_path("res://").path_join("../artifacts")
	DirAccess.make_dir_recursive_absolute(output)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	await capture("native-menu")
	game.paused = false
	game.renderer.queue_redraw()
	game.hud.queue_redraw()
	await capture("native-city")
	game.player = Vector2(1955, 2102)
	game.interact()
	game.camera = Vector2(350, 300)
	game.renderer.queue_redraw()
	game.hud.queue_redraw()
	await capture("native-interior")
	game.interact()
	game.player = Vector2(1530, 1580)
	game.interact()
	game.player = Vector2(1115, 1110)
	game.land()
	game.interact()
	game.camera = game.player
	game.renderer.queue_redraw()
	game.hud.queue_redraw()
	await capture("native-rooftop")
	print("Native rendered smoke test complete.")
	quit(0)
