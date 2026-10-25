-- Pacote E: 🎃 HALLOWEEN (2026-10, pedido do dono: "outro cachorro mítico que faz clone, raridade Halloween, um
-- cachorro palhaço; faz dois clones que atacam com ele e, se ele usar uma habilidade, eles usam junto").
-- SPOOKY CLOWN: macacão roxo de bolinhas laranja, rosto pintado de branco com losangos pretos nos olhos, nariz
-- vermelho redondo, peruca verde-limão dos lados, chapéu de cone listrado laranja/preto com pompom, gola de babado
-- (laranja/preto/roxo), sapatões vermelhos e pompom laranja no rabo. Elementos: Sombra + Fogo (abóbora).
-- Os 2 clones: server/Services/CloneService.lua. Habilidades: SpecialsPacks/Skills_Halloween.lua.
local C = Color3.fromRGB
local PI = math.pi

local WHITE = C(250, 248, 244)
local BLACK = C(28, 22, 32)
local ORANGE = C(255, 135, 30)
local PURPLE = C(118, 52, 170)
local LIME = C(150, 235, 60)
local RED = C(225, 30, 45)

local FABRIC = Enum.Material.Fabric
local SMOOTH = Enum.Material.SmoothPlastic

local function V(x, y, z)
	return Vector3.new(x, y, z)
end

local function CF(x, y, z)
	return CFrame.new(x, y, z)
end

local function ANG(x, y, z)
	return CFrame.Angles(x, y, z)
end

-- medidas da cabeça (igual ao DogBuilder; Blocky2 = cabeça um pouco mais alta)
local function headDims(look)
	local H = look.head
	local hs = H.size
	return hs, 0.95 * (H.w or 1) * hs / 2, (look.V2 and 1.0 or 0.9) * (H.tall or 1) * hs / 2, (H.long or 1) * hs / 2
end

-- CFrame de uma peça já montada no espaço (em unidades) de `seg`
local function localOf(b, seg, part)
	local rel = seg.CFrame:Inverse() * part.CFrame
	return CFrame.new(rel.Position / b.S) * rel.Rotation
end

local function clown(b, ctx)
	local model, torso, look, B = ctx.Model, ctx.Torso, ctx.Look, ctx.Body
	local head = model:FindFirstChild("Head1")
	if head then
		local hs, ax, ay, az = headDims(look)
		-- 🔴 nariz de palhaço: bola vermelha brilhante por cima do nariz
		local nose = model:FindFirstChild("Nariz")
		if nose then
			local at = localOf(b, head, nose)
			b:E(head, "NarizPalhaco", V(0.42, 0.4, 0.4) * hs, RED, CF(at.Position.X, at.Position.Y, at.Position.Z - 0.04 * hs), SMOOTH)
			b:E(head, "NarizBrilho", V(0.12, 0.1, 0.06) * hs, C(255, 210, 210), CF(at.Position.X + 0.08 * hs, at.Position.Y + 0.1 * hs, at.Position.Z - 0.22 * hs), SMOOTH)
		end
		-- ◆ losangos pretos em cima e embaixo de cada olho (pintura de palhaço)
		local gap, ey = 0.21 * hs, 0.08 * hs
		local u = 1 - (gap / ax) ^ 2 - (ey / ay) ^ 2
		local ez = -az * math.sqrt(math.max(u, 0.03)) - 0.01 * hs
		for _, side in ipairs({ -1, 1 }) do
			b:K(head, "Losango", V(0.11, 0.11, 0.04) * hs, BLACK, CF(side * gap, ey + 0.2 * hs, ez + 0.02 * hs) * ANG(0, 0, PI / 4), SMOOTH)
			b:K(head, "Losango", V(0.1, 0.1, 0.04) * hs, BLACK, CF(side * gap, ey - 0.19 * hs, ez + 0.03 * hs) * ANG(0, 0, PI / 4), SMOOTH)
		end
		-- 🟢 peruca encaracolada dos dois lados (cachos em volta das orelhas)
		local rng = Random.new(31)
		for _, side in ipairs({ -1, 1 }) do
			for i = 1, 7 do
				local a = (i - 1) / 6 * PI * 0.9 - PI * 0.15
				local r = rng:NextNumber(0.24, 0.32) * hs
				local p = CF(side * (ax * 0.92 + math.cos(a) * 0.12 * hs), ay * 0.2 + math.sin(a) * 0.32 * hs, 0.06 * hs + rng:NextNumber(-0.1, 0.12) * hs)
				b:E(head, "Peruca", V(r, r, r), i % 3 == 0 and C(110, 205, 45) or LIME, p, FABRIC)
			end
		end
		-- 🎉 chapéu de cone listrado laranja/preto, torto para o lado, com pompom branco
		local hat = CF(0.05 * hs, ay * 0.86, 0.04 * hs) * ANG(0.12, 0, -0.32)
		local layers = 5
		for i = 0, layers - 1 do
			local k = 1 - i / layers
			local w = (0.62 * k + 0.08) * hs
			b:E(head, "Chapeu", V(w, 0.16 * hs, w), i % 2 == 0 and ORANGE or BLACK, hat * CF(0, (0.06 + i * 0.13) * hs, 0), FABRIC)
		end
		b:E(head, "Pompom", V(0.22, 0.22, 0.22) * hs, WHITE, hat * CF(0, (0.12 + layers * 0.13) * hs, 0), FABRIC)
		b:E(head, "ChapeuElastico", V(ax * 2.02, 0.03 * hs, az * 1.6), BLACK, CF(0, -ay * 0.35, 0.05 * hs) * ANG(0, 0, 0.12), SMOOTH)
	end
	-- 🎪 gola de babado embaixo da cabeça (3 cores revezando, inclinada como o pescoço)
	if head then
		local hs, ax, ay, az = headDims(look)
		local base = CF(0, -ay * 0.95, az * 0.35) * ANG(-0.35, 0, 0)
		local n = 14
		local colors = { ORANGE, WHITE, PURPLE }
		for i = 0, n - 1 do
			local a = i / n * PI * 2
			local cf = base * ANG(0, a, 0) * CF(0, 0, -ax * 0.95)
			b:E(head, "Babado", V(0.5, 0.26, 0.42) * hs, colors[i % 3 + 1], cf * ANG(0.35, 0, 0), FABRIC)
		end
	end
	-- 3 botões-pompom na frente do macacão
	for i = 0, 2 do
		b:E(torso, "Botao", V(0.2, 0.2, 0.14), i == 1 and LIME or ORANGE, CF(0, -B.h * 0.12 - i * 0.16, -B.len * 0.45 + i * 0.05) * ANG(-0.4, 0, 0), FABRIC)
	end
	-- 🎃 abóbora pequena pendurada no cinto (lado direito)
	local pumpkin = CF(B.w * 0.5, -B.h * 0.18, B.len * 0.1)
	b:E(torso, "Abobora", V(0.42, 0.36, 0.42), ORANGE, pumpkin, SMOOTH)
	b:K(torso, "AboboraCabo", V(0.06, 0.12, 0.06), C(70, 120, 40), pumpkin * CF(0, 0.22, 0), SMOOTH)
	for _, side in ipairs({ -1, 1 }) do
		b:K(torso, "AboboraOlho", V(0.04, 0.08, 0.08), BLACK, pumpkin * CF(0.2, 0.05, side * 0.08) * ANG(PI / 4, 0, 0), SMOOTH)
	end
	b:K(torso, "AboboraBoca", V(0.04, 0.05, 0.2), BLACK, pumpkin * CF(0.2, -0.08, 0), SMOOTH)
	-- pompom laranja na ponta do rabo
	local tip
	for _, p in ipairs(model:GetChildren()) do
		if p:IsA("BasePart") and string.match(p.Name, "^Rabo%d+$") then
			if not tip or p.Name > tip.Name then
				tip = p
			end
		end
	end
	if tip then
		b:E(tip, "RaboPompom", V(0.38, 0.38, 0.38), ORANGE, CF(0, 0, -tip.Size.Z / b.S * 0.5), FABRIC)
	end
end

local Species = {}

Species.clown_dog = {
	Name = "Spooky Clown",
	Rarity = "Halloween",
	Role = "Trickster",
	Special = "SK_clown_dog_2",
	Clones = 2, -- 🤡 os 2 clones que andam e lutam com ele (server/Services/CloneService)
	-- ataque um pouco menor: os 2 clones batem junto (CloneService)
	Stats = { HP = 1.2, Atk = 0.85, Speed = 19 },
	Look = {
		scale = 1.0,
		main = PURPLE,
		second = C(90, 36, 135),
		belly = ORANGE,
		eye = C(30, 24, 30),
		body = { len = 2.7, w = 1.4, h = 1.35, chest = 1.08 },
		legs = { len = 1.0, thick = 0.4, socks = WHITE, sockH = 0.3, paw = RED },
		head = {
			size = 1.6,
			snout = 0.7,
			lift = 0.42,
			cap = WHITE, -- rosto pintado de branco
			muzzle = WHITE,
			blaze = WHITE,
			nose = RED,
			noseW = 1.2,
			tongue = true,
			eyeSize = 1.12,
		},
		mood = "happy",
		ears = "floppy",
		earColor = ORANGE,
		earInner = WHITE,
		tail = "curl",
		tailColor = PURPLE,
		tailTip = ORANGE,
		extras = {
			spots = ORANGE,
			spotCount = 16,
			spotSeed = 13,
		},
		build = clown,
	},
}

return {
	Species = Species,
	Order = { "clown_dog" },
}
