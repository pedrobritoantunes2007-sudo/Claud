-- 📱 Botões redondos do CELULAR em volta do botão de PULO do Roblox (pedido do dono: achar fácil onde
-- virar pessoa, correr e voar; a trava de câmera 🎯 LOCK saiu em 2026-10). Cada sistema registra o seu botão (TouchPad.Add); o
-- TouchPad arruma os visíveis num arco à esquerda/em cima do pulo, no tamanho certo para o aparelho, e
-- acompanha o pulo se ele mudar de lugar (girar a tela, aparelho diferente). No PC/console não aparece.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Kit = require(script.Parent:WaitForChild("Kit"))
local Icons = require(script.Parent:WaitForChild("Icons"))

local TouchPad = {}
local make = Kit.make
local C = Kit.C
local player = Players.LocalPlayer

local INK = Icons.INK
local ARC = { 180, 140, 100, 60 } -- graus (0 = direita, 90 = em cima): 1º à esquerda do pulo, depois subindo
local entries = {} -- { Key, Order, Button, Visible, Active, Color }
local gui = nil

local function ensureGui()
	if gui then
		return gui
	end
	gui = Kit.Gui("TouchPad", 6)
	return gui
end

-- centro e tamanho do botão de pulo do Roblox (em pixels da tela); se não achar, usa a mesma conta do Roblox
local function jumpButton(): (Vector2, number)
	local touchGui = player:FindFirstChildOfClass("PlayerGui") and player.PlayerGui:FindFirstChild("TouchGui")
	local frame = touchGui and touchGui:FindFirstChild("TouchControlFrame")
	local jump = frame and frame:FindFirstChild("JumpButton")
	if jump and jump:IsA("GuiObject") and jump.AbsoluteSize.X > 10 then
		local inset = 0
		if touchGui:IsA("ScreenGui") and not touchGui.IgnoreGuiInset then
			inset = game:GetService("GuiService"):GetGuiInset().Y
		end
		return jump.AbsolutePosition + jump.AbsoluteSize / 2 + Vector2.new(0, inset), jump.AbsoluteSize.X
	end
	local view = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(844, 390)
	local small = math.min(view.X, view.Y) <= 500
	local size = small and 70 or 120
	local pos = small and Vector2.new(view.X - (size * 1.5 - 10), view.Y - size - 20) or Vector2.new(view.X - (size * 1.5 - 10), view.Y - size * 1.75)
	return pos + Vector2.new(size / 2, size / 2), size
end

local function paint(e)
	local b = e.Button
	local on = e.Active
	b.BackgroundColor3 = on and e.Color:Lerp(Color3.new(1, 1, 1), 0.15) or e.Color:Lerp(C.Dark, 0.18)
	b.BackgroundTransparency = 0
	e.Stroke.Color = on and Color3.new(1, 1, 1) or INK
	e.Stroke.Thickness = on and 3.5 or 3
end

local function layout()
	local center, jumpSize = jumpButton()
	local size = math.clamp(jumpSize * 0.58, 46, 70)
	local radius = jumpSize / 2 + 10 + size / 2
	local visible = {}
	for _, e in ipairs(entries) do
		e.Button.Visible = e.Visible
		if e.Visible then
			table.insert(visible, e)
		end
	end
	for i, e in ipairs(visible) do
		local ring = math.floor((i - 1) / #ARC)
		local a = math.rad(ARC[(i - 1) % #ARC + 1])
		local r = radius + ring * (size + 10)
		local p = center + Vector2.new(math.cos(a) * r, -math.sin(a) * r)
		e.Button.Size = UDim2.fromOffset(size, size)
		e.Button.Position = UDim2.fromOffset(p.X, p.Y)
	end
end

-- opts = { Icon, Icon3D, Label, Color, Order } (Icon3D = nome do ícone desenhado de UI/Icons; sem ele usa o texto de Icon).
-- 🎨 (2026-10-24) cartoon: cor chapada em 2 tons, contorno grosso e ícone 2D (antes 3D com degradê)
-- Devolve { Set = fn({Icon, Icon3D, Label, Active}), SetVisible = fn(bool) }
function TouchPad.Add(key: string, opts, onTap)
	local dummy = { Set = function() end, SetVisible = function() end }
	if not Kit.IsTouch() then
		return dummy
	end
	local parent = ensureGui()
	local button = make("TextButton", {
		Name = key,
		AnchorPoint = Vector2.new(0.5, 0.5),
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = opts.Color or C.Panel2,
		ZIndex = 2,
	}, parent)
	Kit.Corner(button, 999)
	local stroke = Kit.Stroke(button, INK, 3)
	Kit.TwoTone(button, 0.56, 0.15)
	-- ícone desenhado em cima e o nome embaixo, dentro do botão
	local icon3d = opts.Icon3D
		and Icons.Make(button, opts.Icon3D, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.4),
			Size = UDim2.fromScale(0.64, 0.64),
			ZIndex = 3,
		})
	local icon = Kit.Text(button, {
		Position = UDim2.fromScale(0.18, 0.1),
		Size = UDim2.fromScale(0.64, 0.5),
		Text = opts.Icon3D and "" or (opts.Icon or ""),
		ZIndex = 3,
	})
	local label = Kit.Text(button, {
		Position = UDim2.fromScale(0.08, 0.64),
		Size = UDim2.fromScale(0.84, 0.25),
		Text = opts.Label or "",
		Font = Enum.Font.LuckiestGuy,
		ZIndex = 4,
	})
	local pop = make("UIScale", {}, button)
	local e = { Key = key, Order = opts.Order or 99, Button = button, Stroke = stroke, Visible = true, Active = false, Color = opts.Color or C.Panel2 }
	table.insert(entries, e)
	table.sort(entries, function(a, b)
		return a.Order < b.Order
	end)
	paint(e)
	button.MouseButton1Down:Connect(function()
		Kit.Tween(pop, 0.08, { Scale = 0.88 })
	end)
	button.InputEnded:Connect(function()
		Kit.Tween(pop, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
	button.Activated:Connect(function()
		if onTap then
			onTap()
		end
	end)
	layout()
	return {
		Set = function(s)
			if s.Icon3D and icon3d then
				Icons.Set(icon3d, s.Icon3D)
			elseif s.Icon and not icon3d then
				icon.Text = s.Icon
			end
			if s.Label then
				label.Text = s.Label
			end
			if s.Active ~= nil and s.Active ~= e.Active then
				e.Active = s.Active
				paint(e)
			end
		end,
		SetVisible = function(v)
			if e.Visible ~= v then
				e.Visible = v
				layout()
			end
		end,
	}
end

-- acompanha o botão de pulo (muda de lugar ao girar a tela / mudar o tamanho)
if Kit.IsTouch() then
	local last = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - last > 0.5 and #entries > 0 then
			last = now
			layout()
		end
	end)
end

return TouchPad
