--!strict
-- Purely cosmetic combat feedback, derived from replicated state (no remotes):
--   * enemy Humanoid health drops -> damage number + slash from the hero to the enemy
--   * enemy removed               -> death puff
--   * coin removed near the hero  -> coin flies into the hero
-- Only the local player's own enemies/coins get effects.
local Players = game:GetService("Players")

local Fx = require(script.Parent.Parent.Util.Fx)

local localPlayer = Players.LocalPlayer :: Player

local CombatFxController = {}

local function localRoot(): BasePart?
	local character = localPlayer.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function slash(from: Vector3, to: Vector3)
	local length = (to - from).Magnitude
	local part = Fx.part({
		Size = Vector3.new(0.3, 0.3, length),
		CFrame = CFrame.lookAt((from + to) / 2, to),
		Color = Color3.fromRGB(255, 255, 255),
		Transparency = 0.2,
	})
	Fx.tweenThenDestroy(part, 0.15, { Transparency = 1, Size = Vector3.new(0.05, 0.05, length) })
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
			Fx.floatingText(
				root.Position + Vector3.new(0, 2.5, 0),
				tostring(math.floor(delta + 0.5)),
				Color3.fromRGB(255, 235, 120)
			)
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
			Fx.pop(lastPosition, Color3.fromRGB(255, 120, 90), 2, 6, 0.35)
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
	local ghost = Fx.part({
		Shape = Enum.PartType.Cylinder,
		Size = coin.Size,
		CFrame = coin.CFrame,
		Color = coin.Color,
	})
	Fx.tweenThenDestroy(ghost, 0.25, { CFrame = heroRoot.CFrame, Size = coin.Size * 0.4 })
end

function CombatFxController:Start()
	local enemies = workspace:WaitForChild("Enemies")
	enemies.ChildAdded:Connect(watchEnemy)
	for _, model in enemies:GetChildren() do
		task.spawn(watchEnemy, model)
	end

	workspace:WaitForChild("Coins").ChildRemoved:Connect(onCoinRemoved)
end

return CombatFxController
