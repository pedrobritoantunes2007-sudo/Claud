-- Kit visual da interface: cores, fonte, botões cartoon grandes com contorno, painéis, janelas,
-- barras, contadores animados, partículas de UI e um visualizador (ViewportFrame) do cachorro.
-- 🎨 (2026-10-24, pedido do dono: "não quero 3D, quero cartoon, tipo os golpes"): tudo CHAPADO — sem degradê de
-- brilho —, contorno escuro grosso (Kit.INK, o mesmo dos ícones UI/Icons), botões em 2 tons (metade de cima mais
-- clara, corte reto) e o cachorro das telas com luz chapada (cara de desenho).
-- Responsivo: Kit.Screen cria uma ScreenGui com uma "Root" escalada pelo tamanho da tela, então tudo
-- dentro dela é desenhado em "pixels de design" (~1180x640) e encolhe/cresce igual no celular e no PC.
local Debris = game:GetService("Debris")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local DogBuilder = require(ReplicatedStorage.Shared.DogBuilder)
local DogData = require(ReplicatedStorage.Shared.DogData)
local Variants = require(ReplicatedStorage.Shared.Variants)
local Accessories = require(ReplicatedStorage.Shared.Accessories)
local Animator = require(script.Parent.Parent.Animator)
local Icons = require(script.Parent.Icons)

local Kit = {}

Kit.Font = Enum.Font.FredokaOne
Kit.Title = Enum.Font.LuckiestGuy -- títulos e números (letra de desenho)
-- 🎨 cartoon: roxo-azulado vivo nos painéis, cores fortes nos botões
Kit.C = {
	Bg = Color3.fromRGB(56, 42, 128),
	Panel = Color3.fromRGB(78, 62, 168),
	Panel2 = Color3.fromRGB(100, 84, 196),
	Text = Color3.fromRGB(255, 255, 255),
	Muted = Color3.fromRGB(214, 208, 255),
	Gold = Color3.fromRGB(255, 204, 51),
	Green = Color3.fromRGB(76, 217, 100),
	Red = Color3.fromRGB(255, 77, 94),
	Blue = Color3.fromRGB(63, 167, 255),
	Purple = Color3.fromRGB(166, 107, 255),
	Orange = Color3.fromRGB(255, 159, 28),
	Cash = Color3.fromRGB(141, 255, 110),
	Dark = Color3.fromRGB(36, 22, 58),
	Ink = Color3.fromRGB(36, 22, 58),
	Disabled = Color3.fromRGB(130, 124, 152),
	Locked = Color3.fromRGB(150, 92, 104),
	XP = Color3.fromRGB(94, 200, 255),
	Pink = Color3.fromRGB(255, 122, 182),
}
Kit.INK = Kit.C.Ink

-- Tamanho de referência do design (pixels "virtuais" dentro de Kit.Screen)
Kit.DESIGN = Vector2.new(1180, 640)

function Kit.make(className, props, parent)
	local inst = Instance.new(className)
	for k, v in pairs(props) do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end
local make = Kit.make

function Kit.Tween(inst, time, props, style, direction)
	local tween = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
	tween:Play()
	return tween
end

function Kit.Corner(parent, radius)
	return make("UICorner", { CornerRadius = radius and UDim.new(0, radius) or UDim.new(0, 14) }, parent)
end

function Kit.Stroke(parent, color, thickness)
	return make("UIStroke", {
		Color = color or Color3.new(0, 0, 0),
		Thickness = thickness or 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	}, parent)
end

-- 🎨 (cartoon) "degradê" de 2 cores com CORTE RETO no meio (desenho chapado, sem brilho liso de 3D)
function Kit.Gradient(parent, top, bottom, cut)
	local c = cut or 0.55
	return make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, top),
			ColorSequenceKeypoint.new(c, top),
			ColorSequenceKeypoint.new(math.min(1, c + 0.001), bottom),
			ColorSequenceKeypoint.new(1, bottom),
		}),
	}, parent)
end

-- 2 tons cartoon: metade de cima na cor, metade de baixo um pouco mais escura, CORTE RETO (sem degradê)
function Kit.TwoTone(parent, cut, shade)
	local dark = Color3.new(1, 1, 1):Lerp(Color3.new(0, 0, 0), shade or 0.14)
	local c = cut or 0.55
	return make("UIGradient", {
		Name = "TwoTone",
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(c, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(math.min(1, c + 0.001), dark),
			ColorSequenceKeypoint.new(1, dark),
		}),
	}, parent)
end

function Kit.Pad(parent, px)
	return make(
		"UIPadding",
		{ PaddingLeft = UDim.new(0, px), PaddingRight = UDim.new(0, px), PaddingTop = UDim.new(0, px), PaddingBottom = UDim.new(0, px) },
		parent
	)
end

function Kit.Text(parent, props)
	local label = make("TextLabel", {
		BackgroundTransparency = 1,
		Font = Kit.Font,
		TextColor3 = Kit.C.Text,
		TextScaled = true,
		Text = "",
	}, parent)
	for k, v in pairs(props) do
		if k ~= "Outline" then
			label[k] = v
		end
	end
	if props.Outline ~= false then
		make("UIStroke", { Thickness = 2, Color = Kit.C.Ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }, label)
	end
	return label
end

-- Contorno mais grosso num texto do Kit.Text (textos importantes do HUD, legíveis em fundo claro)
function Kit.Thick(label, thickness)
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Thickness = thickness or 3
	end
	return label
end

function Kit.Panel(parent, props)
	local frame = make("Frame", { BackgroundColor3 = Kit.C.Bg, BorderSizePixel = 0 }, parent)
	for k, v in pairs(props) do
		frame[k] = v
	end
	Kit.Corner(frame, 20)
	Kit.Stroke(frame, Kit.C.Ink, 4)
	return frame
end

