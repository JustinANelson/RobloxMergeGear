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

	-- Items land within this many studs of where the enemy died (kept on the zone pad).
	DropScatter = 3,
	-- Keep items this far inside the pad's edge.
	PadInset = 2,
	-- Items taken out of storage land this many studs from the hero.
	WithdrawRadius = 5,
	-- Minimum seconds between loot/inventory requests per player (server rate limit).
	RequestCooldown = 0.05,
	-- Idle pooled Parts kept per kind; extras are destroyed.
	PoolMaxIdlePerKind = 60,

	Gold = {
		despawnSeconds = 30, -- uncollected coins are credited automatically, then removed
		baseMagnetRange = 8, -- studs; the MagnetRange upgrade adds to this
		magnetTickSeconds = 0.1,
	},
})
