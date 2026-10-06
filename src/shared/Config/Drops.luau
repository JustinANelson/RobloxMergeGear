--!strict
-- What enemies drop. Items go straight into the player's bag (storage); the world only shows a
-- short client-side "loot flies to you" effect (see DESIGN D21).
local Types = require(script.Parent.Parent.Types)
local TableUtil = require(script.Parent.Parent.Util.TableUtil)

return TableUtil.deepFreeze({
	-- Chance a regular enemy drops a gear piece. 1 = every kill. The pacing in DESIGN §3
	-- assumes 1; lower it only together with richer drops (e.g. a higher plus).
	DropChance = 1,

	-- Relative weights for which kind a regular enemy drops (normalized at runtime).
	KindWeights = { Helmet = 25, Armor = 25, Boots = 25, Sword = 25 } :: { [Types.ItemKind]: number },

	-- Regular drops come at the Drop Tier plus; bosses guarantee this many pluses above it.
	BossPlusBonus = 3,

	-- Minimum seconds between inventory/forge requests per player (server rate limit).
	RequestCooldown = 0.1,

	Gold = {
		despawnSeconds = 30, -- uncollected coins are credited automatically, then removed
		baseMagnetRange = 8, -- studs; the MagnetRange upgrade adds to this
		magnetTickSeconds = 0.1,
	},
})
