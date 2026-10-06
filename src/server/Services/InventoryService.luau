--!strict
-- The Forge: merging and equipping, all on count-based storage (data.inventory) + data.equipped.
-- The rules are pure functions in Shared/Gear; this service validates requests, applies them to
-- the save, keeps index/stats current, and tells the player what happened (Notify toasts).
-- An item displaced from a slot always goes to storage, so nothing can be lost (D18).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Net = require(Shared.Net)
local Gear = require(Shared.Gear)
local GearConfig = require(Shared.Config.Gear)
local DropConfig = require(Shared.Config.Drops)
local RateLimit = require(script.Parent.Parent.Util.RateLimit)
local Validate = require(script.Parent.Parent.Util.Validate)
local DataService = require(script.Parent.DataService)

type Item = Types.Item

local InventoryService = {}

local function notify(player: Player, message: string, tone: "info" | "good" | "bad")
	Net.event("Notify"):FireClient(player, message, tone)
end

local function allowed(player: Player): Types.PlayerData?
	if not RateLimit.check(player, "Inventory", DropConfig.RequestCooldown) then
		return nil
	end
	return DataService:GetData(player)
end

local function itemFromArgs(kind: unknown, quality: unknown, plus: unknown): Item?
	if not Gear.isValidItem(kind, quality, plus) then
		return nil
	end
	return { kind = kind :: any, quality = quality :: any, plus = plus :: number }
end

-- Bookkeeping after merges: index, stats, dirty keys.
local function afterMerges(player: Player, data: Types.PlayerData, merges: number, made: { Gear.Stack })
	data.stats.merges += merges
	for _, stack in made do
		Gear.recordIndex(data.index, stack.item)
	end
	for _, key in { "inventory", "equipped", "stats", "index" } do
		DataService:MarkDirty(player, key)
	end
end

-- Equips `item` (already taken out of storage); the previous item goes back to storage.
local function equip(player: Player, data: Types.PlayerData, item: Item)
	local equipped: { [string]: Item } = data.equipped :: any -- union-key typing quirk, see Formulas
	local slot = Gear.slotOf(item.kind)
	local previous = equipped[slot]
	if previous then
		Gear.addCount(data.inventory, previous, 1)
	end
	equipped[slot] = { kind = item.kind, quality = item.quality, plus = item.plus }
	DataService:MarkDirty(player, "equipped")
	DataService:MarkDirty(player, "inventory")
end

-- "Sword +6, Helmet +5": the highest result per kind, highest first.
local function describeResults(made: { Gear.Stack }): string
	local bestByKind: { [string]: number } = {}
	for _, stack in made do
		bestByKind[stack.item.kind] = math.max(bestByKind[stack.item.kind] or 0, stack.item.plus)
	end
	local parts = {}
	for kind, plus in bestByKind do
		table.insert(parts, { text = `{GearConfig.Kinds[kind :: any].displayName} +{plus}`, plus = plus })
	end
	table.sort(parts, function(a, b)
		return a.plus > b.plus
	end)
	local texts = {}
	for _, part in parts do
		table.insert(texts, part.text)
	end
	return table.concat(texts, ", ")
end

local function onMergeStack(player: Player, kind: unknown, quality: unknown, plus: unknown)
	local data = allowed(player)
	local item = itemFromArgs(kind, quality, plus)
	if not (data and item) then
		return
	end
	local made = Gear.mergeStack(data.inventory, item)
	if made > 0 then
		local result = Gear.mergeResult(item)
		afterMerges(player, data, made, { { item = result, count = made } })
		notify(player, `Merged → {Gear.displayName(result)} ×{made}`, "good")
	end
end

local function onMergeAll(player: Player)
	local data = allowed(player)
	if not data then
		return
	end
	local summary = Gear.mergeAll(data.inventory, data.equipped)
	if summary.merges > 0 then
		afterMerges(player, data, summary.merges, summary.made)
		notify(player, `Merged {summary.merges}× → {describeResults(summary.made)}`, "good")
	else
		notify(player, "Nothing to merge yet.", "info")
	end
end

local function onUpgradeEquipped(player: Player, slot: unknown)
	local data = allowed(player)
	if not data or not Validate.isSlot(slot) then
		return
	end
	local upgraded = Gear.upgradeEquipped(data.inventory, data.equipped, slot :: Types.Slot)
	if upgraded then
		afterMerges(player, data, 1, { { item = upgraded, count = 1 } })
		notify(player, `Upgraded → {Gear.displayName(upgraded)}`, "good")
	end
end

local function onEquipFromStorage(player: Player, kind: unknown, quality: unknown, plus: unknown)
	local data = allowed(player)
	local item = itemFromArgs(kind, quality, plus)
	if data and item and Gear.addCount(data.inventory, item, -1) then -- false = they don't have one
		equip(player, data, item)
	end
end

local function onEquipBest(player: Player)
	local data = allowed(player)
	if not data then
		return
	end
	local equipped: { [string]: Item } = data.equipped :: any
	local changed = {}
	for _, slot in GearConfig.Slots do
		local best = Gear.bestStored(data.inventory, slot :: any) -- loop var widened, see Formulas
		local current = equipped[slot]
		if best and (not current or best.plus > current.plus) then
			Gear.addCount(data.inventory, best, -1)
			equip(player, data, best)
			table.insert(changed, Gear.displayName(best))
		end
	end
	if #changed > 0 then
		notify(player, `Equipped {table.concat(changed, ", ")}`, "good")
	else
		notify(player, "Already wearing your best gear.", "info")
	end
end

local function onUnequip(player: Player, slot: unknown)
	local data = allowed(player)
	if not data or not Validate.isSlot(slot) then
		return
	end
	local equipped: { [string]: Item } = data.equipped :: any
	local item = equipped[slot :: string]
	if item then
		equipped[slot :: string] = nil
		Gear.addCount(data.inventory, item, 1)
		DataService:MarkDirty(player, "equipped")
		DataService:MarkDirty(player, "inventory")
	end
end

function InventoryService:Init()
	Net.event("RequestMergeStack").OnServerEvent:Connect(onMergeStack)
	Net.event("RequestMergeAll").OnServerEvent:Connect(onMergeAll)
	Net.event("RequestUpgradeEquipped").OnServerEvent:Connect(onUpgradeEquipped)
	Net.event("RequestEquipFromStorage").OnServerEvent:Connect(onEquipFromStorage)
	Net.event("RequestEquipBest").OnServerEvent:Connect(onEquipBest)
	Net.event("RequestUnequip").OnServerEvent:Connect(onUnequip)
end

return InventoryService
