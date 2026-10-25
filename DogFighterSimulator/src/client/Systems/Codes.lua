-- 🎟️ CODES: janela para digitar um código (botão em cima do SETTINGS, no Visuals).
-- Quem confere e entrega é o servidor (CodeService, remote RedeemCode).
local Players = game:GetService("Players")

local UI = script.Parent.Parent:WaitForChild("UI")
local Kit = require(UI:WaitForChild("Kit"))
local Net = require(script.Parent.Parent:WaitForChild("Net"))

local Codes = {}
local make = Kit.make
local C = Kit.C

function Codes.Start(HUD)
	local _player = Players.LocalPlayer
	local menu = Kit.Menu({
		Name = "CodesMenu",
		Title = "🎟️ CODES",
		Color = C.Pink,
		Width = 520,
		Height = 300,
		HeaderHeight = 0.2,
		OnClose = function()
			HUD.CloseAll()
		end,
	})
	local body = menu.Body
	Kit.Text(body, {
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromScale(1, 0.2),
		Text = "Type a code and press REDEEM",
		TextColor3 = C.Muted,
	})
	local input = make("TextBox", {
		Position = UDim2.fromScale(0.05, 0.26),
		Size = UDim2.fromScale(0.9, 0.26),
		Font = Kit.Font,
		TextScaled = true,
		Text = "",
		PlaceholderText = "CODE",
		BackgroundColor3 = Color3.fromRGB(245, 245, 250),
		TextColor3 = Color3.fromRGB(30, 25, 40),
		ClearTextOnFocus = false,
		ZIndex = 3,
	}, body)
	Kit.Corner(input, 10)
	Kit.Stroke(input, C.Dark, 3)
	make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0.12, 0), PaddingBottom = UDim.new(0.12, 0) }, input)
	local result = Kit.Text(body, {
		Position = UDim2.fromScale(0, 0.56),
		Size = UDim2.fromScale(1, 0.16),
		Text = "",
		TextColor3 = C.Muted,
	})
	local busy = false
	local redeem = Kit.Button(body, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.76),
		Size = UDim2.fromScale(0.5, 0.22),
		Text = "REDEEM",
	}, C.Green)
	local function submit()
		local code = input.Text
		if busy or code:gsub("%s", "") == "" then
			return
		end
		busy = true
		redeem.Text = "..."
		local ok, message = Net.Invoke("RedeemCode", code)
		busy = false
		redeem.Text = "REDEEM"
		result.Text = type(message) == "string" and message or (ok and "✔ Done!" or "❌ Invalid code")
		result.TextColor3 = ok and C.Green or C.Red
		if ok then
			input.Text = ""
		end
	end
	redeem.Activated:Connect(submit)
	input.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			submit()
		end
	end)

	HUD.RegisterMenu("Codes", {
		Open = function()
			result.Text = ""
			menu.Show(true)
		end,
		Close = function()
			menu.Show(false)
		end,
	})
end

return Codes
