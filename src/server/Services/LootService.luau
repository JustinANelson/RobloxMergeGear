--!strict
-- Item drops. A kill rolls an item that goes straight into the owner's bag (data.inventory);
-- the owner's client is told where it came from so it can play the loot-fly effect.
-- Nothing item-related exists in the world, so there's no world/save state to keep in sync.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Net = require(Shared.Net)
local Gear = require(Shared.Gear)
local Formulas = require(Shared.Formulas)
local DropConfig = require(Shared.Config.Drops)
local DataService = require(script.Parent.DataService)
local EnemyService = require(script.Parent.EnemyService)

type Item = Types.Item

local LootService = {}

local rng = Random.new()

-- Gives a player a NEW item (drops, rewards, debug): adds it to the bag and the index.
-- `fromPosition` is where the client's loot-fly effect starts (nil = no effect).
-- Returns false if the player's save isn't loaded.
function LootService:GiveItem(player: Player, item: Item, fromPosition: Vector3?): boolean
	local data = DataService:GetData(player)
	if not data then
		return false
	end
	Gear.addCount(data.inventory, item, 1)
	DataService:MarkDirty(player, "inventory")
	if Gear.recordIndex(data.index, item) then
		DataService:MarkDirty(player, "index")
	end
	Net.event("ItemGained"):FireClient(player, item.kind, item.quality, item.plus, fromPosition)
	return true
end

function LootService:Start()
	EnemyService.EnemyKilled:Connect(function(owner, enemy)
		local data = DataService:GetData(owner)
		if not data or (not enemy.isBoss and rng:NextNumber() >= DropConfig.DropChance) then
			return
		end
		local item: Item = {
			kind = Formulas.rollDropKind(rng:NextNumber()),
			quality = "Normal",
			plus = Formulas.rollDropPlus(data.upgrades.DropTier, data.rebirths, enemy.isBoss, rng:NextNumber()),
		}
		LootService:GiveItem(owner, item, enemy.root.Position)
	end)
end

return LootService
