-- 🧑‍🤝‍🧑 Teste do povo da Pawville (sem Roblox): python3 tools/preview/run_shared.py tools/preview/village_stars_test.luau
-- 1) Village.Residents: TODO o povo vira avatar de verdade (amigos do dono), na ordem de Village.RESIDENTS (quem passeia
--    com cachorro primeiro, depois conversa, passeia, banco, vendedores...).
-- 2) VillageFolk.FromAvatar + Pose com um avatar R15 de mentirinha (medidas de um R15 de verdade, juntas Motor6D):
--    em pé o pé encosta no chão, sentado o quadril fica no assento e a canela desce, andando o joelho dobra.
local Village = require(Shared.Village)
local VillageFolk = require(Shared.VillageFolk)

local fails = 0
local function check(ok, msg)
	if not ok then
		fails += 1
		print("FALHOU: " .. msg)
	end
end

---------------------------------------------------------------- 1) moradores
local cast = Village.Cast(2026)
local slotOf = Village.Residents(cast)
local byRole, n = {}, 0
local owners = {}
for _, a in ipairs(cast) do
	if a.Kind == "Dog" and a.Role == "Leash" then
		owners[a.Owner] = true
	end
end
local order = {}
for i, k in pairs(slotOf) do
	order[k] = i
	n += 1
end
for k = 1, n do
	local a = cast[order[k]]
	check(a ~= nil, "lugar " .. k .. " sem pessoa")
	local g = (a.Role == "Walk" and owners[order[k]]) and "WalkDog" or a.Role
	byRole[g] = (byRole[g] or 0) + 1
	-- a ordem dos grupos nunca volta para trás
	if k > 1 then
		local prev = cast[order[k - 1]]
		local pg = (prev.Role == "Walk" and owners[order[k - 1]]) and "WalkDog" or prev.Role
		check(table.find(Village.RESIDENTS, pg) <= table.find(Village.RESIDENTS, g), "ordem dos moradores em " .. k)
	end
end
local folkCount = 0
for i, a in ipairs(cast) do
	if a.Kind == "Folk" then
		folkCount += 1
		check(slotOf[i] ~= nil, "pessoa sem lugar de avatar: " .. a.Role)
	end
end
check(n == folkCount, "nem todo o povo tem lugar de avatar")
print(string.format("lugares: %d (com cachorro %d, conversa %d, passeio %d, banco %d, vendedor %d, praia %d, crianças %d)", n, byRole.WalkDog or 0, byRole.Chat or 0, byRole.Walk or 0, byRole.Sit or 0, byRole.Vendor or 0, byRole.Beach or 0, byRole.Kids or 0))
check(n >= 40, "menos de 40 lugares de pessoa")
check((byRole.WalkDog or 0) >= 1 and order[1] and owners[order[1]], "o 1º do ranking passeia com cachorro")

---------------------------------------------------------------- 2) avatar R15 de mentirinha
-- medidas de um R15: chão em Y = 0, HipHeight 2, raiz (2x2x1) no meio em Y = 3
local tpl = Instance.new("Model")
tpl.Name = "Star_01"
local function part(name, size, y, x)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = CFrame.new(x or 0, y, 0)
	p.Parent = tpl
	return p
end
local hrp = part("HumanoidRootPart", Vector3.new(2, 2, 1), 3)
local lt = part("LowerTorso", Vector3.new(2, 0.4, 1), 2.2)
local ut = part("UpperTorso", Vector3.new(2, 1.6, 1), 3.2)
local head = part("Head", Vector3.new(2, 1, 1), 4.5)
local parts = { HumanoidRootPart = hrp, LowerTorso = lt, UpperTorso = ut, Head = head }
for _, side in ipairs({ "Left", "Right" }) do
	local sx = side == "Left" and -1 or 1
	parts[side .. "UpperArm"] = part(side .. "UpperArm", Vector3.new(1, 1, 1), 3.4, sx * 1.5)
	parts[side .. "LowerArm"] = part(side .. "LowerArm", Vector3.new(1, 1, 1), 2.4, sx * 1.5)
	parts[side .. "Hand"] = part(side .. "Hand", Vector3.new(1, 0.3, 1), 1.75, sx * 1.5)
	parts[side .. "UpperLeg"] = part(side .. "UpperLeg", Vector3.new(1, 1, 1), 1.5, sx * 0.5)
	parts[side .. "LowerLeg"] = part(side .. "LowerLeg", Vector3.new(1, 0.8, 1), 0.6, sx * 0.5)
	parts[side .. "Foot"] = part(side .. "Foot", Vector3.new(1, 0.2, 1), 0.1, sx * 0.5)
end
local motors = {}
local function motor(name, p0, p1, c0, c1)
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = parts[p0]
	m.Part1 = parts[p1]
	m.C0 = c0
	m.C1 = c1
	m.Parent = parts[p1]
	table.insert(motors, m)
