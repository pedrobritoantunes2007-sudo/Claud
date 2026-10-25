-- Catálogo de cachorros, ovos, NPCs da arena e bosses.
-- Regra de design: quanto mais raro, mais a ANATOMIA muda (silhueta, cabeças, asas, tamanho),
-- não só a cor. Comuns parecem cachorros normais e fofos; míticos são absurdos.
--
-- Look (lido pelo DogBuilder):
--   scale       tamanho geral
--   main/second/belly/eye  cores
--   mood  = happy | calm | fierce | evil      expressão (sobrancelhas, pálpebras, língua, presas)
--   eyes  = cute | white | glow | skull | alien | bead | none
--   body  = { len, w, h, chest, haunch, saddle }   chest/haunch = volume do peito/quadril; saddle = cor das costas
--   legs  = { len, thick, front, hind, bowed, socks, sockH, paw, claws, feather, bands, lower, color, noToes }
--           len = altura do chão até a base do tronco (HipHeight)
--   head  = { size, snout, snoutW, flat, lift, forward, w, tall, long, cap, face, muzzle, bridge, blaze, brows,
--             cheeks, jowls, underbite, wrinkles, eyeSize, eyeGap, eyeY, tongue, shark, skull, plate, neckW ... }
--   ears  = pointy | big | cropped | swept | semi | floppy | long | rose | pom | plate | none  (earSize, earColor, earInner, earTip)
--   tail  = curl | sickle | fluffy | thin | plume | stub | whip | dragon | shark | flame | fan | bolt | bone
--           | bandage | stars | tentacles | rock | antenna | wisp  (tailSize, tailColor, tailTip)
--   heads = 1, 2 ou 3
--   extras = { ... } detalhes de anatomia/efeito (ver DogBuilder)
local DogData = {}

-- 📜 catálogo das habilidades novas (2026-10). WaitForChild com tempo: as ferramentas de prévia que não carregam
-- o Skills continuam funcionando (com os poderes antigos)
local SkillsModule = script.Parent:WaitForChild("Skills", 3)
local Skills = SkillsModule and require(SkillsModule) or nil
-- 👑 raridades com SUPREMO (habilidade 4): a partir do Épico (igual ao Config.HasSupreme)
DogData.SUPREME_RARITY = { Epic = true, Legendary = true, Mythic = true, Halloween = true, Divine = true }

local C = Color3.fromRGB

