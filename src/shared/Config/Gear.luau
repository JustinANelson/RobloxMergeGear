--!strict
-- Gear balance (data only; formulas live in Shared/Formulas).
-- Curves are indexed by plus: exp = base * growth^(plus - 1).
local Types = require(script.Parent.Parent.Types)
local TableUtil = require(script.Parent.Parent.Util.TableUtil)

type Curve = Types.Curve

return TableUtil.deepFreeze({
	MaxPlus = 30,

	Slots = { "Helmet", "Armor", "Weapon", "Boots" } :: { Types.Slot },

	-- Kind -> slot it equips into. statMultiplier lets Phase 2 weapon kinds differ (e.g. Bow 0.9 dmg).
	Kinds = {
		Helmet = { slot = "Helmet", displayName = "Helmet", statMultiplier = 1 },
		Armor = { slot = "Armor", displayName = "Armor", statMultiplier = 1 },
		Boots = { slot = "Boots", displayName = "Boots", statMultiplier = 1 },
		Sword = { slot = "Weapon", displayName = "Sword", statMultiplier = 1 },
	} :: { [Types.ItemKind]: { slot: Types.Slot, displayName: string, statMultiplier: number } },

	-- The hero with nothing equipped.
	Hero = {
		maxHealth = 100,
		damage = 4,
		defense = 0,
		walkSpeed = 16,
		attackInterval = 0.8, -- seconds between auto-attacks
		attackRange = 8, -- studs, root to root
		respawnSeconds = 4,
	},

	-- What each slot's plus contributes. Weapon carries offense, Armor/Helmet carry survival,
	-- Boots give speed (linear, capped so movement stays controllable) plus a little defense.
	Stats = {
		Weapon = {
			damage = { kind = "exp", base = 8, growth = 1.4 } :: Curve, -- +1: 8, +5: 31, +10: 165
		},
		Armor = {
			maxHealth = { kind = "exp", base = 40, growth = 1.35 } :: Curve,
			defense = { kind = "exp", base = 2, growth = 1.3 } :: Curve,
		},
		Helmet = {
			maxHealth = { kind = "exp", base = 25, growth = 1.35 } :: Curve,
			defense = { kind = "exp", base = 1.5, growth = 1.3 } :: Curve,
		},
		Boots = {
			walkSpeed = { kind = "linear", perStep = 1, max = 14 } :: Curve, -- +14 studs/s at +14 and above
			defense = { kind = "exp", base = 1, growth = 1.3 } :: Curve,
		},
	} :: { [Types.Slot]: { [Types.StatName]: Curve } },

	-- damageTaken = raw * K / (K + defense). Defense equal to K halves incoming damage.
	DefenseK = 50,

	-- Gear Score = sum over equipped of slotWeight * base * growth^(plus - 1).
	-- Every piece at +4 ≈ 150 (first castle), every piece at +10 ≈ 1730.
	GearScore = {
		base = 10,
		growth = 1.5,
		slotWeight = { Weapon = 1.5, Armor = 1.2, Helmet = 1.0, Boots = 0.8 } :: { [Types.Slot]: number },
	},
})
