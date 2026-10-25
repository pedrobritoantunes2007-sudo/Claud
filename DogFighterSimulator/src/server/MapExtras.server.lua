-- Extras do mapa: depois que o MapBuilder termina (workspace.Map existe), roda Build(map)
-- de cada ModuleScript em ServerScriptService.Server.MapExtras. Cada módulo é independente.
local map = workspace:WaitForChild("Map", 60)
if not map then
	warn("[MapExtras] workspace.Map não apareceu")
	return
end
local extras = script.Parent:WaitForChild("MapExtras")
local pending = 0
for _, module in ipairs(extras:GetChildren()) do
	if module:IsA("ModuleScript") then
		pending += 1
		task.spawn(function()
			local ok, err = pcall(function()
				require(module).Build(map)
			end)
			if not ok then
				warn("[MapExtras] erro em", module.Name, err)
			end
			pending -= 1
		end)
	end
end
-- quando todos os extras terminarem: tira os "blocos piscando" da ilha principal inteira (World/AntiPisca)
task.spawn(function()
	local t0 = os.clock()
	while pending > 0 and os.clock() - t0 < 120 do
		task.wait(0.5)
	end
	local ok, err = pcall(function()
		local AntiPisca = require(script.Parent.World.AntiPisca)
		local n = AntiPisca.Fix({ map }, function()
			task.wait()
		end)
		print("[AntiPisca] ilha principal: " .. n .. " faces corrigidas")
	end)
	if not ok then
		warn("[AntiPisca] ilha principal:", err)
	end
end)
