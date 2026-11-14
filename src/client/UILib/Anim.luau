--[[
	Anim  (StarterPlayerScripts.Client.UILib.Anim)
	Tween helpers that respect the "Reduce animations" setting: when reduced,
	properties are set instantly and looping/decorative motion is skipped.
]]

local TweenService = game:GetService("TweenService")

local Anim = {}
Anim.Reduced = false

local fadeTokens = setmetatable({}, { __mode = "k" })

function Anim.Tween(inst: Instance, props: { [string]: any }, time: number?, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	if Anim.Reduced or time == 0 then
		for key, value in pairs(props) do
			(inst :: any)[key] = value
		end
		return nil
	end
	local tween = TweenService:Create(inst, TweenInfo.new(time or 0.25, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out), props)
	tween:Play()
	return tween
end

function Anim.Await(tween)
	if tween and tween.PlaybackState ~= Enum.PlaybackState.Completed then
		tween.Completed:Wait()
	end
end

-- A UIScale named "AnimScale" used for pop/press effects without touching Size.
function Anim.Scale(inst: Instance): UIScale
	local scale = inst:FindFirstChild("AnimScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = "AnimScale"
		scale.Parent = inst
	end
	return scale :: UIScale
end

function Anim.Pop(inst: Instance, from: number?, time: number?)
	local scale = Anim.Scale(inst)
	if Anim.Reduced then
		scale.Scale = 1
		return nil
	end
	scale.Scale = from or 0.85
	return Anim.Tween(scale, { Scale = 1 }, time or 0.35, Enum.EasingStyle.Back)
end

-- Fades a CanvasGroup in/out and toggles Visible. Safe to call repeatedly.
function Anim.Fade(group: CanvasGroup, visible: boolean, time: number?)
	local token = (fadeTokens[group] or 0) + 1
	fadeTokens[group] = token
	if visible then
		group.Visible = true
		if not Anim.Reduced then
			group.GroupTransparency = 1
		end
		return Anim.Tween(group, { GroupTransparency = 0 }, time or 0.25)
	end
	local tween = Anim.Tween(group, { GroupTransparency = 1 }, time or 0.2)
	if tween then
		tween.Completed:Connect(function()
			if fadeTokens[group] == token then
				group.Visible = false
			end
		end)
	else
		group.Visible = false
	end
	return tween
end

-- Small wobble (rotation, so it also works inside layouts), e.g. for a locked choice.
function Anim.Shake(inst: GuiObject)
	if Anim.Reduced then
		return
	end
	task.spawn(function()
		for _, angle in ipairs({ 3, -3, 2, -2, 1, 0 }) do
			Anim.Tween(inst, { Rotation = angle }, 0.05, Enum.EasingStyle.Linear)
			task.wait(0.05)
		end
		inst.Rotation = 0
	end)
end

--[[
	Repeating back-and-forth tween for ambient motion (skipped when reduced).
	Returns a stop() function.
]]
function Anim.Loop(inst: Instance, props: { [string]: any }, time: number)
	if Anim.Reduced then
		return function() end
	end
	local tween = TweenService:Create(inst, TweenInfo.new(time, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), props)
	tween:Play()
	return function()
		tween:Cancel()
	end
end

return Anim
