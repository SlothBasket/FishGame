class_name BaitColors
extends RefCounted
enum Tag { GREEN, BLUE, SILVER, PEARL, PINK, DARK, GOLD }
const NAMES = ["Green","Blue","Silver","Pearl","Pink","Dark","Gold"]
const TINTS = [Color("568f54"),Color("528cbb"),Color("b9c9cb"),Color("ede6ce"),Color("d98594"),Color("354154"),Color("d7a52d")]
static func material(tag: int, light: bool = false) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = TINTS[clampi(tag,0,6)].lerp(Color("e5e5d3"),0.45 if light else 0.0)
	mat.roughness = 0.4
	mat.metallic = 0.35 if tag in [Tag.SILVER,Tag.GOLD] else 0.1
	return mat
