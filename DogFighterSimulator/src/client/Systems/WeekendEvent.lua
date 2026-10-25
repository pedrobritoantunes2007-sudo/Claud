-- 🎉 AVISO DO EVENTO DE FIM DE SEMANA no HUD (2026-10-25, pedido do dono: "Aparece um aviso no HUD com o tempo que
-- falta."). Pílula colorida embaixo dos botões QUESTS/TRADE (canto de cima à esquerda): ícone + nome do evento + tempo
-- que falta ("2x CATCH · 1d 4h"). Faltando menos de 12 h para o próximo, mostra "starts in". Tocar mostra o que o
-- evento faz. O calendário é o Shared/WeekendEvents (igual ao servidor).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeekendEvents = require(ReplicatedStorage.Shared.WeekendEvents)
local UI = script.Parent.Parent:WaitForChild("UI")
local Kit = require(UI:WaitForChild("Kit"))
local Icons = require(UI:WaitForChild("Icons"))

local WeekendEvent = {}
local make = Kit.make
local C = Kit.C

local SOON = 12 * 3600 -- mostra o "começa em" quando falta menos que isso

function WeekendEvent.Start(HUD)
	local _player = Players.LocalPlayer
	local gui, root = Kit.Screen("WeekendEvent", 6)
	gui.Enabled = true
	-- (moldura com a escala do celular; a pílula dentro dela faz o "pop" com a própria escala)
	local frame = make("Frame", { Name = "Evento", BackgroundTransparency = 1, Size = UDim2.fromOffset(420, 26) }, root)
	local scale = make("UIScale", {}, frame)
	local holder = make("TextButton", {
		Name = "Pilula",
		Text = "",
		AutoButtonColor = true,
		BackgroundColor3 = C.Gold,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(200, 26),
		Visible = false,
	}, frame)
	Kit.Corner(holder, 999)
	Kit.Stroke(holder, C.Ink, 2.5)
	local icon = Icons.Make(holder, "star", { Position = UDim2.fromOffset(-6, -7), Size = UDim2.fromOffset(38, 38), ZIndex = 3 })
	local label = Kit.Text(holder, {
		Position = UDim2.fromOffset(32, 3),
		Size = UDim2.new(1, -40, 1, -6),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Kit.Title,
		ZIndex = 3,
	})
	local shown = nil
	holder.Activated:Connect(function()
		local e = WeekendEvents.Current()
		if e then
			HUD.Toast("🎉 " .. e.Name .. ": " .. e.Desc, "gold")
		elseif shown then
			HUD.Toast("🎉 Next weekend event: " .. shown.Name .. " — " .. shown.Desc, "blue")
		end
	end)

	local function layout()
		local touch = Kit.IsTouch()
		local G = touch and 1.15 or 1
		scale.Scale = G
		frame.Position = UDim2.fromOffset(12, Kit.TopInset() + 10 + 98 * G)
	end
	Kit.OnResize(layout)

	local lastId = nil
	task.spawn(function()
		while true do
			local e, left, nextEvent = WeekendEvents.Current()
			local text, color, iconName = nil, nil, nil
			if e then
				text = e.Short .. " · " .. WeekendEvents.FormatLeft(left) .. " left"
				color, iconName = e.Color, e.Icon
				shown = e
			elseif nextEvent and left < SOON then
				text = nextEvent.Short .. " starts in " .. WeekendEvents.FormatLeft(left)
				color, iconName = C.Panel2, nextEvent.Icon
				shown = nextEvent
			end
			holder.Visible = text ~= nil
			if text then
				label.Text = text
				holder.BackgroundColor3 = color
				holder.Size = UDim2.fromOffset(math.max(150, 46 + #text * 8), 26)
				local id = (e and e.Id or "next") .. tostring(iconName)
				if id ~= lastId then
					lastId = id
					Icons.Set(icon, iconName or "star")
					if e then
						Kit.Pop(holder, true)
					end
				end
			end
			task.wait(1)
		end
	end)
end

return WeekendEvent