-- Botão cartoon (cor chapada em 2 tons, contorno escuro grosso, cresce no hover/seleção do gamepad, "afunda" ao clicar)
function Kit.Button(parent, props, color, onClick)
	color = color or Kit.C.Green
	local button = make("TextButton", {
		BackgroundColor3 = color,
		AutoButtonColor = false,
		Font = Kit.Font,
		TextColor3 = Kit.C.Text,
		TextScaled = true,
		Text = "",
	}, parent)
	for k, v in pairs(props) do
		if k ~= "Outline" then
			button[k] = v
		end
	end
	Kit.Corner(button, 14)
	Kit.Stroke(button, Kit.C.Ink, 3)
	Kit.TwoTone(button)
	make("UIStroke", { Thickness = 2, Color = Kit.C.Ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }, button)
	make(
		"UIPadding",
		{ PaddingTop = UDim.new(0.12, 0), PaddingBottom = UDim.new(0.12, 0), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) },
		button
	)
	local scale = make("UIScale", { Name = "ButtonScale" }, button)
	local function hover(on)
		Kit.Tween(scale, 0.12, { Scale = on and 1.06 or 1 }, Enum.EasingStyle.Back)
	end
	button.MouseEnter:Connect(function()
		hover(true)
	end)
	button.MouseLeave:Connect(function()
		hover(false)
	end)
	button.SelectionGained:Connect(function()
		hover(true)
	end)
	button.SelectionLost:Connect(function()
		hover(false)
	end)
	button.MouseButton1Down:Connect(function()
		Kit.Tween(scale, 0.06, { Scale = 0.92 })
	end)
	button.MouseButton1Up:Connect(function()
		Kit.Tween(scale, 0.14, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
	if onClick then
		button.Activated:Connect(onClick)
	end
	return button
end

function Kit.SetButtonColor(button, color)
	button.BackgroundColor3 = color
end

-- Abre/fecha uma janela com um "pop" (abre com efeito elástico, fecha encolhendo rápido)
function Kit.Pop(frame, visible)
	local scale = frame:FindFirstChild("PopScale") or make("UIScale", { Name = "PopScale" }, frame)
	local token = (frame:GetAttribute("PopToken") or 0) + 1
	frame:SetAttribute("PopToken", token)
	if visible then
		frame.Visible = true
		scale.Scale = 0.7
		Kit.Tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	elseif frame.Visible then
		Kit.Tween(scale, 0.12, { Scale = 0.6 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.12, function()
			if frame:GetAttribute("PopToken") == token then
				frame.Visible = false
				scale.Scale = 1
			end
		end)
	end
end

---------------------------------------------------------------- responsivo
-- Fator de escala da UI para a tela atual (celular pequeno ~0.55, PC 1080p ~1.2)
function Kit.ScaleFactor()
	local camera = workspace.CurrentCamera
	local size = camera and camera.ViewportSize or Vector2.new(1280, 720)
	if size.X < 2 or size.Y < 2 then
		size = Vector2.new(1280, 720)
	end
	local s = math.min(size.X / Kit.DESIGN.X, size.Y / Kit.DESIGN.Y)
	if Kit.IsTouch() then
		s *= 0.9 -- tela pequena: menos coisa tampando o jogo (botões continuam grandes o bastante)
	end
	return math.clamp(s, 0.45, 1.25)
end

function Kit.IsTouch()
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

function Kit.IsGamepad()
	local last = UserInputService:GetLastInputType()
	return last.Name:sub(1, 7) == "Gamepad"
end

-- Tamanho da tela em pixels de design e a altura da barra do Roblox (em pixels de design)
function Kit.DesignSize()
	local camera = workspace.CurrentCamera
	local size = camera and camera.ViewportSize or Vector2.new(1280, 720)
	return size / Kit.ScaleFactor()
end

function Kit.TopInset()
	local inset = GuiService:GetGuiInset()
	return math.max(inset.Y, 36) / Kit.ScaleFactor()
end

local resizeEvent = Instance.new("BindableEvent")
Kit.Resized = resizeEvent.Event
local watchedCamera = nil
local function watchCamera()
	local camera = workspace.CurrentCamera
	if camera and camera ~= watchedCamera then
		watchedCamera = camera
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			resizeEvent:Fire()
		end)
		resizeEvent:Fire()
	end
end
watchCamera()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)

-- Chama fn agora e toda vez que a tela muda de tamanho
function Kit.OnResize(fn)
	fn()
	return Kit.Resized:Connect(fn)
end

---------------------------------------------------------------- 🎨 textos sem emoji (pedido do dono: tudo cartoon)
-- Toda tela do Kit (Kit.Gui) passa os textos por aqui: os emoji somem e, quando o texto COMEÇA com um emoji conhecido
-- (UI/Icons.EMOJI), ele vira um ícone DESENHADO — sozinho no lugar do texto (o texto era só o emoji) ou na ponta
-- esquerda (o texto anda para a direita). Frase comprida só perde o emoji. Atributo "KeepEmoji" = não mexe no texto.
local LEAD = 0.9 -- ícone da ponta (texto TextScaled): fração da altura de dentro do texto
local LEAD_GAP = 4
local LEAD_MAX_CHARS = 30
local shownText = setmetatable({}, { __mode = "k" }) -- texto limpo que o próprio Kit escreveu

-- escala acumulada (UIScale do próprio objeto e dos pais): AbsoluteSize vem escalado, o UIPadding não
local function scaleOf(obj)
	local k = 1
	local node = obj
	while node and not node:IsA("LayerCollector") do
		local sc = node:FindFirstChildOfClass("UIScale")
		if sc then
			k *= sc.Scale
		end
		node = node.Parent
	end
	return math.max(0.05, k)
end

local function textMax(label)
	local c = label:FindFirstChildOfClass("UITextSizeConstraint")
	return c and c.MaxTextSize or nil
end

-- abre espaço para o ícone da ponta: PaddingLeft = o de antes + ícone + folga
-- (a prévia do HUD refaz esta mesma conta pelos atributos LeadPad/LeadBase/LeadMax)
local function placeLead(label)
	local pad = label:FindFirstChildOfClass("UIPadding")
	if not pad then
		return
	end
	local icon = label:FindFirstChild("TextIcon")
	local base = label:GetAttribute("LeadBase") or 0
	local extra = 0
	if icon and icon.Visible and label:GetAttribute("LeadMode") == "lead" then
		local size
		if label.TextScaled then
			local h = label.AbsoluteSize.Y / scaleOf(label)
			local top, bottom = pad.PaddingTop, pad.PaddingBottom
			size = (h * (1 - top.Scale - bottom.Scale) - top.Offset - bottom.Offset) * LEAD
			local mx = label:GetAttribute("LeadMax")
			if mx then
				size = math.min(size, mx)
			end
		else
			size = label.TextSize * 1.15
		end
		extra = math.max(0, size) + LEAD_GAP
	end
	local want = UDim.new(pad.PaddingLeft.Scale, base + extra)
	if pad.PaddingLeft ~= want then
		pad.PaddingLeft = want
	end
end

-- texto centralizado/à direita: o ícone da ponta encosta no começo do texto (TextBounds = texto desenhado)
-- (a prévia do HUD faz a mesma conta medindo o texto)
local function followText(label)
	local icon = label:FindFirstChild("TextIcon")
	if not icon or label:GetAttribute("LeadMode") ~= "lead" then
		return
	end
	local xa = label.TextXAlignment
	local ay = icon.AnchorPoint.Y
	if xa == Enum.TextXAlignment.Left then
		icon.Position = UDim2.new(0, -LEAD_GAP, ay, 0)
		return
	end
	local tb = label.TextBounds
	local w = (tb and tb.X or 0) / scaleOf(label)
	if xa == Enum.TextXAlignment.Right then
		icon.Position = UDim2.new(1, -w - LEAD_GAP, ay, 0)
	else
		icon.Position = UDim2.new(0.5, -w / 2 - LEAD_GAP, ay, 0)
	end
end

local function showTextIcon(label, name, mode)
	local icon = label:FindFirstChild("TextIcon")
	if not name then
		if icon then
			icon.Visible = false
		end
		label:SetAttribute("LeadMode", nil)
		label:SetAttribute("LeadPad", nil)
		placeLead(label)
		return
	end
	local pad = label:FindFirstChildOfClass("UIPadding") or make("UIPadding", {}, label)
	if label:GetAttribute("LeadBase") == nil then
		label:SetAttribute("LeadBase", pad.PaddingLeft.Offset)
	end
	if not icon then
		icon = Icons.Make(label, name, { Name = "TextIcon", ZIndex = label.ZIndex })
		label:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			placeLead(label)
		end)
		label:GetPropertyChangedSignal("TextBounds"):Connect(function()
			followText(label)
		end)
	else
		Icons.Set(icon, name)
	end
	icon.Visible = true
	label:SetAttribute("LeadMode", mode)
	local mx = textMax(label)
	local cap = icon:FindFirstChildOfClass("UISizeConstraint")
	local ratio = icon:FindFirstChildOfClass("UIAspectRatioConstraint")
	if mode == "solo" then
		-- o ícone ocupa o lugar do texto: quadrado no alinhamento do texto
		label:SetAttribute("LeadPad", nil)
		local xa = label.TextXAlignment
		local ax = xa == Enum.TextXAlignment.Left and 0 or xa == Enum.TextXAlignment.Right and 1 or 0.5
		icon.AnchorPoint = Vector2.new(ax, 0.5)
		icon.Position = UDim2.fromScale(ax, 0.5)
		icon.SizeConstraint = Enum.SizeConstraint.RelativeXY
		if label.TextScaled then
			icon.Size = UDim2.fromScale(1, 1)
			if not ratio then
				make("UIAspectRatioConstraint", { AspectRatio = 1 }, icon)
			end
			if mx then
				cap = cap or make("UISizeConstraint", {}, icon)
				cap.MaxSize = Vector2.new(mx * 1.2, mx * 1.2)
			elseif cap then
				cap:Destroy()
			end
		else
			if ratio then
				ratio:Destroy()
			end
			if cap then
				cap:Destroy()
			end
			local px = label.TextSize * 1.25
			icon.Size = UDim2.fromOffset(px, px)
		end
	else
		-- ponta esquerda: o ícone fica ANTES do texto (fora da área do texto, que andou para a direita)
		if ratio then
			ratio:Destroy()
		end
		local ya = label.TextYAlignment
		local ay = ya == Enum.TextYAlignment.Top and 0 or ya == Enum.TextYAlignment.Bottom and 1 or 0.5
		icon.AnchorPoint = Vector2.new(1, ay)
		icon.Position = UDim2.new(0, -LEAD_GAP, ay, 0)
		task.defer(followText, label)
		if label.TextScaled then
			label:SetAttribute("LeadPad", LEAD)
			label:SetAttribute("LeadMax", mx and mx * 1.15 or nil)
			icon.SizeConstraint = Enum.SizeConstraint.RelativeYY
			icon.Size = UDim2.fromScale(LEAD, LEAD)
			if mx then
				cap = cap or make("UISizeConstraint", {}, icon)
				cap.MaxSize = Vector2.new(mx * 1.15, mx * 1.15)
			elseif cap then
				cap:Destroy()
			end
		else
			label:SetAttribute("LeadPad", nil)
			if cap then
				cap:Destroy()
			end
			icon.SizeConstraint = Enum.SizeConstraint.RelativeXY
			local px = label.TextSize * 1.15
			icon.Size = UDim2.fromOffset(px, px)
		end
	end
	placeLead(label)
	followText(label)
