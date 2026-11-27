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
	-- Ships with the Roblox client (the default character splash sound):
	Splash = "rbxasset://sounds/impact_water.mp3",
	-- Music (looped)
	MenuMusic = "",
	GameMusic = "",
	WorldMusic = "", -- while exploring Lifeville
	-- Ambience (looped, explore mode): one per district type, plus night
	AmbientPlaza = "",
	AmbientSchool = "",
	AmbientPark = "",
	AmbientResidential = "",
	AmbientHospital = "",
	AmbientCity = "",
	AmbientHarbour = "",
	AmbientNight = "",
	BuskerMusic = "", -- plays near Jay the busker in the Plaza
}
