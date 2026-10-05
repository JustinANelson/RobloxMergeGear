--!strict
-- Purely cosmetic combat feedback, derived from replicated state (no remotes):
--   * enemy Humanoid health drops -> damage number + slash from the hero to the enemy
--   * enemy removed               -> death puff
--   * coin removed near the hero  -> coin flies into the hero
-- Only the local player's own enemies/coins get effects. All FX parts are client-only.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer :: Player

local CombatFxController = {}

local fxFolder: Folder

local function localRoot(): BasePart?
	local character = localPlayer.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function fxPart(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = fxFolder
	return part
end

local function tweenThenDestroy(instance: Instance, seconds: number, goal: { [string]: any })
	local tween =
		TweenService:Create(instance, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	tween.Completed:Once(function()
		instance:Destroy()
	end)
	tween:Play()
end

local function damageNumber(position: Vector3, amount: number)
	local anchor = fxPart({ Transparency = 1, Size = Vector3.one * 0.2, CFrame = CFrame.new(position) })
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(80, 32)
	gui.StudsOffset = Vector3.new(math.random() * 2 - 1, 2, 0)
	gui.AlwaysOnTop = true
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 235, 120)
	label.TextStrokeTransparency = 0.3
	label.Text = tostring(math.floor(amount + 0.5))
	label.Parent = gui
	gui.Parent = anchor

	TweenService:Create(gui, TweenInfo.new(0.6), { StudsOffset = gui.StudsOffset + Vector3.new(0, 2.5, 0) }):Play()
	tweenThenDestroy(label, 0.6, { TextTransparency = 1, TextStrokeTransparency = 1 })
	task.delay(0.65, function()
		anchor:Destroy()
	end)
end

local function slash(from: Vector3, to: Vector3)
	local length = (to - from).Magnitude
	local part = fxPart({
		Size = Vector3.new(0.3, 0.3, length),
		CFrame = CFrame.lookAt((from + to) / 2, to),
		Color = Color3.fromRGB(255, 255, 255),
		Transparency = 0.2,
	})
	tweenThenDestroy(part, 0.15, { Transparency = 1, Size = Vector3.new(0.05, 0.05, length) })
end

local function puff(position: Vector3)
	local part = fxPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 2,
		CFrame = CFrame.new(position),
		Color = Color3.fromRGB(255, 120, 90),
		Transparency = 0.3,
	})
	tweenThenDestroy(part, 0.35, { Size = Vector3.one * 6, Transparency = 1 })
end

local function watchEnemy(model: Instance)
	if not model:IsA("Model") or model:GetAttribute("OwnerUserId") ~= localPlayer.UserId then
		return
	end
	local humanoid = model:WaitForChild("Humanoid", 5) :: Humanoid?
	local root = model:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	if not (humanoid and root) then
		return
	end

	local lastHealth = humanoid.Health
	local lastPosition = root.Position
	local healthConnection = humanoid.HealthChanged:Connect(function(health)
		lastPosition = root.Position
		local delta = lastHealth - health
		lastHealth = health
		if delta > 0 then
			damageNumber(root.Position + Vector3.new(0, 2.5, 0), delta)
			local heroRoot = localRoot()
			if heroRoot then
				slash(heroRoot.Position, root.Position)
			end
		end
	end)

	local ancestryConnection
	ancestryConnection = model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) then
			healthConnection:Disconnect()
			ancestryConnection:Disconnect()
			puff(lastPosition)
		end
	end)
end

local function onCoinRemoved(coin: Instance)
	if not coin:IsA("BasePart") or coin:GetAttribute("OwnerUserId") ~= localPlayer.UserId then
		return
	end
	local heroRoot = localRoot()
	if not heroRoot or (heroRoot.Position - coin.Position).Magnitude > 60 then
		return
	end
	-- Removed instances keep their last properties, so a local copy can finish the motion.
	local ghost = fxPart({
		Shape = Enum.PartType.Cylinder,
		Size = coin.Size,
		CFrame = coin.CFrame,
		Color = coin.Color,
	})
	tweenThenDestroy(ghost, 0.25, { CFrame = heroRoot.CFrame, Size = coin.Size * 0.4 })
end

function CombatFxController:Start()
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "ClientFx"
	fxFolder.Parent = workspace

	local enemies = workspace:WaitForChild("Enemies")
	enemies.ChildAdded:Connect(watchEnemy)
	for _, model in enemies:GetChildren() do
		task.spawn(watchEnemy, model)
	end

	workspace:WaitForChild("Coins").ChildRemoved:Connect(onCoinRemoved)
end

return CombatFxController