end

local function cartoonText(label)
	local text = label.Text
	if text == shownText[label] then
		return
	end
	if label:GetAttribute("FixedIcon") then
		-- ícone escolhido pelo código (Kit.LeadIcon): aqui só some o emoji
		local clean = Icons.Strip(text)
		shownText[label] = clean
		if clean ~= text then
			label.Text = clean
		end
		return
	end
	local lead, rest = Icons.Lead(text)
	local clean = Icons.Strip(rest or text)
	local mode = nil
	if lead then
		local plain = clean:gsub("<[^>]*>", "")
		if plain:match("^%s*$") then
			mode = "solo"
		elseif (utf8.len(plain) or #plain) <= LEAD_MAX_CHARS and not plain:find("\n") then
			mode = "lead"
		end
	end
	shownText[label] = clean
	if mode or label:FindFirstChild("TextIcon") then
		showTextIcon(label, mode and lead, mode)
	end
	if clean ~= text then
		label.Text = clean
	end
end

local hooked = setmetatable({}, { __mode = "k" })
local function hookText(obj)
	if hooked[obj] or not (obj:IsA("TextLabel") or obj:IsA("TextButton")) or obj.Name == "Glyph" or obj:GetAttribute("KeepEmoji") then
		return
	end
	hooked[obj] = true
	cartoonText(obj)
	obj:GetPropertyChangedSignal("Text"):Connect(function()
		if not obj:GetAttribute("KeepEmoji") then
			cartoonText(obj)
		end
	end)
end

-- ícone desenhado escolhido pelo código na ponta esquerda de um texto (nil = tira); o emoji do texto não manda mais
function Kit.LeadIcon(label, name)
	label:SetAttribute("FixedIcon", name)
	showTextIcon(label, name, name and "lead" or nil)
end

-- Fileira de ícones desenhados (ex.: elementos do cachorro). list.Set({ "fire", "ice" })
-- align = Enum.HorizontalAlignment (Left padrão); label (opcional) = texto antes dos ícones ("STRONG")
function Kit.IconList(parent, props, align, label, labelColor)
	local row = make("Frame", { BackgroundTransparency = 1 }, parent)
	for k, v in pairs(props) do
		row[k] = v
	end
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 3),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, row)
	local api = { Frame = row, Icons = {} }
	if label then
		api.Label = Kit.Text(row, {
			LayoutOrder = 0,
			Size = UDim2.fromScale(0.42, 0.8),
			Text = label,
			Font = Kit.Title,
			TextColor3 = labelColor or Kit.C.Text,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = row.ZIndex,
		})
	end
	function api.Set(names)
		for i, name in ipairs(names) do
			local icon = api.Icons[i]
			if not icon then
				icon = Icons.Make(row, name, {
					LayoutOrder = i,
					Size = UDim2.fromScale(1, 1),
					SizeConstraint = Enum.SizeConstraint.RelativeYY,
					ZIndex = row.ZIndex,
				})
				api.Icons[i] = icon
			else
				Icons.Set(icon, name)
			end
			icon.Visible = true
		end
		for i = #names + 1, #api.Icons do
			api.Icons[i].Visible = false
		end
		if api.Label then
			api.Label.Visible = #names > 0
		end
	end
	return api
