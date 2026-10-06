--!strict
-- Loot-fly effect: when the server says an item was gained (ItemGained), a local copy of it pops
-- up where the enemy died, shows its "+N", then flies into the hero. Purely cosmetic; the item
-- is already in the bag by the time this plays.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Gear = require(Shared.Gear)
local ItemVisuals = require(Shared.Config.ItemVisuals)
local Fx = require(script.Parent.Parent.Util.Fx)

local POP_SECONDS = 0.35
local FLY_SECONDS = 0.35

local localPlayer = Players.LocalPlayer :: Player

local KIND_VISUALS: { [string]: ItemVisuals.KindVisual } = ItemVisuals.Kinds :: any

local LootFxController = {}

local function play(kind: string, plus: number, from: Vector3)
	local visual = KIND_VISUALS[kind]
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (visual and root) or (root.Position - from).Magnitude > 150 then
		return
	end
	local color = Gear.colorForPlus(plus)
	local part = Fx.part({
		Shape = visual.shape,
		Size = visual.size,
		CFrame = CFrame.new(from) * CFrame.Angles(0, math.random() * math.pi * 2, 0),
		Color = color,
		Material = Enum.Material.SmoothPlastic,
	})
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(56, 26)
	gui.StudsOffset = Vector3.new(0, 1.6, 0)
	gui.AlwaysOnTop = true
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.Text = `+{plus}`
	label.Parent = gui
	gui.Parent = part

	-- Pop up, then fly into the hero (re-reading the hero's position so it follows them).
	local up = TweenService:Create(part, TweenInfo.new(POP_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		CFrame = part.CFrame + Vector3.new(0, 3, 0),
	})
	up.Completed:Once(function()
		local target = root.CFrame
		Fx.tweenThenDestroy(part, FLY_SECONDS, { CFrame = target, Size = visual.size * 0.3 })
		task.delay(FLY_SECONDS, function()
			Fx.pop(target.Position, color, 0.5, 3, 0.25)
		end)
	end)
	up:Play()
end

function LootFxController:Init()
	Net.event("ItemGained").OnClientEvent:Connect(function(kind: string, _quality: string, plus: number, from: Vector3?)
		if from then
			play(kind, plus, from)
		end
	end)
end

return LootFxController
