-- 🧑 GENTE DA VILA (Pawville, 2026-10): bonequinhos de BLOCOS no estilo do jogo (cabeça cúbica, roupas em 3–4 tons,
-- cabelos e chapéus de bloquinho), com juntas Motor6D (pescoço, ombros, quadris e raiz) para o cliente animar.
--   VillageFolk.Outfit(seed, role)                      -> roupa sorteada (a mesma seed dá sempre a mesma pessoa)
--   VillageFolk.Build(pasta, cfDoChao, roupa, escala?)  -> rig { Model, Root, Joints, Base, Scale }
--   VillageFolk.Pose(rig, t, estado)                    -> mexe as juntas (andar, correr, sentar, acenar, conversar...)
--   VillageFolk.FromAvatar(molde, pasta, cfDoChao)      -> rig do AVATAR de verdade (top 30 — Services/VillageStars)
-- O cliente (Systems/VillageLife) monta o povo e anima; o servidor só monta o 🎓 Professor (World/Village) e a
-- prévia (tools/preview) monta todo mundo parado. Nada aqui colide nem aparece em raycast.
local VillageFolk = {}

local C = Color3.fromRGB
local BLACK, WHITE = Color3.new(0, 0, 0), Color3.new(1, 1, 1)
local function dk(c, k)
	return c:Lerp(BLACK, k or 0.22)
end
local function lt(c, k)
	return c:Lerp(WHITE, k or 0.18)
end

local SKIN = { C(255, 222, 190), C(244, 198, 156), C(226, 176, 132), C(200, 144, 102), C(164, 110, 74), C(122, 82, 54) }
local HAIR = { C(38, 30, 26), C(84, 56, 36), C(136, 90, 52), C(228, 192, 120), C(196, 92, 50), C(64, 64, 70), C(30, 30, 34) }
local OLD_HAIR = { C(214, 214, 220), C(186, 186, 192), C(236, 236, 240) }
local SHIRT = {
	C(232, 76, 76), C(255, 150, 60), C(255, 210, 70), C(110, 200, 90), C(70, 170, 230), C(120, 110, 230),
	C(220, 110, 200), C(250, 250, 250), C(60, 70, 90), C(250, 160, 180), C(90, 210, 200), C(170, 120, 80),
}
local PANTS = { C(56, 80, 150), C(42, 44, 54), C(112, 86, 62), C(150, 152, 162), C(72, 112, 72), C(196, 176, 134), C(90, 60, 110) }
local SHOES = { C(44, 38, 36), C(240, 240, 242), C(124, 76, 44), C(206, 64, 64), C(60, 90, 160) }
local HATS = { "cap", "beanie", "straw", "bucket", "flowers", "top" }
local HAT_COLORS = { C(220, 60, 60), C(60, 120, 220), C(250, 210, 70), C(60, 170, 90), C(240, 240, 240), C(250, 140, 60), C(150, 90, 220) }

-- roupa por papel: o que a pessoa usa (chapéu de cozinheiro no vendedor, quepe no guarda...)
local ROLE_HAT = { Guard = "guard", Garden = "straw", Fish = "bucket", Sweep = "cap", Beach = "straw" }

