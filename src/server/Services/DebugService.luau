--!strict
-- Studio-only chat commands for testing. Does nothing in live servers.
--   /gold [amount]        add gold (default 1000)
--   /droptier <level>     set the Drop Tier upgrade level
--   /equip <kind> <plus>  equip an item, e.g. /equip sword 5
--   /unequip              move all equipped gear to storage
--   /drop <kind> <plus> [count]  add items to your bag, e.g. /drop sword 1 8
--   /resetdata            wipe your save back to defaults
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Gear = require(Shared.Gear)
local GearConfig = require(Shared.Config.Gear)
local UpgradeConfig = require(Shared.Config.Upgrades)
local DataService = require(script.Parent.DataService)
local LootService = require(script.Parent.LootService)

type Handler = (player: Player, data: Types.PlayerData, args: { string }) -> ()

local DebugService = {}

local function capitalize(s: string): string
	return string.upper(string.sub(s, 1, 1)) .. string.lower(string.sub(s, 2))
end

function DebugService:Start()
	if not RunService:IsStudio() then
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = "DebugCommands"

	local function command(alias: string, handler: Handler)
		local cmd = Instance.new("TextChatCommand")
		cmd.Name = alias
		cmd.PrimaryAlias = "/" .. alias
		-- Created on the server, so Triggered fires on the server.
		cmd.Triggered:Connect(function(source: TextSource, text: string)
			local player = Players:GetPlayerByUserId(source.UserId)
			local data = player and DataService:GetData(player)
			if player and data then
				local args = string.split(text, " ")
				table.remove(args, 1) -- the alias itself
				handler(player, data, args)
			end
		end)
		cmd.Parent = folder
	end

	command("gold", function(player, data, args)
		data.gold += tonumber(args[1]) or 1000
		DataService:MarkDirty(player, "gold")
	end)

	command("droptier", function(player, data, args)
		local level = tonumber(args[1])
		if level then
			data.upgrades.DropTier = math.clamp(math.floor(level), 0, UpgradeConfig.Defs.DropTier.maxLevel)
			DataService:MarkDirty(player, "upgrades")
		end
	end)

	command("equip", function(player, data, args)
		local kind = capitalize(args[1] or "")
		local plus = tonumber(args[2])
		if not Gear.isValidKind(kind) or not plus then
			warn("[Debug] usage: /equip <helmet|armor|boots|sword> <plus>")
			return
		end
		local item: Types.Item = {
			kind = kind :: Types.ItemKind,
			quality = "Normal",
			plus = math.clamp(math.floor(plus), 1, GearConfig.MaxPlus),
		}
		data.equipped[Gear.slotOf(item.kind)] = item
		DataService:MarkDirty(player, "equipped")
	end)

	command("unequip", function(player, data)
		-- To storage, like the real Unequip button, so nothing is lost.
		for _, item in data.equipped :: any do
			Gear.addCount(data.inventory, item, 1)
		end
		table.clear(data.equipped)
		DataService:MarkDirty(player, "equipped")
		DataService:MarkDirty(player, "inventory")
	end)

	command("drop", function(player, _data, args)
		local kind = capitalize(args[1] or "")
		local plus = tonumber(args[2])
		if not Gear.isValidKind(kind) or not plus then
			warn("[Debug] usage: /drop <helmet|armor|boots|sword> <plus> [count]")
			return
		end
		local item: Types.Item = {
			kind = kind :: Types.ItemKind,
			quality = "Normal",
			plus = math.clamp(math.floor(plus), 1, GearConfig.MaxPlus),
		}
		for _ = 1, math.clamp(math.floor(tonumber(args[3]) or 1), 1, 100) do
			LootService:GiveItem(player, table.clone(item), nil)
		end
	end)

	command("resetdata", function(player)
		DataService:ResetData(player)
	end)

	folder.Parent = TextChatService
end

return DebugService
