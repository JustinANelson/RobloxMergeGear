--!strict
-- Tiny UI construction helpers + the shared theme, so panels stay short and consistent.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Format"))

local Ui = {}

Ui.Theme = table.freeze({
	window = Color3.fromRGB(28, 28, 36),
	row = Color3.fromRGB(42, 42, 54),
	stroke = Color3.fromRGB(80, 80, 100),
	text = Color3.fromRGB(240, 240, 245),
	muted = Color3.fromRGB(160, 160, 178),
	accent = Color3.fromRGB(120, 200, 255),
	good = Color3.fromRGB(90, 220, 120),
	bad = Color3.fromRGB(230, 90, 90),
	button = Color3.fromRGB(60, 110, 200),
	buttonAlt = Color3.fromRGB(70, 70, 88),
})

-- Instance.new + props + children. Parent is applied last.
function Ui.new(className: string, props: { [string]: any }?, children: { any }?): any
	local instance = Instance.new(className)
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(instance :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function Ui.corner(radius: number): UICorner
	return Ui.new("UICorner", { CornerRadius = UDim.new(0, radius) })
end

function Ui.padding(pixels: number): UIPadding
	local p = UDim.new(0, pixels)
	return Ui.new("UIPadding", { PaddingTop = p, PaddingBottom = p, PaddingLeft = p, PaddingRight = p })
end

function Ui.list(padding: number, horizontal: boolean?): UIListLayout
	return Ui.new("UIListLayout", {
		Padding = UDim.new(0, padding),
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		VerticalAlignment = if horizontal then Enum.VerticalAlignment.Center else Enum.VerticalAlignment.Top,
	})
end

function Ui.text(props: { [string]: any }): TextLabel
	local label = Ui.new("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextColor3 = Ui.Theme.text,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	for key, value in props do
		(label :: any)[key] = value
	end
	return label
end

function Ui.button(text: string, color: Color3, onActivated: () -> ()): TextButton
	local button = Ui.new("TextButton", {
		Text = text,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = Ui.Theme.text,
		BackgroundColor3 = color,
		AutoButtonColor = true,
		Size = UDim2.fromOffset(84, 30),
	}, { Ui.corner(6) })
	button.Activated:Connect(onActivated)
	return button
end

-- Centered window with a title bar and close button. Returns (window, content frame).
function Ui.window(title: string, onClose: () -> ()): (Frame, Frame)
	local window = Ui.new("Frame", {
		Name = title,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.42, 0.68),
		BackgroundColor3 = Ui.Theme.window,
		Visible = false,
	}, {
		Ui.corner(12) :: any, -- mixed child types: widen so the list isn't typed as {UICorner}
		Ui.new("UIStroke", { Color = Ui.Theme.stroke, Thickness = 2 }),
		Ui.new("UISizeConstraint", { MinSize = Vector2.new(300, 320), MaxSize = Vector2.new(480, 580) }),
		Ui.text({
			Name = "Title",
			Text = title,
			Font = Enum.Font.GothamBold,
			TextSize = 20,
			Position = UDim2.fromOffset(16, 8),
			Size = UDim2.new(1, -64, 0, 32),
		}),
	})
	local close = Ui.button("X", Ui.Theme.buttonAlt, onClose)
	close.Size = UDim2.fromOffset(32, 32)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -8, 0, 8)
	close.Parent = window

	local content = Ui.new("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 48),
		Size = UDim2.new(1, 0, 1, -48),
		Parent = window,
	}, { Ui.padding(12) })
	return window, content
end

-- Formats a stat for display: one decimal below 100, abbreviated (1.2K) from 1000.
function Ui.stat(n: number): string
	if n >= 1000 then
		return Format.abbreviate(n)
	elseif n >= 100 then
		return tostring(math.floor(n + 0.5))
	end
	return tostring(math.floor(n * 10 + 0.5) / 10)
end

return Ui
