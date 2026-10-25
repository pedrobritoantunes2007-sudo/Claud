-- Remotes + cópia local do perfil do jogador (atualizada pelo servidor).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DogData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DogData"))

local Net = {}

Net.Remotes = ReplicatedStorage:WaitForChild("Remotes")
Net.Profile = nil
Net.Changed = Instance.new("BindableEvent") -- (profile)

Net.Remotes.Profile.OnClientEvent:Connect(function(profile)
	Net.Profile = profile
	Net.Changed:Fire(profile)
end)
Net.Remotes.RequestProfile:FireServer()

function Net.WaitProfile()
	while not Net.Profile do
		Net.Changed.Event:Wait()
	end
	return Net.Profile
end

function Net.Equipped()
	local p = Net.Profile
	return p and p.Equipped and p.Dogs[p.Equipped]
end

-- Chama um RemoteFunction sem quebrar a UI se o servidor der erro. Retorna ok, mensagem
function Net.Invoke(remoteName, ...)
	local args = table.pack(...)
	local okCall, ok, message = pcall(function()
		return Net.Remotes[remoteName]:InvokeServer(table.unpack(args, 1, args.n))
	end)
	if not okCall then
		return false, "That didn't work, try again."
	end
	return ok, message
end

-- Power de um cachorro do perfil (mesma conta do servidor)
function Net.Power(dog)
	local Config = require(ReplicatedStorage.Shared.Config)
	local DogData = require(ReplicatedStorage.Shared.DogData)
	local species = dog and DogData.Species[dog.Species]
	if not species then
		return 0
	end
	return Config.Stats(species, dog.Level, dog).Power -- (✨🥇🌈 contam: Shared/Variants)
end

function Net.DogCount()
	-- (☀️ os Divinos não ocupam o canil, igual ao servidor)
	local count = 0
	if Net.Profile then
		for _, dog in pairs(Net.Profile.Dogs) do
			local species = DogData.Species[dog.Species]
			if not (species and species.Rarity == "Divine") then
				count += 1
			end
		end
	end
	return count
end

-- Lista de cachorros ordenada: equipado, favoritos, raridade, level
function Net.SortedDogs(onlyFav)
	local Config = require(ReplicatedStorage.Shared.Config)
	local DogData = require(ReplicatedStorage.Shared.DogData)
	local p = Net.Profile
	local list = {}
	if not p then
		return list
	end
	for _, dog in pairs(p.Dogs) do
		if not onlyFav or dog.Fav then
			table.insert(list, dog)
		end
	end
	table.sort(list, function(a, b)
		if (a.Id == p.Equipped) ~= (b.Id == p.Equipped) then
			return a.Id == p.Equipped
		end
		if a.Fav ~= b.Fav then
			return a.Fav
		end
		local ra = Config.RARITY[DogData.Species[a.Species].Rarity].Order
		local rb = Config.RARITY[DogData.Species[b.Species].Rarity].Order
		if ra ~= rb then
			return ra > rb
		end
		if a.Level ~= b.Level then
			return a.Level > b.Level
		end
		return tonumber(a.Id) < tonumber(b.Id)
	end)
	return list
end

return Net
