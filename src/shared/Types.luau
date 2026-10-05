--!strict
-- Shared type definitions. PlayerData must stay in sync with Config/DataTemplate.

export type Slot = "Helmet" | "Armor" | "Weapon" | "Boots"

-- An item *kind* decides what merges with what; each kind equips into exactly one slot.
-- MVP has one weapon kind (Sword). Bow/Staff arrive with weapon skills in Phase 2 as new kinds,
-- so existing inventories never need re-keying.
export type ItemKind = "Helmet" | "Armor" | "Boots" | "Sword"

-- Phase 3 extends this union ("Refined" | "Unique" | "Elite" | "Super"). Only equal qualities merge.
export type Quality = "Normal"

export type Item = { kind: ItemKind, quality: Quality, plus: number }

-- Storage counts keyed by tostring(plus): DataStores serialize to JSON, and sparse numeric
-- keys don't survive the round trip.
export type CountMap = { [string]: number }
export type Inventory = { [ItemKind]: { [Quality]: CountMap } }

-- Missing key = empty slot. Phase 2 mercenaries reuse this exact shape.
export type Loadout = { [Slot]: Item }

export type UpgradeId = "DropTier" | "EnemyCap" | "SpawnRate" | "MagnetRange"
-- Upgrade levels, all start at 0. Keys must match UpgradeId.
export type Upgrades = { DropTier: number, EnemyCap: number, SpawnRate: number, MagnetRange: number }

export type PlayerData = {
	schemaVersion: number,
	gold: number,
	inventory: Inventory, -- storage counts
	-- Mirror of the items physically lying in the player's zone, updated on every drop/merge/pickup.
	-- Positions aren't saved: on join these are re-dropped (up to the ground cap, rest to storage).
	ground: Inventory,
	equipped: Loadout,
	upgrades: Upgrades,
	rebirths: number,
	index: { [Slot]: number }, -- highest plus ever reached per slot; survives rebirth
	stats: {
		kills: number,
		bossKills: number,
		merges: number,
		castleCaptures: number,
		goldEarned: number,
	},
	offline: { lastOnline: number, incomeRate: number },
}

export type StatName = "maxHealth" | "damage" | "defense" | "walkSpeed"
export type HeroStats = { maxHealth: number, damage: number, defense: number, walkSpeed: number }

-- Balancing curves used throughout Config.
-- exp:    base * growth^(x - 1)
-- linear: min(perStep * x, max)
export type Curve = { kind: "exp", base: number, growth: number } | { kind: "linear", perStep: number, max: number }

return {}
