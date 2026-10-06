--!strict
-- Default player save. ProfileStore deep-copies this for new players and Reconcile() fills in
-- any key added here later, so new top-level fields need no migration.
-- Renaming, moving or retyping a field DOES need one: bump schemaVersion and add a step
-- in server/Data/Migrations.
--
-- Reconcile recurses into nested tables, so map-like tables (equipped, inventory buckets)
-- must stay EMPTY here: any entry in them would reappear on every join after the
-- player removed it. One-time defaults go in server/Data/NewPlayer instead.
local Types = require(script.Parent.Parent.Types)

local template: Types.PlayerData = {
	schemaVersion = 2,
	gold = 0,
	inventory = {
		Helmet = { Normal = {} },
		Armor = { Normal = {} },
		Boots = { Normal = {} },
		Sword = { Normal = {} },
	},
	equipped = {},
	upgrades = { DropTier = 0, EnemyCap = 0, SpawnRate = 0, MagnetRange = 0 },
	rebirths = 0,
	starterKitGranted = false,
	index = { Helmet = 0, Armor = 0, Weapon = 0, Boots = 0 },
	stats = { kills = 0, bossKills = 0, merges = 0, castleCaptures = 0, goldEarned = 0 },
	offline = { lastOnline = 0, incomeRate = 0 },
}

-- Not frozen: ProfileStore copies from it.
return template
