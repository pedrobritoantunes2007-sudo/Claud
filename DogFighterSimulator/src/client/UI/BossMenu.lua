-- 🏰 BOSS: teleporta para a Boss Tower, tela própria para escolher o boss (com power recomendado
-- comparado ao seu), barra de vida/fase/tempo e câmera de combate que mostra o seu cachorro e o boss.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local DogData = require(ReplicatedStorage.Shared.DogData)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Kit = require(script.Parent.Kit)
local Net = require(script.Parent.Parent.Net)

local BossMenu = {}
local make = Kit.make
local C = Kit.C

local player = Players.LocalPlayer

local function myDog()
	local folder = workspace:FindFirstChild("Cachorros")
	if not folder then
		return nil
	end
	for _, model in ipairs(folder:GetChildren()) do
		if model:GetAttribute("Owner") == player.UserId and model:GetAttribute("Action") ~= "KO" then
			return model
		end
	end
	return nil
end

function BossMenu.Start(HUD)
	local menu = Kit.Menu({
		Name = "BossMenu",
		Title = "🏰 BOSS TOWER",
		Color = C.Purple,
		Width = 800,
		Height = 600,
		OnClose = function()
			HUD.CloseAll()
		end,
	})
	local body = menu.Body

	local status = Kit.Text(body, {
		Size = UDim2.fromScale(1, 0.07),
		Text = "",
		TextColor3 = C.Gold,
	})

	-- 👑 12 chefes numa lista que rola (escada: vence um, libera o próximo)
	local scroll = make("ScrollingFrame", {
		Position = UDim2.fromScale(0, 0.085),
		Size = UDim2.fromScale(1, 0.7),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 10,
		ScrollBarImageColor3 = C.Muted,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, body)
	make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, scroll)
	make("UIPadding", { PaddingRight = UDim.new(0, 14) }, scroll)
	local rows = {}
	for i, boss in ipairs(DogData.Bosses) do
		local species = DogData.Species[boss.Species]
		local rarityId = species and species.Rarity or "Legendary"
		local box = Kit.Box(scroll, { LayoutOrder = i, Size = UDim2.new(1, 0, 0, 104) })
		Kit.RarityStroke(box, rarityId, 3)
		local mini = make("Frame", {
			Position = UDim2.fromScale(0.012, 0.07),
			Size = UDim2.fromScale(0.86, 0.86),
			BackgroundColor3 = Kit.Rarity(rarityId).Color:Lerp(C.Dark, 0.45),
			BorderSizePixel = 0,
			ClipsDescendants = true,
		}, box)
		make("UIAspectRatioConstraint", { AspectRatio = 1 }, mini)
		Kit.Corner(mini, 12)
		Kit.Stroke(mini, C.Dark, 2)
		Kit.Gradient(mini, Color3.new(1, 1, 1), Color3.fromRGB(120, 110, 150))
		Kit.Text(mini, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, -0.04),
			Size = UDim2.fromScale(0.4, 0.3),
			Text = "👑",
			ZIndex = 3,
		})
		Kit.Text(box, {
			Position = UDim2.fromScale(0.16, 0.07),
			Size = UDim2.fromScale(0.5, 0.32),
			Text = "#" .. i .. "  " .. boss.Name .. "  LV." .. boss.Level,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local powerBar = Kit.Bar(box, { Position = UDim2.fromScale(0.16, 0.43), Size = UDim2.fromScale(0.5, 0.24) }, C.Green)
		local powerLine = powerBar.Label
		Kit.Text(box, {
			Position = UDim2.fromScale(0.16, 0.72),
			Size = UDim2.fromScale(0.5, 0.22),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = C.Cash,
			Text = "💵 $" .. Config.Format(boss.Reward) .. "   ·   " .. #boss.Phases .. " phases",
		})
		local button = Kit.Button(box, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(0.975, 0.5),
			Size = UDim2.fromScale(0.28, 0.66),
			Text = "⚔️ FIGHT",
		}, C.Red)
		local busy = false
		button.Activated:Connect(function()
			if busy then
				return
			end
			if not player:GetAttribute("InTower") then
				HUD.Toast("Enter the Boss Tower first 🏰", "gold")
				Kit.Shake(button)
				return
			end
			busy = true
			local ok, message = Net.Invoke("BossAction", "start", boss.Id)
			busy = false
			HUD.Toast(message, ok and "gold" or "red")
			if ok then
				HUD.CloseAll()
			else
				Kit.Shake(button)
			end
		end)
		rows[i] = { Boss = boss, Index = i, Button = button, Power = powerLine, Bar = powerBar, Mini = mini }
	end

	local enterButton =
		Kit.Button(body, { Position = UDim2.fromScale(0.15, 0.805), Size = UDim2.fromScale(0.7, 0.175), Text = "🏰 GO TO THE TOWER" }, C.Purple)
	local enterBusy = false
	enterButton.Activated:Connect(function()
		if enterBusy then
			return
		end
		enterBusy = true
		local inTower = player:GetAttribute("InTower")
		local ok, message = Net.Invoke("BossAction", inTower and "leave" or "enter")
		enterBusy = false
		if message and message ~= "" then
			HUD.Toast(message, ok and "gold" or "red")
		end
		if inTower then
			HUD.CloseAll()
		end
	end)

	local function refresh()
		local inTower = player:GetAttribute("InTower") == true
		enterButton.Text = inTower and "🏠 LEAVE THE TOWER" or "🏰 GO TO THE TOWER"
		Kit.SetButtonColor(enterButton, inTower and C.Orange or C.Purple)
		status.Text = inTower and "Pick a boss to fight!" or "Go to the Tower to challenge the bosses."
		local eq = Net.Equipped()
		local mine = eq and Net.Power(eq) or 0
		for _, r in ipairs(rows) do
			local rec = r.Boss.RecommendedPower
			local ready = mine >= rec
			r.Power.Text = "💪 " .. Config.Format(mine) .. " / " .. Config.Format(rec) .. (ready and "  ✅ READY" or "  ⚠️ too weak")
			r.Bar.Fill.BackgroundColor3 = ready and C.Green or C.Orange
			r.Bar.Set(rec > 0 and mine / rec or 1)
			local profile = Net.Profile
			local beaten = profile and profile.BossBeaten or 0
			local locked = r.Index > beaten + 1
			if locked then
				Kit.SetButtonColor(r.Button, C.Disabled)
				r.Button.Text = "🔒 BEAT #" .. (r.Index - 1)
			else
				Kit.SetButtonColor(r.Button, inTower and (ready and C.Red or C.Orange) or C.Disabled)
				r.Button.Text = (r.Index <= beaten and "✅ " or "") .. (inTower and "⚔️ FIGHT" or "🔒 FIGHT")
			end
		end
	end
	player:GetAttributeChangedSignal("InTower"):Connect(function()
		if menu.Open then
			refresh()
		end
	end)

	-- bosses em 3D só enquanto o menu está aberto
	local views = {}
	local function showViews(on)
		for i, r in ipairs(rows) do
			if on and not views[i] then
				local view = Kit.DogViewport(r.Mini, { Size = UDim2.fromScale(1, 1), ZIndex = 2 })
				view.Angle = 0.35 + (i % 4) * 0.15 -- (de frente, cada um num ângulo um pouco diferente)
				view.SetSpecies(r.Boss.Species)
				views[i] = view
			elseif not on and views[i] then
				views[i].Destroy()
				views[i] = nil
			end
		end
	end

	HUD.RegisterMenu("Boss", {
		Open = function()
			refresh()
			menu.Show(true)
			pcall(showViews, true)
		end,
		Close = function()
			menu.Show(false)
			task.delay(0.25, function()
				if not menu.Open then
					showViews(false)
				end
			end)
		end,
	})

	---------------------------------------------------------- barra do boss (topo-meio, no lugar da barra NEXT do HUD)
	local _barGui, barRoot = Kit.Screen("BossBar", 6)
	local barSafe = Kit.SafeArea(barRoot)
	local bar = Kit.Panel(barSafe, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(540, 84),
		Visible = false,
	})
	local barStroke = bar:FindFirstChildOfClass("UIStroke")
	if barStroke then
		barStroke.Color = Color3.fromRGB(120, 20, 30)
	end
	local bossName = Kit.Text(bar, {
		Position = UDim2.fromOffset(14, 6),
		Size = UDim2.new(0.68, -14, 0, 28),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 120, 100),
	})
	local timer = Kit.Text(bar, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 6),
		Size = UDim2.new(0.32, -14, 0, 28),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = C.Gold,
	})
	local hp = Kit.Bar(bar, { Position = UDim2.fromOffset(14, 40), Size = UDim2.new(1, -28, 0, 32) }, Color3.fromRGB(235, 55, 55))
	local lastPhase = 0

	local state: any = { Active = false }
	Net.Remotes.BossState.OnClientEvent:Connect(function(payload)
		state = payload
		local show = payload.Active and player:GetAttribute("InTower") == true
		if show and not bar.Visible then
			Kit.Pop(bar, true)
			lastPhase = 0
		elseif not show and bar.Visible then
			bar.Visible = false
		end
		HUD.SetTopReserve(show and 92 or 0)
		if payload.Active then
			bossName.Text = "👑 " .. payload.Name .. "   PHASE " .. payload.Phase .. "/" .. payload.Phases
			hp.Set(payload.HP / payload.MaxHP)
			hp.Label.Text = Config.Format(payload.HP) .. " / " .. Config.Format(payload.MaxHP)
			if lastPhase ~= 0 and payload.Phase ~= lastPhase then
				Kit.Shine(bar)
				Kit.Shake(bar)
			end
			lastPhase = payload.Phase
		end
	end)

	-- câmera de combate: enquadra o seu cachorro e o boss
	local camera = workspace.CurrentCamera
	local usingBossCam = false
	local smooth = nil
	RunService:BindToRenderStep("BossCamera", Enum.RenderPriority.Camera.Value + 0, function(dt)
		camera = workspace.CurrentCamera
		local active = state.Active and player:GetAttribute("InTower") == true and state.Model and state.Model.Parent ~= nil
		if active then
			local left = state.EndsAt - workspace:GetServerTimeNow()
			timer.Text = "⏱️ " .. Config.FormatTime(left)
			timer.TextColor3 = left < 30 and C.Red or C.Gold
			local bossRoot = state.Model.PrimaryPart
			local dog = myDog()
			local dogRoot = dog and dog.PrimaryPart
			if bossRoot then
				local a = bossRoot.Position
				local b = dogRoot and dogRoot.Position or Layout.BOSS_CENTER
				local mid = (a + b) / 2
				local spread = (a - b).Magnitude
				local away = Vector3.new(mid.X - Layout.BOSS_CENTER.X, 0, mid.Z - Layout.BOSS_CENTER.Z)
				local side = away.Magnitude > 1 and away.Unit or Vector3.new(0, 0, 1)
				local dist = math.clamp(spread * 1.1 + 45, 50, 120)
				local goal = CFrame.lookAt(mid + side * dist * 0.75 + Vector3.new(0, dist * 0.6, 0), mid)
				smooth = smooth and smooth:Lerp(goal, math.min(1, dt * 3)) or goal
				-- o jogador controla o cachorro na luta: câmera normal (só mantém o cálculo para o
				-- timer/barra; a câmera cinematográfica antiga ficava travada longe do cachorro)
				local _ = smooth
			end
		elseif usingBossCam then
			usingBossCam = false
			smooth = nil
			camera.CameraType = Enum.CameraType.Custom
			local character = player.Character
			camera.CameraSubject = character and character:FindFirstChildOfClass("Humanoid")
			bar.Visible = false
			HUD.SetTopReserve(0)
		end
	end)
end

return BossMenu
