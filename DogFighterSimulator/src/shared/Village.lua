-- 🏡 PAWVILLE (2026-10, pedido do dono): a ILHA DE ENTRADA. Todo mundo começa aqui (as casinhas não existem mais):
-- uma vila cheia de gente e cachorros passeando e, no meio, o grande CANIL com um parque de cachorros dentro e o
-- 🎓 Professor Barkley, que dá o primeiro cachorro (sorteio com 3 chances — StarterService).
-- 🌊 (2026-10, pedido do dono: "faça essa ilha bem afastada de tudo") fica LONGE, sozinha no mar ao sul (5000 studs
-- do centro, ~2000 depois da Puppy Meadows), SEM ponte: no fim da rua principal tem o 🌀 portal da ⚔️ ARENA (leva para a
-- praça de spawn da ilha principal, com o Coliseu na frente) e na ilha principal o portal 🏡 PAWVILLE traz de volta.
-- Dados COMPARTILHADOS (servidor monta, cliente anima): posição, formato, onde fica cada coisa, as ruas por onde o
-- povo anda e o "elenco" (quem fica sentado, quem vende, quem passeia com cachorro...).
-- Coordenadas LOCAIS da vila: +Z local aponta para a ilha principal (norte do mundo), igual às outras ilhas.
-- A vila NÃO está no Islands.List: lá é zona segura (sem selvagens, sem luta) e o atributo "Island" do jogador vira
-- "village" (IslandService).
local Village = {}

Village.Id = "village"
Village.Name = "Pawville"
Village.Emoji = "🏡"
Village.Color = Color3.fromRGB(255, 170, 90)
Village.Center = Vector3.new(0, 0, 5000) -- centro no mundo (bem ao sul, longe de tudo; antes era 950, com ponte)
Village.Yaw = math.pi -- +Z local = −Z do mundo (para a ilha principal)
Village.CF = CFrame.new(Village.Center) * CFrame.Angles(0, Village.Yaw, 0)
Village.A = 500 -- meio comprimento da elipse (X local)
Village.B = 310 -- meia largura da elipse (Z local)
Village.GROUND_Y = 6 -- altura do chão das ruas e praças (local)
Village.Half = 576 -- metade do quadrado local varrido pelo chão de blocos (múltiplo de 8)
Village.LIFE_RANGE = 950 -- câmera mais perto que isso do centro: o povo e os cachorros da vila aparecem (cliente)
Village.OCEAN_R = 2000 -- mar próprio em volta da vila (MapBuilder): o oceano do mapa só vai até 3600 do centro

-- "def" no formato das ilhas (IslandKit / ZoneGeo leem CF, Center, Shape)
Village.Def = {
	Id = Village.Id,
	Name = Village.Name,
	CF = Village.CF,
	Center = Village.Center,
	Yaw = Village.Yaw,
	Shape = { { 0, 0, Village.A } },
}

function Village.ToWorld(x, y, z)
	return Village.CF:PointToWorldSpace(Vector3.new(x, y or Village.GROUND_Y, z))
end
function Village.ToLocal(pos)
	return Village.CF:PointToObjectSpace(pos)
end
-- CFrame no mundo de um ponto local, girado ry (ry = 0: olhando para −Z local, para o sul... do mundo é o norte)
function Village.LocalCF(x, y, z, ry)
	return Village.CF * CFrame.new(x, y or Village.GROUND_Y, z) * CFrame.Angles(0, ry or 0, 0)
end
-- giro (ry) para quem está em (x, z) olhar para (tx, tz) — no sistema local
function Village.Face(x, z, tx, tz)
	return math.atan2(-(tx - x), -(tz - z))
end

-- Está na vila? (elipse + folga; altura entre o fundo do mar e o céu baixo)
function Village.Inside(pos, margin)
	margin = margin or 0
	local l = Village.CF:PointToObjectSpace(pos)
	if l.Y < -40 or l.Y > 260 then
		return false
	end
	local a, b = Village.A + margin, Village.B + margin
	return (l.X / a) ^ 2 + (l.Z / b) ^ 2 <= 1
end

