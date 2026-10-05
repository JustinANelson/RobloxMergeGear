--!strict
-- One-time defaults that can't live in DataTemplate (see the Reconcile note there).
-- Runs on every load after migrations; each grant is guarded by its own flag so it applies once.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Gear = require(Shared.Gear)
local GearConfig = require(Shared.Config.Gear)

local NewPlayer = {}

-- String-keyed view: the type solver widens union keys when iterating (see Formulas).
local STARTER_KIT: { [string]: number } = GearConfig.StarterKit :: any

-- Equips the starter kit into any EMPTY slot (never replaces gear). Also used by rebirth (M7).
function NewPlayer.equipStarterKit(data: Types.PlayerData)
	local equipped: { [string]: Types.Item } = data.equipped :: any
	local index: { [string]: number } = data.index :: any
	for kind, plus in STARTER_KIT do
		local slot = Gear.slotOf(kind :: any)
		if not equipped[slot] then
			equipped[slot] = { kind = kind :: any, quality = "Normal", plus = plus }
			index[slot] = math.max(index[slot] or 0, plus)
		end
	end
end

function NewPlayer.apply(data: Types.PlayerData)
	if not data.starterKitGranted then
		NewPlayer.equipStarterKit(data)
		data.starterKitGranted = true
	end
end

return NewPlayer
