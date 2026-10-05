--!strict
-- Drag-and-drop for the local player's ground items (mouse and touch).
--
-- The client never moves the real item. While dragging, it hides the real Part locally and moves
-- a local "ghost" copy. On release it sends an intent:
--   * over another own item that can merge -> RequestMerge(sourceId, targetId)
--   * over empty ground in the player's zone -> RequestMove(itemId, point)
--   * anything else (or an invalid merge)    -> snap back immediately, nothing sent
-- After sending, it waits briefly for the server's result to replicate (source removed / part
-- moved). If nothing arrives in time, the server rejected it, so the ghost snaps back.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Gear = require(Shared.Gear)
local Net = require(Shared.Net)
local Fx = require(script.Parent.Parent.Util.Fx)

local CONFIRM_TIMEOUT = 1 -- seconds to wait for the server before assuming rejection
local LIFT = 1.5 -- studs the ghost floats above the ground while dragging

type Drag = {
	part: BasePart,
	ghost: BasePart,
	origin: CFrame,
	input: InputObject, -- the mouse button / touch that started it
	hoverTarget: BasePart?,
	groundPoint: Vector3?,
	savedCameraType: Enum.CameraType?,
}

local localPlayer = Players.LocalPlayer :: Player

local DragController = {}

local itemsFolder: Instance
local highlight: Highlight
local drag: Drag? = nil

local function isOwnItem(instance: Instance?): boolean
	return instance ~= nil
		and instance:IsA("BasePart")
		and instance.Parent == itemsFolder
		and instance:GetAttribute("OwnerUserId") == localPlayer.UserId
end

local function itemOf(part: BasePart): Types.Item
	return {
		kind = part:GetAttribute("Kind") :: any,
		quality = part:GetAttribute("Quality") :: any,
		plus = part:GetAttribute("Plus") :: any,
	}
end

local function ownPad(): BasePart?
	local index = localPlayer:GetAttribute("ZoneIndex")
	local zones = workspace:FindFirstChild("Map") and (workspace :: any).Map:FindFirstChild("Zones")
	local zone = zones and zones:FindFirstChild(`Zone{index}`)
	return zone and zone:FindFirstChild("Pad") :: BasePart?
end

local function isOnOwnPad(point: Vector3): boolean
	local pad = ownPad()
	if not pad then
		return false
	end
	local localPoint = pad.CFrame:PointToObjectSpace(point)
	return math.abs(localPoint.X) <= pad.Size.X / 2 and math.abs(localPoint.Z) <= pad.Size.Z / 2
end

local function setHidden(part: BasePart, hidden: boolean)
	part.LocalTransparencyModifier = if hidden then 1 else 0
	local label = part:FindFirstChild("Label")
	if label and label:IsA("BillboardGui") then
		label.Enabled = not hidden
	end
end