DogData.Species = {
	------------------------------------------------------------ COMMON
	caramelo = {
		Name = "Caramel Mutt",
		Rarity = "Common",
		Role = "Balanced",
		Special = "Pounce",
		Stats = { HP = 1, Atk = 1, Speed = 16 },
		Look = {
			scale = 1,
			main = C(214, 150, 82),
			second = C(180, 115, 58),
			belly = C(248, 222, 180),
			eye = C(40, 28, 20),
			body = { len = 2.9, w = 1.4, h = 1.3 },
			legs = { len = 1.0, thick = 0.4, socks = C(248, 222, 180), sockH = 0.18 },
			head = { size = 1.55, snout = 0.75, lift = 0.4, blaze = C(248, 222, 180) },
			ears = "semi",
			earTip = C(150, 98, 50),
			tail = "curl",
			extras = { collar = C(220, 60, 60) },
		},
	},
	pug = {
		Name = "Pug",
		Rarity = "Common",
		Role = "Cuddly Tank",
		Special = "Charge",
		Stats = { HP = 1.25, Atk = 0.85, Speed = 14 },
		Look = {
			scale = 0.85,
			main = C(226, 196, 148),
			second = C(55, 45, 42),
			belly = C(236, 214, 172),
			eye = C(25, 20, 20),
			body = { len = 2.4, w = 1.6, h = 1.45, chest = 1.08 },
			legs = { len = 0.7, thick = 0.42 },
			head = {
				size = 1.65,
				snout = 0.32,
				snoutW = 1.15,
				flat = true,
				forward = 0.1,
				lift = 0.3,
				muzzle = C(60, 48, 45),
				wrinkles = true,
				eyeSize = 1.12,
				eyeGap = 0.25,
				tongue = true,
			},
			ears = "rose",
			earSize = 1.05,
			tail = "curl",
			tailTip = C(226, 196, 148),
			extras = { collar = C(60, 190, 200) },
		},
	},
	pinscher = {
		Name = "Pinscher",
		Rarity = "Common",
		Role = "Speedy",
		Special = "Zoomies",
		Stats = { HP = 0.8, Atk = 1, Speed = 21 },
		Look = {
			scale = 0.7,
			main = C(38, 30, 30),
			second = C(38, 30, 30),
			belly = C(185, 105, 50),
			eye = C(30, 20, 15),
			body = { len = 2.5, w = 1.05, h = 1.05, chest = 1.05, haunch = 0.9 },
			legs = { len = 1.35, thick = 0.24, socks = C(185, 105, 50), sockH = 0.4 },
			head = { size = 1.38, snout = 0.8, snoutW = 0.7, lift = 0.55, brows = C(185, 105, 50), eyeSize = 1.15, neckW = 0.8 },
			ears = "big",
			earSize = 0.92,
			earInner = C(200, 120, 110),
			tail = "thin",
			extras = { collar = C(225, 50, 55) },
		},
	},
	poodle = {
		Name = "Poodle",
		Rarity = "Common",
		Role = "Speedy",
		Special = "Zoomies",
		Stats = { HP = 0.85, Atk = 1, Speed = 20 },
		Look = {
			scale = 0.95,
			main = C(250, 246, 242),
			second = C(255, 252, 250),
			belly = C(250, 246, 242),
			eye = C(35, 30, 35),
			body = { len = 2.5, w = 1.15, h = 1.2 },
			legs = { len = 1.35, thick = 0.26 },
			head = { size = 1.38, snout = 0.9, snoutW = 0.7, lift = 0.55, nose = C(40, 35, 40), neckW = 0.8 },
			ears = "pom",
			tail = "plume",
			extras = { poms = true, ruff = C(255, 252, 250), collar = C(240, 110, 170) },
		},
	},
	bulldog = {
		Name = "Bulldog",
		Rarity = "Common",
		Role = "Tough",
		Special = "Charge",
		Stats = { HP = 1.35, Atk = 0.9, Speed = 14 },
		Look = {
			scale = 1,
			main = C(214, 150, 92),
			second = C(214, 150, 92),
			belly = C(252, 246, 236),
			eye = C(30, 22, 20),
			body = { len = 2.6, w = 1.9, h = 1.35, chest = 1.3, haunch = 0.78 },
			legs = { len = 0.65, thick = 0.5, front = 1.25, hind = 0.85, bowed = true, socks = C(252, 246, 236), sockH = 0.25 },
			head = {
				size = 1.6,
				snout = 0.35,
				snoutW = 1.5,
				flat = true,
				forward = 0.25,
				lift = 0.15,
				w = 1.15,
				tall = 0.88,
				jowls = true,
				underbite = true,
				wrinkles = true,
				blaze = C(252, 246, 236),
				muzzle = C(252, 246, 236),
				eyeGap = 0.26,
				eyeY = 0.1,
				neckW = 1.4,
			},
			mood = "calm",
			eyes = "cute",
			ears = "rose",
			earSize = 1.05,
			earColor = C(170, 110, 65),
			tail = "stub",
			extras = { collar = C(45, 42, 50), spikedCollar = true },
		},
	},
	------------------------------------------------------------ UNCOMMON
	snow_husky = {
		Name = "Snow Husky",
		Rarity = "Uncommon",
		Role = "Control",
		Special = "FreezeHowl",
		Stats = { HP = 1, Atk = 1.05, Speed = 18 },
		Look = {
			scale = 1.1,
			main = C(250, 250, 255),
			second = C(80, 88, 105),
			belly = C(250, 250, 255),
			eye = C(90, 190, 255),
			body = { len = 3.1, w = 1.45, h = 1.4, saddle = C(85, 94, 112) },
			legs = { len = 1.05, thick = 0.38 },
			head = {
				size = 1.5,
				snout = 1.0,
				lift = 0.45,
				cap = C(85, 94, 112),
				face = C(250, 250, 255),
				brows = C(250, 250, 255),
				muzzle = C(250, 250, 255),
				bridge = C(250, 250, 255),
				cheeks = C(250, 250, 255),
			},
			eyes = "white",
			ears = "pointy",
			earColor = C(85, 94, 112),
			tail = "sickle",
			tailColor = C(85, 94, 112),
			extras = { ruff = C(250, 250, 255), aura = C(170, 220, 255) },
		},
	},
	armored_doberman = {
		Name = "Armored Doberman",
		Rarity = "Uncommon",
		Role = "Charger",
		Special = "Charge",
		Stats = { HP = 1.15, Atk = 1.1, Speed = 18 },
		Look = {
			scale = 1.15,
			main = C(32, 28, 32),
			second = C(32, 28, 32),
			belly = C(160, 90, 42),
			eye = C(30, 22, 20),
			body = { len = 3.1, w = 1.25, h = 1.3, chest = 1.12, haunch = 0.92 },
			legs = { len = 1.35, thick = 0.34, socks = C(160, 90, 42), sockH = 0.3 },
			head = { size = 1.38, snout = 1.1, snoutW = 0.7, lift = 0.6, brows = C(160, 90, 42), long = 1.05, neckW = 0.9 },
			mood = "fierce",
			eyes = "white",
			ears = "cropped",
			earSize = 1.1,
			tail = "stub",
			extras = { armor = C(140, 148, 160) },
		},
	},
	boxer = {
		Name = "Racer Boxer",
		Rarity = "Uncommon",
		Role = "Speedy",
		Special = "Zoomies",
		Stats = { HP = 0.95, Atk = 1.1, Speed = 22 },
		Look = {
			scale = 1.05,
			main = C(205, 130, 70),
			second = C(205, 130, 70),
			belly = C(252, 248, 240),
			eye = C(30, 20, 15),
			body = { len = 2.9, w = 1.4, h = 1.35, chest = 1.18, haunch = 0.92 },
			legs = { len = 1.15, thick = 0.36, socks = C(252, 248, 240), sockH = 0.22 },
			head = {
				size = 1.45,
				snout = 0.45,
				snoutW = 1.25,
				flat = true,
				lift = 0.5,
				muzzle = C(50, 38, 34),
				blaze = C(252, 248, 240),
				jowls = true,
				underbite = true,
				eyeGap = 0.24,
			},
			mood = "fierce",
			eyes = "cute",
			ears = "floppy",
			earSize = 0.75,
			tail = "stub",
			extras = { headband = C(230, 50, 50), lines = C(255, 220, 120) },
		},
	},
	golden = {
		Name = "Golden Retriever",
		Rarity = "Uncommon",
		Role = "Balanced",
		Special = "Pounce",
		Stats = { HP = 1.1, Atk = 1, Speed = 17 },
		Look = {
			scale = 1.2,
			main = C(232, 176, 92),
			second = C(214, 150, 70),
			belly = C(248, 214, 156),
			eye = C(45, 28, 18),
			body = { len = 3.1, w = 1.5, h = 1.4 },
			legs = { len = 1.0, thick = 0.42, feather = C(248, 214, 156) },
			head = { size = 1.55, snout = 0.85, lift = 0.45, muzzle = C(248, 214, 156), eyeSize = 1.1 },
			ears = "long",
			earSize = 0.95,
			earTip = C(214, 150, 70),
			tail = "fluffy",
			tailFeather = C(248, 214, 156),
			extras = { ruff = C(248, 214, 156), fringe = C(240, 196, 120), collar = C(60, 170, 90) },
		},
	},
	dalmatian = {
		Name = "Dalmatian",
		Rarity = "Uncommon",
		Role = "Shooter",
		Special = "BoneToss",
		Stats = { HP = 0.95, Atk = 1.15, Speed = 18 },
		Look = {
			scale = 1.1,
			main = C(250, 250, 250),
			second = C(28, 28, 30),
			belly = C(255, 255, 255),
			eye = C(30, 25, 25),
			body = { len = 3.0, w = 1.3, h = 1.3 },
			legs = { len = 1.2, thick = 0.34 },
			head = { size = 1.45, snout = 0.9, lift = 0.5, spotEye = C(28, 28, 30), eyeGap = 0.22 },
			ears = "floppy",
			earTip = C(28, 28, 30),
			tail = "thin",
			extras = { spots = C(28, 28, 30), spotCount = 14, collar = C(220, 40, 40) },
		},
	},
	------------------------------------------------------------ RARE
	storm_pup = {
		Name = "Storm Pup",
		Rarity = "Rare",
		Role = "Assassin",
		Special = "ThunderHunt",
		Stats = { HP = 0.9, Atk = 1.2, Speed = 22 },
		Look = {
			scale = 0.9,
			main = C(255, 212, 50),
			second = C(60, 60, 80),
			belly = C(255, 240, 170),
			eye = C(120, 220, 255),
			body = { len = 2.7, w = 1.3, h = 1.3 },
			legs = { len = 0.95, thick = 0.36, paw = C(60, 60, 80) },
			head = { size = 1.5, snout = 0.6, lift = 0.4, cheeks = C(255, 240, 170), eyeSize = 1.15 },
			mood = "happy",
			ears = "big",
			earTip = C(60, 60, 80),
			earInner = C(255, 240, 170),
			tail = "bolt",
			extras = { bolts = C(120, 220, 255), tuft = C(255, 212, 50), eyeGlow = true, aura = C(150, 220, 255) },
		},
	},
	stone_hound = {
		Name = "Stone Hound",
		Rarity = "Rare",
		Role = "Tank",
		Special = "GroundSlam",
		Stats = { HP = 1.5, Atk = 0.95, Speed = 13 },
		Look = {
			scale = 1.25,
			main = C(130, 126, 122),
			second = C(96, 92, 90),
			belly = C(158, 152, 146),
			eye = C(255, 170, 60),
			material = Enum.Material.Slate,
			body = { len = 3, w = 1.8, h = 1.55, chest = 1.2 },
			legs = { len = 0.85, thick = 0.58, front = 1.15, noToes = false, claws = C(80, 76, 74) },
			head = { size = 1.45, snout = 0.85, snoutW = 1.15, forward = 0.15, lift = 0.25, w = 1.1, muzzle = C(110, 106, 102) },
			mood = "fierce",
			ears = "cropped",
			tail = "rock",
			extras = { rocks = true, cracksHead = C(255, 170, 60), cracks = C(255, 150, 50), eyeGlow = true, noBelly = true },
		},
	},
	robo_dog = {
		Name = "Robo Dog",
		Rarity = "Rare",
		Role = "Laser",
		Special = "LaserEyes",
		Stats = { HP = 1.15, Atk = 1.1, Speed = 16 },
		Look = {
			scale = 1.1,
			main = C(205, 210, 220),
			second = C(70, 76, 92),
			belly = C(150, 156, 168),
			eye = C(255, 60, 60),
			material = Enum.Material.Metal,
			body = { len = 3, w = 1.35, h = 1.15 },
			legs = { len = 1.15, thick = 0.3, noToes = true },
			head = { size = 1.3, snout = 0.75, snoutW = 0.85, lift = 0.5 },
			mood = "calm",
			eyes = "none",
			ears = "plate",
			tail = "antenna",
			extras = { robot = C(0, 220, 255), eyeGlow = true, antenna = C(255, 60, 60), noBelly = true },
		},
	},
	horned_pup = {
		Name = "Horned Hound",
		Rarity = "Rare",
		Role = "Charger",
		Special = "Charge",
		Stats = { HP = 1.2, Atk = 1.15, Speed = 17 },
		Look = {
			scale = 1.1,
			main = C(125, 72, 50),
			second = C(80, 45, 30),
			belly = C(200, 160, 120),
			eye = C(255, 200, 80),
			body = { len = 2.9, w = 1.55, h = 1.45, chest = 1.18 },
			legs = { len = 0.95, thick = 0.44, claws = C(240, 232, 210) },
			head = { size = 1.5, snout = 0.75, lift = 0.35, w = 1.05 },
			mood = "fierce",
			ears = "floppy",
			earSize = 0.8,
			tail = "whip",
			extras = { horns = "ram", eyeGlow = true },
		},
	},
	skull_dog = {
		Name = "Skull Dog",
		Rarity = "Rare",
		Role = "Shooter",
		Special = "BoneToss",
		Stats = { HP = 0.9, Atk = 1.25, Speed = 17 },
		Look = {
			scale = 1.05,
			main = C(55, 50, 62),
			second = C(40, 35, 40),
			belly = C(70, 64, 78),
			eye = C(80, 255, 140),
			body = { len = 2.8, w = 1.1, h = 1.2, chest = 1.05, haunch = 0.85 },
			legs = { len = 1.2, thick = 0.24, color = C(240, 232, 210), claws = C(240, 232, 210) },
			head = {
				size = 1.45,
				snout = 0.85,
				snoutW = 0.85,
				lift = 0.5,
				cap = C(240, 232, 210),
				muzzle = C(240, 232, 210),
				skull = true,
				noBridge = true,
				nose = C(30, 26, 30),
				jawColor = C(225, 216, 192),
				neckW = 0.7,
			},
			neckColor = C(240, 232, 210),
			mood = "evil",
			eyes = "skull",
			ears = "pointy",
			earColor = C(240, 232, 210),
			earInner = C(40, 35, 40),
			tail = "bone",
			extras = { ribs = C(240, 232, 210), eyeGlow = true, aura = C(80, 255, 140), noBelly = true },
		},
	},
	crystal_hound = {
		Name = "Crystal Dog",
		Rarity = "Rare",
		Role = "Area",
		Special = "CrystalSpikes",
		Stats = { HP = 1.05, Atk = 1.15, Speed = 16 },
		Look = {
			scale = 1.1,
			main = C(150, 120, 220),
			second = C(100, 80, 170),
			belly = C(205, 190, 245),
			eye = C(225, 200, 255),
			body = { len = 3, w = 1.45, h = 1.4 },
			legs = { len = 1.0, thick = 0.4, paw = C(100, 80, 170) },
			head = { size = 1.4, snout = 0.85, lift = 0.45 },
			mood = "calm",
			ears = "pointy",
			earColor = C(200, 150, 255),
			tail = "fluffy",
			tailFeather = C(200, 150, 255),
			extras = { crystals = C(200, 150, 255), gem = C(230, 180, 255), eyeGlow = true },
		},
	},
	------------------------------------------------------------ EPIC
	brute_bulldog = {
		Name = "Buff Bulldog",
		Rarity = "Epic",
		Role = "Tank",
		Special = "GroundSlam",
		Stats = { HP = 1.5, Atk = 1.1, Speed = 14 },
		Look = {
			scale = 1.45,
			main = C(205, 160, 118),
			second = C(205, 160, 118),
			belly = C(244, 230, 210),
			eye = C(30, 20, 20),
			body = { len = 2.6, w = 2.2, h = 1.65, chest = 1.45, haunch = 0.72 },
			legs = { len = 1.15, thick = 0.58, front = 1.6, hind = 0.72, bowed = true, socks = C(244, 230, 210), sockH = 0.2, bands = C(220, 40, 40) },
			head = {
				size = 1.75,
				snout = 0.35,
				snoutW = 1.6,
				flat = true,
				forward = 0.45,
				lift = 0.05,
				w = 1.18,
				tall = 0.88,
				jowls = true,
				underbite = true,
				wrinkles = true,
				muzzle = C(244, 230, 210),
				blaze = C(244, 230, 210),
				eyeGap = 0.27,
				eyeY = 0.1,
				neckW = 1.5,
			},
			mood = "evil",
			eyes = "white",
			ears = "rose",
			earColor = C(160, 110, 75),
			tail = "stub",
			extras = { muscles = true, collar = C(220, 40, 40), spikedCollar = true },
		},
	},
	samurai_shiba = {
		Name = "Shiba Samurai",
		Rarity = "Epic",
		Role = "Duelist",
		Special = "SamuraiSlash",
		Stats = { HP = 1.05, Atk = 1.3, Speed = 19 },
		Look = {
			scale = 1.05,
			main = C(228, 140, 62),
			second = C(228, 140, 62),
			belly = C(252, 244, 230),
			eye = C(30, 20, 15),
			body = { len = 2.8, w = 1.4, h = 1.35 },
			legs = { len = 1.0, thick = 0.38, socks = C(252, 244, 230), sockH = 0.2 },
			head = {
				size = 1.45,
				snout = 0.75,
				lift = 0.4,
				face = C(252, 244, 230),
				muzzle = C(252, 244, 230),
				brows = C(252, 244, 230),
				bridge = C(228, 140, 62),
			},
			mood = "fierce",
			eyes = "white",
			ears = "pointy",
			earSize = 0.85,
			tail = "curl",
			tailTip = C(252, 244, 230),
			extras = { helmet = C(170, 30, 40), samurai = C(170, 30, 40), katana = true },
		},
	},
	ghost_hound = {
		Name = "Ghost Dog",
		Rarity = "Epic",
		Role = "Illusionist",
		Special = "ShadowClones",
		Stats = { HP = 0.95, Atk = 1.3, Speed = 20 },
		Look = {
			scale = 1.1,
			main = C(210, 232, 255),
			second = C(160, 200, 255),
			belly = C(236, 246, 255),
			eye = C(80, 170, 255),
			material = Enum.Material.Glass,
			body = { len = 2.9, w = 1.3, h = 1.3, haunch = 0.8 },
			legs = { len = 0.9, thick = 0.3, hind = 0.7, noToes = true },
			head = { size = 1.45, snout = 0.75, lift = 0.5 },
			mood = "evil",
			ears = "long",
			tail = "wisp",
			extras = { ghost = true, wisps = true, eyeGlow = true, smoke = C(200, 220, 255), float = 1.2 },
		},
	},
	toxic_hound = {
		Name = "Toxic Hound",
		Rarity = "Epic",
		Role = "Poison",
		Special = "ToxicCloud",
		Stats = { HP = 1.1, Atk = 1.2, Speed = 16 },
		Look = {
			scale = 1.15,
			main = C(92, 150, 62),
			second = C(70, 45, 100),
			belly = C(175, 230, 95),
			eye = C(190, 255, 60),
			body = { len = 3, w = 1.5, h = 1.4 },
			legs = { len = 1.0, thick = 0.4, claws = C(70, 45, 100) },
			head = { size = 1.45, snout = 0.85, lift = 0.4, tongue = true },
			mood = "evil",
			ears = "pointy",
			earColor = C(70, 45, 100),
			earInner = C(175, 230, 95),
			tail = "whip",
			extras = { bubbles = C(150, 255, 60), spikes = C(70, 45, 100), pustules = C(170, 255, 60), eyeGlow = true },
		},
	},
	frost_beast = {
		Name = "Frost Beast",
		Rarity = "Epic",
		Role = "Control",
		Special = "FrozenDomain",
		Stats = { HP = 1.35, Atk = 1.1, Speed = 15 },
		Look = {
			scale = 1.4,
			main = C(232, 242, 255),
			second = C(160, 205, 245),
			belly = C(250, 252, 255),
			eye = C(80, 200, 255),
			body = { len = 3.2, w = 1.9, h = 1.7, chest = 1.2 },
			legs = { len = 1.0, thick = 0.52, claws = C(140, 210, 255), feather = C(250, 252, 255) },
			head = { size = 1.55, snout = 0.9, lift = 0.35, cheeks = C(250, 252, 255) },
			mood = "fierce",
			ears = "pointy",
			earColor = C(160, 205, 245),
			earInner = C(200, 230, 255),
			tail = "sickle",
			extras = { icicleBack = C(140, 215, 255), icicles = C(170, 225, 255), mane = C(244, 250, 255), eyeGlow = true, aura = C(190, 235, 255) },
		},
	},
	magma_hound = {
		Name = "Magma Hound",
		Rarity = "Epic",
		Role = "Area",
		Special = "InfernoRing",
		Stats = { HP = 1.2, Atk = 1.25, Speed = 16 },
		Look = {
			scale = 1.2,
			main = C(55, 40, 40),
			second = C(255, 110, 25),
			belly = C(80, 50, 40),
			eye = C(255, 150, 30),
			material = Enum.Material.Basalt,
			body = { len = 3.1, w = 1.6, h = 1.45 },
			legs = { len = 1.0, thick = 0.46, claws = C(255, 140, 40) },
			head = { size = 1.5, snout = 0.85, lift = 0.4, muzzle = C(70, 48, 44) },
			mood = "evil",
			ears = "pointy",
			earColor = C(45, 32, 32),
			earInner = C(255, 120, 30),
			tail = "flame",
			flameCore = C(255, 220, 90),
			extras = {
				cracks = C(255, 110, 20),
				cracksHead = C(255, 110, 20),
				fire = C(255, 120, 30),
				legFire = C(255, 120, 30),
				eyeGlow = true,
				noBelly = true,
			},
		},
	},
	mummy_dog = {
		Name = "Mummy Dog",
		Rarity = "Epic",
		Role = "Control",
		Special = "MummyBind",
		Stats = { HP = 1.3, Atk = 1.1, Speed = 14 },
		Look = {
			scale = 1.1,
			main = C(120, 100, 80),
			second = C(40, 35, 38),
			belly = C(140, 118, 92),
			eye = C(255, 220, 60),
			material = Enum.Material.Fabric,
			body = { len = 2.9, w = 1.3, h = 1.3, haunch = 0.9 },
			legs = { len = 1.15, thick = 0.34, lower = C(236, 226, 200) },
			head = { size = 1.35, snout = 1.05, snoutW = 0.75, lift = 0.6, long = 1.05 },
			mood = "evil",
			eyes = "glow",
			ears = "big",
			earSize = 1.2,
			earColor = C(236, 226, 200),
			earInner = C(40, 35, 38),
			tail = "bandage",
			extras = { bandages = C(236, 226, 200), wraps = C(236, 226, 200), eyeGlow = true, usekh = C(240, 190, 60), noBelly = true },
		},
	},
	shark_dog = {
		Name = "Shark Dog",
		Rarity = "Epic",
		Role = "Ambush",
		Special = "SharkDive",
		Stats = { HP = 1.15, Atk = 1.3, Speed = 18 },
		Look = {
			scale = 1.25,
			main = C(92, 132, 172),
			second = C(70, 102, 140),
			belly = C(242, 246, 250),
			eye = C(20, 20, 30),
			body = { len = 3.4, w = 1.45, h = 1.4, haunch = 0.85 },
			legs = { len = 0.85, thick = 0.38, paw = C(242, 246, 250) },
			head = { size = 1.5, snout = 1.25, snoutW = 1.15, lift = 0.15, forward = 0.2, shark = true },
			mood = "evil",
			eyes = "bead",
			ears = "none",
			tail = "shark",
			extras = { fin = true, gills = true, pecFins = true },
		},
	},
	alien_dog = {
		Name = "Alien Dog",
		Rarity = "Epic",
		Role = "Control",
		Special = "TractorBeam",
		Stats = { HP = 1, Atk = 1.3, Speed = 17 },
		Look = {
			scale = 1,
			main = C(120, 230, 140),
			second = C(70, 160, 100),
			belly = C(195, 255, 205),
			eye = C(140, 255, 220),
			body = { len = 2.4, w = 1.15, h = 1.15, chest = 0.95 },
			legs = { len = 1.3, thick = 0.22, noToes = true, paw = C(70, 160, 100) },
			head = { size = 1.9, snout = 0.3, snoutW = 0.6, lift = 0.6, tall = 1.15, w = 1.05, neckW = 0.5, noBridge = true },
			mood = "calm",
			eyes = "alien",
			ears = "none",
			tail = "thin",
			extras = { antenna = C(255, 90, 220), eyes3 = true, spots = C(70, 160, 100), spotCount = 8, aura = C(120, 255, 160) },
		},
	},
	ninja_dog = {
		Name = "Ninja Dog",
		Rarity = "Epic",
		Role = "Assassin",
		Special = "ShadowClones",
		Stats = { HP = 0.95, Atk = 1.35, Speed = 21 },
		Look = {
			scale = 1,
			main = C(38, 38, 48),
			second = C(28, 28, 34),
			belly = C(62, 62, 78),
			eye = C(255, 255, 255),
			body = { len = 2.9, w = 1.25, h = 1.25 },
			legs = { len = 1.05, thick = 0.32, socks = C(62, 62, 78), sockH = 0.3 },
			head = { size = 1.35, snout = 0.85, snoutW = 0.8, lift = 0.45 },
			mood = "fierce",
			eyes = "white",
			ears = "pointy",
			earSize = 0.95,
			tail = "thin",
			extras = { headband = C(210, 30, 40), headbandMark = true, hood = C(28, 28, 34), scarf = C(210, 30, 40), katana = true },
		},
	},
	------------------------------------------------------------ LEGENDARY
	dragon_hound = {
		Name = "Dragon Hound",
		Rarity = "Legendary",
		Role = "Fire",
		Special = "DragonBreath",
		Stats = { HP = 1.25, Atk = 1.3, Speed = 17 },
		Look = {
			scale = 1.45,
			main = C(175, 36, 36),
			second = C(95, 15, 22),
			belly = C(250, 192, 92),
			eye = C(255, 210, 40),
			body = { len = 3.5, w = 1.55, h = 1.45, chest = 1.2 },
			legs = { len = 1.05, thick = 0.48, claws = C(240, 232, 210) },
			head = { size = 1.5, snout = 1.35, snoutW = 0.9, lift = 0.6, neckW = 0.85, muzzle = C(175, 36, 36), throat = C(250, 192, 92) },
			neckColor = C(175, 36, 36),
			mood = "fierce",
			eyes = "glow",
			ears = "none",
			tail = "dragon",
			spikeColor = C(250, 192, 92),
			wingSize = 1.3,
			extras = { wings = "dragon", horns = "dragon", spikes = C(250, 192, 92), scales = true, eyeGlow = true, aura = C(255, 120, 40) },
		},
	},
	twin_fang = {
		Name = "Twin Fang",
		Rarity = "Legendary",
		Role = "Combo",
		Special = "DoubleAssault",
		Stats = { HP = 1.3, Atk = 1.3, Speed = 17 },
		Look = {
			scale = 1.4,
			main = C(62, 66, 82),
			second = C(205, 60, 60),
			belly = C(150, 155, 170),
			eye = C(255, 70, 70),
			body = { len = 3.2, w = 2.1, h = 1.55, chest = 1.3, saddle = C(42, 44, 56) },
			legs = { len = 1.1, thick = 0.46, claws = C(230, 230, 235) },
			head = { size = 1.3, snout = 1.0, lift = 0.65, forward = 0.25, neckW = 0.8, muzzle = C(150, 155, 170), cheeks = C(150, 155, 170) },
			mood = "evil",
			ears = "pointy",
			earColor = C(42, 44, 56),
			tail = "whip",
			heads = 2,
			extras = { spikedCollar = true, collar = C(205, 60, 60), eyeGlow = true, aura = C(255, 80, 80) },
		},
	},
	velocity_hound = {
		Name = "Velocity Hound",
		Rarity = "Legendary",
		Role = "Speed",
		Special = "SonicRush",
		Stats = { HP = 0.8, Atk = 1.25, Speed = 30 },
		Look = {
			scale = 0.6,
			main = C(245, 205, 45),
			second = C(210, 40, 40),
			belly = C(255, 242, 190),
			eye = C(255, 255, 255),
			body = { len = 3.1, w = 0.95, h = 1.0, chest = 1.05, haunch = 0.85 },
			legs = { len = 1.2, thick = 0.22, paw = C(210, 40, 40) },
			head = { size = 1.2, snout = 1.1, snoutW = 0.65, lift = 0.4, forward = 0.15, long = 1.1 },
			mood = "fierce",
			eyes = "white",
			ears = "swept",
			earColor = C(210, 40, 40),
			tail = "bolt",
			extras = { lines = C(255, 240, 80), goggles = C(80, 220, 255), trail = C(255, 220, 60), eyeGlow = true },
		},
	},
	storm_wolf = {
		Name = "Storm Wolf",
		Rarity = "Legendary",
		Role = "Assassin",
		Special = "ThunderHunt",
		Stats = { HP = 1.15, Atk = 1.35, Speed = 21 },
		Look = {
			scale = 1.4,
			main = C(42, 58, 115),
			second = C(22, 28, 64),
			belly = C(235, 240, 255),
			eye = C(120, 230, 255),
			body = { len = 3.4, w = 1.5, h = 1.5 },
			legs = { len = 1.2, thick = 0.42, claws = C(235, 240, 255), socks = C(235, 240, 255), sockH = 0.2 },
			head = {
				size = 1.45,
				snout = 1.15,
				snoutW = 0.85,
				lift = 0.55,
				face = C(235, 240, 255),
				muzzle = C(235, 240, 255),
				bridge = C(42, 58, 115),
				cheeks = C(235, 240, 255),
			},
			mood = "fierce",
			ears = "pointy",
			earSize = 1.1,
			earColor = C(22, 28, 64),
			tail = "sickle",
			tailTip = C(120, 230, 255),
			extras = { bolts = C(120, 230, 255), mane = C(30, 40, 90), spiky = true, tuft = C(30, 40, 90), eyeGlow = true, aura = C(120, 200, 255) },
		},
	},
	inferno_hound = {
		Name = "Inferno Hound",
		Rarity = "Legendary",
		Role = "Area",
		Special = "InfernoRing",
		Stats = { HP = 1.2, Atk = 1.35, Speed = 18 },
		Look = {
			scale = 1.4,
			main = C(42, 22, 22),
			second = C(255, 90, 20),
			belly = C(72, 32, 22),
			eye = C(255, 90, 20),
			body = { len = 3.3, w = 1.6, h = 1.5, chest = 1.15 },
			legs = { len = 1.1, thick = 0.46, claws = C(255, 120, 40) },
			head = { size = 1.45, snout = 1.0, snoutW = 0.9, lift = 0.5 },
			mood = "evil",
			ears = "pointy",
			earColor = C(30, 15, 15),
			earInner = C(255, 90, 20),
			tail = "flame",
			flameCore = C(255, 220, 90),
			hornColor = C(30, 15, 15),
			extras = {
				horns = "demon",
				flameMane = true,
				cracks = C(255, 90, 20),
				fire = C(255, 90, 20),
				legFire = C(255, 100, 20),
				spikes = C(30, 10, 10),
				eyeGlow = true,
			},
		},
	},
	shadow_doberman = {
		Name = "Shadow Doberman",
		Rarity = "Legendary",
		Role = "Illusionist",
		Special = "ShadowClones",
		Stats = { HP = 1.05, Atk = 1.45, Speed = 22 },
		Look = {
			scale = 1.3,
			main = C(26, 20, 36),
			second = C(120, 50, 200),
			belly = C(55, 30, 85),
			eye = C(210, 90, 255),
			body = { len = 3.3, w = 1.25, h = 1.35, chest = 1.12, haunch = 0.9 },
			legs = { len = 1.5, thick = 0.32, claws = C(170, 70, 255) },
			head = { size = 1.3, snout = 1.25, snoutW = 0.7, lift = 0.7, long = 1.08, brows = C(170, 70, 255), neckW = 0.85 },
			mood = "evil",
			ears = "cropped",
			earSize = 1.3,
			earInner = C(120, 50, 200),
			tail = "wisp",
			extras = { smoke = C(90, 40, 140), lines = C(170, 70, 255), wisps = true, eyeGlow = true },
		},
	},
	celestial_dog = {
		Name = "Celestial Dog",
		Rarity = "Legendary",
		Role = "Support",
		Special = "Starfall",
		Stats = { HP = 1.2, Atk = 1.3, Speed = 17 },
		Look = {
			scale = 1.25,
			main = C(252, 248, 236),
			second = C(255, 215, 120),
			belly = C(255, 255, 250),
			eye = C(120, 200, 255),
			body = { len = 3.0, w = 1.4, h = 1.4 },
			legs = { len = 1.0, thick = 0.38, paw = C(255, 215, 120) },
			head = { size = 1.45, snout = 0.8, lift = 0.5, eyeSize = 1.1 },
			mood = "calm",
			ears = "floppy",
			earSize = 1.15,
			earTip = C(255, 215, 120),
			tail = "fan",
			wingColors = { C(255, 255, 250), C(255, 245, 215), C(255, 215, 120) },
			extras = { halo = C(255, 230, 120), wings = "feather", float = 2.2, stars = true, gem = C(120, 200, 255), eyeGlow = true },
		},
	},
	------------------------------------------------------------ MYTHIC
	shadow_cerberus = {
		Name = "Shadow Cerberus",
		Rarity = "Mythic",
		Role = "Destroyer",
		Special = "HellGate",
		Stats = { HP = 1.4, Atk = 1.4, Speed = 17 },
		Look = {
			scale = 1.8,
			main = C(64, 50, 76),
			second = C(170, 26, 54),
			belly = C(88, 66, 98),
			eye = C(255, 40, 60),
			body = { len = 3.5, w = 2.4, h = 1.75, chest = 1.35 },
			legs = { len = 1.15, thick = 0.56, front = 1.15, claws = C(200, 30, 60), noToes = true },
			head = { size = 1.6, snout = 1.0, forward = 0.45, lift = 0.75, neckW = 0.85, muzzle = C(84, 64, 96), fangs = true },
			mood = "evil",
			ears = "pointy",
			earInner = C(200, 30, 60),
			tail = "whip",
			tailSize = 1.3,
			spikeColor = C(160, 24, 50),
			hornColor = C(170, 26, 54),
			heads = 3,
			extras = {
				horns = "small",
				smoke = C(60, 10, 30),
				spikedCollar = true,
				collar = C(90, 90, 100),
				spikes = C(140, 20, 45),
				mane = C(40, 30, 48),
				spiky = true,
				lines = C(255, 40, 70),
				spikeCount = 4,
				eyeGlow = true,
				aura = C(255, 40, 80),
			},
		},
	},
	titan_mastiff = {
		Name = "Titan Mastiff",
		Rarity = "Mythic",
		Role = "Colossus",
		Special = "TitanRage",
		Stats = { HP = 1.7, Atk = 1.3, Speed = 14 },
		Look = {
			scale = 2.3,
			main = C(125, 88, 62),
			second = C(125, 88, 62),
			belly = C(205, 175, 135),
			eye = C(255, 200, 60),
			body = { len = 3.2, w = 2.3, h = 1.9, chest = 1.4, haunch = 0.9 },
			legs = { len = 1.45, thick = 0.6, front = 1.2, claws = C(240, 232, 210) },
			head = {
				size = 1.75,
				snout = 0.75,
				snoutW = 1.3,
				forward = 0.45,
				lift = 0.85,
				jowls = true,
				wrinkles = true,
				muzzle = C(45, 32, 28),
				w = 1.08,
				neckW = 1.2,
				plate = C(225, 180, 70),
			},
			mood = "fierce",
			ears = "floppy",
			earSize = 0.85,
			earColor = C(50, 36, 30),
			tail = "thin",
			tailSize = 1.1,
			extras = {
				muscles = true,
				armor = C(225, 180, 70),
				spikedCollar = true,
				collar = C(60, 50, 50),
				chains = true,
				eyeGlow = true,
				aura = C(255, 200, 80),
			},
		},
	},
	cosmic_dog = {
		Name = "Cosmic Dog",
		Rarity = "Mythic",
		Role = "Cosmic",
		Special = "Starfall",
		Stats = { HP = 1.3, Atk = 1.5, Speed = 18 },
		Look = {
			scale = 1.5,
			main = C(42, 30, 95),
			second = C(150, 110, 255),
			belly = C(95, 60, 180),
			eye = C(255, 255, 255),
			body = { len = 3.2, w = 1.5, h = 1.5 },
			legs = { len = 0.95, thick = 0.4, paw = C(150, 110, 255), noToes = true },
			head = { size = 1.55, snout = 0.85, lift = 0.5, muzzle = C(95, 60, 180) },
			mood = "calm",
			ears = "big",
			earInner = C(150, 110, 255),
			tail = "stars",
			extras = { stars = true, galaxy = true, ring = C(255, 210, 140), halo = C(180, 140, 255), float = 3, eyeGlow = true, aura = C(170, 120, 255) },
		},
	},
	phoenix_hound = {
		Name = "Phoenix Hound",
		Rarity = "Mythic",
		Role = "Phoenix",
		Special = "PhoenixDive",
		Stats = { HP = 1.35, Atk = 1.45, Speed = 19 },
		Look = {
			scale = 1.5,
			main = C(255, 122, 32),
			second = C(255, 60, 20),
			belly = C(255, 222, 100),
			eye = C(255, 250, 200),
			body = { len = 3.1, w = 1.35, h = 1.35 },
			legs = { len = 1.05, thick = 0.34, claws = C(255, 222, 100), paw = C(255, 60, 20) },
			head = { size = 1.4, snout = 0.85, lift = 0.6 },
			mood = "fierce",
			ears = "swept",
			earColor = C(255, 60, 20),
			earInner = C(255, 222, 100),
			tail = "fan",
			wingSize = 1.15,
			wingColors = { C(255, 222, 100), C(255, 60, 20), C(255, 150, 40) },
			extras = { wings = "feather", crest = true, fire = C(255, 140, 30), eyeGlow = true, aura = C(255, 160, 40), float = 1.5 },
		},
	},
	void_beast = {
		Name = "Void Beast",
		Rarity = "Mythic",
		Role = "Gravity",
		Special = "VoidRift",
		Stats = { HP = 1.45, Atk = 1.45, Speed = 16 },
		Look = {
			scale = 1.9,
			main = C(42, 28, 66),
			second = C(130, 60, 230),
			belly = C(70, 40, 110),
			eye = C(200, 130, 255),
			body = { len = 3.5, w = 1.85, h = 1.65, chest = 1.25 },
			legs = { len = 1.3, thick = 0.42, claws = C(130, 60, 230), noToes = true },
			head = { size = 1.45, snout = 1.1, snoutW = 0.9, lift = 0.55, forward = 0.2 },
			mood = "evil",
			ears = "none",
			tail = "tentacles",
			extras = {
				horns = "void",
				spikes = C(130, 60, 230),
				smoke = C(60, 20, 120),
				lines = C(170, 90, 255),
				cracks = C(170, 90, 255),
				cracksHead = C(170, 90, 255),
				rift = true,
				eyes3 = true,
				eyeGlow = true,
				aura = C(150, 80, 255),
			},
		},
	},
	------------------------------------------------------------ BOSS-ONLY
	volcanic_cerberus = {
		Name = "Volcanic Cerberus",
		Rarity = "Mythic",
		Role = "Boss",
		Special = "FireBite",
		BossOnly = true,
		Stats = { HP = 1, Atk = 1, Speed = 15 },
		Look = {
			scale = 3.6,
			main = C(45, 25, 25),
			second = C(255, 90, 20),
			belly = C(90, 40, 30),
			eye = C(255, 200, 40),
			material = Enum.Material.Basalt,
			body = { len = 3.5, w = 2.4, h = 1.75, chest = 1.35 },
			legs = { len = 1.15, thick = 0.56, front = 1.15, claws = C(255, 120, 40), noToes = true },
			head = { size = 1.4, snout = 1.0, forward = 0.45, lift = 0.75, neckW = 0.85, muzzle = C(60, 34, 30) },
			mood = "evil",
			ears = "pointy",
			earColor = C(35, 20, 20),
			earInner = C(255, 90, 20),
			tail = "flame",
			flameCore = C(255, 220, 90),
			heads = 3,
			extras = {
				cracks = C(255, 110, 20),
				cracksHead = C(255, 110, 20),
				fire = C(255, 110, 20),
				horns = "demon",
				spikes = C(255, 90, 20),
				legFire = C(255, 110, 20),
				eyeGlow = true,
			},
		},
	},
}

