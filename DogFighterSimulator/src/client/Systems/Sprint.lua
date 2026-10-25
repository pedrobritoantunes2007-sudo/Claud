-- 🏃 Correr: segurar Shift (PC), L3 (controle) ou o botão RUN (celular, liga/desliga).
-- O personagem é o cachorro: anda na velocidade dele (atributo BaseSpeed do modelo) e corre ×RUN_MULT.
-- A câmera abre um pouco o FOV para dar sensação de velocidade.
-- (2026-10-23, pedido do dono: "a trava no Ctrl e correr no Shift" — a 🔒 trava da câmera, no DogControl, é o Ctrl.
-- O Shift Lock do próprio Roblox continua desligado no default.project.json: o nosso conhece o cachorro e o voo.)
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Kit = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Kit"))
local TouchPad = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("TouchPad"))

local Sprint = {}

local WALK_SPEED = 16 -- avatar (antes de escolher o primeiro cachorro)
local RUN_MULT = 1.6
local WALK_FOV = 70
local RUN_FOV = 78

local player = Players.LocalPlayer
local running = false
local runButton = nil -- botão do celular (TouchPad)

local function apply()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	-- AutoControl: o servidor está controlando o cachorro (ida para a Arena, luta, torre): não mexe
	if humanoid and not player:GetAttribute("AutoControl") then
		local base = character:GetAttribute("BaseSpeed") or WALK_SPEED
		humanoid.WalkSpeed = running and base * RUN_MULT or base
	end
	local camera = workspace.CurrentCamera
	if camera then
		TweenService:Create(camera, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { FieldOfView = running and RUN_FOV or WALK_FOV }):Play()
	end
	if runButton then
		runButton.Set({ Active = running })
	end
end

local function setRunning(value: boolean)
	if running == value then
		return
	end
	running = value
	apply()
end

function Sprint.Start(_HUD)
	ContextActionService:BindAction("Sprint", function(_, state)
		if state == Enum.UserInputState.Begin then
			setRunning(true)
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			setRunning(false)
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.ButtonL3)

	-- celular: botão redondo que liga/desliga (segurar o dedo enquanto anda com o analógico é ruim)
	runButton = TouchPad.Add("Run", { Icon = "🏃", Icon3D = "wind", Label = "RUN", Color = Kit.C.Green, Order = 1 }, function()
		setRunning(not running)
	end)

	player:GetAttributeChangedSignal("AutoControl"):Connect(apply)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid", 10)
		apply()
		-- orbe ⚡ SPEED (e troca de cachorro) muda a velocidade base
		character:GetAttributeChangedSignal("BaseSpeed"):Connect(apply)
	end)
	if player.Character then
		apply()
	end
end

return Sprint
