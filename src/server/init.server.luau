--!strict
-- Server entry.
-- Lifecycle contract for every module in Services:
--   :Init()  - set up the service's OWN state, signals, remotes. Must not yield or call other services.
--   :Start() - runs after every Init; may call other services, connect players, and yield.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

require(ReplicatedStorage.Shared.Net).setup()

local Services = script:WaitForChild("Services")

local loaded = {}
for _, module in Services:GetChildren() do
	if module:IsA("ModuleScript") then
		table.insert(loaded, (require :: any)(module))
	end
end
for _, service in loaded do
	if service.Init then
		service:Init()
	end
end
for _, service in loaded do
	if service.Start then
		task.spawn(service.Start, service)
	end
end
