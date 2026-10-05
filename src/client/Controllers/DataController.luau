--!strict
-- Read-only client mirror of the local player's save. The server is the only writer:
-- it sends a full snapshot once, then batched top-level key changes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)

local DataController = {
	-- (key, value) for every top-level key that changed; fired for all keys on snapshot.
	Changed = Signal.new() :: Signal.Signal<string, any>,
}

local data: Types.PlayerData? = nil

function DataController:Get(): Types.PlayerData?
	return data
end

-- Calls handler now (if loaded) and whenever data[key] changes.
function DataController:Observe(key: string, handler: (value: any) -> ()): Signal.Connection
	if data then
		handler((data :: any)[key])
	end
	return DataController.Changed:Connect(function(changedKey, value)
		if changedKey == key then
			handler(value)
		end
	end)
end

function DataController:Init()
	-- RemoteEvents queue until a listener connects, so a snapshot sent before this point isn't lost.
	Net.event("DataSnapshot").OnClientEvent:Connect(function(snapshot: Types.PlayerData)
		data = snapshot
		for key, value in snapshot :: any do
			DataController.Changed:Fire(key, value)
		end
	end)

	Net.event("DataChanged").OnClientEvent:Connect(function(changes: { [string]: any })
		local current = data
		if not current then
			return
		end
		for key, value in changes do
			(current :: any)[key] = value
			DataController.Changed:Fire(key, value)
		end
	end)
end

return DataController
