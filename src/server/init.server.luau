--!strict
-- Server entry: requires every ModuleScript in Services, then calls :Init() on all, then :Start() on all.
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
