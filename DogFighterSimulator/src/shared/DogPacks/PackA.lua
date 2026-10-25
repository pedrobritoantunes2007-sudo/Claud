-- Pacote A: 14 cachorros Comuns / Incomuns / Raros.
-- Comuns e Incomuns são raças reais e reconhecíveis (Beagle, Corgi, Salsicha, Chihuahua, Pastor Alemão,
-- Border Collie, São Bernardo, Akita, Galgo). Os Raros já são exóticos e mudam a ANATOMIA:
-- cacto com braços de saguaro, abelha que flutua com asas de inseto, balão de festa torcido em gomos,
-- brinquedo de corda com chave nas costas e rabo de mola, cogumelo com chapéu gigante.
-- Geometria extra via Look.build(b, ctx) (ver DogBuilder): b:E/b:K/b:W/b:Seg/b:Tri/b:Triangle/b:Joint.
-- Não requer DogData/DogBuilder (evita ciclo). Poderes "A_*" ficam em Server/Services/SpecialsPacks/PackA.
local C = Color3.fromRGB
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local PI = math.pi

local WHITE = C(252, 250, 246)
local _DARK = C(30, 26, 28)
local _GOLD = C(245, 195, 70)

---------------------------------------------------------------- utilidades de construção
local function glow(part, color)
	part.Material = Enum.Material.Neon
	if color then
		part.Color = color
	end
	part.CastShadow = false
	return part
end

-- ponto na superfície aproximada do tronco (igual ao DogBuilder): a = ângulo em volta de Z (0 = topo)
local function bodyPoint(B, a, fz, push)
	if B.Surf then -- Blocky2: tronco de blocos (o DogBuilder empresta a função dele)
		local cf = B.Surf(B, a, fz, push)
		return cf.Position, cf.LookVector
	end
	local rx, ry = B.w * 0.5, B.h * 0.5
	local z = fz * B.len
	local k = math.sqrt(math.max(0.05, 1 - (2 * fz) ^ 2))
	local p = V(math.sin(a) * rx * k, math.cos(a) * ry * k + B.h * 0.04, z)
	local n = V(p.X / (rx * rx), (p.Y - B.h * 0.04) / (ry * ry), z / (B.len * B.len * 0.25)).Unit
	return p + n * (push or 0), n
end

-- dimensões da cabeça como o DogBuilder calcula (meios-eixos)
local function headAxes(look)
	local H = look.head
	local hs = H.size
	-- Blocky2 (look.V2): a cabeça é um pouco mais alta (1.0 em vez de 0.9), igual ao DogBuilder
	return hs, 0.95 * (H.w or 1) * hs / 2, (look.V2 and 1.0 or 0.9) * (H.tall or 1) * hs / 2, 1.0 * (H.long or 1) * hs / 2
end

-- peças soldadas num segmento (o Builder parenta tudo direto no Model)
local function weldedTo(model, segment, names)
	local list = {}
	for _, p in ipairs(model:GetChildren()) do
		if p:IsA("BasePart") and (not names or names[p.Name]) then
			local w = p:FindFirstChildOfClass("Weld")
			if w and w.Part0 == segment then
				table.insert(list, { Part = p, Weld = w })
			end
		end
	end
	return list
end

-- espinho fino (agulha) saindo de um ponto na direção da normal
local function needle(b, parent, p, n, len, color)
	return b:Seg(parent, "A_Espinho", p, p + n * len, 0.035, 0.035, color, Enum.Material.SmoothPlastic)
end

local Pack = {}

