--[[
	Main  (ServerScriptService.Server.Main)  — Script
	Server bootstrap. Steps:
	  1. Net.Init() creates every RemoteEvent/RemoteFunction.
	  2. Require every ModuleScript in Services, sorted by .Priority.
	  3. Call Init() on each in order. Init must not yield; it may connect to
	     other services' Signals (e.g. DataService.ProfileLoaded).
	  4. Call Start() on each in its own thread (may yield, may use other services).
	A service that errors is reported but does not stop the others from starting.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
Net.Init()

local services = {}
for _, module in ipairs(script.Parent.Services:GetChildren()) do
	if module:IsA("ModuleScript") then
		local ok, service = pcall(require, module)
		if ok and type(service) == "table" then
			service.Name = service.Name or module.Name
			table.insert(services, service)
		else
			warn("[Server] Failed to load service " .. module.Name .. ": " .. tostring(service))
		end
	end
end

table.sort(services, function(a, b)
	return (a.Priority or 100) < (b.Priority or 100)
end)

for _, service in ipairs(services) do
	if service.Init then
		local ok, err = pcall(service.Init)
		if not ok then
			warn("[Server] " .. service.Name .. ".Init failed: " .. tostring(err))
		end
	end
end

for _, service in ipairs(services) do
	if service.Start then
		task.spawn(function()
			local ok, err = pcall(service.Start)
			if not ok then
				warn("[Server] " .. service.Name .. ".Start failed: " .. tostring(err))
			end
		end)
	end
end

print(("[Server] CHOOSE YOUR LIFE started with %d services"):format(#services))
