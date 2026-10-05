--!strict
-- Left-side menu bar plus the panel windows it opens. One panel is open at a time.
-- Panels register themselves from their own Start (AddPanel). Menu buttons can also act as
-- drop targets for dragged items (IsOver / SetDropHover), e.g. the Storage button.
local Players = game:GetService("Players")

local Ui = require(script.Parent.Parent.Util.Ui)

type Panel = { button: TextButton, window: GuiObject, onOpen: (() -> ())? }

local localPlayer = Players.LocalPlayer :: Player

local MenuController = {}

local gui: ScreenGui? = nil
local bar: Frame
local panels: { [string]: Panel } = {}
local openName: string? = nil

local function ensureGui(): ScreenGui
	if gui then
		return gui
	end
	local created = Ui.new("ScreenGui", { Name = "Menu", ResetOnSpawn = false })
	bar = Ui.new("Frame", {
		Name = "Bar",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(84, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = created,
	}, { Ui.list(8) })
	created.Parent = localPlayer:WaitForChild("PlayerGui")
	gui = created
	return created
end

function MenuController:AddPanel(name: string, order: number, window: GuiObject, onOpen: (() -> ())?)
	local screen = ensureGui()
	local button = Ui.button(name, Ui.Theme.buttonAlt, function()
		MenuController:Toggle(name)
	end)
	button.Name = name
	button.LayoutOrder = order
	button.Size = UDim2.fromOffset(84, 44)
	Ui.new("UIStroke", { Name = "DropStroke", Color = Ui.Theme.good, Thickness = 3, Enabled = false, Parent = button })
	button.Parent = bar

	window.Visible = false
	window.Parent = screen
	panels[name] = { button = button, window = window, onOpen = onOpen }
end

function MenuController:Open(name: string)
	MenuController:Close()
	local panel = panels[name]
	if panel then
		openName = name
		panel.window.Visible = true
		if panel.onOpen then
			panel.onOpen()
		end
	end
end

function MenuController:Close()
	if openName and panels[openName] then
		panels[openName].window.Visible = false
	end
	openName = nil
end

function MenuController:Toggle(name: string)
	if openName == name then
		MenuController:Close()
	else
		MenuController:Open(name)
	end
end

function MenuController:IsOpen(name: string): boolean
	return openName == name
end

-- Whether a screen position (InputObject.Position) is over that panel's menu button.
function MenuController:IsOver(name: string, position: Vector3): boolean
	local panel = panels[name]
	if not panel then
		return false
	end
	local topLeft = panel.button.AbsolutePosition
	local size = panel.button.AbsoluteSize
	return position.X >= topLeft.X
		and position.X <= topLeft.X + size.X
		and position.Y >= topLeft.Y
		and position.Y <= topLeft.Y + size.Y
end

-- Outlines a menu button while a dragged item hovers over it.
function MenuController:SetDropHover(name: string, hovering: boolean)
	local panel = panels[name]
	local stroke = panel and panel.button:FindFirstChild("DropStroke")
	if stroke and stroke:IsA("UIStroke") then
		stroke.Enabled = hovering
	end
end

return MenuController