-- Raycast from a screen position, ignoring the dragged part, FX and characters.
local function castAt(screenPosition: Vector3, ignore: { Instance }): RaycastResult?
	local camera = workspace.CurrentCamera
	local ray = camera:ScreenPointToRay(screenPosition.X, screenPosition.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { Fx.folder() }
	for _, name in { "Enemies", "Coins" } do
		local folder = workspace:FindFirstChild(name)
		if folder then
			table.insert(exclude, folder)
		end
	end
	if localPlayer.Character then
		table.insert(exclude, localPlayer.Character)
	end
	for _, instance in ignore do
		table.insert(exclude, instance)
	end
	params.FilterDescendantsInstances = exclude
	return workspace:Raycast(ray.Origin, ray.Direction * 500, params)
end

local function finish(d: Drag)
	if d.savedCameraType then
		workspace.CurrentCamera.CameraType = d.savedCameraType
	end
	d.ghost:Destroy()
	setHidden(d.part, false) -- pooled parts get reused, so always restore
end

local function snapBack(d: Drag)
	local tween = TweenService:Create(d.ghost, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { CFrame = d.origin })
	tween.Completed:Once(function()
		finish(d)
	end)
	tween:Play()
end

-- Waits for `signal` (the server's result replicating). Finishes on success, snaps back on timeout.
local function awaitConfirmation(d: Drag, signal: RBXScriptSignal, isConfirmed: () -> boolean)
	local settled = false
	local connection
	connection = signal:Connect(function()
		if not settled and isConfirmed() then
			settled = true
			connection:Disconnect()
			finish(d)
		end
	end)
	task.delay(CONFIRM_TIMEOUT, function()
		if not settled then
			settled = true
			connection:Disconnect()
			snapBack(d)
		end
	end)
end

local function beginDrag(input: InputObject)
	local hit = castAt(input.Position, {})
	local part = hit and hit.Instance
	if not part or not isOwnItem(part) then
		return
	end
	local real = part :: BasePart

	local ghost = real:Clone()
	ghost.CanQuery = false
	ghost.Transparency = 0.25
	ghost.Parent = Fx.folder()
	setHidden(real, true)

	local d: Drag = { part = real, ghost = ghost, origin = real.CFrame, input = input }
	if input.UserInputType == Enum.UserInputType.Touch then
		-- One-finger drags would otherwise also orbit the camera. Freeze it while dragging.
		d.savedCameraType = workspace.CurrentCamera.CameraType
		workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
	end
	drag = d
end

local function updateDrag(d: Drag, screenPosition: Vector3)
	local hit = castAt(screenPosition, { d.part })
	if not hit then
		return
	end
	if isOwnItem(hit.Instance) then
		local target = hit.Instance :: BasePart
		d.hoverTarget = target
		d.groundPoint = nil
		d.ghost.CFrame = CFrame.new(target.Position + Vector3.new(0, target.Size.Y / 2 + LIFT, 0)) * d.origin.Rotation
		highlight.Adornee = target
		highlight.FillColor = if Gear.canMerge(itemOf(d.part), itemOf(target))
			then Color3.fromRGB(90, 255, 120)
			else Color3.fromRGB(255, 80, 80)
	else
		d.hoverTarget = nil
		d.groundPoint = hit.Position
		d.ghost.CFrame = CFrame.new(hit.Position + Vector3.new(0, d.ghost.Size.Y / 2 + LIFT, 0)) * d.origin.Rotation
		highlight.Adornee = nil
	end
end

local function endDrag(d: Drag)
	drag = nil
	highlight.Adornee = nil
	local part = d.part
	if part.Parent ~= itemsFolder then
		finish(d) -- the item vanished mid-drag (e.g. zone cleared)
		return
	end

	local target = d.hoverTarget
	if target and target.Parent == itemsFolder then
		if not Gear.canMerge(itemOf(part), itemOf(target)) then
			snapBack(d)
			return
		end
		Net.event("RequestMerge"):FireServer(part:GetAttribute("ItemId"), target:GetAttribute("ItemId"))
		-- Success = the source item is removed from workspace.Items.
		awaitConfirmation(d, part.AncestryChanged, function()
			return part.Parent ~= itemsFolder
		end)
	elseif d.groundPoint and isOnOwnPad(d.groundPoint) then
		Net.event("RequestMove"):FireServer(part:GetAttribute("ItemId"), d.groundPoint)
		-- Success = the real part moves (the server re-places it at the drop point).
		awaitConfirmation(d, part:GetPropertyChangedSignal("CFrame"), function()
			return true
		end)
	else
		snapBack(d)
	end
end

function DragController:Start()
	itemsFolder = workspace:WaitForChild("Items")

	highlight = Instance.new("Highlight")
	highlight.FillTransparency = 0.5
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = Fx.folder()

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed or drag then
			return
		end
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			beginDrag(input)
		end
	end)

	UserInputService.InputChanged:Connect(function(input: InputObject)
		local d = drag
		if not d then
			return
		end
		local isMouseMove = input.UserInputType == Enum.UserInputType.MouseMovement
			and d.input.UserInputType == Enum.UserInputType.MouseButton1
		if isMouseMove or input == d.input then
			updateDrag(d, input.Position)
		end
	end)

	UserInputService.InputEnded:Connect(function(input: InputObject)
		local d = drag
		if not d then
			return
		end
		local isMouseRelease = input.UserInputType == Enum.UserInputType.MouseButton1
			and d.input.UserInputType == Enum.UserInputType.MouseButton1
		if isMouseRelease or input == d.input then
			endDrag(d)
		end
	end)
end

return DragController
