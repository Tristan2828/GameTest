class_name RunSetup
extends RefCounted
## Choices made before a run starts (host side), read by the arena when it
## spawns players. The lobby fills this in; anyone without a choice (e.g. a
## friend who drops in mid-run) plays the Wanderer.

## peer id -> Characters id
static var characters: Dictionary[int, int] = {}
## Lobby join order (host first); the arena hands out player slots in this order.
static var order: Array[int] = []
## Difficulty and custom game options (host's choice; clients get a copy).
static var config: RunConfig = RunConfig.new()


static func character_for(peer_id: int) -> int:
	return characters.get(peer_id, Characters.Id.WANDERER)
