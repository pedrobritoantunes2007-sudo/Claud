-- 🏝️ Ilhas do mapa (2026-10, pedido do dono: a Arena saiu; cada raridade tem a sua ilha).
-- Dados compartilhados entre servidor e cliente: posição, formato (para saber "em que ilha estou"),
-- preço para abrir, ovo vendido lá, níveis dos cachorros selvagens, campeão e portal HOME.
-- Coordenadas "locais" de cada ilha: +Z local aponta para a ilha principal (o portal HOME fica desse lado).
-- 1 unidade = 1 stud. Norte = −Z (igual ao resto do jogo).
local Layout = require(script.Parent.Layout)

local Islands = {}

-- (2026-10, pedido do dono: "deixa as outras ilhas um pouco mais afastadas") era 2000
Islands.RING = 2500 -- distância do centro do mapa até o centro de cada ilha de raridade
Islands.CLOUD_Y = 700 -- altura do Reino das Nuvens

-- ordem do menu MAP e da aventura (as 7 de raridade + as nuvens no fim)
Islands.ORDER = { "common", "uncommon", "rare", "epic", "legendary", "mythic", "divine", "cloud" }

local function ringPos(i)
	local a = math.rad(90 + (i - 1) * 360 / 7)
	return Vector3.new(math.cos(a) * Islands.RING, 0, math.sin(a) * Islands.RING)
end

local CLOUD_AZ = math.rad(272) -- ao norte, depois da Boss Tower (entre a Pirate Cove e o vulcão)
-- (a ilha principal cresceu Layout.ARENA_GROW: as nuvens e o gêiser andaram junto, a ponte do rochedo não muda)
local CLOUD_R, GEYSER_R = 1350 + Layout.ARENA_GROW, 1062 + Layout.ARENA_GROW
Islands.CLOUD_CENTER = Vector3.new(math.cos(CLOUD_AZ) * CLOUD_R, Islands.CLOUD_Y, math.sin(CLOUD_AZ) * CLOUD_R)
-- Gêiser do Céu: ilhota atrás da Boss Tower, a coluna de vento sobe até as nuvens
Islands.GEYSER = Vector3.new(math.cos(CLOUD_AZ) * GEYSER_R, 0, math.sin(CLOUD_AZ) * GEYSER_R)

