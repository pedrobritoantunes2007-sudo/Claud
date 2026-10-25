-- 🗺️ FOTOS DE CIMA DO MAPA (2026-10-24, pedido do dono: "quero que esse mapa seja exatamente o mapa de cima").
-- Cada ilha foi fotografada DE CIMA com o código de verdade do mapa (tools/preview/map_tiles.py: monta a ilha com os
-- mesmos construtores do servidor e tira a foto sem perspectiva → Imagens/Mapa/<Key>.png, com o mar transparente).
-- O PUBLICAR.bat sobe as fotos para o Roblox (Decal) e escreve os números em IDS. O menu MAP e o minimapa mostram as
-- fotos por cima do desenho (UI/WorldMap); sem número (0) ou enquanto a foto carrega, fica o desenho.
-- Cada foto é QUADRADA: centro (X, Z) no mundo e Span studs de lado (norte = −Z para cima, leste = +X à direita).
local Islands = require(script.Parent.Islands)
local Village = require(script.Parent.Village)

local MapTiles = {}

-- lado de cada foto (studs): a ilha inteira com a praia e um pouco de mar em volta
local SPAN = {
	common = 1560,
	uncommon = 1200,
	rare = 1740,
	epic = 1220,
	legendary = 1400,
	mythic = 1440,
	divine = 1240,
	cloud = 1160,
}

MapTiles.List = {
	-- ilha principal: do gêiser do céu (norte) até a praia do portal da Pawville (sul)
	{ Key = "main", X = 0, Z = -250, Span = 2000 },
	{ Key = "village", X = Village.Center.X, Z = Village.Center.Z, Span = 1240 },
}
for _, id in ipairs(Islands.ORDER) do
	local def = Islands.List[id]
	if def and SPAN[id] then
		table.insert(MapTiles.List, { Key = id, X = def.Center.X, Z = def.Center.Z, Span = SPAN[id], Sky = id == "cloud" })
	end
end

-- Números das fotos no Roblox (Decal). O PUBLICAR.bat preenche sozinho.
-- Não mude o formato "chave = 0 --[[ID_Map]]": é o que o publicador procura.
MapTiles.IDS = {
	main = 0 --[[ID_Map]],
	village = 0 --[[ID_Map]],
	common = 0 --[[ID_Map]],
	uncommon = 0 --[[ID_Map]],
	rare = 0 --[[ID_Map]],
	epic = 0 --[[ID_Map]],
	legendary = 0 --[[ID_Map]],
	mythic = 0 --[[ID_Map]],
	divine = 0 --[[ID_Map]],
	cloud = 0 --[[ID_Map]],
}

MapTiles.ByKey = {}
for _, tile in ipairs(MapTiles.List) do
	local id = MapTiles.IDS[tile.Key]
	tile.Id = (type(id) == "number" and id > 0) and id or 0
	MapTiles.ByKey[tile.Key] = tile
end

-- atributo do ReplicatedStorage com a imagem de verdade da foto (o servidor descobre pelo Decal — Services/MapImages)
function MapTiles.Attr(key)
	return "MapTile_" .. key
end

return MapTiles
