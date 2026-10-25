-- Posições do mapa compartilhadas entre servidor e cliente.
-- Ilha principal (2026-10, mapa novo): no meio o Coliseu do Super Boss, em volta a Praça dos Portais
-- (um portal para cada ilha de raridade), depois as casinhas dos jogadores e a Boss Tower ao norte (2026-10: sem
-- casinhas e sem a torre — Config.HOUSES/BOSS_TOWER; no rochedo da torre ficou um mirante).
-- Os cachorros selvagens agora moram nas ilhas de raridade (Shared/Islands).
local Layout = {}

-- 🏟️ (2026-10, pedido do dono: "aumente a ilha da arena... faça algo muito grande") a Arena CRESCEU: o chão do
-- Coliseu ganhou ARENA_GROW studs de raio e tudo da arquibancada para fora andou o mesmo tanto (a ilha inteira cresceu).
Layout.ARENA_GROW = 80
local GROW = Layout.ARENA_GROW

-- Anéis a partir do centro (+GROW): chão do Coliseu (150) → arquibancadas (até 216) → muralha (226) →
-- Praça dos Portais (234 a 344, portais em 290) → caminhos → terrenos (frente em 447, fundo em 487)
-- → árvores/morrinhos → praia (borda da grama em 542).
Layout.ISLAND_RADIUS = 542 + GROW
Layout.ARENA_CENTER = Vector3.new(0, 0, 0)
-- "Arena" = chão do Coliseu: onde o Super Boss luta e onde vale o PvP quando ele dorme
Layout.ARENA_RADIUS = 150 + GROW
Layout.COLOSSEUM_WALL = 226 + GROW -- muralha de fora do Coliseu
Layout.PORTAL_PLAZA_INNER = 234 + GROW
Layout.PORTAL_PLAZA_OUTER = 344 + GROW
Layout.PORTAL_RING = 290 + GROW -- os portais das ilhas na praça

Layout.PLOT_COUNT = 8
Layout.PLOT_RADIUS = 466 + GROW

Layout.BOSS_CENTER = Vector3.new(0, 160, -670 - GROW)
Layout.BOSS_RADIUS = 120 -- (2026-10: topo da torre maior)

-- Cada terreno olha para o centro (−Z local aponta para a Arena)
function Layout.PlotCFrame(index)
	local angle = math.rad(22.5 + 45 * (index - 1))
	local pos = Vector3.new(math.cos(angle) * Layout.PLOT_RADIUS, 0, math.sin(angle) * Layout.PLOT_RADIUS)
	return CFrame.lookAt(pos, Vector3.new(0, 0, 0))
end

-- Pontos locais dentro do terreno
Layout.PLOT = {
	House = CFrame.new(0, 0, 11),
	Bowls = { CFrame.new(-8, 0, -1), CFrame.new(0, 0, -4), CFrame.new(8, 0, -1) },
	-- ninho: 3 lugares normais + 2 do passe "Ninho Maior" (MonetizationService.EggCap limita pelo total)
	Eggs = {
		CFrame.new(15, 0, 6),
		CFrame.new(17.5, 0, 9.5),
		CFrame.new(13, 0, 10),
		CFrame.new(20, 0, 6),
		CFrame.new(16.5, 0, 13.5),
	},
	-- 🪵 estande de treino: canto de trás da casinha (atrás da casa não cabe: a casa Lv.5 vai até o fundo).
	-- O cachorro chega por StandPath (do lado da casa) e para em StandSpot, de frente para o estande.
	Stand = CFrame.new(15.5, 0, 13),
	StandPath = CFrame.new(15.5, 0, 1),
	StandSpot = CFrame.new(15.5, 0, 9.5),
	DogHome = CFrame.new(0, 0, 3),
	-- onde o cachorro (personagem) nasce: na frente do terreno, olhando para a Arena, longe da casa
	-- (nascendo colado na casa a câmera ficava dentro da parede)
	DogSpawn = CFrame.new(0, 0, -14),
	-- boneco do jogador (avatar) parado na frente da casinha enquanto ele é o cachorro
	OwnerSpot = CFrame.new(-7, 0, -3),
	Gate = CFrame.new(0, 0, -20),
	PlayerSpawn = CFrame.new(-12, 3, -12),
	Sign = CFrame.new(-14, 0, -20),
	HalfWidth = 23,
	Front = -19,
	Back = 21,
}

-- Ponto de entrada da Arena alinhado com o terreno
function Layout.ArenaGateFor(index)
	local angle = math.rad(22.5 + 45 * (index - 1))
	return Vector3.new(math.cos(angle), 0, math.sin(angle)) * (Layout.ARENA_RADIUS + 2)
end

