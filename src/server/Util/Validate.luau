--!strict
-- Checks for untrusted remote arguments. Every Request* handler validates with these
-- (after RateLimit) before touching any state.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GearConfig = require(ReplicatedStorage.Shared.Config.Gear)

local Validate = {}

-- Positive integer (rejects NaN, infinities, fractions).
function Validate.isId(value: unknown): boolean
	return type(value) == "number" and value == value and value % 1 == 0 and value > 0 and value < math.huge
end

function Validate.isFiniteVector3(value: unknown): boolean
	if typeof(value) ~= "Vector3" then
		return false
	end
	local v = value :: Vector3
	for _, n in { v.X, v.Y, v.Z } do
		if n ~= n or math.abs(n) == math.huge then
			return false
		end
	end
	return true
end

-- The player's character exists and is within `maxDistance` studs of `point`.
function Validate.withinReach(player: Player, point: Vector3, maxDistance: number): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root ~= nil and (root.Position - point).Magnitude <= maxDistance
end

function Validate.isSlot(value: unknown): boolean
	return type(value) == "string" and table.find(GearConfig.Slots, value :: any) ~= nil
end

return Validate
