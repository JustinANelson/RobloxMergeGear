--!strict
-- Moves items between storage (data.inventory), the ground (via LootService) and equipped slots.
-- Every move changes both sides in the same step, so the save is never half-moved (D7).
-- An item that's displaced from a slot always goes to storage, so nothing can be lost.
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
local LootService = require(script.Parent.LootService)

type Item = Types.Item

local InventoryService = {}

-- Equips `item` (already removed from wherever it came from); the previous item goes to storage.
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

local function allowed(player: Player): Types.PlayerData?
	if not RateLimit.check(player, "Inventory", DropConfig.RequestCooldown) then
		return nil
	end
	return DataService:GetData(player)
end

local function onEquipFromStorage(player: Player, kind: unknown, quality: unknown, plus: unknown)
	local data = allowed(player)
	if not data or not Gear.isValidItem(kind, quality, plus) then
		return
	end
	local item: Item = { kind = kind :: any, quality = quality :: any, plus = plus :: number }
	if Gear.addCount(data.inventory, item, -1) then -- false = they don't have one
		equip(player, data, item)
	end
end

local function onEquipFromGround(player: Player, itemId: unknown)
	local data = allowed(player)
	if not data or not Validate.isId(itemId) then
		return
	end
	local _, part = LootService:GetGroundItem(player, itemId :: number)
	if not part or not Validate.withinReach(player, part.Position) then
		return
	end
	local item = LootService:TakeGroundItem(player, itemId :: number)
	if item then
		equip(player, data, item)
	end
end

local function onUnequip(player: Player, slot: unknown)
	local data = allowed(player)
	if not data or type(slot) ~= "string" or not table.find(GearConfig.Slots, slot :: any) then
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

local function onStore(player: Player, itemId: unknown)
	local data = allowed(player)
	if not data or not Validate.isId(itemId) then
		return
	end
	local _, part = LootService:GetGroundItem(player, itemId :: number)
	if not part or not Validate.withinReach(player, part.Position) then
		return
	end
	local item = LootService:TakeGroundItem(player, itemId :: number)
	if item then
		Gear.addCount(data.inventory, item, 1)
		DataService:MarkDirty(player, "inventory")
	end
end

local function onWithdraw(player: Player, kind: unknown, quality: unknown, plus: unknown)
	local data = allowed(player)
	if not data or not Gear.isValidItem(kind, quality, plus) then
		return
	end
	local item: Item = { kind = kind :: any, quality = quality :: any, plus = plus :: number }
	if Gear.count(data.inventory, item) < 1 then
		return
	end
	-- Land it next to the hero (LootService clamps onto the pad; random spot if they're elsewhere).
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local point: Vector3? = nil
	if root then
		local angle = math.random() * math.pi * 2
		local radius = DropConfig.WithdrawRadius
		point = root.Position + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
	end
	if LootService:PlaceOnGround(player, item, point) then
		Gear.addCount(data.inventory, item, -1)
		DataService:MarkDirty(player, "inventory")
	end
end

function InventoryService:Init()
	Net.event("RequestEquipFromStorage").OnServerEvent:Connect(onEquipFromStorage)
	Net.event("RequestEquipFromGround").OnServerEvent:Connect(onEquipFromGround)
	Net.event("RequestUnequip").OnServerEvent:Connect(onUnequip)
	Net.event("RequestStore").OnServerEvent:Connect(onStore)
	Net.event("RequestWithdraw").OnServerEvent:Connect(onWithdraw)
end

return InventoryService
