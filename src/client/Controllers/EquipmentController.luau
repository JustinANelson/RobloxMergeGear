--!strict
-- Equipment panel: the four slots with what each contributes, hero totals and Gear Score.
-- Display only; Unequip sends RequestUnequip. Stats are computed with the same shared Formulas
-- the server uses, so the panel always matches what the hero actually gets.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Gear = require(Shared.Gear)
local Net = require(Shared.Net)
local Formulas = require(Shared.Formulas)
local GearConfig = require(Shared.Config.Gear)
local Ui = require(script.Parent.Parent.Util.Ui)
local DataController = require(script.Parent.DataController)
local MenuController = require(script.Parent.MenuController)

type SlotRow = { item: TextLabel, stats: TextLabel, unequip: TextButton }

local STAT_LABELS: { { key: string, label: string } } = {
	{ key = "maxHealth", label = "HP" },
	{ key = "damage", label = "Damage" },
	{ key = "defense", label = "Defense" },
	{ key = "walkSpeed", label = "Speed" },
}

local EquipmentController = {}

local rows: { [string]: SlotRow } = {}
local gearScoreLabel: TextLabel
local totalsLabel: TextLabel

-- "+31 Damage · +2 Defense": what this item adds over the bare hero.
local function contribution(slot: string, item: Types.Item): string
	local base = Formulas.heroStats({})
	local withItem = Formulas.heroStats({ [slot] = item } :: any)
	local parts = {}
	for _, stat in STAT_LABELS do
		local delta = (withItem :: any)[stat.key] - (base :: any)[stat.key]
		if delta > 0 then
			table.insert(parts, `+{Ui.stat(delta)} {stat.label}`)
		end
	end
	return table.concat(parts, " · ")
end

local function render(loadout: Types.Loadout)
	local equipped: { [string]: Types.Item } = loadout :: any
	for slot, row in rows do
		local item = equipped[slot]
		if item then
			row.item.Text = Gear.displayName(item)
			row.item.TextColor3 = Gear.colorForPlus(item.plus)
			row.stats.Text = contribution(slot, item)
			row.unequip.Visible = true
		else
			row.item.Text = "Empty"
			row.item.TextColor3 = Ui.Theme.muted
			row.stats.Text = ""
			row.unequip.Visible = false
		end
	end

	local stats = Formulas.heroStats(loadout)
	local totals = {}
	for _, stat in STAT_LABELS do
		table.insert(totals, `{stat.label} {Ui.stat((stats :: any)[stat.key])}`)
	end
	totalsLabel.Text = table.concat(totals, "   ")
	gearScoreLabel.Text = `Gear Score {Ui.stat(Formulas.gearScore(loadout))}`
end

local function buildSlotRow(slot: string, order: number, parent: Instance): SlotRow
	local row = Ui.new("Frame", {
		Name = slot,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 58),
		BackgroundColor3 = Ui.Theme.row,
		Parent = parent,
	}, { Ui.corner(8) })
	Ui.text({
		Text = slot,
		TextColor3 = Ui.Theme.muted,
		TextSize = 13,
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -120, 0, 16),
		Parent = row,
	})
	local itemLabel = Ui.text({
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		Position = UDim2.fromOffset(12, 20),
		Size = UDim2.new(1, -120, 0, 20),
		Parent = row,
	})
	local statsLabel = Ui.text({
		TextColor3 = Ui.Theme.muted,
		TextSize = 12,
		Position = UDim2.fromOffset(12, 40),
		Size = UDim2.new(1, -120, 0, 14),
		Parent = row,
	})
	local unequip = Ui.button("Unequip", Ui.Theme.buttonAlt, function()
		Net.event("RequestUnequip"):FireServer(slot)
	end)
	unequip.AnchorPoint = Vector2.new(1, 0.5)
	unequip.Position = UDim2.new(1, -10, 0.5, 0)
	unequip.Parent = row
	return { item = itemLabel, stats = statsLabel, unequip = unequip }
end

function EquipmentController:Start()
	local window, content = Ui.window("Equipment", function()
		MenuController:Close()
	end)
	Ui.list(8).Parent = content

	gearScoreLabel = Ui.text({
		LayoutOrder = 0,
		Font = Enum.Font.GothamBold,
		TextSize = 20,
		TextColor3 = Ui.Theme.accent,
		Size = UDim2.new(1, 0, 0, 24),
		Parent = content,
	})
	for i, slot in GearConfig.Slots do
		rows[slot] = buildSlotRow(slot, i, content)
	end
	totalsLabel = Ui.text({
		LayoutOrder = 10,
		TextSize = 14,
		Size = UDim2.new(1, 0, 0, 20),
		Parent = content,
	})
	Ui.text({
		LayoutOrder = 11,
		Text = "Tip: drag an item from the ground onto your hero to equip it.",
		TextColor3 = Ui.Theme.muted,
		TextSize = 12,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 30),
		Parent = content,
	})

	MenuController:AddPanel("Gear", 1, window)
	DataController:Observe("equipped", render)
end

return EquipmentController
