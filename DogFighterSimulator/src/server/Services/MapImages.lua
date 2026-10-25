-- 🗺️ Fotos de cima do mapa (Shared/MapTiles): o PUBLICAR.bat sobe cada foto como DECAL, mas uma tela (ImageLabel)
-- precisa do número da IMAGEM que está dentro do Decal. O servidor abre cada Decal (InsertService — a foto é do dono
-- do jogo) e escreve a imagem num atributo do ReplicatedStorage ("MapTile_<chave>"); o cliente troca a miniatura
-- (rbxthumb, 420x420) pela imagem de verdade assim que o atributo aparece.
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapTiles = require(ReplicatedStorage.Shared.MapTiles)

local MapImages = {}

local function textureOf(id)
	local ok, model = pcall(InsertService.LoadAsset, InsertService, id)
	if not ok or not model then
		return nil
	end
	local texture = nil
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Decal") or d:IsA("Texture") then
			texture = d.Texture
			break
		end
	end
	model:Destroy()
	if type(texture) == "string" and texture ~= "" then
		return texture
	end
	return nil
end

function MapImages.Start()
	task.spawn(function()
		for _, tile in ipairs(MapTiles.List) do
			if tile.Id > 0 then
				local texture = textureOf(tile.Id)
				if texture then
					ReplicatedStorage:SetAttribute(MapTiles.Attr(tile.Key), texture)
				else
					warn("[MapImages] não abri a foto do mapa", tile.Key, tile.Id, "(fica a miniatura)")
				end
				task.wait(0.2)
			end
		end
	end)
end

return MapImages
