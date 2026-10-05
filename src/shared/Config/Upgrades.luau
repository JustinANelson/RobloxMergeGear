--!strict
-- Gold upgrades. Cost of the next level = cost.base * cost.growth^currentLevel.
local Types = require(script.Parent.Parent.Types)
local TableUtil = require(script.Parent.Parent.Util.TableUtil)

export type UpgradeDef = {
	displayName: string,
	description: string,
	maxLevel: number,
	cost: { base: number, growth: number },
	perLevel: number, -- effect step; see Formulas for how each upgrade applies it
}

return TableUtil.deepFreeze({
	Order = { "DropTier", "EnemyCap", "SpawnRate", "MagnetRange" } :: { Types.UpgradeId },

	Defs = {
		DropTier = {
			displayName = "Drop Tier",
			description = "Drops start one plus higher. Enemies get tougher and pay more gold.",
			maxLevel = 29, -- drop plus 1..30
			cost = { base = 150, growth = 2.6 },
			perLevel = 1, -- additive to drop plus
		},
		EnemyCap = {
			displayName = "Enemy Cap",
			description = "More enemies alive in your zone at once.",
			maxLevel = 14,
			cost = { base = 40, growth = 1.6 },
			perLevel = 1, -- additive to Enemies.Spawning.baseCap
		},
		SpawnRate = {
			displayName = "Spawn Rate",
			description = "Enemies spawn faster.",
			maxLevel = 15,
			cost = { base = 60, growth = 1.65 },
			perLevel = 0.93, -- multiplier on spawn interval per level (2.0s -> ~0.68s at max)
		},
		MagnetRange = {
			displayName = "Loot Magnet",
			description = "Collect gold from further away.",
			maxLevel = 15,
			cost = { base = 25, growth = 1.5 },
			perLevel = 2, -- studs added to Drops.Gold.baseMagnetRange
		},
	} :: { DropTier: UpgradeDef, EnemyCap: UpgradeDef, SpawnRate: UpgradeDef, MagnetRange: UpgradeDef },
})