Pack.Species = {
	------------------------------------------------------------ COMUNS
	beagle = {
		Name = "Beagle",
		Rarity = "Common",
		Role = "Tracker",
		Special = "A_ScentHowl",
		Stats = { HP = 1.05, Atk = 1, Speed = 17 },
		Look = {
			scale = 0.9,
			main = C(198, 128, 60),
			second = C(40, 33, 30),
			belly = WHITE,
			eye = C(60, 34, 20),
			body = { len = 2.8, w = 1.35, h = 1.3, saddle = C(40, 33, 30) },
			legs = { len = 0.85, thick = 0.36, socks = WHITE, sockH = 0.5 },
			head = { size = 1.55, snout = 0.85, snoutW = 1.05, lift = 0.4, muzzle = WHITE, blaze = WHITE, eyeSize = 1.12 },
			mood = "happy",
			ears = "long",
			earSize = 1.08,
			earColor = C(176, 108, 48),
			tail = "thin",
			tailSize = 1.1,
			tailTip = WHITE,
			extras = { collar = C(60, 140, 230) },
		},
	},
	corgi = {
		Name = "Corgi",
		Rarity = "Common",
		Role = "Bouncy",
		Special = "A_CorgiBounce",
		Stats = { HP = 1.15, Atk = 0.95, Speed = 15 },
		Look = {
			scale = 0.85,
			main = C(230, 142, 60),
			second = C(205, 118, 45),
			belly = WHITE,
			eye = C(40, 26, 18),
			body = { len = 2.9, w = 1.45, h = 1.25, chest = 1.1, haunch = 1.08 },
			legs = { len = 0.42, thick = 0.36, socks = WHITE, sockH = 0.6 },
			head = { size = 1.55, snout = 0.75, lift = 0.55, blaze = WHITE, muzzle = WHITE, cheeks = WHITE, eyeSize = 1.1 },
			mood = "happy",
			ears = "big",
			earSize = 1.02,
			earInner = C(240, 170, 160),
			tail = "stub",
			tailColor = WHITE,
			extras = { ruff = WHITE, collar = C(70, 180, 95) },
			-- o famoso bumbum de pão fofinho
			build = function(b, ctx)
				local B = ctx.Body
				b:E(ctx.Torso, "A_Bumbum", V(B.w * 0.98, B.h * 0.82, B.len * 0.3), C(255, 246, 232), CF(0, B.h * 0.02, B.len * 0.42))
				for _, side in ipairs({ -1, 1 }) do
					b:E(ctx.Torso, "A_Bumbum", V(B.w * 0.5, B.h * 0.7, B.len * 0.26), C(255, 246, 232), CF(side * B.w * 0.24, -B.h * 0.06, B.len * 0.44))
				end
			end,
		},
	},
	salsicha = {
		Name = "Dachshund",
		Rarity = "Common",
		Role = "Shooter",
		Special = "A_SausageRoll",
		Stats = { HP = 0.95, Atk = 1.05, Speed = 16 },
		Look = {
			scale = 0.85,
			main = C(52, 36, 32),
			second = C(52, 36, 32),
			belly = C(196, 112, 58),
			eye = C(40, 25, 18),
			body = { len = 3.9, w = 1.05, h = 1.05, chest = 1.14, haunch = 0.9 },
			legs = { len = 0.36, thick = 0.3, socks = C(196, 112, 58), sockH = 0.55 },
			head = {
				size = 1.38,
				snout = 1.1,
				snoutW = 0.75,
				long = 1.1,
				lift = 0.45,
				brows = C(196, 112, 58),
				muzzle = C(196, 112, 58),
				neckW = 0.85,
			},
			mood = "happy",
			ears = "long",
			earSize = 1.12,
			tail = "thin",
			extras = { collar = C(230, 60, 60) },
		},
	},
	chihuahua = {
		Name = "Chihuahua",
		Rarity = "Common",
		Role = "Noisy",
		Special = "A_YapBlast",
		Stats = { HP = 0.8, Atk = 1.05, Speed = 19 },
		Look = {
			scale = 0.62,
			main = C(232, 194, 138),
			second = C(214, 166, 104),
			belly = C(250, 236, 210),
			eye = C(30, 22, 20),
			body = { len = 2.2, w = 1.05, h = 1.1, haunch = 0.9 },
			legs = { len = 0.95, thick = 0.24 },
			head = {
				size = 1.8,
				snout = 0.4,
				snoutW = 0.72,
				lift = 0.5,
				w = 1.05,
				tall = 1.05,
				eyeSize = 1.35,
				eyeGap = 0.24,
				muzzle = C(250, 236, 210),
				neckW = 0.65,
			},
			mood = "happy",
			eyes = "cute",
			ears = "big",
			earSize = 1.12,
			earInner = C(245, 170, 165),
			tail = "curl",
			tailSize = 0.8,
			extras = { collar = C(240, 110, 190) },
		},
	},

	------------------------------------------------------------ INCOMUNS
	pastor_alemao = {
		Name = "German Shepherd",
		Rarity = "Uncommon",
		Role = "Police",
		Special = "A_K9Takedown",
		Stats = { HP = 1.1, Atk = 1.1, Speed = 18 },
		Look = {
			scale = 1.15,
			main = C(200, 140, 72),
			second = C(36, 30, 30),
			belly = C(224, 176, 112),
			eye = C(50, 30, 20),
			body = { len = 3.3, w = 1.4, h = 1.45, chest = 1.12, haunch = 0.88, saddle = C(36, 30, 30) },
			legs = { len = 1.1, thick = 0.38, hind = 1.05 },
			head = {
				size = 1.52,
				snout = 1.05,
				snoutW = 0.85,
				long = 1.05,
				lift = 0.65,
				muzzle = C(40, 32, 30),
				bridge = C(70, 52, 40),
				brows = C(224, 176, 112),
			},
			mood = "calm",
			ears = "pointy",
			earSize = 1.3,
			earColor = C(190, 130, 65),
			tail = "fluffy",
			tailColor = C(70, 52, 40),
			tailFeather = C(200, 140, 72),
			extras = {},
			-- colete K9
			build = function(b, ctx)
				local B, torso = ctx.Body, ctx.Torso
				local vest = C(28, 36, 62)
				b:E(torso, "A_Colete", V(B.w * 1.08, B.h * 0.9, B.len * 0.4), vest, CF(0, B.h * 0.1, -B.len * 0.06), Enum.Material.Fabric)
				for _, side in ipairs({ -1, 1 }) do
					b:K(
						torso,
						"A_ColetePlaca",
						V(0.06, B.h * 0.3, B.len * 0.18),
						C(255, 210, 40),
						CF(side * B.w * 0.535, B.h * 0.15, -B.len * 0.06),
						Enum.Material.SmoothPlastic
					)
				end
				b:E(torso, "A_ColeteFaixa", V(B.w * 1.1, 0.16, B.len * 0.41), C(200, 205, 215), CF(0, B.h * 0.48, -B.len * 0.06), Enum.Material.Metal)
			end,
		},
	},
	border_collie = {
		Name = "Border Collie",
		Rarity = "Uncommon",
		Role = "Athlete",
		Special = "A_Frisbee",
		Stats = { HP = 1, Atk = 1.1, Speed = 20 },
		Look = {
			scale = 1.05,
			main = C(32, 30, 34),
			second = C(32, 30, 34),
			belly = WHITE,
			eye = C(70, 45, 25),
			body = { len = 3.0, w = 1.3, h = 1.3 },
			legs = { len = 1.05, thick = 0.32, socks = WHITE, sockH = 0.45, feather = C(60, 58, 64) },
			head = { size = 1.5, snout = 0.9, snoutW = 0.85, lift = 0.5, blaze = WHITE, muzzle = WHITE, eyeSize = 1.1 },
			mood = "happy",
			ears = "semi",
			earSize = 1.08,
			tail = "fluffy",
			tailTip = WHITE,
			tailFeather = C(70, 68, 74),
			extras = { ruff = WHITE },
			-- bandana vermelha no pescoço
			build = function(b, ctx)
				local B, torso = ctx.Body, ctx.Torso
				local red = C(215, 45, 50)
				local y, z = B.h * 0.38, -B.len * 0.43
				local tip = V(0, -B.h * 0.32, z - 0.42)
				b:Triangle(torso, "A_Bandana", V(-0.62, y, z), V(0.62, y, z), tip, 0.08, red, Enum.Material.Fabric)
				b:E(torso, "A_BandanaNo", V(1.25, 0.34, 0.75), red, CF(0, y + 0.02, z + 0.12), Enum.Material.Fabric)
				for i = -1, 1 do
					local p = V(i * 0.2, y, z):Lerp(tip, 0.35 + math.abs(i) * 0.05) + V(0, 0, -0.06)
					b:E(torso, "A_BandanaPinta", V(0.12, 0.12, 0.04), WHITE, CFrame.lookAt(p, p + V(0, 0.35, -1)), Enum.Material.SmoothPlastic)
				end
			end,
		},
	},
	sao_bernardo = {
		Name = "St. Bernard",
		Rarity = "Uncommon",
		Role = "Rescue",
		Special = "A_Avalanche",
		Stats = { HP = 1.35, Atk = 0.95, Speed = 14 },
		Look = {
			scale = 1.3,
			main = C(250, 246, 240),
			second = C(160, 72, 36),
			belly = C(252, 250, 246),
			eye = C(60, 35, 20),
			body = { len = 3.3, w = 1.75, h = 1.6, chest = 1.15, saddle = C(160, 72, 36) },
			legs = { len = 0.95, thick = 0.5 },
			head = {
				size = 1.6,
				snout = 0.75,
				snoutW = 1.3,
				lift = 0.4,
				w = 1.08,
				cap = C(160, 72, 36),
				blaze = WHITE,
				muzzle = WHITE,
				jowls = true,
				eyeSize = 0.95,
				neckW = 1.25,
			},
			mood = "calm",
			eyes = "cute",
			ears = "floppy",
			earColor = C(130, 58, 30),
			tail = "fluffy",
			tailColor = C(160, 72, 36),
			tailTip = WHITE,
			extras = { ruff = WHITE, collar = C(200, 40, 40), tag = false },
			-- barrilzinho de resgate pendurado na coleira
			build = function(b, ctx)
				local B, torso = ctx.Body, ctx.Torso
				local cf = CF(0, -B.h * 0.2, -B.len * 0.5) * ANG(0, PI / 2, 0)
				b:E(torso, "A_Barril", V(0.95, 0.62, 0.62), C(165, 105, 55), cf, Enum.Material.Wood)
				for _, x in ipairs({ -0.3, 0.3 }) do
					b:E(torso, "A_BarrilAro", V(0.1, 0.68, 0.68), C(90, 90, 98), cf * CF(x, 0, 0), Enum.Material.Metal)
				end
				b:E(torso, "A_BarrilTampa", V(0.12, 0.2, 0.2), C(90, 60, 35), cf * CF(0, 0.3, 0), Enum.Material.Wood)
			end,
		},
	},
	akita = {
		Name = "Akita",
		Rarity = "Uncommon",
		Role = "Guardian",
		Special = "A_GuardianStance",
		Stats = { HP = 1.2, Atk = 1.05, Speed = 16 },
		Look = {
			scale = 1.15,
			main = C(214, 120, 58),
			second = C(190, 100, 45),
			belly = WHITE,
			eye = C(40, 25, 18),
			body = { len = 3.0, w = 1.55, h = 1.45, chest = 1.1 },
			legs = { len = 1.0, thick = 0.44, socks = WHITE, sockH = 0.35 },
			head = {
				size = 1.55,
				snout = 0.75,
				snoutW = 1.05,
				w = 1.12,
				lift = 0.5,
				cheeks = WHITE,
				muzzle = WHITE,
				brows = WHITE,
				eyeSize = 1.0,
				neckW = 1.25,
			},
			mood = "calm",
			eyes = "bead",
			ears = "pointy",
			earSize = 0.85,
			tail = "curl",
			tailSize = 1.6,
			tailTip = WHITE,
			extras = { ruff = WHITE },
		},
	},
	galgo = {
		Name = "Greyhound",
		Rarity = "Uncommon",
		Role = "Sprinter",
		Special = "A_Slipstream",
		Stats = { HP = 0.9, Atk = 1.05, Speed = 24 },
		Look = {
			scale = 1.1,
			main = C(142, 146, 162),
			second = C(120, 124, 140),
			belly = C(214, 216, 224),
			eye = C(40, 30, 25),
			body = { len = 3.0, w = 1.0, h = 1.35, chest = 1.25, haunch = 0.72 },
			legs = { len = 1.65, thick = 0.24 },
			head = { size = 1.3, snout = 1.25, snoutW = 0.6, long = 1.15, lift = 0.75, neckW = 0.7, eyeSize = 1.0 },
			mood = "calm",
			ears = "rose",
			earSize = 0.9,
			tail = "thin",
			tailSize = 1.25,
			extras = { collar = C(240, 200, 60) },
			-- casaquinho de tricô listrado
			build = function(b, ctx)
				local B, torso = ctx.Body, ctx.Torso
				local red, cream = C(200, 50, 60), C(250, 235, 210)
				b:E(torso, "A_Casaco", V(B.w * 1.12, B.h * 0.82, B.len * 0.62), red, CF(0, B.h * 0.16, -B.len * 0.06), Enum.Material.Fabric)
				for i = -1, 1 do
					b:E(
						torso,
						"A_CasacoListra",
						V(B.w * 1.14, B.h * 0.84, 0.16),
						cream,
						CF(0, B.h * 0.16, -B.len * 0.06 + i * B.len * 0.18),
						Enum.Material.Fabric
					)
				end
			end,
		},
	},

	------------------------------------------------------------ RAROS
	cactus_dog = {
		Name = "Cactus Dog",
		Rarity = "Rare",
		Role = "Spiky",
		Special = "A_CactusVolley",
		Stats = { HP = 1.3, Atk = 1.05, Speed = 14 },
		Look = {
			scale = 1.05,
			main = C(82, 160, 72),
			second = C(52, 118, 52),
			belly = C(150, 205, 110),
			eye = C(30, 30, 30),
			body = { len = 2.8, w = 1.45, h = 1.55, chest = 1.05 },
			legs = { len = 0.75, thick = 0.42, noToes = true, paw = C(196, 105, 65) },
			head = { size = 1.5, snout = 0.6, snoutW = 1.0, lift = 0.5, muzzle = C(150, 205, 110), eyeSize = 1.2 },
			mood = "happy",
			eyes = "cute",
			ears = "none",
			tail = "cactus",
			extras = { noBelly = true },
			build = function(b, ctx)
				local B, torso, look = ctx.Body, ctx.Torso, ctx.Look
				local green, dark, spineC = look.main, look.second, C(250, 248, 220)
				-- gomos do cacto (linhas escuras ao longo do corpo)
				for _, a in ipairs({ -1.2, -0.6, 0, 0.6, 1.2 }) do
					local p1 = bodyPoint(B, a, -0.4, 0.02)
					local p2 = bodyPoint(B, a, 0, 0.04)
					local p3 = bodyPoint(B, a, 0.4, 0.02)
					b:Seg(torso, "A_Gomo", p1, p2, 0.06, 0.06, dark)
					b:Seg(torso, "A_Gomo", p2, p3, 0.06, 0.06, dark)
				end
				-- braços de saguaro saindo das laterais
				for _, side in ipairs({ -1, 1 }) do
					local z = -B.len * 0.05 * side
					local s0 = V(side * B.w * 0.42, B.h * 0.05, z)
					local elbow = V(side * (B.w * 0.5 + 0.75), B.h * 0.05, z)
					local tip = V(side * (B.w * 0.5 + 0.75), B.h * 0.5 + 1.0, z)
					b:Seg(torso, "A_Braco", s0, elbow, 0.26, 0.26, green)
					b:Seg(torso, "A_Braco", elbow, tip, 0.25, 0.25, green)
					b:E(torso, "A_BracoPonta", V(0.5, 0.5, 0.5), green, CF(tip))
					for k = 0, 3 do
						local p = elbow:Lerp(tip, k / 3)
						needle(b, torso, p + V(side * 0.22, 0, 0), V(side, 0.3, 0).Unit, 0.28, spineC)
						needle(b, torso, p + V(0, 0, -0.22), V(0, 0.3, -1).Unit, 0.28, spineC)
					end
				end
				-- espinhos pelo corpo
				local rng = Random.new(21)
				for _ = 1, 16 do
					local p, n = bodyPoint(B, rng:NextNumber(-1.9, 1.9), rng:NextNumber(-0.4, 0.4), 0)
					needle(b, torso, p, n, 0.32, spineC)
				end
				-- cabeça: flor no topo + "orelhas" de palma
				local head = ctx.Model:FindFirstChild("Head1")
				if head then
					local hs, ax, ay = headAxes(look)
					local top = V(0.12 * hs, ay * 0.95, 0.05 * hs)
					for i = 0, 4 do
						local a = i / 5 * PI * 2
						b:E(head, "A_Petala", V(0.32, 0.1, 0.2) * hs, C(255, 110, 170), CF(top) * ANG(0, a, 0) * CF(0.17 * hs, 0, 0) * ANG(0, 0, 0.35))
					end
					b:E(head, "A_Miolo", V(0.18, 0.12, 0.18) * hs, C(255, 220, 60), CF(top + V(0, 0.05 * hs, 0)))
					for _, side in ipairs({ -1, 1 }) do
						local cf = CF(side * ax * 0.75, ay * 0.75, 0.05 * hs) * ANG(0, 0, -side * 0.45)
						b:E(head, "A_Palma", V(0.16, 0.62, 0.48) * hs, green, cf * CF(0, 0.22 * hs, 0))
						needle(b, head, (cf * CF(side * 0.06 * hs, 0.38 * hs, 0)).Position, V(side, 0.6, 0).Unit, 0.2, spineC)
						needle(b, head, (cf * CF(side * 0.06 * hs, 0.2 * hs, -0.12 * hs)).Position, V(side, 0, -0.5).Unit, 0.2, spineC)
					end
					for _, p in ipairs({ V(-0.3, 0.35, -0.2), V(0.32, 0.2, -0.25), V(0, 0.45, 0.25) }) do
						needle(b, head, p * hs, p.Unit, 0.22, spineC)
					end
				end
				-- rabo: um gomo de cacto em pé (balança com o Animator)
				local tail = ctx.Model:FindFirstChild("TailBase")
				if tail then
					b:Seg(tail, "A_RaboCacto", V(0, 0, 0), V(0, 0.75, 0.25), 0.22, 0.22, green)
					b:E(tail, "A_RaboCacto", V(0.44, 0.44, 0.44), green, CF(0, 0.8, 0.27))
					needle(b, tail, V(0.2, 0.45, 0.15), V(1, 0.2, 0.2).Unit, 0.22, spineC)
					needle(b, tail, V(-0.2, 0.45, 0.15), V(-1, 0.2, 0.2).Unit, 0.22, spineC)
					b:E(tail, "A_RaboFlor", V(0.22, 0.12, 0.22), C(255, 110, 170), CF(0, 1.02, 0.28))
				end
			end,
		},
	},
	bee_dog = {
		Name = "Bee Dog",
		Rarity = "Rare",
		Role = "Swarm",
		Special = "A_BeeSwarm",
		Stats = { HP = 0.95, Atk = 1.2, Speed = 19 },
		Look = {
			scale = 0.95,
			main = C(250, 200, 40),
			second = C(38, 32, 30),
			belly = C(255, 226, 110),
			eye = C(30, 24, 22),
			body = { len = 2.6, w = 1.65, h = 1.6, haunch = 1.12 },
			legs = { len = 0.7, thick = 0.28, color = C(38, 32, 30) },
			head = { size = 1.55, snout = 0.5, snoutW = 0.95, lift = 0.4, muzzle = C(255, 226, 110), eyeSize = 1.3 },
			mood = "happy",
			eyes = "cute",
			ears = "none",
			tail = "stinger",
			extras = { antenna = C(255, 220, 80), float = 0.9 },
			build = function(b, ctx)
				local B, torso, look = ctx.Body, ctx.Torso, ctx.Look
				local dark = look.second
				-- listras pretas em volta do corpo
				for i, z in ipairs({ -0.05, 0.38, 0.8 }) do
					local k = 1.05 - i * 0.04
					b:E(torso, "A_Listra", V(B.w * k * 1.0, B.h * k * 0.98, 0.34), dark, CF(0, B.h * 0.05, z), Enum.Material.SmoothPlastic)
				end
				-- asas de inseto em juntas WingL/WingR (o Animator bate as asas)
				local glass = C(220, 240, 255)
				for _, side in ipairs({ -1, 1 }) do
					local name = side < 0 and "WingL" or "WingR"
					local pivot = b:Pivot(name)
					b:Joint(name, torso, pivot, CF(side * B.w * 0.22, B.h * 0.48, -B.len * 0.08) * ANG(0, 0, side * 0.5), CF())
					local w1 = b:E(pivot, "A_Asa", V(2.1, 0.07, 1.1), glass, CF(side * 1.0, 0.15, 0.2) * ANG(0, side * 0.3, 0), Enum.Material.Glass)
					local w2 = b:E(pivot, "A_Asa", V(1.4, 0.06, 0.75), glass, CF(side * 0.7, 0.05, 0.75) * ANG(0, side * 0.75, 0), Enum.Material.Glass)
					w1.Transparency = 0.3
					w2.Transparency = 0.3
					b:Seg(pivot, "A_AsaVeia", V(0, 0, 0), V(side * 1.95, 0.18, 0.4), 0.035, 0.035, C(120, 130, 150))
					b:Seg(pivot, "A_AsaVeia", V(0, 0, 0.1), V(side * 1.2, 0.08, 1.05), 0.03, 0.03, C(120, 130, 150))
				end
				-- ferrão
				local tail = ctx.Model:FindFirstChild("TailBase")
				if tail then
					b:Seg(tail, "A_Ferrao", V(0, -0.1, 0.05), V(0, -0.25, 0.6), 0.2, 0.2, dark)
					b:Seg(tail, "A_Ferrao", V(0, -0.25, 0.55), V(0, -0.38, 1.05), 0.09, 0.09, dark)
					b:Seg(tail, "A_FerraoPonta", V(0, -0.36, 1.0), V(0, -0.45, 1.3), 0.035, 0.035, C(240, 240, 240))
				end
				-- topete fofinho e bochechas
				local head = ctx.Model:FindFirstChild("Head1")
				if head then
					local hs, ax, ay = headAxes(look)
					b:E(head, "A_Pelo", V(0.5, 0.3, 0.5) * hs, look.belly, CF(0, ay * 0.9, 0.08 * hs))
					for _, side in ipairs({ -1, 1 }) do
						b:E(
							head,
							"A_Bochecha",
							V(0.18, 0.12, 0.06) * hs,
							C(255, 140, 130),
							CF(side * ax * 0.62, -0.08 * hs, -0.36 * hs) * ANG(0, -side * 0.6, 0),
							Enum.Material.SmoothPlastic
						)
					end
				end
			end,
		},
	},
	balloon_dog = {
		Name = "Balloon Dog",
		Rarity = "Rare",
		Role = "Party Animal",
		Special = "A_BalloonBarrage",
		Stats = { HP = 1.0, Atk = 1.2, Speed = 17 },
		Look = {
			scale = 1.1,
			main = C(255, 90, 160),
			second = C(255, 90, 160),
			belly = C(255, 90, 160),
			eye = C(30, 24, 30),
			body = { len = 2.6, w = 1.2, h = 1.2 },
			legs = { len = 1.15, thick = 0.5, noToes = true },
			head = { size = 1.3, snout = 1.1, snoutW = 1.05, lift = 0.85, neckW = 1.25, noBrows = true },
			mood = "calm",
			eyes = "bead",
			ears = "none",
			tail = "balloon",
			extras = { noBelly = true },
			-- balão de festa torcido: gomos compridos, "torções" entre eles, nó no focinho, tudo brilhante
			build = function(b, ctx)
				local B, torso, look, model = ctx.Body, ctx.Torso, ctx.Look, ctx.Model
				local pink = look.main
				local knot = C(235, 70, 140)
				-- torções entre corpo, pescoço e pernas
				for _, z in ipairs({ -B.len * 0.38, B.len * 0.38 }) do
					b:E(torso, "A_Torcao", V(0.42, 0.42, 0.42), knot, CF(0, -B.h * 0.12, z))
				end
				b:E(torso, "A_Torcao", V(0.4, 0.4, 0.4), knot, CF(0, B.h * 0.32, -B.len * 0.44))
				-- orelhas: dois gomos compridos para trás (balançam: "Orelha")
				local head = model:FindFirstChild("Head1")
				if head then
					local hs, ax, ay = headAxes(look)
					for _, side in ipairs({ -1, 1 }) do
						local base = V(side * ax * 0.45, ay * 0.7, 0.1 * hs)
						local tip = base + V(side * 0.35, 0.75, 0.75) * hs
						b:Seg(head, "Orelha", base, tip, 0.2 * hs, 0.2 * hs, pink)
						b:E(head, "OrelhaDentro", V(0.26, 0.26, 0.26) * hs, knot, CF(base))
					end
					-- nó de amarrar na ponta do focinho
					local n = weldedTo(model, head, { Nariz = true })[1]
					if n then
						local c0 = n.Weld.C0
						b:E(head, "A_No", V(0.16, 0.16, 0.22) * hs, knot, CF(c0.Position / b.S) * CF(0, 0, -0.08 * hs))
						b:Seg(
							head,
							"A_NoPonta",
							c0.Position / b.S + V(0, 0, -0.12 * hs),
							c0.Position / b.S + V(0.05, -0.1, -0.3) * hs,
							0.04 * hs,
							0.02 * hs,
							knot
						)
					end
				end
				-- rabo: gomo em pé com nó
				local tail = model:FindFirstChild("TailBase")
				if tail then
					b:E(tail, "A_Torcao", V(0.34, 0.34, 0.34), knot, CF(0, 0, 0))
					b:Seg(tail, "A_RaboBalao", V(0, 0.1, 0.05), V(0, 1.0, 0.35), 0.2, 0.2, pink)
					b:E(tail, "A_RaboNo", V(0.14, 0.18, 0.14), knot, CF(0, 1.18, 0.42))
				end
				-- brilho de balão: reflexo branco nos gomos grandes e tudo um pouco refletivo
				for _, p in ipairs(model:GetChildren()) do
					if p:IsA("BasePart") and p.Transparency < 1 and p.Color == pink then
						p.Reflectance = 0.15
					end
				end
				for _, z in ipairs({ -B.len * 0.2, B.len * 0.15 }) do
					b:E(torso, "A_Reflexo", V(0.18, 0.1, 0.5), WHITE, CF(-B.w * 0.2, B.h * 0.42, z) * ANG(0, 0, 0.5), Enum.Material.Neon)
				end
			end,
		},
	},
	windup_dog = {
		Name = "Wind-Up Dog",
		Rarity = "Rare",
		Role = "Toy",
		Special = "A_WindUpRush",
		Stats = { HP = 1.15, Atk = 1.1, Speed = 17 },
		Look = {
			scale = 1.0,
			main = C(220, 62, 52),
			second = C(245, 198, 70),
			belly = C(240, 234, 222),
			eye = C(20, 20, 24),
			material = Enum.Material.Metal,
			body = { len = 2.8, w = 1.4, h = 1.35 },
			legs = { len = 0.9, thick = 0.34, noToes = true, paw = C(245, 198, 70), color = C(200, 52, 45) },
			head = { size = 1.45, snout = 0.7, snoutW = 1.0, lift = 0.45, muzzle = C(240, 234, 222), nose = C(25, 25, 30) },
			mood = "calm",
			eyes = "bead",
			ears = "none",
			tail = "spring",
			extras = { noBelly = true },
			build = function(b, ctx)
				local B, torso, look, model = ctx.Body, ctx.Torso, ctx.Look, ctx.Model
				local gold, steel = look.second, C(180, 186, 196)
				-- costura de lata ao longo do corpo + rebites
				b:E(torso, "A_Costura", V(0.12, B.h * 1.0, B.len * 0.98), C(150, 40, 35), CF(0, 0.04, 0), Enum.Material.Metal)
				for i = -2, 2 do
					local p = bodyPoint(B, 0, i * 0.17, 0.02)
					for _, side in ipairs({ -1, 1 }) do
						b:E(torso, "A_Rebite", V(0.12, 0.12, 0.12), gold, CF(p + V(side * 0.12, -0.02, 0)), Enum.Material.Foil)
					end
				end
				-- barriga pintada
				b:E(torso, "A_Pintura", V(B.w * 0.7, B.h * 0.4, B.len * 0.6), look.belly, CF(0, -B.h * 0.3, 0), Enum.Material.SmoothPlastic)
				-- chave de corda nas costas (Motor6D "A_Chave": o efeito do poder gira a chave)
				local pivot = b:Pivot("A_ChaveBase")
				b:Joint("A_Chave", torso, pivot, CF(0, B.h * 0.5, B.len * 0.08), CF())
				b:Seg(pivot, "A_ChaveEixo", V(0, -0.1, 0), V(0, 0.7, 0), 0.09, 0.09, steel, Enum.Material.Metal)
				b:E(pivot, "A_ChaveMiolo", V(0.3, 0.3, 0.3), gold, CF(0, 0.7, 0), Enum.Material.Foil)
				for _, side in ipairs({ -1, 1 }) do
					local cf = CF(0, 1.05, side * 0.42) * ANG(side * 0.45, 0, 0)
					b:E(pivot, "A_ChaveAsa", V(0.16, 0.95, 0.75), gold, cf, Enum.Material.Foil)
					b:E(pivot, "A_ChaveFuro", V(0.2, 0.42, 0.3), C(200, 52, 45), cf * CF(0, 0.08, side * 0.02), Enum.Material.Metal)
				end
				-- rabo de mola
				local tail = model:FindFirstChild("TailBase")
				if tail then
					local last = V(0, 0, 0)
					for i = 1, 8 do
						local a = i * PI * 0.75
						local p = V(math.cos(a) * 0.18, i * 0.12, 0.06 * i + math.sin(a) * 0.18)
						b:Seg(tail, "A_Mola", last, p, 0.045, 0.045, steel, Enum.Material.Metal)
						last = p
					end
					b:E(tail, "A_MolaBola", V(0.3, 0.3, 0.3), gold, CF(last + V(0, 0.1, 0)), Enum.Material.Foil)
				end
				-- orelhas de lata (redondas; chamam "Orelha" para o Animator mexer)
				local head = model:FindFirstChild("Head1")
				if head then
					local hs, ax, ay = headAxes(look)
					for _, side in ipairs({ -1, 1 }) do
						local cf = CF(side * ax * 0.78, ay * 0.72, 0.05 * hs) * ANG(0, 0, -side * 0.5)
						b:E(head, "Orelha", V(0.1, 0.5, 0.5) * hs, gold, cf * CF(0, 0.2 * hs, 0), Enum.Material.Foil)
						b:E(head, "OrelhaDentro", V(0.11, 0.32, 0.32) * hs, C(200, 52, 45), cf * CF(side * 0.01 * hs, 0.2 * hs, 0), Enum.Material.Metal)
						b:E(
							head,
							"A_Bochecha",
							V(0.16, 0.16, 0.05) * hs,
							C(255, 120, 130),
							CF(side * ax * 0.6, -0.05 * hs, -0.34 * hs) * ANG(0, -side * 0.6, 0),
							Enum.Material.SmoothPlastic
						)
					end
				end
			end,
		},
	},
	mushroom_dog = {
		Name = "Mushroom Dog",
		Rarity = "Rare",
		Role = "Sleepy",
		Special = "A_SporeBurst",
		Stats = { HP = 1.2, Atk = 1.1, Speed = 15 },
		Look = {
			scale = 1.0,
			main = C(240, 226, 200),
			second = C(205, 45, 45),
			belly = C(255, 248, 235),
			eye = C(40, 28, 30),
			body = { len = 2.7, w = 1.4, h = 1.35 },
			legs = { len = 0.8, thick = 0.42, color = C(232, 214, 186) },
			head = { size = 1.45, snout = 0.6, lift = 0.4, muzzle = C(255, 248, 235), eyeSize = 1.2 },
			mood = "calm",
			eyes = "cute",
			ears = "none",
			tail = "mushroom",
			extras = { aura = C(210, 170, 255) },
			build = function(b, ctx)
				local B, torso, look, model = ctx.Body, ctx.Torso, ctx.Look, ctx.Model
				local red, spot = look.second, WHITE
				-- chapéu gigante na cabeça
				local head = model:FindFirstChild("Head1")
				if head then
					local hs, _, ay = headAxes(look)
					local capY = ay * 1.15
					b:E(head, "A_Chapeu", V(2.3, 1.05, 2.2) * hs, red, CF(0, capY, 0.05 * hs))
					b:E(head, "A_Lamelas", V(2.15, 0.25, 2.05) * hs, C(235, 205, 175), CF(0, capY - 0.3 * hs, 0.05 * hs))
					local rng = Random.new(4)
					for i = 1, 9 do
						local a = i / 9 * PI * 2 + rng:NextNumber(-0.3, 0.3)
						local r = (i % 3 == 0) and 0.25 or rng:NextNumber(0.55, 0.85)
						local u = V(math.cos(a) * r * 1.15, 0, math.sin(a) * r * 1.1)
						local yy = 0.525 * math.sqrt(math.max(0.05, 1 - (u.X / 1.15) ^ 2 - (u.Z / 1.1) ^ 2))
						local p = V(u.X, yy, u.Z) * hs + V(0, capY, 0.05 * hs)
						local n = V(u.X / 1.32, yy / 0.27, u.Z / 1.21).Unit
						local d = rng:NextNumber(0.22, 0.36)
						b:E(head, "A_Pinta", V(d, d, 0.08) * hs, spot, CFrame.lookAt(p, p + n), Enum.Material.SmoothPlastic)
					end
				end
				-- cogumelinhos crescendo nas costas
				local list = { { -0.25, -0.15, 0.55, C(170, 110, 220) }, { 0.3, 0.12, 0.42, C(205, 45, 45) }, { -0.05, 0.32, 0.36, C(170, 110, 220) } }
				for _, m in ipairs(list) do
					local p, n = bodyPoint(B, m[1], m[2], 0)
					local s = m[3]
					local top = p + n * s * 0.9
					b:Seg(torso, "A_Talo", p, top, s * 0.18, s * 0.18, look.belly)
					local cap = b:E(torso, "A_ChapeuMini", V(s * 0.9, s * 0.45, s * 0.9), m[4], CFrame.lookAt(top, top + V(0, 0, -1)))
					if m[4] ~= red then
						glow(cap)
					end
				end
				-- manchas de musgo/terra
				for _, a in ipairs({ -1.3, 1.1 }) do
					local p = bodyPoint(B, a, 0.15, 0.01)
					b:E(torso, "A_Musgo", V(0.6, 0.45, 0.12), C(120, 160, 80), CFrame.lookAt(p, p + V(math.sin(a), 0, 0)), Enum.Material.Grass)
				end
				-- rabo: cogumelo
				local tail = model:FindFirstChild("TailBase")
				if tail then
					b:Seg(tail, "A_RaboTalo", V(0, 0, 0), V(0, 0.55, 0.25), 0.14, 0.14, look.belly)
					b:E(tail, "A_RaboChapeu", V(0.6, 0.32, 0.6), red, CF(0, 0.6, 0.27))
					b:E(tail, "A_RaboPinta", V(0.14, 0.06, 0.14), spot, CF(0.1, 0.75, 0.25), Enum.Material.SmoothPlastic)
				end
			end,
		},
	},
}

