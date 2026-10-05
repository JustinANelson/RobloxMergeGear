--!strict
-- What enemies drop and how ground items behave.
local Types = require(script.Parent.Parent.Types)
local TableUtil = require(script.Parent.Parent.Util.TableUtil)

return TableUtil.deepFreeze({
	-- Relative weights for which kind a regular enemy drops (normalized at runtime).
	KindWeights = { Helmet = 25, Armor = 25, Boots = 25, Sword = 25 } :: { [Types.ItemKind]: number },

	-- Physical items allowed on the ground per player. Overflow goes straight to storage.
	GroundCap = 40,

	-- Regular drops come at the Drop Tier plus; bosses guarantee this many pluses above it.
	BossPlusBonus = 3,

	-- Max distance (studs) between a player's character and an item they drag/merge.
	-- Generous because the camera can pan; the item must also be inside their zone.
	MaxInteractDistance = 80,

	Gold = {
		despawnSeconds = 30, -- uncollected coins are credited automatically, then removed
		baseMagnetRange = 8, -- studs; the MagnetRange upgrade adds to this
	},
})