end

-- Ícone desenhado de um ovo do jogo (com as cores dele: casca e pintas)
function Kit.EggIcon(eggId)
	local egg = DogData.Eggs[eggId]
	if not egg then
		return "egg"
	end
	return "egg#" .. egg.Color:ToHex() .. "#" .. (egg.Spots or egg.Color):ToHex()
end

-- Ícone de cada elemento dos cachorros (Fire -> "fire", Earth -> "boulder"...)
function Kit.ElementIcon(element)
	return Icons.ELEMENT_ICON[element] or "star"
end

-- Linha dividida em fatias iguais, cada uma um texto com ícone na ponta (atributos: ❤ 337 · ⚔ 33 · 💨 16).
-- split.Set({ "❤ 337", { Icon = "fire", Text = "Fire Bite", Color = cor }, ... }) — mostra só as fatias usadas
function Kit.Split(parent, props, max, textProps)
	local row = make("Frame", { BackgroundTransparency = 1 }, parent)
	for k, v in pairs(props) do
		row[k] = v
	end
	local api = { Frame = row, Labels = {} }
	for i = 1, max do
		local label = Kit.Text(row, { Text = "", TextXAlignment = Enum.TextXAlignment.Left, ZIndex = row.ZIndex, Visible = false })
		for k, v in pairs(textProps or {}) do
			label[k] = v
		end
		make("UIPadding", { PaddingRight = UDim.new(0, 6) }, label)
		api.Labels[i] = label
	end
	function api.Set(items)
		local n = math.max(1, #items)
		for i, label in ipairs(api.Labels) do
			local item = items[i]
			label.Visible = item ~= nil
			if item then
				label.Position = UDim2.fromScale((i - 1) / n, 0)
				label.Size = UDim2.fromScale(1 / n, 1)
				if type(item) == "table" then
					label.Text = item.Text or ""
					label.TextColor3 = item.Color or (textProps and textProps.TextColor3) or Kit.C.Text
					Kit.LeadIcon(label, item.Icon)
				else
					label:SetAttribute("FixedIcon", nil)
					label.TextColor3 = (textProps and textProps.TextColor3) or Kit.C.Text
					label.Text = item
				end
			end
		end
	end
	return api
end

-- liga a troca de emoji por desenho em tudo que aparecer dentro de `container` (o Kit.Gui já liga sozinho)
function Kit.Cartoon(container)
	for _, d in ipairs(container:GetDescendants()) do
		hookText(d)
	end
	container.DescendantAdded:Connect(hookText)
end
Kit.CleanText = Icons.Strip

function Kit.Gui(name, order)
	local gui = make("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = order or 1,
	}, Players.LocalPlayer:WaitForChild("PlayerGui"))
	Kit.Cartoon(gui)
	return gui
end

-- ScreenGui + Root escalada. Use Root como pai de tudo (tamanhos em pixels de design).
function Kit.Screen(name, order)
	local gui = Kit.Gui(name, order)
	local root = make("Frame", {
		Name = "Root",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, gui)
	local scale = make("UIScale", {}, root)
	Kit.OnResize(function()
		local s = Kit.ScaleFactor()
		scale.Scale = s
		root.Size = UDim2.fromScale(1 / s, 1 / s)
	end)
	return gui, root
end

---------------------------------------------------------------- janelas
-- Janela padrão: painel centralizado, faixa colorida com título e botão X.
-- opts = { Title, Color, Width, Height, OnClose, HeaderHeight (fração) }
-- Retorna frame, header, closeButton
function Kit.Window(parent, opts)
	local width, height = opts.Width or 560, opts.Height or 460
	local frame = Kit.Panel(parent, {
		Name = opts.Name or "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 14),
		Size = UDim2.new(0.92, 0, 0.84, 0),
		Visible = false,
		ZIndex = 2,
	})
	make("UISizeConstraint", { MaxSize = Vector2.new(width, height) }, frame)
	make("UIAspectRatioConstraint", { AspectRatio = width / height }, frame)
	local color = opts.Color or Kit.C.Gold
	local hh = opts.HeaderHeight or 0.12
	local header = make("Frame", {
		Name = "Header",
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromScale(1, hh),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
	}, frame)
	Kit.Corner(header, 18)
	-- esconde os cantos arredondados de baixo da faixa
	make("Frame", {
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromScale(1, 0.5),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
	}, header)
	local shade = make("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 4),
		BackgroundColor3 = Kit.C.Dark,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
	}, header)
	shade.ZIndex = 2
	-- título: o emoji do começo vira um ícone DESENHADO na faixa (quadrado de 80% da altura da faixa)
	local titleIcon = Icons.Make(header, nil, {
		Name = "TitleIcon",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0.022, 0.5),
		Size = UDim2.fromScale(0.8, 0.8),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		ZIndex = 3,
	})
	local iconW = 0.8 * (height * hh) / width -- largura do ícone em fração da faixa (a janela tem proporção fixa)
	local title = Kit.Thick(Kit.Text(header, {
		Position = UDim2.fromScale(0.035, 0.14),
		Size = UDim2.fromScale(0.75, 0.72),
		Text = "",
		Font = Kit.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	}), 3)
	title:SetAttribute("KeepEmoji", true)
	local shown = nil -- texto limpo que o próprio setTitle escreveu
	local function setTitle()
		if title.Text == shown then
			return
		end
		local icon = Icons.Lead(title.Text)
		local clean = Icons.Strip(title.Text)
		shown = clean
		Icons.Set(titleIcon, icon)
		titleIcon.Visible = icon ~= nil
		local x = icon and (0.022 + iconW + 0.018) or 0.035
		title.Position = UDim2.fromScale(x, 0.14)
		title.Size = UDim2.fromScale(0.785 - x, 0.72)
		if clean ~= title.Text then
			title.Text = clean
		end
	end
	title:GetPropertyChangedSignal("Text"):Connect(setTitle)
	title.Text = opts.Title or ""
	setTitle()
	local close = Kit.Button(header, {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromScale(0.9, 0.9),
		Text = "X",
		ZIndex = 4,
	}, Kit.C.Red, opts.OnClose)
	make("UIAspectRatioConstraint", { AspectRatio = 1 }, close)
	if not Kit.IsTouch() then
		local hint = Kit.Text(close, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 1, 2),
			Size = UDim2.new(1.6, 0, 0.32, 0),
			Text = Kit.IsGamepad() and "B" or "Esc / B",
			TextColor3 = Kit.C.Muted,
			ZIndex = 4,
		})
		hint.Visible = height > 300
	end
	return frame, header, close
