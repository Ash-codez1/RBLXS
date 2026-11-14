--[[
	Client UI end-to-end tests: boots the real client (Main.client.luau and every
	controller) against a real server harness through bridged remotes, then
	clicks through the menus and plays a whole childhood.
	Called from tests/run.luau.
]]

local task = require("@lune/task")

return function(H)
	local test, eq, ok, section = H.test, H.eq, H.ok, H.section
	local V2 = H.Datatypes.Vector2.new
	local MockDataStore = H.new({ Quiet = true }).require("ServerScriptService.Server.Lib.MockDataStore")

	local function bootPair(userId, options)
		options = options or {}
		local store = MockDataStore.new()
		local server = H.new({
			Quiet = true,
			JobId = "ui-" .. userId,
			DataStoreService = {
				GetDataStore = function()
					return store
				end,
				GetRequestBudgetForRequestType = function()
					return 100
				end,
			},
		})
		server.run("ServerScriptService.Server.Main")
		local serverPlayer = server.addPlayer(userId, "UiTester")
		task.wait(0.05)
		local client = H.new({ Quiet = true, IsServer = false, Viewport = options.Viewport, Gamepad = options.Gamepad, Touch = options.Touch })
		client.makeLocalPlayer(userId, "UiTester")
		H.bridge(server, client, serverPlayer)
		client.run("StarterPlayerScripts.Client.Main")
		task.wait(1.3) -- loading screen hands over to the menu
		local api = {
			server = server,
			client = client,
			player = serverPlayer,
			UI = client.require("StarterPlayerScripts.Client.Controllers.UIController"),
			Decision = client.require("StarterPlayerScripts.Client.Controllers.DecisionController"),
			Anim = client.require("StarterPlayerScripts.Client.UILib.Anim"),
			DataService = server.require("ServerScriptService.Server.Services.DataService"),
			gui = client.game.Players.LocalPlayer.PlayerGui,
		}
		function api.root()
			return api.gui.CYL_Main.Root
		end
		function api.screen(name)
			return api.root():FindFirstChild(name)
		end
		function api.button(root, text)
			return H.find(root, function(d)
				local label = d:IsA("GuiButton") and d:FindFirstChild("Label")
				return label and label.Text and label.Text:find(text, 1, true) ~= nil
			end)
		end
		function api.label(root, text)
			return H.find(root, function(d)
				return d.ClassName == "TextLabel" and type(d.Text) == "string" and d.Text:find(text, 1, true) ~= nil
			end)
		end
		function api.click(button, wait)
			assert(button, "click: button is nil")
			button.Activated:Fire()
			task.wait(wait or 0.1)
		end
		function api.data()
			return api.DataService.Get(serverPlayer)
		end
		function api.noErrors()
			local all = {}
			for _, e in ipairs(client.errors) do
				table.insert(all, "client: " .. e)
			end
			for _, e in ipairs(server.errors) do
				table.insert(all, "server: " .. e)
			end
			for _, e in ipairs(H.eventErrors) do
				table.insert(all, "event: " .. e)
			end
			for _, w in ipairs(client.warnings) do
				if w:find("failed") or w:find("Failed") or w:find("error") then
					table.insert(all, "warn: " .. w)
				end
			end
			return #all == 0, table.concat(all, "\n")
		end
		-- Picks the first unlocked card of the current scenario and confirms it.
		function api.decide()
			local game = api.screen("Game")
			local card = H.find(game, function(d)
				return d.ClassName == "TextButton" and d.Parent and d.Parent.Name == "Choices" and d.BackgroundTransparency < 0.4
			end)
			assert(card, "no unlocked card found (mode " .. api.Decision.GetMode() .. ")")
			api.click(card, 0.05) -- select
			api.click(card, 0.5) -- tap again to confirm
			return card.Name
		end
		function api.continue()
			local game = api.screen("Game")
			api.click(api.button(game, "Continue"), 0.1)
			local deadline = os.clock() + 4
			while api.Decision.GetMode() == "Transition" and os.clock() < deadline do
				task.wait(0.05)
			end
			task.wait(0.3)
		end
		return api
	end

	section("Client UI: desktop (1280×720) end-to-end")
	local app = bootPair(700)

	test("Loading screen hands over to the main menu", function()
		eq(app.UI.Current(), "Menu")
		eq(app.gui:FindFirstChild("CYL_Loading"), nil, "loading gui removed")
		ok(app.screen("Menu").Visible, "menu visible")
		ok(not app.UI.IsNarrow())
	end)

	test("Menu shows only working buttons; Continue is disabled with no lives", function()
		local menu = app.screen("Menu")
		ok(app.button(menu, "Play"), "Play")
		ok(app.button(menu, "New Life"), "New Life")
		ok(app.button(menu, "Settings"), "Settings")
		ok(app.button(menu, "Credits"), "Credits")
		eq(app.button(menu, "Shop"), nil, "no Shop until Phase 7")
		eq(app.button(menu, "Achievements"), nil, "no Achievements until Phase 9")
		eq(app.button(menu, "Continue Life"):GetAttribute("Disabled"), true)
		ok(app.label(menu, "Your story hasn't started yet."), "welcome card")
	end)

	test("Play with no life opens name entry; starting a life opens the game", function()
		app.click(app.button(app.screen("Menu"), "Play"), 0.3)
		eq(app.UI.Current(), "NameEntry")
		local box = H.find(app.screen("NameEntry"), function(d)
			return d.ClassName == "TextBox"
		end)
		ok(box and #box.Text > 0, "random name prefilled")
		box.Text = "Zed Tester"
		app.click(app.button(app.screen("NameEntry"), "Start Life"), 0.6)
		eq(app.UI.Current(), "Game")
		eq(app.data().Slots.Slot1.Name, "Zed Tester")
	end)

	test("Game screen shows the HUD and the first scenario's cards", function()
		local game = app.screen("Game")
		eq(app.Decision.GetMode(), "Scenario")
		ok(app.label(game, "First Day of School"), "scenario title")
		ok(app.label(game, "AGE 5"), "age line")
		eq(game.HUD:FindFirstChild("Name", true).Text, "Zed Tester")
		ok(game.HUD:FindFirstChild("Sub", true).Text:find("Age 5"), "HUD age")
		local cards = game:FindFirstChild("Choices", true)
		local count = 0
		for _, c in ipairs(cards:GetChildren()) do
			if c.ClassName == "TextButton" then
				count += 1
			end
		end
		eq(count, 4, "four choice cards")
		ok(app.label(game, "▲"), "consequence preview arrows")
	end)

	test("Select shows the confirm bar; confirming shows the outcome", function()
		local game = app.screen("Game")
		local card = game:FindFirstChild("Listen", true)
		app.click(card, 0.1)
		local bar = game:FindFirstChild("ConfirmBar", true)
		ok(bar.Visible, "confirm bar visible")
		ok(bar.Choice.Text:find("Sit at the front"), "confirm text")
		app.click(app.button(bar, "Confirm"), 0.8)
		eq(app.Decision.GetMode(), "Outcome")
		ok(app.label(game, "Zed Tester sat right at the front"), "story")
		ok(app.label(game, "Intelligence +"), "stat change chip")
		ok(app.label(game, "New trait: 📚 Studious"), "trait chip")
		eq(app.data().Slots.Slot1.Age, 6)
	end)

	test("Continue plays the age-up and loads the next scenario", function()
		app.continue()
		eq(app.Decision.GetMode(), "Scenario")
		ok(app.screen("Game").HUD:FindFirstChild("Sub", true).Text:find("Age 6"), "HUD updated to age 6")
	end)

	test("Stats panel opens with all 8 stats and closes", function()
		app.click(app.screen("Game").HUD:FindFirstChild("Stats", true), 0.2)
		local modal = app.gui.CYL_Overlay.Root:FindFirstChild("StatsModal")
		ok(modal, "stats modal open")
		local grid = modal:FindFirstChild("Stats", true)
		local cells = 0
		for _, c in ipairs(grid:GetChildren()) do
			if c.ClassName == "Frame" then
				cells += 1
			end
		end
		eq(cells, 8)
		ok(app.label(modal, "Studious"), "trait listed")
		app.click(modal:FindFirstChild("Close", true), 0.4)
		eq(app.gui.CYL_Overlay.Root:FindFirstChild("StatsModal"), nil, "closed")
	end)

	test("Play the rest of childhood through the UI to the stage transition", function()
		app.Anim.Reduced = true
		for _ = 1, 5 do
			app.decide()
			eq(app.Decision.GetMode(), "Outcome")
			app.continue()
		end
		eq(app.Decision.GetMode(), "Message")
		ok(app.label(app.screen("Game"), "To be continued"), "end-of-content message")
		local life = app.data().Slots.Slot1
		eq(life.Stage, 2)
		eq(life.Age, 13)
		eq(#life.Decisions, 6)
	end)

	test("HUD menu button returns to the menu, which now shows the life", function()
		app.click(app.screen("Game").HUD:FindFirstChild("Menu", true), 0.3)
		eq(app.UI.Current(), "Menu")
		local menu = app.screen("Menu")
		ok(app.button(menu, "Play as Zed Tester"), "personalised play button")
		ok(app.label(menu, "CURRENT LIFE"), "life card")
		ok(app.button(menu, "Continue Life"):GetAttribute("Disabled") ~= true, "Continue enabled")
	end)

	test("Settings apply instantly and save to the server", function()
		app.click(app.button(app.screen("Menu"), "Settings"), 0.3)
		eq(app.UI.Current(), "Settings")
		local settings = app.screen("Settings")
		-- Toggle notifications off.
		app.click(settings:FindFirstChild("Show notifications", true).Switch, 0.1)
		-- Graphics: Auto -> Low.
		local graphicsRow = settings:FindFirstChild("Graphics", true)
		app.click(app.button(graphicsRow, "›"), 0.1)
		local Graphics = app.client.require("StarterPlayerScripts.Client.Controllers.GraphicsController")
		ok(Graphics.IsLow(), "graphics low")
		eq(app.client.game.Lighting.GlobalShadows, false, "shadows off on Low")
		eq(app.client.game.Lighting.BloomEffect.Enabled, false, "bloom off on Low")
		-- Music volume +5%.
		app.click(app.button(settings:FindFirstChild("Music volume", true), "+"), 0.1)
		eq(app.client.game.SoundService.CYL_Music.Volume, 0.55, "music group volume")
		-- Privacy: My life stats -> Nobody (Friends -> Nobody).
		app.click(app.button(settings:FindFirstChild("My life stats", true), "›"), 0.1)
		task.wait(1.2) -- debounce + save
		local data = app.data()
		eq(data.Settings.Notifications, false)
		eq(data.Settings.Graphics, "Low")
		eq(data.Settings.MusicVolume, 0.55)
		eq(data.Privacy.ShareStats, "Nobody")
		ok(app.label(settings, "Saved"), "saved indicator")
	end)

	test("UI scale setting rescales the layout", function()
		local before = app.UI.GetVirtualSize().X
		app.click(app.button(app.screen("Settings"):FindFirstChild("UI scale", true), "+"), 0.7)
		local after = app.UI.GetVirtualSize().X
		ok(after < before, ("virtual width shrinks as scale grows (%d -> %d)"):format(before, after))
		eq(app.data().Settings.UIScale ~= nil, true)
	end)

	test("Back returns to the menu; Credits opens and closes", function()
		app.UI.Back()
		task.wait(0.2)
		eq(app.UI.Current(), "Menu")
		app.click(app.button(app.screen("Menu"), "Credits"), 0.3)
		eq(app.UI.Current(), "Credits")
		ok(app.label(app.screen("Credits"), "Created by"), "credits content")
		app.click(app.button(app.screen("Credits"), "Back"), 0.3)
		eq(app.UI.Current(), "Menu")
	end)

	test("Slot screen lists lives; delete asks for confirmation", function()
		app.click(app.button(app.screen("Menu"), "Continue Life"), 0.3)
		eq(app.UI.Current(), "SlotSelect")
		local slots = app.screen("SlotSelect")
		ok(app.label(slots, "Zed Tester"), "life listed")
		ok(app.label(slots, "Empty Slot"), "empty slots listed")
		app.click(slots:FindFirstChild("Delete", true), 0.3)
		local modal = app.gui.CYL_Overlay.Root:FindFirstChild("ConfirmModal")
		ok(modal, "confirm modal")
		app.click(app.button(modal, "Delete"), 0.6)
		eq(app.data().Slots.Slot1, false, "deleted on server")
		ok(not app.label(app.screen("SlotSelect"), "Zed Tester"), "slot list refreshed")
	end)

	test("New Life from a slot and replacing requires confirmation", function()
		app.click(app.button(app.screen("SlotSelect"), "Back"), 0.3)
		app.click(app.button(app.screen("Menu"), "New Life"), 0.3)
		app.click(app.button(app.screen("SlotSelect"), "Start New Life"), 0.3)
		eq(app.UI.Current(), "NameEntry")
		local box = H.find(app.screen("NameEntry"), function(d)
			return d.ClassName == "TextBox"
		end)
		box.Text = "X"
		app.click(app.button(app.screen("NameEntry"), "Start Life"), 0.4)
		eq(app.UI.Current(), "NameEntry", "stays on bad name")
		ok(app.label(app.screen("NameEntry"), "2–20 characters"), "error message shown")
	end)

	test("No errors or failure warnings on client or server", function()
		local clean, report = app.noErrors()
		ok(clean, report)
	end)
	app.server.close()

	section("Client UI: phone portrait (390×844)")
	local phone = bootPair(701, { Viewport = V2(390, 844), Touch = true })
	test("Portrait layout is narrow and the full loop works", function()
		ok(phone.UI.IsNarrow(), "narrow")
		local graphics = phone.client.require("StarterPlayerScripts.Client.Controllers.GraphicsController")
		ok(graphics.IsLow(), "Auto graphics resolves to Low on touch-only devices")
		phone.click(phone.button(phone.screen("Menu"), "Play"), 0.3)
		phone.click(phone.button(phone.screen("NameEntry"), "Start Life"), 0.6)
		eq(phone.UI.Current(), "Game")
		ok(phone.screen("Game").HUD:FindFirstChild("Bottom"), "two-row HUD")
		phone.decide()
		eq(phone.Decision.GetMode(), "Outcome")
		phone.continue()
		eq(phone.Decision.GetMode(), "Scenario")
		phone.click(phone.screen("Game").HUD:FindFirstChild("Stats", true), 0.3)
		ok(phone.gui.CYL_Overlay.Root:FindFirstChild("StatsModal"), "stats modal")
		local clean, report = phone.noErrors()
		ok(clean, report)
	end)
	phone.server.close()

	section("Client UI: phone landscape (844×390) + live resize")
	local wide = bootPair(702, { Viewport = V2(844, 390), Touch = true })
	test("Compact landscape works and survives rotating mid-decision", function()
		wide.click(wide.button(wide.screen("Menu"), "Play"), 0.3)
		wide.click(wide.button(wide.screen("NameEntry"), "Start Life"), 0.6)
		eq(wide.UI.Current(), "Game")
		ok(wide.screen("Game").HUD:FindFirstChild("Bottom"), "compact two-row HUD")
		-- Select a card, then rotate the device: selection must survive the re-layout.
		local game = wide.screen("Game")
		wide.click(game:FindFirstChild("Wave", true), 0.1)
		wide.gui.CYL_Main.AbsoluteSize = V2(390, 844)
		task.wait(0.3)
		ok(wide.UI.IsNarrow(), "now portrait")
		ok(wide.screen("Game"):FindFirstChild("ConfirmBar", true).Visible, "selection kept after rotate")
		wide.click(wide.button(wide.screen("Game"), "Confirm"), 0.6)
		eq(wide.Decision.GetMode(), "Outcome")
		local clean, report = wide.noErrors()
		ok(clean, report)
	end)
	wide.server.close()

	section("Client UI: gamepad")
	local pad = bootPair(703, { Gamepad = true })
	test("Gamepad focus lands on buttons and cards; B is bound", function()
		local GuiService = pad.client.game:GetService("GuiService")
		local CAS = pad.client.game:GetService("ContextActionService")
		ok(CAS.Bound.CYL_Back, "B bound for back")
		pad.click(pad.button(pad.screen("Menu"), "Play"), 0.3)
		pad.click(pad.button(pad.screen("NameEntry"), "Start Life"), 0.6)
		task.wait(0.1)
		local selected = GuiService.SelectedObject
		ok(selected and selected.Parent and selected.Parent.Name == "Choices", "first card focused")
		pad.click(selected, 0.1)
		local focused = GuiService.SelectedObject
		ok(focused and focused.Name == "Confirm", "focus moves to Confirm")
		-- B cancels the selection rather than leaving the game.
		CAS.Bound.CYL_CancelChoice("CYL_CancelChoice", H.Enum.UserInputState.Begin)
		task.wait(0.1)
		eq(pad.screen("Game"):FindFirstChild("ConfirmBar", true).Visible, false, "selection cleared")
		eq(pad.UI.Current(), "Game")
		local clean, report = pad.noErrors()
		ok(clean, report)
	end)
	pad.server.close()
end
