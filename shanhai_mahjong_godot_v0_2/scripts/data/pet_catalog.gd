class_name PetCatalog
extends RefCounted
## The pet list is gameplay data. Actual artworks stay unchanged in assets/pets.

const IDS: Array[String] = [
	"001", "002", "008", "010", "011", "013", "018",
	"021", "023", "030", "032", "034", "035", "038"
]

static func texture_for(pet_id: String) -> Texture2D:
	return load("res://assets/pets/no_%s_icon.png" % pet_id) as Texture2D