end

-- Menu completo: ScreenGui escalada + fundo escurecido + janela (Kit.Window) + área de conteúdo.
-- opts = { Name, Title, Color, Width, Height, HeaderHeight, Order, OnClose }
-- Retorna { Gui, Root, Frame, Header, Body, Show(visible) }
function Kit.Menu(opts)
	local gui, root = Kit.Screen(opts.Name, opts.Order or 10)
	local backdrop = Kit.Backdrop(root, opts.OnClose)
	local safe = Kit.SafeArea(root)
	local frame, header = Kit.Window(safe, opts)
	local hh = opts.HeaderHeight or 0.12
	local body = make("Frame", {
		Name = "Body",
		Position = UDim2.fromScale(0, hh),
		Size = UDim2.fromScale(1, 1 - hh),
		BackgroundTransparency = 1,
		ZIndex = 2,
	}, frame)
	Kit.Pad(body, 14)
	-- fechado = ScreenGui desligada (o Visuals usa isso para saber se há menu aberto)
	gui.Enabled = false
	local menu = { Gui = gui, Root = root, Frame = frame, Header = header, Body = body, Open = false }
	function menu.Show(visible)
		menu.Open = visible
		if visible then
			gui.Enabled = true
		end
		Kit.ShowBackdrop(backdrop, visible)
		Kit.Pop(frame, visible)
		if not visible then
			task.delay(0.2, function()
				if not menu.Open then
					gui.Enabled = false
				end
			end)
		end
	end
	return menu
end

-- Painel interno (linha/caixa dentro de uma janela)
function Kit.Box(parent, props, color)
	local box = make("Frame", { BackgroundColor3 = color or Kit.C.Panel, BorderSizePixel = 0 }, parent)
	for k, v in pairs(props) do
		box[k] = v
	end
	Kit.Corner(box, 14)
	Kit.Stroke(box, Kit.C.Ink, 2.5)
	return box
end

