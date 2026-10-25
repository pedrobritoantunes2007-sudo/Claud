-- ⚙️ SETTINGS: qualidade gráfica, volume/liga-desliga da música e dos efeitos sonoros e o 📖 HOW TO PLAY
-- (abre o guia do tutorial, Systems/Tutorial — menu "Guide" do HUD).
-- Tudo vive em atributos do LocalPlayer (lidos pelos outros sistemas):
--   GraphicsQuality ("Alto" | "Médio" | "Baixo"), MusicVolume (0..1), MusicaMudo (bool),
--   SfxVolume (0..1), SfxMudo (bool).
-- O servidor coloca os valores salvos ao entrar; cada mudança é enviada (SaveSettings) para salvar na conta.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Kit"))
local C = Kit.C

local Settings = {}

local player = Players.LocalPlayer

local QUALITIES = { "Baixo", "Médio", "Alto" }
local QUALITY_LABEL = { Baixo = "Low", ["Médio"] = "Medium", Alto = "High" }
local QUALITY_COLOR = { Baixo = C.Orange, ["Médio"] = C.Blue, Alto = C.Green }
local STEP = 0.1

local function volume(attr: string): number
	local v = player:GetAttribute(attr)
	if typeof(v) == "number" and v == v then
		return math.clamp(v, 0, 1)
	end
	return 1
end

-- envia para salvar 1,5 s depois da última mudança (não manda um pedido a cada clique)
local saveToken = 0
local function queueSave()
	saveToken += 1
	local token = saveToken
	task.delay(1.5, function()
		if token ~= saveToken then
			return
		end
		local remote = ReplicatedStorage:FindFirstChild("Remotes")
		remote = remote and remote:FindFirstChild("SaveSettings")
		if remote and remote:IsA("RemoteEvent") then
			remote:FireServer({
				Graphics = player:GetAttribute("GraphicsQuality"),
				Music = volume("MusicVolume"),
				MusicOn = player:GetAttribute("MusicaMudo") ~= true,
				Sfx = volume("SfxVolume"),
				SfxOn = player:GetAttribute("SfxMudo") ~= true,
			})
		end
	end)
end

