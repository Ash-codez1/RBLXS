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
			api.click(card, 0.05) -- tap again to confirm
			api.waitMode(function(m)
				return m == "Outcome"
			end, 6)
			return card.Name
		end
		function api.waitMode(predicate, timeout)
			local deadline = os.clock() + (timeout or 4)
			while not predicate(api.Decision.GetMode()) and os.clock() < deadline do
				task.wait(0.03)
			end
		end
		-- Skips a playing Life Reveal and presses its end-card button.
		function api.finishReveal(buttonName)
			local revealGui = api.gui:FindFirstChild("CYL_Reveal")
			local deadline = os.clock() + 8
			while os.clock() < deadline do
				local skip = revealGui:FindFirstChild("RevealSkip", true)
				local finish = revealGui:FindFirstChild(buttonName or "RevealContinue", true) or (not buttonName and revealGui:FindFirstChild("RevealMenu", true))
				if finish then
					api.click(finish, 0.2)
					return true
				elseif skip then
					skip.Activated:Fire()
				end
				task.wait(0.1)
			end
			return false
		end
		-- Continue from an outcome: through an event card (if any) and any transition.
		api.eventsSeen = 0
		function api.continue()
			local game = api.screen("Game")
			api.click(api.button(game, "Continue"), 0.1)
			if api.Decision.GetMode() == "Event" then
				api.eventsSeen += 1
				assert(api.label(game, "EVENT"), "event card shows its rarity banner")
				api.click(api.button(game, "Continue"), 0.1)
			end
			if api.Decision.GetMode() == "Reveal" then
				api.revealsSeen = (api.revealsSeen or 0) + 1
				api.finishReveal()
			end
			if api.Decision.GetMode() == "Transition" then
				local skipper = H.find(game, function(d)
					return d.ClassName == "TextButton" and d.Text == "" and d.Parent and d.Parent.Name == "View"
				end)
				if skipper then
					api.click(skipper, 0.05) -- tap to skip
				end
			end
			api.waitMode(function(m)
				return m == "Scenario" or m == "Message"
			end)
			task.wait(0.15)
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

	test("People panel lists your parents and actions change bonds on the server", function()
		app.click(app.screen("Game").HUD:FindFirstChild("People", true), 0.2)
		local modal = app.gui.CYL_Overlay.Root:FindFirstChild("PeopleModal")
		ok(modal, "people panel open")
		local life = app.data().Slots.Slot1
		local parent = life.People[1]
		ok(app.label(modal, parent.Name), "parent listed by name")
		ok(app.label(modal, "2 actions left"), "actions counter")
		local before = parent.Bond
		app.click(modal:FindFirstChild(parent.Id, true):FindFirstChild("Time", true), 0.5)
		ok(app.data().Slots.Slot1.People[1].Bond > before, "bond increased on the server")
		ok(app.label(modal, "1 action left"), "counter updated")
		app.click(modal:FindFirstChild(parent.Id, true):FindFirstChild("Talk", true), 0.5)
		ok(app.label(modal, "0 actions left"), "out of actions")
		eq(modal:FindFirstChild(parent.Id, true):FindFirstChild("Time", true):GetAttribute("Disabled"), true, "buttons disabled")
		app.click(modal:FindFirstChild("Close", true), 0.4)
	end)

	test("Lifestyle panel changes your focus", function()
		app.click(app.screen("Game").HUD:FindFirstChild("Lifestyle", true), 0.2)
		local modal = app.gui.CYL_Overlay.Root:FindFirstChild("LifestyleModal")
		ok(modal, "lifestyle panel open")
		ok(app.label(modal, "Available from age 16"), "money focus is age-gated for a child")
		app.click(modal:FindFirstChild("Health", true), 0.5)
		eq(app.data().Slots.Slot1.Focus, "Health")
		ok(app.label(modal, "✓ CURRENT"), "current marked")
		app.click(modal:FindFirstChild("Close", true), 0.4)
	end)

	test("Play an entire life through the UI, from age 6 to 85", function()
		app.Anim.Reduced = true
		local careerSeen = false
		for _ = 1, 37 do
			app.decide()
			eq(app.Decision.GetMode(), "Outcome")
			app.continue()
			local occupation = app.screen("Game").HUD:FindFirstChild("Occupation", true)
			local text = occupation and occupation:FindFirstChild("Label") and occupation.Label.Text or ""
			if text ~= "" and not text:find("Pupil") and not text:find("Student") then
				careerSeen = true
			end
		end
		eq(app.Decision.GetMode(), "Message")
		ok(app.label(app.screen("Game"), "A Life Complete"), "life complete message")
		ok(app.label(app.screen("Game"), "lived to 85"), "summary mentions final age")
		local life = app.data().Slots.Slot1
		eq(life.Completed, true)
		eq(life.Age, 85)
		eq(#life.Decisions, 38)
		ok(careerSeen, "HUD showed an occupation beyond school")
		eq(app.revealsSeen, 6, "a Life Reveal after every stage (5) plus the final reveal")
		local history = app.data().LifeHistory
		eq(#history, 1, "life saved to Life History")
		ok(history[1].Ending and history[1].Ending.Title, "ending title")
		ok(app.data().Coins > 100, "coins awarded for the completed life")
		print(("      (%d random event card(s); ending: %s %s)"):format(app.eventsSeen, history[1].Ending.Icon, history[1].Ending.Title))
	end)

	test("HUD menu button returns to the menu, which now shows the life", function()
		app.click(app.screen("Game").HUD:FindFirstChild("Menu", true), 0.3)
		eq(app.UI.Current(), "Menu")
		local menu = app.screen("Menu")
		ok(app.button(menu, "Play"), "play button")
		ok(app.label(menu, "CURRENT LIFE"), "life card")
		ok(app.button(menu, "Continue Life"):GetAttribute("Disabled") ~= true, "Continue enabled")
	end)

	test("Life History lists the finished life; detail, replay and compare work", function()
		local menu = app.screen("Menu")
		app.click(app.button(menu, "Life History"), 0.3)
		eq(app.UI.Current(), "LifeHistory")
		local screen = app.screen("LifeHistory")
		local entry = app.data().LifeHistory[1]
		ok(app.label(screen, entry.Ending.Title), "ending shown in the list")
		app.click(screen:FindFirstChild("Life" .. entry.Id, true), 0.3)
		local detail = app.gui.CYL_Overlay.Root:FindFirstChild("LifeDetailModal")
		ok(detail, "detail panel")
		ok(app.label(detail, "PREDICTIONS VS REALITY"), "journey section")
		app.click(detail:FindFirstChild("CompareLives", true), 0.3)
		ok(app.gui.CYL_Overlay.Root:FindFirstChild("PickLifeModal"), "compare picker")
		ok(app.label(app.gui.CYL_Overlay.Root:FindFirstChild("PickLifeModal"), "Complete another life"), "needs two lives")
		app.UI.ClosePanel()
		task.wait(0.3)
		app.click(screen:FindFirstChild("Life" .. entry.Id, true), 0.3)
		app.click(app.gui.CYL_Overlay.Root:FindFirstChild("LifeDetailModal"):FindFirstChild("Replay", true), 0.3)
		local Reveal = app.client.require("StarterPlayerScripts.Client.Controllers.RevealController")
		ok(Reveal.IsPlaying(), "final reveal replaying")
		ok(app.finishReveal("RevealMenu"), "replay can be closed")
		task.wait(0.2)
		ok(not Reveal.IsPlaying(), "replay finished")
		app.click(app.button(screen, "Back"), 0.3)
		eq(app.UI.Current(), "Menu")
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
		phone.click(phone.screen("Game").HUD:FindFirstChild("Future", true), 0.3)
		local future = phone.gui.CYL_Overlay.Root:FindFirstChild("FutureModal")
		ok(future, "future panel")
		ok(phone.label(future, "POSSIBLE FUTURES") and phone.label(future, "%"), "live odds shown")
		phone.click(future:FindFirstChild("Compare", true), 0.5)
		ok(phone.label(future, "Nobody else is here yet"), "compare list (alone in server)")
		phone.click(phone.screen("Game").HUD:FindFirstChild("Stats", true), 0.3)
		ok(phone.gui.CYL_Overlay.Root:FindFirstChild("StatsModal"), "stats modal")
		-- Money panel as an adult with savings and a loan.
		phone.DataService.Update(phone.player, function(d)
			local life = d.Slots.Slot1
			life.Age = 30
			life.Money = 20000
			table.insert(life.Loans, { Kind = "Student", Balance = 4000, Rate = 0.03, Payment = 500 })
		end)
		task.wait(0.3)
		phone.click(phone.screen("Game").HUD:FindFirstChild("Money", true), 0.3)
		local money = phone.gui.CYL_Overlay.Root:FindFirstChild("MoneyModal")
		ok(money, "money panel")
		ok(phone.label(money, "Student loan"), "loan listed")
		ok(phone.label(money, "Rent"), "budget shows rent")
		phone.click(money:FindFirstChild("Invest50", true), 0.6)
		eq(phone.data().Slots.Slot1.Investments, 10000, "invested half")
		eq(phone.data().Slots.Slot1.Money, 10000)
		phone.click(money:FindFirstChild("Repay1Max", true), 0.6)
		eq(#phone.data().Slots.Slot1.Loans, 0, "loan paid off")
		eq(phone.data().Slots.Slot1.Money, 6000)
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
