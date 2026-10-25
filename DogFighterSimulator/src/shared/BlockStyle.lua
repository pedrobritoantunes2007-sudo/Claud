-- 🧱 ESTILO "BLOQUINHOS" (pedido do dono, 2026-10: "gostei do chão e da cor das fotos, faz tudo parecer assim").
-- Regras para TODO o mapa:
--   • Tudo quadrado: só Part bloco (e WedgePart só em telhado/rampa). NADA de Ball, Cylinder, SpecialMesh esfera.
--   • Material SmoothPlastic (sem textura). O "detalhe" vem de blocos e tons, como nos cachorros.
--   • Cada coisa em 3–4 tons: Dark (embaixo/sombra/quinas), Base, Light (em cima), Hi (pontos de luz).
--   • Chão: quadrados de 2–3 tons de verde vivo (xadrez aleatório) + lateral de terra marrom.
-- Use BlockStyle.Pick(pal, rng) para variar o tom de um bloco e BlockStyle.Tile(pal, x, z) para xadrez fixo.
local BlockStyle = {}

local C = Color3.fromRGB

BlockStyle.MATERIAL = Enum.Material.SmoothPlastic

-- paletas { Dark, Base, Light, Hi }
BlockStyle.PAL = {
	-- chão
	Grass = { C(88, 176, 50), C(96, 186, 54), C(108, 198, 60), C(128, 212, 72) }, -- o gramado das fotos
	Dirt = { C(118, 80, 50), C(134, 92, 58), C(150, 104, 66), C(166, 120, 78) }, -- lateral de terra
	Path = { C(176, 132, 86), C(192, 148, 98), C(206, 162, 110), C(220, 178, 124) }, -- trilha de terra batida
	Sand = { C(226, 204, 146), C(238, 218, 160), C(246, 228, 176), C(252, 238, 196) },
	Stone = { C(112, 112, 122), C(136, 136, 146), C(158, 158, 168), C(182, 182, 192) },
	Cobble = { C(140, 134, 126), C(162, 156, 146), C(180, 174, 164), C(198, 192, 182) },
	Snow = { C(214, 228, 244), C(232, 242, 255), C(244, 249, 255), C(255, 255, 255) },
	Ice = { C(150, 206, 236), C(176, 224, 248), C(198, 236, 252), C(224, 246, 255) },
	Jungle = { C(52, 140, 50), C(64, 156, 58), C(78, 172, 66), C(98, 190, 80) },
	Canyon = { C(196, 112, 56), C(220, 134, 70), C(236, 156, 86), C(246, 180, 110) },
	CanyonRed = { C(160, 70, 42), C(184, 86, 50), C(204, 104, 62), C(222, 126, 80) },
	Basalt = { C(44, 38, 46), C(60, 52, 60), C(76, 66, 76), C(94, 84, 94) },
	Ash = { C(98, 98, 110), C(118, 118, 130), C(136, 136, 148), C(154, 154, 166) },
	Lava = { C(230, 70, 20), C(255, 98, 30), C(255, 140, 40), C(255, 200, 80) },
	Marble = { C(222, 216, 204), C(240, 234, 222), C(248, 244, 236), C(255, 252, 246) },
	Gold = { C(204, 150, 40), C(226, 178, 61), C(242, 202, 82), C(255, 228, 120) },
	Cosmic = { C(56, 44, 120), C(70, 56, 140), C(90, 74, 170), C(122, 107, 208) },
	Cloud = { C(220, 232, 248), C(236, 244, 255), C(246, 250, 255), C(255, 255, 255) },
	-- natureza / construção
	Leaf = { C(52, 128, 38), C(78, 168, 46), C(112, 202, 62), C(160, 230, 88) },
	Pine = { C(28, 92, 52), C(40, 120, 64), C(60, 150, 80), C(98, 184, 104) },
	Bark = { C(92, 62, 40), C(120, 82, 52), C(146, 102, 64), C(166, 120, 78) },
	Wood = { C(150, 100, 58), C(176, 122, 72), C(198, 144, 88), C(216, 166, 108) }, -- tábuas
	Roof = { C(170, 52, 44), C(200, 68, 56), C(222, 90, 72), C(240, 120, 96) },
	Water = { C(40, 150, 200), C(59, 186, 214), C(96, 210, 232), C(160, 232, 246) },
}

-- material do Terrain antigo → paleta de bloco (para converter o chão das ilhas)
BlockStyle.FROM_TERRAIN = {
	Mud = "Grass",
	Grass = "Grass",
	LeafyGrass = "Jungle",
	Sand = "Sand",
	Ground = "Path",
	Rock = "Stone",
	Cobblestone = "Cobble",
	Basalt = "Basalt",
	Snow = "Snow",
	Ice = "Ice",
	Slate = "Ash",
	Sandstone = "Canyon",
	Limestone = "CanyonRed",
	Concrete = "Marble",
	Salt = "Gold",
	Asphalt = "Cosmic",
	Pavement = "Cosmic",
	CrackedLava = "Lava",
}
-- cor da lateral (parede de penhasco) de cada paleta de chão
BlockStyle.SIDE = { Grass = "Dirt", Jungle = "Dirt", Path = "Dirt", Snow = "Stone", Sand = "Sand" }

-- tom aleatório (pesos: Dark 25%, Base 40%, Light 30%, Hi 5%)
function BlockStyle.Pick(pal, rng)
	local r = rng:NextNumber()
	return r < 0.25 and pal[1] or r < 0.65 and pal[2] or r < 0.95 and pal[3] or pal[4]
end

-- xadrez fixo por posição (o mesmo quadrado sempre tem o mesmo tom; ninguém precisa guardar nada)
local P32 = 4294967296
local function hash(x, z)
	local h = bit32.bxor((x * 73856093) % P32, (z * 19349663) % P32)
	h = bit32.bxor(h, bit32.rshift(h, 13))
	h = (h * 668265) % P32
	h = bit32.bxor(h, bit32.rshift(h, 16))
	return h % 1000 / 1000
end
BlockStyle.Hash = function(x, z)
	return hash(math.floor(x), math.floor(z))
end
function BlockStyle.Tile(pal, x, z, size)
	local s = size or 4
	local r = hash(math.floor(x / s), math.floor(z / s))
	return r < 0.34 and pal[1] or r < 0.72 and pal[2] or pal[3]
end

return BlockStyle