function Settings.Start(HUD)
	local menu = Kit.Menu({
		Name = "SettingsMenu",
		Title = "⚙️ SETTINGS",
		Color = C.Purple,
		Width = 560,
		Height = 480,
		HeaderHeight = 0.13,
		OnClose = function()
			HUD.CloseAll()
		end,
	})
	local body = menu.Body
	local refreshers = {}
	local function refreshAll()
		for _, fn in ipairs(refreshers) do
			fn()
		end
	end

	local function row(index: number, title: string)
		local box = Kit.Box(body, {
			Position = UDim2.fromScale(0, (index - 1) * 0.255),
			Size = UDim2.fromScale(1, 0.225),
		}, C.Panel2)
		Kit.Text(box, {
			Position = UDim2.fromScale(0.03, 0.22),
			Size = UDim2.fromScale(0.3, 0.56),
			Text = title,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		return box
	end

	---------------------------------------------------------------- gráficos
	local gfx = row(1, "🖥️ Graphics")
	local qualityButtons = {}
	for i, q in ipairs(QUALITIES) do
		local button = Kit.Button(gfx, {
			Position = UDim2.fromScale(0.35 + (i - 1) * 0.215, 0.18),
			Size = UDim2.fromScale(0.2, 0.64),
			Text = QUALITY_LABEL[q],
		}, C.Disabled, function()
			player:SetAttribute("GraphicsQuality", q)
		end)
		qualityButtons[q] = button
	end
	table.insert(refreshers, function()
		local current = player:GetAttribute("GraphicsQuality")
		for q, button in pairs(qualityButtons) do
			Kit.SetButtonColor(button, q == current and QUALITY_COLOR[q] or C.Disabled)
		end
	end)

	---------------------------------------------------------------- volume (música / efeitos)
	local function volumeRow(index: number, title: string, volumeAttr: string, muteAttr: string)
		local box = row(index, title)
		local function setVolume(v: number)
			v = math.clamp(math.floor(v * 10 + 0.5) / 10, 0, 1)
			player:SetAttribute(volumeAttr, v)
			-- mexer no volume liga o som de novo (e volume 0 é o mesmo que desligado)
			player:SetAttribute(muteAttr, v <= 0)
		end
		Kit.Button(box, {
			Position = UDim2.fromScale(0.35, 0.18),
			Size = UDim2.fromScale(0.1, 0.64),
			Text = "−",
		}, C.Blue, function()
			setVolume(volume(volumeAttr) - STEP)
		end)
		local back = Kit.make("Frame", {
			Position = UDim2.fromScale(0.465, 0.36),
			Size = UDim2.fromScale(0.2, 0.28),
			BackgroundColor3 = C.Dark,
			BorderSizePixel = 0,
		}, box)
		Kit.Corner(back, 8)
		local fill = Kit.make("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = C.XP,
			BorderSizePixel = 0,
		}, back)
		Kit.Corner(fill, 8)
		local pct = Kit.Text(back, {
			Size = UDim2.fromScale(1, 1.3),
			Position = UDim2.fromScale(0, -0.15),
			Text = "100%",
			ZIndex = 3,
		})
		Kit.Button(box, {
			Position = UDim2.fromScale(0.68, 0.18),
			Size = UDim2.fromScale(0.1, 0.64),
			Text = "+",
		}, C.Blue, function()
			setVolume(volume(volumeAttr) + STEP)
		end)
		local toggle = Kit.Button(box, {
			Position = UDim2.fromScale(0.8, 0.18),
			Size = UDim2.fromScale(0.17, 0.64),
			Text = "ON",
		}, C.Green, function()
			local nowMuted = player:GetAttribute(muteAttr) == true
			player:SetAttribute(muteAttr, not nowMuted)
			if nowMuted and volume(volumeAttr) <= 0 then
				player:SetAttribute(volumeAttr, 0.5)
			end
		end)
		table.insert(refreshers, function()
			local v = volume(volumeAttr)
			local isMuted = player:GetAttribute(muteAttr) == true
			fill.Size = UDim2.fromScale(isMuted and 0 or v, 1)
			pct.Text = isMuted and "OFF" or (math.floor(v * 100 + 0.5) .. "%")
			toggle.Text = isMuted and "OFF" or "ON"
			Kit.SetButtonColor(toggle, isMuted and C.Red or C.Green)
		end)
		player:GetAttributeChangedSignal(volumeAttr):Connect(refreshAll)
		player:GetAttributeChangedSignal(muteAttr):Connect(refreshAll)
	end
	volumeRow(2, "🎵 Music", "MusicVolume", "MusicaMudo")
	volumeRow(3, "💥 Sound Effects", "SfxVolume", "SfxMudo")

	---------------------------------------------------------------- 📖 guia (os cartões do tutorial)
	local help = row(4, "📖 How to Play")
	local guideButton = Kit.Button(help, {
		Position = UDim2.fromScale(0.35, 0.18),
		Size = UDim2.fromScale(0.62, 0.64),
		Text = Kit.IsTouch() and "📖 OPEN THE GUIDE" or "📖 OPEN THE GUIDE (H)",
	}, C.Gold, function()
		HUD.Toggle("Guide")
	end)
	Kit.Pulse(guideButton, 0.04, 1.6)

	player:GetAttributeChangedSignal("GraphicsQuality"):Connect(refreshAll)
	refreshAll()
	-- salva qualquer mudança, venha de onde vier (ex.: botão 🔊 da música)
	for _, attr in ipairs({ "GraphicsQuality", "MusicVolume", "MusicaMudo", "SfxVolume", "SfxMudo" }) do
		player:GetAttributeChangedSignal(attr):Connect(queueSave)
	end

	HUD.RegisterMenu("Settings", {
		Open = function()
			refreshAll()
			menu.Show(true)
		end,
		Close = function()
			menu.Show(false)
		end,
	})
end

return Settings
