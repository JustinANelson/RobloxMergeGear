--!strict
-- Shows server Notify messages as toasts.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared").Net)
local Toast = require(script.Parent.Parent.Util.Toast)

local NotifyController = {}

function NotifyController:Init()
	Net.event("Notify").OnClientEvent:Connect(function(message: string, tone: Toast.Tone?)
		Toast.show(message, tone)
	end)
end

return NotifyController
