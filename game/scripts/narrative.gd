extends RefCounted
## Data-driven branching dialogue. Only explicit quest choices complete talk/delivery objectives.
static func quests() -> Array[Dictionary]:
	return [
		{"title":"A name in the ledger","text":"Talk to Mara, the informant inside the marina cafe.","kind":"talk","npc":"mara","building":24,"point":Vector2(1955,2102),"reward":0},
		{"title":"The sealed package","text":"Deliver Mara's package to Inez at the marina docks.","kind":"delivery","npc":"inez","building":-1,"point":Vector2(2370,2100),"reward":500},
		{"title":"Above the noise","text":"Talk to Rafe inside Meridian Hotel. Learn who owns the flight log.","kind":"talk","npc":"rafe","building":12,"point":Vector2(1115,1262),"reward":150},
		{"title":"The rooftop rendezvous","text":"Take the Sunset Park helicopter. Land on Meridian Hotel's rooftop H.","kind":"land","npc":"","building":-1,"point":Vector2(1115,1110),"reward":700},
		{"title":"A way off the island","text":"Return to Inez at the docks. Decide how to deliver the evidence.","kind":"talk","npc":"inez","building":-1,"point":Vector2(2370,2100),"reward":150},
		{"title":"Beyond the breakwater","text":"Take the marina speedboat to the offshore buoy with the evidence.","kind":"boat","npc":"","building":-1,"point":Vector2(2750,580),"reward":900},
		{"title":"A harbor worth keeping","text":"Chapter complete. The evidence is safe. Explore Azure Harbor freely.","kind":"free","npc":"","building":-1,"point":Vector2(2080,2180),"reward":0}]

static func characters() -> Array[Dictionary]:
	return [
		{"id":"mara","name":"MARA VOSS","role":"CAFE OWNER / INFORMANT","portrait":"mara","building":24,"local":Vector2(98,101),"pos":Vector2.ZERO},
		{"id":"inez","name":"INEZ ROCHA","role":"DOCKMASTER","portrait":"inez","building":-1,"local":Vector2.ZERO,"pos":Vector2(2370,2100)},
		{"id":"rafe","name":"RAFE SOL","role":"MERIDIAN CONCIERGE","portrait":"rafe","building":12,"local":Vector2(114,64),"pos":Vector2.ZERO}]

static func dialogue(npc: String, stage: int, branch: String) -> Dictionary:
	if npc == "mara" and stage == 0:
		return {"node":"mara_offer","text":"You came back at the wrong time. Someone is buying this harbor one frightened signature at a time. I copied their ledger. Will you take it to Inez?", "choices":[
			{"label":"Who is behind the buyout?","next":"mara_truth"},
			{"label":"I'll take the package. Keep the cafe open.","action":"complete"},
			{"label":"Not yet. I need to look around.","action":"close"}]}
	if npc == "inez" and stage == 1:
		return {"node":"inez_package","text":"Mara trusts you, so I will too. That package proves who is paying the patrols. Rafe at Meridian has the flight log that ties it together. Did anyone follow you?", "choices":[
			{"label":"No. Here's the sealed package.","action":"complete","flag":"careful"},
			{"label":"Maybe. We should move quickly.","action":"complete","flag":"bold"},
			{"label":"Hold on. Let me check the docks.","action":"close"}]}
	if npc == "rafe" and stage == 2:
		return {"node":"rafe_log","text":"Inez warned me. The ledger is not enough without the flight log. Meet my contact on our roof. Use the helicopter in Sunset Park; the elevator cannot bring the evidence out unnoticed.", "choices":[
			{"label":"Why not give the log to the police?","next":"rafe_police"},
			{"label":"I'll take the helicopter.","action":"complete"},
			{"label":"I need a moment.","action":"close"}]}
	if npc == "inez" and stage == 4:
		return {"node":"inez_escape","text":"You got the log. Good. A reporter waits beyond the breakwater. " + ("You have been careful. Let's keep it that way." if branch == "careful" else "After all that noise, we cannot linger."), "choices":[
			{"label":"Send a quiet signal. I'll use the speedboat.","action":"complete","flag":"quiet_signal"},
			{"label":"Tell them the truth is coming, loud and clear.","action":"complete","flag":"public_signal"},
			{"label":"I'll return after checking the city.","action":"close"}]}
	var text := "This harbor is more than a business. Finish what you started."
	if stage == 6:
		text = "The reporter has the evidence. For the first time in months, this city can breathe. You helped us keep our home."
	return {"node":"ambient","text":text,"choices":[{"label":"I'll see you around.","action":"close"}]}

static func branch_node(node: String) -> Dictionary:
	match node:
		"mara_truth":
			return {"node":node,"text":"A company called Meridian Holdings. Not the hotel staff—the people above them. They use debt, not bulldozers. Inez knows which boats carry their money.","choices":[{"label":"Then let's give Inez the ledger.","action":"complete"},{"label":"I need to think about this.","action":"close"}]}
		"rafe_police":
			return {"node":node,"text":"Some officers still care. Others appear in the ledger. I cannot tell which is which anymore. Get it to someone who can publish it, not bury it.","choices":[{"label":"Understood. I'll meet your contact on the roof.","action":"complete"},{"label":"I'll return when I'm ready.","action":"close"}]}
	return {}
