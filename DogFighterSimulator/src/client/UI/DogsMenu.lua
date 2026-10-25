-- Tela 🐶 DOGS com duas abas:
--   🐶 MEUS: grade de cards (raridade, estrelas de evolução, level, power, comparação ↑↓ com o equipado)
--            + detalhe com cachorro 3D, XP, atributos, Special e Equipar / Favorito / Renomear / Libertar.
--   📖 ÍNDICE: todas as espécies de DogData.Order por raridade. Descobertas aparecem coloridas com nome e
--            Special; as outras ficam "???" em silhueta. Contador "X/N descobertos".
-- Desempenho: só UM visualizador 3D (o grande do detalhe), reaproveitado nas duas abas.
-- (2026-10-25) ✨ SHINY / 🥇 GOLD / 🌈 RAINBOW aparecem pintados nos cards e no palco (Shared/Variants), com selo e
-- borda brilhando; botão 🧬 EVOLVE no detalhe (3 iguais → 1 GOLD, 3 GOLD → 1 RAINBOW: Services/EvolveService); o
-- 📖 ÍNDICE mostra os 📖 prêmios do Dex no topo (Shared/DexRewards) e o exclusivo do 🎟️ Passe de Temporada.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Islands = require(ReplicatedStorage.Shared.Islands)
local DogData = require(ReplicatedStorage.Shared.DogData)
local Variants = require(ReplicatedStorage.Shared.Variants)
local DexRewards = require(ReplicatedStorage.Shared.DexRewards)
local Kit = require(script.Parent.Kit)
local Icons = require(script.Parent.Icons)
local Net = require(script.Parent.Parent.Net)

local DogsMenu = {}
local make = Kit.make
local C = Kit.C
local player = Players.LocalPlayer
local AnyConfig: any = Config

local SORTS = {
	{ Id = "power", Label = "💪 Power" },
	{ Id = "level", Label = "⭐ Level" },
	{ Id = "rarity", Label = "💎 Rarity" },
	{ Id = "new", Label = "🆕 Newest" },
}

-- Campos do perfil que podem guardar as espécies já descobertas (mapa id->true ou lista de ids)
local DEX_FIELDS = { "Discovered", "Dex", "Seen", "Collection", "Found", "Index" }
local sessionSeen = {} -- espécies vistas nesta sessão (caso o perfil ainda não tenha campo de descobertas)

-- (2026-10) habilidades do cachorro: tecla 2 · tecla 3 · Supremo (Épico para cima), cada uma com o SEU ícone desenhado
-- level = nível do cachorro (nil no catálogo): poder ainda travado fica cinza com o nível que libera (Config.POWER_UNLOCK)
local function powerLine(speciesId, level)
	local pw = DogData.PowersFor(speciesId)
	local items = {}
	for index = 1, 3 do
		local id = pw[index]
		if id then
			local info = DogData.Specials[id]
			local name = info and info.Name or id
			name = (name:gsub("^SUPREME%s+", ""))
			local need = Config.PowerUnlockLevel(index)
			local locked = level ~= nil and level < need
			table.insert(items, {
				Icon = locked and "lock" or (index == 3 and "crown" or Icons.ForPower(id, info)),
				Text = locked and (name .. " Lv." .. need) or name,
				Color = locked and C.Disabled or Color3.fromRGB(230, 200, 255),
			})
		end
	end
	return items, pw
end

-- elementos contra quem o cachorro é forte / fraco (mesma conta do DogData.StrongWeakLabel), como ícones
local function matchIcons(speciesId)
	local strongText, weakText = DogData.StrongWeakLabel(speciesId)
	local function toIcons(text)
		local out = {}
		for _, e in ipairs(DogData.DOG_ELEMENT_ORDER) do
			if string.find(text, DogData.DOG_ELEMENTS[e].Icon, 1, true) then
				table.insert(out, Kit.ElementIcon(e))
			end
		end
		return out
	end
	return toIcons(strongText), toIcons(weakText)
end

local function rarityOrder(dog)
	return Config.RARITY[DogData.Species[dog.Species].Rarity].Order
end

local function hex(color)
	return "#" .. color:ToHex()
end

-- Estrelas de evolução (campo Stars do cachorro; 0/ausente = nenhuma)
local function maxStars()
	local levels = AnyConfig.STAR_LEVELS
	if type(levels) == "table" and #levels > 0 then
		return #levels
	end
	return tonumber(AnyConfig.MAX_STARS) or 5
end

local function starsOf(dog)
	local stars = tonumber(dog and dog.Stars)
	if not stars and dog and type(AnyConfig.StarsFor) == "function" then
		stars = AnyConfig.StarsFor(dog.Level or 1)
	end
	return math.max(0, math.floor(stars or 0))
end

local function starsRich(stars, total)
	if total <= 0 then
		return ""
	end
	return '<font color="'
		.. hex(C.Gold)
		.. '">'
		.. string.rep("★", math.min(stars, total))
		.. "</font>"
		.. '<font color="#5A5470">'
		.. string.rep("★", math.max(0, total - stars))
		.. "</font>"
end

-- Modelo do meu cachorro no mundo (para o atributo Recovering)
local function myModel()
	local folder = workspace:FindFirstChild("Cachorros")
	if not folder then
		return nil
	end
	for _, model in ipairs(folder:GetChildren()) do
		if model:GetAttribute("Owner") == player.UserId and model:GetAttribute("Kind") == "player" then
			return model
		end
	end
	return nil
end

-- Estado de recuperação de um cachorro. Retorna texto curto ou nil.
local function recoveryText(dog, equipped)
	local value = dog and (dog.Recovering or dog.RecoverUntil)
	if equipped then
		local model = myModel()
		local attr = model and model:GetAttribute("Recovering")
		if attr ~= nil and attr ~= false then
			value = attr
		elseif player:GetAttribute("DogState") == "ko" then
			return "😵 FAINTED"
		end
	end
	if value == nil or value == false or value == 0 then
		return nil
	end
	if type(value) == "number" then
		local now = workspace:GetServerTimeNow()
		if value > 1e6 then
			if value <= now then
				return nil
			end
			return "🩹 RECOVERING " .. Config.FormatTime(value - now)
		elseif value > 0 and value < 1 then
			return "🩹 RECOVERING " .. math.floor(value * 100) .. "%"
		end
	end
	return "🩹 RECOVERING"
end

local function discoveredSet(p)
	local set = {}
	if p then
		for _, field in ipairs(DEX_FIELDS) do
			local t = p[field]
			if type(t) == "table" then
				for k, v in pairs(t) do
					if type(k) == "string" and v then
						set[k] = true
					elseif type(v) == "string" then
						set[v] = true
					end
				end
			end
		end
		for _, dog in pairs(p.Dogs or {}) do
			set[dog.Species] = true
		end
	end
	for id in pairs(sessionSeen) do
		set[id] = true
	end
	return set
end

-- Espécies do índice (sem as exclusivas de boss), agrupadas por raridade
local function dexSpecies()
	local groups, total = {}, 0
	for _, rarityId in ipairs(Config.RARITIES) do
		groups[rarityId] = {}
	end
	for _, id in ipairs(DogData.Order) do
		local species = DogData.Species[id]
		if species and not species.BossOnly and groups[species.Rarity] then
			table.insert(groups[species.Rarity], id)
			total += 1
		end
	end
	return groups, total
end

-- 🦮 (2026-10-25, sem ovos) onde capturar: ilhas com selvagens desta espécie (Halloween/Divino só na roleta)
local FLY_RARITIES = { Uncommon = true, Rare = true, Epic = true, Legendary = true, Mythic = true } -- (= NPCService)
local function wildFor(speciesId)
	local species = DogData.Species[speciesId]
	local list = {}
	for _, def in pairs(Islands.List) do
		local here
		if def.Flyers then
			here = FLY_RARITIES[species.Rarity] == true and table.find(DogData.SpeciesWithElement(species.Rarity, "Fly"), speciesId) ~= nil
		else
			here = (def.Golden and "Mythic" or def.Rarity) == species.Rarity
		end
		if here and not species.BossOnly then
			table.insert(list, def)
		end
	end
	if #list == 0 then
		return nil
	end
	table.sort(list, function(a, b)
		return (a.Price or 0) < (b.Price or 0)
	end)
	local names = {}
	for _, def in ipairs(list) do
		table.insert(names, def.Name)
	end
	return table.concat(names, ", ")
