-- 🏝️ Ilhas no cliente (2026-10, mapa novo):
--   • placas dos portais da Praça: ✅ aberta / 🔓 preço (a próxima) / 🔒 trancada — para cada jogador
--   • faixa grande com o nome da ilha ao chegar (e o nível dos selvagens)
--   • ar de cada ilha (Atmosphere): neve azulada, deserto quente, fumaça do vulcão, espaço roxo...
--   • plataformas de pulo (LaunchPad), o Gêiser do Céu (sobe até as nuvens) e os anéis de vento
--   • balcão do ovo (EggStandPrompt) abre o 🎒 EGGS; santuário do Divino abre a ⭐ SHOP
--   • ilhas longe da câmera escondem os enfeites (o terreno continua): o jogo fica leve
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local DogData = require(ReplicatedStorage.Shared.DogData)
local Islands = require(ReplicatedStorage.Shared.Islands)
local Village = require(ReplicatedStorage.Shared.Village)
local UI = script.Parent.Parent:WaitForChild("UI")
local Kit = require(UI:WaitForChild("Kit"))
local Net = require(script.Parent.Parent:WaitForChild("Net"))
local C = Kit.C

local IslandsClient = {}
IslandsClient.HUD = nil :: any

local player = Players.LocalPlayer

local function opened(id)
	if id == "common" or id == "main" or id == "colosseum" then
		return true
	end
	local p = Net.Profile
	return p ~= nil and type(p.Islands) == "table" and p.Islands[id] == true
end

local function myRoot()
	local char = player.Character
	return char and char.PrimaryPart, char and char:FindFirstChildOfClass("Humanoid")
end

---------------------------------------------------------------- placas dos portais
local function refreshSigns()
	local map = workspace:FindFirstChild("Map")
	local isle = map and map:FindFirstChild("IlhaPrincipal")
	local plaza = isle and isle:FindFirstChild("PracaPortais")
	if not plaza then
		return
	end
	local p = Net.Profile
	for _, id in ipairs(Islands.ORDER) do
		local portal = plaza:FindFirstChild("Portal_" .. id)
		local def = Islands.List[id]
		if portal and def then
			local text, color
			if opened(id) then
				text, color = "✅ OPEN", C.Cash
			elseif p and Islands.CanUnlock(p.Islands or {}, id) then
				-- 🔐 (2026-10-24) cada ilha pede mais que dinheiro: mostra quantos passos faltam (lista no MAP)
				local list, ok = Islands.Requirements(p, id, Islands.EquippedLevel(p))
				local missing = 0
				for _, r in ipairs(list) do
					if not r.Done then
						missing += 1
					end
				end
				if ok then
					text, color = "🔓 READY · $" .. Config.Format(def.Price or 0), C.Gold
				else
					text, color = "🔒 " .. missing .. (missing == 1 and " step" or " steps") .. " left · MAP", Color3.fromRGB(255, 200, 120)
				end
			else
				text, color = "🔒 $" .. Config.Format(def.Price or 0), Color3.fromRGB(255, 140, 140)
			end
			for _, d in ipairs(portal:GetDescendants()) do
				if d:IsA("TextLabel") and d.Name == "Status" then
					d.Text = text
					d.TextColor3 = color
				end
			end
		end
	end
end

---------------------------------------------------------------- faixa com o nome da ilha
local banner, bannerTitle, bannerSub
local function buildBanner()
	local gui, root = Kit.Screen("IslandBanner", 30)
	gui.Enabled = true
	banner = Kit.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.24, 0), -- abaixo do chip da ilha, da barra NEXT e dos avisos do HUD
		Size = UDim2.fromOffset(440, 70), -- (2026-10-24: menor — "muita coisa tampa a tela")
		BackgroundTransparency = 1,
		Visible = false,
	}, root)
	bannerTitle = Kit.Text(banner, { Size = UDim2.fromScale(1, 0.62), Text = "", TextColor3 = C.Gold })
	bannerSub = Kit.Text(banner, { Position = UDim2.fromScale(0, 0.6), Size = UDim2.fromScale(1, 0.36), Text = "", TextColor3 = C.Text })
end

