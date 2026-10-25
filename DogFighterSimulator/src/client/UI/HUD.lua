-- HUD principal — 🎨 CARTOON E PEQUENO (2026-10-24, pedido do dono: "não quero 3D, quero cartoon, tipo os golpes;
-- deixa o HUD não muito grande; onde aparece o cachorro em cima tira o cachorro de lá; aparecem muitas coisas e muitas
-- tampam a tela do jogador, não faça isso"). Peças chapadas (sem degradê de brilho), contorno escuro grosso, sombra dura
-- embaixo e ícones desenhados em 2D (UI/Icons). Sem emoji: o emoji de um aviso vira o ícone dele.
--   cima-esquerda: cartão do cachorro SEM retrato (nível na moeda dourada, nome, estrelas, vida e XP) e uma linha de
--     botões pequenos: QUESTS (as missões do dia viraram um botão com contador — antes era um painel grande aberto),
--     TRADE, CODES e SETTINGS
--   cima-meio: chip da ilha, a linha do OBJETIVO (só quando importa: missão, 1º cachorro, ilha nova liberada, Super
--     Boss acordado; as DICAS somem sozinhas) e os avisos (no máximo 2, pequenos e rápidos)
--   cima-direita: dinheiro (o + abre a loja), chip do SUPER BOSS e o minimapa desenhado (só no PC)
--   direita: botões DOGS / EGGS / MAP / SHOP (PC: coluna; celular: grade)
--   centro-baixo: chip de estado (desmaiado, indo para a arena, sequência de vitórias)
--   faixas de LEVEL UP etc.: uma fita pequena no alto (antes um painel grande com raios no meio da tela)
-- Tudo dentro de Kit.Screen (pixels de design); no celular cada grupo fica 1,15x maior. O meio da tela fica livre.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Monetization = require(ReplicatedStorage.Shared.Monetization)
local Islands = require(ReplicatedStorage.Shared.Islands)
local Village = require(ReplicatedStorage.Shared.Village)
local DogData = require(ReplicatedStorage.Shared.DogData)
local Kit = require(script.Parent.Kit)
local Icons = require(script.Parent.Icons)
local WorldMap = require(script.Parent.WorldMap)
local Net = require(script.Parent.Parent.Net)

local HUD = {}
local ConfigAny: any = Config -- campos opcionais (StarsFor, StarText...) que podem não existir
local make = Kit.make

local player = Players.LocalPlayer
local gui, root
local menus = {} -- [name] = { Open = fn, Close = fn }
local openMenu = nil
local menuChanged = Instance.new("BindableEvent")
HUD.MenuChanged = menuChanged.Event -- (nomeDoMenuAberto | nil)
HUD.OnToast = nil :: ((any, any) -> ())? -- (Systems/Sfx: som de cada aviso)

function HUD.RegisterMenu(name, menu)
	menus[name] = menu
end

function HUD.IsOpen(name)
	if name then
		return openMenu == name
	end
	return openMenu ~= nil
end

function HUD.HasMenu(name)
	return menus[name] ~= nil
end

function HUD.GetMenu(name)
	return menus[name]
end

function HUD.Toggle(name)
	local menu = menus[name]
	if not menu then
		return
	end
	if openMenu == name then
		menu.Close()
		openMenu = nil
		menuChanged:Fire(nil)
		return
	end
	if openMenu and menus[openMenu] then
		menus[openMenu].Close()
	end
	openMenu = name
	menu.Open()
	menuChanged:Fire(name)
end

function HUD.CloseAll()
	if openMenu and menus[openMenu] then
		menus[openMenu].Close()
	end
	if openMenu then
		openMenu = nil
		menuChanged:Fire(nil)
	end
end

---------------------------------------------------------------- estilo cartoon
local function rgb(n)
	return Color3.fromRGB(math.floor(n / 65536) % 256, math.floor(n / 256) % 256, n % 256)
end
local WHITE = Color3.new(1, 1, 1)
local INK = Icons.INK
local COL = {
	panel = rgb(0x3b2f86), -- fundo das peças (roxo-azulado)
	gold = rgb(0xffc93c),
	green = rgb(0x46cf5c),
	cash = rgb(0x3fbf4f),
	blue = rgb(0x3fa7ff),
	teal = rgb(0x22c8ad),
	pink = rgb(0xff6fb0),
	purple = rgb(0x8f5cf0),
	red = rgb(0xff5a5a),
	orange = rgb(0xff9f1c),
}
local MUTED = rgb(0xd6d0ff)
local GOLD_TEXT = rgb(0xffd84a)
local CASH_TEXT = rgb(0x8dff6e)
local RED_TEXT = rgb(0xff7b7b)
local FILL = {
	green = rgb(0x5be05a),
	xp = rgb(0x4fc3ff),
	gold = rgb(0xffc93c),
	teal = rgb(0x2fd9bb),
	red = rgb(0xff5a5a),
	heal = rgb(0x7ff0cf),
	orange = rgb(0xffa733),
}
local LUCKY, FRED = Enum.Font.LuckiestGuy, Enum.Font.FredokaOne
local BORDER = 2.5 -- contorno
local DROP = 3 -- sombra dura embaixo

local function inkStroke(parent, thickness)
	return make("UIStroke", {
		Color = INK,
		Thickness = thickness or BORDER,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	}, parent)
end

-- texto do HUD: tamanho fixo (pixels de design), contorno escuro, cresce sozinho na largura
local function label(parent, text, size, color, font, props)
	local l = make("TextLabel", {
		BackgroundTransparency = 1,
		Font = font or FRED,
		Text = text or "",
		TextSize = size,
		TextColor3 = color or WHITE,
		TextXAlignment = Enum.TextXAlignment.Left,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, size + 4),
	}, parent)
	for k, v in pairs(props or {}) do
		l[k] = v
	end
	make("UIStroke", {
		Color = INK,
		Thickness = math.max(1.4, size * 0.15),
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		LineJoinMode = Enum.LineJoinMode.Round,
	}, l)
	return l
end

local function textWidth(text, size, font)
	local ok, v = pcall(function()
		return TextService:GetTextSize(text, size, font, Vector2.new(4000, 400))
	end)
	return ok and v.X or #text * size * 0.6
end

