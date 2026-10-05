--!strict
-- Cosmetic feedback for the local player's ground items, derived from replicated attributes:
--   * item appears  -> small pop in its color
--   * Plus goes up  -> bigger pop + "+N!" (a merge landed)
-- Items are pooled server-side, so the same Part can leave and re-enter workspace.Items;
-- each appearance gets fresh connections that are dropped when it leaves.
local Players = game:GetService("Players")

local Fx = require(script.Parent.Parent.Util.Fx)

local localPlayer = Players.LocalPlayer :: Player

local LootFxController = {}

local function watchItem(part: Instance)
	if not part:IsA("BasePart") or part:GetAttribute("OwnerUserId") ~= localPlayer.UserId then
		return
	end
	Fx.pop(part.Position, part.Color, 0.5, 3, 0.3)

	local lastPlus = part:GetAttribute("Plus") :: number? or 0
	local plusConnection = part:GetAttributeChangedSignal("Plus"):Connect(function()
		local plus = part:GetAttribute("Plus") :: number?
		if plus and plus > lastPlus then
			Fx.pop(part.Position, part.Color, 1, 7, 0.4)
			Fx.floatingText(part.Position + Vector3.new(0, 1.5, 0), `+{plus}!`, part.Color)
		end
		lastPlus = plus or lastPlus
	end)

	local ancestryConnection
	ancestryConnection = part.AncestryChanged:Connect(function()
		if not part:IsDescendantOf(workspace) then
			plusConnection:Disconnect()
			ancestryConnection:Disconnect()
		end
	end)
end

function LootFxController:Start()
	local items = workspace:WaitForChild("Items")
	items.ChildAdded:Connect(watchItem)
	for _, part in items:GetChildren() do
		watchItem(part)
	end
end

return LootFxController
