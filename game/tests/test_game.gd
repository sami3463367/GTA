extends SceneTree
const World=preload("res://scripts/world_data.gd")
const Nav=preload("res://scripts/city_navigation.gd")
var checks:=0
var failures:=0
var saved:=""
var had_save:=false
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error("FAIL: "+label)
	else:
		print("PASS: "+label)
func _initialize() -> void:
	call_deferred("run_tests")
func tick(game:Node2D,seconds:=0.6) -> void:
	for i in range(int(seconds/0.05)+1):
		game.update_game(0.05)
	game.renderer.sync_visuals(0.01)
func run_tests() -> void:
	var blocks:=World.buildings()
	check(blocks.size()==28,"28 closed city buildings")
	check(World.can_move(World.START,"foot",blocks),"safe initial position")
	for kind in ["foot","car","boat","helicopter"]:
		check(not World.can_move(Vector2(-10,10),kind,blocks),"world bounds: "+kind)
	check(not World.can_move(Vector2(200,200),"foot",blocks),"outside roof footprint is solid")
	check(World.can_move(Vector2(200,200),"helicopter",blocks),"flight can cross rooftops")
	check(not World.can_move(Vector2(2650,1200),"foot",blocks),"sea blocks feet")
	check(World.can_move(Vector2(2650,1200),"boat",blocks),"sea supports boat")
	for block in blocks:
		check(World.can_move(block.door,"foot",blocks),"entrance reachable: "+block.name)
	var nav:=Nav.new(blocks)
	check(nav.nodes.size()>100,"sidewalk graph populated")
	var route:=nav.path(Vector2(128,128),Vector2(2120,2110))
	check(route.size()>5,"AStar returns connected sidewalk route")
	for i in range(1,route.size()):
		check(nav.line_clear(route[i-1],route[i]),"path edge does not cross building")
	check(not nav.line_clear(Vector2(120,230),Vector2(440,230)),"building blocks combat line of sight")
	had_save=FileAccess.file_exists(World.SAVE_PATH)
	if had_save:
		saved=FileAccess.get_file_as_string(World.SAVE_PATH)
		DirAccess.remove_absolute(World.SAVE_PATH)
	var game=load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.paused=false
	check(game.renderer.terrain is TileMapLayer,"native textured city TileMapLayer")
	check(game.renderer.terrain.get_used_cells().size()>20000,"terrain is authored with textured tiles, not flat fills")
	check(game.renderer.ambient is CanvasModulate,"native ambient CanvasModulate")
	check(game.renderer.light_pool.size()==12 and game.renderer.headlamps.size()==2,"real native point light pools")
	check(game.doors.size()==3,"real entrance Area2D triggers")
	var cafe:int=game.building_index(24)
	var hotel:int=game.building_index(12)
	for i in range(blocks.size()):
		check(game.roof_alpha[i]==1 and not game.interior_visible(i),"default opaque roof / hidden interior %d"%i)
	check(not game.renderer.cast_sprites[0].body.visible,"Mara occluded from outside")
	var roof_image:Image=game.renderer.art["building_0"].get_image()
	check(roof_image.get_pixel(130,120).a==1,"roof texture fully opaque at center")
	game.player=blocks[cafe].door
	game.request_enter(cafe)
	check(game.room==cafe and game.chapter==0,"entry opens only cafe, does NOT auto-complete quest")
	game.update_game(0.18)
	check(game.roof_alpha[cafe]>0 and game.roof_alpha[cafe]<1,"smooth roof fade in progress")
	check(game.roof_alpha[hotel]==1 and not game.interior_visible(hotel),"neighbor interior remains hidden")
	tick(game)
	check(game.roof_alpha[cafe]==0,"selected roof fades fully out")
	check(game.renderer.floor_layer.visible,"textured indoor TileMap floor enabled")
	check(game.renderer.cast_sprites[0].body.visible,"Mara visible only inside cafe")
	check(not game.can_player_move(blocks[cafe].rect.position+Vector2(70,65)),"counter has collision")
	game.player=game.cast[0].pos+Vector2(0,28)
	game.interact()
	check(not game.dialogue.is_empty(),"nearby NPC starts dialogue")
	game.choose_dialogue(2)
	check(game.chapter==0 and game.dialogue.is_empty(),"declining leaves quest unchanged")
	game.interact()
	game.choose_dialogue(0)
	check(game.dialogue.node=="mara_truth","branching information dialogue")
	game.choose_dialogue(0)
	check(game.chapter==1,"explicit acceptance starts package delivery")
	game.request_exit()
	game.update_game(0.18)
	check(game.room==cafe and game.roof_alpha[cafe]>0,"exit fades roof before moving to street")
	tick(game)
	check(game.room==-1 and game.roof_alpha[cafe]==1,"exiting restores opaque roof")
	check(not game.renderer.cast_sprites[0].body.visible and not game.renderer.floor_layer.visible,"exit hides indoor NPC and floor completely")
	game.player=game.cast[1].pos+Vector2(-25,0)
	game.interact()
	game.choose_dialogue(0)
	check(game.chapter==2 and game.branch=="careful","delivery dialogue records chosen branch")
	game.player=blocks[hotel].door
	game.door_cooldown=0
	game.request_enter(hotel)
	tick(game)
	game.player=game.cast[2].pos+Vector2(0,30)
	game.interact()
	game.choose_dialogue(0)
	check(game.dialogue.node=="rafe_police","second NPC has authored dialogue branch")
	game.choose_dialogue(0)
	check(game.chapter==3,"Rafe unlocks rooftop objective")
	game.request_exit()
	tick(game)
	game.player=World.PARK
	game.use_vehicle()
	check(game.boarded==-1 and game.transition.kind=="board","boarding begins smooth transition")
	tick(game,0.3)
	check(game.boarded==1 and game.fleet[1].flying,"helicopter boarding completes")
	game.use_vehicle()
	check(game.boarded==1 and game.transition.is_empty(),"cannot leave helicopter in midair")
	game.player=Vector2(1115,1110)
	game.land()
	check(game.rooftop==hotel and game.chapter==4,"rooftop landing advances evidence quest")
	check(game.roof_alpha[hotel]==1 and not game.interior_visible(hotel),"rooftop landing does not unmask interior")
	game.use_vehicle()
	tick(game,0.3)
	check(game.boarded==-1 and game.rooftop==hotel,"step onto rooftop")
	game.player=blocks[hotel].rect.position+Vector2(35,40)
	game.interact()
	check(game.rooftop==-1,"rooftop lift returns to street")
	game.player=game.cast[1].pos+Vector2(-25,0)
	game.interact()
	game.choose_dialogue(1)
	check(game.chapter==5 and game.branch=="public_signal","final choice changes narrative flag")
	game.player=Vector2(2430,2135)
	game.use_vehicle()
	tick(game,0.3)
	check(game.boarded==2,"board speedboat from dock")
	game.player=Vector2(2750,580)
	game.fleet[2].pos=game.player
	game.use_vehicle()
	check(game.transition.is_empty() and game.boarded==2,"unsafe open-water exit rejected")
	game.update_game(0.05)
	check(game.chapter==6 and game.cash==2400,"complete story with all rewards")
	check(game.save_game(),"atomic save succeeds")
	game.chapter=0
	game.load_game()
	check(game.chapter==6 and game.branch=="public_signal","quest and branch restore offline")
	check(World.can_move(game.player,"foot",blocks),"sea save restores safe land")
	game.boarded=-1
	game.ammo=1
	game.shoot()
	check(game.ammo==0 and game.bullets.size()>0,"magazine and projectile system")
	game.reload_weapon()
	tick(game,1.1)
	check(game.ammo==30 and game.reserve==90,"reload moves ammunition from reserve")
	var hp:float=game.health
	game.apply_damage(20)
	check(game.health<hp and game.armor<50 and game.damage_flash>0 and game.shake>0,"armor, damage flash and camera shake")
	var traffic_start:Vector2=game.fleet[5].pos
	for i in range(20):game.update_traffic(0.05)
	check(game.fleet[5].pos.distance_to(traffic_start)>1,"traffic follows authored lane waypoints")
	game.wanted=2
	game.update_people(0.05)
	check(game.people[0].state in ["chase","cover","attack"],"hostile AI enters combat state")
	game.hud.perform("fire",-1,1)
	game.hud.press_at(Vector2(145,590),0)
	check(game.fire_held and game.stick.x>0,"independent touch fire and joystick")
	game.hud.release_pointer(1)
	check(not game.fire_held and game.stick.x>0,"releasing fire preserves movement touch")
	game.hud.release_pointer(0)
	check(game.stick==Vector2.ZERO,"touch release clears movement")
	game.graphics_high=false
	game.save_game()
	game.graphics_high=true
	game.load_game()
	check(not game.graphics_high,"graphics option persists")
	var file:=FileAccess.open(World.SAVE_PATH,FileAccess.WRITE)
	file.store_string('{"version":2,"chapter":"invalid"}')
	file.close()
	var stage:int=game.chapter
	game.load_game()
	check(game.chapter==stage,"corrupt save ignored")
	if had_save:
		file=FileAccess.open(World.SAVE_PATH,FileAccess.WRITE)
		file.store_string(saved)
		file.close()
	else:
		DirAccess.remove_absolute(World.SAVE_PATH)
	game.queue_free()
	await process_frame
	print("RESULT: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
