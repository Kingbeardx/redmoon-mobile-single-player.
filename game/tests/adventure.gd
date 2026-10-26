extends SceneTree
const World = preload("res://scripts/world.gd")
var failures: int = 0
func check(value: bool, description: String) -> void:
	if not value:
		failures += 1
		push_error(description)
func _initialize() -> void:
	var w = World.new()
	check(w.initialize(), "initialize")
	w.inventory = {"1:1": 1, "4:1": 2}
	check(w.item_name("1:1") != "Recovered item 1:1", "decoded item names")
	w.use_item("1:1")
	check(w.weapon_bonus == 6, "equip")
	w.hp = 50
	w.use_item("4:1")
	check(w.hp == 75 and w.inventory["4:1"] == 1, "consumable")
	w.gold = 30
	w.shop_available = true
	var heals: int = w.potions
	w.buy_heal()
	check(w.gold == 15 and w.potions == heals + 1, "purchase")
	w.sell_item("4:1")
	check(w.gold == 20 and w.inventory["4:1"] == 0, "sale")
	w.defeated = 10
	w.claim_bounty()
	w.claim_bounty()
	check(w.gold == 120, "one-time bounty")
	w.character_id = 2
	check(w.save_game("user://adventure-test.json") == OK, "save")
	var restored = World.new()
	restored.initialize()
	check(restored.load_game("user://adventure-test.json") and restored.gold == 120 and restored.weapon_bonus == 6 and restored.character_id == 2, "extended save roundtrip")
	DirAccess.remove_absolute("user://adventure-test.json")
	print("ADVENTURE CHECKS: 9 checks, ", failures, " failures")
	quit(1 if failures else 0)
