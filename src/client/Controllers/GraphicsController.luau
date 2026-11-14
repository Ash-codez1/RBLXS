--[[
	GraphicsController  (StarterPlayerScripts.Client.Controllers.GraphicsController)
	Applies the Graphics setting (Auto / Low / High) on this client only.
	Roblox doesn't let games change the engine's quality level, so this
	controls what the game itself adds: shadows, post-processing effects
	(Bloom, SunRays, DepthOfField, Blur) and decorative UI motion.
	World systems (Phase 8) read GraphicsController.IsLow() before spawning
	optional decoration such as extra NPCs or particles.

	Auto = Low on touch-only devices (phones/tablets), High elsewhere.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Signal = require(ReplicatedStorage:WaitForChild("Shared").Util.Signal)

local GraphicsController = {}
GraphicsController.Priority = 3
GraphicsController.Changed = Signal.new() -- (resolvedMode: "Low" | "High")

local resolved = "High"
local originalShadows = nil

function GraphicsController.Resolve(mode: string): string
	if mode == "Low" or mode == "High" then
		return mode
	end
	local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled and not UserInputService.GamepadEnabled
	return if touchOnly then "Low" else "High"
end

function GraphicsController.Apply(mode: string)
	resolved = GraphicsController.Resolve(mode)
	local low = resolved == "Low"
	if originalShadows == nil then
		originalShadows = Lighting.GlobalShadows
	end
	Lighting.GlobalShadows = if low then false else originalShadows
	for _, effect in ipairs(Lighting:GetChildren()) do
		if effect:IsA("PostEffect") and not effect:IsA("ColorCorrectionEffect") then
			effect.Enabled = not low
		end
	end
	local UIController = require(script.Parent.UIController)
	UIController.SetDecorations(not low)
	GraphicsController.Changed:Fire(resolved)
end

function GraphicsController.IsLow(): boolean
	return resolved == "Low"
end

function GraphicsController.Init() end
function GraphicsController.Start() end

return GraphicsController
