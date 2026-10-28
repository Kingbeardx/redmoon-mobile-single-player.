extends RefCounted
## Pure arithmetic recovered statically from the original server. These do not
## claim to replace the complete original hit/equipment/party combat pipeline.
var experience: Array[int]=[0,20]
const GROWTH = [[8,20,10,10],[10,18,8,12],[15,10,10,13],[14,10,14,10],[15,8,10,15],[14,10,12,12],[10,15,13,10],[12,12,12,12],[8,10,20,10]]

func _init() -> void:
	for n in range(2,1001):
		var rem: int=n%100;var factor: int=1
		if rem>=95:factor=2*rem-187
		elif n>=100 and rem<=3:factor=9-2*rem
		experience.append((experience[-1]+factor*n*n)&0xffffffff)
	# Constructor 0x442371: levels 900..998 are multiplied by eight.
	for n in range(900,999):experience[n]=(experience[n]*8)&0xffffffff

func required_xp(level: int) -> int:return maxi(1,experience[clampi(level,1,1000)])

static func danger_max(power: int) -> int:
	if power<=10000:return maxi(1,(50+((power*power)&0xffffffff)/150)&0xffffffff)
	return maxi(1,(50+(power/15)*(power/10))&0xffffffff)

static func special_attack(level: int) -> int:return 50+((level*level)&0xffffffff)/6

