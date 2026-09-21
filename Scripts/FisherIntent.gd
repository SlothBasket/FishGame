class_name FisherIntent
extends RefCounted
## Device-independent intent. IDs, positions, outcomes and resource values are absent.
var move_forward: float = 0
var move_side: float = 0
var aim: Vector3 = Vector3.FORWARD
var retrieve: float = 0
var steering: float = 0
var rod: Vector3 = Vector3.FORWARD
var tier: int = 3
var species: int = 0
var cast_serial: int = 0
var escape: bool = false
var rise: bool = false
var descend: bool = false
var power: bool = false
var jerk: bool = false
var vision: bool = false

func numbers() -> PackedFloat32Array:
	return PackedFloat32Array([move_forward,move_side,aim.x,aim.y,aim.z,retrieve,steering,rod.x,rod.y,rod.z,tier,species,cast_serial])

func flags() -> int:
	return int(escape)|int(rise)<<1|int(descend)<<2|int(power)<<3|int(jerk)<<4|int(vision)<<5

static func decode(values: PackedFloat32Array, bits: int) -> FisherIntent:
	if values.size() != 13 or bits < 0 or bits > 63: return null
	for value in values:
		if not is_finite(value): return null
	if values[10] < 0 or values[10] > 5 or values[11] < 0 or values[11] > 4 or values[12] < 0 or values[12] > 1000000: return null
	for i in [10,11,12]:
		if values[i] != floorf(values[i]): return null
	var result = FisherIntent.new()
	result.move_forward = clampf(values[0],-1,1)
	result.move_side = clampf(values[1],-1,1)
	result.aim = Vector3(clampf(values[2],-1,1),clampf(values[3],-1,1),clampf(values[4],-1,1))
	result.rod = Vector3(clampf(values[7],-1,1),clampf(values[8],-1,1),clampf(values[9],-1,1))
	if result.aim.length_squared() < 0.01 or result.rod.length_squared() < 0.01: return null
	result.aim = result.aim.normalized()
	result.rod = result.rod.normalized()
	result.retrieve = ReelSpeed.quantize(values[5])
	result.steering = clampf(values[6],-1,1)
	result.tier = roundi(values[10])
	result.species = roundi(values[11])
	result.cast_serial = roundi(values[12])
	result.escape = bits & 1 != 0
	result.rise = bits & 2 != 0
	result.descend = bits & 4 != 0
	result.power = bits & 8 != 0
	result.jerk = bits & 16 != 0
	result.vision = bits & 32 != 0
	return result
