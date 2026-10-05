--!strict
-- Client entry: same Init/Start lifecycle as the server, over Controllers.
local Controllers = script:WaitForChild("Controllers")

local loaded = {}
for _, module in Controllers:GetChildren() do
	if module:IsA("ModuleScript") then
		table.insert(loaded, (require :: any)(module))
	end
end
for _, controller in loaded do
	if controller.Init then
		controller:Init()
	end
end
for _, controller in loaded do
	if controller.Start then
		task.spawn(controller.Start, controller)
	end
end
