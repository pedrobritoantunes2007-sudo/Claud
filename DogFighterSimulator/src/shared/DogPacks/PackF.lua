-- Pacote F: 🎟️ EXCLUSIVOS DO PASSE DE TEMPORADA (2026-10-25, pedido do dono: "a premium inclui um cachorro exclusivo
-- no nível 30"). Exclusive = true: nunca aparece selvagem, na roleta, em ovo nem em compra aleatória (só no nível 30
-- da trilha premium — Shared/SeasonPass); não conta para "completar raridade" no Dex (Shared/DexRewards).
-- 🌌 AURORA PUP (Temporada 1): filhote fofo de pelo branco-gelo com mechas verde-água, asas de penas nas cores da
-- aurora boreal (verde-água → azul → rosa), coroinha de 3 estrelas de luz e um laço de aurora na ponta do rabo.
-- Elementos: Luz + Gelo + Voo. Poderes: os da fênix de gelo (SK_frost_phoenix_*) com nome e cor de aurora.
local C = Color3.fromRGB

local MINT = C(120, 245, 220)
local SKY = C(110, 170, 255)
local PINK = C(255, 140, 220)
local WHITE = C(246, 252, 255)
local NEON = Enum.Material.Neon

local function V(x, y, z)
	return Vector3.new(x, y, z)
end
local function CF(x, y, z)
	return CFrame.new(x, y, z)
end
local function ANG(x, y, z)
	return CFrame.Angles(x, y, z)
end

local function aurora(b, ctx)
	local model, look = ctx.Model, ctx.Look
	local head = model:FindFirstChild("Head1")
	if head then
		local hs = look.head.size
		-- coroinha: 3 estrelas de luz (losangos) em cima da cabeça
		for i = -1, 1 do
			local h = (0.26 - math.abs(i) * 0.06) * hs
			b:K(head, "EstrelaAurora", V(h, h, 0.06 * hs), i == 0 and WHITE or (i < 0 and MINT or PINK), CF(i * 0.2 * hs, 0.55 * hs + h * 0.3, 0.02 * hs) * ANG(0, 0, math.pi / 4), NEON)
		end
	end
	-- laço de aurora na ponta do rabo (3 fitas de luz)
	local tip
	for _, p in ipairs(model:GetChildren()) do
		if p:IsA("BasePart") and string.match(p.Name, "^Rabo%d+$") then
			if not tip or p.Name > tip.Name then
				tip = p
			end
		end
	end
	if tip then
		for k, col in ipairs({ MINT, SKY, PINK }) do
			b:K(tip, "FitaAurora", V(0.08, 0.5, 0.18), col, CF(0, 0, -tip.Size.Z / b.S * 0.5) * ANG(0, 0, (k - 2) * 0.6) * CF(0, 0.25, 0), NEON)
		end
	end
end

local Species = {}

Species.aurora_pup = {
	Name = "Aurora Pup",
	Rarity = "Mythic",
	Role = "Season",
	Exclusive = true, -- 🎟️ só no nível 30 premium do Passe de Temporada (Temporada 1)
	Special = "C_GlacialRebirth",
	Stats = { HP = 1.35, Atk = 1.45, Speed = 20 },
	Look = {
		scale = 1.3,
		main = WHITE,
		second = MINT,
		belly = C(255, 255, 255),
		eye = C(120, 230, 255),
		body = { len = 2.6, w = 1.25, h = 1.25, chest = 1.1 },
		legs = { len = 0.95, thick = 0.32, socks = MINT, sockH = 0.22, paw = PINK },
		head = { size = 1.5, snout = 0.85, lift = 0.5, muzzle = C(255, 255, 255), nose = C(90, 120, 200), tongue = true, eyeSize = 1.15 },
		mood = "happy",
		ears = "swept",
		earColor = MINT,
		earInner = PINK,
		tail = "fan",
		tailColor = WHITE,
		tailTip = MINT,
		wingSize = 1.3,
		wingColors = { MINT, SKY, PINK },
		extras = {
			wings = "feather",
			crest = true,
			float = 1.5,
			eyeGlow = true,
			aura = C(140, 255, 225),
		},
		build = aurora,
	},
}

return {
	Species = Species,
	Order = { "aurora_pup" },
}
