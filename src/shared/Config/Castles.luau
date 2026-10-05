--!strict
-- Castles on the shared map. Ownership is per-server; income earned is saved to player data.
local TableUtil = require(script.Parent.Parent.Util.TableUtil)

export type CastleTier = { requiredPower: number, goldPerSecond: number }
export type CastleDef = { id: string, name: string, tier: number }

return TableUtil.deepFreeze({
	-- requiredPower is both the unlock gate (Gear Score to attempt) and a neutral castle's defense.
	Tiers = {
		{ requiredPower = 150, goldPerSecond = 4 }, -- all gear around +4
		{ requiredPower = 500, goldPerSecond = 15 }, -- around +7
		{ requiredPower = 1500, goldPerSecond = 50 }, -- around +10, near the first rebirth
		{ requiredPower = 4000, goldPerSecond = 150 }, -- around +12, a post-rebirth goal
	} :: { CastleTier },

	-- Placed on the map in this order, in the gaps between personal zones (see Config/Map).
	Castles = {
		{ id = "Oakhold", name = "Oakhold", tier = 1 },
		{ id = "Stonewatch", name = "Stonewatch", tier = 2 },
		{ id = "Ironspire", name = "Ironspire", tier = 3 },
		{ id = "Briarkeep", name = "Briarkeep", tier = 1 },
		{ id = "Ravencrest", name = "Ravencrest", tier = 2 },
		{ id = "Dragonmaw", name = "Dragonmaw", tier = 4 },
	} :: { CastleDef },

	Battle = {
		durationSeconds = 6, -- length of the auto-resolved battle visual
		-- winChance = 1 / (1 + (defense / attackerPower)^steepness), clamped.
		-- Equal power -> 50%, 1.2x -> 67%, 1.5x -> 84%.
		steepness = 4,
		minChance = 0.05,
		maxChance = 0.95,
		defenderBonus = 1.1, -- owned castle defends at owner's capture-time Gear Score * this
		retryCooldownSeconds = 45, -- after a failed attempt, per player per castle
		captureRange = 25, -- studs from the castle's capture point
	},
})