end
motor("Root", "HumanoidRootPart", "LowerTorso", CFrame.new(0, -0.8, 0), CFrame.new())
motor("Waist", "LowerTorso", "UpperTorso", CFrame.new(0, 0.2, 0), CFrame.new(0, -0.8, 0))
motor("Neck", "UpperTorso", "Head", CFrame.new(0, 0.8, 0), CFrame.new(0, -0.5, 0))
for _, side in ipairs({ "Left", "Right" }) do
	local sx = side == "Left" and -1 or 1
	motor(side .. "Shoulder", "UpperTorso", side .. "UpperArm", CFrame.new(sx * 1.5, 0.7, 0), CFrame.new(0, 0.5, 0))
	motor(side .. "Elbow", side .. "UpperArm", side .. "LowerArm", CFrame.new(0, -0.5, 0), CFrame.new(0, 0.5, 0))
	motor(side .. "Wrist", side .. "LowerArm", side .. "Hand", CFrame.new(0, -0.5, 0), CFrame.new(0, 0.15, 0))
	motor(side .. "Hip", "LowerTorso", side .. "UpperLeg", CFrame.new(sx * 0.5, -0.2, 0), CFrame.new(0, 0.5, 0))
	motor(side .. "Knee", side .. "UpperLeg", side .. "LowerLeg", CFrame.new(0, -0.5, 0), CFrame.new(0, 0.4, 0))
	motor(side .. "Ankle", side .. "LowerLeg", side .. "Foot", CFrame.new(0, -0.4, 0), CFrame.new(0, 0.1, 0))
end
local hum = Instance.new("Humanoid")
hum.Parent = tpl
tpl:SetAttribute("RootH", 3)
local script = Instance.new("LocalScript") -- molde nunca leva script junto
script.Name = "Animate"
script.Parent = tpl

-- cinemática: cada peça segue a junta (Part1 = Part0 * C0 * C1⁻¹), a partir da raiz
local function solve(model)
	local list = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d.ClassName == "Motor6D" then
			table.insert(list, d)
		end
	end
	for _ = 1, #list do
		for _, m in ipairs(list) do
			m.Part1.CFrame = m.Part0.CFrame * m.C0 * m.C1:Inverse()
		end
	end
end
local function bottomOf(p)
	-- ponto mais baixo da caixa girada
	local cf, s = p.CFrame, p.Size / 2
	local low = math.huge
	for _, dx in ipairs({ -1, 1 }) do
		for _, dy in ipairs({ -1, 1 }) do
			for _, dz in ipairs({ -1, 1 }) do
				low = math.min(low, cf:PointToWorldSpace(Vector3.new(dx * s.X, dy * s.Y, dz * s.Z)).Y)
			end
		end
	end
	return low
end

local folder = Instance.new("Folder")
local G = 10 -- chão em Y = 10
local rig = VillageFolk.FromAvatar(tpl, folder, CFrame.new(5, G, 7))
check(rig ~= nil, "FromAvatar devolveu nil")
if rig then
	check(rig.Avatar == true and rig.Hand ~= nil and rig.Joints.LK ~= nil, "rig do avatar sem mão/joelho")
	check(math.abs(rig.HipToRoot - 1) < 0.01, "quadril até a raiz = " .. rig.HipToRoot)
	check(rig.Model:FindFirstChild("Animate") == nil, "script do molde foi junto")
	check(rig.Root.Anchored == true, "raiz não ancorada")
	-- em pé
	VillageFolk.Pose(rig, 0, {})
	rig.Root.CFrame = CFrame.new(5, G + VillageFolk.RootHeight(rig, "Stand"), 7)
	solve(rig.Model)
	local foot = rig.Model:FindFirstChild("LeftFoot")
	print(string.format("em pé: pé em %.2f (chão %d), cabeça em %.2f", bottomOf(foot), G, rig.Head.Position.Y))
	check(math.abs(bottomOf(foot) - G) < 0.15, "em pé o pé não encosta no chão")
	-- sentado no banco (assento em 2,2)
	VillageFolk.Pose(rig, 0, { Sit = 1 })
	rig.Root.CFrame = CFrame.new(5, G + VillageFolk.RootHeight(rig, "Sit"), 7)
	solve(rig.Model)
	local ul, ll = rig.Model:FindFirstChild("LeftUpperLeg"), rig.Model:FindFirstChild("LeftLowerLeg")
	local hipY = (lt.CFrame * CFrame.new(-0.5, -0.2, 0)).Y
	hipY = (rig.Model:FindFirstChild("LowerTorso").CFrame * CFrame.new(-0.5, -0.2, 0)).Y
	print(string.format("sentado: quadril em %.2f (assento %.1f), coxa a %.2f, canela a %.2f", hipY - G, 2.2, ul.Position.Y - G, ll.Position.Y - G))
	check(math.abs(hipY - (G + 2.2)) < 0.05, "sentado o quadril não fica no assento")
	check(math.abs(ul.Position.Y - hipY) < 0.05, "sentado a coxa não fica deitada")
	check(math.abs(ul.CFrame.UpVector.Y) < 0.1, "sentado a coxa não fica deitada (giro)")
	check(ll.CFrame.UpVector.Y > 0.9 and ll.Position.Y < ul.Position.Y - 0.3, "sentado a canela não desce")
	-- sentado no chão (praia)
	VillageFolk.Pose(rig, 0, { SitGround = 1 })
	rig.Root.CFrame = CFrame.new(5, G + VillageFolk.RootHeight(rig, "SitGround"), 7)
	solve(rig.Model)
	print(string.format("na areia: pé em %.2f", bottomOf(rig.Model:FindFirstChild("LeftFoot")) - G))
	check(bottomOf(rig.Model:FindFirstChild("LeftFoot")) > G - 0.12, "sentado na areia o pé entra no chão")
	-- andando: a perna de trás dobra o joelho
	VillageFolk.Pose(rig, 0, { Walk = 1, Phase = math.pi / 2 })
	local lk, rk = rig.Joints.LK, rig.Joints.RK
	local function bend(j, base)
		local _, _, _, _, _, _, _, r11 = (base:Inverse() * j.C0):GetComponents()
		return r11
	end
	print(string.format("andando: joelhos cos = %.2f / %.2f", bend(lk, rig.Base.LK), bend(rk, rig.Base.RK)))
	check(bend(lk, rig.Base.LK) > 0.99 or bend(rk, rig.Base.RK) > 0.99, "andando os 2 joelhos dobrados")
	check(bend(lk, rig.Base.LK) < 0.99 or bend(rk, rig.Base.RK) < 0.99, "andando nenhum joelho dobra")
