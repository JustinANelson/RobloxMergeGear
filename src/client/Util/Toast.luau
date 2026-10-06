--!strict
-- Short messages under the HUD ("Merged 9× → Sword +6"). Newest at the bottom, max 4, auto-fade.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Ui = require(script.Parent.Ui)

local MAX_VISIBLE = 4
local SHOW_SECONDS = 2.5

export type Tone = "info" | "good" | "bad"

local Toast = {}

local container: Frame? = nil
local order = 0

local function ensureContainer(): Frame
	if container then
		return container
	end
	local gui = Ui.new("ScreenGui", { Name = "Toasts", ResetOnSpawn = false, DisplayOrder = 10 })
	local frame = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 64),
		Size = UDim2.fromOffset(420, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = gui,
	}, { Ui.list(6) })
	local layout = frame:FindFirstChildOfClass("UIListLayout") :: UIListLayout
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	container = frame
	return frame
end

function Toast.show(message: string, tone: Tone?)
	local parent = ensureContainer()
	local color = if tone == "good" then Ui.Theme.good elseif tone == "bad" then Ui.Theme.bad else Ui.Theme.accent

	local existing = {}
	for _, child in parent:GetChildren() do
		if child:IsA("Frame") then
			table.insert(existing, child)
		end
	end
	table.sort(existing, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i = 1, #existing - MAX_VISIBLE + 1 do
		existing[i]:Destroy()
	end

	order += 1
	local frame = Ui.new("Frame", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(0, 34),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Ui.Theme.window,
		BackgroundTransparency = 0.1,
		Parent = parent,
	}, {
		Ui.corner(8),
		Ui.new("UIStroke", { Color = color, Thickness = 2 }) :: any,
		Ui.new("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }),
	})
	local label = Ui.text({
		Text = message,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = Ui.Theme.text,
		Size = UDim2.fromOffset(0, 34),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = frame,
	})

	task.delay(SHOW_SECONDS, function()
		if frame.Parent then
			local fade = TweenInfo.new(0.4)
			TweenService:Create(frame, fade, { BackgroundTransparency = 1 }):Play()
			TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
			task.delay(0.4, function()
				frame:Destroy()
			end)
		end
	end)
end

return Toast
