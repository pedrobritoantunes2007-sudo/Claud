-- 🧰 Contexto de montagem de uma ilha: altura do chão, espaço reservado, "espalhar" enfeites,
-- builders no chão e as partes que toda ilha tem (portal HOME, estande do ovo, palco do campeão).
-- Cada módulo de ilha (World/Isles/*.lua) devolve { Spec = function() ... end, Build = function(ctx) ... end }.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage.Shared.Config)
local Islands = require(ReplicatedStorage.Shared.Islands)
local TerrainGen = require(script.Parent.TerrainGen)
local Deco = require(script.Parent.Deco)
local Details = require(script.Parent.Details)

local IslandKit = {}
IslandKit.__index = IslandKit

function IslandKit.new(id, spec, parent, seed, def)
	def = def or Islands.List[id]
	local folder = Instance.new("Model")
	folder.Name = id
	folder:SetAttribute("Island", id)
	local self = setmetatable({
		Id = id,
		Def = def,
		CF = def.CF,
		Spec = spec,
		Folder = folder,
		Rng = Random.new(seed or 1),
		Res = {},
		Groups = {},
	}, IslandKit)
	folder.Parent = parent
	return self
end

-- grupo (pasta) dentro da ilha: "Natureza", "Marco", "Vila"...
function IslandKit:Group(name)
	local g = self.Groups[name]
	if not g then
		g = Instance.new("Folder")
		g.Name = name
		g.Parent = self.Folder
		self.Groups[name] = g
	end
	return g
end

function IslandKit:H(x, z)
	if not self.Spec.Mask then
		return self.Spec.FlatY or 0
	end
	return (TerrainGen.Height(self.Spec, x, z))
end
function IslandKit:Slope(x, z)
	if not self.Spec.Mask then
		return 0
	end
	return TerrainGen.Slope(self.Spec, x, z)
end
function IslandKit:Reserve(x, z, r)
	table.insert(self.Res, { x, z, r })
end
function IslandKit:Free(x, z, pad)
	pad = pad or 0
	for _, r in ipairs(self.Res) do
		local dx, dz = x - r[1], z - r[2]
		if dx * dx + dz * dz < (r[3] + pad) ^ 2 then
			return false
		end
	end
	return true
end

-- CFrame do mundo de um ponto local (y local; nil = no chão), com giro local
function IslandKit:LocalCF(x, y, z, ry)
	return self.CF * CFrame.new(x, y or self:H(x, z), z) * CFrame.Angles(0, ry or 0, 0)
end
-- Builder com origem no chão (ou na altura y local), girado ry, escala s
function IslandKit:At(x, z, ry, y, s, group)
	return Deco.Builder(group and self:Group(group) or self.Folder, self:LocalCF(x, y, z, ry), s or 1)
end

-- Célula de detalhe (pasta de 160 studs) do ponto local (x, z) na altura local y (nil = chão).
-- O cliente só mostra as células perto da câmera (client/Systems/Islands.lua): detalhe pequeno vai sempre aqui.
function IslandKit:Detail(x, z, y)
	return Details.Cell(self:Group("Detalhes"), self.CF:PointToWorldSpace(Vector3.new(x, y or self:H(x, z), z)))
end
-- Detalhe pequeno no chão do ponto (x, z): fn = Details.X ou Deco.X, no formato (pasta, cf, escala, rng, ...)
function IslandKit:Put(fn, x, z, ry, s, ...)
	local y = self:H(x, z)
	return fn(self:Detail(x, z, y), self:LocalCF(x, y, z, ry), s or 1, self.Rng, ...)
end
-- igual ao Put, mas na altura local y (deque, telhado, pedaço flutuante...)
function IslandKit:PutAt(fn, x, y, z, ry, s, ...)
	return fn(self:Detail(x, z, y), self:LocalCF(x, y, z, ry), s or 1, self.Rng, ...)
end

-- Espalha n coisas. fn(x, z, y, i). opts: minY, maxY, maxSlope, pad, region(x,z), cx, cz, half, r, tries
function IslandKit:Scatter(n, fn, opts)
	opts = opts or {}
	local rng = self.Rng
	local half = opts.half or self.Spec.Half or 600
	local cx, cz = opts.cx or 0, opts.cz or 0
	local placed, tries = 0, 0
	local maxTries = n * (opts.tries or 40)
	while placed < n and tries < maxTries do
		tries += 1
		local x, z = cx + rng:NextNumber(-half, half), cz + rng:NextNumber(-half, half)
		local ok = true
		if opts.r then
			local dx, dz = x - cx, z - cz
			ok = dx * dx + dz * dz <= opts.r * opts.r
		end
		if ok and opts.region then
			ok = opts.region(x, z)
		end
		if ok then
			local y = self:H(x, z)
			if y >= (opts.minY or 3.4) and y <= (opts.maxY or 1e9) then
				if (opts.maxSlope == nil or self:Slope(x, z) <= opts.maxSlope) and self:Free(x, z, opts.pad or 0) then
					placed += 1
					fn(x, z, y, placed)
				end
			end
		end
	end
	return placed
end

---------------------------------------------------------------- partes comuns
-- Portal HOME da ilha (volta para a Praça dos Portais da ilha principal)
function IslandKit:HomePortal(y)
	local p = self.Def.Portal
	local gy = y or (self.Spec.Mask and self:H(p.X, p.Z) or p.Y)
	local cf = self.CF * CFrame.new(p.X, gy, p.Z)
	local model, swirl = Deco.Portal(self:Group("Portal"), cf, Islands.COLORS.main, Islands.COLORS.main, "HomePortal", { Crown = true })
	swirl:SetAttribute("PortalTo", "main")
	swirl:SetAttribute("PortalFrom", self.Id)
	CollectionService:AddTag(swirl, "IslandPortal")
	local sb = Deco.Builder(model, cf, 1)
	-- placa "HOME" em cima da coroa do arco: tábua escura com moldura de blocos (ouro claro em cima, escuro
	-- embaixo, quinas de ouro), 2 suportes de pedra e cubinhos de luz nas pontas
	local GOLD, GOLD_DK = Color3.fromRGB(255, 211, 77), Color3.fromRGB(196, 150, 40)
	local sign = sb:Box(Vector3.new(30, 7, 1), Color3.fromRGB(45, 60, 75), 0, 68.5, 0)
	sb:Box(Vector3.new(31.4, 1, 1.6), GOLD, 0, 72.4, 0, 0, 0, 0, Deco.DECOR)
	sb:Box(Vector3.new(31.4, 1, 1.6), GOLD_DK, 0, 64.6, 0, 0, 0, 0, Deco.DECOR)
	for _, sx in ipairs({ -1, 1 }) do
		sb:Box(Vector3.new(1, 7, 1.6), GOLD_DK, sx * 15.2, 68.5, 0, 0, 0, 0, Deco.DECOR)
		sb:Box(Vector3.new(1.8, 1.8, 1.8), GOLD, sx * 15.4, 72.6, 0, 0, 0, 0, Deco.DECOR)
		sb:Box(Vector3.new(1, 1, 1), Islands.COLORS.main, sx * 15.4, 74, 0, 0, 0, 0, Deco.GLOW)
		sb:Box(Vector3.new(2, 1.2, 2), Color3.fromRGB(240, 234, 222), sx * 8, 63.6, 0, 0, 0, 0, Deco.DECOR)
	end
	Deco.Sign(sign, Enum.NormalId.Back, "🏠 HOME", nil, Color3.fromRGB(255, 255, 255))
	Deco.Sign(sign, Enum.NormalId.Front, "🏠 HOME", nil, Color3.fromRGB(255, 255, 255))
	self:Reserve(p.X, p.Z, 36)
	return model, swirl
end

-- 🦮 (2026-10-25, o dono: "tira o ovo e só deixa o spin") sem ovos o pedestal vira LOJA DE COLEIRAS: em cima, a estátua
-- de um cachorro da ilha (mostra quem dá para capturar ali) e o prompt "Leashes" (etiqueta LeashShopPrompt: o cliente
-- Systems/Catch abre a loja). O mesmo pedestal, os mesmos caminhos e placas.
function IslandKit:LeashStand(x, z, colors, y, ry)
	local DogBuilder = require(ReplicatedStorage.Shared.DogBuilder)
	local DogData = require(ReplicatedStorage.Shared.DogData)
	local def = self.Def
	local list
	if def.Flyers then
		list = DogData.SpeciesWithElement(def.Rarity or "Rare", "Fly")
	else
		list = DogData.SpeciesOfRarity(def.Golden and "Mythic" or def.Rarity or "Common")
	end
	local species = nil
	for _, id in ipairs(list or {}) do
		if not DogData.Species[id].BossOnly then
			species = id
			break
		end
	end
	colors = colors or {}
	local cf = self:LocalCF(x, y, z, ry)
	local model = Deco.EggStand(self:Group("Ovo"), cf, nil, colors.Base, colors.Top, colors.Ring)
	model.Name = "LeashStand"
	if species then
		local ok, statue = pcall(DogBuilder.Build, species, { scale = 3.4 })
		if ok and statue then
			statue.Name = "Estatua"
			for _, d in ipairs(statue:GetDescendants()) do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
					d.CanQuery = false
				end
			end
			statue.Parent = model
			-- (o cachorro olha para −Z: fica de frente para a frente do pedestal) e pisa no topo dele
			statue:PivotTo(cf * CFrame.Angles(0, math.pi, 0))
			local box, size = statue:GetBoundingBox()
			local bottom = box.Position.Y - size.Y / 2
			statue:PivotTo(statue:GetPivot() + Vector3.new(0, (cf.Position.Y + 10.1) - bottom, 0))
		end
	end
	local anchor = Deco.Builder(model, cf, 1):Box(Vector3.new(6, 6, 6), Color3.new(1, 1, 1), 0, 14, 0, 0, 0, 0, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	anchor.Name = "PromptAnchor"
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "LeashPrompt"
	prompt.ActionText = "Leashes"
	prompt.ObjectText = "🐾 Leash Shop"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 26
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.Parent = anchor
	CollectionService:AddTag(prompt, "LeashShopPrompt")
	-- placa flutuando (dá para achar a loja de longe)
	local board = Instance.new("BillboardGui")
	board.Name = "LeashSign"
	board.Size = UDim2.fromOffset(260, 60)
	board.StudsOffsetWorldSpace = Vector3.new(0, 14, 0)
	board.MaxDistance = 220
	board.LightInfluence = 0
	board.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.LuckiestGuy
	label.TextScaled = true
	label.Text = "🐾 LEASH SHOP"
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeColor3 = Color3.fromRGB(30, 60, 120)
	label.TextStrokeTransparency = 0
	label.Parent = board
	self:Reserve(x, z, 30)
	return model
end

-- placa que apontava para o ovo da ilha (sem ovos aponta para a loja de coleiras)
function IslandKit.EggSign(text)
	return Config.EGGS and text or "🐾 LEASHES"
end

-- Estande do ovo gigante da ilha (com ProximityPrompt que abre o EGGS nesse ovo)
function IslandKit:EggStand(x, z, colors, y, ry)
	if not Config.EGGS then
		return self:LeashStand(x, z, colors, y, ry)
	end
	local eggId = self.Def.Egg
	local DogBuilder = require(ReplicatedStorage.Shared.DogBuilder)
	local egg = nil
	if eggId then
		local ok, m = pcall(DogBuilder.Egg, eggId, 7)
		if ok then
			egg = m
		end
	end
	colors = colors or {}
	local cf = self:LocalCF(x, y, z, ry)
	local model = Deco.EggStand(self:Group("Ovo"), cf, egg, colors.Base, colors.Top, colors.Ring)
	if eggId then
		local anchor = Deco.Builder(model, cf, 1):Box(Vector3.new(6, 6, 6), Color3.new(1, 1, 1), 0, 14, 0, 0, 0, 0, {
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
		})
		anchor.Name = "PromptAnchor"
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Buy Egg"
		prompt.ObjectText = (require(ReplicatedStorage.Shared.DogData).Eggs[eggId] or {}).Name or "Egg"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.MaxActivationDistance = 26
		prompt.RequiresLineOfSight = false
		prompt.HoldDuration = 0
		prompt:SetAttribute("EggId", eggId)
		prompt.Parent = anchor
		CollectionService:AddTag(prompt, "EggStandPrompt")
	end
	self:Reserve(x, z, 30)
	return model
end

-- Palco do campeão (o campeão de verdade é um NPC do NPCService que fica perto daqui).
-- Palco quadrado de blocos (Deco.ChampionStage): borda de luz, ladrilhos e cubos de luz nas quinas.
function IslandKit:ChampionStage(x, z, color, y, r)
	local b = self:At(x, z, 0, y, 1, "Campeao")
	r = r or 26
	Deco.ChampionStage(self:Group("Campeao"), b.Base, color or Color3.fromRGB(255, 211, 77), r)
	local crown = b:Box(Vector3.new(1, 1, 1), Color3.new(1, 1, 1), 0, 40, 0, 0, 0, 0, { Transparency = 1, CanCollide = false, CanQuery = false })
	Deco.Billboard(crown, Vector3.new(0, 0, 0), "👑 CHAMPION", Color3.fromRGB(255, 211, 77), 22, 500)
	self:Reserve(x, z, 30)
end

-- Ponto de orbe (o ArenaOrbs põe os orbes nos pontos marcados de cada ilha). Orbes desligados (Config.ORBS): nada
function IslandKit:OrbSpot(x, z, y)
	if not Config.ORBS then
		return nil
	end
	local cf = self:LocalCF(x, y, z, 0)
	local spot = Instance.new("Part")
	spot.Name = "OrbSpot"
	spot.Anchored = true
	spot.CanCollide = false
	spot.CanQuery = false
	spot.CanTouch = false
	spot.Transparency = 1
	spot.Size = Vector3.new(1, 1, 1)
	spot.CFrame = cf + Vector3.new(0, 3.5, 0)
	spot.Parent = self:Group("OrbSpots")
	-- marquinha de blocos no chão (só enfeite, na célula de detalhe: o cliente mostra só de perto)
	local gy = y or self:H(x, z)
	Deco.OrbPad(self:Detail(x, z, gy), self:LocalCF(x, gy, z, 0))
	return spot
end

return IslandKit