-- Formato aproximado de cada ilha em círculos locais { x, z, raio } (e "Holes" = lagoas/baías sem chão).
-- Serve para: em que ilha o jogador está, onde os selvagens podem andar/renascer e para onde voltar quem cai.
-- Wild = quantos selvagens a ilha tem (2026-10: o DOBRO, pedido do dono: "está tendo pouco cachorro"; e o DOBRO de
-- novo junto com a Pawville: "aumente o dobro de cachorro em cada ilha"; 2026-10-25, com a captura: "dobra o número de
-- cachorro em cada ilha" → o DOBRO outra vez. Só existem com jogador na ilha — NPCService)
Islands.List = {
	common = {
		Name = "Puppy Meadows",
		Rarity = "Common",
		Theme = "Farm",
		Center = ringPos(1),
		Price = 0,
		Egg = "paw",
		Levels = { 1, 8 },
		Wild = 80,
		Champion = { Species = "bulldog", Name = "Big Bruno", Level = 10, Scale = 3.4 },
		ChampionAt = Vector3.new(-229, 0, -447), -- 2º dedo da pata
		Portal = Vector3.new(0, 0, 470),
		Shape = {
			{ 0, 150, 380 }, { -170, 140, 290 }, { 170, 140, 290 }, { 0, 330, 300 },
			{ -565, -150, 140 }, { -229, -447, 155 }, { 229, -447, 155 }, { 565, -150, 140 },
		},
	},
	uncommon = {
		Name = "Frosty Peaks",
		Rarity = "Uncommon",
		Theme = "Snow",
		Center = ringPos(2),
		Price = 2000, -- (2026-10-24: era 1500; cada ilha custa cada vez mais)
		Requires = "common",
		Egg = "spotted",
		Levels = { 8, 16 },
		Wild = 80,
		Champion = { Species = "snow_husky", Name = "Alpha Husky", Level = 18, Scale = 3.6 },
		ChampionAt = Vector3.new(0, 0, 255), -- no meio do lago congelado
		Portal = Vector3.new(300, 0, 380),
		Shape = { { 0, 0, 520 } },
		Holes = { { 0, 545, 190 } }, -- baía aberta para o mar
	},
	rare = {
		Name = "Bone Canyon",
		Rarity = "Rare",
		Theme = "Desert",
		Center = ringPos(3),
		Price = 11000, -- (2026-10-24: era 7500; cada ilha custa cada vez mais)
		Requires = "uncommon",
		Egg = "blue",
		Levels = { 15, 25 },
		Wild = 80,
		Champion = { Species = "horned_pup", Name = "Canyon King", Level = 28, Scale = 3.6 },
		ChampionAt = Vector3.new(700, 0, -120),
		Portal = Vector3.new(-560, 0, 300),
		Shape = {
			{ -470, 0, 160 }, { -235, 0, 160 }, { 0, 0, 160 }, { 235, 0, 160 }, { 470, 0, 160 },
			{ 600, 170, 205 }, { 600, -170, 205 }, { -600, 170, 205 }, { -600, -170, 205 },
		},
	},
	epic = {
		Name = "Pirate Cove",
		Rarity = "Epic",
		Theme = "Pirate",
		Center = ringPos(4),
		Price = 60000, -- (2026-10-24: era 35000; cada ilha custa cada vez mais)
		Requires = "rare",
		Egg = "crystal",
		Levels = { 24, 36 },
		Wild = 72,
		Champion = { Species = "pirate_dog", Name = "Captain Barkbeard", Level = 38, Scale = 3 },
		ChampionAt = Vector3.new(-16.7, 0, 114.6), -- no convés do navio ancorado no cais
		ChampionY = 26.7, -- altura do convés (Epic.DECK_Y)
		Portal = Vector3.new(-160, 0, 452),
		Shape = { { 0, 0, 548 } },
		Holes = { { 0, 40, 300 }, { 0, 470, 62 } }, -- lagoa e entrada do mar
	},
	legendary = {
		Name = "Inferno Volcano",
		Rarity = "Legendary",
		Theme = "Volcano",
		Center = ringPos(5),
		Price = 330000, -- (2026-10-24: era 175000; cada ilha custa cada vez mais)
		Requires = "epic",
		Egg = "golden",
		Levels = { 35, 50 },
		Wild = 72,
		Champion = { Species = "dragon_hound", Name = "Ancient Dragon Hound", Level = 55, Scale = 3.8 },
		ChampionAt = Vector3.new(126, 0, -505),
		Portal = Vector3.new(0, 0, 440),
		Shape = {
			{ 0, 0, 470 },
			{ 117, 553, 85 }, { 503, 257, 85 }, { 512, -239, 85 }, { 137, -548, 85 }, { -348, -445, 85 }, { -565, -10, 85 }, { -356, 439, 85 },
		},
	},
	mythic = {
		Name = "Cosmic Rift",
		Rarity = "Mythic",
		Theme = "Space",
		Center = ringPos(6),
		Price = 1900000, -- (2026-10-24: era 900000; cada ilha custa cada vez mais)
		Requires = "legendary",
		Egg = "celestial",
		Levels = { 48, 75 },
		Wild = 64,
		Champion = { Species = "void_beast", Name = "Void Emperor", Level = 80, Scale = 3.8 },
		ChampionAt = Vector3.new(-430, 154, -170), -- no maior pedaço flutuante
		Portal = Vector3.new(0, 0, 330),
		Shape = { { 0, 30, 330 } },
		-- pedaços flutuantes { x, altura do chão, z, raio }
		Floating = { { 440, 95, -110, 120 }, { -430, 150, -170, 140 }, { 60, 230, -480, 130 }, { 500, 65, 300, 90 }, { -500, 115, 290, 95 } },
	},
	divine = {
		Name = "Sunfire Sanctum",
		Rarity = "Divine",
		Theme = "Temple",
		Center = ringPos(7),
		Price = 7500000, -- (2026-10-24: era 3000000; cada ilha custa cada vez mais)
		Requires = "mythic",
		Egg = nil, -- o Divino continua só por Robux (altar na ilha)
		Levels = { 75, 100 },
		Wild = 64,
		Golden = true, -- selvagens dourados (Sun Guardians, versões douradas dos míticos)
		Champion = { Species = "sun_dragon", Name = "Sunfire Avatar", Level = 100, Scale = 3.6 },
		ChampionAt = Vector3.new(-180, 0, -434),
		Portal = Vector3.new(0, 0, 372),
		Shape = {
			{ 0, 0, 395 },
			{ 191, 462, 60 }, { 462, 191, 60 }, { 462, -191, 60 }, { 191, -462, 60 },
			{ -191, -462, 60 }, { -462, -191, 60 }, { -462, 191, 60 }, { -191, 462, 60 },
		},
	},
	cloud = {
		Name = "Sky Kingdom",
		Rarity = "Sky",
		Theme = "Clouds",
		Center = Islands.CLOUD_CENTER,
		Price = 650000, -- (2026-10-24: era 400000; cada ilha custa cada vez mais)
		Requires = "legendary",
		Egg = "sky",
		Levels = { 25, 60 },
		Wild = 56,
		Flyers = true, -- só cachorros que voam, voando de verdade
		Champion = { Species = "seraph_hound", Name = "Sky Seraph", Level = 65, Scale = 3.4 },
		ChampionAt = Vector3.new(-409, 70, -72), -- flutuando sobre uma nuvem
		Portal = Vector3.new(0, 7, 225),
		-- nuvem grande no meio + 6 nuvens menores (o módulo da ilha usa estes mesmos círculos)
		Shape = { { 0, 0, 262 }, { 267, 318, 108 }, { 413, -36, 104 }, { 208, -359, 112 }, { -175, -376, 100 }, { -409, -72, 116 }, { -267, 318, 106 } },
	},
}

-- cor de cada ilha no MAP e nas placas (cor da raridade; as nuvens são azul-céu)
Islands.COLORS = {
	main = Color3.fromRGB(63, 208, 201),
	common = Color3.fromRGB(190, 190, 195),
	uncommon = Color3.fromRGB(90, 220, 110),
	rare = Color3.fromRGB(70, 160, 255),
	epic = Color3.fromRGB(180, 90, 255),
	legendary = Color3.fromRGB(255, 200, 40),
	mythic = Color3.fromRGB(255, 60, 110),
	divine = Color3.fromRGB(255, 140, 40),
	cloud = Color3.fromRGB(124, 200, 255),
}
-- cor do redemoinho de cada portal (tema da ilha)
Islands.SWIRL = {
	common = Color3.fromRGB(139, 224, 106),
	uncommon = Color3.fromRGB(191, 233, 255),
	rare = Color3.fromRGB(255, 169, 77),
	epic = Color3.fromRGB(47, 212, 196),
	legendary = Color3.fromRGB(255, 90, 31),
	mythic = Color3.fromRGB(161, 107, 255),
	divine = Color3.fromRGB(255, 194, 61),
	cloud = Color3.fromRGB(232, 246, 255),
}
Islands.EMOJI = { common = "🌻", uncommon = "❄️", rare = "🦴", epic = "🏴‍☠️", legendary = "🌋", mythic = "🌌", divine = "☀️", cloud = "☁️" }

-- giro de cada ilha: +Z local aponta para o centro do mapa
for _, def in pairs(Islands.List) do
	local c = def.Center
	def.Yaw = math.atan2(-c.X, -c.Z)
	def.CF = CFrame.new(c) * CFrame.Angles(0, def.Yaw, 0)
end
for id, def in pairs(Islands.List) do
	def.Id = id
end

function Islands.Get(id)
	return Islands.List[id]
end

function Islands.ToWorld(id, lx, ly, lz)
	return Islands.List[id].CF:PointToWorldSpace(Vector3.new(lx, ly, lz))
end

function Islands.ToLocal(id, pos)
	return Islands.List[id].CF:PointToObjectSpace(pos)
end

-- CFrame no mundo de um ponto local (com giro local opcional)
function Islands.LocalCFrame(id, lx, ly, lz, ry)
	return Islands.List[id].CF * CFrame.new(lx, ly, lz) * CFrame.Angles(0, ry or 0, 0)
end

-- O ponto local (x, z) está dentro do formato da ilha (com folga `margin`)?
function Islands.InsideLocal(id, x, z, margin)
	local def = Islands.List[id]
	margin = margin or 0
	local inside = false
	for _, c in ipairs(def.Shape) do
		local dx, dz = x - c[1], z - c[2]
		if dx * dx + dz * dz <= (c[3] + margin) ^ 2 then
			inside = true
			break
		end
	end
	if inside and def.Holes and margin <= 0 then
		for _, h in ipairs(def.Holes) do
			local dx, dz = x - h[1], z - h[2]
			if dx * dx + dz * dz <= (h[3] + margin) ^ 2 then
				return false
			end
		end
	end
	return inside
end

-- Em qual ilha de raridade/nuvens está esta posição? (nil = ilha principal, mar ou céu)
-- margin: folga além da praia (ex.: 40 para contar quem está chegando de barco/voando baixo)
function Islands.At(pos, margin)
	margin = margin or 30
	for id, def in pairs(Islands.List) do
		local rel = pos - def.Center
		if rel.X * rel.X + rel.Z * rel.Z < 1000 * 1000 then
			local yOk
			if id == "cloud" then
				yOk = rel.Y > -260 and rel.Y < 500
			else
				yOk = pos.Y < 450
			end
			if yOk then
				local l = def.CF:PointToObjectSpace(pos)
				if Islands.InsideLocal(id, l.X, l.Z, margin) then
					return id
				end
				if def.Floating then
					for _, f in ipairs(def.Floating) do
						local dx, dz = l.X - f[1], l.Z - f[3]
						if dx * dx + dz * dz <= (f[4] + margin) ^ 2 and l.Y > f[2] - 60 then
							return id
						end
					end
				end
			end
		end
	end
	return nil
end

-- Ponto local sorteado dentro do formato (longe da borda), sem cair em lagoa/baía
function Islands.RandomLocal(id, margin, rng)
	local def = Islands.List[id]
	rng = rng or Random.new()
	margin = margin or 20
	-- sorteia um círculo pelo tamanho (área), depois um ponto nele
	local total = 0
	for _, c in ipairs(def.Shape) do
		total += c[3] * c[3]
	end
	for _ = 1, 40 do
		local pick = rng:NextNumber() * total
		local chosen = def.Shape[1]
		for _, c in ipairs(def.Shape) do
			pick -= c[3] * c[3]
			if pick <= 0 then
				chosen = c
				break
			end
		end
		local a = rng:NextNumber(0, math.pi * 2)
		local r = math.sqrt(rng:NextNumber()) * math.max(5, chosen[3] - margin)
		local x, z = chosen[1] + math.cos(a) * r, chosen[2] + math.sin(a) * r
		if Islands.InsideLocal(id, x, z, -margin) or Islands.InsideLocal(id, x, z, 0) then
			return x, z
		end
	end
	local c = def.Shape[1]
	return c[1], c[2]
end

-- Ponto do mundo mais perto, dentro da ilha (para manter os selvagens e os poderes em terra)
function Islands.ClampWorld(id, pos, margin)
	local def = Islands.List[id]
	local l = def.CF:PointToObjectSpace(pos)
	margin = margin or 6
	if Islands.InsideLocal(id, l.X, l.Z, -margin) then
		return pos
	end
	-- leva para dentro do círculo mais perto
	local best, bestD = nil, math.huge
	for _, c in ipairs(def.Shape) do
		local dx, dz = l.X - c[1], l.Z - c[2]
		local d = math.sqrt(dx * dx + dz * dz) - c[3]
		if d < bestD then
			bestD, best = d, c
		end
	end
	local dx, dz = l.X - best[1], l.Z - best[2]
	local len = math.sqrt(dx * dx + dz * dz)
	local maxR = math.max(4, best[3] - margin)
	if len > maxR then
		dx, dz = dx / len * maxR, dz / len * maxR
	end
	local p = def.CF:PointToWorldSpace(Vector3.new(best[1] + dx, l.Y, best[2] + dz))
	return Vector3.new(p.X, pos.Y, p.Z)
end

-- Portal HOME da ilha e ponto de chegada (um pouco para dentro da ilha)
function Islands.PortalCFrame(id)
	local def = Islands.List[id]
	local p = def.Portal
	return def.CF * CFrame.new(p.X, p.Y, p.Z)
end
function Islands.ArrivalPoint(id)
	local def = Islands.List[id]
	local p = def.Portal
	return def.CF:PointToWorldSpace(Vector3.new(p.X, p.Y, p.Z - 34))
end

-- Portal de cada ilha na Praça dos Portais (ilha principal), virado para a ilha
Islands.PLAZA_PORTAL_RADIUS = Layout.PORTAL_RING
-- alguns portais saem um pouco da direção da ilha para não ficar na frente dos portões do Coliseu
-- (0°, 90°, 180°, 270°) nem encostar no portal vizinho (graus, mesmo giro do AzimuthOf)
local PLAZA_ANGLE = { common = 74, epic = 238, cloud = 256 }
function Islands.AzimuthOf(id)
	local c = Islands.List[id].Center
	return math.atan2(c.Z, c.X)
end
function Islands.PlazaAngle(id)
	return PLAZA_ANGLE[id] and math.rad(PLAZA_ANGLE[id]) or Islands.AzimuthOf(id)
end
function Islands.PlazaPortalCFrame(id)
	local a = Islands.PlazaAngle(id)
	local pos = Vector3.new(math.cos(a), 0, math.sin(a)) * Islands.PLAZA_PORTAL_RADIUS
	-- +Z local do portal aponta para fora (para a ilha)
	return CFrame.new(pos) * CFrame.Angles(0, math.atan2(math.cos(a), math.sin(a)), 0)
end

-- Pode abrir esta ilha agora? (precisa da anterior aberta) — só a ORDEM; o que mais falta: Islands.Requirements
function Islands.CanUnlock(unlocked, id)
	local def = Islands.List[id]
	if not def or unlocked[id] then
		return false
	end
	return def.Requires == nil or unlocked[def.Requires] == true
end

-- 🔐 (2026-10-24, pedido do dono: "quero que seja cada vez mais difícil ir para outras ilhas") cada ilha nova pede
-- MAIS que a anterior: além do Cash (Price, que cresce cada vez mais rápido) o cachorro EQUIPADO precisa ter o level
-- mínimo, o 👑 CAMPEÃO da ilha anterior precisa ter sido derrotado e é preciso completar N 📜 missões do NPC de lá.
-- (o servidor conta: data.Champions[ilha] = vitórias contra o campeão, data.IslandQuests[ilha] = missões feitas)
Islands.GATES = {
	uncommon = { Level = 8, Missions = 2 },
	rare = { Level = 16, Missions = 3 },
	epic = { Level = 25, Missions = 4 },
	legendary = { Level = 36, Missions = 5 },
	mythic = { Level = 50, Missions = 6 },
	divine = { Level = 75, Missions = 8 },
	cloud = { Level = 40, Missions = 5 },
}

-- O que precisa para abrir a ilha `id`: lista na ordem { Kind, Need, Have, Done, Name? } e se já dá para abrir.
--   Kind: "island" (a anterior aberta) · "level" (cachorro equipado) · "champion" (vencer o campeão da anterior)
--         · "missions" (missões na anterior) · "cash"
-- data = perfil (Islands, Champions, IslandQuests, Cash) · level = level do cachorro equipado
function Islands.Requirements(data, id, level)
	local def = Islands.List[id]
	local list = {}
	if not def then
		return list, false
	end
	local gate = Islands.GATES[id] or {}
	local prevId = def.Requires
	local prev = prevId and Islands.List[prevId]
	local opened = type(data) == "table" and type(data.Islands) == "table" and data.Islands or {}
	local function count(field)
		local t = type(data) == "table" and data[field]
		return type(t) == "table" and prevId and (tonumber(t[prevId]) or 0) or 0
	end
	if prev then
		table.insert(list, { Kind = "island", Name = prev.Name, Need = 1, Have = opened[prevId] and 1 or 0, Done = opened[prevId] == true })
	end
	if gate.Level then
		local have = tonumber(level) or 0
		table.insert(list, { Kind = "level", Need = gate.Level, Have = have, Done = have >= gate.Level })
	end
	if prev and prev.Champion then
		local have = count("Champions")
		table.insert(list, { Kind = "champion", Name = prev.Champion.Name, Island = prev.Name, Need = 1, Have = math.min(have, 1), Done = have >= 1 })
	end
	if prev and gate.Missions then
		local have = count("IslandQuests")
		table.insert(list, { Kind = "missions", Island = prev.Name, Need = gate.Missions, Have = math.min(have, gate.Missions), Done = have >= gate.Missions })
	end
	local price = def.Price or 0
	if price > 0 then
		local cash = type(data) == "table" and tonumber(data.Cash) or 0
		table.insert(list, { Kind = "cash", Need = price, Have = math.min(cash, price), Done = cash >= price })
	end
	local ok = not opened[id]
	for _, r in ipairs(list) do
		if not r.Done then
			ok = false
		end
	end
	return list, ok
end

-- level do cachorro equipado num perfil (servidor e cliente)
function Islands.EquippedLevel(data)
	local dogs = type(data) == "table" and data.Dogs
	local dog = type(dogs) == "table" and data.Equipped and dogs[data.Equipped]
	return type(dog) == "table" and tonumber(dog.Level) or 0
end

-- 📜 MISSÕES (2026-10, pedido do dono, estilo Blox Fruits): o NPC na entrada de cada ilha dá 2 missões —
--   🐶 normal: derrotar Count selvagens da ilha (prêmio Cash + XP)   👑 boss: derrotar o campeão (BossCash + BossXP).
-- É de onde vem o dinheiro do jogo (selvagem sozinho não paga Cash). Conta feita assim: ~6 missões normais + 1 de
-- boss pagam a próxima ilha, e o XP leva um cachorro do começo ao fim dos níveis da ilha em ~5–10 missões.
Islands.QUESTS = {
	common = { Count = 8, Cash = 220, XP = 380, BossCash = 550, BossXP = 950 },
	uncommon = { Count = 8, Cash = 900, XP = 900, BossCash = 2200, BossXP = 2200 },
	rare = { Count = 8, Cash = 3500, XP = 2200, BossCash = 9000, BossXP = 5500 },
	epic = { Count = 7, Cash = 15000, XP = 5500, BossCash = 38000, BossXP = 13000 },
	legendary = { Count = 7, Cash = 60000, XP = 13000, BossCash = 150000, BossXP = 32000 },
	mythic = { Count = 6, Cash = 200000, XP = 45000, BossCash = 500000, BossXP = 110000 },
	divine = { Count = 6, Cash = 550000, XP = 90000, BossCash = 1300000, BossXP = 220000 },
	cloud = { Count = 6, Cash = 45000, XP = 18000, BossCash = 110000, BossXP = 45000 },
}
for id, q in pairs(Islands.QUESTS) do
	if Islands.List[id] then
		Islands.List[id].Quest = q
	end
end

-- onde fica o NPC das missões: ao lado do ponto de chegada (um pouco mais para dentro), virado para quem chega
function Islands.QuestGiverCFrame(id)
	local def = Islands.List[id]
	local p = def.Portal
	local at = def.CF:PointToWorldSpace(Vector3.new(p.X + 15, p.Y, p.Z - 46))
	local look = Islands.ArrivalPoint(id)
	return CFrame.lookAt(at, Vector3.new(look.X, at.Y, look.Z))
end

-- Ilha de cada ovo (o ovo só aparece no EGGS depois de abrir a ilha dele)
Islands.EGG_ISLAND = {}
for id, def in pairs(Islands.List) do
	if def.Egg then
		Islands.EGG_ISLAND[def.Egg] = id
	end
end

return Islands
