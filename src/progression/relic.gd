class_name Relic
extends Resource
## A passive item bought in the shop between stages. Each is a `.tres` file in
## `src/progression/relics/`, registered in Relics.ALL (index = network id).

@export var title: String = "Relic"
## PixelArt sprite shown in the shop and the run summary.
@export var icon: String = ""
@export_multiline var description: String = ""
@export var price: int = 20
## Stat effects, applied in order (they can include drawbacks).
@export var effects: Array[Upgrade] = []
## Only offered in co-op games (e.g. revive relics are useless solo).
@export var co_op_only: bool = false
## Only offered to heroes with this CharacterStats.MainWeapon (-1 = everyone).
@export var for_weapon: int = -1