-- Ordem de exibição (por raridade)
DogData.Order = {
	"caramelo",
	"pug",
	"pinscher",
	"poodle",
	"bulldog",
	"snow_husky",
	"armored_doberman",
	"boxer",
	"golden",
	"dalmatian",
	"storm_pup",
	"stone_hound",
	"robo_dog",
	"horned_pup",
	"skull_dog",
	"crystal_hound",
	"brute_bulldog",
	"samurai_shiba",
	"ghost_hound",
	"toxic_hound",
	"frost_beast",
	"magma_hound",
	"mummy_dog",
	"shark_dog",
	"alien_dog",
	"ninja_dog",
	"dragon_hound",
	"twin_fang",
	"velocity_hound",
	"storm_wolf",
	"inferno_hound",
	"shadow_doberman",
	"celestial_dog",
	"shadow_cerberus",
	"titan_mastiff",
	"cosmic_dog",
	"phoenix_hound",
	"void_beast",
}

-- Descrição dos Specials (mostrada na tela de cachorros)
DogData.Specials = {
	Pounce = { Name = "Pounce", Desc = "Crouches and leaps onto the target." },
	Charge = { Name = "Charge", Desc = "Lowers its head and rams the target with knockback." },
	Zoomies = { Name = "Zoomies", Desc = "Runs in crazy circles and bites over and over." },
	BoneToss = { Name = "Boomerang Bone", Desc = "Throws bones that fly back, hitting everything on the way." },
	FreezeHowl = { Name = "Frost Howl", Desc = "Howls and freezes everyone nearby." },
	FrozenDomain = { Name = "Frozen Domain", Desc = "Howls, ice spreads, it slides back and unleashes a wave that freezes everything." },
	ThunderHunt = { Name = "Thunder Hunt", Desc = "Crouches, charges up electricity, dashes through the target and lightning strikes." },
	GroundSlam = { Name = "Ground Slam", Desc = "Rears up and slams its paws down, sending out a shockwave." },
	LaserEyes = { Name = "Laser Eyes", Desc = "Locks on and sweeps the area with a laser." },
	CrystalSpikes = { Name = "Crystal Spikes", Desc = "Crystals burst from the ground in a line to the target." },
	SamuraiSlash = { Name = "Samurai Slash", Desc = "Three lightning-fast zigzag slashes." },
	ShadowClones = { Name = "Shadow Clones", Desc = "Turns into a shadow, 3 clones surround the target and the real one strikes from behind (crit)." },
	ToxicCloud = { Name = "Toxic Cloud", Desc = "Releases a poison cloud that deals damage over time." },
	InfernoRing = { Name = "Inferno Ring", Desc = "Growls, runs in a circle making a ring of fire, then leaps and blows up the area." },
	MummyBind = { Name = "Mummy Wrap", Desc = "Bandages pin the target in place." },
	SharkDive = { Name = "Shark Dive", Desc = "Dives underground with only its fin showing, then bursts up under the target." },
	TractorBeam = { Name = "Tractor Beam", Desc = "Lifts the target into the air and slams it down." },
	DragonBreath = { Name = "Dragon Breath", Desc = "Backs up, breathes a cone of fire and finishes with a tail strike." },
	DoubleAssault = { Name = "Double Assault", Desc = "The heads take turns attacking, then finish with a double bite." },
	SonicRush = { Name = "Sonic Rush", Desc = "Vanishes, trails slice across the arena and it hits the target from every side." },
	Starfall = { Name = "Starfall", Desc = "Floats up and rains stars down on enemies." },
	HellGate = { Name = "Hell Gate", Desc = "Opens a portal in the ground, all three heads attack and shadows rise around it." },
	TitanRage = { Name = "Titan Rage", Desc = "Roars, the ground shakes and it grows up to 4x. Every hit causes an impact." },
	PhoenixDive = { Name = "Phoenix Dive", Desc = "Soars high and dives in flames onto the target." },
	VoidRift = { Name = "Void Rift", Desc = "Opens a black hole that pulls everyone in and explodes." },
	FireBite = { Name = "Fire Bite", Desc = "Flaming bites from all three heads." },
}