Pack.Order = {
	"beagle",
	"corgi",
	"salsicha",
	"chihuahua",
	"pastor_alemao",
	"border_collie",
	"sao_bernardo",
	"akita",
	"galgo",
	"cactus_dog",
	"bee_dog",
	"balloon_dog",
	"windup_dog",
	"mushroom_dog",
}

Pack.Specials = {
	A_CorgiBounce = { Name = "Butt Bounce", Desc = "Jumps backwards and butt-slams the target; the ground ripples in waves." },
	A_YapBlast = { Name = "Yap Blast", Desc = "Shakes with rage and barks in a cone that pushes back and stuns." },
	A_K9Takedown = { Name = "K9 Takedown", Desc = "Sniffs, locks on to the target, leaps and pins it down with bites." },
	A_Frisbee = { Name = "Perfect Frisbee", Desc = "Throws a frisbee that curves around the target, then leaps over it to catch it midair." },
	A_Avalanche = { Name = "Avalanche", Desc = "Howls from the mountain: a snowball rolls, grows and buries the target." },
	A_CactusVolley = { Name = "Spike Volley", Desc = "Puffs up and fires fans of spikes; the ones that land keep stabbing." },
	A_BeeSwarm = { Name = "Bee Swarm", Desc = "Buzzes and releases a swarm that chases the target and ends with a sting." },
	A_BalloonBarrage = { Name = "Water Balloons", Desc = "Inflates three balloons and lobs them around the target; they splash and leave a puddle." },
	A_ScentHowl = { Name = "Hunter's Nose", Desc = "Sniffs the trail to the target, dashes at it and lets out a hunting howl that pushes back." },
	A_SausageRoll = { Name = "Sausage Roll", Desc = "Curls up like a wheel, rolls through the target and comes back like a boomerang." },
	A_GuardianStance = { Name = "Guardian Stance", Desc = "Plants its paws behind a golden shield (less damage) and strikes back with a ground stomp." },
	A_Slipstream = { Name = "Slipstream", Desc = "Marks a track, dashes straight through the target and the slipstream cuts everything in its path." },
	A_WindUpRush = { Name = "Wind-Up Rush", Desc = "Winds the key on its back and zigzags around, slamming into the target." },
	A_SporeBurst = { Name = "Sleepy Spores", Desc = "Its cap puffs up and releases spores that make the target doze off." },
}

return Pack
