--[[
	Hospital  (ServerScriptService.Server.World.Districts.Hospital)
	St. Hope Hospital: reception and waiting area, the wards, the staff
	entrance, an ambulance bay, car park and helipad. Faces west, towards
	the Plaza.
]]

return function(B, ctx)
	local f = ctx.Folder
	B.Slab(f, "Forecourt", ctx.Pos(-38, 0).X, ctx.Pos(-38, 0).Z, 56, 128, 0.16, "#CFC6B8", Enum.Material.Concrete, 0.1)

	local hospital, hIn = B.Building(f, {
		Name = "St. Hope Hospital", CFrame = ctx.At(10, -6, 90), Width = 64, Depth = 40, Height = 24, Floors = 2,
		Wall = "#F8F9FA", Roof = "#0077B6", Floor = "#E0F2F1", FloorMaterial = Enum.Material.Marble,
		DoorWidth = 12, DoorHeight = 11, Sign = "🏥 ST. HOPE HOSPITAL", SignColor = "#0077B6",
	})
	-- Reception and waiting area
	B.Counter(hospital, hIn(0, 0, -6), 14, "#0077B6")
	B.Spot(hospital, "Hospital_Checkup", hIn(0, 0, -10))
	B.NPC(ctx.NPCs, "Doctor", hIn(-4, 0, -3.5))
	for _, x in ipairs({ -26, -22, -18, -14 }) do
		B.Chair(hospital, hIn(x, 0, -12, 180), "#90E0EF")
		B.Chair(hospital, hIn(x, 0, -6, 0), "#90E0EF")
	end
	B.Plant(hospital, hIn(-29, 0, -17))
	-- Wards along the back wall
	for _, x in ipairs({ -26, -18, -10, 10, 18, 26 }) do
		B.Bed(hospital, hIn(x, 0, 14, 0), "#CAF0F8")
	end
	B.Spot(hospital, "Hospital_Volunteer", hIn(14, 0, 6))
	B.NPC(ctx.NPCs, "Nurse", hIn(18, 0, 7))
	-- Staff entrance
	B.Board(hospital, hIn(26, 3, -18.8, 180), 7, 2.5, "STAFF ONLY", "#023E8A")
	B.Spot(hospital, "Hospital_Shift", hIn(26, 0, -14))

	-- Ambulance bay, car park and helipad
	B.Block(f, "AmbulanceCanopy", ctx.At(-40, 40, 0, 10), 18, 0.6, 14, "#0077B6", Enum.Material.SmoothPlastic)
	for _, p in ipairs({ { -48, 34 }, { -32, 34 }, { -48, 46 }, { -32, 46 } }) do
		B.Block(f, "CanopyPost", ctx.At(p[1], p[2]), 0.6, 10, 0.6, "#ADB5BD", Enum.Material.Metal)
	end
	local ambulance = B.Car(f, ctx.At(-40, 40, 180), "#F8F9FA", "Van")
	B.Part(ambulance, { Name = "Stripe", Size = Vector3.new(5.2, 0.6, 11.2), CFrame = ctx.At(-40, 40, 180, 2.4), Color = "#E63946", CanCollide = false })
	for i, z in ipairs({ -40, -28, -16 }) do
		B.Car(f, ctx.At(-56, z, 90), ({ "#457B9D", "#F4A261", "#6A994E" })[i], ({ "Hatch", "SUV", "Hatch" })[i])
	end
	B.Cylinder(f, "Helipad", ctx.At(44, 46), 22, 0.4, "#495057", Enum.Material.Concrete)
	B.Sign(f, "HelipadH", ctx.At(44, 46, 0, 0.62) * CFrame.Angles(math.rad(90), 0, 0), 9, 9, "H", "#495057")

	for _, p in ipairs({ { -62, -60 }, { -62, 62 }, { 62, -62 }, { 62, 26 }, { 16, 60 } }) do
		B.Tree(f, ctx.Pos(p[1], p[2], 0.1), 1)
	end
	for _, z in ipairs({ -50, -20, 10, 30, 56 }) do
		B.Lamp(f, ctx.Pos(-64, z, 0.16))
	end
	B.Bench(f, ctx.At(-26, -48, 90, 0.16))
	B.Bench(f, ctx.At(-26, 26, 90, 0.16))
	B.PostSign(f, "HospitalSign", ctx.At(-64, -8, 90), 12, "🏥 St. Hope Hospital", "#0077B6")
end
