class_name CafeData
## Static content tables for the cafe prototype: menu, prep actions, regulars.
## Kept as plain dictionaries so they're quick to tweak while the design is in flux;
## move to Resources once the shape settles.

enum Quality { POOR, GOOD, PERFECT }

const QUALITY_NAMES := ["Poor", "Good", "Perfect!"]

## `steps`: drink minigame stages. `uses`: a stock key consumed when the item is
## made or taken. Items without `uses` are unlimited.
const ITEMS := {
	"espresso": {
		"name": "Espresso", "kind": "drink", "price": 3,
		"steps": ["pull"], "color": Color(0.36, 0.23, 0.16),
	},
	"latte": {
		"name": "Latte", "kind": "drink", "price": 4,
		"steps": ["pull", "steam"], "color": Color(0.78, 0.62, 0.48),
	},
	"honey_latte": {
		"name": "Dream-honey Latte", "kind": "drink", "price": 7,
		"steps": ["pull", "steam"], "uses": "honey_syrup", "color": Color(0.91, 0.72, 0.29),
	},
	"croissant": {
		"name": "Croissant", "kind": "pastry", "price": 3,
		"uses": "croissant", "color": Color(0.88, 0.64, 0.35),
	},
	"moon_muffin": {
		"name": "Moonflour Muffin", "kind": "pastry", "price": 5,
		"uses": "moon_muffin", "color": Color(0.62, 0.66, 1.0),
	},
}

const STOCK_NAMES := {
	"croissant": "Croissants",
	"moon_muffin": "Moon muffins",
	"honey_syrup": "Honey syrup",
}

## Dungeon ingredients. The prototype starts with a fake haul from "last night".
const PANTRY_NAMES := {
	"moonflour": "Moonflour",
	"dream_honey": "Dream honey",
}
const STARTING_PANTRY := {"moonflour": 2, "dream_honey": 1}

const PREP_ACTIONS := [
	{"name": "Bake croissants", "gives": {"croissant": 4}, "costs": {}},
	{"name": "Bake moonflour muffins", "gives": {"moon_muffin": 3}, "costs": {"moonflour": 1}},
	{"name": "Make dream-honey syrup", "gives": {"honey_syrup": 3}, "costs": {"dream_honey": 1}},
]

const REGULARS := {
	"theo": {
		"name": "Theo",
		"model": "res://assets/kenney/characters/character-male-c.glb",
		"favourite": ["honey_latte", "latte"],
		"opening": "Sorry, I've been staring at the same paragraph for an hour. Thesis stuff.",
		"choices": [
			{
				"text": "What's it about?",
				"reply": "Dreams, actually. Why we have them. Ironic, since I haven't had one in months.",
			},
			{
				"text": "Want a cat to help? Mochi's a great editor.",
				"reply": "...Yeah. Okay. That's actually really nice. Hi, Mochi.",
			},
		],
		"skipped": "Theo will bring it up on his next visit.",
	},
}

const BARISTA_MODEL := "res://assets/kenney/characters/character-female-b.glb"

const WALK_IN_MODELS := [
	"res://assets/kenney/characters/character-female-a.glb",
	"res://assets/kenney/characters/character-female-c.glb",
	"res://assets/kenney/characters/character-female-d.glb",
	"res://assets/kenney/characters/character-female-e.glb",
	"res://assets/kenney/characters/character-female-f.glb",
	"res://assets/kenney/characters/character-male-a.glb",
	"res://assets/kenney/characters/character-male-b.glb",
	"res://assets/kenney/characters/character-male-d.glb",
	"res://assets/kenney/characters/character-male-e.glb",
	"res://assets/kenney/characters/character-male-f.glb",
]


static func item(id: String) -> Dictionary:
	return ITEMS[id]


static func item_name(id: String) -> String:
	return ITEMS[id]["name"]


static func ids_of_kind(kind: String) -> Array[String]:
	var out: Array[String] = []
	for id in ITEMS:
		if ITEMS[id]["kind"] == kind:
			out.append(id)
	return out
