--[[
	Main  (StarterPlayerScripts.Client.Main)  — LocalScript
	Client bootstrap: same Init/Start lifecycle as the server, using the
	ModuleScripts in Client.Controllers (and Client.UI from Phase 2 on).
]]

local controllers = {}

local function collect(folder: Instance?)
	if not folder then
		return
	end
	for _, module in ipairs(folder:GetChildren()) do
		if module:IsA("ModuleScript") then
			local ok, controller = pcall(require, module)
			if ok and type(controller) == "table" then
				controller.Name = controller.Name or module.Name
				table.insert(controllers, controller)
			else
				warn("[Client] Failed to load " .. module.Name .. ": " .. tostring(controller))
			end
		end
	end
end

collect(script.Parent:WaitForChild("Controllers"))
collect(script.Parent:FindFirstChild("UI"))

table.sort(controllers, function(a, b)
	return (a.Priority or 100) < (b.Priority or 100)
end)

for _, controller in ipairs(controllers) do
	if controller.Init then
		local ok, err = pcall(controller.Init)
		if not ok then
			warn("[Client] " .. controller.Name .. ".Init failed: " .. tostring(err))
		end
	end
end

for _, controller in ipairs(controllers) do
	if controller.Start then
		task.spawn(function()
			local ok, err = pcall(controller.Start)
			if not ok then
				warn("[Client] " .. controller.Name .. ".Start failed: " .. tostring(err))
			end
		end)
	end
end
