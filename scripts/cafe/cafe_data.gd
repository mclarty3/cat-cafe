class_name CafeData
## Static content tables for the cafe prototype: menu items, pantry, regulars.
## Kept as plain dictionaries so they're quick to tweak while the design is in flux;
## move to Resources once the shape settles.

enum Quality { POOR, GOOD, PERFECT }

const QUALITY_NAMES := ["Poor", "Good", "Perfect!"]

## `steps`: drink minigame stages. `ingredient`: a pantry item used up, one per
## item, when it goes on the morning menu (items without one are free to make).
## Pastries and drinks with an ingredient are counted (they sell out); other
## drinks are unlimited once on the menu. `model` is how it
## looks on the pass and in your hands, optionally standing on a `base` (see ItemModel).
const ITEMS := {
	"espresso": {
		"name": "Espresso", "kind": "drink", "price": 3,
		"steps": ["pull"], "color": Color(0.36, 0.23, 0.16),
		"model": "res://assets/kenney/food/cup-coffee.glb", "model_scale": 0.32,
		"base": "res://assets/kenney/food/cup-saucer.glb", "base_scale": 0.3,
	},
	"latte": {
		"name": "Latte", "kind": "drink", "price": 4,
		"steps": ["pull", "steam"], "color": Color(0.78, 0.62, 0.48),
		"model": "res://assets/kenney/food/cup-coffee.glb", "model_scale": 0.5,
	},
	"honey_latte": {
		"name": "Dream-honey Latte", "kind": "drink", "price": 7,
		"steps": ["pull", "steam"], "ingredient": "dream_honey", "color": Color(0.91, 0.72, 0.29),
		"model": "res://assets/kenney/food/cup-coffee.glb", "model_scale": 0.5,
	},
	"croissant": {
		"name": "Croissant", "kind": "pastry", "price": 3,
		"color": Color(0.88, 0.64, 0.35),
		"model": "res://assets/kenney/food/croissant.glb", "model_scale": 0.3,
	},
	"moon_muffin": {
		"name": "Moonflour Muffin", "kind": "pastry", "price": 5,
		"ingredient": "moonflour", "color": Color(0.62, 0.66, 1.0),
		"model": "res://assets/kenney/food/muffin.glb", "model_scale": 0.35,
	},
}

## Dungeon ingredients. The prototype starts with a fake haul from "last night".
const PANTRY_NAMES := {
	"moonflour": "Moonflour",
	"dream_honey": "Dream honey",
}
const STARTING_PANTRY := {"moonflour": 2, "dream_honey": 1}

## Confirmed personalities and their effects, from the roster in docs/Cats.md.
## Each effect is an icon (res://assets/ui/icons/<icon>.png) plus its description,
## shown on the Cats roster cards; mark drawbacks with "negative": true. The
## effects aren't active in-game yet.
const PERSONALITIES := {
	"Lazy": {
		"cafe": [{"icon": "hourglass", "text": "Calms stressed or impatient customers"}],
		"dream": [{"icon": "suit_hearts", "text": "Standing still slowly heals you"}],
	},
	"Playful": {
		"cafe": [
			{"icon": "pawns", "text": "Brings in families"},
			{"icon": "exploding", "text": "Knocks things over", "negative": true},
		],
		"dream": [{"icon": "shield", "text": "Occasionally bats projectiles away"}],
	},
	"Curious": {
		"cafe": [{"icon": "token", "text": "Finds dropped coins and lost items around the cafe"}],
		"dream": [{"icon": "structure_wall", "text": "Reveals hidden walls and secret rooms"}],
	},
	"Nocturnal": {
		"cafe": [{"icon": "suit_clubs", "text": "A \"lucky black cat\" that draws superstitious customers"}],
		"dream": [{"icon": "warning", "text": "Sees in the dark and reveals traps"}],
	},
	"Hunter": {
		"cafe": [{"icon": "target", "text": "Handles \"mouse in the kitchen\" events"}],
		"dream": [{"icon": "sword", "text": "Bonus damage to small enemies"}],
	},
	"Chatty": {
		"cafe": [{"icon": "exclamation", "text": "Announces customers and hurries the staff"}],
		"dream": [{"icon": "information", "text": "Warns you about enemies off-screen"}],
	},
}

