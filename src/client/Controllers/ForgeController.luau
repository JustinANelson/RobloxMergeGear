--!strict
-- The Forge panel: the bag, grouped by slot. Each slot shows the equipped item (with an
-- "Upgrade" button when a matching copy is stored), then each stored stack with a merge preview
-- and Merge / Equip buttons. The header has Equip Best and Merge All (cascades, see Gear.mergeAll).
-- The panel only sends requests; it redraws from replicated data (rebuilt only while open).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Gear = require(Shared.Gear)
local Net = require(Shared.Net)
local GearConfig = require(Shared.Config.Gear)
local Ui = require(script.Parent.Parent.Util.Ui)
local DataController = require(script.Parent.DataController)
local MenuController = require(script.Parent.MenuController)

local PANEL = "Forge"

local ForgeController = {}

local header: TextLabel
local list: ScrollingFrame
local stale = true
local rowOrder = 0

local function nextOrder(): number
	rowOrder += 1
	return rowOrder
end

local function row(height: number, color: Color3?): Frame
	return Ui.new("Frame", {
		LayoutOrder = nextOrder(),
		Size = UDim2.new(1, -8, 0, height),
		BackgroundColor3 = color or Ui.Theme.row,
		Parent = list,
	}, { Ui.corner(8) })
end

local function buttonBar(parent: Instance, width: number): Frame
	local bar = Ui.new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(width, 30),
		BackgroundTransparency = 1,
		Parent = parent,
	}, { Ui.list(6, true) })
	local layout = bar:FindFirstChildOfClass("UIListLayout") :: UIListLayout
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	return bar
end

local function slotHeader(slot: Types.Slot, equipped: Types.Item?, storedCopies: number)
	local frame = row(40, Ui.Theme.window)
	local text = if equipped
		then `{slot}  ·  equipped <font color="#{Gear.colorForPlus(equipped.plus):ToHex()}">{Gear.displayName(equipped)}</font>`
		else `{slot}  ·  nothing equipped`
	Ui.text({
		Text = text,
		RichText = true,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -150, 1, 0),
		Parent = frame,
	})
	if equipped and storedCopies > 0 and equipped.plus < GearConfig.MaxPlus then
		local bar = buttonBar(frame, 140)
		local upgrade = Ui.button(`Upgrade → +{equipped.plus + 1}`, Ui.Theme.good, function()
			Net.event("RequestUpgradeEquipped"):FireServer(slot)
		end)
		upgrade.Size = UDim2.fromOffset(136, 30)
		upgrade.TextColor3 = Color3.new(0, 0, 0)
		upgrade.Parent = bar
	end
end

local function stackRow(stack: Gear.Stack, equipped: Types.Item?)
	local item = stack.item
	local frame = row(50)
	Ui.text({
		Text = `{Gear.displayName(item)}  ×{stack.count}`,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = Gear.colorForPlus(item.plus),
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -190, 0, 20),
		Parent = frame,
	})

	local canMerge = stack.count >= 2 and item.plus < GearConfig.MaxPlus
	local note, noteColor = "", Ui.Theme.muted
	if canMerge then
		local pairCount = stack.count // 2
		note = `{pairCount} pair{if pairCount > 1 then "s" else ""} → +{item.plus + 1} ×{pairCount}`
		noteColor = Ui.Theme.accent
	end
	if not equipped or item.plus > equipped.plus then
		note = (if note ~= "" then note .. "   " else "") .. "▲ better than equipped"
		noteColor = if canMerge then noteColor else Ui.Theme.good
	end
	Ui.text({
		Text = note,
		TextSize = 12,
		TextColor3 = noteColor,
		Position = UDim2.fromOffset(12, 27),
		Size = UDim2.new(1, -190, 0, 16),
		Parent = frame,
	})

	local bar = buttonBar(frame, 176)
	if canMerge then
		Ui.button("Merge", Ui.Theme.button, function()
			Net.event("RequestMergeStack"):FireServer(item.kind, item.quality, item.plus)
		end).Parent =
			bar
	end
	Ui.button("Equip", Ui.Theme.buttonAlt, function()
		Net.event("RequestEquipFromStorage"):FireServer(item.kind, item.quality, item.plus)
	end).Parent =
		bar
end

local function rebuild()
	local data = DataController:Get()
	if not data then
		return
	end
	stale = false
	rowOrder = 0
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local equipped: { [string]: Types.Item } = data.equipped :: any
	local stacks = Gear.stacks(data.inventory)
	local total = 0
	for _, stack in stacks do
		total += stack.count
	end
	header.Text = `Bag: {total} item{if total == 1 then "" else "s"}`

	for _, slot in GearConfig.Slots do
		local current = equipped[slot]
		slotHeader(
			slot :: any,
			current, -- loop var widened to string, see Formulas
			if current then Gear.count(data.inventory, current) else 0
		)
		local any = false
		for _, stack in stacks do
			if Gear.slotOf(stack.item.kind) == slot then
				stackRow(stack, current)
				any = true
			end
		end
		if not any then
			local frame = row(28)
			frame.BackgroundTransparency = 1
			Ui.text({
				Text = "Nothing stored",
				TextSize = 13,
				TextColor3 = Ui.Theme.muted,
				Position = UDim2.fromOffset(12, 0),
				Size = UDim2.new(1, -12, 1, 0),
				Parent = frame,
			})
		end
	end
end

local function onDataChanged(key: string)
	if key == "inventory" or key == "equipped" then
		if MenuController:IsOpen(PANEL) then
			rebuild()
		else
			stale = true
		end
	end
end

function ForgeController:Start()
	local window, content = Ui.window(PANEL, function()
		MenuController:Close()
	end)

	header = Ui.text({
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		Size = UDim2.new(1, -240, 0, 32),
		Parent = content,
	})
	local actions = Ui.new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(236, 32),
		BackgroundTransparency = 1,
		Parent = content,
	}, { Ui.list(8, true) });
	(actions:FindFirstChildOfClass("UIListLayout") :: UIListLayout).HorizontalAlignment = Enum.HorizontalAlignment.Right
	local equipBest = Ui.button("Equip Best", Ui.Theme.buttonAlt, function()
		Net.event("RequestEquipBest"):FireServer()
	end)
	equipBest.Size = UDim2.fromOffset(110, 32)
	equipBest.Parent = actions
	local mergeAll = Ui.button("Merge All", Ui.Theme.good, function()
		Net.event("RequestMergeAll"):FireServer()
	end)
	mergeAll.Size = UDim2.fromOffset(110, 32)
	mergeAll.TextColor3 = Color3.new(0, 0, 0)
	mergeAll.Parent = actions

	list = Ui.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(1, 0, 1, -42),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = content,
	}, { Ui.list(6) })

	MenuController:AddPanel(PANEL, 2, window, function()
		if stale then
			rebuild()
		end
	end)
	DataController.Changed:Connect(onDataChanged)
end

return ForgeController
