--!strict
-- Every balancing formula, in one place. Pure functions of config + inputs: no Instances, no state.
-- The server uses these to decide outcomes; the client uses the same functions to display/predict.
local Config = script.Parent.Config
local Types = require(script.Parent.Types)
local GearConfig = require(Config.Gear)
local EnemyConfig = require(Config.Enemies)
local UpgradeConfig = require(Config.Upgrades)
local DropConfig = require(Config.Drops)
local CastleConfig = require(Config.Castles)
local RebirthConfig = require(Config.Rebirth)
local EconomyConfig = require(Config.Economy)

local Formulas = {}

-- String-keyed views of slot-keyed config: the type solver widens singleton keys when
-- indexing union-keyed maps, so the loops below index these instead.
local SLOTS: { string } = GearConfig.Slots :: any
local SLOT_STATS: { [string]: { [string]: Types.Curve } } = GearConfig.Stats :: any
local SLOT_WEIGHT: { [string]: number } = GearConfig.GearScore.slotWeight :: any

function Formulas.curve(c: Types.Curve, x: number): number
	if c.kind == "exp" then
		return c.base * c.growth ^ (x - 1)
	else
		return math.min(c.perStep * x, c.max)
	end
end

-- Gear -----------------------------------------------------------------------

function Formulas.heroStats(loadout: Types.Loadout): Types.HeroStats
	local hero = GearConfig.Hero
	local stats: { [string]: number } = {
		maxHealth = hero.maxHealth,
		damage = hero.damage,
		defense = hero.defense,
		walkSpeed = hero.walkSpeed,
	}
	for _, slot in SLOTS do
		local item: Types.Item? = (loadout :: any)[slot]
		if item then
			local multiplier = GearConfig.Kinds[item.kind].statMultiplier
			for stat, c in SLOT_STATS[slot] do
				stats[stat] += Formulas.curve(c, item.plus) * multiplier
			end
		end
	end
	return stats :: any
end

function Formulas.gearScore(loadout: Types.Loadout): number
	local gs = GearConfig.GearScore
	local total = 0
	for _, slot in SLOTS do
		local item: Types.Item? = (loadout :: any)[slot]
		if item then
			total += SLOT_WEIGHT[slot] * gs.base * gs.growth ^ (item.plus - 1)
		end
	end
	return math.floor(total)
end

function Formulas.damageTaken(raw: number, defense: number): number
	local k = GearConfig.DefenseK
	return raw * k / (k + defense)
end

-- Base +1 items needed to build an item at this plus.
function Formulas.baseItemsFor(plus: number): number
	return 2 ^ (plus - 1)
end

-- Drops ------------------------------------------------------------------------

-- Kinds in a stable order so a given roll always maps to the same kind.
local DROP_KINDS: { string } = {}
for kind in DropConfig.KindWeights :: any do
	table.insert(DROP_KINDS, kind)
end
table.sort(DROP_KINDS)

-- Weighted pick of which kind drops. r is uniform in [0, 1).
function Formulas.rollDropKind(r: number): Types.ItemKind
	local weights: { [string]: number } = DropConfig.KindWeights :: any
	local total = 0
	for _, kind in DROP_KINDS do
		total += weights[kind]
	end
	local pick = r * total
	for _, kind in DROP_KINDS do
		pick -= weights[kind]
		if pick < 0 then
			return kind :: any
		end
	end
	return DROP_KINDS[#DROP_KINDS] :: any
end

-- Plus of a drop: Drop Tier plus, + boss bonus, + 1 with the rebirth bonus chance. r is uniform in [0, 1).
function Formulas.rollDropPlus(dropTierLevel: number, rebirths: number, isBoss: boolean, r: number): number
	local plus = Formulas.dropPlus(dropTierLevel)
	if isBoss then
		plus += DropConfig.BossPlusBonus
	end
	if r < Formulas.bonusPlusChance(rebirths) then
		plus += 1
	end
	return math.min(plus, GearConfig.MaxPlus)
end

-- Upgrades -------------------------------------------------------------------

-- Cost of buying the next level, or nil when maxed.
function Formulas.upgradeCost(id: Types.UpgradeId, currentLevel: number): number?
	local def: UpgradeConfig.UpgradeDef = (UpgradeConfig.Defs :: any)[id]
	if currentLevel >= def.maxLevel then
		return nil
	end
	return math.floor(def.cost.base * def.cost.growth ^ currentLevel)
end

function Formulas.dropPlus(dropTierLevel: number): number
	return 1 + dropTierLevel * UpgradeConfig.Defs.DropTier.perLevel
end

function Formulas.enemyCap(level: number): number
	return EnemyConfig.Spawning.baseCap + level * UpgradeConfig.Defs.EnemyCap.perLevel
end

function Formulas.spawnInterval(level: number): number
	return EnemyConfig.Spawning.baseInterval * UpgradeConfig.Defs.SpawnRate.perLevel ^ level
end

function Formulas.magnetRange(level: number): number
	return DropConfig.Gold.baseMagnetRange + level * UpgradeConfig.Defs.MagnetRange.perLevel
end

-- Enemies (tier = the owner's current drop plus) ---------------------------------

export type EnemyStats = { health: number, damage: number, gold: number, walkSpeed: number }

function Formulas.enemyStats(tier: number, isBoss: boolean): EnemyStats
	local grunt = EnemyConfig.Grunt
	local stats = {
		health = Formulas.curve(grunt.health, tier),
		damage = Formulas.curve(grunt.damage, tier),
		gold = Formulas.curve(grunt.gold, tier),
		walkSpeed = grunt.walkSpeed,
	}
	if isBoss then
		local boss = EnemyConfig.Boss
		stats.health *= boss.healthMultiplier
		stats.damage *= boss.damageMultiplier
		stats.gold *= boss.goldMultiplier
		stats.walkSpeed = boss.walkSpeed
	end
	return stats
end

-- Castles ----------------------------------------------------------------------

function Formulas.captureChance(attackerPower: number, defense: number): number
	local battle = CastleConfig.Battle
	if attackerPower <= 0 then
		return 0
	end
	local chance = 1 / (1 + (defense / attackerPower) ^ battle.steepness)
	return math.clamp(chance, battle.minChance, battle.maxChance)
end

-- Rebirth ----------------------------------------------------------------------

function Formulas.rebirthRequiredPlus(rebirths: number): number
	return RebirthConfig.firstRequiredPlus + rebirths * RebirthConfig.requiredPlusStep
end

function Formulas.goldMultiplier(rebirths: number): number
	return 1 + rebirths * RebirthConfig.goldMultiplierPerRebirth
end

function Formulas.bonusPlusChance(rebirths: number): number
	return math.min(rebirths * RebirthConfig.bonusPlusChancePerRebirth, RebirthConfig.bonusPlusChanceMax)
end

-- Offline ----------------------------------------------------------------------

-- Estimated gold/s from simply farming the zone (used only for the offline income rate).
function Formulas.zoneFarmRate(data: Types.PlayerData): number
	local tier = Formulas.dropPlus(data.upgrades.DropTier)
	local goldPerKill = Formulas.enemyStats(tier, false).gold
	return goldPerKill / Formulas.spawnInterval(data.upgrades.SpawnRate) * Formulas.goldMultiplier(data.rebirths)
end

function Formulas.offlinePayout(incomeRate: number, secondsAway: number): number
	local offline = EconomyConfig.Offline
	if secondsAway < offline.minSecondsAway then
		return 0
	end
	local seconds = math.min(secondsAway, offline.maxHours * 3600)
	return math.floor(incomeRate * seconds * offline.efficiency)
end

return Formulas