---------------------------------------------------------------- Ovos
-- Cada ovo sorteia uma RARIDADE e depois um cachorro daquela raridade.
DogData.Eggs = {
	paw = { Name = "Paw Egg", Color = Color3.fromRGB(235, 220, 190), Spots = Color3.fromRGB(150, 110, 70), Odds = { Common = 78, Uncommon = 20, Rare = 2 } },
	spotted = {
		Name = "Spotted Egg",
		Color = Color3.fromRGB(220, 250, 220),
		Spots = Color3.fromRGB(70, 170, 90),
		Odds = { Common = 35, Uncommon = 50, Rare = 13, Epic = 2 },
	},
	blue = {
		Name = "Blue Egg",
		Color = Color3.fromRGB(110, 170, 255),
		Spots = Color3.fromRGB(230, 240, 255),
		Odds = { Uncommon = 35, Rare = 50, Epic = 13, Legendary = 2 },
	},
	crystal = {
		Name = "Crystal Egg",
		Color = Color3.fromRGB(190, 130, 255),
		Spots = Color3.fromRGB(255, 220, 255),
		Glass = true,
		Odds = { Rare = 45, Epic = 44, Legendary = 10, Mythic = 1 },
	},
	golden = {
		Name = "Golden Egg",
		Color = Color3.fromRGB(255, 200, 40),
		Spots = Color3.fromRGB(255, 250, 200),
		Shiny = true,
		Odds = { Epic = 55, Legendary = 43, Mythic = 2 },
	},
	celestial = {
		Name = "Celestial Egg",
		Color = Color3.fromRGB(60, 40, 140),
		Spots = Color3.fromRGB(255, 255, 255),
		Shiny = true,
		Odds = { Legendary = 75, Mythic = 25 },
	},
	-- ☁️ Reino das Nuvens: só sai cachorro que VOA (elemento Fly)
	-- 🎃 Halloween: o único ovo com o Spooky Clown (2% — fora isso, Épicos, Lendários e Míticos)
	halloween = {
		Name = "Spooky Egg",
		Color = Color3.fromRGB(70, 30, 100),
		Spots = Color3.fromRGB(255, 130, 30),
		Shiny = true,
		Odds = { Epic = 52, Legendary = 38, Mythic = 8, Halloween = 2 },
	},
	sky = {
		Name = "Sky Egg",
		Color = Color3.fromRGB(244, 249, 255),
		Spots = Color3.fromRGB(156, 203, 255),
		Shiny = true,
		Pool = "Fly",
		Odds = { Rare = 40, Epic = 38, Legendary = 19, Mythic = 3 },
	},
}

