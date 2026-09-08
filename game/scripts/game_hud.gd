extends Node2D
## Custom textured HUD and hit-tested native touch UI. No default Buttons or ProgressBars.
const World=preload("res://scripts/world_data.gd")
var game:Node2D
var art:Dictionary
var font:Font=preload("res://assets/fonts/HarborSans.ttf")
var bold:Font=preload("res://assets/fonts/HarborSans-Bold.ttf")
var panel_style:StyleBoxTexture
var button_style:StyleBoxTexture
var joystick_center:=Vector2(115,590)
var joystick_id:=-1
var fire_touch_id:=-1
var thumb:=Vector2.ZERO
var hover:=Vector2(-100,-100)
var lag_health:=100.0
var reset_pending:=false
var hits:Array[Dictionary]=[]

func _ready() -> void:
	art=game.renderer.art
	panel_style=StyleBoxTexture.new()
	panel_style.texture=art["ui_panel"]
	button_style=StyleBoxTexture.new()
	button_style.texture=art["ui_button"]
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		panel_style.set_texture_margin(side,18)
		button_style.set_texture_margin(side,16)

func panel(rect:Rect2) -> void:
	draw_style_box(panel_style,rect)

func text(value:String,point:Vector2,size:=14,color:=Color("e5eee9"),strong:=false) -> void:
	draw_string(bold if strong else font,point,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func paragraph(value:String,point:Vector2,width:float,size:=14,color:=Color("b9cbc9"),spacing:=21.0) -> void:
	var line:=""
	var y:=point.y
	for word in value.split(" "):
		if font.get_string_size(line+word,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>width and not line.is_empty():
			text(line,Vector2(point.x,y),size,color)
			y+=spacing
			line=""
		line+=word+" "
	text(line,Vector2(point.x,y),size,color)

func image(key:String,rect:Rect2,tint:=Color.WHITE) -> void:
	draw_texture_rect(art[key],rect,false,tint)

func hit(rect:Rect2,action:String,value:=-1) -> void:
	hits.append({"rect":rect,"action":action,"value":value})

func action_button(rect:Rect2,icon:String,title:String,action:String,active:=false) -> void:
	var highlighted:=rect.has_point(hover) or active
	image("control",rect,Color("bdded3") if highlighted else Color.WHITE)
	var center:=rect.get_center()
	var extent:=rect.size.x*0.50
	image("icon_"+icon,Rect2(center-Vector2.ONE*extent/2,Vector2.ONE*extent),Color("f5d794") if active else Color("e4eee7"))
	var tw:=font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,9).x
	text(title,Vector2(center.x-tw/2,rect.end.y+11),9,Color("d4e1d5"))
	hit(rect,action)

func text_button(rect:Rect2,title:String,action:String,value:=-1) -> void:
	draw_style_box(button_style,rect)
	if rect.has_point(hover):
		image("light",rect,Color(0.2,0.6,0.8,0.28))
	text(title,rect.position+Vector2(18,rect.size.y/2+5),14,Color("e6eee2"),true)
	hit(rect,action,value)

func _process(dt:float) -> void:
	scale=get_viewport_rect().size/Vector2(1280,720)
	thumb=thumb.lerp(game.stick,minf(1,dt*20))
	lag_health=lerpf(lag_health,game.health,minf(1,dt*1.7))
	if game.paused or not game.dialogue.is_empty():
		joystick_id=-1
		fire_touch_id=-1
		game.stick=Vector2.ZERO
	queue_redraw()

func _input(event:InputEvent) -> void:
	if event is InputEventMouseMotion:
		hover=event.position/scale
		if joystick_id==-2:
			game.stick=((hover-joystick_center)/54).limit_length()
	if event is InputEventScreenDrag and event.index==joystick_id:
		game.stick=((event.position/scale-joystick_center)/54).limit_length()
	if event is InputEventScreenTouch:
		if event.pressed:
			press_at(event.position/scale,event.index)
		else:
			release_pointer(event.index)
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:
			press_at(event.position/scale,-2)
		else:
			release_pointer(-2)

func press_at(point:Vector2,pointer:int) -> void:
	if not game.paused and game.dialogue.is_empty() and point.distance_to(joystick_center)<90:
		joystick_id=pointer
		game.stick=((point-joystick_center)/54).limit_length()
		get_viewport().set_input_as_handled()
		return
	for target in hits:
		if target.rect.has_point(point):
			perform(target.action,target.value,pointer)
			get_viewport().set_input_as_handled()
			return
	if not game.dialogue.is_empty() and point.y>435:
		game.dialogue_age=100

func release_pointer(pointer:int) -> void:
	if pointer==joystick_id:
		joystick_id=-1
		game.stick=Vector2.ZERO
	if pointer==fire_touch_id:
		fire_touch_id=-1
		game.fire_held=false

func perform(action:String,value:=-1,pointer:=-2) -> void:
	match action:
		"fire":
			fire_touch_id=pointer
			game.fire_held=true
			game.shoot()
		"talk":game.interact()
		"vehicle":game.use_vehicle()
		"land":game.land()
		"sprint":game.sprint=not game.sprint
		"reload":game.reload_weapon()
		"pause":game.toggle_pause()
		"resume":game.paused=false;reset_pending=false
		"sound":game.sound_enabled=not game.sound_enabled;game.save_game()
		"graphics":game.graphics_high=not game.graphics_high;game.save_game()
		"new":
			if reset_pending:
				game.reset_story()
				game.paused=false
				reset_pending=false
			else:
				reset_pending=true
		"choice":game.choose_dialogue(value)

func _draw() -> void:
	if art==null:
		return
	hits.clear()
	if game.paused:
		draw_menu()
		return
	draw_status()
	draw_radar()
	draw_quest()
	if not game.dialogue.is_empty():
		draw_dialogue()
	else:
		image("stick_base",Rect2(joystick_center-Vector2(84,84),Vector2(168,168)))
		image("light",Rect2(joystick_center+thumb*32-Vector2(58,58),Vector2(116,116)),Color(0.3,0.9,0.85,0.22+thumb.length()*0.25))
		image("stick_thumb",Rect2(joystick_center+thumb*47-Vector2(32,32),Vector2(64,64)))
		text("MOVE",joystick_center+Vector2(-17,104),10,Color("bed2cf"))
		action_button(Rect2(1160,518,90,90),"shoot","FIRE","fire",game.fire_held)
		action_button(Rect2(1052,552,77,77),"talk","TALK / E","talk",not game.nearest_npc().is_empty())
		action_button(Rect2(1127,629,70,70),"vehicle","VEHICLE / F","vehicle",game.boarded>=0)
		action_button(Rect2(1208,635,61,61),"sprint","SPRINT","sprint",game.sprint)
		action_button(Rect2(1048,642,58,58),"land","LAND / L","land")
		draw_context()
	if game.damage_flash>0:
		image("damage",Rect2(0,0,1280,720),Color(1,1,1,game.damage_flash))
	if game.notice_time>0 and game.dialogue.is_empty():
		panel(Rect2(329,636,650,59))
		paragraph(game.notice,Vector2(349,660),610,13,Color("d8e8d9"),19)

func draw_status() -> void:
	# Floating portrait + luminous textured segmented gauges, rather than a health box.
	image("portrait_hero",Rect2(24,23,88,88))
	text("AZURE HARBOR",Vector2(126,38),13,Color("edf0df"),true)
	text("THE LEDGER",Vector2(126,54),9,Color("afc8c7"))
	image("ui_button",Rect2(123,62,198,19),Color("657b82"))
	var lag_width:=190*clampf(lag_health/100,0,1)
	if lag_width>0:
		draw_texture_rect_region(art["health_lag"],Rect2(127,65,lag_width,11),Rect2(0,0,256*clampf(lag_health/100,0,1),20))
	var hp_width:=190*clampf(game.health/100,0,1)
	if hp_width>0:
		draw_texture_rect_region(art["health"],Rect2(127,65,hp_width,11),Rect2(0,0,256*clampf(game.health/100,0,1),20))
	image("ui_button",Rect2(123,84,198,12),Color("657b82"))
	if game.armor>0:
		draw_texture_rect_region(art["armor"],Rect2(127,86,190*game.armor/100,7),Rect2(0,0,256*game.armor/100,20))
	image("icon_shoot",Rect2(124,102,26,26))
	text("RELOADING" if game.reload_timer>0 else "%02d / %03d"%[game.ammo,game.reserve],Vector2(157,121),15,Color("e4e9d9"),true)
	image("icon_reload",Rect2(272,103,24,24),Color("95c8cd"))
	hit(Rect2(122,98,199,34),"reload")
	text("$ %s"%game.cash,Vector2(28,133),12,Color("cfe2bd"))
	var clock_hour:=(12+int(game.clock/7.5))%24
	text("%02d:%02d"%[clock_hour,int(fposmod(game.clock,7.5)/7.5*60)],Vector2(349,42),13,Color("d4e4dd"))
	text("OFFLINE",Vector2(349,57),9,Color("99b6b7"))
	for i in range(5):
		image("icon_shoot",Rect2(346+i*16,74,13,13),Color("f09378") if i<ceili(game.wanted) else Color(0.5,0.6,0.6,0.25))
	action_button(Rect2(962,25,45,45),"pause","","pause")

func draw_radar() -> void:
	panel(Rect2(1027,18,236,220))
	var origin:=Vector2(1038,29)
	var size:=Vector2(213,184)
	image("radar_map",Rect2(origin,size),Color("a1c3c7"))
	var ratio:=size/World.SIZE
	for npc in game.people:
		if npc.hostile and npc.alive and game.wanted>=1:
			image("icon_shoot",Rect2(origin+npc.pos*ratio-Vector2(5,5),Vector2(10,10)),Color("ff7b73"))
	if game.chapter<game.story.size()-1:
		var point:Vector2=origin+game.objective_point()*ratio
		image("icon_waypoint",Rect2(point-Vector2(6,6),Vector2(12,12)),Color("f6db96"))
	var p:Vector2=origin+game.player*ratio
	draw_set_transform(p,game.heading+PI/2)
	image("icon_waypoint",Rect2(-7,-7,14,14),Color("e7ffff"))
	draw_set_transform(Vector2.ZERO)
	text("N ↑",Vector2(1040,229),10,Color("d9e3bd"))
	text("AZURE COAST",Vector2(1150,229),10,Color("afc8c7"))

func draw_quest() -> void:
	panel(Rect2(24,153,362,124))
	text("STORY  /  %02d"%mini(game.chapter+1,6),Vector2(43,177),10,Color("c4d79e"),true)
	text(game.story[game.chapter].title,Vector2(43,202),17,Color("edf0df"),true)
	paragraph(game.story[game.chapter].text,Vector2(43,224),324,12,Color("adc5c7"),18)
	if game.chapter<game.story.size()-1 and game.dialogue.is_empty():
		var difference:Vector2=game.objective_point()-game.player
		if difference.length()>170:
			var p:=Vector2(640,355)+difference.normalized()*174
			draw_set_transform(p,difference.angle()+PI/2)
			image("icon_waypoint",Rect2(-12,-15,24,30),Color("f4df9e"))
			draw_set_transform(Vector2.ZERO)
			text("%d m"%int(difference.length()),p+Vector2(-16,32),10,Color("e7e8c2"))

func draw_context() -> void:
	var prompt:=""
	var npc:Dictionary=game.nearest_npc()
	if not npc.is_empty():
		prompt="Talk to %s  [E / Touch]"%npc.name.split(" ")[0].capitalize()
	elif not game.nearby_vending().is_empty():
		prompt="Vending machine · Drink $15 [E / Talk]"
	elif game.room>=0:
		prompt="Walk to the south doorway to leave" if not game.blocks[game.room].helipad else "Talk nearby · L / LAND: rooftop elevator"
	elif game.rooftop>=0 and game.boarded<0:
		prompt="E at the lift · F beside the helicopter"
	elif game.boarded>=0:
		prompt="F / Vehicle: exit safely · L: helicopter landing"
	elif game.nearest_vehicle()>=0:
		prompt="Enter %s  [F / Vehicle]"%game.fleet[game.nearest_vehicle()].kind
	else:
		for b in game.blocks:
			if b.interior and game.player.distance_to(b.door)<70:
				prompt="Step through the marked doorway  [E / Touch]"
	if not prompt.is_empty():
		panel(Rect2(411,496,458,43))
		text(prompt,Vector2(428,523),12,Color("dfebca"))
	text("WASD Move   E Talk   F Vehicle   R Reload   L Land   Shift Sprint",Vector2(371,713),10,Color("9fbab9"))

func draw_dialogue() -> void:
	panel(Rect2(20,437,1240,265))
	image("portrait_"+game.speaker.portrait,Rect2(43,461,105,105))
	text(game.speaker.name,Vector2(170,473),20,Color("e9e9d0"),true)
	text(game.speaker.role,Vector2(171,492),10,Color("8bb7bd"))
	var visible_chars:=int(game.dialogue_age*95)
	var spoken:String=game.dialogue.text
	paragraph(spoken.substr(0,visible_chars),Vector2(171,521),513,15,Color("c5d8d5"),23)
	text("CHOOSE YOUR RESPONSE",Vector2(735,467),10,Color("c5d69b"),true)
	for i in range(game.dialogue.choices.size()):
		var rect:=Rect2(725,480+i*67,508,57)
		draw_style_box(button_style,rect)
		if rect.has_point(hover):
			image("light",rect,Color(0.25,0.65,0.65,0.25))
		text(str(i+1),rect.position+Vector2(14,33),15,Color("e2d29a"),true)
		paragraph(game.dialogue.choices[i].label,rect.position+Vector2(41,23),447,13,Color("dce7dc"),19)
		hit(rect,"choice",i)
	text("1 / 2 / 3 to choose  ·  Esc to leave  ·  Tap text to reveal",Vector2(171,681),10,Color("83a9b1"))

func draw_menu() -> void:
	image("ui_panel",Rect2(0,0,1280,720),Color(0.7,0.8,0.85,0.65))
	panel(Rect2(47,70,575,584))
	text("AZURE HARBOR",Vector2(83,142),38,Color("e8ecda"),true)
	text("THE LEDGER",Vector2(85,175),18,Color("c5d799"),true)
	paragraph("A missing flight log. A sealed ledger. A harbor that refuses to disappear. Talk to the people who call this city home—and choose how to help them.",Vector2(85,221),488,15,Color("b4cfcc"),24)
	text_button(Rect2(82,324,506,57),"RESUME YOUR STORY" if game.clock>1 else "ENTER AZURE HARBOR","resume")
	text_button(Rect2(82,397,245,48),"SOUND: ON" if game.sound_enabled else "SOUND: OFF","sound")
	text_button(Rect2(341,397,247,48),"GRAPHICS: HIGH" if game.graphics_high else "GRAPHICS: LITE","graphics")
	text_button(Rect2(82,460,506,48),"CONFIRM RESET (CLEARS SAVE)" if reset_pending else "START A NEW STORY","new")
	paragraph("Walk into the cafe doorway. Approach Mara, then TALK. Use the separate vehicle icon to enter a car. Reload with R or tap the ammo indicator. Rooftop elevator: L inside Meridian.",Vector2(85,544),488,12,Color("90b1b6"),20)
	text("NATIVE GODOT  /  SHARED ANDROID + WEB BUILD  /  v0.4",Vector2(85,630),10,Color("bfd4b9"))
	image("portrait_mara",Rect2(877,293,155,155))
	text("Every name",Vector2(804,505),37,Color("e7eddf"),true)
	text("has a story.",Vector2(804,552),37,Color("d2dfac"),true)
