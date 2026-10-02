class_name CatEvent
extends RefCounted
## One bit of cat mischief during service. The cafe schedules a couple a day
## (see Cafe's "Cat events" settings). A subclass names the mischief its cats
## need, picks them in prepare(), and plays out in run(): a coroutine that
## drives the cats step by step and returns the line for the results screen.

var cafe: Cafe
var cats: Array[CafeCat] = []


## The id cats list under `mischief` in CafeData.CATS to be able to do this.
func mischief_id() -> String:
	return ""


## Picks the cats (free ones that can do this) and checks anything else it
## needs. False means it can't happen right now.
func prepare() -> bool:
	var able := cafe.free_cats(mischief_id())
	if able.is_empty():
		return false
	cats = [able.pick_random()]
	return true


## Plays the event out. Returns a line for the results screen.
func run() -> String:
	return ""


func cat() -> CafeCat:
	return cats[0]


## Waits one frame; returns its length. (Waits on the cafe, so an event left
## running when the scene goes away just stops.)
func tick() -> float:
	return await cafe.ticked


## Waits `seconds`, frame by frame.
func wait(seconds: float) -> void:
	while seconds > 0.0:
		seconds -= await tick()
