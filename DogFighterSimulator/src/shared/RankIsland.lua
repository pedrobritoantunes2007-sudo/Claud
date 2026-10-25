-- 🏆 ILHA DO RANKING (2026-10-25, pedido do dono: "uma ilha separada, com portal na Pawville e na ilha principal. Os
-- placares ficam só lá: mais fortes, vitórias da semana, mais capturas, Dex mais completo, melhores clãs e nível do
-- Passe de Temporada.")
-- Ilhota redonda sozinha no mar ao norte, com a PRAÇA DOS CAMPEÕES: os 6 placares em meia-lua virados para o pódio
-- do meio, e 2 portais de volta (⚔️ ARENA = ilha principal, 🏡 PAWVILLE). Zona segura (sem selvagens, sem luta).
-- Dados COMPARTILHADOS (servidor monta: World/RankIsland + LeaderboardService; cliente: HUD/MAP).
-- Coordenadas LOCAIS: +Z local aponta para o centro do mapa (igual às outras ilhas; aqui Yaw = 0, +Z local = +Z do mundo).
local RankIsland = {}

RankIsland.Id = "rank"
RankIsland.Name = "Ranking Island"
RankIsland.Emoji = "🏆"
RankIsland.Color = Color3.fromRGB(255, 196, 64)
RankIsland.Center = Vector3.new(0, 0, -4300)
RankIsland.Yaw = 0
RankIsland.CF = CFrame.new(RankIsland.Center) * CFrame.Angles(0, RankIsland.Yaw, 0)
RankIsland.R = 190 -- raio da ilha (até a areia)
RankIsland.Half = 256 -- metade do quadrado varrido pelo chão de blocos (múltiplo de 8)
RankIsland.GROUND_Y = 4 -- altura da praça (local)
RankIsland.PLAZA_R = 92 -- praça de pedra (os placares ficam na beira)

RankIsland.Def = {
	Id = RankIsland.Id,
	Name = RankIsland.Name,
	CF = RankIsland.CF,
	Center = RankIsland.Center,
	Yaw = RankIsland.Yaw,
	Shape = { { 0, 0, RankIsland.R } },
}

-- 🌀 os 2 portais (na beira sul da praça, +Z local, virados para o pódio) e onde quem chega aparece
RankIsland.PORTALS = {
	{ To = "main", X = -46, Z = 132, Text = "⚔️ ARENA" },
	{ To = "village", X = 46, Z = 132, Text = "🏡 PAWVILLE" },
}
RankIsland.SPAWN = { X = 0, Z = 100 }

-- 🪧 os 6 placares em meia-lua no norte da praça (−Z local), cada um virado para o pódio do meio
RankIsland.BOARDS = {
	{ Key = "Power", Angle = 210 },
	{ Key = "Wins", Angle = 234 },
	{ Key = "Catches", Angle = 258 },
	{ Key = "Dex", Angle = 282 },
	{ Key = "Clans", Angle = 306 },
	{ Key = "Season", Angle = 330 },
}
RankIsland.BOARD_R = 78

-- 🌀 o portal da ilha principal: na Praça dos Portais, no vão entre a chegada do spawn (90°) e a Frosty Peaks (141°)
RankIsland.PLAZA_ANGLE = 120 -- graus (mesmo giro do Islands.PlazaAngle)
-- 🌀 o portal da Pawville: à direita do fim da rua principal (espelho do portal da Puppy Meadows)
RankIsland.VILLAGE_PORTAL = { X = 74, Z = 254 }

function RankIsland.ToWorld(x, y, z)
	return RankIsland.CF:PointToWorldSpace(Vector3.new(x, y or RankIsland.GROUND_Y, z))
end
function RankIsland.LocalCF(x, y, z, ry)
	return RankIsland.CF * CFrame.new(x, y or RankIsland.GROUND_Y, z) * CFrame.Angles(0, ry or 0, 0)
end
-- giro (ry) para quem está em (x, z) olhar para (tx, tz) — no sistema local (ry = 0 olha para −Z)
function RankIsland.Face(x, z, tx, tz)
	return math.atan2(-(tx - x), -(tz - z))
end
-- posição local de um placar
function RankIsland.BoardPos(board)
	local a = math.rad(board.Angle)
	return math.cos(a) * RankIsland.BOARD_R, math.sin(a) * RankIsland.BOARD_R
end

-- Está na ilha? (círculo + folga; altura entre o fundo do mar e o céu baixo)
function RankIsland.Inside(pos, margin)
	local l = RankIsland.CF:PointToObjectSpace(pos)
	if l.Y < -40 or l.Y > 260 then
		return false
	end
	local r = RankIsland.R + (margin or 0)
	return l.X * l.X + l.Z * l.Z <= r * r
end

return RankIsland