## Resident cats. The cafe spawns one of each at the start of the day.
## Hand-written for the prototype; real cats will be generated. The full set of
## fields (and how each should be generated) is in "Cat data schema" in docs/Cats.md.
##   tint: multiplies the shared Kenney cat texture (there's only one cat model)
##   swatch: the colour shown for the cat in UI (roughly how the tinted model looks)
##   walk_speed / idle: how they wander (idle is a min-max pause in seconds)
##   mischief: the cat events this cat can cause (ids from the CatEvent scripts):
##     "mug" (Playful), "fight" (anyone not Lazy), "curtains" (kittens),
##     "croissant_thief" (Hunter)
##   voice: pitch of its meows and purrs, and how often petting gets a meow
##          rather than a purr (0 = always purrs, 1 = always meows)
const CATS := {
	"mochi": {
		"name": "Mochi", "personality": "Playful",
		"blurb": "Bats at anything that moves. Including mugs. Especially mugs.",
		"since": "Found in the cafe when you arrived",
		"tint": Color(1, 1, 1), "swatch": Color(0.66, 0.6, 0.76), "walk_speed": 0.6, "idle": Vector2(2, 6),
		"voice": {"pitch": 1.08, "meowy": 0.6},
		"mischief": ["mug", "fight"],
	},
	"biscuit": {
		"name": "Biscuit", "personality": "Lazy",
		"blurb": "Has never been in a hurry. Treats every lap as a personal invitation.",
		"since": "Rescued from a dream of endless afternoons",
		"tint": Color(1.55, 1.4, 1.15), "swatch": Color(0.78, 0.7, 0.6), "walk_speed": 0.3, "idle": Vector2(10, 20),
		"voice": {"pitch": 0.9, "meowy": 0.2},
	},
	"pepper": {
		"name": "Pepper", "personality": "Curious",
		"blurb": "Has to know what's in every bag, box and cupboard. Immediately.",
		"since": "Followed you home from the dream's flooded library",
		"tint": Color(0.75, 0.82, 0.95), "swatch": Color(0.45, 0.5, 0.68), "walk_speed": 0.75, "idle": Vector2(1, 3),
		"voice": {"pitch": 1.15, "meowy": 0.7},
		"mischief": ["fight"],
	},
	"inky": {
		"name": "Inky", "personality": "Nocturnal",
		"blurb": "Sleeps through the day shift. Some regulars swear they're lucky.",
		"since": "Befriended under a moonlit stair in the dream",
		"tint": Color(0.28, 0.27, 0.32), "swatch": Color(0.16, 0.15, 0.2), "walk_speed": 0.4, "idle": Vector2(15, 30),
		"voice": {"pitch": 0.95, "meowy": 0.25},
		"mischief": ["fight"],
	},
	"clementine": {
		"name": "Clementine", "personality": "Hunter",
		"blurb": "Stalks crumbs, shoelaces and the occasional real mouse.",
		"since": "Rescued from a possessed pantry",
		"tint": Color(1.5, 0.95, 0.55), "swatch": Color(0.9, 0.55, 0.3), "walk_speed": 1.0, "idle": Vector2(3, 7),
		"voice": {"pitch": 1.0, "meowy": 0.45},
		"mischief": ["croissant_thief", "fight"],
	},
	"bao": {
		"name": "Bao", "personality": "Chatty",
		"blurb": "Has an opinion about every customer, and shares it loudly.",
		"since": "Talked its way out of a dream about a crowded train station",
		"tint": Color(1.7, 1.65, 1.5), "swatch": Color(0.92, 0.88, 0.8), "walk_speed": 0.55, "idle": Vector2(2, 5),
		"voice": {"pitch": 1.05, "meowy": 0.85},
		"mischief": ["fight"],
	},
	"tofu": {
		"name": "Tofu", "personality": "Lazy",
		"blurb": "Can sleep anywhere. Has slept in the pastry case. Twice.",
		"since": "Adopted from the shelter down the street",
		"tint": Color(0.7, 0.7, 0.72), "swatch": Color(0.5, 0.5, 0.52), "walk_speed": 0.3, "idle": Vector2(12, 24),
		"voice": {"pitch": 0.88, "meowy": 0.15},
	},
	"sprout": {
		"name": "Sprout", "personality": "Curious",
		"blurb": "A kitten who has just discovered that the world has corners.",
		"since": "Found napping in a dream greenhouse",
		"tint": Color(1.35, 1.0, 0.7), "swatch": Color(0.85, 0.62, 0.42), "walk_speed": 0.85, "idle": Vector2(1, 3),
		"voice": {"pitch": 1.3, "meowy": 0.75},
		"mischief": ["curtains"],
	},
}

## Planned computer features, shown greyed out until they exist.
const FURNITURE_IDEAS := [
	{"name": "Rearrange tables", "note": "Move and rotate furniture before opening"},
	{"name": "Swap the rug", "note": "Decor that changes the mood"},
	{"name": "Cat tree", "note": "Somewhere for cats to settle near customers"},
]
const UPGRADE_IDEAS := [
	{"name": "Second group head", "price": 120, "note": "Pull two shots at once"},
	{"name": "Bigger pastry case", "price": 80, "note": "More pastry slots"},
	{"name": "Bigger menu board", "price": 100, "note": "Another drink slot"},
	{"name": "Extra table", "price": 60, "note": "More seats, fewer customers taking it to go"},
]

const REGULARS := {
	"theo": {
		"name": "Theo",
		"model": "res://assets/kenney/characters/character-male-c.glb",
		"favourite": ["honey_latte", "latte"],
		"greeting": "Hey. The usual, if there's any of that honey left?",
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

## Cafe radio: plays in order and wraps around. Lo-fi by TAD (CC0).
const PLAYLIST: Array[String] = [
	"res://assets/audio/music/cat_caffe.ogg",
	"res://assets/audio/music/a_cup_of_tea.ogg",
	"res://assets/audio/music/bartender.ogg",
]

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


## Counted items sell out; the rest are unlimited once on the menu.
static func is_counted(id: String) -> bool:
	return ITEMS[id]["kind"] == "pastry" or ITEMS[id].has("ingredient")


static func ids_of_kind(kind: String) -> Array[String]:
	var out: Array[String] = []
	for id in ITEMS:
		if ITEMS[id]["kind"] == kind:
			out.append(id)
	return out