-- Level alto melhora um pouco as chances: até +5 pontos tirados da raridade mais baixa e
-- divididos entre as duas mais altas do ovo.
-- Chances (%) de cada raridade para um ovo. Level alto melhora um pouco: até +5 pontos tirados da
-- raridade mais baixa e divididos entre as duas mais altas do ovo. Usado no sorteio e na tela do inventário.
local RARITY_ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Halloween" }
-- luck = pontos de sorte da loja (🍀 Lucky Paw / Lucky Rush: Monetization.LuckOf), somados ao bônus do level
function DogData.EggOdds(eggId, dogLevel, luck)
	local egg = DogData.Eggs[eggId]
	local odds = table.clone(egg.Odds)
	local present = {}
	for _, rarity in ipairs(RARITY_ORDER) do
		if odds[rarity] then
			table.insert(present, rarity)
		end
	end
	if #present >= 2 then
		local bonus = math.min(5, math.floor((dogLevel or 1) / 10))
		local lowest, top, second = present[1], present[#present], present[#present - 1]
		local room = math.max(0, odds[lowest] - 1)
		bonus = math.min(bonus, room)
		local extra = math.min(math.max(0, tonumber(luck) or 0), room - bonus)
		odds[lowest] -= bonus + extra
		odds[top] += bonus * 0.4 + extra * 0.5
		odds[second] += bonus * 0.6 + extra * 0.5
	end
	local total = 0
	for _, w in pairs(odds) do
		total += w
	end
	local result = {}
	for _, rarity in ipairs(present) do
		table.insert(result, { Rarity = rarity, Chance = odds[rarity] / total * 100 })
	end
	return result
end

function DogData.RollRarity(eggId, dogLevel, rng, luck)
	local list = DogData.EggOdds(eggId, dogLevel, luck)
	local roll = (rng or Random.new()):NextNumber() * 100
	for _, entry in ipairs(list) do
		roll -= entry.Chance
		if roll <= 0 then
			return entry.Rarity
		end
	end
	return list[#list].Rarity
end

function DogData.SpeciesOfRarity(rarity)
	local list = {}
	for _, id in ipairs(DogData.Order) do
		if DogData.Species[id].Rarity == rarity then
			table.insert(list, id)
		end
	end
	return list
end

-- espécies de uma raridade que têm o elemento (ex.: "Fly" = voam de verdade)
function DogData.SpeciesWithElement(rarity, element)
	local list = {}
	for _, id in ipairs(DogData.SpeciesOfRarity(rarity)) do
		if table.find(DogData.ElementsOf(id), element) then
			table.insert(list, id)
		end
	end
	return list
end

function DogData.RollSpecies(eggId, dogLevel, luck)
	local rng = Random.new()
	local egg = DogData.Eggs[eggId]
	for _ = 1, 8 do
		local rarity = DogData.RollRarity(eggId, dogLevel, rng, luck)
		local list = (egg and egg.Pool) and DogData.SpeciesWithElement(rarity, egg.Pool) or DogData.SpeciesOfRarity(rarity)
		if #list > 0 then
			return list[rng:NextInteger(1, #list)], rarity
		end
	end
	local list = DogData.SpeciesOfRarity("Common")
	return list[rng:NextInteger(1, #list)], "Common"
end

---------------------------------------------------------------- NPCs da arena
DogData.ArenaNPCs = {
	-- Escada de dificuldade para a Arena grande (raio 110): 25 NPCs, Power ~x1.3-1.6 por degrau, cobrindo
	-- do starter Lv.1 até Míticos Lv.70. Recompensa = Config.KillReward(Level, Power, levelDoVencedor).
	-- Valores com o multiplicador padrão do NPCService (0.75 de vida/ataque):
	-- (vitória contra o mesmo level): Street Dog P36 $11 4XP · Stray Bulldog P60 $14 12XP · Wild Husky P103 $21 14XP
	--   Wild Storm Pup P229 $38 28XP · Wild Frost Beast P630 $87 90XP · Wild Inferno Hound P1867 $224 254XP
	--   Alpha Shadow Cerberus P4840 $522 606XP · Ancient Cosmic Dog P8387 $854 1446XP
	{ Name = "Street Dog", Species = "caramelo", Level = 1, Count = 3 },
	{ Name = "Wild Pug", Species = "pug", Level = 2, Count = 2 },
	{ Name = "Wild Pinscher", Species = "pinscher", Level = 4, Count = 2 },
	{ Name = "Stray Bulldog", Species = "bulldog", Level = 6, Count = 2 },
	{ Name = "Wild Husky", Species = "snow_husky", Level = 6, Count = 2 },
	{ Name = "Wild Boxer", Species = "boxer", Level = 9, Count = 1 },
	{ Name = "Wild Storm Pup", Species = "storm_pup", Level = 9, Count = 2 },
	{ Name = "Stone Hound", Species = "stone_hound", Level = 13, Count = 1 },
	{ Name = "Wild Skull Dog", Species = "skull_dog", Level = 17, Count = 1 },
	{ Name = "Wild Frost Beast", Species = "frost_beast", Level = 17, Count = 1 },
	{ Name = "Wild Toxic Hound", Species = "toxic_hound", Level = 22, Count = 1 },
	{ Name = "Wild Ninja Dog", Species = "ninja_dog", Level = 28, Count = 1 },
	{ Name = "Wild Inferno Hound", Species = "inferno_hound", Level = 28, Count = 1 },
	{ Name = "Alpha Storm Wolf", Species = "storm_wolf", Level = 36, Count = 1 },
	{ Name = "Alpha Shadow Cerberus", Species = "shadow_cerberus", Level = 42, Count = 1 },
	{ Name = "Alpha Dragon Hound", Species = "dragon_hound", Level = 45, Count = 1 },
	{ Name = "Ancient Titan Mastiff", Species = "titan_mastiff", Level = 55, Count = 1 },
	{ Name = "Ancient Cosmic Dog", Species = "cosmic_dog", Level = 70, Count = 1 },
}

---------------------------------------------------------------- Bosses (Boss Tower)
-- Cachorro que desmaia na torre volta para a casinha (não renasce na luta), então cada boss é feito para
-- UM jogador com RecommendedPower vencer sozinho em ~90 s terminando com ~25% da vida (bosses são "esponjas":
-- muita vida, mordida fraca, poderes de área fortes). Em grupo fica bem mais fácil.
-- Recompensa: Config.BossReward (Cash + XP, divididos pela parte do dano).
-- 👑 ESCADA DE 12 CHEFES (2026-10): vencer um libera o próximo (data.BossBeaten). Mais chefes = mais
-- forte e prêmio maior. Lacaios aparecem nas fases e há ataques com aviso no chão (BossService).
DogData.Bosses = {
	{
		Id = "thunder_king",
		Name = "Thunder King",
		Species = "storm_wolf",
		Scale = 2.4,
		Level = 20,
		HPMult = 4.5,
		AtkMult = 0.018,
		Reward = 700,
		RecommendedPower = 600,
		Phases = { { At = 1, Specials = { "ThunderHunt" } }, { At = 0.5, Specials = { "ThunderHunt", "LightningStorm" } } },
	},
	{
		Id = "frost_titan",
		Name = "Frost Titan",
		Species = "frost_beast",
		Scale = 2.4,
		Level = 25,
		HPMult = 5.0,
		AtkMult = 0.021,
		Reward = 1100,
		RecommendedPower = 900,
		Phases = { { At = 1, Specials = { "El_Ice_Bolt", "FreezeHowl" } }, { At = 0.5, Specials = { "El_Ice_Nova", "Ult_Ice_Rain" } } },
	},
	{
		Id = "werewolf_alpha",
		Name = "Werewolf Alpha",
		Species = "werewolf_dog",
		Scale = 2.3,
		Level = 30,
		HPMult = 5.4,
		AtkMult = 0.024,
		Reward = 1600,
		RecommendedPower = 1400,
		Phases = { { At = 1, Specials = { "SamuraiSlash", "El_Shadow_Rush" } }, { At = 0.5, Specials = { "El_Shadow_Volley", "Ult_Shadow_Slam" } } },
	},
	{
		Id = "volcanic_cerberus",
		Name = "Volcanic Cerberus",
		Species = "volcanic_cerberus",
		Scale = 1,
		Level = 35,
		HPMult = 5.9,
		AtkMult = 0.028,
		Reward = 2200,
		RecommendedPower = 2000,
		Phases = { { At = 1, Specials = { "FireBite" } }, { At = 0.66, Specials = { "FireBite", "Meteor" } }, { At = 0.33, Specials = { "Meteor", "LavaFloor", "FireBite" } } },
	},
	{
		Id = "kraken_lord",
		Name = "Kraken Lord",
		Species = "octopus_dog",
		Scale = 2.4,
		Level = 40,
		HPMult = 6.3,
		AtkMult = 0.03,
		Reward = 3200,
		RecommendedPower = 2800,
		Phases = { { At = 1, Specials = { "El_Water_Volley", "El_Water_Beam" } }, { At = 0.5, Specials = { "Ult_Water_Vortex", "El_Water_Rain" } } },
	},
	{
		Id = "yeti_king",
		Name = "Yeti King",
		Species = "yeti_dog",
		Scale = 2.5,
		Level = 45,
		HPMult = 6.7,
		AtkMult = 0.031,
		Reward = 4300,
		RecommendedPower = 3700,
		Phases = { { At = 1, Specials = { "GroundSlam", "El_Ice_Nova" } }, { At = 0.66, Specials = { "Ult_Ice_Slam", "FreezeHowl" } }, { At = 0.33, Specials = { "Ult_Ice_Slam", "Ult_Ice_Rain" } } },
	},
	{
		Id = "dragon_emperor",
		Name = "Dragon Emperor",
		Species = "dragon_hound",
		Scale = 2.3,
		Level = 50,
		HPMult = 7.0,
		AtkMult = 0.033,
		Reward = 5600,
		RecommendedPower = 4700,
		Phases = { { At = 1, Specials = { "DragonBreath", "El_Fire_Rain" } }, { At = 0.5, Specials = { "Ult_Fire_Beam", "Meteor", "DragonBreath" } } },
	},
	{
		Id = "void_titan",
		Name = "Void Titan",
		Species = "void_beast",
		Scale = 2.2,
		Level = 55,
		HPMult = 7.2,
		AtkMult = 0.034,
		Reward = 6500,
		RecommendedPower = 5500,
		Phases = { { At = 1, Specials = { "VoidRift" } }, { At = 0.5, Specials = { "VoidRift", "TitanRage", "Meteor" } } },
	},
	{
		Id = "archmage",
		Name = "Archmage",
		Species = "wizard_dog",
		Scale = 2.4,
		Level = 60,
		HPMult = 7.8,
		AtkMult = 0.037,
		Reward = 8800,
		RecommendedPower = 7400,
		Phases = { { At = 1, Specials = { "El_Light_Beam", "LightningStorm" } }, { At = 0.66, Specials = { "Ult_Light_Rain", "El_Thunder_Volley" } }, { At = 0.33, Specials = { "Ult_Thunder_Rain", "Ult_Light_Beam" } } },
	},
	{
		Id = "shadow_cerberus",
		Name = "Shadow Cerberus",
		Species = "shadow_cerberus",
		Scale = 2.0,
		Level = 65,
		HPMult = 8.4,
		AtkMult = 0.04,
		Reward = 11500,
		RecommendedPower = 9600,
		Phases = { { At = 1, Specials = { "ShadowClones", "El_Shadow_Vortex" } }, { At = 0.5, Specials = { "Ult_Shadow_Rain", "Ult_Shadow_Vortex", "HellGate" } } },
	},
	{
		Id = "phoenix_god",
		Name = "Phoenix God",
		Species = "phoenix_hound",
		Scale = 2.2,
		Level = 72,
		HPMult = 9.2,
		AtkMult = 0.044,
		Reward = 15500,
		RecommendedPower = 13000,
		Phases = { { At = 1, Specials = { "PhoenixDive", "El_Fire_Volley" } }, { At = 0.66, Specials = { "Meteor", "Ult_Fire_Rain" } }, { At = 0.33, Specials = { "Ult_Fire_Slam", "LavaFloor", "Meteor" } } },
	},
	{
		Id = "cosmic_overlord",
		Name = "Cosmic Overlord",
		Species = "cosmic_dog",
		Scale = 2.6,
		Level = 80,
		HPMult = 10.5,
		AtkMult = 0.05,
		Reward = 22000,
		RecommendedPower = 18500,
		Phases = { { At = 1, Specials = { "Starfall", "VoidRift" } }, { At = 0.66, Specials = { "Ult_Light_Beam", "Meteor", "Starfall" } }, { At = 0.33, Specials = { "Supreme_Light", "Ult_Shadow_Rain", "VoidRift" } } },
	},
}
DogData.BOSS_TIME = 180

---------------------------------------------------------------- Pacotes extras de cachorros
-- Cada ModuleScript em Shared/DogPacks retorna { Species = {...}, Order = {...}, Specials = {...} }.
-- Assim vários criadores podem adicionar cachorros sem mexer neste arquivo.
do
	local packs = script.Parent:FindFirstChild("DogPacks")
	if packs then
		local list = packs:GetChildren()
		table.sort(list, function(a, b)
			return a.Name < b.Name
		end)
		for _, module in ipairs(list) do
			if module:IsA("ModuleScript") then
				local ok, pack = pcall(require, module)
				if ok and type(pack) == "table" then
					for id, species in pairs(pack.Species or {}) do
						DogData.Species[id] = species
					end
					for _, id in ipairs(pack.Order or {}) do
						if DogData.Species[id] and not table.find(DogData.Order, id) then
							table.insert(DogData.Order, id)
						end
					end
					for name, info in pairs(pack.Specials or {}) do
						DogData.Specials[name] = info
					end
				else
					warn("[DogData] invalid pack", module.Name, pack)
				end
			end
		end
	end
end

-- 🐾 PODERES 2 e 3 de cada cachorro (pedido do dono: "tem vários com o mesmo golpe, faça vários").
-- Além dos poderes de cada espécie, existem 64 poderes ELEMENTAIS (8 elementos × 8 formas,
-- Services/SpecialsPacks/PackElements). Cada cachorro recebe 2 poderes, distribuídos para quase
-- ninguém repetir: o poder da espécie fica como 2 se ainda ninguém o usa; senão vira um elemental.
-- O elemento combina com o cachorro pelo nome (gelo, fogo, raio...).
-- (2026-10) + Wind, Fly e Nature: os 11 elementos dos cachorros (DOG_ELEMENTS) têm poderes próprios
DogData.ELEMENT_ORDER = { "Fire", "Ice", "Thunder", "Poison", "Water", "Shadow", "Earth", "Light", "Wind", "Fly", "Nature" }
DogData.SHAPE_ORDER = { "Bolt", "Nova", "Rush", "Rain", "Beam", "Slam", "Vortex", "Volley" }
DogData.ELEMENTS = {
	Fire = { Name = "Flame", Color = Color3.fromRGB(255, 120, 40), Effect = "burns" },
	Ice = { Name = "Frost", Color = Color3.fromRGB(150, 220, 255), Effect = "freezes" },
	Thunder = { Name = "Thunder", Color = Color3.fromRGB(255, 235, 90), Effect = "strikes twice with lightning" },
	Poison = { Name = "Toxic", Color = Color3.fromRGB(140, 230, 70), Effect = "poisons" },
	Water = { Name = "Tidal", Color = Color3.fromRGB(70, 160, 255), Effect = "launches into the air" },
	Shadow = { Name = "Shadow", Color = Color3.fromRGB(150, 80, 220), Effect = "always lands a critical hit" },
	Earth = { Name = "Stone", Color = Color3.fromRGB(170, 130, 80), Effect = "stuns" },
	Light = { Name = "Holy", Color = Color3.fromRGB(255, 250, 200), Effect = "heals you" },
	Wind = { Name = "Gale", Color = Color3.fromRGB(180, 240, 225), Effect = "blows enemies far away" },
	Fly = { Name = "Sky", Color = Color3.fromRGB(215, 235, 255), Effect = "strikes again from the sky" },
	Nature = { Name = "Wild", Color = Color3.fromRGB(90, 200, 90), Effect = "roots enemies in vines and heals you" },
}
local SHAPES = {
	Bolt = { Name = "Bolt", Desc = "Spits a ball that explodes on the target" },
	Nova = { Name = "Nova", Desc = "Blasts everything around" },
	Rush = { Name = "Rush", Desc = "Dashes into the target and explodes" },
	Rain = { Name = "Rain", Desc = "Makes it rain from the sky around the target" },
	Beam = { Name = "Beam", Desc = "Fires a long beam" },
	Slam = { Name = "Slam", Desc = "Jumps high and slams the ground" },
	Vortex = { Name = "Vortex", Desc = "A vortex pulls enemies in and hurts them" },
	Volley = { Name = "Volley", Desc = "Shoots three balls in a fan" },
}
DogData.BIG_SHAPES = { "Rain", "Vortex", "Slam", "Beam" }
-- 💥 ULTIMATE (habilidade 3) e 👑 SUPREMO (habilidade 4, só Míticos) de cada elemento
local ULT_NAMES = {
	Fire = { "Inferno", "Apocalypse" },
	Ice = { "Glacier", "Eruption" },
	Thunder = { "Thunder God", "Wrath" },
	Poison = { "Plague", "Storm" },
	Water = { "Tsunami", "Fury" },
	Shadow = { "Void", "Massacre" },
	Earth = { "Earthquake", "Titan" },
	Light = { "Divine", "Judgment" },
	Wind = { "Hurricane", "Fury" },
	Fly = { "Skyfall", "Dive" },
	Nature = { "Overgrowth", "Bloom" },
}
local ULT_SHAPE_WORD = { Rain = "Storm", Vortex = "Cyclone", Slam = "Crash", Beam = "Cannon" }
for _, e in ipairs(DogData.ELEMENT_ORDER) do
	local un = ULT_NAMES[e]
	for _, sh in ipairs(DogData.BIG_SHAPES) do
		DogData.Specials["Ult_" .. e .. "_" .. sh] = {
			Name = un[1] .. " " .. ULT_SHAPE_WORD[sh],
			Desc = "ULTIMATE: " .. string.lower(DogData.ELEMENTS[e].Name) .. " erupts from the ground, then a huge " .. string.lower(sh) .. " and a final blast.",
			Element = e,
		}
	end
	DogData.Specials["Supreme_" .. e] = {
		Name = "SUPREME " .. string.upper(un[1] .. " " .. un[2]),
		Desc = "Charges while you fight. The sky falls: meteors, lightning and a giant explosion.",
		Element = e,
	}
end
for _, e in ipairs(DogData.ELEMENT_ORDER) do
	for _, sh in ipairs(DogData.SHAPE_ORDER) do
		local el = DogData.ELEMENTS[e]
		DogData.Specials["El_" .. e .. "_" .. sh] = {
			Name = el.Name .. " " .. SHAPES[sh].Name,
			Desc = SHAPES[sh].Desc .. " and " .. el.Effect .. ".",
			Element = e,
		}
	end
end

local ELEMENT_WORDS = {
	Fire = { "fire", "flame", "lava", "inferno", "phoenix", "dragon", "magma", "volcan", "blaze", "ember", "hell", "sun" },
	Ice = { "ice", "frost", "snow", "glaci", "frozen", "polar", "yeti", "husky", "winter", "crystal" },
	Thunder = { "thunder", "storm", "volt", "light" .. "ning", "spark", "electr", "zap", "sonic", "speed" },
	Poison = { "toxic", "poison", "venom", "slime", "acid", "bee", "sting", "swamp", "zombie" },
	Water = { "water", "aqua", "shark", "kraken", "ocean", "sea", "tide", "wave", "pirate", "hydra" },
	Shadow = { "shadow", "void", "dark", "ghost", "night", "ninja", "mummy", "cerber", "abyss", "phantom", "spect" },
	Earth = { "rock", "stone", "earth", "golem", "titan", "mud", "bull", "tank", "mecha", "robot", "metal" },
	Light = { "light", "star", "angel", "holy", "cosmic", "celest", "astro", "moon", "gold", "unicorn", "rainbow" },
	Wind = { "wind", "gale", "breeze", "tornado", "swift" },
	Fly = { "wing", "sky", "bird", "feather", "balloon" },
	Nature = { "leaf", "plant", "flower", "forest", "mushroom", "cactus", "vine" },
}
local function elementFor(id, species)
	local text = string.lower(id .. " " .. (species.Name or ""))
	for _, e in ipairs(DogData.ELEMENT_ORDER) do
		for _, w in ipairs(ELEMENT_WORDS[e]) do
			if string.find(text, w, 1, true) then
				return e
			end
		end
	end
	local h = 0
	for i = 1, #id do
		h = (h * 31 + string.byte(id, i)) % 9973
	end
	return DogData.ELEMENT_ORDER[h % #DogData.ELEMENT_ORDER + 1]
end

---------------------------------------------------------------- 🌈 ELEMENTOS DOS CACHORROS
-- Pedido do dono: cada cachorro tem 1 elemento (alguns 2, e os mais especiais 3). Fly = os que voam de verdade (asas). Aparece no DOGS, no
-- Índice, na tela do ovo e na plaquinha. A habilidade 3 é o ULTIMATE do elemento ou a FUSÃO dos elementos
-- (ver "FUSÃO DE ELEMENTOS" mais abaixo).
DogData.DOG_ELEMENT_ORDER = { "Fire", "Water", "Ice", "Thunder", "Wind", "Fly", "Earth", "Nature", "Poison", "Shadow", "Light" }
DogData.DOG_ELEMENTS = {
	Fire = { Name = "Fire", Icon = "🔥", Color = C(255, 120, 40) },
	Water = { Name = "Water", Icon = "💧", Color = C(70, 160, 255) },
	Ice = { Name = "Ice", Icon = "❄️", Color = C(150, 220, 255) },
	Thunder = { Name = "Thunder", Icon = "⚡", Color = C(255, 220, 60) },
	Wind = { Name = "Wind", Icon = "🌪️", Color = C(180, 235, 220) },
	Fly = { Name = "Fly", Icon = "🦅", Color = C(200, 230, 255) },
	Earth = { Name = "Earth", Icon = "⛰️", Color = C(170, 130, 80) },
	Nature = { Name = "Nature", Icon = "🌿", Color = C(90, 200, 90) },
	Poison = { Name = "Poison", Icon = "☠️", Color = C(150, 90, 220) },
	Shadow = { Name = "Shadow", Icon = "🌑", Color = C(110, 70, 160) },
	Light = { Name = "Light", Icon = "✨", Color = C(255, 240, 160) },
}

DogData.SPECIES_ELEMENTS = {
	-- Comuns
	caramelo = { "Earth" },
	pug = { "Earth" },
	pinscher = { "Wind" },
	poodle = { "Wind" },
	bulldog = { "Earth" },
	beagle = { "Nature" },
	corgi = { "Wind" },
	salsicha = { "Earth" },
	chihuahua = { "Wind" },
	-- Incomuns
	snow_husky = { "Ice" },
	armored_doberman = { "Earth" },
	boxer = { "Wind" },
	golden = { "Light" },
	dalmatian = { "Water" },
	pastor_alemao = { "Thunder" },
	border_collie = { "Wind" },
	sao_bernardo = { "Ice" },
	akita = { "Earth" },
	galgo = { "Wind" },
	-- Raros
	storm_pup = { "Thunder" },
	stone_hound = { "Earth" },
	robo_dog = { "Thunder" },
	horned_pup = { "Earth" },
	skull_dog = { "Shadow" },
	crystal_hound = { "Ice", "Light" },
	cactus_dog = { "Nature", "Earth" },
	bee_dog = { "Poison", "Fly" },
	balloon_dog = { "Fly" },
	windup_dog = { "Thunder" },
	mushroom_dog = { "Nature", "Poison" },
	-- Épicos
	brute_bulldog = { "Earth" },
	samurai_shiba = { "Wind" },
	ghost_hound = { "Shadow" },
	toxic_hound = { "Poison" },
	frost_beast = { "Ice" },
	magma_hound = { "Fire", "Earth" },
	mummy_dog = { "Shadow", "Earth" },
	shark_dog = { "Water" },
	alien_dog = { "Light" },
	ninja_dog = { "Shadow", "Wind" },
	pirate_dog = { "Water" },
	scorpion_dog = { "Poison", "Earth" },
	flytrap_dog = { "Nature" },
	dj_dog = { "Thunder" },
	knight_dog = { "Light" },
	armadillo_dog = { "Earth" },
	saber_dog = { "Ice" },
	-- Lendários
	dragon_hound = { "Fire", "Fly" },
	twin_fang = { "Shadow", "Light" },
	velocity_hound = { "Wind", "Thunder" },
	storm_wolf = { "Thunder", "Wind" },
	inferno_hound = { "Fire" },
	shadow_doberman = { "Shadow" },
	celestial_dog = { "Light", "Fly" },
	astronaut_dog = { "Light", "Fire" },
	yeti_dog = { "Ice", "Earth" },
	werewolf_dog = { "Shadow" },
	octopus_dog = { "Water", "Shadow" },
	tank_dog = { "Earth", "Fire" },
	wizard_dog = { "Fire", "Ice", "Thunder" },
	-- Míticos
	shadow_cerberus = { "Shadow", "Fire" },
	titan_mastiff = { "Earth", "Light" },
	cosmic_dog = { "Light", "Shadow" },
	phoenix_hound = { "Fire", "Fly" },
	void_beast = { "Shadow" },
	volcanic_cerberus = { "Fire", "Earth" },
	hydra_hound = { "Poison", "Water" },
	bone_dragon = { "Shadow", "Fly" },
	kraken_hound = { "Water", "Shadow" },
	chrono_hound = { "Light", "Thunder" },
	singularity_pup = { "Shadow", "Earth" },
	seraph_hound = { "Light", "Fly" },
	crystal_golem = { "Earth", "Ice" },
	frost_phoenix = { "Ice", "Fly" },
	thunder_colossus = { "Thunder", "Earth" },
	rainbow_unicorn = { "Light", "Water" },
	demon_samurai = { "Fire", "Wind" },
	mecha_hound = { "Thunder", "Fire" },
	planet_hound = { "Earth", "Water", "Nature" },
	-- Divino
	sun_dragon = { "Fire", "Light", "Fly" },
	-- 🎃 Halloween
	clown_dog = { "Shadow", "Fire" },
}

-- 🆚 VANTAGEM DE ELEMENTO (pedido do dono, estilo Pokémon): cada elemento bate FORTE em 2 outros.
-- Golpe forte = Config.ELEMENT_STRONG do dano ("SUPER!"); se o alvo é forte contra quem bate = Config.ELEMENT_WEAK.
DogData.ELEMENT_STRONG = {
	Fire = { "Ice", "Nature" }, -- derrete o gelo, queima as plantas
	Water = { "Fire", "Earth" }, -- apaga o fogo, vira lama
	Ice = { "Fly", "Wind" }, -- congela as asas e o vento
	Thunder = { "Water", "Fly" }, -- eletrifica a água, derruba quem voa
	Wind = { "Fire", "Poison" }, -- apaga o fogo, espalha o veneno
	Fly = { "Nature", "Earth" }, -- de cima, a terra e as plantas não alcançam
	Earth = { "Thunder", "Poison" }, -- aterra o raio, enterra o veneno
	Nature = { "Water", "Earth" }, -- bebe a água, racha a pedra com raízes
	Poison = { "Nature", "Water" }, -- mata as plantas, contamina a água
	Shadow = { "Light", "Thunder" }, -- engole a luz e a energia
	Light = { "Shadow", "Poison" }, -- espanta a sombra, purifica o veneno
}

local function strongVs(a, d)
	local list = DogData.ELEMENT_STRONG[a]
	return list ~= nil and table.find(list, d) ~= nil
end

-- lista de elementos do cachorro (sempre pelo menos 1)
function DogData.ElementsOf(speciesId)
	local list = speciesId and DogData.SPECIES_ELEMENTS[speciesId]
	if list and #list > 0 then
		return list
	end
	local sp = speciesId and DogData.Species[speciesId]
	return { sp and elementFor(speciesId, sp) or "Earth" }
end

-- "🔥🪨" (short) ou "🔥 Fire + 🪨 Earth"
function DogData.ElementLabel(speciesId, short)
	local parts = {}
	for _, e in ipairs(DogData.ElementsOf(speciesId)) do
		local info = DogData.DOG_ELEMENTS[e]
		if info then
			table.insert(parts, short and info.Icon or (info.Icon .. " " .. info.Name))
		end
	end
	return table.concat(parts, short and "" or " + ")
end

-- pontos de vantagem do atacante contra o alvo: +1 por par forte, −1 por par fraco (cache por dupla)
local advantageCache = {}
function DogData.ElementAdvantage(attackerId, targetId)
	if not attackerId or not targetId then
		return 0
	end
	local key = attackerId .. ">" .. targetId
	local cached = advantageCache[key]
	if cached then
		return cached
	end
	local score = 0
	for _, a in ipairs(DogData.ElementsOf(attackerId)) do
		for _, d in ipairs(DogData.ElementsOf(targetId)) do
			if strongVs(a, d) then
				score += 1
			elseif strongVs(d, a) then
				score -= 1
			end
		end
	end
	advantageCache[key] = score
	return score
end

-- elementos contra quem este cachorro é forte / fraco (para mostrar no menu)
function DogData.StrongWeakLabel(speciesId)
	local mine = DogData.ElementsOf(speciesId)
	local strong, weak = {}, {}
	for _, e in ipairs(DogData.DOG_ELEMENT_ORDER) do
		local s, w = 0, 0
		for _, a in ipairs(mine) do
			if strongVs(a, e) then
				s += 1
			elseif strongVs(e, a) then
				w += 1
			end
		end
		local icon = DogData.DOG_ELEMENTS[e].Icon
		if s > w then
			table.insert(strong, icon)
		elseif w > s then
			table.insert(weak, icon)
		end
	end
	return table.concat(strong, ""), table.concat(weak, "")
end

---------------------------------------------------------------- 🌀 FUSÃO DE ELEMENTOS
-- Pedido do dono: as habilidades seguem os ELEMENTOS do cachorro; quem tem 2 ou 3 elementos solta um golpe
-- que JUNTA os elementos. Nome próprio para cada combinação (chave = elementos em ordem alfabética).
local FUSION_NAMES = {
	["Earth+Fire"] = { "Magma Burst", "MAGMA CATACLYSM" },
	["Earth+Ice"] = { "Glacier Quake", "PERMAFROST" },
	["Earth+Light"] = { "Golden Titan Strike", "TITAN'S JUDGMENT" },
	["Earth+Nature"] = { "Thorn Quake", "WILD EARTH" },
	["Earth+Nature+Water"] = { "World Bloom", "LIVING PLANET" },
	["Earth+Poison"] = { "Toxic Sands", "VENOM DESERT" },
	["Earth+Shadow"] = { "Grave Quake", "ABYSS COLLAPSE" },
	["Earth+Thunder"] = { "Thunder Quake", "STORM TITAN" },
	["Fire+Fly"] = { "Blazing Wings", "PHOENIX SKYFALL" },
	["Fire+Ice+Thunder"] = { "Elemental Trinity", "ARCANE TRINITY" },
	["Fire+Light"] = { "Solar Flare", "SUPERNOVA" },
	["Fire+Fly+Light"] = { "Sunfire Nova", "DIVINE SUNFIRE" },
	["Fire+Shadow"] = { "Hellfire", "INFERNO OF SHADOWS" },
	["Fire+Thunder"] = { "Plasma Storm", "PLASMA OVERLOAD" },
	["Fire+Wind"] = { "Firestorm", "BLAZING TEMPEST" },
	["Fly+Ice"] = { "Blizzard Wings", "FROZEN SKY" },
	["Fly+Light"] = { "Heaven's Wings", "DIVINE ASCENSION" },
	["Fly+Poison"] = { "Toxic Swarm", "PLAGUE SKY" },
	["Fly+Shadow"] = { "Phantom Wings", "NIGHT DESCENT" },
	["Ice+Light"] = { "Prism Frost", "DIAMOND DUST" },
	["Light+Shadow"] = { "Eclipse", "TOTAL ECLIPSE" },
	["Light+Thunder"] = { "Holy Thunder", "JUDGMENT BOLT" },
	["Light+Water"] = { "Rainbow Tide", "RAINBOW DELUGE" },
	["Nature+Poison"] = { "Spore Bloom", "TOXIC JUNGLE" },
	["Poison+Water"] = { "Venom Tide", "HYDRA FLOOD" },
	["Shadow+Water"] = { "Abyssal Tide", "DEEP ABYSS" },
	["Shadow+Wind"] = { "Shadow Gale", "NIGHT TEMPEST" },
	["Thunder+Wind"] = { "Storm Rush", "HURRICANE STORM" },
}
local SHAPE_WORD = { Rain = "rain", Vortex = "vortex", Slam = "slam", Beam = "beam" }

local function fusionKey(elems)
	local list = table.clone(elems)
	table.sort(list)
	return table.concat(list, "+")
end

-- registra nome/descrição de uma fusão (habilidade 3) e do Supremo de fusão (habilidade 4)
local function registerFusion(elems, shape)
	local key = fusionKey(elems)
	local names = FUSION_NAMES[key]
	local words = {}
	local effects = {}
	for _, e in ipairs(elems) do
		table.insert(words, DogData.ELEMENTS[e].Name)
		table.insert(effects, DogData.ELEMENTS[e].Effect)
	end
	local id = table.concat(elems, "_")
	local fusName = "Fus_" .. id .. "_" .. shape
	if not DogData.Specials[fusName] then
		DogData.Specials[fusName] = {
			Name = names and names[1] or (table.concat(words, " ") .. " Fusion"),
			Desc = "FUSION: " .. string.lower(words[1]) .. " erupts from the ground, then a " .. table.concat(words, "-", 2) .. " "
				.. SHAPE_WORD[shape] .. ", then everything explodes together. It " .. table.concat(effects, ", ") .. ".",
			Elements = table.clone(elems),
			Fusion = true,
		}
	end
	local supName = "SupFus_" .. id
	if not DogData.Specials[supName] then
		DogData.Specials[supName] = {
			Name = "SUPREME " .. (names and names[2] or string.upper(table.concat(words, " ") .. " FUSION")),
			Desc = "Charges while you fight. The sky falls with " .. string.lower(table.concat(words, ", ")) .. " and a giant fusion explosion.",
			Elements = table.clone(elems),
			Fusion = true,
		}
	end
	return fusName, supName
end

local powers = nil -- [speciesId] = { poder2, poder3, supremo }
local function buildPowers()
	powers = {}
	local shapeUses = {} -- variar a forma grande entre cachorros do mesmo elemento/combinação
	local list = {}
	for id in pairs(DogData.Species) do
		table.insert(list, id)
	end
	table.sort(list)
	for _, id in ipairs(list) do
		local sp = DogData.Species[id]
		local elems = DogData.ElementsOf(id)
		-- 2 = o golpe PRÓPRIO do cachorro (decisão do dono: cada um guarda o seu)
		local p2 = sp.Special
		if not DogData.Specials[p2] then
			p2 = "El_" .. elems[1] .. "_Bolt"
		end
		-- 3 = ULTIMATE do elemento (1 elemento) ou FUSÃO dos elementos (2 ou 3); forma grande variada
		local key = fusionKey(elems)
		local n = shapeUses[key] or 0
		shapeUses[key] = n + 1
		local h = 0
		for i = 1, #id do
			h = (h * 31 + string.byte(id, i)) % 9973
		end
		local shape = DogData.BIG_SHAPES[(h + n) % #DogData.BIG_SHAPES + 1]
		local p3, supreme
		if #elems == 1 then
			p3 = "Ult_" .. elems[1] .. "_" .. shape
			supreme = "Supreme_" .. elems[1]
		else
			p3, supreme = registerFusion(elems, shape)
		end
		if sp.Power3 then
			p3 = sp.Power3
		end
		-- 4 = SUPREMO (2026-10: a partir do ÉPICO, igual ao Config.HasSupreme)
		local hasSupreme = DogData.SUPREME_RARITY[sp.Rarity] == true
		-- (2026-10) HABILIDADES NOVAS: cada cachorro com as suas (shared/Skills.lua); os poderes antigos
		-- acima ficam só de reserva (cachorro novo sem catálogo) e para os bosses
		local catalog = Skills and Skills.For(id)
		if catalog then
			powers[id] = { catalog[1] or p2, catalog[2] or p3, hasSupreme and (catalog[3] or supreme) or nil }
		else
			powers[id] = { p2, p3, hasSupreme and supreme or nil }
		end
	end
end

-- { poder da habilidade 2, poder da habilidade 3, supremo (habilidade 4) }
function DogData.PowersFor(speciesId)
	if not powers then
		buildPowers()
	end
	return powers[speciesId] or { "Pounce", "Charge" }
end

-- todos os nomes de fusão em uso (o servidor registra uma função para cada)
function DogData.FusionPowers()
	if not powers then
		buildPowers()
	end
	local out = {}
	for name, info in pairs(DogData.Specials) do
		if info.Fusion then
			table.insert(out, name)
		end
	end
	table.sort(out)
	return out
end

function DogData.ThirdPower(speciesId)
	return DogData.PowersFor(speciesId)[2]
end

---------------------------------------------------------------- 🎯 ataque 1 À DISTÂNCIA
-- Pedido do dono: alguns cachorros MORDEM (de perto, mais dano) e outros ATIRAM PELA BOCA (de longe,
-- Config.SHOT_DAMAGE do dano). O tiro sai da boca, voa até o alvo e explode no estilo dele.
-- Estilo = como o cliente desenha (client/Effects.lua, H.MouthShot):
--   Shape: Ball (bola), Shard (lasca/estrela), Bone (osso), Wave (onda de som), Beam (laser reto), Bolt (raio)
--   Trail: Fire / Smoke / Sparkle / Swirl · Count: tiros por ataque (rajada) · Arc: sobe em arco
--   Speed: studs/s (Beam e Bolt são instantâneos) · Impact: Burst / Shatter / Splash / Explode / Pop
DogData.SHOT_STYLES = {
	Fire = { Name = "Fireball", Icon = "🔥", Shape = "Ball", Color = C(255, 130, 30), Color2 = C(255, 235, 150), Trail = "Fire", Size = 1.1, Speed = 110, Impact = "Explode" },
	Lava = { Name = "Lava Spit", Icon = "🌋", Shape = "Ball", Color = C(255, 80, 20), Color2 = C(70, 25, 15), Trail = "Fire", Size = 1.3, Speed = 90, Arc = 3, Impact = "Splash" },
	Ice = { Name = "Ice Shard", Icon = "❄️", Shape = "Shard", Color = C(150, 220, 255), Color2 = C(255, 255, 255), Trail = "Sparkle", Size = 1.0, Speed = 130, Impact = "Shatter" },
	Thunder = { Name = "Thunder Bark", Icon = "⚡", Shape = "Bolt", Color = C(255, 235, 90), Color2 = C(255, 255, 255), Size = 1.0, Impact = "Burst" },
	Laser = { Name = "Laser", Icon = "🔴", Shape = "Beam", Color = C(255, 60, 60), Color2 = C(255, 255, 255), Size = 0.8, Impact = "Burst" },
	Poison = { Name = "Venom Spit", Icon = "🧪", Shape = "Ball", Color = C(130, 230, 60), Color2 = C(60, 120, 30), Trail = "Smoke", Size = 1.0, Speed = 90, Arc = 2, Impact = "Splash" },
	Ink = { Name = "Ink Shot", Icon = "🦑", Shape = "Ball", Color = C(70, 40, 110), Color2 = C(20, 10, 40), Trail = "Smoke", Size = 1.1, Speed = 95, Impact = "Splash" },
	Water = { Name = "Water Blast", Icon = "💧", Shape = "Ball", Color = C(90, 180, 255), Color2 = C(230, 245, 255), Trail = "Sparkle", Size = 1.1, Speed = 105, Bubble = true, Impact = "Splash" },
	Sound = { Name = "Bark Wave", Icon = "📢", Shape = "Wave", Color = C(255, 255, 255), Color2 = C(255, 150, 220), Size = 1.0, Speed = 120, Impact = "Burst" },
	Bone = { Name = "Bone Shot", Icon = "🦴", Shape = "Bone", Color = C(245, 240, 225), Color2 = C(200, 190, 170), Size = 1.0, Speed = 100, Impact = "Shatter" },
	Needle = { Name = "Needle Spit", Icon = "🌵", Shape = "Shard", Color = C(120, 200, 80), Color2 = C(255, 255, 200), Size = 0.6, Speed = 140, Count = 3, Impact = "Burst" },
	Bee = { Name = "Bee Spit", Icon = "🐝", Shape = "Ball", Color = C(255, 210, 40), Color2 = C(40, 30, 20), Trail = "Sparkle", Size = 0.6, Speed = 80, Count = 3, Arc = 2, Impact = "Burst" },
	Spore = { Name = "Spore Puff", Icon = "🍄", Shape = "Ball", Color = C(220, 120, 200), Color2 = C(255, 230, 250), Trail = "Smoke", Size = 0.9, Speed = 75, Arc = 3, Impact = "Splash" },
	Star = { Name = "Star Shot", Icon = "⭐", Shape = "Shard", Color = C(255, 230, 120), Color2 = C(180, 140, 255), Trail = "Sparkle", Size = 1.0, Speed = 130, Impact = "Burst" },
	Arcane = { Name = "Arcane Orb", Icon = "🔮", Shape = "Ball", Color = C(190, 110, 255), Color2 = C(120, 220, 255), Trail = "Swirl", Size = 1.0, Speed = 100, Impact = "Burst" },
	Shell = { Name = "Rocket Shot", Icon = "🚀", Shape = "Ball", Color = C(90, 95, 100), Color2 = C(255, 160, 60), Trail = "Fire", Size = 1.0, Speed = 120, Impact = "Explode" },
	Plasma = { Name = "Plasma Shot", Icon = "👽", Shape = "Ball", Color = C(110, 255, 150), Color2 = C(230, 255, 240), Trail = "Sparkle", Size = 0.9, Speed = 135, Impact = "Burst" },
	Photon = { Name = "Photon Cannon", Icon = "🤖", Shape = "Ball", Color = C(110, 200, 255), Color2 = C(255, 255, 255), Trail = "Sparkle", Size = 1.2, Speed = 140, Impact = "Explode" },
	Void = { Name = "Void Orb", Icon = "🌑", Shape = "Ball", Color = C(60, 20, 100), Color2 = C(170, 90, 255), Trail = "Swirl", Size = 1.1, Speed = 95, Impact = "Burst" },
	Ghost = { Name = "Ghost Fire", Icon = "💀", Shape = "Ball", Color = C(90, 255, 200), Color2 = C(20, 70, 60), Trail = "Fire", Size = 1.1, Speed = 100, Impact = "Explode" },
	Holy = { Name = "Holy Beam", Icon = "✨", Shape = "Beam", Color = C(255, 225, 120), Color2 = C(255, 255, 255), Size = 1.0, Impact = "Burst" },
	Rainbow = { Name = "Rainbow Beam", Icon = "🌈", Shape = "Beam", Color = C(255, 120, 200), Color2 = C(255, 255, 255), Size = 1.0, Rainbow = true, Impact = "Burst" },
	Balloon = { Name = "Balloon Pop", Icon = "🎈", Shape = "Ball", Color = C(255, 110, 170), Color2 = C(255, 255, 255), Size = 1.4, Speed = 60, Arc = 2, Impact = "Pop" },
	Sunfire = { Name = "Sunfire Shot", Icon = "☀️", Shape = "Ball", Color = C(255, 160, 50), Color2 = C(255, 240, 170), Trail = "Fire", Size = 1.3, Speed = 130, Impact = "Explode" },
	Meteor = { Name = "Meteor Spit", Icon = "☄️", Shape = "Ball", Color = C(150, 95, 60), Color2 = C(255, 150, 50), Trail = "Fire", Size = 1.3, Speed = 100, Arc = 4, Impact = "Explode" },
}

-- quem atira (o resto morde). Comuns/Incomuns: poucos; quanto mais raro, mais "mágico" o tiro.
DogData.RANGED = {
	-- comuns / incomuns
	salsicha = "Bone",
	chihuahua = "Sound",
	snow_husky = "Ice",
	dalmatian = "Water", -- cachorro de bombeiro
	-- raros
	robo_dog = "Laser",
	skull_dog = "Bone",
	cactus_dog = "Needle",
	bee_dog = "Bee",
	balloon_dog = "Balloon",
	mushroom_dog = "Spore",
	-- épicos
	toxic_hound = "Poison",
	frost_beast = "Ice",
	magma_hound = "Lava",
	alien_dog = "Plasma",
	dj_dog = "Sound",
	-- lendários
	dragon_hound = "Fire",
	inferno_hound = "Fire",
	celestial_dog = "Holy",
	astronaut_dog = "Shell",
	octopus_dog = "Ink",
	tank_dog = "Shell",
	wizard_dog = "Arcane",
	-- míticos
	cosmic_dog = "Star",
	phoenix_hound = "Fire",
	bone_dragon = "Ghost",
	kraken_hound = "Water",
	singularity_pup = "Void",
	seraph_hound = "Holy",
	frost_phoenix = "Ice",
	rainbow_unicorn = "Rainbow",
	mecha_hound = "Photon",
	planet_hound = "Meteor",
	-- divino
	sun_dragon = "Sunfire",
}

-- nome do estilo e o estilo do tiro, ou nil se o cachorro morde
function DogData.ShotFor(speciesId)
	local name = speciesId and DogData.RANGED[speciesId]
	if name and DogData.SHOT_STYLES[name] then
		return name, DogData.SHOT_STYLES[name]
	end
	return nil, nil
end

-- 📜 habilidades novas (shared/Skills.lua): nome, descrição, ícone e cor de cada uma entram em DogData.Specials
-- (as telas e o efeito "SpecialName" leem daqui)
if Skills then
	for speciesId, list in pairs(Skills.BySpecies) do
		local element = DogData.ElementsOf(speciesId)[1]
		for slot, skill in ipairs(list) do
			if not skill.Keep then
				DogData.Specials[skill.Id] = {
					Name = skill.Name,
					Desc = skill.Desc,
					Icon3D = skill.Icon,
					Color = skill.Color,
					Element = element,
					Skill = slot,
					Supreme = slot == 3 or nil,
				}
			end
		end
	end
end

-- 🐕 TAMANHO NO JOGO (2026-10, pedido do dono: "manter a maioria um tamanho pequeno que pareça cachorro").
-- Antes todo cachorro lutava 1,4x maior que o DogBuilder e os míticos gigantes chegavam a 4 bonecos de altura.
-- Agora cada espécie tem o seu fator (Fighters.Spawn e os cachorros da vila): o topo da cabeça fica entre ~2 e
-- ~4,5 studs (o boneco do Roblox tem ~5); só os colossos míticos passam disso (até ~7,5). Os bosses continuam
-- enormes (não usam esta tabela). Espécie sem fator = 1 (o Look.scale já é o tamanho no jogo).
-- Refazer a tabela: python tools/preview/sizes.py (mede as cabeças e imprime os fatores).
DogData.GAME_SIZE = {
	-- common
	beagle = 1, bulldog = 1, caramelo = 0.94, chihuahua = 1, corgi = 1, pinscher = 1, poodle = 0.9, pug = 1,
	salsicha = 1,
	-- uncommon
	akita = 0.82, armored_doberman = 0.78, border_collie = 0.88, boxer = 0.85, dalmatian = 0.84, galgo = 0.75,
	golden = 0.81, pastor_alemao = 0.79, sao_bernardo = 0.77, snow_husky = 0.85,
	-- rare
	balloon_dog = 0.84, bee_dog = 1, cactus_dog = 0.93, crystal_hound = 0.89, horned_pup = 0.9, mushroom_dog = 1,
	robo_dog = 0.88, skull_dog = 0.89, stone_hound = 0.86, storm_pup = 1.02, windup_dog = 0.97,
	-- epic
	alien_dog = 0.87, armadillo_dog = 1.05, brute_bulldog = 0.77, dj_dog = 0.97, flytrap_dog = 0.93, frost_beast = 0.76,
	ghost_hound = 0.93, knight_dog = 0.8, magma_hound = 0.86, mummy_dog = 0.88, ninja_dog = 0.97, pirate_dog = 0.89,
	saber_dog = 0.8, samurai_shiba = 0.95, scorpion_dog = 1.05, shark_dog = 0.92, toxic_hound = 0.89,
	-- legendary
	astronaut_dog = 0.87, celestial_dog = 0.86, dragon_hound = 0.76, inferno_hound = 0.78, octopus_dog = 0.8,
	shadow_doberman = 0.76, storm_wolf = 0.76, tank_dog = 0.9, twin_fang = 0.76, velocity_hound = 1.08,
	werewolf_dog = 0.72, wizard_dog = 0.88, yeti_dog = 0.71,
	-- mythic
	bone_dragon = 0.68, chrono_hound = 0.8, cosmic_dog = 0.8, crystal_golem = 0.59, demon_samurai = 0.72,
	frost_phoenix = 0.78, hydra_hound = 0.58, kraken_hound = 0.71, mecha_hound = 0.57, phoenix_hound = 0.79,
	planet_hound = 0.81, rainbow_unicorn = 0.71, seraph_hound = 0.78, shadow_cerberus = 0.66, singularity_pup = 1.12,
	thunder_colossus = 0.53, titan_mastiff = 0.56, void_beast = 0.66, volcanic_cerberus = 0.51,
	-- divine
	sun_dragon = 0.8,
}
function DogData.GameScale(speciesId)
	return DogData.GAME_SIZE[speciesId] or 1
end

-- monta as habilidades já ao carregar: os nomes das FUSÕES precisam existir em todo cliente (efeito "SpecialName")
DogData.PowersFor("caramelo")

return DogData
