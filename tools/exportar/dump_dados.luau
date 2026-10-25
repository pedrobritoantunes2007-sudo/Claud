-- Exporta os DADOS do projeto Roblox (números, raridades, ovos, ilhas, habilidades, sons) como um JSON só.
-- Roda dentro do pacote do exportar.py. Cores viram "#rrggbb", Vector3 vira [x, y, z], Enum vira o nome.

local Config = require(SHARED.Config)
local DogData = require(SHARED.DogData)
local Islands = require(SHARED.Islands)
local Skills = require(SHARED.Skills)
local SfxConfig = SHARED:FindFirstChild("SfxConfig") and require(SHARED.SfxConfig) or {}
local MusicConfig = SHARED:FindFirstChild("MusicConfig") and require(SHARED.MusicConfig) or {}

local function hex(c)
	return string.format("#%02x%02x%02x", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

local function esc(s)
	s = string.gsub(s, '[%c"\\]', function(ch)
		if ch == "\n" then
			return "\\n"
		elseif ch == "\t" then
			return "\\t"
		elseif ch == '"' then
			return '\\"'
		elseif ch == "\\" then
			return "\\\\"
		end
		return string.format("\\u%04x", string.byte(ch))
	end)
	return '"' .. s .. '"'
end

local function num(n)
	if n ~= n or n == math.huge or n == -math.huge then
		return "null"
	end
	if n == math.floor(n) and math.abs(n) < 1e15 then
		return string.format("%d", n)
	end
	return string.format("%.6g", n)
end

local encode
local function isArray(t)
	local n = 0
	for k in pairs(t) do
		if type(k) ~= "number" or k < 1 or k ~= math.floor(k) then
			return false
		end
		n += 1
	end
	for i = 1, n do
		if t[i] == nil then
			return false
		end
	end
	return n > 0
end

function encode(v, seen, skip)
	local tv = typeof(v)
	if tv == "nil" then
		return "null"
	elseif tv == "boolean" then
		return v and "true" or "false"
	elseif tv == "number" then
		return num(v)
	elseif tv == "string" then
		return esc(v)
	elseif tv == "Color3" then
		return esc(hex(v))
	elseif tv == "Vector3" then
		return "[" .. num(v.X) .. "," .. num(v.Y) .. "," .. num(v.Z) .. "]"
	elseif tv == "EnumItem" then
		return esc(v.Name)
	elseif tv == "table" then
		if seen[v] then
			return "null"
		end
		seen[v] = true
		local out = {}
		if isArray(v) then
			for _, item in ipairs(v) do
				local e = encode(item, seen, skip)
				if e ~= nil then
					table.insert(out, e)
				end
			end
			seen[v] = nil
			return "[" .. table.concat(out, ",") .. "]"
		end
		local keys = {}
		for k in pairs(v) do
			if (type(k) == "string" or type(k) == "number") and not (skip and skip[k]) then
				table.insert(keys, k)
			end
		end
		table.sort(keys, function(a, b)
			return tostring(a) < tostring(b)
		end)
		for _, k in ipairs(keys) do
			local e = encode(v[k], seen, nil)
			if e ~= nil then
				table.insert(out, esc(tostring(k)) .. ":" .. e)
			end
		end
		seen[v] = nil
		return "{" .. table.concat(out, ",") .. "}"
	end
	return nil -- funções, Instances, CFrames...
end

local function enc(v, skip)
	return encode(v, {}, skip)
end

-- espécies sem o "Look" (desenho; esse vai no cachorros.json)
local species = {}
for id, sp in pairs(DogData.Species) do
	local copy = {}
	for k, val in pairs(sp) do
		if k ~= "Look" then
			copy[k] = val
		end
	end
	copy.Elements = DogData.ElementsOf(id)
	copy.Powers = DogData.PowersFor(id)
	copy.GameScale = DogData.GameScale(id)
	copy.Shot = DogData.RANGED[id]
	species[id] = copy
end

local eggOdds = {}
for id in pairs(DogData.Eggs) do
	eggOdds[id] = DogData.EggOdds(id, 1)
end

local xp = {}
for level = 1, Config.MAX_LEVEL do
	xp[level] = Config.XPToNext(level)
end

local specials = {}
for id, info in pairs(DogData.Specials or {}) do
	if type(info) == "table" then
		specials[id] = { Name = info.Name, Color = info.Color, Icon = info.Icon, Desc = info.Desc }
	end
end

local parts = {
	'"Config":' .. enc(Config),
	'"XPToNext":' .. enc(xp),
	'"Species":' .. enc(species),
	'"Order":' .. enc(DogData.Order),
	'"Eggs":' .. enc(DogData.Eggs),
	'"EggOdds":' .. enc(eggOdds),
	'"ShotStyles":' .. enc(DogData.SHOT_STYLES),
	'"DogElements":' .. enc(DogData.DOG_ELEMENTS),
	'"DogElementOrder":' .. enc(DogData.DOG_ELEMENT_ORDER),
	'"ElementStrong":' .. enc(DogData.ELEMENT_STRONG),
	'"Specials":' .. enc(specials),
	'"Islands":' .. enc(Islands),
	'"Skills":' .. enc(Skills.BySpecies),
	'"Sfx":' .. enc(SfxConfig),
	'"Music":' .. enc(MusicConfig),
}
print("JSON>>{" .. table.concat(parts, ",") .. "}<<JSON")
