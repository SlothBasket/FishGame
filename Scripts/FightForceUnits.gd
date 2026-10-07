class_name FightForceUnits
extends RefCounted
## One conversion boundary for prototype force/load units. Never scales world motion.
const SCALE: float = 2.0
const BASE_STRENGTH: float = 110*SCALE
const BASE_BREAK: float = 93.5*SCALE
static func load_units(legacy_force: float) -> float: return legacy_force*SCALE
static func acceleration(force: float, mass: float) -> float: return force/(SCALE*maxf(0.01,mass))