---------------------------------------------------------------- lugares
-- 🏰 CANIL: retângulo local (centro X, Z; largura W em X, fundo D em Z). Portão no lado norte (+Z).
-- Parede de fora 2 de grossura + boxes de 16 → pátio de dentro (o parque) x ∈ [−72, 72], z ∈ [−92, 12].
Village.KENNEL = { X = 0, Z = -40, W = 180, D = 140, Wall = 2, Booth = 16, Gate = 18, H = 20 }
do
	local k = Village.KENNEL
	k.X0, k.X1 = k.X - k.W / 2, k.X + k.W / 2 -- −90, 90
	k.Z0, k.Z1 = k.Z - k.D / 2, k.Z + k.D / 2 -- −110, 30
	k.IX0, k.IX1 = k.X0 + k.Wall + k.Booth, k.X1 - k.Wall - k.Booth -- −72, 72
	k.IZ0, k.IZ1 = k.Z0 + k.Wall + k.Booth, k.Z1 - k.Wall - k.Booth -- −92, 12
end

-- 🎓 Professor Barkley: no palco logo depois do portão, olhando para quem entra
Village.PROFESSOR = { X = 0, Z = -4, Ry = math.pi, Range = 14 }
-- onde o jogador nasce (pracinha entre a praça e o portão do canil, olhando para o portão)
Village.SPAWN = { X = 0, Z = 56, Ry = 0 }
-- onde o primeiro cachorro aparece (na frente do professor)
Village.STARTER_SPOT = { X = 0, Z = 10, Ry = math.pi }
-- ⛲ praça (calçada redonda) e o chafariz no meio
Village.SQUARE = { X = 0, Z = 98, R = 46, Fountain = 11, Walk = 28 }
-- 🌀 portal da ⚔️ ARENA: no fim da rua principal (ponta norte, onde antes saía a ponte). Quem anda para +Z entra.
Village.ARENA_PORTAL = { X = 0, Z = 304 }
-- 🌻 portal da PUPPY MEADOWS (2026-10-23, pedido do dono: o guia do tutorial leva até "o portal da primeira ilha,
-- onde tem cachorros mais fracos"): à esquerda do fim da rua principal, virado para ela (lugar livre e plano)
Village.MEADOWS_PORTAL = { X = -74, Z = 254 }
-- 🦮 onde o cliente fica na frente da loja de coleiras (a guia leva até aqui no tutorial)
Village.LEASH_SHOP = { X = -62, Z = 119 }
Village.MEADOWS_PORTAL.Ry = Village.Face(Village.MEADOWS_PORTAL.X, Village.MEADOWS_PORTAL.Z, 0, 270)
-- 🚪 arco "Welcome to Pawville" na rua principal
Village.GATE_ARCH = { X = 0, Z = 266 }

-- 🌳 parque de dentro do canil (pátio): trilha de cascalho em volta e os brinquedos no meio
Village.PARK = {
	Loop = { { 0, 16 }, { -42, 6 }, { -58, -30 }, { -52, -74 }, { 0, -84 }, { 52, -74 }, { 58, -30 }, { 42, 6 }, { 0, 16 } },
	Stage = { X = 0, Z = -4, R = 9 },
	Tree = { X = 0, Z = -50, R = 9 },
	Pool = { X = -32, Z = -56, R = 10 },
	Sand = { X = -30, Z = -22, W = 18, D = 14 },
	Agility = { X = 30, Z = -42, W = 30, D = 52 },
	Toys = { X = -12, Z = -72 },
}

---------------------------------------------------------------- ruas
-- { Name, Half (meia largura), Kind ("Cobble" pedra | "Path" terra | "Gravel" cascalho), Pts = {{x, z}...} }
-- O povo anda por elas (Village.Graph). Ponto de uma rua que cai no meio de outra vira cruzamento sozinho.
local SQ = Village.SQUARE
local sqRing = {}
for k = 0, 8 do
	local a = math.rad(90 + k * 45)
	table.insert(sqRing, { math.floor(SQ.X + math.cos(a) * SQ.Walk + 0.5), math.floor(SQ.Z + math.sin(a) * SQ.Walk + 0.5) })
end
Village.STREETS = {
	{ Name = "Main", Half = 11, Kind = "Cobble", Pts = { { 0, 290 }, { 0, 266 }, { 0, 198 }, { 0, SQ.Z + SQ.Walk } } },
	{ Name = "Square", Half = 5, Kind = "Cobble", Pts = sqRing, Loop = true },
	{ Name = "Gate", Half = 8, Kind = "Cobble", Pts = { { 0, SQ.Z - SQ.Walk }, { 0, 32 }, { 0, 16 } } },
	{ Name = "Park", Half = 3.5, Kind = "Gravel", Pts = Village.PARK.Loop, Loop = true, Inside = true },
	{ Name = "RingNE", Half = 7, Kind = "Cobble", Pts = { { SQ.Walk, SQ.Z }, { 62, SQ.Z }, { 132, SQ.Z } } },
	{ Name = "RingNW", Half = 7, Kind = "Cobble", Pts = { { -SQ.Walk, SQ.Z }, { -62, SQ.Z }, { -132, SQ.Z } } },
	{ Name = "RingE", Half = 7, Kind = "Cobble", Pts = { { 132, SQ.Z }, { 132, 20 }, { 132, -60 }, { 132, -152 } } },
	{ Name = "RingW", Half = 7, Kind = "Cobble", Pts = { { -132, SQ.Z }, { -132, 20 }, { -132, -60 }, { -132, -152 } } },
	{ Name = "RingS", Half = 7, Kind = "Cobble", Pts = { { 132, -152 }, { 60, -152 }, { 0, -152 }, { -60, -152 }, { -132, -152 } } },
	{ Name = "NE", Half = 6, Kind = "Path", Pts = { { 0, 198 }, { 64, 198 }, { 150, 210 }, { 222, 176 }, { 280, 104 }, { 280, 20 } } },
	{ Name = "NW", Half = 6, Kind = "Path", Pts = { { 0, 198 }, { -64, 198 }, { -150, 210 }, { -222, 176 }, { -280, 104 }, { -280, 20 } } },
	{ Name = "East", Half = 6, Kind = "Path", Pts = { { 132, 20 }, { 210, 26 }, { 280, 20 }, { 360, 8 }, { 430, -14 } } },
	{ Name = "West", Half = 6, Kind = "Path", Pts = { { -132, 20 }, { -210, 26 }, { -280, 20 }, { -340, 4 } } },
	{ Name = "SE", Half = 6, Kind = "Path", Pts = { { 132, -152 }, { 186, -196 }, { 256, -204 }, { 320, -160 }, { 358, -84 }, { 360, 8 } } },
	{ Name = "SW", Half = 6, Kind = "Path", Pts = { { -132, -152 }, { -186, -196 }, { -256, -204 }, { -320, -160 }, { -350, -84 }, { -340, 4 } } },
	{ Name = "South", Half = 6, Kind = "Cobble", Pts = { { 0, -152 }, { 0, -206 }, { 0, -246 } } },
	{ Name = "Beach", Half = 5, Kind = "Path", Pts = { { -246, -228 }, { -128, -244 }, { 0, -246 }, { 128, -244 }, { 246, -228 } } },
	{ Name = "BeachE", Half = 5, Kind = "Path", Pts = { { 256, -204 }, { 246, -228 } } },
	{ Name = "BeachW", Half = 5, Kind = "Path", Pts = { { -256, -204 }, { -246, -228 } } },
}

-- distância de (x, z) até a rua mais perto (e a rua). skipInside = ignora a trilha de dentro do canil
local function segDist(x, z, a, b)
	local px, pz, vx, vz = x - a[1], z - a[2], b[1] - a[1], b[2] - a[2]
	local len2 = vx * vx + vz * vz
	local h = len2 > 0 and math.clamp((px * vx + pz * vz) / len2, 0, 1) or 0
	local dx, dz = px - vx * h, pz - vz * h
	return math.sqrt(dx * dx + dz * dz)
end
Village.SegDist = segDist
function Village.StreetDist(x, z, skipInside)
	local best, bestStreet = math.huge, nil
	for _, s in ipairs(Village.STREETS) do
		if not (skipInside and s.Inside) then
			local pts = s.Pts
			for i = 1, #pts - 1 do
				local d = segDist(x, z, pts[i], pts[i + 1]) - s.Half
				if d < best then
					best, bestStreet = d, s
				end
			end
		end
	end
	return best, bestStreet
end

-- 🕸️ rede de caminhos para o povo andar: { Nodes = { {x, z}... }, Links = { [i] = { j... } } } (local, sem altura)
local graph = nil
function Village.Graph()
	if graph then
		return graph
	end
	-- 1) cópia das ruas com os cruzamentos "em T" (ponto de uma rua no meio do segmento de outra) inseridos
	local lines = {}
	for _, s in ipairs(Village.STREETS) do
		local pts = {}
		for _, p in ipairs(s.Pts) do
			table.insert(pts, { p[1], p[2] })
		end
		table.insert(lines, pts)
	end
	for _, line in ipairs(lines) do
		for _, other in ipairs(lines) do
			if other ~= line then
				for _, p in ipairs(other) do
					local i = 1
					while i < #line do
						local a, b = line[i], line[i + 1]
						local nearEnd = (math.abs(p[1] - a[1]) + math.abs(p[2] - a[2]) < 1) or (math.abs(p[1] - b[1]) + math.abs(p[2] - b[2]) < 1)
						if not nearEnd and segDist(p[1], p[2], a, b) < 1 then
							table.insert(line, i + 1, { p[1], p[2] })
							break
						end
						i += 1
					end
				end
			end
		end
	end
	-- 2) pontos iguais (menos de 1 stud) viram o mesmo nó
	local nodes, links = {}, {}
	local function nodeOf(p)
		for i, n in ipairs(nodes) do
			if math.abs(n[1] - p[1]) < 1 and math.abs(n[2] - p[2]) < 1 then
				return i
			end
		end
		table.insert(nodes, { p[1], p[2] })
		links[#nodes] = {}
		return #nodes
	end
	local function link(a, b)
		if a ~= b and not table.find(links[a], b) then
			table.insert(links[a], b)
			table.insert(links[b], a)
		end
	end
	for _, line in ipairs(lines) do
		local prev = nil
		for _, p in ipairs(line) do
			local i = nodeOf(p)
			if prev then
				link(prev, i)
			end
			prev = i
		end
	end
	graph = { Nodes = nodes, Links = links }
	return graph
end

---------------------------------------------------------------- 🏪 lojas da rua principal e prédios fixos
-- Side = de que lado da rua (−1 = x negativo), Z = meio da fachada. O prédio olha para a rua.
Village.SHOPS = {
	{ Side = -1, Z = 160, Text = "🥖 BONE BAKERY", Wall = Color3.fromRGB(250, 226, 180), Roof = Color3.fromRGB(178, 98, 62), Awning = Color3.fromRGB(226, 120, 70) },
	{ Side = -1, Z = 236, Text = "☕ PUP CAFÉ", Wall = Color3.fromRGB(255, 196, 206), Roof = Color3.fromRGB(150, 70, 96), Awning = Color3.fromRGB(240, 110, 140) },
	{ Side = 1, Z = 160, Text = "🍦 ICE CREAM", Wall = Color3.fromRGB(196, 244, 222), Roof = Color3.fromRGB(70, 150, 140), Awning = Color3.fromRGB(80, 200, 170) },
	{ Side = 1, Z = 236, Text = "🧸 TOY STORE", Wall = Color3.fromRGB(255, 232, 140), Roof = Color3.fromRGB(80, 110, 200), Awning = Color3.fromRGB(90, 150, 240) },
}
Village.SHOP_X = 37 -- meio do prédio (a fachada fica em 37 − 11 = 26)
-- prédios grandes em volta da praça (olham para o sul, para a rua do anel)
Village.TOWN_HALL = { X = -92, Z = 150 }
Village.SCHOOL = { X = 92, Z = 150 }
-- lojas extras nas ruas de fora: pet shop e salão de banho
Village.PET_SHOP = { X = -200, Z = 70, Ry = 0 }
Village.GROOMER = { X = 200, Z = 70, Ry = 0 }
-- pontos marcantes de fora
Village.WINDMILL = { X = -420, Z = 50 }
Village.LIGHTHOUSE = { X = 476, Z = -64 }
Village.POND = { X = -232, Z = -96, R = 34 }
Village.PLAYGROUND = { X = 228, Z = -96 }
Village.ORCHARD = { X = 370, Z = 110 }
Village.GARDENS = { X = -350, Z = -150 }
Village.DOCK = { X = 128, Z = -292, Len = 44 }

-- bancos da praça (no chão, olhando para o chafariz) — o povo senta aqui
Village.BENCHES = {}
for _, a in ipairs({ 37, 53, 127, 143, 217, 233, 307, 323 }) do
	local r = math.rad(a)
	local x, z = SQ.X + math.cos(r) * 38, SQ.Z + math.sin(r) * 38
	table.insert(Village.BENCHES, { X = x, Z = z, Ry = Village.Face(x, z, SQ.X, SQ.Z) })
end
-- bancos do parque do canil (visitantes olhando os cachorros)
for _, b in ipairs({ { -47, -36 }, { 47, -36 }, { -20, 0 }, { 20, 0 } }) do
	table.insert(Village.BENCHES, { X = b[1], Z = b[2], Ry = Village.Face(b[1], b[2], 0, -44), Park = true })
end
-- barraquinhas da praça (o vendedor fica atrás, olhando para a praça)
Village.STALLS = {
	-- 🦮 (2026-10-25, pedido do dono: "faz uma loja de coleira em Pawville") a barraquinha da esquerda vende COLEIRAS
	{ X = -62, Z = 128, Text = "🐾 LEASH SHOP", Color = Color3.fromRGB(70, 140, 235), Leash = true },
	{ X = 62, Z = 128, Text = "🎈 BALLOONS", Color = Color3.fromRGB(90, 150, 240) },
}

---------------------------------------------------------------- 🧑‍🤝‍🧑 elenco (o cliente monta e anima; a prévia usa parado)
-- Role: "Walk" (anda pelas ruas, Dog = passeia com cachorro), "Sit" (banco), "Chat" (conversa em dupla),
-- "Vendor" (barraca), "Guard" (portão), "Kids" (crianças correndo em volta do chafariz), "Fish" (pescando no cais),
-- "Staff" (funcionário do canil), "Greeter" (dá boas-vindas perto do spawn), "Sweep" (varrendo), "Garden" (jardineiro),
-- "Beach" (na praia), "Music" (tocando violão)
Village.FOLK = {
	{ Role = "Greeter", X = 14, Z = 50, Ry = Village.Face(14, 50, 0, 56), Say = { "Welcome to Pawville! 🐾", "Prof. Barkley is inside the Kennel!", "Go get your first dog! 🐶" } },
	{ Role = "Guard", X = 14, Z = 262, Ry = Village.Face(14, 262, 0, 290) },
	{ Role = "Guard", X = -14, Z = 262, Ry = Village.Face(-14, 262, 0, 290) },
	{ Role = "Vendor", X = -62, Z = 135, Ry = Village.Face(-62, 135, -62, 100), Say = { "Leashes! Catch wild dogs! 🐾", "Your first pack is FREE!" } },
	{ Role = "Vendor", X = 62, Z = 135, Ry = Village.Face(62, 135, 62, 100), Say = { "Balloons! 🎈", "Pick a color!" } },
	{ Role = "Kids", X = SQ.X, Z = SQ.Z, R = 18, Count = 3 },
	{ Role = "Chat", X = -50, Z = 70, Ry = Village.Face(-50, 70, -44, 66), Say = { "Did you see the new dogs?", "So cute! 🐶" } },
	{ Role = "Chat", X = -44, Z = 66, Ry = Village.Face(-44, 66, -50, 70), Say = { "I got a Rare one! 💙", "Haha, nice!" } },
	{ Role = "Chat", X = 18, Z = 214, Ry = Village.Face(18, 214, 24, 222) },
	{ Role = "Chat", X = 24, Z = 222, Ry = Village.Face(24, 222, 18, 214), Say = { "Lovely day!", "Woof! 😄" } },
	{ Role = "Music", X = 40, Z = 72, Ry = Village.Face(40, 72, 0, 90) },
	{ Role = "Sweep", X = -16, Z = 182, Ry = 0.6 },
	{ Role = "Garden", X = -96, Z = 30, Ry = 1.2 },
	{ Role = "Fish", X = 126, Z = -324, Ry = 0, Y = 2.7 },
	{ Role = "Fish", X = 130.5, Z = -314, Ry = -0.4, Y = 2.7 },
	{ Role = "Beach", X = -90, Z = -270, Ry = 0.4 },
	{ Role = "Beach", X = 40, Z = -276, Ry = -0.3 },
	{ Role = "Staff", X = -40, Z = 18, Ry = Village.Face(-40, 18, -40, 0), Say = { "Welcome to the Kennel!", "Talk to Prof. Barkley! 🎓" } },
	{ Role = "Staff", X = 44, Z = 18, Ry = Village.Face(44, 18, 44, 0) },
	{ Role = "Staff", X = -8, Z = -64, Ry = 0.8, Ball = true },
	{ Role = "Kids", X = 228, Z = -96, R = 12, Count = 3 },
	{ Role = "Walk", Count = 22, DogEvery = 3 }, -- (2026-10: eram 30 — a vila estava pesada)
}
-- 🐕 cachorros soltos: "Park" (pátio do canil), "Roam" (passeando sozinhos perto de um ponto), "Booth" (dormindo
-- nos boxes do canil). Species = lista para sortear (estilo da vila: raças comuns e algumas especiais)
Village.DOGS = {
	-- (2026-10: cada cachorro tem ~170 peças animadas — eram 14/6/3/2/3, a vila estava pesada)
	{ Role = "Park", Count = 8 },
	{ Role = "Booth", Count = 4 },
	{ Role = "Roam", X = SQ.X, Z = SQ.Z, R = 40, Count = 2 },
	{ Role = "Roam", X = -232, Z = -10, R = 40, Count = 1 },
	{ Role = "Roam", X = 0, Z = -248, R = 45, Count = 2 },
}
Village.TOWN_DOGS = { "caramelo", "pug", "pinscher", "poodle", "bulldog", "beagle", "corgi", "salsicha", "chihuahua", "golden", "dalmatian", "border_collie", "sao_bernardo", "snow_husky", "akita", "boxer" }
Village.PARK_DOGS = { "caramelo", "pug", "corgi", "beagle", "golden", "dalmatian", "poodle", "chihuahua", "balloon_dog", "mushroom_dog", "windup_dog", "robo_dog", "bee_dog", "galgo", "pastor_alemao", "salsicha" }
Village.BOOTH_NAMES = { "REX", "LUNA", "BOLT", "DAISY", "MAX", "COCO", "BUDDY", "ROSIE", "TOBY", "PEPPER", "OREO", "BISCUIT", "MILO", "NALA", "ZIGGY", "HONEY", "SCOUT", "LULU", "TEDDY", "PIXIE", "RUFUS", "GINGER" }

-- boxes do canil (dentro da parede): fileira do fundo (sul) e as 2 laterais. { X, Z, Ry (olha para o pátio), Name }
do
	local k = Village.KENNEL
	local list = {}
	local i = 0
	local function add(x, z, ry)
		i += 1
		table.insert(list, { X = x, Z = z, Ry = ry, Name = Village.BOOTH_NAMES[(i - 1) % #Village.BOOTH_NAMES + 1] })
	end
	local bw = 14
	-- fundo: 12 boxes de 14 entre x −84..84
	for n = 0, 11 do
		add(-84 + bw / 2 + n * bw, k.Z0 + k.Wall + k.Booth / 2, Village.Face(0, 0, 0, 1))
	end
	-- laterais: 6 boxes de 14 entre z −90..−6 (2 studs depois da fileira do fundo)
	for n = 0, 5 do
		local z = k.IZ0 + 2 + bw / 2 + n * bw
		add(k.X0 + k.Wall + k.Booth / 2, z, Village.Face(0, 0, 1, 0))
		add(k.X1 - k.Wall - k.Booth / 2, z, Village.Face(0, 0, -1, 0))
	end
	Village.BOOTHS = list
end

-- dá para andar aqui? (em terra, longe da beira e fora do lago dos patos) — cachorro que passeia não entra na água
function Village.Walkable(x, z, margin)
	margin = margin or 24
	if (x / (Village.A - margin)) ^ 2 + (z / (Village.B - margin)) ^ 2 > 1 then
		return false
	end
	local P = Village.POND
	return (x - P.X) ^ 2 + (z - P.Z) ^ 2 > (P.R + 10) ^ 2
end

-- ponto livre do gramado do parque (local da vila): longe da trilha, do palco, da árvore, da piscina, da caixa de
-- areia e do circuito (os cachorros do pátio passeiam por estes pontos)
function Village.ParkFree(x, z, margin)
	margin = margin or 0
	local k, P = Village.KENNEL, Village.PARK
	if not (x > k.IX0 + 3 + margin and x < k.IX1 - 3 - margin and z > k.IZ0 + 3 + margin and z < k.IZ1 - 6 - margin) then
		return false
	end
	local L = P.Loop
	for i = 1, #L - 1 do
		if segDist(x, z, L[i], L[i + 1]) < 5 + margin then
			return false
		end
	end
	for _, f in ipairs({ P.Stage, P.Tree, P.Pool }) do
		if (x - f.X) ^ 2 + (z - f.Z) ^ 2 < (f.R + 4 + margin) ^ 2 then
			return false
		end
	end
	for _, f in ipairs({ P.Sand, P.Agility }) do
		if math.abs(x - f.X) < f.W / 2 + 3 + margin and math.abs(z - f.Z) < f.D / 2 + 3 + margin then
			return false
		end
	end
	return true
end
-- ponto do gramado do parque sorteado
function Village.ParkSpot(rng)
	local k = Village.KENNEL
	for _ = 1, 60 do
		local x, z = rng:NextNumber(k.IX0, k.IX1), rng:NextNumber(k.IZ0, k.IZ1)
		if Village.ParkFree(x, z, 1) then
			return x, z
		end
	end
	return 0, Village.PARK.Tree.Z + 14
end

-- 🎭 o ELENCO montado a partir do FOLK/DOGS (a mesma seed dá sempre o mesmo elenco). Lista de atores:
--   Folk: { Kind = "Folk", Role, Seed, X, Z, Ry, How = "Stand"|"Sit"|"SitGround"|"Walk"|"Run", Scale, Y?, Say?, Node?, R?, Phase?, Speed?, Ball?, Park? }
--   Dog:  { Kind = "Dog", Role = "Leash"|"Park"|"Booth"|"Roam", Species, X, Z, Ry, Owner? (índice do dono), R?, Y? }
function Village.Cast(seed)
	local rng = Random.new(seed or 2026)
	local cast = {}
	local function add(t)
		table.insert(cast, t)
		return #cast
	end
	local function pickList(list)
		return list[rng:NextInteger(1, #list)]
	end
	local g = Village.Graph()
	local k = Village.KENNEL
	for _, f in ipairs(Village.FOLK) do
		if f.Role == "Walk" then
			-- nós de rua fora do canil (quem visita o canil chega andando pela rua)
			local street = {}
			for i, n in ipairs(g.Nodes) do
				if not (n[1] > k.X0 and n[1] < k.X1 and n[2] > k.Z0 and n[2] < k.Z1) then
					table.insert(street, i)
				end
			end
			for i = 1, f.Count do
				local node = street[rng:NextInteger(1, #street)]
				local p = g.Nodes[node]
				local id = add({ Kind = "Folk", Role = "Walk", Seed = rng:NextInteger(1, 999999), Node = node, X = p[1], Z = p[2], Ry = rng:NextNumber(0, 6.28), How = "Walk", Speed = rng:NextNumber(5, 7.5) })
				if f.DogEvery and i % f.DogEvery == 0 then
					add({ Kind = "Dog", Role = "Leash", Owner = id, Species = pickList(Village.TOWN_DOGS), X = p[1] + 2, Z = p[2] + 2, Ry = 0 })
				end
			end
		elseif f.Role == "Kids" then
			for i = 1, f.Count do
				local ph = i / f.Count * math.pi * 2
				add({ Kind = "Folk", Role = "Kids", Seed = rng:NextInteger(1, 999999), X = f.X + math.cos(ph) * f.R, Z = f.Z + math.sin(ph) * f.R, CX = f.X, CZ = f.Z, R = f.R, Phase = ph, Ry = 0, How = "Run", Scale = 0.72 })
			end
		else
			local how = (f.Role == "Fish" or f.Role == "Beach") and "SitGround" or "Stand"
			add({ Kind = "Folk", Role = f.Role, Seed = rng:NextInteger(1, 999999), X = f.X, Z = f.Z, Ry = f.Ry or 0, How = how, Y = f.Y, Say = f.Say, Ball = f.Ball })
		end
	end
	-- gente sentada em metade dos bancos
	for _, b in ipairs(Village.BENCHES) do
		if rng:NextNumber() < 0.55 then
			add({ Kind = "Folk", Role = "Sit", Seed = rng:NextInteger(1, 999999), X = b.X, Z = b.Z, Ry = b.Ry, How = "Sit", Park = b.Park, Scale = rng:NextNumber() < 0.2 and 0.72 or 1 })
		end
	end
	-- cachorros
	local usedBooth = {}
	for _, d in ipairs(Village.DOGS) do
		for _ = 1, d.Count do
			if d.Role == "Park" then
				local x, z = Village.ParkSpot(rng)
				add({ Kind = "Dog", Role = "Park", Species = pickList(Village.PARK_DOGS), X = x, Z = z, Ry = rng:NextNumber(0, 6.28) })
			elseif d.Role == "Booth" then
				local b = nil
				for _ = 1, 20 do
					local i = rng:NextInteger(1, #Village.BOOTHS)
					if not usedBooth[i] then
						usedBooth[i] = true
						b = Village.BOOTHS[i]
						break
					end
				end
				if b then
					-- na caminha (no fundo do box), olhando para o pátio
					local lx, lz = -math.sin(b.Ry), -math.cos(b.Ry)
					add({ Kind = "Dog", Role = "Booth", Species = pickList(Village.PARK_DOGS), X = b.X - lx * 4.2, Z = b.Z - lz * 4.2, Ry = b.Ry, Y = 1.45 })
				end
			else
				local x, z = d.X, d.Z
				for _ = 1, 12 do
					local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(0, d.R)
					x, z = d.X + math.cos(a) * r, d.Z + math.sin(a) * r
					if Village.Walkable(x, z) then
						break
					end
				end
				add({ Kind = "Dog", Role = "Roam", Species = pickList(Village.TOWN_DOGS), X = x, Z = z, CX = d.X, CZ = d.Z, R = d.R, Ry = rng:NextNumber(0, 6.28) })
			end
		end
	end
	return cast
end

-- 🧑‍🤝‍🧑 TODO o povo da vila são AVATARES DE VERDADE (2026-10, pedido do dono: "coloque todos serem meus amigos do
-- Roblox"): os amigos do dono (Services/VillageStars → Systems/VillageLife) ocupam os lugares nesta ordem — quem passeia
-- com cachorro, quem conversa, quem passeia, quem senta nos bancos, vendedores, recepção, funcionários do canil, músico,
-- praia, a criançada correndo, guardas, varredor, jardineiro e pescadores. Com poucos amigos, os primeiros lugares (os
-- mais à vista) é que ficam cheios. Devolve { [índice no elenco] = lugar (1 = o 1º da lista) }.
Village.RESIDENTS = { "WalkDog", "Chat", "Walk", "Sit", "Vendor", "Greeter", "Staff", "Music", "Beach", "Kids", "Guard", "Sweep", "Garden", "Fish" }
function Village.Residents(cast)
	local hasDog = {}
	for _, a in ipairs(cast) do
		if a.Kind == "Dog" and a.Role == "Leash" and a.Owner then
			hasDog[a.Owner] = true
		end
	end
	local slotOf, k = {}, 0
	for _, group in ipairs(Village.RESIDENTS) do
		for i, a in ipairs(cast) do
			if a.Kind == "Folk" and ((a.Role == "Walk" and hasDog[i]) and "WalkDog" or a.Role) == group then
				k += 1
				slotOf[i] = k
			end
		end
	end
	return slotOf
end

return Village