end
-- altura do avatar pelas JUNTAS: HipHeight errado (0, como às vezes vem do servidor) e peças fora do lugar não
-- mudam nada (antes a raiz ia para HipHeight + meia raiz = 1 e as pernas entravam no chão)
local tpl2 = tpl:Clone()
tpl2:SetAttribute("RootH", nil)
tpl2:FindFirstChildOfClass("Humanoid").HipHeight = 0
for _, d in ipairs(tpl2:GetDescendants()) do
	if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
		d.CFrame = CFrame.new(0, 50, 0) -- desmontado
	end
end
local h2 = VillageFolk.AvatarRootHeight(tpl2)
print(string.format("altura pelas juntas: %.2f", h2 or -1))
check(h2 ~= nil and math.abs(h2 - 3) < 0.05, "altura do avatar pelas juntas errada")
local rig2 = VillageFolk.FromAvatar(tpl2, folder, CFrame.new(0, G, 0))
check(rig2 ~= nil and math.abs(rig2.RootH - 3) < 0.05, "FromAvatar não usou a altura das juntas")
-- o 🎓 professor de verdade (avatar montado pelo servidor) também vira rig
local prof = tpl:Clone()
prof.Parent = folder
check(VillageFolk.RigFrom(prof) ~= nil and VillageFolk.RigFrom(prof).Avatar == true, "RigFrom não aceita o professor avatar")

-- 🖼️ (2026-10-23) retrato do tutorial: a cabeça pelas juntas (HeadRel, com as peças ainda fora do lugar) e a cópia do
-- professor do palco sem o botão "Talk" nem a plaquinha (o original continua com eles)
local headY = rig2 and rig2.HeadRel and rig2.HeadRel.Position.Y
print(string.format("cabeça pelas juntas: %.2f acima da raiz", headY or -1))
check(headY ~= nil and math.abs(headY - 1.5) < 0.05, "HeadRel errado")
local pp = Instance.new("ProximityPrompt")
pp.Parent = prof:FindFirstChild("HumanoidRootPart")
local bb = Instance.new("BillboardGui")
bb.Parent = prof:FindFirstChild("Head")
local copy = VillageFolk.FromAvatar(prof, folder, CFrame.new())
local leaked = false
for _, d in ipairs(copy and copy.Model:GetDescendants() or {}) do
	if d:IsA("ProximityPrompt") or d:IsA("BillboardGui") then
		leaked = true
	end
end
check(copy ~= nil and not leaked, "a cópia do professor levou o botão/plaquinha")
check(pp.Parent ~= nil and bb.Parent ~= nil, "o professor de verdade perdeu o botão/plaquinha")

-- molde sem as juntas: não serve (a vila usa o povo de blocos)
local bad = Instance.new("Model")
local r = Instance.new("Part")
r.Name = "HumanoidRootPart"
r.Parent = bad
check(VillageFolk.FromAvatar(bad, folder, CFrame.new()) == nil, "molde sem juntas foi aceito")

print(fails == 0 and "OK: povo da vila" or ("FALHAS: " .. fails))
