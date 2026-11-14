--[[
	SoundIds  (ReplicatedStorage.Shared.Data.SoundIds)
	Audio asset ids used by AudioController. Fill these in with sounds from the
	Creator Store (Toolbox → Audio) that you have permission to use, e.g.
	Click = "rbxassetid://1234567890". Empty entries are skipped silently, so the
	game runs fine before audio is added.
]]

return {
	-- UI
	Click = "",
	Select = "",
	Confirm = "",
	Locked = "",
	Positive = "",
	Negative = "",
	AgeUp = "",
	StageComplete = "",
	Notify = "",
	-- Music (looped)
	MenuMusic = "",
	GameMusic = "",
}