function VillageFolk.Outfit(seed, role)
	local rng = Random.new(seed or 1)
	local function pick(list)
		return list[rng:NextInteger(1, #list)]
	end
	local o = {}
	o.Skin = pick(SKIN)
	o.Old = role ~= "Kids" and rng:NextNumber() < 0.14
	o.Hair = o.Old and pick(OLD_HAIR) or pick(HAIR)
	o.HairStyle = o.Old and (rng:NextNumber() < 0.5 and "bald" or "short") or pick({ "short", "short", "long", "ponytail", "bun", "spiky", "bowl", "mohawk", "long" })
	o.Shirt = pick(SHIRT)
	o.ShirtStyle = pick({ "tee", "tee", "long", "stripes", "jacket", "dress", "overalls", "tee" })
	o.Accent = pick(SHIRT)
	if o.Accent == o.Shirt then
		o.Accent = WHITE
	end
	o.Pants = pick(PANTS)
	o.Shorts = role == "Beach" or role == "Kids" and rng:NextNumber() < 0.5 or rng:NextNumber() < 0.15
	o.Shoes = pick(SHOES)
	o.Hat = ROLE_HAT[role] or (rng:NextNumber() < 0.4 and pick(HATS) or nil)
	o.HatColor = pick(HAT_COLORS)
	o.Glasses = rng:NextNumber() < (o.Old and 0.6 or 0.16)
	o.Backpack = role == "Walk" and rng:NextNumber() < 0.14 or role == "Kids" and rng:NextNumber() < 0.5
	o.Scarf = rng:NextNumber() < 0.08
	o.Mustache = o.Old and rng:NextNumber() < 0.5
	o.Blush = rng:NextNumber() < 0.3
	o.Apron = role == "Vendor" and C(250, 250, 248) or nil
	if role == "Staff" then
		-- funcionários do canil: camiseta verde com patinha, boné verde
		o.Shirt, o.ShirtStyle, o.Accent, o.Hat, o.HatColor = C(80, 180, 110), "tee", C(255, 255, 255), "cap", C(60, 150, 90)
		o.Paw = true
	elseif role == "Guard" then
		o.Shirt, o.ShirtStyle, o.Accent, o.Pants, o.HatColor = C(60, 80, 150), "jacket", C(250, 210, 80), C(40, 44, 70), C(50, 60, 120)
	elseif role == "Sweep" or role == "Garden" then
		o.ShirtStyle = "overalls"
	end
	if o.ShirtStyle == "dress" then
		o.Shorts = false
	end
	o.Hold = role == "Sweep" and "broom" or role == "Fish" and "rod" or role == "Music" and "guitar" or nil
	return o
end

-- 🎓 Professor Barkley: jaleco branco, óculos, cabelo grisalho dos lados, bigode e gravata-borboleta vermelha
function VillageFolk.ProfessorOutfit()
	return {
		Skin = C(244, 204, 166),
		Old = true,
		Hair = C(214, 214, 222),
		HairStyle = "bald",
		Shirt = C(120, 170, 230),
		ShirtStyle = "long",
		Accent = C(250, 250, 250),
		Pants = C(112, 86, 62),
		Shoes = C(70, 46, 34),
		Glasses = true,
		Mustache = true,
		LabCoat = true,
		BowTie = C(220, 50, 60),
		Hold = "clipboard",
	}
end

---------------------------------------------------------------- montagem
local NOPHYS = { CanCollide = false, CanQuery = false, CanTouch = false, Massless = true }
-- juntas: { Part0 (nome), C0 (sem escala), C1 (sem escala) } — a pose parte destes C0 "de descanso"
local JOINTS = {
	Root = { Vector3.new(0, 0, 0), Vector3.new(0, 0, 0) },
	Neck = { Vector3.new(0, 1, 0), Vector3.new(0, -0.6, 0) },
	LS = { Vector3.new(-1.5, 0.75, 0), Vector3.new(0, 0.75, 0) },
	RS = { Vector3.new(1.5, 0.75, 0), Vector3.new(0, 0.75, 0) },
	LH = { Vector3.new(-0.5, -1, 0), Vector3.new(0, 1, 0) },
	RH = { Vector3.new(0.5, -1, 0), Vector3.new(0, 1, 0) },
}

local function newPart(parent, name, size, cf, color, shadow)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = false
	for k, v in pairs(NOPHYS) do
		p[k] = v
	end
	p.CastShadow = shadow == true
	p.Parent = parent
	return p
end

-- cfDoChao = pés no chão, olhando para a frente (−Z). roupa = VillageFolk.Outfit(...). s = escala (criança 0.72)
function VillageFolk.Build(parent, cfGround, o, s)
	s = s or 1
	local model = Instance.new("Model")
	model.Name = "Villager"
	local root = newPart(model, "HumanoidRootPart", Vector3.new(2, 2, 1) * s, cfGround * CFrame.new(0, 3 * s, 0), WHITE)
	root.Transparency = 1
	root.Anchored = true
	model.PrimaryPart = root
	local base = root.CFrame
	local function V(x, y, z)
		return Vector3.new(x, y, z) * s
	end
	local function at(x, y, z)
		return base * CFrame.new(x * s, y * s, z * s)
	end
	-- peças principais
	local torso = newPart(model, "Torso", V(2, 2, 1), at(0, 0, 0), o.Shirt, true)
	local head = newPart(model, "Head", V(1.2, 1.2, 1.2), at(0, 1.6, 0), o.Skin, true)
	local longSleeve = o.ShirtStyle == "long" or o.ShirtStyle == "jacket" or o.LabCoat
	local armColor = longSleeve and (o.LabCoat and C(248, 248, 250) or o.Shirt) or o.Skin
	local la = newPart(model, "LeftArm", V(1, 2, 1), at(-1.5, 0, 0), armColor, true)
	local ra = newPart(model, "RightArm", V(1, 2, 1), at(1.5, 0, 0), armColor, true)
	local legColor = (o.Shorts or o.ShirtStyle == "dress") and o.Skin or o.Pants
	local ll = newPart(model, "LeftLeg", V(1, 2, 1), at(-0.5, -2, 0), legColor, true)
	local rl = newPart(model, "RightLeg", V(1, 2, 1), at(0.5, -2, 0), legColor, true)

	-- enfeite colado numa peça: offset no espaço da peça
	local function deco(on, name, size, offset, color, shadow)
		local p = newPart(model, name, size * s, on.CFrame * CFrame.new(offset * s), color, shadow)
		local w = Instance.new("WeldConstraint")
		w.Part0 = on
		w.Part1 = p
		w.Parent = p
		return p
	end
	local function decoCF(on, name, size, cf, color)
		local p = newPart(model, name, size * s, on.CFrame * (CFrame.new(cf.Position * s) * cf.Rotation), color)
		local w = Instance.new("WeldConstraint")
		w.Part0 = on
		w.Part1 = p
		w.Parent = p
		return p
	end

	---------------------------------------------------------------- rosto
	local eye = C(30, 26, 30)
	for _, sx in ipairs({ -1, 1 }) do
		deco(head, "Olho", Vector3.new(0.16, 0.24, 0.06), Vector3.new(sx * 0.24, 0.08, -0.6), eye)
		deco(head, "Brilho", Vector3.new(0.06, 0.06, 0.07), Vector3.new(sx * 0.24 - 0.03, 0.14, -0.6), WHITE)
	end
	local mouth = dk(o.Skin, 0.55)
	deco(head, "Boca", Vector3.new(0.38, 0.08, 0.06), Vector3.new(0, -0.24, -0.6), mouth)
	for _, sx in ipairs({ -1, 1 }) do
		deco(head, "Boca", Vector3.new(0.08, 0.08, 0.06), Vector3.new(sx * 0.22, -0.18, -0.6), mouth)
	end
	if o.Blush then
		for _, sx in ipairs({ -1, 1 }) do
			deco(head, "Bochecha", Vector3.new(0.22, 0.1, 0.05), Vector3.new(sx * 0.4, -0.12, -0.6), C(255, 150, 160))
		end
	end
	if o.Glasses then
		local frame = C(40, 36, 40)
		for _, sx in ipairs({ -1, 1 }) do
			deco(head, "Oculos", Vector3.new(0.4, 0.32, 0.05), Vector3.new(sx * 0.25, 0.08, -0.63), frame)
			deco(head, "Lente", Vector3.new(0.28, 0.2, 0.05), Vector3.new(sx * 0.25, 0.08, -0.645), C(200, 230, 250))
		end
		deco(head, "Oculos", Vector3.new(0.14, 0.06, 0.05), Vector3.new(0, 0.12, -0.63), frame)
	end
	if o.Mustache then
		deco(head, "Bigode", Vector3.new(0.62, 0.14, 0.08), Vector3.new(0, -0.12, -0.62), o.Hair)
	end

	---------------------------------------------------------------- cabelo
	local hc, hs = o.Hair, o.HairStyle
	if hs == "bald" then
		for _, sx in ipairs({ -1, 1 }) do
			deco(head, "Cabelo", Vector3.new(0.14, 0.42, 0.7), Vector3.new(sx * 0.63, 0.08, 0.16), hc)
		end
		deco(head, "Cabelo", Vector3.new(1.26, 0.42, 0.14), Vector3.new(0, 0.08, 0.63), hc)
	elseif hs ~= nil then
		deco(head, "Cabelo", Vector3.new(1.3, 0.3, 1.3), Vector3.new(0, 0.62, 0.02), hc, true)
		deco(head, "Cabelo", Vector3.new(1.3, 0.62, 0.26), Vector3.new(0, 0.3, 0.56), hc)
		for _, sx in ipairs({ -1, 1 }) do
			deco(head, "Cabelo", Vector3.new(0.12, 0.44, 0.9), Vector3.new(sx * 0.62, 0.34, 0.14), hc)
		end
		deco(head, "Franja", Vector3.new(1.28, 0.18, 0.1), Vector3.new(0, 0.5, -0.6), lt(hc, 0.08))
		if hs == "long" then
			deco(head, "Cabelo", Vector3.new(1.3, 1.5, 0.3), Vector3.new(0, -0.18, 0.56), hc)
			for _, sx in ipairs({ -1, 1 }) do
				deco(head, "Cabelo", Vector3.new(0.2, 1.1, 0.5), Vector3.new(sx * 0.62, -0.1, 0.3), hc)
			end
		elseif hs == "ponytail" then
			deco(head, "Rabo", Vector3.new(0.44, 1.0, 0.44), Vector3.new(0, 0.05, 0.86), hc)
			deco(head, "Laco", Vector3.new(0.5, 0.2, 0.2), Vector3.new(0, 0.45, 0.78), o.Accent)
		elseif hs == "bun" then
			deco(head, "Coque", Vector3.new(0.62, 0.5, 0.62), Vector3.new(0, 0.98, 0.18), hc)
		elseif hs == "spiky" then
			for k = 0, 4 do
				deco(head, "Espeto", Vector3.new(0.34, 0.4, 0.34), Vector3.new(-0.44 + k * 0.22, 0.86, (k % 2) * 0.24 - 0.1), hc)
			end
		elseif hs == "bowl" then
			deco(head, "Cabelo", Vector3.new(1.34, 0.5, 1.34), Vector3.new(0, 0.48, 0.02), hc)
		elseif hs == "mohawk" then
			deco(head, "Moicano", Vector3.new(0.26, 0.5, 1.1), Vector3.new(0, 0.95, 0.05), o.Accent)
		end
	end

	---------------------------------------------------------------- chapéu
	local hat, hcol = o.Hat, o.HatColor or C(220, 60, 60)
	if hat == "cap" then
		deco(head, "Bone", Vector3.new(1.34, 0.42, 1.34), Vector3.new(0, 0.78, 0.02), hcol, true)
		deco(head, "Aba", Vector3.new(1.0, 0.12, 0.66), Vector3.new(0, 0.6, -0.9), dk(hcol, 0.15))
		deco(head, "Botao", Vector3.new(0.2, 0.1, 0.2), Vector3.new(0, 1.03, 0), lt(hcol))
	elseif hat == "beanie" then
		deco(head, "Gorro", Vector3.new(1.36, 0.6, 1.36), Vector3.new(0, 0.74, 0), hcol, true)
		deco(head, "Gorro", Vector3.new(1.4, 0.2, 1.4), Vector3.new(0, 0.48, 0), dk(hcol, 0.15))
		deco(head, "Pompom", Vector3.new(0.4, 0.4, 0.4), Vector3.new(0, 1.16, 0), WHITE)
	elseif hat == "straw" then
		local straw = C(236, 204, 120)
		deco(head, "Aba", Vector3.new(2.3, 0.14, 2.3), Vector3.new(0, 0.66, 0), straw, true)
		deco(head, "Chapeu", Vector3.new(1.32, 0.52, 1.32), Vector3.new(0, 0.95, 0), lt(straw, 0.1), true)
		deco(head, "Fita", Vector3.new(1.36, 0.16, 1.36), Vector3.new(0, 0.78, 0), hcol)
	elseif hat == "bucket" then
		deco(head, "Aba", Vector3.new(1.7, 0.18, 1.7), Vector3.new(0, 0.66, 0), dk(hcol, 0.1), true)
		deco(head, "Chapeu", Vector3.new(1.32, 0.5, 1.32), Vector3.new(0, 0.95, 0), hcol, true)
	elseif hat == "top" then
		local tc = C(40, 38, 46)
		deco(head, "Aba", Vector3.new(1.8, 0.12, 1.8), Vector3.new(0, 0.66, 0), tc, true)
		deco(head, "Cartola", Vector3.new(1.18, 1.1, 1.18), Vector3.new(0, 1.26, 0), tc, true)
		deco(head, "Fita", Vector3.new(1.22, 0.2, 1.22), Vector3.new(0, 0.82, 0), hcol)
	elseif hat == "flowers" then
		local fl = { C(255, 120, 160), C(255, 220, 80), C(255, 255, 255), C(170, 130, 255), C(120, 200, 255) }
		for k = 0, 7 do
			local a = k / 8 * math.pi * 2
			deco(head, "Flor", Vector3.new(0.3, 0.3, 0.3), Vector3.new(math.cos(a) * 0.62, 0.68, math.sin(a) * 0.62), fl[k % #fl + 1])
		end
	elseif hat == "guard" then
		deco(head, "Quepe", Vector3.new(1.32, 1.1, 1.32), Vector3.new(0, 1.1, 0), hcol, true)
		deco(head, "Aba", Vector3.new(1.1, 0.12, 0.5), Vector3.new(0, 0.6, -0.8), C(30, 30, 36))
		deco(head, "Distintivo", Vector3.new(0.4, 0.4, 0.08), Vector3.new(0, 1.05, -0.68), C(255, 210, 80))
	end

	---------------------------------------------------------------- roupa
	local st = o.ShirtStyle
	-- mangas curtas (camiseta): bloco da cor da camisa na metade de cima do braço
	if not longSleeve then
		for _, arm in ipairs({ la, ra }) do
			deco(arm, "Manga", Vector3.new(1.06, 0.9, 1.06), Vector3.new(0, 0.56, 0), st == "overalls" and o.Accent or o.Shirt)
		end
	else
		-- mãos de fora (manga comprida)
		for _, arm in ipairs({ la, ra }) do
			deco(arm, "Mao", Vector3.new(1.04, 0.46, 1.04), Vector3.new(0, -0.78, 0), o.Skin)
			deco(arm, "Punho", Vector3.new(1.08, 0.16, 1.08), Vector3.new(0, -0.48, 0), dk(armColor, 0.12))
		end
	end
	if st == "stripes" then
		for _, y in ipairs({ 0.45, -0.15 }) do
			deco(torso, "Listra", Vector3.new(2.04, 0.3, 1.04), Vector3.new(0, y, 0), o.Accent)
		end
	elseif st == "jacket" then
		deco(torso, "Camisa", Vector3.new(0.7, 2.0, 0.06), Vector3.new(0, 0, -0.52), o.Accent)
		for _, sx in ipairs({ -1, 1 }) do
			deco(torso, "Lapela", Vector3.new(0.3, 0.7, 0.08), Vector3.new(sx * 0.42, 0.6, -0.53), dk(o.Shirt, 0.2))
			deco(torso, "Botao", Vector3.new(0.12, 0.12, 0.06), Vector3.new(sx * 0.48, -0.2, -0.53), C(250, 210, 90))
		end
	elseif st == "overalls" then
		torso.Color = o.Accent
		deco(torso, "Jardineira", Vector3.new(1.5, 1.2, 1.04), Vector3.new(0, -0.4, 0), o.Pants)
		for _, sx in ipairs({ -1, 1 }) do
			deco(torso, "Alca", Vector3.new(0.26, 1.0, 1.06), Vector3.new(sx * 0.55, 0.5, 0), o.Pants)
			deco(torso, "Fivela", Vector3.new(0.2, 0.2, 0.06), Vector3.new(sx * 0.55, 0.15, -0.54), C(250, 210, 90))
		end
		deco(torso, "Bolso", Vector3.new(0.6, 0.4, 0.06), Vector3.new(0, -0.35, -0.54), dk(o.Pants, 0.15))
	elseif st == "dress" then
		deco(torso, "Saia", Vector3.new(2.4, 1.3, 1.4), Vector3.new(0, -1.45, 0), o.Shirt, true)
		deco(torso, "Barra", Vector3.new(2.44, 0.2, 1.44), Vector3.new(0, -2.0, 0), o.Accent)
		deco(torso, "Cinto", Vector3.new(2.04, 0.2, 1.04), Vector3.new(0, -0.7, 0), o.Accent)
	end
	if st ~= "dress" and st ~= "overalls" and not o.LabCoat then
		deco(torso, "Cinto", Vector3.new(2.04, 0.22, 1.04), Vector3.new(0, -0.89, 0), dk(o.Pants, 0.35))
		deco(torso, "Fivela", Vector3.new(0.3, 0.2, 0.06), Vector3.new(0, -0.89, -0.53), C(230, 200, 90))
	end
	if st == "tee" and not o.Paw then
		deco(torso, "Gola", Vector3.new(0.8, 0.12, 0.06), Vector3.new(0, 0.9, -0.52), dk(o.Shirt, 0.18))
	end
	if o.Paw then
		-- patinha branca na camiseta dos funcionários do canil
		deco(torso, "Pata", Vector3.new(0.6, 0.5, 0.06), Vector3.new(0, 0.05, -0.53), o.Accent)
		for k = -1, 1 do
			deco(torso, "Dedo", Vector3.new(0.2, 0.2, 0.06), Vector3.new(k * 0.26, 0.45 - math.abs(k) * 0.08, -0.53), o.Accent)
		end
	end
	if o.LabCoat then
		local coat = C(248, 248, 250)
		torso.Color = coat
		deco(torso, "Camisa", Vector3.new(0.6, 1.9, 0.06), Vector3.new(0, 0.05, -0.52), o.Shirt)
		deco(torso, "Jaleco", Vector3.new(2.1, 1.5, 1.1), Vector3.new(0, -1.55, 0), coat, true)
		deco(torso, "Bolso", Vector3.new(0.5, 0.4, 0.06), Vector3.new(-0.55, 0.3, -0.53), dk(coat, 0.08))
		deco(torso, "Caneta", Vector3.new(0.08, 0.4, 0.08), Vector3.new(-0.45, 0.5, -0.56), C(60, 110, 220))
		for _, sx in ipairs({ -1, 1 }) do
			deco(torso, "Lapela", Vector3.new(0.3, 0.8, 0.08), Vector3.new(sx * 0.42, 0.5, -0.54), dk(coat, 0.1))
		end
	end
	if o.BowTie then
		deco(torso, "Gravata", Vector3.new(0.56, 0.26, 0.1), Vector3.new(0, 0.82, -0.56), o.BowTie)
		deco(torso, "Gravata", Vector3.new(0.18, 0.18, 0.12), Vector3.new(0, 0.82, -0.58), dk(o.BowTie, 0.25))
	end
	if o.Apron then
		deco(torso, "Avental", Vector3.new(1.6, 2.4, 0.08), Vector3.new(0, -0.6, -0.54), o.Apron)
		deco(torso, "Bolso", Vector3.new(0.7, 0.4, 0.06), Vector3.new(0, -1.1, -0.59), dk(o.Apron, 0.08))
	end
	if o.Scarf then
		deco(torso, "Cachecol", Vector3.new(2.1, 0.42, 1.12), Vector3.new(0, 0.82, 0), o.Accent)
		deco(torso, "Cachecol", Vector3.new(0.42, 0.9, 0.14), Vector3.new(0.45, 0.25, -0.58), o.Accent)
	end
	if o.Backpack then
		deco(torso, "Mochila", Vector3.new(1.4, 1.5, 0.7), Vector3.new(0, 0.05, 0.85), o.Accent, true)
		deco(torso, "Mochila", Vector3.new(1.1, 0.5, 0.2), Vector3.new(0, -0.3, 1.25), dk(o.Accent, 0.2))
	end
	-- calça: bermuda (metade de cima da perna) e sapatos
	for _, leg in ipairs({ ll, rl }) do
		if o.Shorts and st ~= "dress" then
			deco(leg, "Bermuda", Vector3.new(1.06, 0.9, 1.06), Vector3.new(0, 0.56, 0), o.Pants)
		end
		if st == "dress" or o.Shorts then
			deco(leg, "Meia", Vector3.new(1.04, 0.4, 1.04), Vector3.new(0, -0.55, 0), WHITE)
		end
		deco(leg, "Sapato", Vector3.new(1.06, 0.38, 1.24), Vector3.new(0, -0.82, -0.1), o.Shoes)
		deco(leg, "Sola", Vector3.new(1.08, 0.1, 1.26), Vector3.new(0, -0.96, -0.1), dk(o.Shoes, 0.4))
	end

	---------------------------------------------------------------- coisas na mão
	local hold = o.Hold
	if hold == "broom" then
		decoCF(ra, "Vassoura", Vector3.new(0.2, 4.4, 0.2), CFrame.new(0, -0.6, -0.6) * CFrame.Angles(0.25, 0, 0), C(150, 104, 60))
		decoCF(ra, "Vassoura", Vector3.new(1.2, 0.8, 0.5), CFrame.new(0, -2.75, -1.15) * CFrame.Angles(0.25, 0, 0), C(226, 196, 110))
	elseif hold == "rod" then
		decoCF(ra, "Vara", Vector3.new(0.16, 0.16, 7), CFrame.new(0, -0.9, -3.2) * CFrame.Angles(0.5, 0, 0), C(120, 84, 50))
	elseif hold == "guitar" then
		deco(torso, "Violao", Vector3.new(1.4, 1.5, 0.4), Vector3.new(0.1, -0.45, -0.75), C(200, 120, 60), true)
		deco(torso, "Boca", Vector3.new(0.4, 0.4, 0.06), Vector3.new(0.1, -0.35, -0.97), C(60, 36, 24))
		decoCF(torso, "Braco", Vector3.new(2.0, 0.26, 0.18), CFrame.new(-0.9, 0.15, -0.8) * CFrame.Angles(0, 0, 0.35), C(110, 70, 40))
	elseif hold == "clipboard" then
		decoCF(la, "Prancheta", Vector3.new(0.9, 1.15, 0.1), CFrame.new(0.3, -0.9, -0.55) * CFrame.Angles(-0.4, 0, 0), C(150, 104, 60))
		decoCF(la, "Papel", Vector3.new(0.72, 0.9, 0.04), CFrame.new(0.3, -0.92, -0.62) * CFrame.Angles(-0.4, 0, 0), WHITE)
	elseif hold == "balloons" then
		for k, col in ipairs({ C(255, 90, 110), C(90, 160, 255), C(255, 220, 70) }) do
			local b = decoCF(ra, "Balao", Vector3.new(0.9, 1.1, 0.9), CFrame.new((k - 2) * 0.7, 3.4 + (k % 2) * 0.5, -0.4), col)
			b.CastShadow = false
		end
		decoCF(ra, "Fio", Vector3.new(0.05, 2.6, 0.05), CFrame.new(0, 1.9, -0.4), WHITE)
	end

	---------------------------------------------------------------- juntas
	local joints = {}
	local function joint(name, p0, p1)
		local j = JOINTS[name]
		local m = Instance.new("Motor6D")
		m.Name = name
		m.Part0 = p0
		m.Part1 = p1
		m.C0 = CFrame.new(j[1] * s)
		m.C1 = CFrame.new(j[2] * s)
		m.Parent = p0
		joints[name] = m
	end
	joint("Root", root, torso)
	joint("Neck", torso, head)
	joint("LS", torso, la)
	joint("RS", torso, ra)
	joint("LH", torso, ll)
	joint("RH", torso, rl)
	local baseC0 = {}
	for name, m in pairs(joints) do
		baseC0[name] = m.C0
	end
	model:SetAttribute("Scale", s)
	model.Parent = parent
	return { Model = model, Root = root, Head = head, Joints = joints, Base = baseC0, Scale = s }
end

-- 🌟 AVATAR DE VERDADE (2026-10: o povo da vila são os AMIGOS do dono no Roblox — Services/VillageStars monta o molde
-- R15 com a roupa do Roblox de cada um). As juntas R15 ficam com os mesmos nomes do povo de blocos (Root, Neck, LS/RS,
-- LH/RH) + os joelhos (LK/RK: dobram para sentar e no passo).
local R15 = { Root = "Root", Neck = "Neck", LS = "LeftShoulder", RS = "RightShoulder", LH = "LeftHip", RH = "RightHip", LK = "LeftKnee", RK = "RightKnee" }

-- onde cada peça fica em relação à raiz, seguindo as juntas Motor6D (Part1 = Part0 * C0 * C1⁻¹). Não depende de onde as
-- peças estão no mundo (o molde vem do servidor fora do mundo, às vezes desmontado)
local function solveRel(model, root)
	local rel = { [root] = CFrame.new() }
	local motors = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") and d.Part0 and d.Part1 then
			table.insert(motors, d)
		end
	end
	for _ = 1, 10 do
		local changed = false
		for _, m in ipairs(motors) do
			if rel[m.Part0] and not rel[m.Part1] then
				rel[m.Part1] = rel[m.Part0] * m.C0 * m.C1:Inverse()
				changed = true
			end
		end
		if not changed then
			break
		end
	end
	return rel
end

-- ponto mais baixo (Y) de uma peça girada em `cf`
local function lowestY(cf, size)
	local h = size / 2
	local low = math.huge
	for _, dx in ipairs({ -1, 1 }) do
		for _, dy in ipairs({ -1, 1 }) do
			for _, dz in ipairs({ -1, 1 }) do
				low = math.min(low, cf:PointToWorldSpace(Vector3.new(dx * h.X, dy * h.Y, dz * h.Z)).Y)
			end
		end
	end
	return low
end

-- altura da raiz até a sola do pé (em pé) de um avatar R15, pelas juntas. (Antes vinha do HipHeight do Humanoid, que
-- o Roblox às vezes só calcula com o boneco no mundo: o povo ficava com as pernas dentro do chão)
function VillageFolk.AvatarRootHeight(model)
	local root = model:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return nil
	end
	local rel = solveRel(model, root)
	local low = nil
	for _, name in ipairs({ "LeftFoot", "RightFoot" }) do
		local foot = model:FindFirstChild(name)
		local cf = foot and rel[foot]
		if cf then
			local y = lowestY(cf, foot.Size)
			low = low and math.min(low, y) or y
		end
	end
	if not low or -low < 0.5 then
		return nil
	end
	return -low
end

-- rig de um avatar R15 que já existe (clone do molde ou o 🎓 professor montado pelo servidor). nil se não servir
function VillageFolk.AvatarRig(model)
	local root = model:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return nil
	end
	local joints, base = {}, {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") then
			for key, name in pairs(R15) do
				if d.Name == name then
					joints[key] = d
					base[key] = d.C0
				end
			end
		end
	end
	for name in pairs(JOINTS) do
		if not joints[name] then
			return nil
		end
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	local rootH = VillageFolk.AvatarRootHeight(model) or model:GetAttribute("RootH") or (hum and hum.HipHeight + root.Size.Y / 2) or 3
	-- quadril até a raiz (sentado, o quadril fica no assento)
	local rel = solveRel(model, root)
	local hipCF = joints.LH.Part0 and rel[joints.LH.Part0]
	local hipToRoot = hipCF and -(hipCF * joints.LH.C0).Position.Y or root.Size.Y / 2
	hipToRoot = math.clamp(hipToRoot, 0.4, rootH)
	local head = model:FindFirstChild("Head")
	return {
		Model = model,
		Root = root,
		Head = head,
		-- a cabeça em relação à raiz, pelas juntas (o retrato do tutorial mira nela antes do mundo montar o boneco)
		HeadRel = head and rel[head] or nil,
		Joints = joints,
		Base = base,
		Scale = rootH / 3,
		Avatar = true,
		RootH = rootH,
		HipToRoot = hipToRoot,
		-- comprimento da perna (quadril até a sola): sentado na areia o pé não pode entrar no chão
		LegLen = math.max(0.5, rootH - hipToRoot),
		Hand = model:FindFirstChild("RightHand"),
	}
end

-- rig de um boneco que já existe (o 🎓 Professor vem montado do servidor): acha as juntas pelo nome
function VillageFolk.RigFrom(model)
	if model:FindFirstChild("LowerTorso") then
		return VillageFolk.AvatarRig(model) -- (2026-10: o professor virou o avatar do dono do jogo)
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if not (root and model:FindFirstChild("Torso")) then
		return nil
	end
	local s = model:GetAttribute("Scale") or 1
	local joints, base = {}, {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") and JOINTS[d.Name] then
			joints[d.Name] = d
			base[d.Name] = CFrame.new(JOINTS[d.Name][1] * s)
		end
	end
	for name in pairs(JOINTS) do
		if not joints[name] then
			return nil
		end
	end
	return { Model = model, Root = root, Head = model:FindFirstChild("Head"), Joints = joints, Base = base, Scale = s }
end

-- clona o molde de um avatar e põe em pé no chão `cfGround` (sem colisão, só a raiz ancorada). nil se não servir.
-- (Também serve para copiar um avatar que já está no mundo — o 🎓 professor no retrato do tutorial: botões, plaquinhas
-- e scripts dele não vêm junto)
function VillageFolk.FromAvatar(template, parent, cfGround)
	local archivable = template.Archivable
	template.Archivable = true
	local model = template:Clone()
	template.Archivable = archivable
	if not model then
		return nil
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
			d.Anchored = d.Name == "HumanoidRootPart"
		elseif d:IsA("LuaSourceContainer") or d:IsA("ProximityPrompt") or d:IsA("BillboardGui") then
			d:Destroy()
		end
	end
	local rig = VillageFolk.AvatarRig(model)
	if not rig then
		model:Destroy()
		return nil
	end
	model.PrimaryPart = rig.Root
	rig.Root.CFrame = cfGround * CFrame.new(0, rig.RootH, 0)
	model.Parent = parent
	return rig
end

---------------------------------------------------------------- poses
local function lerp(a, b, t)
	return a + (b - a) * t
end

-- estado (pesos 0..1 e números):
--   Walk, Run (pesos) + Phase (fase do passo) · Sit (sentado no banco) · SitGround (sentado no chão/beira)
--   Wave (acenando) · Talk (gesticulando) · Sweep · Garden (agachado mexendo na terra) · Strum (violão)
--   Fish (segurando a vara) · Throw (0..1 arremesso) · Clap · LookYaw/LookPitch (cabeça)
function VillageFolk.Pose(rig, t, st)
	local J, B = rig.Joints, rig.Base
	local walk, run = st.Walk or 0, st.Run or 0
	local ph = st.Phase or 0
	local sw = math.sin(ph)
	local amp = 0.55 * walk + 1.0 * run
	local la, ra = sw * amp, -sw * amp
	local lz, rz = 0.04, 0.04
	local ll, rl = -sw * amp, sw * amp
	local bob = math.abs(math.cos(ph)) * (0.1 * walk + 0.22 * run)
	local lean = 0.04 * walk + 0.22 * run
	local rootY, rootRoll = bob, 0
	local yaw, pitch, tilt = st.LookYaw or 0, st.LookPitch or 0, 0
	-- respirando parado
	local idle = math.max(0, 1 - walk - run)
	rootY += math.sin(t * 1.9) * 0.025 * idle
	la += math.sin(t * 1.3) * 0.03 * idle
	ra -= math.sin(t * 1.3 + 0.5) * 0.03 * idle

	local sit = st.Sit or 0
	if sit > 0 then
		ll, rl = lerp(ll, 1.57, sit), lerp(rl, 1.57, sit)
		la, ra = lerp(la, 0.35, sit), lerp(ra, 0.35, sit)
		lean = lerp(lean, -0.05, sit)
	end
	local sg = st.SitGround or 0
	if sg > 0 then
		ll, rl = lerp(ll, 1.35, sg), lerp(rl, 1.25, sg)
		la, ra = lerp(la, -0.3, sg), lerp(ra, -0.3, sg)
		lz, rz = lerp(lz, 0.25, sg), lerp(rz, 0.25, sg)
		lean = lerp(lean, -0.25, sg)
	end
	local talk = st.Talk or 0
	if talk > 0 then
		la = lerp(la, 0.35 + math.sin(t * 3.1) * 0.25, talk)
		ra = lerp(ra, 0.5 + math.sin(t * 2.3 + 1) * 0.35, talk)
		rz = lerp(rz, 0.25 + math.sin(t * 2.7) * 0.15, talk)
		pitch += math.sin(t * 2.1) * 0.08 * talk
		yaw += math.sin(t * 0.9) * 0.15 * talk
	end
	local wave = st.Wave or 0
	if wave > 0 then
		ra = lerp(ra, 0.15, wave)
		rz = lerp(rz, 2.6 + math.sin(t * 9) * 0.35, wave)
		tilt += 0.08 * wave
	end
	local clap = st.Clap or 0
	if clap > 0 then
		local c = math.abs(math.sin(t * 7))
		la, ra = lerp(la, 0.9, clap), lerp(ra, 0.9, clap)
		lz, rz = lerp(lz, -0.35 + c * 0.35, clap), lerp(rz, -0.35 + c * 0.35, clap)
	end
	local sweep = st.Sweep or 0
	if sweep > 0 then
		local s2 = math.sin(t * 3.2)
		la, ra = lerp(la, 0.8, sweep), lerp(ra, 0.65, sweep)
		lz, rz = lerp(lz, -0.35 + s2 * 0.25, sweep), lerp(rz, 0.35 + s2 * 0.25, sweep)
		rootRoll += s2 * 0.06 * sweep
		pitch -= 0.25 * sweep
	end
	local garden = st.Garden or 0
	if garden > 0 then
		local g = math.sin(t * 4)
		lean = lerp(lean, 0.55, garden)
		rootY = lerp(rootY, -0.7, garden)
		ll, rl = lerp(ll, 0.7, garden), lerp(rl, 0.2, garden)
		la, ra = lerp(la, 1.0 + g * 0.2, garden), lerp(ra, 1.1 - g * 0.25, garden)
		pitch -= 0.3 * garden
	end
	local strum = st.Strum or 0
	if strum > 0 then
		ra = lerp(ra, 0.7 + math.sin(t * 11) * 0.25, strum)
		rz = lerp(rz, -0.45, strum)
		la = lerp(la, 0.9, strum)
		lz = lerp(lz, -0.5, strum)
		yaw += math.sin(t * 2.5) * 0.12 * strum
		rootY += math.abs(math.sin(t * 5)) * 0.06 * strum
	end
	local fish = st.Fish or 0
	if fish > 0 then
		la, ra = lerp(la, 0.75, fish), lerp(ra, 0.85 + math.sin(t * 0.8) * 0.06, fish)
		lz = lerp(lz, -0.3, fish)
	end
	local throw = st.Throw or 0
	if throw > 0 then
		-- 0..0.5 puxa o braço para trás, 0.5..1 joga para a frente
		local k = st.ThrowT or 0
		local arm = k < 0.5 and lerp(0, -2.2, k / 0.5) or lerp(-2.2, 1.4, (k - 0.5) / 0.5)
		ra = lerp(ra, arm, throw)
		lean = lerp(lean, k < 0.5 and -0.1 or 0.18, throw)
	end

	J.Root.C0 = B.Root * CFrame.new(0, rootY * rig.Scale, 0) * CFrame.Angles(-lean, 0, rootRoll)
	J.Neck.C0 = B.Neck * CFrame.Angles(pitch, yaw, tilt)
	J.LS.C0 = B.LS * CFrame.Angles(la, 0, -lz)
	J.RS.C0 = B.RS * CFrame.Angles(ra, 0, rz)
	J.LH.C0 = B.LH * CFrame.Angles(ll, 0, -0.02)
	J.RH.C0 = B.RH * CFrame.Angles(rl, 0, 0.02)
	-- joelhos (só o avatar R15 tem): a canela fica para baixo sentado no banco e dobra quando a perna vai para trás
	if J.LK and J.RK then
		J.LK.C0 = B.LK * CFrame.Angles(math.min(0, ll) * 0.9 - 1.57 * sit - 0.3 * garden, 0, 0)
		J.RK.C0 = B.RK * CFrame.Angles(math.min(0, rl) * 0.9 - 1.57 * sit, 0, 0)
	end
end

-- altura da raiz acima do chão para cada jeito de estar (o cliente põe o Root nesta altura)
function VillageFolk.RootHeight(rig, how, seatTop)
	local s = rig.Scale
	if rig.Avatar then
		-- avatar R15: em pé = altura do molde; sentado = quadril no assento (ou no chão)
		if how == "Sit" then
			return (seatTop or 2.2) + rig.HipToRoot
		elseif how == "SitGround" then
			-- pernas a ~77° (Pose): o pé desce cos(1,35) ≈ 0,22 do comprimento da perna abaixo do quadril
			return math.max(0.15, rig.LegLen * 0.22) + rig.HipToRoot
		end
		return rig.RootH
	end
	if how == "Sit" then
		return (seatTop or 2.2) + 1 * s
	elseif how == "SitGround" then
		return 1.15 * s
	end
	return 3 * s
end

return VillageFolk
