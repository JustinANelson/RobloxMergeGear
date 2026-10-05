--!strict
-- Item identity, merge rules, and count-based storage helpers. Pure: operates on plain tables.
local Types = require(script.Parent.Types)
local GearConfig = require(script.Parent.Config.Gear)
local ItemVisuals = require(script.Parent.Config.ItemVisuals)

local Gear = {}

function Gear.slotOf(kind: Types.ItemKind): Types.Slot
	return GearConfig.Kinds[kind].slot
end

function Gear.isValidKind(kind: unknown): boolean
	return type(kind) == "string" and GearConfig.Kinds[kind :: any] ~= nil
end

-- For untrusted input (remote args): a real kind, a known quality, an integer plus in range.
function Gear.isValidItem(kind: unknown, quality: unknown, plus: unknown): boolean
	return Gear.isValidKind(kind)
		and table.find(GearConfig.Qualities, quality :: any) ~= nil
		and type(plus) == "number"
		and plus % 1 == 0
		and plus >= 1
		and plus <= GearConfig.MaxPlus
end

function Gear.displayName(item: Types.Item): string
	return `{GearConfig.Kinds[item.kind].displayName} +{item.plus}`
end

-- Two items merge when kind, quality and plus all match and the result stays within MaxPlus.
function Gear.canMerge(a: Types.Item, b: Types.Item): boolean
	return a.kind == b.kind and a.quality == b.quality and a.plus == b.plus and a.plus < GearConfig.MaxPlus
end

function Gear.mergeResult(a: Types.Item): Types.Item
	return { kind = a.kind, quality = a.quality, plus = a.plus + 1 }
end

function Gear.colorForPlus(plus: number): Color3
	for _, band in ItemVisuals.PlusBands do
		if plus <= band.maxPlus then
			return band.color
		end
	end
	return ItemVisuals.PlusBands[#ItemVisuals.PlusBands].color
end

-- Storage counts ---------------------------------------------------------------

local function bucket(inventory: Types.Inventory, item: Types.Item): Types.CountMap
	local byQuality = inventory[item.kind]
	if not byQuality then
		byQuality = {}
		inventory[item.kind] = byQuality
	end
	local counts = byQuality[item.quality]
	if not counts then
		counts = {}
		byQuality[item.quality] = counts
	end
	return counts
end

function Gear.count(inventory: Types.Inventory, item: Types.Item): number
	return bucket(inventory, item)[tostring(item.plus)] or 0
end

-- Adds (or with negative delta, removes) items. Returns false without changing anything if
-- that would make the count negative. Zero counts are removed to keep saves small.
function Gear.addCount(inventory: Types.Inventory, item: Types.Item, delta: number): boolean
	local counts = bucket(inventory, item)
	local key = tostring(item.plus)
	local new = (counts[key] or 0) + delta
	if new < 0 then
		return false
	end
	(counts :: any)[key] = if new == 0 then nil else new
	return true
end

export type Stack = { item: Types.Item, count: number }

local SLOT_ORDER: { [string]: number } = {}
for i, slot in GearConfig.Slots do
	SLOT_ORDER[slot] = i
end

-- Flattens a count map into stacks, sorted by slot order, then plus (highest first).
function Gear.stacks(inventory: Types.Inventory): { Stack }
	local result: { Stack } = {}
	for kind, byQuality in inventory :: any do
		for quality, counts in byQuality do
			for key, count in counts do
				if count > 0 then
					table.insert(result, {
						item = { kind = kind, quality = quality, plus = tonumber(key) :: number },
						count = count,
					})
				end
			end
		end
	end
	table.sort(result, function(a, b)
		local slotA = SLOT_ORDER[Gear.slotOf(a.item.kind)]
		local slotB = SLOT_ORDER[Gear.slotOf(b.item.kind)]
		if slotA ~= slotB then
			return slotA < slotB
		elseif a.item.kind ~= b.item.kind then
			return a.item.kind < b.item.kind
		end
		return a.item.plus > b.item.plus
	end)
	return result
end

function Gear.totalCount(inventory: Types.Inventory): number
	local total = 0
	for _, stack in Gear.stacks(inventory) do
		total += stack.count
	end
	return total
end

return Gear