-- peça cartoon: holder (posição/tamanho) > Pop (centro, recebe a escala) > sombra dura + corpo de cor CHAPADA.
-- button = true: corpo clicável (TextButton) em 2 tons (metade de baixo um pouco mais escura, corte reto)
local function piece(parent, props, color, radius, button)
	local holder = make("Frame", { BackgroundTransparency = 1, BorderSizePixel = 0 }, parent)
	for k, v in pairs(props) do
		holder[k] = v
	end
	local pop = make("Frame", {
		Name = "Pop",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, holder)
	local shadow = make("Frame", {
		Name = "Shadow",
		Position = UDim2.fromOffset(0, DROP),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = INK,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, pop)
	Kit.Corner(shadow, radius or 14)
	inkStroke(shadow)
	local bodyProps = { Name = "Body", Size = UDim2.fromScale(1, 1), BackgroundColor3 = color or COL.panel, BorderSizePixel = 0, ZIndex = 2 }
	if button then
		bodyProps.Text = ""
		bodyProps.AutoButtonColor = false
	end
	local body = make(button and "TextButton" or "Frame", bodyProps, pop)
	Kit.Corner(body, radius or 14)
	inkStroke(body)
	if button then
		Kit.TwoTone(body, 0.56, 0.13)
	end
	return holder, body, pop
end

-- cresce no mouse/seleção do controle e afunda no clique (a escala vai no Pop: sombra junto)
local function pressable(button, pop)
	local scale = make("UIScale", { Name = "PressScale" }, pop)
	local function to(v, t, style)
		Kit.Tween(scale, t, { Scale = v }, style or Enum.EasingStyle.Back)
	end
	button.MouseEnter:Connect(function()
		to(1.07, 0.12)
	end)
	button.MouseLeave:Connect(function()
		to(1, 0.12)
	end)
	button.SelectionGained:Connect(function()
		to(1.07, 0.12)
	end)
	button.SelectionLost:Connect(function()
		to(1, 0.12)
	end)
	button.MouseButton1Down:Connect(function()
		to(0.9, 0.06, Enum.EasingStyle.Quad)
	end)
	button.MouseButton1Up:Connect(function()
		to(1, 0.14)
	end)
end

-- barra cartoon (fundo escuro, cor chapada e um risco claro). Devolve { Set, Paint, Label, Fill }
local function bar(parent, props, fill, textSize)
	local back = make("Frame", { BackgroundColor3 = rgb(0x1e1240), BackgroundTransparency = 0.15, BorderSizePixel = 0 }, parent)
	for k, v in pairs(props) do
		back[k] = v
	end
	Kit.Corner(back, 999)
	inkStroke(back, 2.2)
	local f = make("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = fill, BorderSizePixel = 0, ZIndex = 1 }, back)
	Kit.Corner(f, 999)
	local stripe = make("Frame", {
		Position = UDim2.new(0, 4, 0.16, 0),
		Size = UDim2.new(1, -8, 0.22, 0),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
	}, f)
	Kit.Corner(stripe, 999)
	local text = label(back, "", textSize or 10, WHITE, FRED, {
		Name = "Label",
		AutomaticSize = Enum.AutomaticSize.None,
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 2,
	})
	local b = { Frame = back, Fill = f, Label = text, Value = 0, Started = false }
	function b.Set(pct, instant)
		pct = math.clamp(pct, 0, 1)
		if not instant and b.Started and math.abs(pct - b.Value) < 0.0005 then
			return -- mesmo valor: não refaz a animação (é chamado 5x por segundo)
		end
		b.Started = true
		b.Value = pct
		f.Visible = pct > 0.005
		if instant then
			f.Size = UDim2.fromScale(pct, 1)
		else
			Kit.Tween(f, 0.35, { Size = UDim2.fromScale(pct, 1) })
		end
	end
	function b.Paint(color)
		f.BackgroundColor3 = color
	end
	return b
end

-- bolinha vermelha de aviso no canto de um botão ("!", "3", "NEW"). Devolve set(texto | nil)
local function badge(parent, size)
	local b = make("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(1, 0.5), -- cresce para a esquerda ("NEW" não sai da tela)
		Position = UDim2.new(1, size * 0.33, 0, size * 0.15),
		Size = UDim2.fromOffset(size, size),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = rgb(0xff4b4b),
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 30,
	}, parent)
	Kit.Corner(b, 999)
	inkStroke(b, 2)
	local t = label(b, "", math.floor(size * 0.62), WHITE, LUCKY, {
		Size = UDim2.fromOffset(size, size),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 31,
	})
	make("UIPadding", { PaddingLeft = UDim.new(0, size * 0.22), PaddingRight = UDim.new(0, size * 0.22) }, t)
	local stopPulse = nil
	return function(text)
		b.Visible = text ~= nil and text ~= ""
		t.Text = text or ""
		if b.Visible and not stopPulse then
			stopPulse = Kit.Pulse(b, 0.12, 0.8)
		elseif not b.Visible and stopPulse then
			stopPulse()
			stopPulse = nil
		end
	end
end

-- some aos poucos (aviso indo embora)
local function fadeTree(frame, t)
	for _, d in ipairs(frame:GetDescendants()) do
		if d:IsA("UIStroke") then
			Kit.Tween(d, t, { Transparency = 1 })
		elseif d:IsA("TextLabel") then
			Kit.Tween(d, t, { TextTransparency = 1 })
		elseif d:IsA("Frame") and d.BackgroundTransparency < 1 then
			Kit.Tween(d, t, { BackgroundTransparency = 1 })
		end
	end
end

---------------------------------------------------------------- números e emoji
local function commas(n)
	n = math.floor(n)
	local s = tostring(math.abs(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return (n < 0 and "-" or "") .. out
end

-- $1,240 até 999.999; depois 1.2M, 3.4B...
local function money(n)
	if math.abs(n) >= 1e6 then
		return Config.Format(n)
	end
	return commas(n)
end

-- cada emoji conhecido vira um ícone desenhado (o primeiro que aparece no texto manda; a tabela fica no UI/Icons)
local function iconFor(text)
	local best = Icons.FromEmoji(text)
	if not best and string.find(text, "$", 1, true) then
		best = "coins"
	end
	return best
end
HUD.IconFor = iconFor

-- tira os emoji (o ícone desenhado já mostra); mantém ★ ☆ e tira "·" que sobrou nas pontas
local function stripEmoji(s)
	s = Icons.Strip(s)
	s = s:gsub("^[%s·]+", ""):gsub("[%s·]+$", "")
	return s
end
HUD.StripEmoji = stripEmoji

---------------------------------------------------------------- avisos empilhados (no máximo 2, pequenos)
local toastList
local toastCount = 0
local TOAST_COLORS = {
	gold = GOLD_TEXT,
	red = RED_TEXT,
	green = CASH_TEXT,
	blue = rgb(0x8fd0ff),
	purple = rgb(0xcfb2ff),
	orange = rgb(0xffbe6a),
	pink = rgb(0xffa3cf),
	white = WHITE,
	xp = rgb(0x8fdcff),
}
local TOAST_TIME = 2.6
local TOAST_MAX = 2
local TOAST_SIZE = 12
local TOAST_H = 26

local function fadeOutToast(item)
	if not item.Parent or item:GetAttribute("Leaving") then
		return
	end
	item:SetAttribute("Leaving", true)
	local pop = item:FindFirstChild("Pop")
	local scale = pop and pop:FindFirstChild("PopScale")
	if scale then
		Kit.Tween(scale, 0.2, { Scale = 0.75 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end
	fadeTree(item, 0.2)
	task.delay(0.22, function()
		item:Destroy()
	end)
end

local function toastWidth(text, hasIcon)
	return math.ceil(textWidth(text, TOAST_SIZE, FRED)) + (hasIcon and 44 or 26)
end

function HUD.Toast(message, colorName)
	if not toastList or message == nil or message == "" then
		return
	end
	message = tostring(message)
	local icon = iconFor(message)
	local text = stripEmoji(message)
	if text == "" then
		return
	end
	local color = TOAST_COLORS[colorName] or WHITE
	-- 🔊 (2026-10-25) cada aviso toca um som (Systems/Sfx coloca a função aqui)
	if HUD.OnToast then
		pcall(HUD.OnToast, message, colorName)
	end

	-- mesma mensagem repetida: só soma "x2", "x3"...
	local last = toastList:FindFirstChild("Toast" .. toastCount)
	if last and not last:GetAttribute("Leaving") and last:GetAttribute("Message") == text then
		local n = (last:GetAttribute("Count") or 1) + 1
		last:SetAttribute("Count", n)
		last:SetAttribute("Expire", os.clock() + TOAST_TIME)
		local labelObj = last:FindFirstChild("Label", true)
		if labelObj and labelObj:IsA("TextLabel") then
			labelObj.Text = text .. "  x" .. n
			last.Size = UDim2.fromOffset(toastWidth(labelObj.Text, icon ~= nil), TOAST_H)
		end
		local pop = last:FindFirstChild("Pop")
		local scale = pop and pop:FindFirstChild("PopScale")
		if scale and scale:IsA("UIScale") then
			scale.Scale = 1.1
			Kit.Tween(scale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
		end
		return
	end

	toastCount += 1
	local item, body, pop = piece(toastList, {
		Name = "Toast" .. toastCount,
		LayoutOrder = -toastCount, -- o mais novo fica em cima
		Size = UDim2.fromOffset(toastWidth(text, icon ~= nil), TOAST_H),
	}, COL.panel, 999)
	body.BackgroundTransparency = 0.08
	item:SetAttribute("Message", text)
	item:SetAttribute("Expire", os.clock() + TOAST_TIME)
	if icon then
		Icons.Make(body, icon, { Position = UDim2.fromOffset(-4, -5), Size = UDim2.fromOffset(34, 34), ZIndex = 3 })
	end
	label(body, text, TOAST_SIZE, color, FRED, {
		Name = "Label",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, icon and 34 or 13, 0.5, 0),
	})
	local scale = make("UIScale", { Name = "PopScale", Scale = 0.6 }, pop)
	Kit.Tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)

	-- limite: os mais antigos saem primeiro
	local alive = {}
	for _, c in ipairs(toastList:GetChildren()) do
		if c:IsA("Frame") and not c:GetAttribute("Leaving") then
			table.insert(alive, c)
		end
	end
	table.sort(alive, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i = TOAST_MAX + 1, #alive do
		fadeOutToast(alive[i])
	end

	task.spawn(function()
		while item.Parent and os.clock() < (item:GetAttribute("Expire") or 0) do
			task.wait(0.2)
		end
		fadeOutToast(item)
	end)
end

-- Espaço reservado no topo (barra do boss da torre): a linha do objetivo some e os avisos descem
local topReserve = 0
local onTopReserve = nil
function HUD.SetTopReserve(px)
	topReserve = px or 0
	if onTopReserve then
		onTopReserve()
	end
end

---------------------------------------------------------------- faixas (LEVEL UP...) — uma fita pequena no alto
local bannerHolder
local bannerQueue = {}
local bannerBusy = false

local function playBanner(b)
	local touch = Kit.IsTouch()
	local bigW = textWidth(b.Big, 22, LUCKY)
	local smallW = math.max(textWidth(b.Title, 10, FRED), textWidth(b.Small or "", 11, FRED))
	local w = math.clamp(math.ceil(math.max(bigW, smallW)) + 78, 210, 380)
	local holder, body, pop = piece(bannerHolder, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -10),
		Size = UDim2.fromOffset(w, 58),
		ZIndex = 20,
	}, COL.panel, 18)
	local stroke = body:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Thickness = 3
	end
	-- faixa colorida embaixo (cor da faixa)
	local strip = make("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 8),
		BackgroundColor3 = b.Color,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, body)
	Kit.Corner(strip, 4)
	Icons.Make(body, b.Icon or "star", { Position = UDim2.fromOffset(-14, -12), Size = UDim2.fromOffset(60, 60), ZIndex = 6 })
	label(body, b.Title, 10, MUTED, FRED, {
		AutomaticSize = Enum.AutomaticSize.None,
		Position = UDim2.fromOffset(50, 3),
		Size = UDim2.new(1, -58, 0, 13),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 3,
	})
	local big = label(body, b.Big, 22, b.Color, LUCKY, {
		AutomaticSize = Enum.AutomaticSize.None,
		Position = UDim2.fromOffset(50, 15),
		Size = UDim2.new(1, -58, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
	})
	label(body, b.Small or "", 11, WHITE, FRED, {
		AutomaticSize = Enum.AutomaticSize.None,
		Position = UDim2.fromOffset(50, 38),
		Size = UDim2.new(1, -58, 0, 13),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
	})
	local bigScale = make("UIScale", { Scale = 0.4 }, big)
	Kit.Pop(pop, true)
	Kit.Tween(holder, 0.3, { Position = UDim2.new(0.5, 0, 0, 0) }, Enum.EasingStyle.Back)
	task.delay(0.06, function()
		Kit.Tween(bigScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		Kit.Burst(holder, UDim2.fromScale(0.5, 0.5), b.Color, touch and 6 or 10, nil, touch and 60 or 90)
	end)
	task.wait(touch and math.min(b.Time or 2.2, 1.6) or (b.Time or 2.2))
	Kit.Tween(holder, 0.22, { Position = UDim2.new(0.5, 0, 0, -90) }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	fadeTree(holder, 0.22)
	task.wait(0.24)
	holder:Destroy()
end

-- Faixa: título, linha grande colorida, linha pequena. Fica na fila. O emoji vira ícone desenhado.
function HUD.Banner(title, big, small, color, time)
	local raw = tostring(big or "") .. " " .. tostring(title or "") .. " " .. tostring(small or "")
	table.insert(bannerQueue, {
		Title = stripEmoji(tostring(title or "")),
		Big = stripEmoji(tostring(big or "")),
		Small = stripEmoji(tostring(small or "")),
		Icon = iconFor(raw) or "star",
		Color = color or GOLD_TEXT,
		Time = time and math.min(time, 2.6) or nil,
	})
	-- (fila longa: as mais velhas caem — nada de faixa atrás de faixa tampando o jogo)
	while #bannerQueue > 3 do
		table.remove(bannerQueue, 1)
	end
	if bannerBusy or not bannerHolder then
		return
	end
	bannerBusy = true
	task.spawn(function()
		while #bannerQueue > 0 do
			local b = table.remove(bannerQueue, 1)
			-- muitas seguidas: encurta para não acumular
			if #bannerQueue > 0 then
				b.Time = math.min(b.Time or 2.2, 1.3)
			end
			pcall(playBanner, b)
		end
		bannerBusy = false
	end)
end

---------------------------------------------------------------- utilidades
local function myDogModel()
	local folder = workspace:FindFirstChild("Cachorros")
	if not folder then
		return nil
	end
	for _, model in ipairs(folder:GetChildren()) do
		if model:GetAttribute("Kind") == "player" and model:GetAttribute("Owner") == player.UserId then
			return model
		end
	end
	return nil
end

local function duelTarget()
	local mine = myDogModel()
	local id = mine and mine:GetAttribute("DuelId") or 0
	if id == 0 then
		return nil
	end
	for _, model in ipairs(workspace.Cachorros:GetChildren()) do
		if model:GetAttribute("FighterId") == id then
			return model
		end
	end
	return nil
end

local badgeSetters = {}
-- Bolinha de aviso num botão ("Shop", "Dogs", "Inventario", "Missoes", "Trade"...); nil apaga
function HUD.SetBadge(menuName, text)
	local set = badgeSetters[menuName]
	if set then
		set(text)
	end
end

-- Botão do HUD de um menu (o Tutorial aponta a seta para ele)
local buttons = {}
function HUD.GetButton(name)
	if name == "MissoesPill" then
		name = "Missoes"
	end
	return buttons[name]
end

---------------------------------------------------------------- PACOTE INICIAL (botão SHOP)
local starterRibbon = nil
local starterForced = nil -- nil = automático pelo perfil; true/false = definido pela tela da Loja

local function starterPackOwned(p)
	if not p then
		return false
	end
	local pp: any = p
	if pp.StarterPack or pp.StarterPackBought then
		return true
	end
	for _, key in ipairs({ "Passes", "Gamepasses", "Purchases", "Products" }) do
		local t = pp[key]
		if type(t) == "table" and (t.StarterPack or t.PacoteInicial) then
			return true
		end
	end
	return player:GetAttribute("StarterPack") == true
end

local function refreshStarterRibbon()
	if not starterRibbon then
		return
	end
	local show
	if starterForced ~= nil then
		show = starterForced
	else
		show = not starterPackOwned(Net.Profile)
	end
	starterRibbon.Frame.Visible = show
end

-- A tela da Loja pode ligar/desligar o destaque "PACOTE INICIAL" (nil volta ao automático)
function HUD.SetStarterHighlight(visible)
	starterForced = visible
	refreshStarterRibbon()
end

---------------------------------------------------------------- missões (o Progression manda o retrato)
local questState = nil
local onQuests = nil
-- state = retrato do Progression (Daily, ResetIn...). (O HUD só mostra o contador: quem resgata é o menu QUESTS)
function HUD.SetQuests(state, _claim, _receivedAt)
	questState = state
	if onQuests then
		onQuests()
	end
end

---------------------------------------------------------------- botões
local MENU = {
	{ Menu = "Shop", Label = "HOME", Icon = "doghouse", Color = rgb(0xff9f43) },
	{ Menu = "Dogs", Label = "DOGS", Icon = "dog", Color = rgb(0x3fa7ff) },
	{ Menu = "Inventario", Label = "EGGS", Icon = "egg", Color = rgb(0xffbf2e) },
	{ Menu = "Map", Label = "MAP", Icon = "map", Color = rgb(0x22c8ad) },
	{ Menu = "Boss", Label = "BOSS", Icon = "tower", Color = rgb(0x8f5cf0) },
	{ Menu = "Loja", Label = "SHOP", Icon = "gift", Color = rgb(0xff6fb0) },
}
-- 🏠 2026-10: sem casinha (Config.HOUSES = false) o botão HOME sai — ele só tinha casinha, estande e time
if not Config.HOUSES then
	table.remove(MENU, 1)
end
-- 🥚 2026-10-25: sem ovos (Config.EGGS = false, o dono: "tira o ovo e só deixa o spin") o botão EGGS sai
if not Config.EGGS then
	for i, m in ipairs(MENU) do
		if m.Menu == "Inventario" then
			table.remove(MENU, i)
			break
		end
	end
end
-- 🏰 2026-10: sem a Boss Tower (Config.BOSS_TOWER = false) o botão BOSS sai
if not Config.BOSS_TOWER then
	for i, m in ipairs(MENU) do
		if m.Menu == "Boss" then
			table.remove(MENU, i)
			break
		end
	end
end
local function menuColor(name)
	for _, m in ipairs(MENU) do
		if m.Menu == name then
			return m.Color
		end
	end
	return MENU[1].Color
end
local UTIL = {
	{ Menu = "Trade", Label = "TRADE", Icon = "trade", Color = rgb(0x3fa7ff) },
	{ Menu = "Codes", Label = "CODES", Icon = "key", Color = rgb(0xffbf2e) },
	{ Menu = "Settings", Label = "SETTINGS", Icon = "gear", Color = rgb(0x8d97b5) },
}

local function openOrSoon(menuName, labelText)
	if menus[menuName] then
		HUD.Toggle(menuName)
	else
		-- a tela ainda não existe (ou ainda está carregando): avisa sem quebrar
		HUD.Toast(labelText .. " is loading...", "gold")
	end
end

---------------------------------------------------------------- construção
function HUD.Start()
	gui, root = Kit.Screen("HUD", 5)
	-- ⏳ enquanto o servidor não manda o perfil (servidor abrindo, save carregando), um aviso no meio da tela — sem
	-- ele a tela ficava vazia e parecia que o jogo tinha quebrado
	local loading = nil
	if not Net.Profile then
		loading = label(root, "Loading your save...", 24, WHITE, LUCKY, {
			Name = "Loading",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.42),
			Size = UDim2.fromOffset(600, 40),
		})
		task.delay(20, function()
			if loading and loading.Parent then
				loading.Text = "Still loading your save... (if it takes too long, rejoin)"
			end
		end)
	end
	Net.WaitProfile()
	if loading then
		loading:Destroy()
		loading = nil
	end

	-- grupos com escala própria (no celular 1,15x)
	local function group(name, anchor, size)
		local f = make("Frame", { Name = name, AnchorPoint = anchor, Size = size, BackgroundTransparency = 1 }, root)
		return f, make("UIScale", {}, f)
	end
	local left, leftScale = group("Left", Vector2.new(0, 0), UDim2.fromOffset(216, 100))
	local center, centerScale = group("Center", Vector2.new(0.5, 0), UDim2.fromOffset(360, 160))
	local right, rightScale = group("Right", Vector2.new(1, 0), UDim2.fromOffset(170, 200))

	---------------------------------------------------------- cartão do cachorro (cima-esquerda) — sem retrato
	local cardHolder, card, cardPop = piece(left, { Name = "DogCard", Position = UDim2.fromOffset(24, 0), Size = UDim2.fromOffset(196, 52) }, COL.panel, 16, true)
	local cardGrad = card:FindFirstChild("TwoTone")
	if cardGrad then
		cardGrad:Destroy() -- (o cartão é clicável mas fica chapado)
	end
	pressable(card, cardPop)
	-- nível: moeda dourada saindo do lado esquerdo
	local levelHolder, levelBody = piece(cardHolder, {
		Name = "Level",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 2, 0.5, 0),
		Size = UDim2.fromOffset(46, 46),
		ZIndex = 6,
	}, COL.gold, 999)
	local levelScale = make("UIScale", {}, levelHolder)
	label(levelBody, "LV", 10, WHITE, LUCKY, {
		AutomaticSize = Enum.AutomaticSize.None,
		Position = UDim2.fromOffset(0, 4),
		Size = UDim2.new(1, 0, 0, 11),
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local levelText = label(levelBody, "1", 19, WHITE, LUCKY, {
		AutomaticSize = Enum.AutomaticSize.None,
		Position = UDim2.fromOffset(0, 16),
		Size = UDim2.new(1, 0, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	-- 🍼 (2026-10-24) reforço de iniciante ligado (Config.ROOKIE): mamadeira no cantinho do nível
	local rookieBadge = Icons.Make(cardHolder, "bottle", { Position = UDim2.fromOffset(14, -14), Size = UDim2.fromOffset(22, 22), ZIndex = 8, Visible = false })
	local nameRow = make("Frame", { Position = UDim2.fromOffset(30, 3), Size = UDim2.fromOffset(160, 17), BackgroundTransparency = 1 }, card)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, nameRow)
	local nameText = label(nameRow, "", 13, WHITE, LUCKY, { LayoutOrder = 1 })
	local starsText = label(nameRow, "", 10, GOLD_TEXT, FRED, { LayoutOrder = 2 })
	local hpBar = bar(card, { Position = UDim2.fromOffset(40, 21), Size = UDim2.fromOffset(148, 14) }, FILL.green, 10)
	Icons.Make(card, "heart", { Position = UDim2.fromOffset(27, 17), Size = UDim2.fromOffset(21, 21), ZIndex = 5 })
	local xpBar = bar(card, { Position = UDim2.fromOffset(40, 38), Size = UDim2.fromOffset(148, 9) }, FILL.xp, 8)
	card.Activated:Connect(function()
		HUD.Toggle("Dogs") -- clicar no cartão abre os DOGS
	end)

	---------------------------------------------------------- QUESTS + TRADE / CODES / SETTINGS (linha pequena)
	local questHolder, questBody, questPop = piece(left, { Name = "Missoes", Position = UDim2.fromOffset(0, 62), Size = UDim2.fromOffset(96, 28) }, COL.teal, 999, true)
	Icons.Make(questBody, "scroll", { Position = UDim2.fromOffset(-6, -6), Size = UDim2.fromOffset(34, 34), ZIndex = 3 })
	local questLabel = label(questBody, "QUESTS", 12, WHITE, LUCKY, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 28, 0.5, 1) })
	local questBadge = badge(questBody, 18)
	pressable(questBody, questPop)
	questBody.Activated:Connect(function()
		openOrSoon("Missoes", "QUESTS")
	end)
	buttons.Missoes = questHolder
	-- (o número do badge = missões prontas para pegar o prêmio)
	local externalQuestBadge = nil
	badgeSetters.Missoes = function(text)
		externalQuestBadge = text
		questBadge(text)
	end

	local utilButtons = {}
	for i, u in ipairs(UTIL) do
		local holder, body, pop = piece(left, { Name = u.Menu, Position = UDim2.fromOffset(104 + (i - 1) * 36, 62), Size = UDim2.fromOffset(28, 28) }, u.Color, 999, true)
		Icons.Make(body, u.Icon, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.82, 0.82),
			ZIndex = 3,
		})
		pressable(body, pop)
		body.Activated:Connect(function()
			openOrSoon(u.Menu, u.Label)
		end)
		badgeSetters[u.Menu] = badge(body, 16)
		utilButtons[i] = { Holder = holder }
		buttons[u.Menu] = holder
	end

	local function refreshQuests()
		local s = questState
		local daily = s and s.Daily or {}
		local claimable, done, total = 0, 0, 0
		for _, m in ipairs(daily) do
			total += 1
			local goal = math.max(1, m.Goal or 1)
			if m.Claimed then
				done += 1
			elseif (m.Count or 0) >= goal then
				claimable += 1
			end
		end
		questLabel.Text = total > 0 and string.format("QUESTS %d/%d", done, total) or "QUESTS"
		questHolder.Size = UDim2.fromOffset(math.ceil(textWidth(questLabel.Text, 12, LUCKY)) + 40, 28)
		local w = questHolder.Size.X.Offset
		for i, u in ipairs(utilButtons) do
			u.Holder.Position = UDim2.fromOffset(w + 8 + (i - 1) * 36, 62)
		end
		if externalQuestBadge == nil then
			questBadge(claimable > 0 and tostring(claimable) or nil)
		end
		return claimable
	end
	onQuests = refreshQuests
	refreshQuests()

	---------------------------------------------------------- chip da ilha (cima-meio)
	local islandHolder, islandBody = piece(center, {
		Name = "Island",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 4),
		Size = UDim2.fromOffset(220, 28),
	}, COL.green, 999)
	Icons.Make(islandBody, "island", { Position = UDim2.fromOffset(-6, -9), Size = UDim2.fromOffset(40, 40), ZIndex = 3 })
	local islandName = label(islandBody, "", 14, WHITE, LUCKY, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 36, 0.5, 1) })
	local islandSub = label(islandBody, "", 10, rgb(0xf2ffe6), FRED, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 36, 0.5, 1) })

	local function refreshIsland()
		local where = player:GetAttribute("Island")
		local def = Islands.List[where]
		local name, sub, color
		if def then
			name = string.upper(def.Name)
			sub = "Wild Lv." .. def.Levels[1] .. "-" .. def.Levels[2]
			color = Islands.SWIRL[where] or Islands.COLORS[where]
		elseif where == "colosseum" then
			name = "COLOSSEUM"
			sub = workspace:GetAttribute("SuperBossAwake") and "Super Boss! PvP paused" or "PvP ON"
			color = rgb(0xff6a5a)
		elseif where == Village.Id then
			name = string.upper(Village.Name)
			sub = "Safe zone"
			color = Village.Color
		else
			name = "HOME ISLAND"
			sub = "Safe zone"
			color = Islands.COLORS.main
		end
		islandName.Text = name
		islandSub.Text = sub
		local nameW = textWidth(name, 14, LUCKY)
		local subW = textWidth(sub, 10, FRED)
		islandSub.Position = UDim2.new(0, 36 + nameW + 7, 0.5, 1)
		islandHolder.Size = UDim2.fromOffset(math.ceil(36 + nameW + 7 + subW + 14), 28)
		-- (cor chapada da ilha, um pouco mais escura para o texto branco aparecer)
		islandBody.BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.18)
	end
	player:GetAttributeChangedSignal("Island"):Connect(refreshIsland)
	workspace:GetAttributeChangedSignal("SuperBossAwake"):Connect(refreshIsland)
	refreshIsland()

	---------------------------------------------------------- linha do OBJETIVO (só quando importa)
	local goalHolder, goalBody, goalPop = piece(center, {
		Name = "Goal",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 40),
		Size = UDim2.fromOffset(300, 34),
		Visible = false,
	}, COL.panel, 12, true)
	local goalGrad = goalBody:FindFirstChild("TwoTone")
	if goalGrad then
		goalGrad:Destroy()
	end
	goalBody.BackgroundTransparency = 0.06
	local goalIcon = Icons.Make(goalBody, "target", { Position = UDim2.fromOffset(-8, -6), Size = UDim2.fromOffset(36, 36), ZIndex = 3 })
	local goalRow = make("Frame", { Position = UDim2.fromOffset(32, 1), Size = UDim2.new(1, -40, 0, 16), BackgroundTransparency = 1 }, goalBody)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, goalRow)
	local goalTag = label(goalRow, "NEXT:", 11, GOLD_TEXT, LUCKY, { LayoutOrder = 1 })
	local goalText = label(goalRow, "", 11, WHITE, FRED, { LayoutOrder = 2 })
	local goalBar = bar(goalBody, { Position = UDim2.fromOffset(32, 19), Size = UDim2.new(1, -42, 0, 10) }, FILL.green, 8)
	goalBar.Label.Visible = false
	local goalMenu = "Map"
	pressable(goalBody, goalPop)
	goalBody.Activated:Connect(function()
		openOrSoon(goalMenu, "MAP")
	end)
	-- dicas (TIP) aparecem um pouco e somem; missão, 1º cachorro, ilha pronta e boss acordado ficam
	local goalKey, goalShownAt, goalSticky = nil, 0, false
	local TIP_TIME = 9

	-- acordado: quanto falta para ele voltar a dormir; dormindo: quanto falta para acordar (WorldBoss: 30 min / 10 min)
	local function bossClock()
		local awake = workspace:GetAttribute("SuperBossAwake") == true
		local left = tonumber(workspace:GetAttribute(awake and "SuperBossLeft" or "SuperBossIn")) or 0
		return awake, left
	end

	-- o que a linha mostra agora: tag, texto, barra (0..1), cor da barra, ícone, fica? (false = dica que some)
	local function goalNow(p)
		local unlocked = type(p.Islands) == "table" and p.Islands or {}
		local cash = p.Cash or 0
		-- 🎓 ainda sem cachorro: o objetivo é falar com o professor no canil da Pawville
		if not p.Started then
			return "FIRST:", "Get your dog from " .. Config.STARTER_ROLL.Professor, 0, FILL.gold, "dog", true
		end
		-- 📜 a MISSÃO do NPC da ilha (QuestService: atributos Quest*) — estilo Blox Fruits
		local questText = player:GetAttribute("QuestText")
		if questText then
			local have = player:GetAttribute("QuestHave") or 0
			local need = math.max(1, player:GetAttribute("QuestNeed") or 1)
			local qIsland = Islands.List[player:GetAttribute("QuestIsland") or ""]
			local where = qIsland and player:GetAttribute("Island") ~= qIsland.Id and (" (" .. qIsland.Name .. ")") or ""
			local boss = player:GetAttribute("QuestKind") == "boss"
			return boss and "BOSS:" or "MISSION:", stripEmoji(questText) .. where .. "  " .. have .. "/" .. need, have / need, FILL.gold, boss and "crown" or "scroll", true
		end
		-- 🌍 Super Boss acordado
		local awake, left = bossClock()
		if awake then
			return "BOSS:", "Super Boss is UP! " .. Config.FormatTime(left) .. " left", 1, FILL.red, "boss", true
		end
		-- 🏡 na Pawville com cachorro: a aventura começa na ilha principal (dica)
		if player:GetAttribute("Island") == Village.Id and not unlocked.uncommon then
			return "TIP:", "Take the ARENA portal, then the Puppy Meadows portal", 0, FILL.gold, "portal", false
		end
		-- 🔐 próxima ilha (cada vez mais difícil — Islands.Requirements): pronta para abrir, ou o próximo passo
		local nextStep = nil
		for _, id in ipairs(Islands.ORDER) do
			local def = Islands.List[id]
			if def and (def.Price or 0) > 0 and not unlocked[id] and Islands.CanUnlock(unlocked, id) then
				local list, ok = Islands.Requirements(p, id, Islands.EquippedLevel(p))
				if ok then
					return "READY:", "Unlock " .. def.Name .. " in the MAP!", 1, FILL.gold, "map", true
				end
				for _, r in ipairs(list) do
					if not r.Done then
						nextStep = { Req = r, Island = def }
						break
					end
				end
				break
			end
		end
		-- 📜 numa ilha sem missão: onde pegar uma (dica) — a não ser que o próximo passo seja outro
		local here = Islands.List[player:GetAttribute("Island") or ""]
		local needMissions = nextStep and nextStep.Req.Kind == "missions"
		if here and here.Quest and (not nextStep or needMissions) then
			return "TIP:", "Talk to the Mission NPC at the entrance", 0, FILL.gold, "alert", false
		end
		if nextStep then
			local r, name = nextStep.Req, nextStep.Island.Name
			if r.Kind == "champion" then
				return "NEXT:", "Beat " .. r.Name .. " to open " .. name, 0, FILL.gold, "crown", false
			elseif r.Kind == "missions" then
				return "NEXT:", r.Have .. "/" .. r.Need .. " missions in " .. r.Island .. " to open " .. name, r.Have / r.Need, FILL.gold, "scroll", false
			elseif r.Kind == "level" then
				return "NEXT:", "Dog Lv." .. r.Need .. " to open " .. name, r.Have / r.Need, FILL.gold, "up", false
			elseif r.Kind == "cash" then
				return "NEXT:", "$" .. money(r.Need) .. " to open " .. name, cash / math.max(1, r.Need), FILL.gold, "coins", false
			end
		end
		return nil
	end

	local function placeGoal()
		local show = goalHolder:GetAttribute("Want") == true and topReserve <= 0
		if goalHolder.Visible ~= show then
			goalHolder.Visible = show
		end
	end

	local function refreshGoal(p)
		p = p or Net.Profile
		if not p then
			return
		end
		local tag, text, pct, color, icon, sticky = goalNow(p)
		local key = tag and (tag .. text) or nil
		if key ~= goalKey then
			goalKey = key
			goalShownAt = os.clock()
			goalSticky = sticky == true
			if key then
				local holderWasHidden = not goalHolder.Visible
				goalHolder:SetAttribute("Want", true)
				placeGoal()
				if holderWasHidden and goalHolder.Visible then
					Kit.Pop(goalPop, true)
				end
			end
		end
		-- dica: some sozinha depois de um tempo (o objetivo de verdade fica)
		local want = key ~= nil and (goalSticky or os.clock() - goalShownAt < TIP_TIME)
		goalHolder:SetAttribute("Want", want)
		placeGoal()
		if not key then
			return
		end
		goalMenu = "Map"
		goalTag.Text = tag
		goalText.Text = text
		Icons.Set(goalIcon, icon)
		goalBar.Set(pct)
		goalBar.Paint(color)
		goalBar.Frame.Visible = pct > 0 and pct < 1 or tag == "MISSION:" or tag == "BOSS:"
		local w = textWidth(tag, 11, LUCKY) + 4 + textWidth(text, 11, FRED)
		local size = UDim2.fromOffset(math.clamp(math.ceil(w) + 48, 180, 380), goalBar.Frame.Visible and 34 or 22)
		if goalHolder.Size ~= size then
			goalHolder.Size = size
		end
	end
	-- a missão muda (aceitou, contou mais um, completou) ou o jogador muda de ilha: redesenha a linha
	for _, attr in ipairs({ "QuestText", "QuestHave", "QuestNeed", "QuestCash", "Island" }) do
		player:GetAttributeChangedSignal(attr):Connect(function()
			refreshGoal()
		end)
	end

	---------------------------------------------------------- avisos (embaixo da linha do objetivo)
	toastList = make("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 80),
		Size = UDim2.fromOffset(520, 70),
		BackgroundTransparency = 1,
		ZIndex = 15,
	}, center)
	make("UIListLayout", {
		Padding = UDim.new(0, 7),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, toastList)

	---------------------------------------------------------- dinheiro (cima-direita)
	local cashHolder, cashBody = piece(right, {
		Name = "Cash",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(160, 34),
	}, COL.cash, 999)
	Icons.Make(cashBody, "coins", { Position = UDim2.fromOffset(-14, -9), Size = UDim2.fromOffset(48, 48), ZIndex = 3 })
	local cashText = label(cashBody, "$0", 18, WHITE, LUCKY, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 36, 0.5, 1) })
	local cashScale = make("UIScale", {}, cashText)
	local _, plusBody, plusPop = piece(cashBody, {
		Name = "Plus",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -4, 0.5, -1),
		Size = UDim2.fromOffset(24, 24),
		ZIndex = 4,
	}, COL.gold, 999, true)
	Icons.Make(plusBody, "plus", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.78, 0.78), ZIndex = 5 })
	pressable(plusBody, plusPop)
	plusBody.Activated:Connect(function()
		openOrSoon("Loja", "SHOP")
	end)

	---------------------------------------------------------- chip do SUPER BOSS
	local _, bossBody, bossPop = piece(right, {
		Name = "SuperBoss",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 42),
		Size = UDim2.fromOffset(150, 28),
	}, COL.purple, 999, true)
	local bossIcon = Icons.Make(bossBody, "boss", { Position = UDim2.fromOffset(-6, -6), Size = UDim2.fromOffset(36, 36), ZIndex = 3 })
	local bossTitle = label(bossBody, "SUPER BOSS", 10, WHITE, LUCKY, { Position = UDim2.fromOffset(30, 1) })
	local bossTimer = label(bossBody, "", 10, rgb(0xf1e6ff), FRED, { Position = UDim2.fromOffset(30, 13) })
	pressable(bossBody, bossPop)
	bossBody.Activated:Connect(function()
		openOrSoon("Map", "MAP")
	end)
	local bossAwakeShown = nil
	local stopBossPulse = nil
	local function refreshBoss()
		local awake, left = bossClock()
		if awake ~= bossAwakeShown then
			bossAwakeShown = awake
			bossTitle.Text = awake and "BOSS IS UP!" or "SUPER BOSS"
			bossTitle.TextColor3 = awake and GOLD_TEXT or WHITE
			bossBody.BackgroundColor3 = awake and rgb(0xe23b54) or COL.purple
			if awake and not stopBossPulse then
				stopBossPulse = Kit.Pulse(bossIcon, 0.12, 0.7)
			elseif not awake and stopBossPulse then
				stopBossPulse()
				stopBossPulse = nil
			end
		end
		bossTimer.Text = awake and (Config.FormatTime(left) .. " left") or ("wakes in " .. Config.FormatTime(left))
	end

	---------------------------------------------------------- ⏱️ turbinadas da loja (só aparecem enquanto valem)
	-- (Cash Rush / Lucky Rush: chip pequeno ao lado do SUPER BOSS com o tempo que falta; clique = loja nas turbinadas)
	local boostChips = {}
	for i, b in ipairs({ { Kind = "Cash", Icon = "coins", Color = COL.cash }, { Kind = "Luck", Icon = "clover", Color = COL.teal } }) do
		local holder, body, pop = piece(right, {
			Name = "Boost" .. b.Kind,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -158, 0, 42),
			Size = UDim2.fromOffset(74, 28),
			Visible = false,
		}, b.Color, 999, true)
		Icons.Make(body, b.Icon, { Position = UDim2.fromOffset(-6, -5), Size = UDim2.fromOffset(32, 32), ZIndex = 3 })
		local text = label(body, "", 12, WHITE, LUCKY, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 28, 0.5, 1) })
		pressable(body, pop)
		body.Activated:Connect(function()
			openOrSoon("Loja", "SHOP")
			local shop = HUD.GetMenu("Loja")
			if shop and shop.Tab then
				shop.Tab("boosts")
			end
		end)
		boostChips[i] = { Holder = holder, Text = text, Kind = b.Kind }
	end
	local function refreshBoosts()
		local x = 158
		for _, chip in ipairs(boostChips) do
			local left = Monetization.BoostLeft(player, chip.Kind)
			chip.Holder.Visible = left > 0
			if left > 0 then
				chip.Holder.Position = UDim2.new(1, -x, 0, 42)
				chip.Text.Text = left >= 3600 and string.format("%dh%02d", left // 3600, (left % 3600) // 60) or Config.FormatTime(left)
				x += 80
			end
		end
	end

	---------------------------------------------------------- 🗺️ minimapa (só no PC)
	-- (2026-10-24, pedido do dono: "quero que esse radar vire o mapa realmente mostrando o mapa") embaixo dos pontinhos
	-- fica o MAPA DESENHADO de verdade (UI/WorldMap: as ilhas com contorno, praia, Coliseu, pontes, ruas e portais),
	-- girando junto com a câmera (para a frente = para cima). Clique no minimapa = mais perto / mais longe.
	local RADAR = 124
	local radarHolder, radarBody = piece(right, {
		Name = "Radar",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 80),
		Size = UDim2.fromOffset(RADAR, RADAR),
	}, WorldMap.OCEAN, 999)
	local mapCanvas = make("CanvasGroup", {
		Name = "Mapa",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WorldMap.OCEAN,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, radarBody)
	Kit.Corner(mapCanvas, 999)
	local mapPivot = make("Frame", {
		Name = "Giro",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		ZIndex = 3,
	}, mapCanvas)
	local mapZoom = make("UIScale", { Name = "Zoom" }, mapPivot)
	-- eu: setinha branca no meio, apontando para onde o cachorro olha
	local meMark = label(radarBody, "▲", 15, WHITE, Enum.Font.GothamBlack, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		AutomaticSize = Enum.AutomaticSize.None,
		Size = UDim2.fromOffset(16, 16),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 9,
	})
	local north = label(radarBody, "N", 10, WHITE, LUCKY, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 9),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 9,
	})
	local RANGE_NEAR, RANGE_FAR = 320, 1000
	local RADAR_RANGE = RANGE_NEAR
	local MAP_SCALE = (RADAR / 2 - 8) / RANGE_NEAR -- px por stud no zoom de perto (o mesmo dos pontinhos)
	local mapWorld = WorldMap.Build(mapPivot, MAP_SCALE)
	-- clique: perto <-> longe (o "+"/"−" no canto mostra que dá para clicar)
	local zoomChip = label(radarBody, "−", 13, WHITE, LUCKY, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.85, 0, 0.85, 0),
		AutomaticSize = Enum.AutomaticSize.None,
		Size = UDim2.fromOffset(18, 18),
		BackgroundTransparency = 0,
		BackgroundColor3 = COL.panel,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 9,
	})
	Kit.Corner(zoomChip, 999)
	inkStroke(zoomChip, 1.6)
	local zoomButton = make("TextButton", {
		Name = "Zoom",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 10,
	}, radarBody)
	zoomButton.Activated:Connect(function()
		RADAR_RANGE = RADAR_RANGE == RANGE_NEAR and RANGE_FAR or RANGE_NEAR
		mapZoom.Scale = RANGE_NEAR / RADAR_RANGE
		zoomChip.Text = RADAR_RANGE == RANGE_NEAR and "−" or "+"
	end)
	-- pontinhos dos cachorros: DENTRO do mapa (giram junto com ele); tamanho e contorno descontam o zoom
	local dotPool, iconPool = {}, {}
	local function radarDot(i, color)
		local d = dotPool[i]
		if not d then
			d = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, ZIndex = 30 }, mapWorld)
			Kit.Corner(d, 999)
			inkStroke(d, 1.4)
			dotPool[i] = d
		end
		local z = mapZoom.Scale
		d.Size = UDim2.fromOffset(9 / z, 9 / z)
		d:FindFirstChildOfClass("UIStroke").Thickness = 1.4 / z
		d.BackgroundColor3 = color
		d.Visible = true
		return d
	end
	local function radarIcon(i, name)
		local d = iconPool[i]
		if not d then
			d = Icons.Make(radarBody, name, { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(20, 20), ZIndex = 6 })
			iconPool[i] = d
		end
		Icons.Set(d, name)
		d.Visible = true
		return d
	end
	-- câmera "deitada" (frente e direita no chão) e o cachorro do jogador
	local function radarBasis()
		local cam = workspace.CurrentCamera
		local character = player.Character
		local me = character and character.PrimaryPart
		if not (cam and me) then
			return nil
		end
		local look = cam.CFrame.LookVector
		local fwd = Vector3.new(look.X, 0, look.Z)
		fwd = fwd.Magnitude > 0.01 and fwd.Unit or Vector3.new(0, 0, -1)
		return me, fwd, Vector3.new(-fwd.Z, 0, fwd.X)
	end
	-- ícones presos na borda quando longe (chefe, campeão e portal de volta da ilha): { Part = peça | Pos = ponto, Name }
	local iconTargets = {}
	-- 10x por segundo: quem aparece (pontinhos e ícones)
	local function updateRadar()
		local me = radarBasis()
		if not me then
			return
		end
		local character = player.Character
		local origin = me.Position
		local reach = (RADAR_RANGE * 1.5) ^ 2
		local nDot = 0
		table.clear(iconTargets)
		local folder = workspace:FindFirstChild("Cachorros")
		for _, model in ipairs(folder and folder:GetChildren() or {}) do
			local root = model:IsA("Model") and model.PrimaryPart
			if root and model ~= character then
				local kind = model:GetAttribute("Kind")
				if kind == "boss" then
					table.insert(iconTargets, { Part = root, Name = "boss" })
				elseif kind == "npc" or (kind == "player" and model:GetAttribute("Owner") ~= player.UserId) then
					local p = root.Position
					local dx, dz = p.X - origin.X, p.Z - origin.Z
					if dx * dx + dz * dz < reach then
						nDot += 1
						radarDot(nDot, kind == "npc" and rgb(0xff4b4b) or rgb(0x4aa8ff)).Position =
							UDim2.fromOffset(p.X * MAP_SCALE, p.Z * MAP_SCALE)
					end
				end
			end
		end
		for i = nDot + 1, #dotPool do
			dotPool[i].Visible = false
		end
		local where = player:GetAttribute("Island")
		local def = Islands.List[where]
		if def then
			if def.ChampionAt then
				local at = def.ChampionAt
				table.insert(iconTargets, { Pos = Islands.ToWorld(where, at.X, at.Y, at.Z), Name = "crown" })
			end
			if def.Portal then
				table.insert(iconTargets, { Pos = Islands.ToWorld(where, def.Portal.X, def.Portal.Y, def.Portal.Z), Name = "portal" })
			end
		end
	end
	-- a cada quadro: o mapa gira e anda (liso), a setinha, o N e os ícones da borda
	local function updateRadarView()
		local me, fwd, rightV = radarBasis()
		if not me then
			return
		end
		local origin = me.Position
		local R = RADAR / 2 - 8
		mapPivot.Rotation = math.deg(math.atan2(-fwd.X, -fwd.Z))
		mapWorld.Position = UDim2.fromOffset(-origin.X * MAP_SCALE, -origin.Z * MAP_SCALE)
		local look = me.CFrame.LookVector
		meMark.Rotation = math.deg(math.atan2(look:Dot(rightV), look:Dot(fwd)))
		local n = 0
		for _, target in ipairs(iconTargets) do
			local pos = target.Part and target.Part.Parent and target.Part.Position or target.Pos
			if pos then
				local d = pos - origin
				local x, y = d:Dot(rightV), -d:Dot(fwd)
				local dist = math.sqrt(x * x + y * y)
				if dist > RADAR_RANGE then
					x, y = x / dist * RADAR_RANGE, y / dist * RADAR_RANGE
				end
				n += 1
				radarIcon(n, target.Name).Position = UDim2.new(0.5, x / RADAR_RANGE * R, 0.5, y / RADAR_RANGE * R)
			end
		end
		for i = n + 1, #iconPool do
			iconPool[i].Visible = false
		end
		-- N gira na borda: norte = −Z
		local nx, ny = -rightV.Z, fwd.Z
		local len = math.max(0.001, math.sqrt(nx * nx + ny * ny))
		north.Position = UDim2.new(0.5, nx / len * (R + 1), 0.5, ny / len * (R + 1))
	end

	---------------------------------------------------------- botões dos menus (direita)
	local side = make("Frame", {
		Name = "Side",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 300),
		Size = UDim2.fromOffset(54, 300),
		BackgroundTransparency = 1,
	}, root)
	local grid = make("UIGridLayout", {
		CellPadding = UDim2.fromOffset(8, 8),
		CellSize = UDim2.fromOffset(54, 54),
		FillDirection = Enum.FillDirection.Horizontal,
		FillDirectionMaxCells = 1,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, side)
	local menuButtons = {}
	for i, m in ipairs(MENU) do
		local holder, body, pop = piece(side, { Name = m.Menu, LayoutOrder = i }, m.Color, 14, true)
		Icons.Make(body, m.Icon, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0.02, 0),
			Size = UDim2.fromScale(0.72, 0.72),
			ZIndex = 3,
		})
		local text = label(body, m.Label, 10, WHITE, LUCKY, {
			AnchorPoint = Vector2.new(0.5, 1),
			AutomaticSize = Enum.AutomaticSize.None,
			Position = UDim2.new(0.5, 0, 1, 1),
			Size = UDim2.new(1, 0, 0.3, 0),
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 4,
		})
		pressable(body, pop)
		body.Activated:Connect(function()
			openOrSoon(m.Menu, m.Label)
		end)
		badgeSetters[m.Menu] = badge(body, 18)
		menuButtons[m.Menu] = {
			Holder = holder,
			Body = body,
			Label = text,
			Stroke = body:FindFirstChildOfClass("UIStroke"),
			Color = m.Color,
		}
		buttons[m.Menu] = holder
		if m.Menu == "Loja" then
			-- fitinha "STARTER PACK" piscando em cima do botão SHOP
			-- (embaixo do botão: não tampa os outros botões, nem em coluna nem em grade)
			local ribbonHolder, ribbonBody = piece(body, {
				Name = "Ribbon",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 1, 2),
				Size = UDim2.fromOffset(70, 16),
				Rotation = -5,
				ZIndex = 20,
			}, COL.gold, 6)
			label(ribbonBody, "STARTER PACK", 8, WHITE, LUCKY, {
				AutomaticSize = Enum.AutomaticSize.None,
				Size = UDim2.fromScale(1, 1),
				TextXAlignment = Enum.TextXAlignment.Center,
			})
			Kit.Pulse(ribbonHolder, 0.07, 0.8)
			starterRibbon = { Frame = ribbonHolder }
		end
	end
	refreshStarterRibbon()
	player:GetAttributeChangedSignal("StarterPack"):Connect(refreshStarterRibbon)

	local function paintMenuButton(menuName, color)
		local mb = menuButtons[menuName]
		if mb and mb.Body.BackgroundColor3 ~= color then
			mb.Body.BackgroundColor3 = color
		end
	end

	HUD.MenuChanged:Connect(function(name)
		for menuName, mb in pairs(menuButtons) do
			if mb.Stroke then
				mb.Stroke.Color = menuName == name and WHITE or INK
			end
		end
		if name == "Dogs" then
			HUD.SetBadge("Dogs", nil)
		end
	end)

	---------------------------------------------------------- chip de estado (centro-baixo)
	local chipHolder, chipBody = piece(root, {
		Name = "StatusChip",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -112),
		Size = UDim2.fromOffset(240, 26),
		Visible = false,
	}, COL.panel, 999)
	local chipIcon = Icons.Make(chipBody, "heart", { Position = UDim2.fromOffset(-4, -6), Size = UDim2.fromOffset(34, 34), ZIndex = 3 })
	local chipText = label(chipBody, "", 12, WHITE, FRED, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 33, 0.5, 0) })
	local chipScale = make("UIScale", {}, chipHolder)

	---------------------------------------------------------- faixas
	bannerHolder = make("Frame", {
		Name = "Banners",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 120),
		Size = UDim2.fromOffset(380, 70),
		BackgroundTransparency = 1,
		ZIndex = 20,
	}, root)
	local bannerScale = make("UIScale", {}, bannerHolder)

	---------------------------------------------------------- arrumação (PC / celular, muda com a tela)
	local G = 1
	local goalY = 40
	local function moveToasts()
		local y = topReserve > 0 and (goalY + topReserve / G) or (goalY + (goalHolder.Visible and goalHolder.Size.Y.Offset + 8 or 0))
		local want = UDim2.new(0.5, 0, 0, y)
		if toastList.Position ~= want then
			toastList.Position = want
		end
	end
	local function placeToasts()
		placeGoal()
		moveToasts()
	end
	onTopReserve = placeToasts
	goalHolder:GetPropertyChangedSignal("Visible"):Connect(moveToasts)
	goalHolder:GetPropertyChangedSignal("Size"):Connect(moveToasts)

	local function layout()
		local touch = Kit.IsTouch()
		G = touch and 1.15 or 1
		local top = Kit.TopInset()
		local screen = Kit.DesignSize()
		leftScale.Scale, centerScale.Scale, rightScale.Scale = G, G, G
		left.Position = UDim2.fromOffset(12, top + 10)
		right.Position = UDim2.new(1, -12, 0, top + 10)
		center.Position = UDim2.new(0.5, 0, 0, top - 30 > 0 and (top - 30) or 0)
		goalY = 40
		placeToasts()

		-- botões dos menus: PC em coluna embaixo do radar; celular em grade embaixo do dinheiro
		local cell, gap, cols, rows, sideTop
		local radarOn = not touch
		if touch then
			-- (dedo: botão menor que isso fica difícil de apertar no celular)
			cell, gap = 64, 8
			cols = math.min(#MENU, 2)
			rows = math.ceil(#MENU / cols)
			sideTop = top + 10 + 80 * G
			local maxBottom = screen.Y * 0.62
			if sideTop + rows * (cell + gap) > maxBottom then
				cell = math.clamp(math.floor((maxBottom - sideTop) / rows) - gap, 52, 64)
			end
		else
			cell, gap = 54, 8
			local function fit(withRadar)
				local topY = top + 10 + (withRadar and (80 + RADAR + 12) or 82) * G
				local avail = screen.Y - topY - 120
				for _, c in ipairs({ 1, 2 }) do
					local r = math.ceil(#MENU / c)
					if r * cell + (r - 1) * gap <= avail then
						return topY, c, r, avail
					end
				end
				return topY, 2, math.ceil(#MENU / 2), avail
			end
			local avail
			sideTop, cols, rows, avail = fit(true)
			if rows * cell + (rows - 1) * gap > avail then
				radarOn = false
				sideTop, cols, rows, avail = fit(false)
			end
			if rows * cell + (rows - 1) * gap > avail then
				cell = math.clamp(math.floor((avail - (rows - 1) * gap) / rows), 42, 54)
			end
		end
		grid.CellSize = UDim2.fromOffset(cell, cell)
		grid.CellPadding = UDim2.fromOffset(gap, gap)
		grid.FillDirectionMaxCells = cols
		side.Size = UDim2.fromOffset(cols * cell + (cols - 1) * gap, rows * cell + (rows - 1) * gap)
		side.Position = UDim2.new(1, -12, 0, sideTop)
		for _, mb in pairs(menuButtons) do
			mb.Label.TextSize = math.max(8, math.floor(cell * 0.19))
		end
		radarHolder.Visible = radarOn

		-- acima dos golpes
		chipHolder.Position = UDim2.new(0.5, 0, 1, touch and -126 or -112)
		chipScale.Scale = touch and 1.15 or 1
		bannerScale.Scale = touch and 0.9 or 1
		bannerHolder.Position = UDim2.new(0.5, 0, 0, top + (touch and 70 or 96))
	end
	Kit.OnResize(layout)

	---------------------------------------------------------- estado do cachorro (desmaio / recuperação)
	local koSince = nil
	local function onDogState()
		if player:GetAttribute("DogState") == "ko" then
			koSince = koSince or os.clock()
		else
			koSince = nil
		end
	end
	player:GetAttributeChangedSignal("DogState"):Connect(onDogState)
	onDogState()

	-- segundos até o cachorro desmaiado voltar (usa RespawnAt do servidor se existir)
	local function koLeft()
		local at = player:GetAttribute("RespawnAt")
		if type(at) == "number" then
			return math.max(0, math.ceil(at - workspace:GetServerTimeNow()))
		end
		return math.max(0, math.ceil(Config.KO_RESPAWN - (os.clock() - (koSince or os.clock()))))
	end
	HUD.KOLeft = koLeft

	local function dogStars(dog, model)
		local d: any = dog
		local stars = d and (d.Stars or d.Evolution) or nil
		if stars == nil and model then
			stars = model:GetAttribute("Stars")
		end
		if stars == nil and dog and type(ConfigAny.StarsFor) == "function" then
			local ok, value = pcall(ConfigAny.StarsFor, dog.Level)
			stars = ok and value or nil
		end
		return tonumber(stars) or 0
	end

	-- vida no cartão (várias vezes por segundo)
	local lastHpPct = -1
	local function refreshDogStatus()
		local model = myDogModel()
		local hum = model and model:FindFirstChildOfClass("Humanoid")
		local hp, maxHp = 0, 1
		if hum then
			hp, maxHp = math.max(0, hum.Health), math.max(1, hum.MaxHealth)
		end
		local ko = player:GetAttribute("DogState") == "ko"
		local recovering = model ~= nil and model:GetAttribute("Recovering") == true and not ko
		local pct = ko and 0 or hp / maxHp
		if math.abs(pct - lastHpPct) > 0.001 then
			hpBar.Set(pct, lastHpPct < 0)
			lastHpPct = pct
		end
		if ko then
			hpBar.Label.Text = "Back in " .. koLeft() .. "s"
			hpBar.Paint(FILL.red)
		elseif not hum then
			hpBar.Label.Text = "--"
			hpBar.Paint(FILL.green)
		else
			hpBar.Label.Text = commas(math.ceil(hp)) .. " / " .. commas(maxHp)
			hpBar.Paint(recovering and FILL.heal or (pct < 0.3 and FILL.red or pct < 0.6 and FILL.orange or FILL.green))
		end
	end

	---------------------------------------------------------- atualização pelo perfil
	local lastCash = nil
	local lastDogId, lastLevel, lastXP = nil, nil, nil
	local lastStars = nil
	local xpFmt = function(n)
		return "XP " .. commas(n)
	end

	local function refresh()
		local p = Net.Profile
		if not p then
			return
		end
		-- dinheiro
		if lastCash and p.Cash ~= lastCash then
			local diff = p.Cash - lastCash
			Kit.FloatText(cashHolder, UDim2.new(0.55, 0, 1, 14), (diff > 0 and "+$" or "-$") .. money(math.abs(diff)), diff > 0 and CASH_TEXT or RED_TEXT, 16)
			cashScale.Scale = diff > 0 and 1.12 or 0.92
			Kit.Tween(cashScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		end
		lastCash = p.Cash
		Kit.CountTo(cashText, p.Cash, function(n)
			return "$" .. money(n)
		end, 0.7)
		refreshStarterRibbon()
		refreshGoal(p)

		-- aviso na CASA quando dá para comprar alguma melhoria
		local canBuy = false
		local nextHouse = Config.HOUSE[(p.HouseLevel or 1) + 1]
		if nextHouse and p.Cash >= nextHouse.Cost then
			canBuy = true
		end
		local nextStand = Config.STAND[(p.Stand or 1) + 1]
		if nextStand and p.Cash >= nextStand.Cost then
			canBuy = true
		end
		HUD.SetBadge("Shop", canBuy and "!" or nil)

		-- cachorro equipado
		local dog = Net.Equipped()
		cardHolder.Visible = dog ~= nil
		if not dog then
			return
		end
		local species = DogData.Species[dog.Species]
		if not species then
			return
		end
		local name = string.upper(dog.Name)
		nameText.Text = name
		nameText.TextSize = #name > 10 and math.max(10, math.floor(13 * 10 / #name)) or 13
		levelText.Text = tostring(dog.Level)
		levelText.TextSize = dog.Level >= 100 and 15 or 19
		rookieBadge.Visible = type(ConfigAny.RookieBoost) == "function" and ConfigAny.RookieBoost(dog.Level) > 0
		local stars = dogStars(dog, myDogModel())
		starsText.Text = Kit.StarsText(stars)
		if lastStars and stars > lastStars and dog.Id == lastDogId then
			Kit.Burst(card, UDim2.fromOffset(150, 10), GOLD_TEXT, 10, { "★", "✦" }, 60)
		end
		lastStars = stars

		local maxed = dog.Level >= Config.MAX_LEVEL
		local need = Config.XPToNext(dog.Level)
		local pct = maxed and 1 or math.clamp(dog.XP / need, 0, 1)
		xpFmt = function(n)
			return maxed and "XP MAX" or ("XP " .. commas(n) .. " / " .. commas(need))
		end
		if dog.Id ~= lastDogId then
			-- trocou de cachorro: mostra direto
			xpBar.Set(pct, true)
			Kit.CountSet(xpBar.Label, dog.XP, xpFmt)
			lastHpPct = -1
		elseif dog.Level ~= lastLevel then
			-- subiu de level: enche a barra, brilha e recomeça
			xpBar.Set(1)
			task.delay(0.35, function()
				xpBar.Set(0, true)
				xpBar.Set(pct)
			end)
			Kit.CountSet(xpBar.Label, dog.XP, xpFmt)
			Kit.Shine(card)
			levelScale.Scale = 1.35
			Kit.Tween(levelScale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
		else
			xpBar.Set(pct)
			Kit.CountTo(xpBar.Label, dog.XP, xpFmt, 0.4)
			if lastXP and dog.XP > lastXP then
				Kit.FloatText(card, UDim2.fromOffset(150, 52), "+" .. commas(dog.XP - lastXP) .. " XP", rgb(0x8fdcff), 14)
			end
		end
		lastDogId, lastLevel, lastXP = dog.Id, dog.Level, dog.XP
	end
	Net.Changed.Event:Connect(refresh)
	refresh()

	---------------------------------------------------------- relógios (5x por segundo)
	local lastQuestTick = 0
	local function tick()
		local p = Net.Profile
		if p then
			refreshGoal(p)
		end

		refreshDogStatus()
		refreshBoss()
		refreshBoosts()
		if os.clock() - lastQuestTick > 1 then
			lastQuestTick = os.clock()
			refreshQuests()
		end

		-- chip: só o que precisa de atenção (o duelo em si aparece na barra VS do Targeting)
		local mode = player:GetAttribute("ArenaMode") or "off"
		local state = player:GetAttribute("DogState")
		local inTower = player:GetAttribute("InTower") == true
		local dog = Net.Equipped()
		local name = dog and dog.Name or "Your dog"
		local text, color, icon = nil, WHITE, "paw"
		if state == "ko" then
			text, color, icon = name .. " fainted... back in " .. koLeft() .. "s", RED_TEXT, "heart"
		elseif not inTower then
			if state == "toArena" then
				text, color, icon = name .. " is heading to the Arena...", GOLD_TEXT, "paw"
			elseif state == "toHome" then
				text, color, icon = name .. " is coming back...", rgb(0xffbe6a), "paw"
			elseif mode ~= "off" then
				local streak = p and p.Streak or 0
				if streak > 0 and not duelTarget() then
					text, color, icon = streak .. " win streak!", rgb(0xffbe6a), "fire"
				end
			end
		end
		chipHolder.Visible = text ~= nil
		if text then
			chipText.Text = text
			chipText.TextColor3 = color
			Icons.Set(chipIcon, icon)
			chipHolder.Size = UDim2.fromOffset(math.ceil(textWidth(text, 12, FRED)) + 46, 26)
		end
		paintMenuButton("Map", mode == "pvp" and COL.red or menuColor("Map"))
	end
	task.spawn(function()
		while true do
			local ok, err = pcall(tick)
			if not ok then
				warn("[HUD]", err)
			end
			task.wait(0.2)
		end
	end)
	task.spawn(function()
		while true do
			if radarHolder.Visible and gui.Enabled then
				local ok, err = pcall(updateRadar)
				if not ok then
					warn("[HUD radar]", err)
				end
			end
			task.wait(0.1)
		end
	end)
	RunService.RenderStepped:Connect(function()
		if radarHolder.Visible and gui.Enabled then
			local ok, err = pcall(updateRadarView)
			if not ok then
				warn("[HUD minimapa]", err)
			end
		end
	end)

	---------------------------------------------------------- Esc / B fecham menus
	UserInputService.InputBegan:Connect(function(input, processed)
		if not openMenu or UserInputService:GetFocusedTextBox() then
			return
		end
		local key = input.KeyCode
		if key == Enum.KeyCode.ButtonB or key == Enum.KeyCode.Escape or (key == Enum.KeyCode.B and not processed) then
			HUD.CloseAll()
		end
	end)

	---------------------------------------------------------- avisos e faixas do servidor
	Net.Remotes.Notify.OnClientEvent:Connect(HUD.Toast)
	Net.Remotes.LevelUp.OnClientEvent:Connect(function(name, speciesId, oldLevel, newLevel)
		local species = DogData.Species[speciesId]
		HUD.Banner(string.upper((species and species.Name or "") .. " " .. name), "⭐ LEVEL UP!", "LV." .. oldLevel .. "  →  LV." .. newLevel, GOLD_TEXT)
	end)
	Net.Remotes.FoodReward.OnClientEvent:Connect(function(name, speciesId, amount, oldLevel, newLevel)
		-- (comida sem subir de nível: só um aviso pequeno; subiu: a fita)
		if oldLevel == newLevel then
			HUD.Toast("🍖 +" .. Config.Format(amount) .. " XP for " .. tostring(name), "xp")
			return
		end
		local species = DogData.Species[speciesId]
		HUD.Banner(
			string.upper((species and species.Name or "") .. " " .. name),
			"🍖 +" .. Config.Format(amount) .. " XP!",
			"LV." .. oldLevel .. "  →  LV." .. newLevel,
			rgb(0x8fdcff)
		)
	end)

	HUD.Gui = gui
	HUD.Root = root
	-- 🎓 (2026-10) sem cachorro ainda (perfil novo) o HUD aparece do mesmo jeito: a linha FIRST mostra o caminho até o
	-- professor. O cartão do cachorro já some sozinho sem cachorro (refresh)
	gui.Enabled = true
end

return HUD