---------------------------------------------------------------- barras / contadores / efeitos
-- Barra de progresso cartoon (fundo escuro, cor chapada e um risco claro em cima). Retorna { Frame, Fill, Label, Set(pct, instant) }
function Kit.Bar(parent, props, color)
	local back = make("Frame", { BackgroundColor3 = Color3.fromRGB(30, 18, 52), BorderSizePixel = 0 }, parent)
	for k, v in pairs(props) do
		back[k] = v
	end
	Kit.Corner(back, 999)
	Kit.Stroke(back, Kit.C.Ink, 2.5)
	local fill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = color or Kit.C.XP, BorderSizePixel = 0, ZIndex = back.ZIndex }, back)
	Kit.Corner(fill, 999)
	local gloss = make("Frame", {
		Position = UDim2.new(0, 5, 0.16, 0),
		Size = UDim2.new(1, -10, 0.22, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		ZIndex = back.ZIndex,
	}, fill)
	Kit.Corner(gloss, 999)
	local label = Kit.Text(back, { Size = UDim2.fromScale(1, 1), Text = "", ZIndex = back.ZIndex + 1 })
	make("UIPadding", { PaddingTop = UDim.new(0.1, 0), PaddingBottom = UDim.new(0.1, 0) }, label)
	local bar = { Frame = back, Fill = fill, Label = label, Value = 0 }
	function bar.Set(pct, instant)
		pct = math.clamp(pct, 0, 1)
		bar.Value = pct
		fill.Visible = pct > 0.005
		if instant then
			fill.Size = UDim2.fromScale(pct, 1)
		else
			Kit.Tween(fill, 0.35, { Size = UDim2.fromScale(pct, 1) })
		end
	end
	return bar
end

-- Número que "corre" até o valor novo (Cash, XP...). fmt(n) -> texto
local counters = setmetatable({}, { __mode = "k" })
function Kit.CountTo(label, target, fmt, duration)
	local state = counters[label]
	if not state then
		counters[label] = { Target = target, Shown = target, Token = 0 }
		label.Text = fmt(target)
		return
	end
	if state.Target == target then
		return
	end
	state.Target = target
	state.Token += 1
	local token = state.Token
	local from, start, dur = state.Shown, os.clock(), duration or 0.6
	task.spawn(function()
		while state.Token == token and label.Parent do
			local k = math.min(1, (os.clock() - start) / dur)
			state.Shown = from + (target - from) * (1 - (1 - k) ^ 3)
			label.Text = fmt(k >= 1 and target or state.Shown)
			if k >= 1 then
				break
			end
			RunService.Heartbeat:Wait()
		end
	end)
end

-- Define o valor na hora (sem animar), ex.: quando o level muda e a barra recomeça
function Kit.CountSet(label, value, fmt)
	local state = counters[label]
	if state then
		state.Token += 1 -- para qualquer animação em andamento
		state.Target = value
		state.Shown = value
	else
		counters[label] = { Target = value, Shown = value, Token = 0 }
	end
	label.Text = fmt(value)
end

-- Partículas de UI: estrelinhas que explodem de um ponto (feedback de compra, level up...)
function Kit.Burst(parent, position, color, count, glyphs, distance)
	count = count or 14
	glyphs = glyphs or { "✦", "★", "●" }
	distance = distance or 110
	for i = 1, count do
		local angle = (i / count) * math.pi * 2 + math.random() * 0.5
		local dist = distance * (0.5 + math.random() * 0.6)
		local size = math.random(14, 28)
		-- (cartoon: só símbolos de letra — ✦ ★ ● —; um emoji vira ★)
		local glyph = Icons.Strip(glyphs[math.random(1, #glyphs)])
		local p = Kit.Text(parent, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = position,
			Size = UDim2.fromOffset(size, size),
			Text = glyph ~= "" and glyph or "★",
			TextColor3 = color:Lerp(Color3.new(1, 1, 1), math.random() * 0.4),
			Rotation = math.random(0, 360),
			ZIndex = 60,
		})
		p:SetAttribute("KeepEmoji", true)
		local t = 0.45 + math.random() * 0.35
		Kit.Tween(p, t, {
			Position = position + UDim2.fromOffset(math.cos(angle) * dist, math.sin(angle) * dist),
			Rotation = p.Rotation + math.random(-200, 200),
			TextTransparency = 1,
		})
		local stroke = p:FindFirstChildOfClass("UIStroke")
		if stroke then
			Kit.Tween(stroke, t, { Transparency = 1 })
		end
		Debris:AddItem(p, t + 0.05)
	end
end

-- Faixa de brilho que atravessa um botão/painel (compra feita!)
function Kit.Shine(frame)
	local oldClip = frame.ClipsDescendants
	frame.ClipsDescendants = true
	local band = make("Frame", {
		Position = UDim2.fromScale(-0.4, 0),
		Size = UDim2.fromScale(0.35, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = frame.ZIndex + 5,
	}, frame)
	make("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.25),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, band)
	Kit.Tween(band, 0.45, { Position = UDim2.fromScale(1.1, 0) }, Enum.EasingStyle.Sine)
	task.delay(0.47, function()
		band:Destroy()
		frame.ClipsDescendants = oldClip
	end)
end

-- Tremidinha de "não deu" (sem dinheiro etc.)
function Kit.Shake(frame)
	local base = frame:GetAttribute("ShakeBase") or frame.Position
	frame:SetAttribute("ShakeBase", base)
	task.spawn(function()
		for _, dx in ipairs({ -8, 8, -6, 6, -3, 0 }) do
			frame.Position = base + UDim2.fromOffset(dx, 0)
			task.wait(0.035)
		end
		frame.Position = base
		frame:SetAttribute("ShakeBase", nil)
	end)
end

-- Pulsa (cresce/encolhe) em loop até chamar a função retornada
function Kit.Pulse(frame, amount, period)
	local scale = frame:FindFirstChild("PulseScale") or make("UIScale", { Name = "PulseScale" }, frame)
	local tween = TweenService:Create(
		scale,
		TweenInfo.new((period or 0.9) / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Scale = 1 + (amount or 0.06) }
	)
	tween:Play()
	return function()
		tween:Cancel()
		scale.Scale = 1
	end
end

-- Texto que sobe e some (+$50, +5 XP...)
function Kit.FloatText(parent, position, text, color, size)
	local label = Kit.Text(parent, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = UDim2.fromOffset(size and size * 6 or 160, size or 26),
		Text = text,
		TextColor3 = color or Kit.C.Text,
		ZIndex = 60,
	})
	local scale = make("UIScale", { Scale = 0.4 }, label)
	Kit.Tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	Kit.Tween(label, 1.1, { Position = position - UDim2.fromOffset(0, 46) }, Enum.EasingStyle.Quad)
	task.delay(0.6, function()
		Kit.Tween(label, 0.5, { TextTransparency = 1 })
		local stroke = label:FindFirstChildOfClass("UIStroke")
		if stroke then
			Kit.Tween(stroke, 0.5, { Transparency = 1 })
		end
	end)
	Debris:AddItem(label, 1.2)
	return label
end

-- Raios girando atrás de algo (level up, ovo chocado). Retorna o frame (destrua para parar).
function Kit.Rays(parent, props, color, count)
	local holder = make("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5) }, parent)
	for k, v in pairs(props) do
		holder[k] = v
	end
	make("UIAspectRatioConstraint", { AspectRatio = 1 }, holder)
	count = count or 12
	for i = 1, count do
		local ray = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.09, 1),
			Rotation = (180 / count) * i,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = holder.ZIndex,
		}, holder)
		make("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0.35),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}, ray)
	end
	task.spawn(function()
		while holder.Parent do
			holder.Rotation += 0.4
			RunService.RenderStepped:Wait()
		end
	end)
	return holder
end

-- Chip pequeno (raridade, tags). Retorna o frame e o texto
function Kit.Chip(parent, props, color, text)
	local chip = make("Frame", { BackgroundColor3 = color, BorderSizePixel = 0 }, parent)
	for k, v in pairs(props) do
		chip[k] = v
	end
	Kit.Corner(chip, 999)
	Kit.Stroke(chip, Kit.C.Ink, 2.5)
	local label = Kit.Text(chip, { Size = UDim2.fromScale(1, 1), Text = text or "", ZIndex = chip.ZIndex })
	make("UIPadding", { PaddingTop = UDim.new(0.14, 0), PaddingBottom = UDim.new(0.14, 0), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, label)
	return chip, label
end

-- Brilho arco-íris / cintilante (Mítico e Lendário): gira um UIGradient em loop.
-- Um único loop gira todos os gradientes (barato mesmo com muitos cards na lista).
local shimmering = setmetatable({}, { __mode = "k" })
local shimmerConn = nil
function Kit.Shimmer(target, colors)
	local keys = {}
	for i, c in ipairs(colors) do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), c))
	end
	local gradient = make("UIGradient", { Color = ColorSequence.new(keys) }, target)
	shimmering[gradient] = true
	if not shimmerConn then
		shimmerConn = RunService.Heartbeat:Connect(function(dt)
			for g in pairs(shimmering) do
				if g.Parent then
					g.Rotation = (g.Rotation + dt * 120) % 360
				else
					shimmering[g] = nil
				end
			end
		end)
	end
	return gradient
end

---------------------------------------------------------------- raridade
Kit.RAINBOW = {
	Color3.fromRGB(255, 70, 110),
	Color3.fromRGB(255, 170, 60),
	Color3.fromRGB(255, 240, 90),
	Color3.fromRGB(90, 230, 140),
	Color3.fromRGB(80, 170, 255),
	Color3.fromRGB(190, 110, 255),
	Color3.fromRGB(255, 70, 110),
}
Kit.GOLDEN = {
	Color3.fromRGB(255, 190, 40),
	Color3.fromRGB(255, 250, 200),
	Color3.fromRGB(255, 160, 30),
	Color3.fromRGB(255, 250, 200),
	Color3.fromRGB(255, 190, 40),
}

-- ☀️ brilho do Divino: ouro → laranja → vermelho (o Sunfire Dragon)
Kit.SUNFIRE = {
	Color3.fromRGB(255, 230, 120),
	Color3.fromRGB(255, 160, 50),
	Color3.fromRGB(255, 90, 60),
	Color3.fromRGB(255, 160, 50),
	Color3.fromRGB(255, 230, 120),
}

-- 🎃 brilho do Halloween: abóbora → roxo → verde-limão (o Spooky Clown)
Kit.PUMPKIN = {
	Color3.fromRGB(255, 140, 30),
	Color3.fromRGB(150, 60, 220),
	Color3.fromRGB(160, 240, 70),
	Color3.fromRGB(150, 60, 220),
	Color3.fromRGB(255, 140, 30),
}

function Kit.Rarity(rarityId)
	return Config.RARITY[rarityId] or Config.RARITY.Common
end

-- degradê que cintila das raridades altas (nil = cor lisa da raridade)
function Kit.RarityGradient(rarityId)
	if rarityId == "Divine" then
		return Kit.SUNFIRE
	elseif rarityId == "Halloween" then
		return Kit.PUMPKIN
	elseif rarityId == "Mythic" then
		return Kit.RAINBOW
	elseif rarityId == "Legendary" then
		return Kit.GOLDEN
	end
	return nil
end

-- Contorno colorido pela raridade. Lendário = dourado cintilante, Mítico = arco-íris girando.
function Kit.RarityStroke(frame, rarityId, thickness)
	local rarity = Kit.Rarity(rarityId)
	local stroke = make("UIStroke", {
		Name = "RarityStroke",
		Color = rarity.Color,
		Thickness = thickness or 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	}, frame)
	local gradient = Kit.RarityGradient(rarityId)
	if gradient then
		stroke.Color = Color3.new(1, 1, 1)
		Kit.Shimmer(stroke, gradient)
	end
	return stroke
end

-- Cor de texto da raridade com brilho (Lendário/Mítico) aplicado direto no texto
function Kit.RarityText(label, rarityId)
	local rarity = Kit.Rarity(rarityId)
	local old = label:FindFirstChild("RarityShimmer")
	if old then
		old:Destroy()
	end
	local gradient = Kit.RarityGradient(rarityId)
	if gradient then
		label.TextColor3 = Color3.new(1, 1, 1)
		Kit.Shimmer(label, gradient).Name = "RarityShimmer"
	else
		label.TextColor3 = rarity.Color
	end
end

---------------------------------------------------------------- área segura / modal / botões extras
-- Frame abaixo da barra superior do Roblox (pixels de design). Use como pai das janelas/HUD.
function Kit.SafeArea(root)
	local safe = make("Frame", { Name = "Safe", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, root)
	Kit.OnResize(function()
		local top = Kit.TopInset()
		safe.Position = UDim2.fromOffset(0, top)
		safe.Size = UDim2.new(1, 0, 1, -top - 4)
	end)
	return safe
end

-- Fundo escurecido atrás de uma janela (clicar fora fecha). Kit.ShowBackdrop(b, true/false)
function Kit.Backdrop(parent, onClick)
	local backdrop = make("TextButton", {
		Name = "Backdrop",
		Text = "",
		AutoButtonColor = false,
		Selectable = false,
		BackgroundColor3 = Color3.fromRGB(10, 8, 22),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 1,
	}, parent)
	if onClick then
		backdrop.Activated:Connect(onClick)
	end
	return backdrop
end

function Kit.ShowBackdrop(backdrop, visible)
	local token = (backdrop:GetAttribute("FadeToken") or 0) + 1
	backdrop:SetAttribute("FadeToken", token)
	if visible then
		backdrop.Visible = true
		Kit.Tween(backdrop, 0.2, { BackgroundTransparency = 0.45 })
	else
		Kit.Tween(backdrop, 0.15, { BackgroundTransparency = 1 })
		task.delay(0.15, function()
			if backdrop:GetAttribute("FadeToken") == token then
				backdrop.Visible = false
			end
		end)
	end
end

-- Botão sem padding interno (para cards com vários textos dentro)
function Kit.Card(parent, props, color, onClick)
	local card = Kit.Button(parent, props, color, onClick)
	local pad = card:FindFirstChildOfClass("UIPadding")
	if pad then
		pad:Destroy()
	end
	return card
end

-- Botão grande com ícone em cima e rótulo embaixo (barra lateral do HUD)
function Kit.IconButton(parent, props, color, icon, label, onClick)
	local button = Kit.Card(parent, props, color, onClick)
	Kit.Text(button, {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.06),
		Size = UDim2.fromScale(0.86, 0.56),
		Text = icon,
		ZIndex = button.ZIndex + 1,
	})
	local strip = make("Frame", {
		Name = "LabelStrip",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -5),
		Size = UDim2.new(1, -10, 0.3, 0),
		BackgroundColor3 = Kit.C.Dark,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		ZIndex = button.ZIndex + 1,
	}, button)
	Kit.Corner(strip, 999)
	local text = Kit.Thick(Kit.Text(strip, { Name = "Label", Size = UDim2.fromScale(1, 1), Text = label, ZIndex = button.ZIndex + 2 }), 2.5)
	make("UIPadding", { PaddingTop = UDim.new(0.1, 0), PaddingBottom = UDim.new(0.1, 0), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }, text)
	return button
