--!strict
-- Client-only visual helpers shared by the FX controllers. Everything goes in workspace.ClientFx
-- and is never seen by the server or other players.
local TweenService = game:GetService("TweenService")

local Fx = {}

local folder: Folder? = nil

function Fx.folder(): Folder
	if not folder then
		local created = Instance.new("Folder")
		created.Name = "ClientFx"
		created.Parent = workspace
		folder = created
	end
	return folder :: Folder
end

-- Anchored, non-colliding, non-queryable neon part in the FX folder.
function Fx.part(props: { [string]: any }): Part
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
	part.Parent = Fx.folder()
	return part
end

function Fx.tweenThenDestroy(instance: Instance, seconds: number, goal: { [string]: any })
	local tween =
		TweenService:Create(instance, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	tween.Completed:Once(function()
		instance:Destroy()
	end)
	tween:Play()
end

-- Expanding, fading ball.
function Fx.pop(position: Vector3, color: Color3, fromSize: number, toSize: number, seconds: number)
	local ball = Fx.part({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * fromSize,
		CFrame = CFrame.new(position),
		Color = color,
		Transparency = 0.3,
	})
	Fx.tweenThenDestroy(ball, seconds, { Size = Vector3.one * toSize, Transparency = 1 })
end

-- Text that rises and fades, e.g. damage numbers.
function Fx.floatingText(position: Vector3, text: string, color: Color3)
	local anchor = Fx.part({ Transparency = 1, Size = Vector3.one * 0.2, CFrame = CFrame.new(position) })
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(80, 32)
	gui.StudsOffset = Vector3.new(math.random() * 2 - 1, 2, 0)
	gui.AlwaysOnTop = true
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.3
	label.Text = text
	label.Parent = gui
	gui.Parent = anchor

	TweenService:Create(gui, TweenInfo.new(0.6), { StudsOffset = gui.StudsOffset + Vector3.new(0, 2.5, 0) }):Play()
	Fx.tweenThenDestroy(label, 0.6, { TextTransparency = 1, TextStrokeTransparency = 1 })
	task.delay(0.65, function()
		anchor:Destroy()
	end)
end

return Fx
