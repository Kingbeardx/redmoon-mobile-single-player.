extends RefCounted
## Complete replacement combat pipeline; native arithmetic with explicit offline
## hit floors and defense limits. Not a claim of bit-identical JCE behavior.
var random:=RandomNumberGenerator.new()
func _init() -> void:random.randomize()
func hit_chance(attack: int,defense: int,bonus: int=0,multiplier: float=1) -> int:
	var total: int=maxi(1,attack+defense)
	var difference: int=50*absi(attack-defense)/total
	return clampi(int((50+(difference if attack>defense else -difference)+bonus)*multiplier),5,99)
func player_hit(w,enemy: Dictionary) -> bool:
	var dex: int=int(w.monster_metadata.get(int(enemy.get("monster_id",0)),{}).get("dexterity",10))
	if float(enemy.get("stealth_time",0))>0:dex*=2
	var bonus: int=15 if not w.skills.active("concentration").is_empty() and w.skills.equipped_weapon() in ["gun","firearm"] else 0
	var mult: float=1.2 if not w.skills.active("luck").is_empty() else 1
	# Offline playability floor; original arithmetic above remains independently testable.
	return random.randi_range(0,99)<maxi(65,hit_chance(w.movement_dexterity(),dex,bonus,mult))
func monster_hit(w,enemy: Dictionary) -> bool:
	var dex: int=int(w.monster_metadata.get(int(enemy.get("monster_id",0)),{}).get("dexterity",10))
	return random.randi_range(0,99)<mini(85,hit_chance(dex,w.movement_dexterity()))
func monster_health(w,id: int) -> int:
	var power: int=maxi(0,int(w.monster_metadata.get(id,{}).get("constitution",10)))
	return maxi(1,50+(power/15)*(power/10))
func monster_damage(w,enemy: Dictionary,psychic: bool=false) -> int:
	if enemy.has("scaled_encounter"):return maxi(2,w.max_hp()/20)
	if enemy.has("campaign_id"):return maxi(2,w.max_hp()/15+int(enemy["campaign_id"]))
	var row: Dictionary=w.monster_metadata.get(int(enemy.get("monster_id",0)),{})
	var damage: int=maxi(1,w.rules.strength_attack(int(row.get("spirit" if psychic else "strength",10))))
	return mini(damage,maxi(4,w.max_hp()/6)) if bool(enemy.get("starter",false)) else damage
func mitigation(amount: int,power: int,armor: int) -> int:
	var reduced: int=maxi(1,amount-maxi(0,armor))
	return maxi(1,reduced*(100-mini(50,int(maxi(0,power)*.009)))/100)

func minimum_attack(strength: int,dexterity: int) -> int:
	var total: int=strength+dexterity
	if total<=0:return 75
	var difference: int=75*absi(dexterity-strength)/total
	return clampi(75+(difference if dexterity>=strength else -difference),1,100)
func roll_damage(w,amount: int,psychic: bool=false) -> int:
	var minimum: int=85 if psychic else minimum_attack(w.effective_stat("strength"),w.movement_dexterity())
	return maxi(1,amount*random.randi_range(minimum,100)/100)
