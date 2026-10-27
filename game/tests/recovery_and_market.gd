extends SceneTree
const World=preload("res://scripts/world.gd")
var failures: int=0
var checks: int=0
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:
		failures+=1
		push_error(label)
func _initialize() -> void:
	var w=World.new()
	w.initialize()
	w.gold=500
	var stock: Array=w.zone_stock()
	check(stock.size()>0,"source market stock exists")
	var item: Dictionary={}
	for candidate in stock:
		if int(candidate["price"])>0:
			item=candidate
			break
	check(not item.is_empty(),"nonzero-price source stock available")
	w.gold=int(item["price"])+100
	var gold: int=w.gold
	check(w.buy_stock(item["purchase_key"]),"buy source-listed item")
	check(w.gold==gold-int(item["price"]) and int(w.inventory[item["key"]])>0,"purchase updates inventory and gold")
	w.gold=0
	check(not w.buy_stock(item["purchase_key"]),"purchase refuses insufficient gold")
	var path: String="user://recovery-market-test.json"
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path+".bak")
	w.gold=25
	w.save_game(path)
	w.gold=50
	w.save_game(path)
	check(FileAccess.file_exists(path+".bak"),"backup created")
	var broken=FileAccess.open(path,FileAccess.WRITE)
	broken.store_string("{damaged");broken.close()
	var restored=World.new()
	restored.initialize()
	check(restored.load_game(path) and restored.gold==25,"corrupt save recovers last known good backup")
	check(restored.purchases==w.purchases,"purchase state survives recovery")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path+".bak")
	print("RECOVERY / MARKET: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
