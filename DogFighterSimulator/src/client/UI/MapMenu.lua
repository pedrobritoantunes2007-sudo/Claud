-- Tela 🗺️ MAP (2026-10-24, pedidos do dono: "quero que esse radar vire o mapa realmente mostrando o mapa" e "quero que
-- seja cada vez mais difícil ir para outras ilhas"). À esquerda o MAPA DESENHADO do mundo (UI/WorldMap: as ilhas de
-- verdade, com contorno cartoon) com a rota de cada portal da Praça até a sua ilha (dourada = aberta, branca = a
-- próxima, cinza = trancada) e um botão em cima de cada ilha. À direita, a ilha escolhida: níveis, ovo, campeão e —
-- se estiver trancada — a LISTA do que falta para abri-la (Islands.Requirements: a anterior aberta, o level do
-- cachorro, o campeão da anterior derrotado, as missões feitas lá e o Cash). Embaixo: GO / UNLOCK / trancada.
-- Em cima: quanto falta para o Super Boss acordar e o PvP (só vale no ⚔️ Coliseu, com o Super Boss dormindo).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DogData = require(ReplicatedStorage.Shared.DogData)
local Islands = require(ReplicatedStorage.Shared.Islands)
local Layout = require(ReplicatedStorage.Shared.Layout)
local MapTiles = require(ReplicatedStorage.Shared.MapTiles)
local Village = require(ReplicatedStorage.Shared.Village)
local Kit = require(script.Parent.Kit)
local Icons = require(script.Parent.Icons)
local WorldMap = require(script.Parent.WorldMap)
local Net = require(script.Parent.Parent.Net)

local MapMenu = {}
local C = Kit.C
local make = Kit.make

local player = Players.LocalPlayer

-- destinos: 🏡 Pawville (ilha de entrada), a ilha principal e o Coliseu, depois as ilhas na ordem da aventura
local DESTS = { Village.Id, "main", "colosseum" }
for _, id in ipairs(Islands.ORDER) do
	table.insert(DESTS, id)
end
-- ícone desenhado de cada lugar
local ICON = {
	[Village.Id] = "house",
	main = "home",
	colosseum = "sword",
	common = "flower",
	uncommon = "ice",
	rare = "bone",
	epic = "skull",
	legendary = "fire",
	mythic = "portal",
	divine = "sun",
	cloud = "cloud",
}
local EXTRA = {
	main = { Name = "Home Island", Color = Islands.COLORS.main, Sub = "Portals to every island" },
	colosseum = { Name = "Colosseum", Color = C.Red, Sub = "Super Boss · PvP" },
	[Village.Id] = { Name = Village.Name, Color = Village.Color, Sub = "Start village · Kennel · Safe zone" },
}
-- onde fica o botão de cada lugar no mapa (mundo)
local function destPos(id)
	if id == "main" then
		return Layout.SPAWN_PLAZA
	elseif id == "colosseum" then
		return Vector3.new(0, 0, 0)
	elseif id == Village.Id then
		return Village.Center
	end
	return Islands.List[id].Center
end

local function opened(id)
	if id == "main" or id == "colosseum" or id == "common" or id == Village.Id then
		return true
	end
	local p = Net.Profile
	return p ~= nil and type(p.Islands) == "table" and p.Islands[id] == true
end

