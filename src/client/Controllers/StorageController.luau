--!strict
-- Storage panel: every stored stack with Equip and Take out buttons, plus ground/storage counts.
-- The list is rebuilt from data only while the panel is open (or when it opens), since it's small.
-- Storing works by dragging a ground item onto the "Storage" menu button (see DragController).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Gear = require(Shared.Gear)
local Net = require(Shared.Net)
local DropConfig = require(Shared.Config.Drops)
local Ui = require(script.Parent.Parent.Util.Ui)
local DataController = require(script.Parent.DataController)
local MenuController = require(script.Parent.MenuController)

local PANEL = "Storage"

local StorageController = {}

local header: TextLabel
local list: ScrollingFrame
local emptyLabel: TextLabel
local stale = true

local function upgradeNote(item: Types.Item, equipped: { [string]: Types.Item }): (string, Color3)
	local current = equipped[Gear.slotOf(item.kind)]
	if not current then
		return "Empty slot", Ui.Theme.good
	elseif item.plus > current.plus then
		return `▲ over +{current.plus}`, Ui.Theme.good
	end
	return `Equipped +{current.plus}`, Ui.Theme.muted
end

local function buildRow(stack: Gear.Stack, order: number, equipped: { [string]: Types.Item }, groundFull: boolean)
	local item = stack.item
	local row = Ui.new("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, 52),
		BackgroundColor3 = Ui.Theme.row,
		Parent = list,
	}, { Ui.corner(8) })
	Ui.text({
		Text = `{Gear.displayName(item)}  ×{stack.count}`,
		Font = Enum.Font.GothamBold,
		TextSize = 17,
		TextColor3 = Gear.colorForPlus(item.plus),
		Position = UDim2.fromOffset(12, 7),
		Size = UDim2.new(1, -200, 0, 20),
		Parent = row,
	})
	local note, noteColor = upgradeNote(item, equipped)
	Ui.text({
		Text = note,
		TextSize = 12,
		TextColor3 = noteColor,
		Position = UDim2.fromOffset(12, 29),
		Size = UDim2.new(1, -200, 0, 16),
		Parent = row,
	})

	local buttons = Ui.new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(176, 30),
		BackgroundTransparency = 1,
		Parent = row,
	}, { Ui.list(8, true) })
	Ui.button("Equip", Ui.Theme.button, function()
		Net.event("RequestEquipFromStorage"):FireServer(item.kind, item.quality, item.plus)
	end).Parent =
		buttons
	local takeOut = Ui.button("Take out", Ui.Theme.buttonAlt, function()
		if not groundFull then -- the server would refuse anyway; skip the round trip
			Net.event("RequestWithdraw"):FireServer(item.kind, item.quality, item.plus)
		end
	end)
	if groundFull then
		takeOut.AutoButtonColor = false
		takeOut.TextTransparency = 0.6
	end
	takeOut.Parent = buttons
end

local function rebuild()
	local data = DataController:Get()
	if not data then
		return
	end
	stale = false
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local onGround = Gear.totalCount(data.ground)
	local groundFull = onGround >= DropConfig.GroundCap
	local stacks = Gear.stacks(data.inventory)
	local stored = 0
	for i, stack in stacks do
		stored += stack.count
		buildRow(stack, i, data.equipped :: any, groundFull)
	end
	header.Text =
		`On ground {onGround} / {DropConfig.GroundCap}{if groundFull then " (full)" else ""}   ·   Stored {stored}`
	header.TextColor3 = if groundFull then Ui.Theme.bad else Ui.Theme.text
	emptyLabel.Visible = #stacks == 0
end

local function onDataChanged(key: string)
	if key == "inventory" or key == "ground" or key == "equipped" then
		if MenuController:IsOpen(PANEL) then
			rebuild()
		else
			stale = true
		end
	end
end

function StorageController:Start()
	local window, content = Ui.window(PANEL, function()
		MenuController:Close()
	end)

	header = Ui.text({ TextSize = 14, Size = UDim2.new(1, 0, 0, 20), Parent = content })
	Ui.text({
		Text = "Drag ground items onto the Storage button to store them. Overflow past the ground cap lands here too.",
		TextColor3 = Ui.Theme.muted,
		TextSize = 12,
		TextWrapped = true,
		Position = UDim2.fromOffset(0, 22),
		Size = UDim2.new(1, 0, 0, 30),
		Parent = content,
	})
	list = Ui.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 58),
		Size = UDim2.new(1, 0, 1, -58),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = content,
	}, { Ui.list(6) })
	emptyLabel = Ui.text({
		Text = "Storage is empty.",
		TextColor3 = Ui.Theme.muted,
		Position = UDim2.fromOffset(0, 66),
		Size = UDim2.new(1, 0, 0, 20),
		Visible = false,
		Parent = content,
	})

	MenuController:AddPanel(PANEL, 2, window, function()
		if stale then
			rebuild()
		end
	end)
	DataController.Changed:Connect(onDataChanged)
end

return StorageController
