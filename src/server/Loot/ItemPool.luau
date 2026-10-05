--!strict
-- Creates, dresses and recycles the physical Parts for ground items.
-- Knows nothing about ownership or save data; LootService decides what exists.
-- Released parts are parented to nil and reused, so clients see them leave and re-enter
-- workspace.Items (client code must handle ChildAdded more than once per Part).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Gear = require(Shared.Gear)
local ItemVisuals = require(Shared.Config.ItemVisuals)
local DropConfig = require(Shared.Config.Drops)

local ItemPool = {}

local KIND_VISUALS: { [string]: ItemVisuals.KindVisual } = ItemVisuals.Kinds :: any

local idle: { [string]: { BasePart } } = {}
local folder: Folder

local function create(kind: Types.ItemKind): BasePart
	local visual = KIND_VISUALS[kind]
	local part = Instance.new("Part")
	part.Name = kind
	part.Shape = visual.shape
	part.Size = visual.size
	part.Anchored = true
	part.CanCollide = false -- players walk through items
	part.CanTouch = false
	part.CanQuery = true -- clients raycast against items to pick them up
	part.Material = Enum.Material.SmoothPlastic

	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(56, 26)
	gui.StudsOffset = Vector3.new(0, 1.8, 0)
	gui.MaxDistance = ItemVisuals.LabelMaxDistance
	local label = Instance.new("TextLabel")
	label.Name = "Plus"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextStrokeTransparency = 0.2
	label.Parent = gui
	gui.Parent = part

	return part
end

-- The parent folder for live items (workspace.Items). Call once from LootService:Init.
function ItemPool.init(parent: Folder)
	folder = parent
end

-- Updates color, label and attributes to match the item (used on spawn and after a merge).
function ItemPool.dress(part: BasePart, item: Types.Item)
	local color = Gear.colorForPlus(item.plus)
	part.Color = color
	part:SetAttribute("Kind", item.kind)
	part:SetAttribute("Quality", item.quality)
	part:SetAttribute("Plus", item.plus)
	local label = (part :: any).Label.Plus :: TextLabel
	label.Text = `+{item.plus}`
	label.TextColor3 = color
end

-- Puts the part's bottom on `groundPoint`, keeping its current yaw.
function ItemPool.place(part: BasePart, groundPoint: Vector3)
	part.CFrame = CFrame.new(groundPoint + Vector3.new(0, part.Size.Y / 2, 0)) * part.CFrame.Rotation
end

function ItemPool.acquire(item: Types.Item, id: number, ownerUserId: number, groundPoint: Vector3): BasePart
	local list = idle[item.kind]
	local part = (list and table.remove(list)) or create(item.kind)
	part.CFrame = CFrame.Angles(0, math.random() * math.pi * 2, 0)
	ItemPool.place(part, groundPoint)
	ItemPool.dress(part, item)
	part:SetAttribute("ItemId", id)
	part:SetAttribute("OwnerUserId", ownerUserId)
	part.Parent = folder
	return part
end

function ItemPool.release(part: BasePart, kind: Types.ItemKind)
	part.Parent = nil
	part:SetAttribute("ItemId", nil)
	part:SetAttribute("OwnerUserId", nil)
	local list = idle[kind]
	if not list then
		list = {}
		idle[kind] = list
	end
	if #list < DropConfig.PoolMaxIdlePerKind then
		table.insert(list, part)
	else
		part:Destroy()
	end
end

return ItemPool
