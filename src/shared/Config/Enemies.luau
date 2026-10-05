--!strict
-- Enemy balance. Enemy power tracks the player's Drop Tier plus (call it T), so raising
-- Drop Tier is a trade: better drops and more gold, but tougher enemies.
-- Curves are indexed by T: exp = base * growth^(T - 1).
local Types = require(script.Parent.Parent.Types)
local TableUtil = require(script.Parent.Parent.Util.TableUtil)

type Curve = Types.Curve

return TableUtil.deepFreeze({
	Spawning = {
		baseCap = 6, -- alive at once per zone; EnemyCap upgrade adds to this
		baseInterval = 2.0, -- seconds between spawns; SpawnRate upgrade shortens this
		edgeInset = 8, -- studs kept clear between spawn points and the zone pad's edge
	},

	Ai = {
		tickSeconds = 0.2, -- how often enemies re-think (chase/attack); also the hero attack check rate
		-- Enemies only chase while their owner is inside the zone pad (+ this margin), so they never
		-- leave the zone. Otherwise they return to where they spawned.
		leashMargin = 10,
	},

	Grunt = {
		health = { kind = "exp", base = 30, growth = 1.45 } :: Curve,
		damage = { kind = "exp", base = 5, growth = 1.4 } :: Curve,
		gold = { kind = "exp", base = 3, growth = 1.5 } :: Curve,
		walkSpeed = 12,
		attackInterval = 1.2,
		attackRange = 5,
	},

	Boss = {
		healthMultiplier = 12,
		damageMultiplier = 3,
		goldMultiplier = 15,
		spawnInterval = 180, -- seconds, while no boss is alive
		walkSpeed = 10,
		scale = 2,
	},
})