end

-- Bolinha de aviso no canto de um botão ("!", "3", "NEW"). Retorna set(text|nil)
function Kit.Badge(parent, color)
	local badge = make("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(30, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = color or Kit.C.Red,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 30,
	}, parent)
	Kit.Corner(badge, 999)
	Kit.Stroke(badge, Kit.C.Dark, 2.5)
	local label = Kit.Text(badge, {
		Size = UDim2.fromOffset(30, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		TextScaled = false,
		TextSize = 18,
		Text = "",
		ZIndex = 31,
	})
	make("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, label)
	local stopPulse = nil
	return function(text)
		badge.Visible = text ~= nil and text ~= ""
		label.Text = text or ""
		if badge.Visible and not stopPulse then
			stopPulse = Kit.Pulse(badge, 0.15, 0.8)
		elseif not badge.Visible and stopPulse then
			stopPulse()
			stopPulse = nil
		end
	end
end

-- Faixa inclinada piscando sobre um botão ("PACOTE INICIAL", "NOVO!"). Retorna { Frame, Label, SetText(t|nil) }
function Kit.Ribbon(parent, props, color, text)
	color = color or Kit.C.Pink
	local ribbon = make("Frame", {
		Name = "Ribbon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 1, -2),
		Size = UDim2.new(1.35, 0, 0.3, 0),
		Rotation = -6,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = 32,
	}, parent)
	for k, v in pairs(props or {}) do
		ribbon[k] = v
	end
	Kit.Corner(ribbon, 8)
	Kit.Stroke(ribbon, Kit.C.Ink, 2.5)
	local label = Kit.Thick(Kit.Text(ribbon, { Size = UDim2.fromScale(1, 1), Text = text or "", ZIndex = 33 }), 2)
	make("UIPadding", { PaddingTop = UDim.new(0.1, 0), PaddingBottom = UDim.new(0.1, 0), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }, label)
	local r = { Frame = ribbon, Label = label }
	function r.SetText(t)
		ribbon.Visible = t ~= nil and t ~= ""
		label.Text = t or ""
	end
	return r
end

-- Pisca a cor de fundo de um frame entre duas cores até chamar a função retornada
function Kit.Flash(frame, colorA, colorB, period)
	local tween = TweenService:Create(
		frame,
		TweenInfo.new((period or 0.8) / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ BackgroundColor3 = colorB }
	)
	frame.BackgroundColor3 = colorA
	tween:Play()
	return function()
		tween:Cancel()
		frame.BackgroundColor3 = colorA
	end
end

-- Estrelas de evolução: "★★★" (até 5) ou "★ x7"
function Kit.StarsText(stars)
	stars = math.floor(tonumber(stars) or 0)
	if stars <= 0 then
		return ""
	elseif stars <= 5 then
		return string.rep("★", stars)
	end
	return "★ x" .. stars
end

-- Seta de comparação de power: "↑ +120" verde, "↓ -40" vermelho, "=" cinza
function Kit.Compare(value, reference)
	if not reference then
		return "", Kit.C.Muted
	end
	local diff = math.floor(value) - math.floor(reference)
	if diff > 0 then
		return "↑ +" .. Config.Format(diff), Kit.C.Green
	elseif diff < 0 then
		return "↓ -" .. Config.Format(-diff), Kit.C.Red
	end
	return "= same", Kit.C.Muted
end

---------------------------------------------------------------- cachorro nas telas
-- luz "de desenho" dos ViewportFrames: ambiente forte e quase nada de sol (cores chapadas, só um tiquinho de forma)
Kit.FLAT_AMBIENT = Color3.fromRGB(232, 228, 238)
Kit.FLAT_LIGHT = Color3.fromRGB(70, 66, 60)

-- Cachorro animado dentro de uma moldura. Retorna { Frame, SetSpecies(id), SetAction(a), Destroy() }
function Kit.DogViewport(parent, props)
	-- (luz chapada: quase só ambiente — o cachorro fica com cara de desenho, sem sombreado 3D)
	local vp = make("ViewportFrame", {
		BackgroundTransparency = 1,
		Ambient = Kit.FLAT_AMBIENT,
		LightColor = Kit.FLAT_LIGHT,
		LightDirection = Vector3.new(-0.4, -1, -0.6),
	}, parent)
	for k, v in pairs(props or {}) do
		vp[k] = v
	end
	local world = make("WorldModel", {}, vp)
	local camera = make("Camera", { FieldOfView = 30 }, vp)
	vp.CurrentCamera = camera
	local view = { Frame = vp, Model = nil, Angle = 0.6, Spin = true, Walk = false, Zoom = 1 }

	-- variant (opcional) = o cachorro do perfil (✨ shiny / 🥇 Gold / 🌈 Rainbow: Shared/Variants) · acc = acessórios
	-- equipados { [slot] = id } (Shared/Accessories)
	function view.SetSpecies(speciesId, scale, variant, acc)
		if view.Model then
			Animator.Untrack(view.Model)
			view.Model:Destroy()
			view.Model = nil
		end
		if not speciesId then
			return
		end
		local model = DogBuilder.Build(speciesId, { scale = scale })
		if variant then
			Variants.Paint(model, variant)
		end
		if acc then
			Accessories.Attach(model, acc)
		end
		model.PrimaryPart.Anchored = true
		model:PivotTo(CFrame.new())
		model.Parent = world
		view.Model = model
		Animator.Track(model, {
			UseC0 = true,
			Speed = function()
				return view.Walk and 10 or 0
			end,
		})
		local size = model:GetExtentsSize()
		view.Distance = math.max(size.X, size.Y, size.Z) * 2.1 + 2
	end

	function view.SetAction(action)
		if view.Model then
			view.Model:SetAttribute("Action", action)
		end
	end

	-- (2026-10-25, o dono: "todos os cachorros olham para trás, faça olhar para frente") o cachorro olha para −Z, então a
	-- câmera fica na FRENTE dele (−Z). Spin = em vez de dar a volta inteira (metade do tempo de costas), balança devagar
	-- de um lado para o outro sempre mostrando a cara.
	local t0 = os.clock()
	local conn = RunService.RenderStepped:Connect(function()
		if not view.Model or not vp.Visible then
			return
		end
		local angle = view.Angle
		if view.Spin then
			angle += math.sin((os.clock() - t0) * 0.7) * 0.55
		end
		local d = (view.Distance or 10) * view.Zoom
		local focus = Vector3.new(0, -(view.Model:GetAttribute("HipHeight") or 1) * 0.3, 0)
		camera.CFrame = CFrame.lookAt(focus + Vector3.new(math.sin(angle) * d, d * 0.28, -math.cos(angle) * d), focus)
	end)

	function view.Destroy()
		conn:Disconnect()
		if view.Model then
			Animator.Untrack(view.Model)
		end
		vp:Destroy()
	end
	return view
end

-- Retrato parado do cachorro (cartões de lista): monta o modelo uma vez, sem animação nem loop
-- por quadro, então dá para ter dezenas na tela. Retorna o ViewportFrame.
-- variant (opcional) = o cachorro do perfil: ✨ shiny / 🥇 Gold / 🌈 Rainbow aparecem pintados (Shared/Variants)
function Kit.DogPortrait(parent, props, speciesId, variant)
	local vp = make("ViewportFrame", {
		BackgroundTransparency = 1,
		Ambient = Kit.FLAT_AMBIENT,
		LightColor = Kit.FLAT_LIGHT,
		LightDirection = Vector3.new(-0.4, -1, -0.6),
	}, parent)
	for k, v in pairs(props or {}) do
		vp[k] = v
	end
	local ok, model = pcall(DogBuilder.Build, speciesId, {})
	if not ok or not model then
		return vp
	end
	if variant then
		Variants.Paint(model, variant)
	end
	model.PrimaryPart.Anchored = true
	model:PivotTo(CFrame.new())
	model.Parent = vp
	local camera = make("Camera", { FieldOfView = 30 }, vp)
	vp.CurrentCamera = camera
	local size = model:GetExtentsSize()
	local d = math.max(size.X, size.Y, size.Z) * 1.9 + 1.5
	local angle = 0.75
	local focus = Vector3.new(0, -(model:GetAttribute("HipHeight") or 1) * 0.25, 0)
	-- (câmera na frente do cachorro, que olha para −Z: de três-quartos, mostrando a cara)
	camera.CFrame = CFrame.lookAt(focus + Vector3.new(math.sin(angle) * d, d * 0.25, -math.cos(angle) * d), focus)
	return vp
end

return Kit