local bannerToken = 0
local function showBanner(where)
	if not banner then
		return
	end
	local title, sub, color
	local def = Islands.List[where]
	if def then
		local egg = def.Egg and DogData.Eggs[def.Egg]
		title = Islands.EMOJI[where] .. " " .. string.upper(def.Name)
		local spot = (egg and not Config.EGGS) and "  ·  🦮 Catch them!" or egg and ("  ·  🥚 " .. egg.Name) or "  ·  ☀️ Sunfire shrine"
		sub = "Wild dogs Lv." .. def.Levels[1] .. "-" .. def.Levels[2] .. spot
		color = Islands.COLORS[where]:Lerp(Color3.new(1, 1, 1), 0.25)
	elseif where == "colosseum" then
		title, sub, color = "⚔️ COLOSSEUM", "🌍 Super Boss  ·  ⚔️ PvP (when it sleeps)", C.Red
	elseif where == Village.Id then
		title, sub, color = Village.Emoji .. " " .. string.upper(Village.Name), "Safe zone  ·  🎓 Prof. Barkley is in the Kennel", Village.Color:Lerp(Color3.new(1, 1, 1), 0.2)
	else
		return
	end
	bannerToken += 1
	local token = bannerToken
	bannerTitle.Text = title
	bannerTitle.TextColor3 = color
	bannerSub.Text = sub
	banner.Visible = true
	bannerTitle.TextTransparency, bannerSub.TextTransparency = 1, 1
	Kit.Tween(bannerTitle, 0.35, { TextTransparency = 0 })
	Kit.Tween(bannerSub, 0.35, { TextTransparency = 0 })
	task.delay(2.6, function()
		if token ~= bannerToken then
			return
		end
		Kit.Tween(bannerTitle, 0.6, { TextTransparency = 1 })
		Kit.Tween(bannerSub, 0.6, { TextTransparency = 1 })
		task.delay(0.65, function()
			if token == bannerToken then
				banner.Visible = false
			end
		end)
	end)
end

---------------------------------------------------------------- ar de cada ilha (Atmosphere)
local AIR = {
	common = { Density = 0.24, Haze = 0.6, Color = Color3.fromRGB(215, 235, 255), Decay = Color3.fromRGB(120, 160, 210) },
	uncommon = { Density = 0.36, Haze = 1.6, Color = Color3.fromRGB(225, 238, 255), Decay = Color3.fromRGB(170, 200, 240) },
	rare = { Density = 0.3, Haze = 1.4, Color = Color3.fromRGB(255, 226, 185), Decay = Color3.fromRGB(220, 150, 90) },
	epic = { Density = 0.26, Haze = 0.9, Color = Color3.fromRGB(205, 240, 235), Decay = Color3.fromRGB(110, 170, 170) },
	legendary = { Density = 0.45, Haze = 2.2, Color = Color3.fromRGB(150, 100, 90), Decay = Color3.fromRGB(110, 45, 30) },
	mythic = { Density = 0.38, Haze = 1.2, Color = Color3.fromRGB(150, 120, 230), Decay = Color3.fromRGB(70, 40, 140) },
	divine = { Density = 0.25, Haze = 1, Color = Color3.fromRGB(255, 232, 175), Decay = Color3.fromRGB(230, 170, 90) },
	cloud = { Density = 0.14, Haze = 0.3, Color = Color3.fromRGB(235, 245, 255), Decay = Color3.fromRGB(150, 190, 240) },
}
local baseAir
local function applyAir(where)
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmo then
		return
	end
	if not baseAir then
		baseAir = { Density = atmo.Density, Haze = atmo.Haze, Color = atmo.Color, Decay = atmo.Decay }
	end
	local goal = AIR[where] or baseAir
	TweenService:Create(atmo, TweenInfo.new(2.5, Enum.EasingStyle.Sine), goal):Play()
end

