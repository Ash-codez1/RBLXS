--[[
	ControlsController  (StarterPlayerScripts.Client.Controllers.ControlsController)
	Until the 3D world arrives (Phase 8) the game is played through its menus,
	so the default character controls are switched off: no walking with WASD
	behind the UI, and no touch thumbstick / jump button covering the decision
	cards on phones and tablets.
	ControlsController.SetEnabled(true) turns them back on (world mode).
]]

local Players = game:GetService("Players")

local ControlsController = {}
ControlsController.Priority = 6

local controls = nil
local wantEnabled = false

function ControlsController.SetEnabled(enabled: boolean)
	wantEnabled = enabled
	if controls then
		if enabled then
			controls:Enable()
		else
			controls:Disable()
		end
	end
end

function ControlsController.Init() end

function ControlsController.Start()
	-- PlayerModule is Roblox's default control script inside PlayerScripts.
	local ok, module = pcall(function()
		local playerScripts = Players.LocalPlayer:WaitForChild("PlayerScripts", 15)
		local playerModule = playerScripts and playerScripts:WaitForChild("PlayerModule", 15)
		return playerModule and require(playerModule)
	end)
	if ok and module then
		controls = module:GetControls()
		ControlsController.SetEnabled(wantEnabled)
	end
end

return ControlsController