-- Extras do cenário (usados pelo MapBuilder; seguros para ler em qualquer lugar)
Layout.GROUND_Y = 0 -- topo do gramado/terrenos/Arena
Layout.WATER_LEVEL = -2 -- superfície da água
Layout.ARENA_PLAZA_RADIUS = Layout.PORTAL_PLAZA_OUTER -- fim da Praça dos Portais (piso de pedra)
-- praça de spawn (avenida +Z, entre a Praça dos Portais e as casinhas)
Layout.SPAWN_PLAZA = Vector3.new(0, 0, 400 + GROW)
-- 🏡 portal da Pawville: no fim da avenida do spawn (+Z), onde antes saía a ponte (a vila ficou longe, sem ponte)
Layout.PAWVILLE_PORTAL = Vector3.new(0, 0, 524 + GROW)
-- anel livre atrás dos terrenos (árvores, morrinhos, marcos de borda)
Layout.PLOT_BACK_RADIUS = Layout.PLOT_RADIUS + 21
Layout.ISLET_ANGLES = { 45, 135, 225, 315 } -- pontes de madeira para as ilhotas
Layout.ISLET_RADIUS = 22
Layout.COAST_RADIUS = Layout.ISLAND_RADIUS + 18 -- fim da areia da praia (depois só água)
-- ponte de pedra da ilha até a porta da Boss Tower (eixo X = BOSS_CENTER.X, largura 12)
Layout.BOSS_BRIDGE_START = Vector3.new(Layout.BOSS_CENTER.X, 0, -Layout.ISLAND_RADIUS + 8)
Layout.BOSS_BRIDGE_WIDTH = 12

function Layout.IsletCenter(angleDegrees)
	local a = math.rad(angleDegrees)
	return Vector3.new(math.cos(a), 0, math.sin(a)) * (Layout.ISLAND_RADIUS + 66)
end

-- 🌊 BEIRA DO MUNDO (2026-10-25, o dono: "arrumar o mar (é bug): a água vai cobrir o mapa inteiro e ir bem mais longe;
-- coloco um chão invisível no fundo do mar e paredes invisíveis nos lados, para ninguém cair no limbo"). Antes o mar era
-- um círculo de 3600 em volta do centro + outro em volta da Pawville: fora deles (e embaixo da água) era o vazio.
--   MinX/MaxX/MinZ/MaxZ = onde ficam as PAREDES invisíveis (todas as ilhas, a 🏡 Pawville e a 🏆 Ilha do Ranking ficam
--   bem dentro: tools/preview/sea_test.luau confere); a ÁGUA continua SeaMargin studs depois das paredes.
--   FloorY = fundo do mar = topo do CHÃO invisível · WallTop = altura das paredes (bem acima do ☁️ Reino das Nuvens)
--   RescueY = rede de segurança do servidor: abaixo disso (ou do lado de fora das paredes) volta para a terra
Layout.WORLD = {
	MinX = -4400,
	MaxX = 4400,
	MinZ = -5600,
	MaxZ = 6800,
	SeaMargin = 1200,
	FloorY = -20,
	WallTop = 2000,
	RescueY = -60,
}

-- está dentro das paredes do mundo? (margin > 0 = mais para dentro)
function Layout.InWorld(position, margin)
	local W, m = Layout.WORLD, margin or 0
	return position.X > W.MinX + m and position.X < W.MaxX - m and position.Z > W.MinZ + m and position.Z < W.MaxZ - m
end

-- 🛡️ (2026-10, pedido do dono: "quando entram em PvP não podem sair voando de lá, tipo uma barreira invisível") o
-- chão do Coliseu vale até esta altura (voando lá dentro também é PvP) e é o teto da BARREIRA invisível: quem está no
-- PvP não sai voando (nem por cima nem pelos lados) — só andando pelos portões
Layout.ARENA_CEILING = 70

function Layout.InArena(position)
	local flat = Vector3.new(position.X, 0, position.Z) - Layout.ARENA_CENTER
	return flat.Magnitude < Layout.ARENA_RADIUS - 1 and position.Y < Layout.ARENA_CEILING
end

-- ponto mantido dentro da barreira do PvP (`margin` studs para dentro dos lados e do teto)
function Layout.ArenaClamp(position, margin)
	margin = margin or 3
	local c = Layout.ARENA_CENTER
	local rel = Vector3.new(position.X - c.X, 0, position.Z - c.Z)
	local maxR = Layout.ARENA_RADIUS - 1 - margin
	local p = position
	if rel.Magnitude > maxR then
		local q = c + rel.Unit * maxR
		p = Vector3.new(q.X, p.Y, q.Z)
	end
	if p.Y > Layout.ARENA_CEILING - margin then
		p = Vector3.new(p.X, Layout.ARENA_CEILING - margin, p.Z)
	end
	return p
end

function Layout.InBoss(position)
	local offset = position - Layout.BOSS_CENTER
	return Vector3.new(offset.X, 0, offset.Z).Magnitude < Layout.BOSS_RADIUS + 4 and math.abs(offset.Y) < 60
end

-- Coliseu do Super Boss (mesmo centro e raio do chão da "Arena")
Layout.COLOSSEUM_CENTER = Layout.ARENA_CENTER
Layout.COLOSSEUM_RADIUS = Layout.ARENA_RADIUS

return Layout