---------------------------------------------------------------- voo controlado (plataforma de pulo / gêiser)
local flying = false
local function fly(target, apexExtra, duration)
	local root, hum = myRoot()
	if flying or not (root and hum) then
		return
	end
	flying = true
	local start = root.Position
	local apex = math.max(start.Y, target.Y) + (apexExtra or 40)
	local t0 = os.clock()
	local T = duration
	hum.PlatformStand = true
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local r = myRoot()
		if r ~= root or not root.Parent then
			conn:Disconnect()
			flying = false
			return
		end
		local u = math.clamp((os.clock() - t0) / T, 0, 1)
		-- parábola que passa pelo ápice: sobe rápido e desce suave no alvo
		local flat = start:Lerp(target, u)
		local h = (1 - u) * (1 - u) * start.Y + 2 * u * (1 - u) * (2 * apex - (start.Y + target.Y) / 2) + u * u * target.Y
		local p = Vector3.new(flat.X, h, flat.Z)
		local dir = Vector3.new(target.X - start.X, 0, target.Z - start.Z)
		local look = dir.Magnitude > 1 and CFrame.lookAt(p, p + dir) or CFrame.new(p) * root.CFrame.Rotation
		root.CFrame = look
		root.AssemblyLinearVelocity = Vector3.zero
		if u >= 1 then
			conn:Disconnect()
			hum.PlatformStand = false
			flying = false
		end
	end)
end