end

local function eggsFor(rarityId)
	if rarityId == "Divine" then
		return "☀️ Robux Shop (never from eggs)"
	end
	local names = {}
	local ids = {}
	for id, egg in pairs(DogData.Eggs) do
		if egg.Odds[rarityId] then
			table.insert(ids, id)
		end
	end
	table.sort(ids, function(a, b)
		return (DogData.Eggs[a].Odds[rarityId] or 0) > (DogData.Eggs[b].Odds[rarityId] or 0)
	end)
	for i = 1, math.min(3, #ids) do
		table.insert(names, DogData.Eggs[ids[i]].Name)
	end
	return table.concat(names, ", ")
end

function DogsMenu.Start(HUD)
	local menu = Kit.Menu({
		Name = "DogsMenu",
		Title = "🐶 MY DOGS",
		Color = C.Blue,
		Width = 1040,
		Height = 600,
		HeaderHeight = 0.1,
		OnClose = function()
			HUD.CloseAll()
		end,
	})
	local frame, body = menu.Frame, menu.Body
	local headerTitle = nil
	for _, c in ipairs(menu.Header:GetChildren()) do
		if c:IsA("TextLabel") then
			headerTitle = c
		end
	end

	local LEFT_W = 0.57
	---------------------------------------------------------- abas + filtros
	local tab = "mine" -- "mine" | "dex"
	local onlyFav = false
	local rarityFilter = 0 -- 0 = todas, senão índice em Config.RARITIES
	local sortIndex = 1

	local tabMine = Kit.Button(body, { Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(0.175, 0.085), Text = "🐶 MY DOGS" }, C.Blue)
	local tabDex = Kit.Button(body, { Position = UDim2.fromScale(0.185, 0), Size = UDim2.fromScale(0.175, 0.085), Text = "📖 INDEX" }, C.Panel2)
	local badgeDex = Kit.Badge(tabDex, C.Red)
	-- (estreito: o ícone desenhado da ponta fica colado no número)
	local countText = Kit.Text(body, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(LEFT_W, 0.012),
		Size = UDim2.fromScale(0.105, 0.065),
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "",
	})

	local favToggle = Kit.Button(body, { Position = UDim2.fromScale(0, 0.1), Size = UDim2.fromScale(0.12, 0.07), Text = "☆ Fav" }, C.Panel2)
	local rarityButton = Kit.Button(body, { Position = UDim2.fromScale(0.13, 0.1), Size = UDim2.fromScale(0.16, 0.07), Text = "💎 All" }, C.Panel2)
	local sortButton = Kit.Button(body, { Position = UDim2.fromScale(0.3, 0.1), Size = UDim2.fromScale(0.16, 0.07), Text = SORTS[1].Label }, C.Panel2)
	local sellButton = Kit.Button(body, { Position = UDim2.fromScale(0.47, 0.1), Size = UDim2.fromScale(0.1, 0.07), Text = "💰 SELL" }, C.Green)

	---------------------------------------------------------- 💰 venda em massa (janela por cima)
	local SELL_RARITIES = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }
	local sellPick = { Common = true }
	local keepBest = true
	local sellPanel = Kit.Box(menu.Frame, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromScale(0.56, 0.62),
		Visible = false,
		ZIndex = 30,
	}, C.Bg)
	Kit.Text(sellPanel, { Position = UDim2.fromScale(0.05, 0.04), Size = UDim2.fromScale(0.9, 0.12), Text = "💰 QUICK SELL", TextColor3 = C.Gold, ZIndex = 31 })
	local sellButtons = {}
	local keepButton
	local sellInfo = Kit.Text(sellPanel, { Position = UDim2.fromScale(0.05, 0.645), Size = UDim2.fromScale(0.9, 0.08), Text = "", TextColor3 = C.Cash, ZIndex = 31 })
	local sellPreview = { Count = 0, Cash = 0 }
	local function refreshSell()
		for rarityId, b in pairs(sellButtons) do
			local r = Config.RARITY[rarityId]
			b.Text = (sellPick[rarityId] and "✔ " or "") .. r.Label
			Kit.SetButtonColor(b, sellPick[rarityId] and r.Color:Lerp(C.Dark, 0.25) or C.Disabled)
		end
		keepButton.Text = (keepBest and "✔ " or "") .. "Keep best of each dog"
		Kit.SetButtonColor(keepButton, keepBest and C.Blue or C.Disabled)
		sellInfo.Text = "..."
		task.spawn(function()
			local ok, result = Net.Invoke("SellDogs", "preview", sellPick, keepBest)
			if ok and type(result) == "table" then
				local n, cash = result.Count, result.Cash
				sellPreview.Count, sellPreview.Cash = n, cash
				sellInfo.Text = n > 0 and ("🐶 ×" .. n .. "   →   💵 +$" .. Config.Format(cash)) or "Nothing to sell 👍"
			end
		end)
	end
	for i, rarityId in ipairs(SELL_RARITIES) do
		local col = (i - 1) % 2
		local row = math.floor((i - 1) / 2)
		sellButtons[rarityId] = Kit.Button(sellPanel, {
			Position = UDim2.fromScale(0.06 + col * 0.45, 0.17 + row * 0.11),
			Size = UDim2.fromScale(0.43, 0.095),
			Text = "",
			ZIndex = 31,
		}, C.Disabled, function()
			sellPick[rarityId] = not sellPick[rarityId] or nil
			refreshSell()
		end)
	end
	keepButton = Kit.Button(sellPanel, { Position = UDim2.fromScale(0.06, 0.505), Size = UDim2.fromScale(0.88, 0.09), Text = "", ZIndex = 31 }, C.Blue, function()
		keepBest = not keepBest
		refreshSell()
	end)
	Kit.Text(sellPanel, {
		Position = UDim2.fromScale(0.05, 0.6),
		Size = UDim2.fromScale(0.9, 0.045),
		Text = "Legendary & Mythic: only repeats (best one is kept)",
		TextColor3 = C.Gold,
		ZIndex = 31,
	})
	Kit.Text(sellPanel, {
		Position = UDim2.fromScale(0.05, 0.73),
		Size = UDim2.fromScale(0.9, 0.06),
		Text = "⭐ favorites and your equipped dog are never sold",
		TextColor3 = C.Muted,
		ZIndex = 31,
	})
	Kit.Button(sellPanel, { Position = UDim2.fromScale(0.06, 0.82), Size = UDim2.fromScale(0.42, 0.13), Text = "CANCEL", ZIndex = 31 }, C.Panel2, function()
		sellPanel.Visible = false
	end)
	local confirmSell = Kit.Button(sellPanel, { Position = UDim2.fromScale(0.52, 0.82), Size = UDim2.fromScale(0.42, 0.13), Text = "💰 SELL", ZIndex = 31 }, C.Green)
	local sellBusy = false
	confirmSell.Activated:Connect(function()
		if sellBusy or sellPreview.Count == 0 then
			return
		end
		sellBusy = true
		local ok, result = Net.Invoke("SellDogs", "sell", sellPick, keepBest)
		sellBusy = false
		if ok and type(result) == "table" then
			HUD.Toast("💰 Sold " .. result.Count .. " dogs  +$" .. Config.Format(result.Cash), "gold")
			sellPanel.Visible = false
		else
			HUD.Toast(type(result) == "string" and result or "Couldn't sell", "red")
		end
	end)
	sellButton.Activated:Connect(function()
		sellPanel.Visible = not sellPanel.Visible
		if sellPanel.Visible then
			refreshSell()
		end
	end)

	local dexBar = Kit.Bar(body, { Position = UDim2.fromScale(0.3, 0.108), Size = UDim2.fromScale(LEFT_W - 0.3, 0.055), Visible = false }, C.Gold)

	---------------------------------------------------------- lista (cards ou índice)
	local list = make("ScrollingFrame", {
		Position = UDim2.fromScale(0, 0.185),
		Size = UDim2.fromScale(LEFT_W, 0.815),
		BackgroundColor3 = C.Panel,
		BorderSizePixel = 0,
		ScrollBarThickness = 12,
		ScrollBarImageColor3 = C.Muted,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, body)
	Kit.Corner(list, 14)
	Kit.Stroke(list, C.Dark, 2)
	make("UIPadding", {
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 20),
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 12),
	}, list)
	local mineGrid = make("Frame", { Name = "Mine", Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, list)
	make("UIGridLayout", {
		CellSize = UDim2.new(0.315, 0, 0, 196),
		CellPadding = UDim2.new(0.0275, 0, 0, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, mineGrid)
	local dexHolder = make("Frame", {
		Name = "Dex",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = false,
	}, list)
	make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, dexHolder)

	local emptyText = Kit.Text(body, {
		Position = UDim2.fromScale(0.03, 0.42),
		Size = UDim2.fromScale(LEFT_W - 0.06, 0.07),
		Text = "",
		TextColor3 = C.Muted,
		Visible = false,
		ZIndex = 5,
	})

	---------------------------------------------------------- detalhe (direita)
	local detail = Kit.Box(body, { Position = UDim2.fromScale(LEFT_W + 0.015, 0), Size = UDim2.fromScale(1 - LEFT_W - 0.015, 1) })
	local stage = make("Frame", {
		Position = UDim2.fromScale(0.03, 0.02),
		Size = UDim2.fromScale(0.94, 0.42),
		BackgroundColor3 = C.Panel2,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, detail)
	Kit.Corner(stage, 14)
	Kit.Gradient(stage, Color3.new(1, 1, 1), Color3.fromRGB(110, 100, 150))
	local stageStroke = nil
	local view = Kit.DogViewport(stage, { Size = UDim2.fromScale(1, 1), ZIndex = 2 })
	view.Walk = false
	local rarityChip, rarityChipText = Kit.Chip(stage, {
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.fromScale(0.38, 0.14),
		ZIndex = 3,
	}, C.Panel2, "")
	rarityChipText.ZIndex = 4
	local levelChip, levelChipText = Kit.Chip(stage, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromScale(0.26, 0.14),
		ZIndex = 3,
	}, C.Gold, "")
	levelChipText.ZIndex = 4
	-- (estrelas no alto, entre o chip de raridade e o de level: o lado direito fica para FORTE/FRACO)
	local starsLabel = Kit.Text(stage, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.56, 0, 0, 10),
		Size = UDim2.fromScale(0.3, 0.12),
		RichText = true,
		Text = "",
		ZIndex = 4,
	})
	local statusChip, statusChipText = Kit.Chip(stage, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.fromScale(0.62, 0.14),
		ZIndex = 3,
		Visible = false,
	}, C.Green, "")
	statusChipText.ZIndex = 4
	-- 🌈 elementos do cachorro (embaixo do chip de raridade) e contra quem ele é forte/fraco (direita)
	local elementIcons = Kit.IconList(stage, { Position = UDim2.new(0, 10, 0.18, 0), Size = UDim2.fromScale(0.4, 0.14), ZIndex = 4 })
	local strongIcons = Kit.IconList(stage, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0.18, 0),
		Size = UDim2.fromScale(0.5, 0.09),
		ZIndex = 4,
	}, Enum.HorizontalAlignment.Right, "STRONG", Color3.fromRGB(140, 255, 140))
	local weakIcons = Kit.IconList(stage, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0.285, 0),
		Size = UDim2.fromScale(0.5, 0.09),
		ZIndex = 4,
	}, Enum.HorizontalAlignment.Right, "WEAK", Color3.fromRGB(255, 140, 140))

	-- informações do cachorro (aba MEUS)
	local mineInfo = make("Frame", { Position = UDim2.fromScale(0, 0.45), Size = UDim2.fromScale(1, 0.55), BackgroundTransparency = 1 }, detail)
	local title = Kit.Text(mineInfo, { Position = UDim2.fromScale(0.04, 0), Size = UDim2.fromScale(0.92, 0.13), Text = "" })
	local sub = Kit.Text(mineInfo, {
		Position = UDim2.fromScale(0.04, 0.135),
		Size = UDim2.fromScale(0.92, 0.08),
		Text = "",
		TextColor3 = C.Muted,
	})
	local xpBar = Kit.Bar(mineInfo, { Position = UDim2.fromScale(0.04, 0.235), Size = UDim2.fromScale(0.92, 0.085) }, C.XP)
	local power = Kit.Text(mineInfo, {
		Position = UDim2.fromScale(0.04, 0.34),
		Size = UDim2.fromScale(0.46, 0.1),
		Text = "",
		TextColor3 = C.Orange,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local compare = Kit.Text(mineInfo, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(0.96, 0.35),
		Size = UDim2.fromScale(0.48, 0.08),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	local stats = Kit.Split(mineInfo, { Position = UDim2.fromScale(0.04, 0.455), Size = UDim2.fromScale(0.92, 0.075) }, 4)
	local specialBox = Kit.Box(mineInfo, { Position = UDim2.fromScale(0.04, 0.55), Size = UDim2.fromScale(0.92, 0.22) }, Color3.fromRGB(80, 60, 120))
	local special = Kit.Split(specialBox, { Position = UDim2.fromScale(0.03, 0.08), Size = UDim2.fromScale(0.94, 0.4) }, 3, { Font = Kit.Title })
	local specialDesc = Kit.Text(specialBox, {
		Position = UDim2.fromScale(0.03, 0.52),
		Size = UDim2.fromScale(0.94, 0.42),
		Text = "",
		TextColor3 = C.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	-- (2026-10: sem o TIME que rende — Config.HOUSES = false — o EQUIP fica maior no lugar do botão TEAM)
	local equipButton = Kit.Button(mineInfo, {
		Name = "TutEquip",
		Position = UDim2.fromScale(0.04, 0.8),
		Size = UDim2.fromScale(Config.HOUSES and 0.27 or 0.25, 0.18),
		Text = "EQUIP",
	}, C.Green)
	-- 🧬 EVOLVE (2026-10-25): no lugar do TIME (que só existe com casinha)
	local evolveButton = Kit.Button(mineInfo, { Name = "Evolve", Position = UDim2.fromScale(0.3, 0.8), Size = UDim2.fromScale(0.23, 0.18), Text = "🧬 EVOLVE" }, C.Purple)
	evolveButton.Visible = not Config.HOUSES
	local teamButton = Kit.Button(mineInfo, { Name = "TutTeam", Position = UDim2.fromScale(0.33, 0.8), Size = UDim2.fromScale(0.2, 0.18), Text = "💵 TEAM" }, C.Cash)
	teamButton.Visible = Config.HOUSES
	local favButton = Kit.Button(mineInfo, { Position = UDim2.fromScale(0.55, 0.8), Size = UDim2.fromScale(0.12, 0.18), Text = "☆" }, C.Gold)
	local renameButton = Kit.Button(mineInfo, { Position = UDim2.fromScale(0.69, 0.8), Size = UDim2.fromScale(0.12, 0.18), Text = "✏️" }, C.Blue)
	local releaseButton = Kit.Button(mineInfo, { Position = UDim2.fromScale(0.83, 0.8), Size = UDim2.fromScale(0.13, 0.18), Text = "🕊️" }, C.Red)

	-- informações da espécie (aba ÍNDICE)
	local dexInfo = make("Frame", { Position = UDim2.fromScale(0, 0.45), Size = UDim2.fromScale(1, 0.55), BackgroundTransparency = 1, Visible = false }, detail)
	local dexTitle = Kit.Text(dexInfo, { Position = UDim2.fromScale(0.04, 0), Size = UDim2.fromScale(0.92, 0.13), Text = "" })
	local dexSub = Kit.Text(dexInfo, { Position = UDim2.fromScale(0.04, 0.135), Size = UDim2.fromScale(0.92, 0.08), Text = "", TextColor3 = C.Muted })
	local dexStats = Kit.Split(dexInfo, { Position = UDim2.fromScale(0.04, 0.24), Size = UDim2.fromScale(0.92, 0.08) }, 4)
	local dexSpecialBox = Kit.Box(dexInfo, { Position = UDim2.fromScale(0.04, 0.34), Size = UDim2.fromScale(0.92, 0.24) }, Color3.fromRGB(80, 60, 120))
	local dexSpecial = Kit.Split(dexSpecialBox, { Position = UDim2.fromScale(0.03, 0.08), Size = UDim2.fromScale(0.94, 0.4) }, 3, { Font = Kit.Title })
	local dexSpecialDesc = Kit.Text(dexSpecialBox, {
		Position = UDim2.fromScale(0.03, 0.52),
		Size = UDim2.fromScale(0.94, 0.42),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local dexOwned = Kit.Text(dexInfo, {
		Position = UDim2.fromScale(0.04, 0.62),
		Size = UDim2.fromScale(0.92, 0.08),
		Text = "",
		TextColor3 = C.Green,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local dexEggs = Kit.Box(dexInfo, { Position = UDim2.fromScale(0.04, 0.74), Size = UDim2.fromScale(0.92, 0.22) }, C.Panel2)
	local dexEggsText = Kit.Text(dexEggs, {
		Position = UDim2.fromScale(0.04, 0.1),
		Size = UDim2.fromScale(0.92, 0.8),
		Text = "",
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	---------------------------------------------------------- caixa de renomear
	local renameShade = make("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Selectable = false,
		BackgroundColor3 = C.Dark,
		BackgroundTransparency = 0.4,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 20,
	}, frame)
	Kit.Corner(renameShade, 20)
	local renameBox = Kit.Panel(renameShade, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.46, 0.4),
		ZIndex = 21,
	})
	Kit.Text(renameBox, { Position = UDim2.fromScale(0.05, 0.06), Size = UDim2.fromScale(0.9, 0.2), Text = "✏️ New name", ZIndex = 22 })
	local input = make("TextBox", {
		Position = UDim2.fromScale(0.08, 0.32),
		Size = UDim2.fromScale(0.84, 0.25),
		Font = Kit.Font,
		TextScaled = true,
		Text = "",
		PlaceholderText = "Popcorn",
		BackgroundColor3 = Color3.fromRGB(245, 245, 250),
		TextColor3 = Color3.fromRGB(30, 25, 40),
		ClearTextOnFocus = false,
		ZIndex = 22,
	}, renameBox)
	Kit.Corner(input, 10)
	Kit.Stroke(input, C.Dark, 3)
	make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0.1, 0), PaddingBottom = UDim.new(0.1, 0) }, input)
	local renameOk = Kit.Button(renameBox, { Position = UDim2.fromScale(0.08, 0.66), Size = UDim2.fromScale(0.4, 0.24), Text = "OK ✔", ZIndex = 22 }, C.Green)
	Kit.Button(renameBox, { Position = UDim2.fromScale(0.52, 0.66), Size = UDim2.fromScale(0.4, 0.24), Text = "Cancel", ZIndex = 22 }, C.Red, function()
		renameShade.Visible = false
	end)

	---------------------------------------------------------- estado
	local selected = nil -- id do cachorro (aba MEUS)
	local confirmEvolve = false
	local dexSelected = nil -- id da espécie (aba ÍNDICE)
	local confirmRelease = false
	local cards = {} -- [dogId] = { Select, Recover }
	local dexCells = {} -- [speciesId] = { Select }
	local lastSignature = nil
	local lastDexSignature = nil
	local knownDex = nil -- descobertas na última vez que o índice foi visto (para o "NEW")

	local function equippedPower()
		local eq = Net.Equipped()
		return eq and Net.Power(eq) or nil
	end

	-- palco 3D: espécie, cor da raridade e silhueta · variant = o cachorro do perfil (✨🥇🌈) · acc = acessórios
	local function setStage(speciesId, silhouette, variant, acc)
		local species = DogData.Species[speciesId]
		local rarity = Kit.Rarity(species.Rarity)
		local special = variant and Variants.IsSpecial(variant) and variant or nil
		local key = speciesId .. "|" .. Variants.Label(special, true) .. "|" .. (acc and table.concat({ acc.Hat or "", acc.Collar or "", acc.Glasses or "", acc.Cape or "" }, ",") or "")
		local changed = view.SpeciesId ~= key
		if changed then
			view.SpeciesId = key
			view.SetSpecies(speciesId, nil, special, acc)
			if stageStroke then
				stageStroke:Destroy()
			end
			stageStroke = Kit.RarityStroke(stage, species.Rarity, 4)
		end
		view.Frame.ImageColor3 = silhouette and Color3.new(0, 0, 0) or Color3.new(1, 1, 1)
		stage.BackgroundColor3 = silhouette and Color3.fromRGB(70, 64, 92) or rarity.Color:Lerp(C.Panel2, 0.45)
		Kit.SetButtonColor(rarityChip, (special and Variants.Color(special) or rarity.Color):Lerp(C.Dark, 0.2))
		rarityChipText.Text = special and (rarity.Label .. " · " .. Variants.Label(special, true)) or rarity.Label
		-- 🆚 elementos (ícones desenhados): os do cachorro e contra quais ele é forte (verde) / fraco (vermelho)
		local mine, strong, weak = {}, {}, {}
		if not silhouette then
			for _, e in ipairs(DogData.ElementsOf(speciesId)) do
				table.insert(mine, Kit.ElementIcon(e))
			end
			strong, weak = matchIcons(speciesId)
		end
		elementIcons.Set(mine)
		strongIcons.Set(strong)
		weakIcons.Set(weak)
		return changed
	end

	local function howl()
		view.SetAction("Howl")
		-- 🐶 (2026-10-25) e late/uiva com a voz do tamanho dele
		local module = script.Parent.Parent:FindFirstChild("Systems") and script.Parent.Parent.Systems:FindFirstChild("Sfx")
		if module and view.Model then
			pcall(function()
				local S = require(module)
				local name, pitch = S.VoiceFor(S.HeightOf(view.Model), math.random() < 0.3 and "howl" or "bark")
				S.Play(name, nil, { Pitch = pitch, Volume = 0.5, Gap = 0.3 })
			end)
		end
		task.delay(1.2, function()
			view.SetAction(nil)
		end)
	end

	local function showStatus(text, color)
		statusChip.Visible = text ~= nil
		if text then
			statusChipText.Text = text
			Kit.SetButtonColor(statusChip, color)
		end
	end

	---------------------------------------------------------- detalhe: MEUS
	local function showDetail(fresh)
		local p = Net.Profile
		local dog = p and selected and p.Dogs[selected]
		if not dog then
			local eq = Net.Equipped()
			selected = eq and eq.Id
			dog = eq
		end
		for id, c in pairs(cards) do
			c.Select.Visible = id == selected
		end
		if not dog then
			return
		end
		local species = DogData.Species[dog.Species]
		local st = Config.Stats(species, dog.Level, dog)
		local accOn = p.Equipped == dog.Id and type(p.Acc) == "table" and p.Acc.On or nil
		if setStage(dog.Species, false, dog, accOn) then
			fresh = true
		end
		if fresh then
			howl()
		end
		levelChip.Visible = true
		levelChipText.Text = "LV." .. dog.Level
		local stars = starsOf(dog)
		starsLabel.Text = starsRich(stars, math.max(stars, maxStars()))
		title.Text = string.upper(dog.Name)
		sub.Text = species.Name .. "  ·  " .. species.Role
		local maxed = dog.Level >= Config.MAX_LEVEL
		local need = Config.XPToNext(dog.Level)
		xpBar.Set(maxed and 1 or dog.XP / need, fresh)
		xpBar.Label.Text = maxed and "MAX LEVEL" or (Config.Format(dog.XP) .. " / " .. Config.Format(need) .. " XP")
		power.Text = "💪 " .. Config.Format(st.Power)
		local equipped = p.Equipped == dog.Id
		if equipped then
			compare.Text = "your fighter"
			compare.TextColor3 = C.Gold
		else
			local text, color = Kit.Compare(st.Power, equippedPower())
			compare.Text = text ~= "" and (text .. " vs equipped") or ""
			compare.TextColor3 = color
		end
		local statItems = {
			{ Icon = "heart", Text = Config.Format(st.MaxHP) },
			{ Icon = "sword", Text = Config.Format(st.Atk) },
			{ Icon = "wind", Text = tostring(st.Speed) },
		}
		if Config.HOUSES then
			table.insert(statItems, { Icon = "coins", Text = "$" .. Config.Format(math.floor(Config.TeamIncome(species, dog.Level))) .. "/min" })
		end
		stats.Set(statItems)
		local inTeam = table.find(p.Team or {}, dog.Id) ~= nil
		teamButton.Text = inTeam and "💵 IN TEAM ✔" or "💵 + TEAM"
		Kit.SetButtonColor(teamButton, inTeam and C.Disabled or C.Cash)
		-- habilidades 2, 3 e o Supremo (shared/Skills.lua: cada cachorro com as suas)
		local line, pw = powerLine(dog.Species, dog.Level)
		local sp2 = DogData.Specials[pw[1]]
		special.Set(line)
		specialDesc.Text = sp2 and sp2.Desc or ""
		local recovering = recoveryText(dog, equipped)
		if recovering then
			showStatus(recovering, C.Orange)
		elseif equipped then
			showStatus("✔ EQUIPPED", C.Green)
		else
			showStatus(nil)
		end
		equipButton.Text = equipped and "EQUIPPED ✔" or "EQUIP"
		Kit.SetButtonColor(equipButton, equipped and C.Disabled or C.Green)
		favButton.Text = dog.Fav and "★" or "☆"
		releaseButton.Visible = not equipped
		confirmRelease = false
		releaseButton.Text = "🕊️"
		Kit.SetButtonColor(releaseButton, C.Red)
		-- 🧬 quantos iguais (mesma espécie e versão) tem para evoluir
		confirmEvolve = false
		if Variants.CanEvolve(dog) then
			local list, have = Variants.EvolvePick(p.Dogs, dog.Id, nil)
			local next = Variants.TIERS[Variants.TierOf(dog) + 1]
			evolveButton.Text = "🧬 " .. next.Label .. " " .. math.min(have, Variants.EVOLVE_COUNT) .. "/" .. Variants.EVOLVE_COUNT
			Kit.SetButtonColor(evolveButton, list and (Variants.TierOf(dog) == 0 and C.Gold or C.Purple) or C.Disabled)
		else
			evolveButton.Text = "🌈 MAX"
			Kit.SetButtonColor(evolveButton, C.Disabled)
		end
	end

	local function sortedDogs()
		local p = Net.Profile
		local out = {}
		for _, dog in ipairs(Net.SortedDogs(onlyFav)) do
			local r = DogData.Species[dog.Species].Rarity
			if rarityFilter == 0 or Config.RARITIES[rarityFilter] == r then
				table.insert(out, dog)
			end
		end
		local mode = SORTS[sortIndex].Id
		local powers = {}
		for _, dog in ipairs(out) do
			powers[dog] = Net.Power(dog)
		end
		table.sort(out, function(a, b)
			if (a.Id == p.Equipped) ~= (b.Id == p.Equipped) then
				return a.Id == p.Equipped
			end
			if mode == "level" and a.Level ~= b.Level then
				return a.Level > b.Level
			elseif mode == "rarity" and rarityOrder(a) ~= rarityOrder(b) then
				return rarityOrder(a) > rarityOrder(b)
			elseif mode == "new" then
				return tonumber(a.Id) > tonumber(b.Id)
			end
			if powers[a] ~= powers[b] then
				return powers[a] > powers[b]
			end
			return tonumber(a.Id) < tonumber(b.Id)
		end)
		return out
	end

	local function selectionRing(parent, visible)
		local ring = make("Frame", {
			Name = "Selected",
			Position = UDim2.fromOffset(-5, -5),
			Size = UDim2.new(1, 10, 1, 10),
			BackgroundTransparency = 1,
			Visible = visible,
			ZIndex = 6,
		}, parent)
		Kit.Corner(ring, 18)
		Kit.Stroke(ring, Color3.new(1, 1, 1), 4)
		return ring
	end

	-- faixa colorida no topo do card (rótulo da raridade bem legível)
	local function rarityBand(card, rarityId, text)
		local rarity = Kit.Rarity(rarityId)
		local band = make("Frame", {
			Size = UDim2.new(1, 0, 0.145, 0),
			BackgroundColor3 = rarity.Color:Lerp(C.Dark, 0.15),
			BorderSizePixel = 0,
			ZIndex = 2,
		}, card)
		Kit.Corner(band, 14)
		local filler = make("Frame", {
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.fromScale(1, 0.5),
			BackgroundColor3 = band.BackgroundColor3,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, band)
		local gradient = Kit.RarityGradient(rarityId)
		if gradient then
			for _, f in ipairs({ band, filler }) do
				f.BackgroundColor3 = Color3.new(1, 1, 1)
				Kit.Shimmer(f, gradient)
			end
		end
		local label = Kit.Text(band, {
			Position = UDim2.fromScale(0.05, 0.08),
			Size = UDim2.fromScale(0.9, 0.84),
			Text = text,
			ZIndex = 3,
		})
		return band, label
	end

	local function buildCard(dog, order, p, eqPower)
		local species = DogData.Species[dog.Species]
		local rarity = Config.RARITY[species.Rarity]
		local isEquipped = p.Equipped == dog.Id
		local card = Kit.Card(mineGrid, { LayoutOrder = order, Text = "" }, rarity.Color:Lerp(Color3.fromRGB(35, 30, 50), 0.62), function()
			if selected ~= dog.Id then
				selected = dog.Id
				showDetail(true)
			end
		end)
		local border = card:FindFirstChildOfClass("UIStroke")
		if border then
			border:Destroy()
		end
		local special = Variants.IsSpecial(dog)
		if special then
			-- ✨🥇🌈 borda brilhando na cor da versão
			local stroke = Kit.Stroke(card, Color3.new(1, 1, 1), 4)
			Kit.Shimmer(stroke, Variants.TierOf(dog) == 2 and Kit.RAINBOW or Variants.TierOf(dog) == 1 and Kit.GOLDEN or { Variants.SHINY_COLOR, Color3.new(1, 1, 1), Variants.SHINY_COLOR })
		else
			Kit.RarityStroke(card, species.Rarity, 3)
		end
		local ring = selectionRing(card, dog.Id == selected)
		rarityBand(card, species.Rarity, special and (rarity.Label .. " · " .. Variants.Label(dog, true)) or rarity.Label)

		-- imagem do cachorro (retrato 3D parado, pintado se for shiny/gold/rainbow)
		Kit.DogPortrait(card, {
			Position = UDim2.fromScale(0.04, 0.15),
			Size = UDim2.fromScale(0.92, 0.38),
			ZIndex = 2,
		}, dog.Species, special and dog or nil)

		Kit.Text(card, {
			Position = UDim2.fromScale(0.06, 0.53),
			Size = UDim2.fromScale(0.88, 0.13),
			Text = dog.Name,
			ZIndex = 2,
		})
		Kit.Text(card, {
			Position = UDim2.fromScale(0.06, 0.66),
			Size = UDim2.fromScale(0.88, 0.085),
			Text = species.Name,
			TextColor3 = C.Muted,
			ZIndex = 2,
		})
		local stars = starsOf(dog)
		local pw = Net.Power(dog)
		local arrow, arrowColor = "", C.Muted
		if isEquipped then
			arrow, arrowColor = "✔ EQUIPPED", C.Green
		elseif eqPower then
			arrow, arrowColor = Kit.Compare(pw, eqPower)
			if arrow == "= same" then
				arrow = "="
			end
		end
		if stars > 0 then
			Kit.Text(card, {
				Position = UDim2.fromScale(0.06, 0.755),
				Size = UDim2.fromScale(0.42, 0.085),
				RichText = true,
				Text = starsRich(stars, stars),
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 2,
			})
		end
		Kit.Text(card, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(0.94, 0.755),
			Size = UDim2.fromScale(stars > 0 and 0.5 or 0.88, 0.085),
			Text = arrow,
			TextColor3 = arrowColor,
			TextXAlignment = stars > 0 and Enum.TextXAlignment.Right or Enum.TextXAlignment.Center,
			ZIndex = 2,
		})
		Kit.Text(card, {
			Position = UDim2.fromScale(0.06, 0.85),
			Size = UDim2.fromScale(0.42, 0.12),
			Text = "LV." .. dog.Level,
			TextColor3 = C.Gold,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 2,
		})
		Kit.Text(card, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(0.94, 0.85),
			Size = UDim2.fromScale(0.52, 0.12),
			Text = "💪" .. Config.Format(pw),
			TextColor3 = C.Orange,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 2,
		})
		if dog.Fav then
			Kit.Text(card, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(8, 8),
				Size = UDim2.fromOffset(30, 30),
				Text = "★",
				TextColor3 = C.Gold,
				ZIndex = 7,
			})
		end
		-- aviso de recuperação (atualizado pelo loop enquanto o menu está aberto)
		local recover = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.92, 0.2),
			BackgroundColor3 = C.Orange,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 8,
		}, card)
		Kit.Corner(recover, 10)
		Kit.Stroke(recover, C.Dark, 2)
		local recoverText = Kit.Text(recover, { Position = UDim2.fromScale(0.04, 0.1), Size = UDim2.fromScale(0.92, 0.8), Text = "", ZIndex = 9 })
		cards[dog.Id] = { Select = ring, Recover = recover, RecoverText = recoverText, Dog = dog, Equipped = isEquipped }
	end

	local function refreshRecovery()
		for _, c in pairs(cards) do
			local text = recoveryText(c.Dog, c.Equipped)
			c.Recover.Visible = text ~= nil
			if text then
				c.RecoverText.Text = text
			end
		end
		if tab == "mine" and selected and Net.Profile then
			local dog = Net.Profile.Dogs[selected]
			if dog then
				local equipped = Net.Profile.Equipped == dog.Id
				local text = recoveryText(dog, equipped)
				if text then
					showStatus(text, C.Orange)
				elseif equipped then
					showStatus("✔ EQUIPPED", C.Green)
				else
					showStatus(nil)
				end
			end
		end
	end

	local function rebuildMine(force)
		local p = Net.Profile
		if not p then
			return
		end
		local dogs = sortedDogs()
		-- só reconstrói se algo visível mudou (o perfil chega várias vezes por segundo enquanto come)
		local parts = { tostring(p.Equipped), tostring(onlyFav), rarityFilter, sortIndex }
		for _, dog in ipairs(dogs) do
			table.insert(parts, dog.Id .. ":" .. dog.Level .. ":" .. dog.Name .. ":" .. tostring(dog.Fav) .. ":" .. starsOf(dog) .. ":" .. Variants.Label(dog, true))
		end
		local signature = table.concat(parts, "|")
		if not force and signature == lastSignature then
			return
		end
		lastSignature = signature
		for _, c in ipairs(mineGrid:GetChildren()) do
			if c:IsA("GuiButton") then
				c:Destroy()
			end
		end
		table.clear(cards)
		local eqPower = equippedPower()
		for i, dog in ipairs(dogs) do
			buildCard(dog, i, p, eqPower)
		end
		emptyText.Visible = #dogs == 0
		emptyText.Text = onlyFav and "No favorites yet ⭐" or "No dogs match this filter"
		refreshRecovery()
	end

	---------------------------------------------------------- ÍNDICE
	local function showDex(fresh)
		local p = Net.Profile
		local found = discoveredSet(p)
		for id, c in pairs(dexCells) do
			c.Select.Visible = id == dexSelected
		end
		local species = dexSelected and DogData.Species[dexSelected]
		if not species then
			return
		end
		local known = found[dexSelected] == true
		local rarity = Kit.Rarity(species.Rarity)
		if setStage(dexSelected, not known) then
			fresh = true
		end
		if fresh and known then
			howl()
		end
		levelChip.Visible = false
		starsLabel.Text = ""
		local st = Config.Stats(species, 1)
		local sp = DogData.Specials[species.Special]
		local owned, best = 0, 0
		for _, dog in pairs(p and p.Dogs or {}) do
			if dog.Species == dexSelected then
				owned += 1
				best = math.max(best, dog.Level)
			end
		end
		if known then
			dexTitle.Text = string.upper(species.Name)
			dexSub.Text = rarity.Label .. "  ·  " .. DogData.ElementLabel(dexSelected) .. "  ·  " .. species.Role
			dexStats.Set({
				"LV.1",
				{ Icon = "heart", Text = Config.Format(st.MaxHP) },
				{ Icon = "sword", Text = Config.Format(st.Atk) },
				{ Icon = "wind", Text = tostring(st.Speed) },
			})
			local line, pw = powerLine(dexSelected)
			local sp2 = DogData.Specials[pw[1]] or sp
			dexSpecial.Set(line)
			dexSpecialDesc.Text = sp2 and sp2.Desc or ""
			if owned > 0 then
				dexOwned.Text = "✔ You own " .. owned .. "  ·  best LV." .. best
				dexOwned.TextColor3 = C.Green
			else
				dexOwned.Text = "You've owned this dog before"
				dexOwned.TextColor3 = C.Muted
			end
			showStatus("✔ DISCOVERED", C.Green)
		else
			dexTitle.Text = "???"
			dexSub.Text = rarity.Label .. "  ·  not discovered yet"
			dexStats.Set({ { Icon = "heart", Text = "???" }, { Icon = "sword", Text = "???" }, { Icon = "wind", Text = "???" } })
			dexSpecial.Set({ { Icon = "question", Text = "Special: ???" } })
			dexSpecialDesc.Text = "Catch this dog in the wild (or hatch it) to reveal it!"
			dexOwned.Text = ""
			showStatus("🔒 NOT DISCOVERED", C.Disabled)
		end
		Kit.RarityText(dexSub, species.Rarity)
		if species.Exclusive then
			dexEggsText.Text = "🎟️ EXCLUSIVE: only in the SEASON PASS (premium track, level 30)"
		elseif Config.EGGS then
			dexEggsText.Text = "🥚 Found in: " .. eggsFor(species.Rarity)
		else
			local where = wildFor(dexSelected)
			dexEggsText.Text = where and ("🦮 Catch it on: " .. where) or "🎰 Dog Roulette only"
		end
	end

	local function buildDexCell(parent, id, order, known, isNew)
		local species = DogData.Species[id]
		local rarity = Kit.Rarity(species.Rarity)
		local cell = Kit.Card(
			parent,
			{ LayoutOrder = order, Text = "" },
			known and rarity.Color:Lerp(Color3.fromRGB(35, 30, 50), 0.55) or Color3.fromRGB(38, 34, 52),
			function()
				if dexSelected ~= id then
					dexSelected = id
					showDex(true)
				end
			end
		)
		local border = cell:FindFirstChildOfClass("UIStroke")
		if known then
			if border then
				border:Destroy()
			end
			Kit.RarityStroke(cell, species.Rarity, 3)
		elseif border then
			border.Color = rarity.Color:Lerp(C.Dark, 0.55)
		end
		local ring = selectionRing(cell, id == dexSelected)
		local cellIcon = Icons.Make(cell, known and Icons.ForPower(species.Special, DogData.Specials[species.Special]) or "question", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.08),
			Size = UDim2.fromScale(0.5, 0.5),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			ZIndex = 2,
		})
		if not known then
			Icons.Gray(cellIcon, true)
		end
		Kit.Text(cell, {
			Position = UDim2.fromScale(0.05, 0.62),
			Size = UDim2.fromScale(0.9, 0.3),
			Text = known and species.Name or "???",
			TextColor3 = known and C.Text or C.Muted,
			ZIndex = 2,
		})
		if isNew then
			local chip = Kit.Chip(cell, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, 4, 0, 4),
				Size = UDim2.fromOffset(52, 22),
				ZIndex = 7,
			}, C.Red, "NEW")
			chip:FindFirstChildOfClass("TextLabel").ZIndex = 8
		end
		dexCells[id] = { Select = ring }
	end

	local function rebuildDex(force)
		local p = Net.Profile
		local found = discoveredSet(p)
		local groups, total = dexSpecies()
		local count = 0
		local parts = { rarityFilter }
		for _, rarityId in ipairs(Config.RARITIES) do
			for _, id in ipairs(groups[rarityId]) do
				if found[id] then
					count += 1
					table.insert(parts, id)
				end
			end
		end
		countText.Text = "📖 " .. count .. "/" .. total
		dexBar.Set(total > 0 and count / total or 0)
		dexBar.Label.Text = count .. "/" .. total .. " discovered"
		local signature = table.concat(parts, "|")
		if not force and signature == lastDexSignature then
			return
		end
		lastDexSignature = signature
		for _, c in ipairs(dexHolder:GetChildren()) do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		table.clear(dexCells)
		-- 📖 PRÊMIOS DO DEX (2026-10-25): os marcos (10/25/50 descobertos e cada raridade completa) com a barra de cada um
		local rewards = make("Frame", { LayoutOrder = 0, Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, dexHolder)
		make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, rewards)
		Kit.Text(rewards, {
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, 30),
			Text = "🎁 DEX REWARDS — leashes, spins, Cash and titles!",
			TextColor3 = C.Gold,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local rgrid = make("Frame", { LayoutOrder = 2, Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, rewards)
		make("UIGridLayout", { CellSize = UDim2.new(0.317, 0, 0, 74), CellPadding = UDim2.new(0.024, 0, 0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, rgrid)
		for i, m in ipairs(DexRewards.MILESTONES) do
			local have, goal, done = DexRewards.Progress(m, found)
			if goal > 0 then
				local box = Kit.Box(rgrid, { LayoutOrder = i }, done and Color3.fromRGB(46, 120, 70) or C.Panel2)
				Kit.Text(box, {
					Position = UDim2.fromScale(0.05, 0.04),
					Size = UDim2.fromScale(0.9, 0.3),
					Text = (done and "✔ " or "") .. m.Name,
					TextColor3 = done and C.Green or C.Text,
				})
				local bar = Kit.Bar(box, { Position = UDim2.fromScale(0.05, 0.38), Size = UDim2.fromScale(0.9, 0.24) }, done and C.Green or C.Gold)
				bar.Set(goal > 0 and have / goal or 0)
				bar.Label.Text = have .. "/" .. goal
				Kit.Text(box, {
					Position = UDim2.fromScale(0.05, 0.66),
					Size = UDim2.fromScale(0.9, 0.28),
					Text = DexRewards.RewardText(m.Reward) .. (m.Title and (" · 🎖️ " .. m.Title) or ""),
					TextColor3 = C.Muted,
				})
			end
		end
		local firstId = nil
		for gi, rarityId in ipairs(Config.RARITIES) do
			local ids = groups[rarityId]
			if #ids > 0 and (rarityFilter == 0 or Config.RARITIES[rarityFilter] == rarityId) then
				local rarity = Kit.Rarity(rarityId)
				local have = 0
				for _, id in ipairs(ids) do
					if found[id] then
						have += 1
					end
				end
				local section = make("Frame", {
					LayoutOrder = gi,
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
				}, dexHolder)
				make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, section)
				local head = Kit.Text(section, {
					LayoutOrder = 1,
					Size = UDim2.new(1, 0, 0, 30),
					Text = rarity.Label .. "   " .. have .. "/" .. #ids .. (have == #ids and "  ✔" or ""),
					TextXAlignment = Enum.TextXAlignment.Left,
				})
				Kit.RarityText(head, rarityId)
				local grid = make("Frame", {
					LayoutOrder = 2,
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
				}, section)
				make("UIGridLayout", {
					CellSize = UDim2.new(0.232, 0, 0, 100),
					CellPadding = UDim2.new(0.024, 0, 0, 10),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}, grid)
				for i, id in ipairs(ids) do
					firstId = firstId or id
					local isNew = found[id] and knownDex ~= nil and not knownDex[id]
					buildDexCell(grid, id, i, found[id] == true, isNew)
				end
			end
		end
		if not (dexSelected and dexCells[dexSelected]) then
			-- começa pelo cachorro equipado (ou pelo primeiro da lista)
			local eq = Net.Equipped()
			dexSelected = (eq and dexCells[eq.Species]) and eq.Species or firstId
		end
		emptyText.Visible = false
	end

	-- "!" na aba ÍNDICE quando há espécie nova desde a última visita
	local function updateDexBadge()
		local found = discoveredSet(Net.Profile)
		if knownDex == nil then
			knownDex = found
			badgeDex(nil)
			return
		end
		local fresh = 0
		for id in pairs(found) do
			if DogData.Species[id] and not knownDex[id] then
				fresh += 1
			end
		end
		badgeDex(fresh > 0 and tostring(fresh) or nil)
	end

	---------------------------------------------------------- troca de aba / filtros
	local function refreshFilters()
		local mine = tab == "mine"
		Kit.SetButtonColor(tabMine, mine and C.Blue or C.Panel2)
		Kit.SetButtonColor(tabDex, mine and C.Panel2 or C.Gold)
		if headerTitle then
			headerTitle.Text = mine and "🐶 MY DOGS" or "📖 DOG INDEX"
		end
		favToggle.Visible = mine
		sortButton.Visible = mine
		sellButton.Visible = mine
		dexBar.Frame.Visible = not mine
		mineGrid.Visible = mine
		dexHolder.Visible = not mine
		mineInfo.Visible = mine
		dexInfo.Visible = not mine
		favToggle.Text = onlyFav and "★ Fav" or "☆ Fav"
		Kit.SetButtonColor(favToggle, onlyFav and C.Gold or C.Panel2)
		if rarityFilter == 0 then
			rarityButton.Text = "💎 All"
			Kit.SetButtonColor(rarityButton, C.Panel2)
		else
			local r = Config.RARITY[Config.RARITIES[rarityFilter]]
			rarityButton.Text = r.Label
			Kit.SetButtonColor(rarityButton, r.Color:Lerp(C.Dark, 0.2))
		end
		sortButton.Text = SORTS[sortIndex].Label
		if mine then
			countText.Text = "🐶 " .. Net.DogCount() .. "/" .. Config.MaxDogs(player)
			rebuildMine(false)
			showDetail(false)
		else
			emptyText.Visible = false
			rebuildDex(false)
			showDex(false)
		end
		list.CanvasPosition = Vector2.zero
	end

	local function setTab(newTab)
		if tab == newTab then
			return
		end
		if tab == "dex" then
			-- saiu do índice: o que estava lá deixa de ser "novo"
			knownDex = discoveredSet(Net.Profile)
			lastDexSignature = nil
			badgeDex(nil)
		end
		tab = newTab
		refreshFilters()
		if tab == "mine" then
			showDetail(true)
		else
			showDex(true)
		end
	end
	tabMine.Activated:Connect(function()
		setTab("mine")
	end)
	tabDex.Activated:Connect(function()
		setTab("dex")
	end)
	favToggle.Activated:Connect(function()
		onlyFav = not onlyFav
		refreshFilters()
	end)
	rarityButton.Activated:Connect(function()
		rarityFilter = (rarityFilter + 1) % (#Config.RARITIES + 1)
		refreshFilters()
	end)
	sortButton.Activated:Connect(function()
		sortIndex = sortIndex % #SORTS + 1
		refreshFilters()
	end)

	local dirty = false
	Net.Changed.Event:Connect(function(p)
		for _, dog in pairs(p.Dogs or {}) do
			sessionSeen[dog.Species] = true
		end
		if not menu.Open then
			updateDexBadge()
			return
		end
		if dirty then
			return
		end
		dirty = true
		task.delay(0.3, function()
			dirty = false
			if not menu.Open then
				return
			end
			if tab == "mine" then
				countText.Text = "🐶 " .. Net.DogCount() .. "/" .. Config.MaxDogs(player)
				rebuildMine(false)
				showDetail(false)
			else
				rebuildDex(false)
				showDex(false)
			end
		end)
	end)

	---------------------------------------------------------- ações (aba MEUS)
	equipButton.Activated:Connect(function()
		local p = Net.Profile
		if not selected or not p or p.Equipped == selected then
			return
		end
		local ok, message = Net.Invoke("EquipDog", selected)
		HUD.Toast(message, ok and "green" or "red")
		if ok then
			Kit.Burst(stage, UDim2.fromScale(0.5, 0.55), C.Green, 16, nil, 120)
			howl()
		else
			Kit.Shake(equipButton)
		end
	end)
	teamButton.Activated:Connect(function()
		if selected then
			local ok, message = Net.Invoke("TeamAction", "toggle", selected)
			HUD.Toast(message or "", ok and "green" or "red")
			if not ok then
				Kit.Shake(teamButton)
			end
		end
	end)
	favButton.Activated:Connect(function()
		local dog = Net.Profile and selected and Net.Profile.Dogs[selected]
		if dog then
			favButton.Text = dog.Fav and "☆" or "★"
			Net.Invoke("FavoriteDog", selected, not dog.Fav)
			if not dog.Fav then
				Kit.Burst(favButton, UDim2.fromScale(0.5, 0.5), C.Gold, 8, { "★" }, 50)
			end
		end
	end)
	renameButton.Activated:Connect(function()
		local dog = Net.Profile and selected and Net.Profile.Dogs[selected]
		if not dog then
			return
		end
		input.Text = dog.Name
		renameShade.Visible = true
		Kit.Pop(renameBox, true)
		input:CaptureFocus()
	end)
	local function doRename()
		if not renameShade.Visible then
			return
		end
		local ok, result = Net.Invoke("RenameDog", selected, input.Text)
		if ok then
			renameShade.Visible = false
			HUD.Toast("✏️ Now named " .. tostring(result) .. "!", "green")
		else
			HUD.Toast(result, "red")
			Kit.Shake(renameBox)
		end
	end
	renameOk.Activated:Connect(doRename)
	input.FocusLost:Connect(function(enter)
		if enter then
			doRename()
		end
	end)
	releaseButton.Activated:Connect(function()
		local dog = Net.Profile and selected and Net.Profile.Dogs[selected]
		if not dog then
			return
		end
		if not confirmRelease then
			confirmRelease = true
			local rarity = Config.RARITY[DogData.Species[dog.Species].Rarity]
			releaseButton.Text = "+$" .. Config.Format(math.floor(rarity.Release * (1 + dog.Level * 0.05) * Variants.ValueMult(dog))) .. "?"
			Kit.SetButtonColor(releaseButton, C.Orange)
			local id = dog.Id
			task.delay(3, function()
				if confirmRelease and selected == id then
					confirmRelease = false
					releaseButton.Text = "🕊️"
					Kit.SetButtonColor(releaseButton, C.Red)
				end
			end)
			return
		end
		local ok, message = Net.Invoke("ReleaseDog", selected)
		HUD.Toast(message, ok and "green" or "red")
		if ok then
			selected = nil
		end
	end)

	-- 🧬 EVOLVE: 1º toque mostra o que vai acontecer, 2º toque confirma (some com os 3 e nasce 1 da versão de cima)
	evolveButton.Activated:Connect(function()
		local p = Net.Profile
		local dog = p and selected and p.Dogs[selected]
		if not (dog and Variants.CanEvolve(dog)) then
			return
		end
		local list, have = Variants.EvolvePick(p.Dogs, dog.Id, nil)
		local nextTier = Variants.TIERS[Variants.TierOf(dog) + 1]
		if not list then
			HUD.Toast("🧬 You need " .. Variants.EVOLVE_COUNT .. " " .. (Variants.TierOf(dog) == 1 and "GOLD " or "") .. DogData.Species[dog.Species].Name .. " (you have " .. have .. "). Catch more! ⭐ Favorites are kept safe.", "orange")
			Kit.Shake(evolveButton)
			return
		end
		if not confirmEvolve then
			confirmEvolve = true
			evolveButton.Text = "3 → 1 " .. nextTier.Label .. "?"
			Kit.SetButtonColor(evolveButton, C.Orange)
			local id = dog.Id
			task.delay(3, function()
				if confirmEvolve and selected == id then
					showDetail(false)
				end
			end)
			return
		end
		confirmEvolve = false
		local ok, result = Net.Invoke("EvolveAction", "evolve", dog.Id)
		if ok and type(result) == "table" then
			selected = result.Uid
			HUD.Banner("🧬 EVOLVED!", (result.Shiny and "✨ " or "") .. result.Label .. " " .. tostring(result.Name), "x" .. tostring(nextTier.Mult) .. " HP and Attack!", nextTier.Color, 3)
			Kit.Burst(stage, UDim2.fromScale(0.5, 0.55), nextTier.Color, 24, { "★", "✦" }, 140)
			lastSignature = nil
			task.delay(0.4, function()
				rebuildMine(true)
				showDetail(true)
			end)
		else
			HUD.Toast(type(result) == "string" and result or "Couldn't evolve right now.", "red")
			Kit.Shake(evolveButton)
		end
	end)

	-- recuperação muda sem o perfil mudar (atributo no modelo): checa enquanto o menu está aberto
	task.spawn(function()
		while true do
			task.wait(0.5)
			if menu.Open and tab == "mine" then
				local ok, err = pcall(refreshRecovery)
				if not ok then
					warn("[DogsMenu]", err)
				end
			end
		end
	end)

	task.spawn(function()
		local p = Net.WaitProfile()
		for _, dog in pairs(p.Dogs or {}) do
			sessionSeen[dog.Species] = true
		end
		updateDexBadge()
	end)

	HUD.RegisterMenu("Dogs", {
		Open = function()
			sellPanel.Visible = false
			menu.Show(true)
			HUD.SetBadge("Dogs", nil)
			lastSignature, lastDexSignature = nil, nil
			refreshFilters()
			if tab == "mine" then
				showDetail(true)
			else
				showDex(true)
			end
		end,
		Close = function()
			renameShade.Visible = false
			if tab == "dex" then
				knownDex = discoveredSet(Net.Profile)
				badgeDex(nil)
			end
			menu.Show(false)
			-- libera o modelo 3D enquanto o menu está fechado
			task.delay(0.25, function()
				if not menu.Open then
					view.SetSpecies(nil)
					view.SpeciesId = nil
				end
			end)
		end,
	})
end

-- Outros módulos (ex.: Hatch) avisam que uma espécie foi vista nesta sessão
function DogsMenu.MarkSeen(speciesId)
	sessionSeen[speciesId] = true
end

return DogsMenu
