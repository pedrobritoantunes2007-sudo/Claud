-- 🧍🐶 BOTÃO PESSOA ⇄ CACHORRO no canto de baixo à esquerda do HUD (2026-10-25, pedido do dono: "coloca um botão que
-- aparece no HUD embaixo no canto inferior esquerdo, Z para humano, e quando você é um humano aparece um cachorro").
-- Faz o mesmo que a tecla Z (DogControl → remote ToggleHuman). Cachorro: bonequinho + "HUMAN"; pessoa: cachorro + "DOG".
-- No celular sem teclado quem faz isso é o botão redondo do TouchPad (o canto de baixo à esquerda é do analógico).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local UI = script.Parent.Parent:WaitForChild("UI")
local Kit = require(UI:WaitForChild("Kit"))
local Icons = require(UI:WaitForChild("Icons"))
local Net = require(script.Parent.Parent:WaitForChild("Net"))

local HumanButton = {}
local C = Kit.C

function HumanButton.Start(_HUD)
	local player = Players.LocalPlayer
	local gui, root = Kit.Screen("HumanButton", 6)
	gui.Enabled = true
	local button = Kit.Button(root, {
		Name = "HumanToggle",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -16),
		Size = UDim2.fromOffset(92, 92),
		Visible = false,
	}, C.Blue, function()
		ReplicatedStorage.Remotes.ToggleHuman:FireServer()
	end)
	local icon = Icons.Make(button, "person", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, -0.06),
		Size = UDim2.fromScale(0.72, 0.72),
		ZIndex = 3,
	})
	local label = Kit.Text(button, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1.08),
		Size = UDim2.fromScale(1.05, 0.3),
		Text = "HUMAN",
		Font = Kit.Title,
		ZIndex = 3,
	})
	-- a tecla (Z) num selinho no canto, igual aos golpes
	local _key, keyLabel = Kit.Chip(button, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.92, 0.1),
		Size = UDim2.fromOffset(30, 30),
		ZIndex = 4,
	}, C.Panel, "Z")
	keyLabel.Font = Kit.Title
	keyLabel.ZIndex = 5

	local function refresh()
		local human = player:GetAttribute("HumanMode") == true
		Icons.Set(icon, human and "dog" or "person")
		label.Text = human and "DOG" or "HUMAN"
		Kit.SetButtonColor(button, human and C.Orange or C.Blue)
		-- só depois do 1º cachorro, e no celular sem teclado fica o botão do TouchPad
		local started = Net.Profile ~= nil and Net.Profile.Started == true
		button.Visible = started and (UserInputService.KeyboardEnabled or not UserInputService.TouchEnabled)
	end
	player:GetAttributeChangedSignal("HumanMode"):Connect(refresh)
	Net.Changed.Event:Connect(refresh)
	UserInputService.LastInputTypeChanged:Connect(refresh)
	refresh()
end

return HumanButton
