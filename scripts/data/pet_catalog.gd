class_name PetCatalog
extends RefCounted
## Names and elements are imported from the user's pet design workbook.
const EARTH_PLACEHOLDER_ID := "earth_placeholder"
const BASE_IDS: Array[String] = ["001", "002", "030", "050", EARTH_PLACEHOLDER_ID]
const ELEMENT_NAMES := {"fire": "火", "water": "水", "lightning": "雷", "wind": "风", "earth": "土"}
static var DATA: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/data/pets.json"))
static var IDS: Array[String] = _ids()

static func _ids() -> Array[String]:
	var result: Array[String] = []
	for id in DATA:
		result.append(id)
	return result

static func element_for(pet_id: String) -> String:
	return DATA.get(pet_id, {}).get("element", "")

static func name_for(pet_id: String) -> String:
	return DATA.get(pet_id, {}).get("name", pet_id)

static func texture_for(pet_id: String) -> Texture2D:
	var path: String = DATA.get(pet_id, {}).get("texture", "")
	return null if path.is_empty() else load(path) as Texture2D

