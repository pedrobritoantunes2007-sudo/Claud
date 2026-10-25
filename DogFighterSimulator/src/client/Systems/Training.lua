-- 🥊 Botão TRAIN: aparece embaixo, no meio, enquanto o cachorro está batendo no estande de treino.
-- Cada toque = batida extra (o servidor limita a Config.TRAIN_CLICK_RATE por segundo).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local UI = script.Parent.Parent:WaitForChild("UI")
local Kit = require(UI:WaitForChild("Kit"))
local Net = require(script.Parent.Parent:WaitForChild("Net"))

local Training = {}

local player = Players.LocalPlayer

function Training.Start(_HUD)
	if not Config.HOUSES then
		return -- 2026-10: o estande de treino saiu (o XP vem das 📜 missões)
	end
	local _, root = Kit.Screen("Training", 6)
	local last = 0
	local button
	local function hit()
		local now = os.clock()
		if now - last < 1 / Config.TRAIN_CLICK_RATE then
			return
		end
		last = now
		Net.Remotes.TrainClick:FireServer()
		local scale = button:FindFirstChild("ButtonScale")
		if scale then
			scale.Scale = 0.88
			Kit.Tween(scale, 0.15, { Scale = 1 }, Enum.EasingStyle.Back)
		end
	end
	button = Kit.Button(root, {
		Name = "TrainButton",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -170), -- acima da barra de habilidades
		Size = UDim2.fromOffset(220, 74),
		Text = "🥊 TRAIN!",
		Visible = false,
	}, Kit.C.Orange, hit)
	Kit.Text(button, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 2),
		Size = UDim2.new(1.2, 0, 0, 22),
		Text = Kit.IsTouch() and "tap fast for bonus XP" or "click or press T for bonus XP",
		TextColor3 = Kit.C.Muted,
	})
	local function refresh()
		button.Visible = player:GetAttribute("Training") == true
	end
	player:GetAttributeChangedSignal("Training"):Connect(refresh)
	refresh()
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.T and button.Visible then
			hit()
		end
	end)
end

return Training
