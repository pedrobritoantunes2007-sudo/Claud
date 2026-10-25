-- Ponto de entrada do cliente.
-- Sistemas extras: qualquer ModuleScript em Client/Systems com função Start(HUD) é iniciado automaticamente.
local Animator = require(script.Parent:WaitForChild("Animator"))
local Effects = require(script.Parent:WaitForChild("Effects"))
local UI = script.Parent:WaitForChild("UI")
local HUD = require(UI:WaitForChild("HUD"))

-- (2026-10) cada parte começa protegida: um erro numa delas não apaga o HUD inteiro nem trava o resto
local function safe(name, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		warn("[Client] erro ao iniciar", name, err)
	end
end
safe("Animator", Animator.Start)
safe("Effects", Effects.Start)
-- 🎬 tela de entrada (nome do jogo + ilhas vistas do alto + PLAY) antes de tudo; o tutorial espera o PLAY
safe("Title", function()
	require(UI:WaitForChild("Title")).Start()
end)
safe("HUD", HUD.Start)
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
for _, name in ipairs({ "ShopMenu", "DogsMenu", "MapMenu", "BossMenu", "Hatch" }) do
	-- 🏰 (2026-10) sem a Boss Tower (Config.BOSS_TOWER = false) a tela do BOSS nem é montada
	if name ~= "BossMenu" or Config.BOSS_TOWER then
		safe(name, function()
			require(UI:WaitForChild(name)).Start(HUD)
		end)
	end
end
local systems = script.Parent:WaitForChild("Systems")
for _, module in ipairs(systems:GetChildren()) do
	if module:IsA("ModuleScript") then
		task.spawn(function()
			local ok, err = pcall(function()
				require(module).Start(HUD)
			end)
			if not ok then
				warn("[Client] erro ao iniciar", module.Name, err)
			end
		end)
	end
end
-- (2026-10: a tela "escolha seu primeiro cachorro" saiu — o 1º cachorro é o sorteio do Prof. Barkley na Pawville,
-- Systems/Starter, que inicia sozinho como os outros sistemas)
