class_name RunSetup
extends RefCounted
## Choices made before a run starts (host side), read by the arena when it
## spawns players. The lobby fills this in; anyone without a choice (e.g. a
## friend who drops in mid-run) plays the Wanderer.

## peer id -> Characters id
static var characters: Dictionary[int, int] = {}


static func character_for(peer_id: int) -> int:
	return characters.get(peer_id, Characters.Id.WANDERER)
