class_name LevelCatalog
extends RefCounted

static var LEVELS: Array = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/data/levels.json"))

static func pet_ids_for(config: Dictionary, seed_value: int) -> Array[String]:
	# Guarantee five elements, then rotate additional artwork within this level's pool.
	var result: Array[String] = PetCatalog.BASE_IDS.duplicate()
	var candidates: Array[String] = []
	for id in config.pets:
		if id not in result:
			candidates.append(id)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	while result.size() < int(config.species) and not candidates.is_empty():
		var id: String = candidates.pop_at(rng.randi_range(0, candidates.size() - 1))
		var element := PetCatalog.element_for(id)
		var existing := 0
		for chosen in result:
			if PetCatalog.element_for(chosen) == element:
				existing += 1
		if existing < int(config.get("element_pairs", {}).get(element, 100)):
			result.append(id)
	return result

static func pair_ids_for(config: Dictionary, pool: Array[String], seed_value: int) -> Array[String]:
	var result: Array[String] = []
	var quotas: Dictionary = config.get("element_pairs", {})
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for element in quotas:
		var species: Array[String] = []
		for id in pool:
			if PetCatalog.element_for(id) == element:
				species.append(id)
		if species.is_empty():
			return []
		var start := rng.randi_range(0, species.size() - 1)
		for i in range(int(quotas[element])):
			result.append(species[(start + i) % species.size()])
	return result
