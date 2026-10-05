--!strict
-- Top-of-screen HUD: gold, Gear Score, Drop Tier.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Formulas = require(Shared.Formulas)
local Format = require(Shared.Util.Format)
local DataController = require(script.Parent.DataController)

local HudController = {}

local function makePill(parent: Instance, order: number, caption: string, accent: Color3): TextLabel
	local pill = Instance.new("Frame")
	pill.Name = caption
	pill.LayoutOrder = order
	pill.Size = UDim2.fromOffset(150, 46)
	pill.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	pill.BackgroundTransparency = 0.25

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = pill

	local stroke = Instance.new("UIStroke")
	stroke.Color = accent
	stroke.Thickness = 2
	stroke.Parent = pill

	local captionLabel = Instance.new("TextLabel")
	captionLabel.Size = UDim2.fromScale(1, 0.38)
	captionLabel.Position = UDim2.fromScale(0, 0.06)
	captionLabel.BackgroundTransparency = 1
	captionLabel.Font = Enum.Font.GothamMedium
	captionLabel.TextScaled = true
	captionLabel.TextColor3 = accent
	captionLabel.Text = caption
	captionLabel.Parent = pill

	local value = Instance.new("TextLabel")
	value.Name = "Value"
	value.Size = UDim2.fromScale(1, 0.5)
	value.Position = UDim2.fromScale(0, 0.44)
	value.BackgroundTransparency = 1
	value.Font = Enum.Font.GothamBold
	value.TextScaled = true
	value.TextColor3 = Color3.new(1, 1, 1)
	value.Text = "…"
	value.Parent = pill

	pill.Parent = parent
	return value
end

function HudController:Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, 8)
	bar.Size = UDim2.fromOffset(0, 46)
	bar.AutomaticSize = Enum.AutomaticSize.X
	bar.BackgroundTransparency = 1
	bar.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = bar

	local gold = makePill(bar, 1, "Gold", Color3.fromRGB(255, 205, 70))
	local gearScore = makePill(bar, 2, "Gear Score", Color3.fromRGB(120, 200, 255))
	local dropTier = makePill(bar, 3, "Drop Tier", Color3.fromRGB(170, 255, 140))

	DataController:Observe("gold", function(value: number)
		gold.Text = Format.abbreviate(value)
	end)
	DataController:Observe("equipped", function(loadout: Types.Loadout)
		gearScore.Text = Format.abbreviate(Formulas.gearScore(loadout))
	end)
	DataController:Observe("upgrades", function(upgrades: Types.Upgrades)
		dropTier.Text = `+{Formulas.dropPlus(upgrades.DropTier)}`
	end)

	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
end

return HudController
