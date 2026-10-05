--!strict
-- Default player save. ProfileStore deep-copies this for new players and Reconcile() fills in
-- any key added here later, so new top-level fields need no migration.
-- Renaming, moving or retyping a field DOES need one: bump schemaVersion and add a step
-- in server/Data/Migrations.
local Types = require(script.Parent.Parent.Types)

local template: Types.PlayerData = {
	schemaVersion = 1,
	gold = 0,
	inventory = {
		Helmet = { Normal = {} },
		Armor = { Normal = {} },
		Boots = { Normal = {} },
		Sword = { Normal = {} },
	},
	ground = {},
	equipped = {},
	upgrades = { DropTier = 0, EnemyCap = 0, SpawnRate = 0, MagnetRange = 0 },
	rebirths = 0,
	index = { Helmet = 0, Armor = 0, Weapon = 0, Boots = 0 },
	stats = { kills = 0, bossKills = 0, merges = 0, castleCaptures = 0, goldEarned = 0 },
	offline = { lastOnline = 0, incomeRate = 0 },
}

-- Not frozen: ProfileStore copies from it.
return template