local lastPad = 0
local function checkPads(root)
	local now = os.clock()
	if flying or now - lastPad < 1.5 then
		return
	end
	local pos = root.Position
	for _, pad in ipairs(CollectionService:GetTagged("LaunchPad")) do
		local d = pad.Position - pos
		if math.abs(d.Y) < 9 and Vector3.new(d.X, 0, d.Z).Magnitude < 7.5 then
			local target = pad:GetAttribute("Target")
			if typeof(target) == "Vector3" then
				lastPad = now
				local dist = (Vector3.new(target.X, 0, target.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude
				fly(target, 35 + dist * 0.12, math.clamp(1.2 + dist / 140, 1.4, 3.2))
				return
			end
		end
	end
	for _, vent in ipairs(CollectionService:GetTagged("Geyser")) do
		local d = vent.Position - pos
		if math.abs(d.Y) < 14 and Vector3.new(d.X, 0, d.Z).Magnitude < 24 then
			lastPad = now
			if not opened("cloud") then
				local def = Islands.List.cloud
				local hud = IslandsClient.HUD
				if hud then
					hud.Toast("🔒 " .. def.Name .. " is locked — unlock it in 🗺️ MAP to ride the geyser!", "red")
				end
				return
			end
			local target = vent:GetAttribute("Target")
			if typeof(target) == "Vector3" then
				fly(target, 30, 4.2)
			end
			return
		end
	end
end

-- anel de vento: quem voa por dentro ganha um empurrão para a frente
local lastRing = {}
local function checkRings(root)
	local now = os.clock()
	local pos = root.Position
	for _, ring in ipairs(CollectionService:GetTagged("WindRing")) do
		if (ring.Position - pos).Magnitude < 30 and now - (lastRing[ring] or 0) > 1.2 then
			local l = ring.CFrame:PointToObjectSpace(pos)
			if math.abs(l.X) < 22 and math.abs(l.Y) < 22 and math.abs(l.Z) < 6 then
				lastRing[ring] = now
				local look = root.CFrame.LookVector
				root.AssemblyLinearVelocity = look * 140 + Vector3.new(0, 25, 0)
			end
		end
	end
end

---------------------------------------------------------------- ilhas longe: esconde os enfeites
local hidden = {} -- [model] = true
local stash = Instance.new("Folder")
stash.Name = "IlhasLonge"
local function cullIslands(camPos)
	-- gráfico Baixo (⚙️ SETTINGS): esconde mais perto (celular fraco)
	local k = player:GetAttribute("GraphicsQuality") == "Baixo" and 0.7 or 1
	local folder = workspace:FindFirstChild("Islands")
	if folder then
		for _, model in ipairs(folder:GetChildren()) do
			local id = model:GetAttribute("Island")
			local def = id and (Islands.List[id] or (id == Village.Id and Village.Def))
			if def and model:GetAttribute("Ready") then
				local far = (def.Center - camPos).Magnitude > (id == "cloud" and 2700 or 1750) * k
				if far and model.Parent == folder then
					hidden[model] = true
					model.Parent = stash
				end
			end
		end
	end
	for model in pairs(hidden) do
		local id = model:GetAttribute("Island")
		local def = id and (Islands.List[id] or (id == Village.Id and Village.Def))
		if def and (def.Center - camPos).Magnitude <= (id == "cloud" and 2500 or 1550) * k then
			hidden[model] = nil
			model.Parent = workspace:FindFirstChild("Islands") or workspace
		elseif not def then
			hidden[model] = nil
		end
	end
end

---------------------------------------------------------------- detalhes pequenos: só perto da câmera
-- (Detalhista Perfeccionista, 2026-10) cada ilha guarda pedrinhas, caixas, flores e bichinhos em células de
-- 160 studs (tag "DetailCell", atributo Cell = centro). Longe da câmera a célula sai do workspace: não desenha nada.
local cellHome = {} -- [célula] = pasta onde ela mora
local cellStash = Instance.new("Folder")
cellStash.Name = "DetalhesLonge"
local function cullDetails(camPos)
	local k = player:GetAttribute("GraphicsQuality") == "Baixo" and 0.65 or 1
	-- (2026-10: era 470/540 — mais leve; a Pawville sozinha tem ~42 mil peças de detalhe)
	local show, hide = 420 * k, 480 * k
	for _, cell in ipairs(CollectionService:GetTagged("DetailCell")) do
		local center = cell:GetAttribute("Cell")
		if typeof(center) == "Vector3" then
			if cellHome[cell] == nil and cell.Parent ~= cellStash then
				cellHome[cell] = cell.Parent
			end
			local d = (center - camPos).Magnitude
			if d > hide and cell.Parent ~= cellStash then
				cell.Parent = cellStash
			elseif d < show and cell.Parent == cellStash and cellHome[cell] then
				cell.Parent = cellHome[cell]
			end
		end
	end
end

---------------------------------------------------------------- entrada
function IslandsClient.Start(HUD)
	IslandsClient.HUD = HUD
	stash.Parent = ReplicatedStorage
	cellStash.Parent = ReplicatedStorage
	buildBanner()
	Net.Changed.Event:Connect(refreshSigns)
	task.spawn(function()
		while true do
			pcall(refreshSigns)
			task.wait(4)
		end
	end)
	local last = player:GetAttribute("Island")
	player:GetAttributeChangedSignal("Island"):Connect(function()
		local where = player:GetAttribute("Island")
		if where ~= last then
			last = where
			showBanner(where)
			applyAir(where)
		end
	end)
	-- balcão do ovo → 🎒 EGGS; santuário do Divino → ⭐ SHOP
	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who ~= player then
			return
		end
		if CollectionService:HasTag(prompt, "EggStandPrompt") then
			local egg = DogData.Eggs[prompt:GetAttribute("EggId") or ""]
			if not HUD.IsOpen("Inventario") then
				HUD.Toggle("Inventario")
			end
			if egg then
				HUD.Toast("🥚 " .. egg.Name .. " — buy it in 🎒 EGGS!", "gold")
			end
		elseif CollectionService:HasTag(prompt, "DivineShrinePrompt") and not HUD.IsOpen("Loja") then
			HUD.Toggle("Loja")
			-- ☀️ o altar do Divino abre a loja direto na aba do Sunfire Dragon
			local shop = HUD.GetMenu and HUD.GetMenu("Loja")
			if shop and shop.Tab then
				shop.Tab("dogs")
			end
		end
	end)
	-- flash na tela quando o servidor teleporta (portais, MAP)
	local flash = Kit.make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 50,
	}, (select(2, Kit.Screen("TeleportFlash", 45))))
	flash.Parent.Parent.Enabled = true
	Net.Remotes.Effect.OnClientEvent:Connect(function(name)
		if name == "Teleport" then
			flash.BackgroundTransparency = 0.15
			Kit.Tween(flash, 0.7, { BackgroundTransparency = 1 })
		end
	end)
	local acc, detailAcc = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		local root = myRoot()
		if root then
			checkPads(root)
			checkRings(root)
		end
		acc += dt
		detailAcc += dt
		local cam = workspace.CurrentCamera
		if acc > 1 then
			acc = 0
			if cam then
				pcall(cullIslands, cam.CFrame.Position)
			end
		end
		if detailAcc > 0.4 then
			detailAcc = 0
			if cam then
				pcall(cullDetails, cam.CFrame.Position)
			end
		end
	end)
end

return IslandsClient