local function clock(sec)
	sec = math.max(0, math.floor(sec or 0))
	return string.format("%d:%02d", sec // 60, sec % 60)
end

-- texto de cada passo da lista (Islands.Requirements) e o ícone dele quando ainda falta
local REQ_ICON = { island = "map", level = "up", champion = "crown", missions = "scroll", cash = "coins" }
local function reqText(r)
	if r.Kind == "island" then
		return "Open " .. r.Name
	elseif r.Kind == "level" then
		return "Dog Lv." .. r.Need .. (r.Done and "" or ("  (yours: Lv." .. r.Have .. ")"))
	elseif r.Kind == "champion" then
		return "Beat " .. r.Name
	elseif r.Kind == "missions" then
		return "Missions in " .. r.Island .. "  " .. r.Have .. "/" .. r.Need
	elseif r.Kind == "cash" then
		return "$" .. Config.Format(r.Need) .. (r.Done and "" or ("  (you: $" .. Config.Format(r.Have) .. ")"))
	end
	return ""
end

function MapMenu.Start(HUD)
	local menu = Kit.Menu({
		Name = "MapMenu",
		Title = "🗺️ MAP",
		Color = Islands.COLORS.main,
		Width = 1000,
		Height = 640,
		HeaderHeight = 0.1,
		OnClose = function()
			HUD.CloseAll()
		end,
	})
	local body = menu.Body

	---------------------------------------------------------- topo: Super Boss + PvP
	local bossBox = Kit.Box(body, { Size = UDim2.fromScale(0.58, 0.1) }, C.Panel2)
	local bossText = Kit.Text(bossBox, {
		Position = UDim2.fromScale(0.03, 0.15),
		Size = UDim2.fromScale(0.94, 0.7),
		Text = "",
		TextColor3 = C.Gold,
	})
	-- ⚔️ (2026-10) o PvP não tem mais botão: liga sozinho no chão do Coliseu (pausa com o Super Boss acordado)
	local pvpBox = Kit.Box(body, { Position = UDim2.fromScale(0.6, 0), Size = UDim2.fromScale(0.4, 0.1) }, C.Panel2)
	local pvpText = Kit.Text(pvpBox, {
		Name = "PvPStatus",
		Position = UDim2.fromScale(0.03, 0.15),
		Size = UDim2.fromScale(0.94, 0.7),
		Text = "",
		TextColor3 = C.Red,
	})

	---------------------------------------------------------- 🗺️ o mapa (esquerda): as FOTOS DE CIMA das ilhas de verdade
	-- (2026-10-24, o dono: "quero que esse mapa seja exatamente o mapa de cima") — UI/WorldMap põe as fotos de cima
	-- (Shared/MapTiles) por cima do desenho. Nada tampa as ilhas: só o nome embaixo de cada uma, um cadeado pequeno se
	-- estiver trancada e o alfinete onde você está. Clicar na ilha escolhe ela. A Pawville (bem longe, ao sul) fica
	-- num quadrinho no canto de baixo.
	-- tamanho nominal da área do mapa em pixels de design (janela 1000x640, faixa 10%, margem 14, 58% x 88%)
	local MAP_W, MAP_H = (1000 - 28) * 0.58, (640 * 0.9 - 28) * 0.88
	-- o anel das ilhas inteiro (do vulcão, ao norte, até os dedos da Puppy Meadows, ao sul)
	local TOP, BOTTOM = -2980, 3300
	local SCALE = MAP_H / (BOTTOM - TOP)
	local ORIGIN = Vector3.new(0, 0, (TOP + BOTTOM) / 2)
	local mapBox = Kit.Box(body, { Position = UDim2.fromScale(0, 0.12), Size = UDim2.fromScale(0.58, 0.88) }, WorldMap.OCEAN)
	local canvas = make("CanvasGroup", {
		Name = "Mapa",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WorldMap.OCEAN,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, mapBox)
	Kit.Corner(canvas, 12)
	-- (tudo em ESCALA da área do mapa: numa tela pequena a janela encolhe e o mapa encolhe junto)
	local BOX = Vector2.new(MAP_W, MAP_H)
	local center = WorldMap.Build(canvas, SCALE, BOX, ORIGIN)
	center.ZIndex = 3

	-- ponto do mundo -> px nominais a partir do centro do mapa; e px nominais -> posição em escala
	local function px(pos)
		return pos.X * SCALE, (pos.Z - ORIGIN.Z) * SCALE
	end
	local function at(x, z)
		return UDim2.fromScale(0.5 + x / MAP_W, 0.5 + z / MAP_H)
	end
	-- (contorno da BORDA — num TextButton o contorno "normal" iria para o texto)
	local function ink(frame, thickness)
		return make("UIStroke", { Color = Kit.INK, Thickness = thickness or 1.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, frame)
	end
	-- 🧭 rotas: pontinhos da Praça dos Portais até cada ilha (a cor mostra se já dá para ir)
	local routes = {}
	for _, id in ipairs(Islands.ORDER) do
		local a = Islands.PlazaPortalCFrame(id).Position
		local b = Islands.PortalCFrame(id).Position
		local dots = {}
		local len = (b - a).Magnitude
		local n = math.max(2, math.floor(len / 160))
		for i = 1, n - 1 do
			local x, z = px(a:Lerp(b, i / n))
			local d = make("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = at(x, z),
				Size = UDim2.fromOffset(5, 5),
				BackgroundColor3 = C.Gold,
				BorderSizePixel = 0,
				ZIndex = 25,
			}, center)
			Kit.Corner(d, 999)
			ink(d)
			table.insert(dots, d)
		end
		routes[id] = dots
	end

	-- 🏡 quadrinho da Pawville (canto de baixo, à esquerda) com a foto de cima dela e a rota até o portal dela
	local INSET_W, INSET_H = 96, 70
	local inset = make("TextButton", {
		Name = "Map_" .. Village.Id,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 8, 1, -8),
		Size = UDim2.fromOffset(INSET_W, INSET_H),
		BackgroundColor3 = WorldMap.OCEAN,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		ClipsDescendants = true,
		ZIndex = 40,
	}, canvas)
	Kit.Corner(inset, 10)
	local insetRing = ink(inset, 3)
	local insetPhoto = make("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromScale(1.15, 1.15),
		SizeConstraint = Enum.SizeConstraint.RelativeXX,
		BackgroundTransparency = 1,
		ZIndex = 41,
	}, inset)
	if not WorldMap.BindTile(insetPhoto, Village.Id) then
		insetPhoto.Visible = false
		Icons.Make(inset, "house", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.42),
			Size = UDim2.fromScale(0.55, 0.55),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			ZIndex = 42,
		})
	end
	do
		local x0, z0 = px(Layout.PAWVILLE_PORTAL)
		local x1, z1 = -MAP_W / 2 + 8 + INSET_W, MAP_H / 2 - 8 - INSET_H / 2
		local steps = 8
		for i = 1, steps - 1 do
			local d = make("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = at(x0 + (x1 - x0) * i / steps, z0 + (z1 - z0) * i / steps),
				Size = UDim2.fromOffset(5, 5),
				BackgroundColor3 = Village.Color,
				BorderSizePixel = 0,
				ZIndex = 25,
			}, center)
			Kit.Corner(d, 999)
			ink(d)
		end
	end

	---------------------------------------------------------- cada lugar: área de clique em cima da ilha + nome embaixo
	local markers = {}
	local selected = nil
	local refresh -- (definida mais abaixo)
	-- raio (studs) da área de clique / do anel de escolha de cada lugar
	local function reach(id)
		if id == "main" then
			return Layout.ISLAND_RADIUS + 20
		elseif id == "colosseum" then
			return Layout.COLOSSEUM_WALL
		end
		local tile = MapTiles.ByKey[id]
		return tile and tile.Span * 0.4 or 500
	end
	for _, id in ipairs(DESTS) do
		local def = Islands.List[id]
		local nameText = EXTRA[id] and EXTRA[id].Name or (def and def.Name) or id
		local m = { Id = id }
		if id == Village.Id then
			m.Button, m.Ring = inset, insetRing
			m.Name = Kit.Text(inset, {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -2),
				Size = UDim2.new(1, -6, 0, 16),
				Text = nameText,
				Font = Kit.Title,
				ZIndex = 44,
			})
		else
			local x, z = px(destPos(id))
			if id == "main" then
				x, z = px(Vector3.new(0, 0, 0))
			end
			local r = reach(id) * SCALE
			local hit = make("TextButton", {
				Name = "Map_" .. id,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = at(x, z),
				Size = UDim2.fromOffset(2 * r, 2 * r),
				BackgroundTransparency = 1,
				AutoButtonColor = false,
				Text = "",
				ZIndex = id == "colosseum" and 32 or 30,
			}, center)
			Kit.Corner(hit, 999)
			local ring = make("UIStroke", { Color = C.Gold, Thickness = 3, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, hit)
			m.Button, m.Ring = hit, ring
			-- nome embaixo da ilha (o Coliseu: no meio da arena)
			local nz = id == "colosseum" and z or (z + r * 0.92)
			m.Name = Kit.Text(center, {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = at(x, nz),
				Size = UDim2.fromOffset(120, 15),
				Text = nameText,
				Font = Kit.Title,
				ZIndex = 34,
			})
		end
		-- (o cadeado pequeno vai colado no nome — Kit.LeadIcon — quando a ilha está trancada) e o alfinete em cima
		m.Here = Icons.Make(id == Village.Id and inset or center, "pin", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = id == Village.Id and UDim2.fromScale(0.5, 0.42) or m.Button.Position,
			Size = UDim2.fromOffset(24, 24),
			ZIndex = 45,
			Visible = false,
		})
		m.Button.Activated:Connect(function()
			selected = id
			refresh()
		end)
		markers[id] = m
	end

	---------------------------------------------------------- a ilha escolhida (direita)
	local side = Kit.Box(body, { Position = UDim2.fromScale(0.6, 0.12), Size = UDim2.fromScale(0.4, 0.88) }, C.Panel)
	local bigIcon = Icons.Make(side, nil, {
		Position = UDim2.fromScale(0.04, 0.03),
		Size = UDim2.fromScale(0.17, 0.17),
		SizeConstraint = Enum.SizeConstraint.RelativeXX,
		ZIndex = 3,
	})
	local title = Kit.Text(side, {
		Position = UDim2.fromScale(0.25, 0.035),
		Size = UDim2.fromScale(0.72, 0.075),
		Text = "",
		Font = Kit.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	})
	local sub = Kit.Text(side, {
		Position = UDim2.fromScale(0.25, 0.11),
		Size = UDim2.fromScale(0.72, 0.05),
		Text = "",
		TextColor3 = C.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	})
	local info = Kit.Split(side, { Position = UDim2.fromScale(0.05, 0.19), Size = UDim2.fromScale(0.9, 0.055), ZIndex = 3 }, 2)
	local info2 = Kit.Split(side, { Position = UDim2.fromScale(0.05, 0.255), Size = UDim2.fromScale(0.9, 0.055), ZIndex = 3 }, 1)
	local listTitle = Kit.Text(side, {
		Position = UDim2.fromScale(0.05, 0.335),
		Size = UDim2.fromScale(0.9, 0.06),
		Text = "",
		Font = Kit.Title,
		TextColor3 = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	})
	local rows = {}
	for i = 1, 5 do
		local row = Kit.Box(side, {
			Position = UDim2.fromScale(0.05, 0.405 + (i - 1) * 0.085),
			Size = UDim2.fromScale(0.9, 0.075),
			ZIndex = 3,
		}, C.Panel2)
		local text = Kit.Text(row, {
			Position = UDim2.fromScale(0.03, 0.12),
			Size = UDim2.fromScale(0.94, 0.76),
			Text = "",
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 4,
		})
		rows[i] = { Row = row, Text = text }
	end
	local action = Kit.Button(side, {
		Name = "MapAction",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromScale(0.86, 0.12),
		Text = "GO",
		ZIndex = 4,
	}, C.Green)

	local function requirementsOf(id)
		local p = Net.Profile
		if not p or opened(id) then
			return {}, false
		end
		return Islands.Requirements(p, id, Islands.EquippedLevel(p))
	end

	-- primeira ilha ainda fechada (a "fronteira" da aventura)
	local function frontier()
		for _, id in ipairs(Islands.ORDER) do
			if not opened(id) then
				return id
			end
		end
		return nil
	end

	local highlight = nil
	function refresh()
		local p = Net.Profile
		local mode = player:GetAttribute("ArenaMode") or "off"
		if workspace:GetAttribute("SuperBossAwake") then
			bossText.Text = "🌍 SUPER BOSS IS AWAKE! Team up in the Colosseum!  " .. clock(workspace:GetAttribute("SuperBossLeft"))
			bossText.TextColor3 = C.Red
			pvpText.Text = "🛡️ PvP paused (Super Boss)"
			pvpText.TextColor3 = C.Gold
		else
			bossText.Text = "😴 Super Boss wakes up in " .. clock(workspace:GetAttribute("SuperBossIn")) .. "  (stays 10 min)"
			bossText.TextColor3 = C.Gold
			pvpText.Text = mode == "pvp" and "⚔️ YOU ARE IN PvP!" or "⚔️ PvP: ON inside the Colosseum"
			pvpText.TextColor3 = C.Red
		end
		local here = player:GetAttribute("Island")
		local front = frontier()
		selected = selected or (Islands.List[here or ""] and here) or front or "main"

		-- nomes, cadeados, anel da escolhida e rotas no mapa
		for id, m in pairs(markers) do
			local isOpen = opened(id)
			local def = Islands.List[id]
			if m.Locked ~= not isOpen then
				m.Locked = not isOpen
				Kit.LeadIcon(m.Name, m.Locked and "lock" or nil)
			end
			m.Here.Visible = here == id
			local chosen = selected == id or highlight == id
			if id == Village.Id then
				m.Ring.Color = chosen and C.Gold or Kit.INK
				m.Ring.Thickness = chosen and 4 or 3
			else
				m.Ring.Transparency = chosen and 0 or 1
			end
			m.Name.TextColor3 = isOpen and C.Text or (id == front and C.Gold or C.Muted)
			if def and routes[id] then
				local dotColor = isOpen and C.Gold or (id == front and Color3.new(1, 1, 1) or Color3.fromRGB(120, 120, 140))
				for _, d in ipairs(routes[id]) do
					d.BackgroundColor3 = dotColor
				end
			end
		end

		-- a ilha escolhida
		local id = selected
		local def = Islands.List[id]
		local extra = EXTRA[id]
		local color = extra and extra.Color or Islands.COLORS[id] or C.Text
		Icons.Set(bigIcon, ICON[id] or "island")
		title.Text = extra and extra.Name or def.Name
		title.TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.35)
		if def then
			local egg = def.Egg and DogData.Eggs[def.Egg]
			local rarity = Config.RARITY[def.Rarity]
			sub.Text = (def.Rarity == "Sky" and "Flying dogs only" or (rarity and (rarity.Label .. " dogs") or "")) .. "  ·  Lv." .. def.Levels[1] .. "-" .. def.Levels[2]
			info.Set({
				-- (🥚 2026-10-25: sem ovos o pedestal da ilha é a loja de coleiras)
				(egg and not Config.EGGS) and { Icon = "leash", Text = "Leash shop" }
					or egg and { Icon = Kit.EggIcon(def.Egg), Text = egg.Name }
					or { Icon = "sun", Text = "Sunfire shrine" },
				{ Icon = "crown", Text = def.Champion and def.Champion.Name or "Champion" },
			})
			local champs = p and type(p.Champions) == "table" and tonumber(p.Champions[id]) or 0
			local quests = p and type(p.IslandQuests) == "table" and tonumber(p.IslandQuests[id]) or 0
			info2.Set({
				{
					Icon = "scroll",
					Text = quests .. " missions done here  ·  champion " .. (champs > 0 and "beaten" or "not beaten yet"),
					Color = C.Muted,
				},
			})
		else
			sub.Text = extra.Sub
			info.Set({})
			info2.Set({})
		end

		local list, ready = requirementsOf(id)
		local isOpen = opened(id)
		-- ilha aberta que leva à próxima fechada: a lista mostra o que fazer AQUI para abrir a próxima
		local nextId = nil
		if isOpen and front and Islands.List[front].Requires == id then
			nextId = front
			list = requirementsOf(front)
		end
		for i, row in ipairs(rows) do
			local r = list[i]
			row.Row.Visible = r ~= nil
			if r then
				row.Text.Text = reqText(r)
				row.Text.TextColor3 = r.Done and C.Cash or C.Text
				Kit.LeadIcon(row.Text, r.Done and "check" or REQ_ICON[r.Kind])
				row.Row.BackgroundColor3 = r.Done and Color3.fromRGB(60, 120, 90) or C.Panel2
			end
		end
		if isOpen then
			if nextId then
				listTitle.Text = "NEXT: " .. string.upper(Islands.List[nextId].Name) .. " NEEDS"
				listTitle.TextColor3 = C.Gold
			else
				listTitle.Text = here == id and "YOU ARE HERE" or "OPEN"
				listTitle.TextColor3 = here == id and C.Gold or C.Cash
			end
			action.Text = here == id and "YOU ARE HERE" or (id == "main" and "GO HOME" or "GO")
			Kit.SetButtonColor(action, here == id and C.Disabled or C.Green)
		elseif ready then
			listTitle.Text = "READY TO OPEN!"
			listTitle.TextColor3 = C.Gold
			action.Text = "UNLOCK  $" .. Config.Format(def.Price or 0)
			Kit.SetButtonColor(action, C.Gold)
		else
			local missing = 0
			for _, r in ipairs(list) do
				if not r.Done then
					missing += 1
				end
			end
			listTitle.Text = "TO OPEN IT (" .. missing .. " LEFT):"
			listTitle.TextColor3 = C.Gold
			action.Text = "🔒 LOCKED"
			Kit.SetButtonColor(action, C.Locked)
		end
	end

	action.Activated:Connect(function()
		local id = selected
		if not id then
			return
		end
		if opened(id) then
			if player:GetAttribute("Island") == id then
				return
			end
			local ok, msg = Net.Invoke("IslandAction", "travel", id)
			HUD.Toast(msg or "", ok and "green" or "red")
			if ok then
				HUD.CloseAll()
			end
			return
		end
		local list, ready = requirementsOf(id)
		if ready then
			local ok, msg = Net.Invoke("IslandAction", "unlock", id)
			HUD.Toast(msg or "", ok and "gold" or "red")
			return
		end
		for _, r in ipairs(list) do
			if not r.Done then
				HUD.Toast("🔒 " .. reqText(r), "red")
				break
			end
		end
		Kit.Shake(side)
	end)

	Net.Changed.Event:Connect(function()
		if menu.Open then
			refresh()
		end
	end)
	for _, attr in ipairs({ "ArenaMode", "Island" }) do
		player:GetAttributeChangedSignal(attr):Connect(function()
			if menu.Open then
				refresh()
			end
		end)
	end
	task.spawn(function()
		while true do
			task.wait(1)
			if menu.Open then
				refresh()
			end
		end
	end)

	HUD.RegisterMenu("Map", {
		Open = function()
			selected = nil
			refresh()
			menu.Show(true)
		end,
		Close = function()
			menu.Show(false)
			highlight = nil
		end,
	})

	-- portal trancado / ilha aberta (IslandService)
	local remote = Net.Remotes:WaitForChild("IslandEvent", 30)
	if remote then
		remote.OnClientEvent:Connect(function(kind, id)
			local def = Islands.List[id]
			if not def then
				return
			end
			if kind == "locked" then
				HUD.Toast("🔒 " .. def.Name .. " is locked — see what it needs in the MAP!", "red")
				highlight = id
				if not menu.Open then
					HUD.Toggle("Map")
				end
				selected = id
				refresh()
				if markers[id] then
					Kit.Shake(markers[id].Button)
				end
			elseif kind == "unlocked" then
				HUD.Toast("🏝️ " .. def.Name .. " UNLOCKED! Step into its portal!", "gold")
				if markers[id] then
					Kit.Burst(side, UDim2.fromScale(0.5, 0.5), C.Gold, 14)
				end
				refresh()
			end
		end)
	end
end

return MapMenu
