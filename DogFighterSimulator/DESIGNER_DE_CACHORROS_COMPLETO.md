# 🐶 DESIGNER DE CACHORROS — memória e regras
Função: cria e cuida dos cachorros (e de outros bichos) dos jogos: raças, idades, cores, raridades, poses, animações,
comportamento (seguir, olhar para o dono, necessidades) e também quando o jogador VIRA o cachorro.
Faz parte da equipe (lista no `roblox-dev.md`, seção A EQUIPE). Leia este arquivo antes de cada tarefa e escreva em "Aprendizados" depois de cada uma.
Trabalha junto com: Designer 3D (peças), Animador (poses), Designer de Jogo (raridades e economia) e DEV (programa).

## Dois estilos de cachorro (perguntar ao dono qual usar no jogo novo)
1. **Adote um Cachorro — blocos fofos** (estilo Adopt Me): seções "Visual", "Comportamento" e "Técnica" abaixo.
2. **Dog Fighter — low-poly cartoon**: elipsoides lisas (SpecialMesh Sphere) + cunhas e triângulos (2 WedgeParts) para orelhas,
   asas, nadadeiras e espinhos; ~100 peças por cachorro. Seção "Estilo Dog Fighter" abaixo; o CÓDIGO COMPLETO fica no
   arquivo `DESIGNER_DE_CACHORROS_COMPLETO.md` (fim do arquivo).

## Visual (aprovado pelo dono)
- Cachorros FOFOS de blocos, estilo Adopt Me: cabeça grande e corpo pequeno (filhote bem cabeçudo), olhos grandes com brilho,
  nariz, língua, coleira com plaquinha. Nada de desenho 2D.
- Cantos "chanfrados": cada caixa vira 3 blocos cruzados e parece arredondada.
- Feito por código: `DogBuilder.makeDog(raça, idade, gênero, aura, cf, humor, opções)`.
  Pivôs para animar: corpo, cabeça, rabo e as 4 patas (FL, FR, BL, BR).
- **Raças** em `Breeds.lua` (o Adote um Cachorro tem 40). Cada raça é uma "receita" de cores:
  main, white, ear, ears ("up"/"floppy"), fluffy, spots, mask, saddle, patch (mancha no olho), size, mat (material), glow, aura.
  Raça nova = receita nova + nome em `Config.BREEDS` (o save só aceita raças da lista).
- **Idades** (tamanho e cabeça): Puppy 0.22 / cabeça 1.75 (cores mais clarinhas) · Young 0.30 / 1.4 · Adult 0.36 / 1.3 ·
  Senior 0.34 / 1.3 com o pelo 50% cinza.
- **Menino/menina**: cor da coleira/laço diferente.
- **Raridades** (peso de sorteio): Common 600, Uncommon 250, Rare 100, Epic 40, Legendary 9, Mythic 1.
  Cores: cinza, verde, azul, roxo, dourado, rosa. O nível do jogador libera raridades; limite global para o mais raro na rua.
  Raros ganham brilho e aura (Lightning amarela, Mystic roxa, Fire laranja).
- **Humor e estado visíveis**: partes de feliz/triste (orelhas, rabo, olhos) e sujeira de 0 a 1 (manchas no pelo).

## Comportamento
- O pet OLHA para o dono: a cabeça vira para o jogador perto (com limite e suave) e o corpo gira devagar quando está parado.
- Necessidades viram atributos (`Need_food`...) e o CLIENTE desenha os balões em cima do pet. Tarefa feita = moedas + XP (servidor);
  nível libera truque; filhote cresce de idade.
- Estados que esperam o jogador (lavar, comer, bolinha) têm tempo máximo e cancelam se o dono for longe (senão o cachorro fica parado para sempre).
- Modelos ancorados movidos por CFrame atravessam parede → para entrar/sair de uma sala, passe pela porta (pontos no caminho).
- Minijogos com o cachorro (esponja, tigela, bolinha) são 3D de verdade, com poses do cachorro. O cliente joga e manda só o resultado;
  o servidor confere (dono, estado, tempo mínimo) e é ele quem move o cachorro.
  Esponja: raycast só no modelo do cachorro (`Include`) e manchas grudadas nas peças com CFrame relativo.
- Cena de tutorial: cachorro de demonstração LOCAL (só no cliente).

## Técnica (para não travar)
- O servidor move só 1 peça invisível por cachorro (`Root`, CanQuery = false, `BulkMoveTo`) e manda o resto por atributos
  (Moving, Action, Mood, Dirt, State, OwnerId, Slot). O cliente monta e anima o modelo (DogProxy + DogRenderer).
  Servidor movendo dezenas de peças 60x/s = cachorros travados, com tranco e atrasados.
- Longe de todos os jogadores: parar a animação e mover só 4x por segundo; desconectar o Heartbeat quando o modelo some.
- Animações: só as padrão do Roblox (as de outros donos não carregam) ou poses feitas com `Motor6D.Transform` no `RunService.Stepped`.
- Sinal da rotação: `CFrame.Angles(+x, 0, 0)` LEVANTA o nariz. Abaixar a cabeça (comer, farejar) = x negativo; rabo para baixo = x positivo.
- Raycast do chão no servidor: `Include` só com o mapa + Terrain (com `Exclude` ele batia em gente, bike e cachorro).

## Estilo Dog Fighter (código: DogBuilder.lua + DogData.lua + DogPacks/PackA, PackB, PackC)
- `DogBuilder.Build(speciesId, options)` monta o cachorro pelo `Look` do DogData. Peças soltas (sem âncora, Massless, sem colisão)
  presas por Motor6D: Body (raiz → Torso), Neck1..3 e Jaw1..3 (até 3 cabeças), LegFL/FR/BL/BR, Tail, WingL/WingR; orelhas por
  Welds "Orelha"/"OrelhaDentro". O cliente anima pelo `Motor6D.Transform`; o servidor só move o HumanoidRootPart.
  Medidas em "unidades" do cachorro × escala; o cachorro olha para -Z.
- **Regra de design: quanto mais raro, mais muda a ANATOMIA** (silhueta, cabeças, asas, tamanho), não só a cor.
  Comuns/Incomuns = raças reais e fofas · Raros = exóticos (cacto, abelha, balão, brinquedo de corda, cogumelo) ·
  Épicos/Lendários = membros e postura diferentes (perna de pau, planta carnívora, esteira de tanque, tentáculos, meio em pé) ·
  Míticos = absurdos, reconhecíveis só pela silhueta (hidra de 5 cabeças, serafim de 6 asas, cachorro planeta com anéis).
- **Look**: scale · main/second/belly/eye · mood (happy, calm, fierce, evil) · eyes (cute, white, glow, skull, alien, bead, none) ·
  body {len, w, h, chest, haunch, saddle} · legs {len, thick, socks, paw, claws, feather...} · head {size, snout, flat, lift, ...} ·
  ears (pointy, big, cropped, swept, semi, floppy, long, rose, pom, plate, none) · tail (19 tipos: curl, sickle, fluffy, dragon,
  shark, flame, bolt, tentacles...) · heads 1–3 · extras {...}. Sem mood/eyes: comum = feliz/fofo, raro = calmo, épico+ = feroz.
- **Pacotes**: cada ModuleScript em `Shared/DogPacks` devolve `{ Species, Order, Specials }` — dá para adicionar cachorros sem mexer
  no DogData. Geometria própria em `Look.build(b, ctx)` com b:E (elipsoide), b:K (bloco), b:W (cunha), b:Seg, b:Chain, b:Tri,
  b:Triangle, b:Joint. Peças que giram/balançam: atributos CSpin / CWave / CFreq / CPhase + "CAnim" no modelo (o cliente anima).
- Atributos do modelo: Species, HipHeight, BaseScale, Heads, Float, Wings, GroundHip. Auras grandes de raridade ficam no cliente (DogFX).
- O jogo tem **78 cachorros**: 38 do jogo base + Pack A (14 comuns/incomuns/raros) + Pack B (13 épicos/lendários) + Pack C (13 míticos).

## Quando o jogador É o cachorro (Dog Fighter)
- O modelo do cachorro (Humanoid + HumanoidRootPart) vira o `player.Character`; `CharacterAutoLoads = false`
  (o avatar só aparece antes de escolher o primeiro cachorro).
- Scripts de "personagem novo" ignoram quando o novo personagem é o cachorro; um guard no cliente põe a câmera sempre no cachorro atual.
- Correr com Shift (desligar o Shift Lock): velocidade do cachorro × 1,6; no celular, botão RUN.
  Cachorro com asas fica no chão; espaço 2x (pular 2x no celular) liga/desliga o voo.
- Poder especial que move o cachorro: o servidor pega a física por 1–2 s, o cliente trava os controles e devolve no fim.
- Habilidades: 1 = Mordida, 2 = Poder especial, 3 = poder do tipo. O servidor escolhe alvo, dano e recarga.
  Morder um NPC começa a luta e ele revida sozinho (IA reaproveitada).
- Cachorros mortos/corpos se apagam sozinhos (apagar 2 vezes não pode dar erro). Entre serviços use Signal, nunca BindableEvent
  (ele copia tabelas: os cachorros mortos não sumiam).
- Economia: ovos (Paw $100 → Celestial $300k), time de cachorros que rende $/min, vender só os repetidos guardando o melhor de
  cada espécie, rebirth mantém os cachorros.

## Aprendizados
- [Equipe, 2026-10] Criado a pedido do dono juntando tudo o que aprendemos sobre cachorros no Adote um Cachorro e no Dog Fighter.
- [Equipe, 2026-10] O dono gosta de ver os bichos numa FOTO-CATÁLOGO (grade com o bicho em 3D num chão verde redondo + nome + raridade colorida). Como fazer: rodar o DogBuilder no mock (scratchpad/r3d/dogs/dog_run.py) → three.js → página HTML → print. A aura/brilho dos raros não aparece na foto.
- [DogFighter, 2026-10] Juntei o código dos cachorros do Dog Fighter com este arquivo. Foto-catálogo dos 78 no mock: separar o arquivo juntado em módulos pelos marcadores `ARQUIVO:`, Config falso só com RARITY {Order, Color}, e desenhar peça com SpecialMesh Sphere como elipsoide (tamanho × Scale) — script em scratchpad/r3d/df/df_run.py.
- [DogFighter, 2026-10] O dono quis TODOS os cachorros do Dog Fighter no estilo blocos do Adote. Solução sem refazer 78 modelos: `DogBuilder.STYLE = "Blocky"` — cada elipsoide vira caixa (0.9 do tamanho) e, no FIM do Build, ganha cantos chanfrados (2 blocos soldados que copiam cor/transparência); ovos continuam redondos ("Round"). Mantém toda a anatomia (asas, cabeças, pacotes). ~196 peças por cachorro.
- [DogFighter, 2026-10] "Quero mais detalhados" → PELO PIXELADO: no fim do Build, quadradinhos de tons vizinhos (×0.84–1.16 da cor) nas faces dos blocos grandes, numa grade sem sobrepor (sem piscar), sem a face de baixo, máx. 90 por cachorro; + brilho no nariz. Mostre também uma foto DE PERTO (na grade pequena o detalhe some). ~285 peças por cachorro.
- [DogFighter, 2026-10] Para animação realista o rig ganhou JOELHOS (KneeFL/FR/BL/BR: punho na frente, jarrete atrás) e COTOVELO nas asas (WingL2/WingR2). Feito no FIM do Build: tudo soldado abaixo do joelho / além do cotovelo é re-soldado na parte nova, então enfeites de pacotes também acompanham. Robôs ficam sem joelho.
- [DogFighter, 2026-10] Olhos no estilo blocos: os olhos eram posicionados na superfície da cabeça REDONDA e ficavam tortos/enterrados na cabeça quadrada → flatEyes: cada camada (olho, íris, pupila, brilho) fica reta na frente da cara (ou da máscara), 15% maior, camadas a 0.022 de distância (sem piscar).

---

# 📦 CÓDIGO DOS CACHORROS DO DOG FIGHTER — VERSÃO BLOCOS DETALHADOS (DogBuilder.lua, DogData.lua, DogPacks/PackA, PackB, PackC)
Copie cada parte para o arquivo indicado em `ARQUIVO:` (pasta `src/shared`). O `Config.lua` do jogo precisa ter `RARITY[nome] = { Order, Color }`.
`DogBuilder.STYLE = "Blocky"` (blocos detalhados, estilo Adote) ou `"Round"` (elipsoides lisas). Tem joelhos e cotovelo das asas para o Animator novo.

```lua
-- DESIGNER DOS CACHORROS (Dog Fighter Simulator) — todos os arquivos que desenham os cachorros juntos.
-- VERSÃO BLOCOS: DogBuilder.STYLE = "Blocky" monta todos no estilo do Adote um Cachorro (blocos de cantos chanfrados).
-- Para voltar às elipsoides lisas: DogBuilder.STYLE = "Round".
-- Partes: DogBuilder.lua, DogData.lua, DogPacks/PackA.lua, PackB.lua, PackC.lua

--[[ ================================================================
     ARQUIVO: src/shared/DogBuilder.lua
================================================================ ]]
-- Constrói o modelo 3D de cada cachorro a partir do "Look" do DogData.
-- Estilo low-poly cartoon: elipsoides (SpecialMesh Sphere), cunhas e triângulos (2 WedgeParts) para
-- orelhas, asas, nadadeiras e espinhos. Articulações Motor6D para a animação procedural:
--   Body (raiz -> Torso), Neck1..3 (Torso -> Head1..3), Jaw1..3, LegFL/FR/BL/BR, Tail (Torso -> TailBase), WingL/WingR
-- O cliente anima pelos Motor6D.Transform (Animator.lua) e mexe as orelhas pelos Welds "Orelha"/"OrelhaDentro";
-- o servidor só move o HumanoidRootPart. Convenção: o cachorro olha para -Z.
-- Toda medida abaixo está em "unidades" do cachorro (antes da escala); o Builder aplica a escala.
local DogData = require(script.Parent.DogData)
local Config = require(script.Parent.Config)

local DogBuilder = {}

local C = Color3.fromRGB
local DARK = C(24, 20, 22)
local WHITE = C(250, 250, 250)
local BONE = C(240, 232, 210)
local PINK = C(236, 150, 160)
local TONGUE = C(232, 96, 112)
local GOLD = C(245, 195, 70)
local STEEL = C(170, 176, 188)
local NOSE = C(30, 24, 26)

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local PI = math.pi

local function V(x, y, z)
	return Vector3.new(x, y, z)
end

local function CF(x, y, z)
	if type(x) ~= "number" then
		return CFrame.new(x)
	end
	return CFrame.new(x, y, z)
end

local function ANG(x, y, z)
	return CFrame.Angles(x, y, z)
end

local function shade(c, k)
	return Color3.new(math.clamp(c.R * k, 0, 1), math.clamp(c.G * k, 0, 1), math.clamp(c.B * k, 0, 1))
end

---------------------------------------------------------------- primitivas
local function basePart(className)
	local p = Instance.new(className)
	p.Anchored = false
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = true
	return p
end

local Builder = {}
Builder.__index = Builder

-- 🧱 ESTILO dos cachorros: "Blocky" = blocos de cantos chanfrados (igual ao Adote um Cachorro); "Round" = elipsoides lisas
DogBuilder.STYLE = "Blocky"
local BLOCK_K = 0.9 -- no estilo blocos a caixa é um pouco menor que a elipsoide (a caixa parece maior)

function Builder.new(model, scale, material, style)
	return setmetatable({ Model = model, S = scale, Material = material, Style = style or DogBuilder.STYLE }, Builder)
end

-- elipsoide (esfera esticada); no estilo blocos vira uma caixa que ganha cantos chanfrados no fim do Build
function Builder:Ellipsoid(name, size, color, material)
	local p = basePart("Part")
	p.Name = name
	p.Color = color
	p.Material = material or self.Material
	if self.Style == "Blocky" then
		p.Size = size * self.S * BLOCK_K
		p:SetAttribute("Bloco", true)
		return p
	end
	p.Size = size * self.S
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- peça decorativa soldada em `p` (segue a animação)
local function addOn(p, name, size, color, material, lcf)
	local c = basePart("Part")
	c.Name = name
	c.Size = size
	c.Color = color
	c.Material = material
	c.CastShadow = false
	c.CFrame = p.CFrame * lcf
	local weld = Instance.new("Weld")
	weld.Part0 = p
	weld.Part1 = c
	weld.C0 = lcf
	weld.Parent = c
	c.Parent = p.Parent
	return c
end

-- PELO PIXELADO: quadradinhos de tons vizinhos nas faces dos blocos grandes (textura sem imagem, estilo voxel).
-- Cada face é uma grade; as casas sorteadas nunca se sobrepõem (sem piscar). A face virada para baixo fica sem.
local FUR_MAX = 90 -- máximo de quadradinhos por cachorro (peso)
local NO_FUR = { Olho = true, Iris = true, Pupila = true, Brilho = true, Lingua = true, Nariz = true, Dente = true }
local FACES = {
	{ n = Vector3.new(0, 1, 0), u = Vector3.new(1, 0, 0), v = Vector3.new(0, 0, 1) },
	{ n = Vector3.new(0, -1, 0), u = Vector3.new(1, 0, 0), v = Vector3.new(0, 0, 1) },
	{ n = Vector3.new(1, 0, 0), u = Vector3.new(0, 1, 0), v = Vector3.new(0, 0, 1) },
	{ n = Vector3.new(-1, 0, 0), u = Vector3.new(0, 1, 0), v = Vector3.new(0, 0, 1) },
	{ n = Vector3.new(0, 0, 1), u = Vector3.new(1, 0, 0), v = Vector3.new(0, 1, 0) },
	{ n = Vector3.new(0, 0, -1), u = Vector3.new(1, 0, 0), v = Vector3.new(0, 1, 0) },
}
local TONES = { 0.84, 0.91, 1.09, 1.16 }
local function furTiles(p, s, r, rng, budget)
	local used = 0
	for _, f in ipairs(FACES) do
		if used >= budget then break end
		if p.CFrame:VectorToWorldSpace(f.n).Y > -0.5 then
			local w = math.abs(f.u:Dot(s)) - 2 * r
			local h = math.abs(f.v:Dot(s)) - 2 * r
			local depth = math.abs(f.n:Dot(s)) / 2
			local g = math.clamp(math.min(w, h) / 3, 0.14, 0.5)
			local nu, nv = math.floor(w / g), math.floor(h / g)
			if nu * nv >= 2 then
				local cells = {}
				for i = 0, nu - 1 do
					for j = 0, nv - 1 do
						table.insert(cells, { i, j })
					end
				end
				local k = math.min(5, math.floor(nu * nv * 0.4 + 0.5), budget - used)
				for _ = 1, k do
					local cell = table.remove(cells, rng:NextInteger(1, #cells))
					local cu = -w / 2 + (cell[1] + 0.5) * g + (w - nu * g) / 2
					local cv = -h / 2 + (cell[2] + 0.5) * g + (h - nv * g) / 2
					local pos = f.n * (depth + 0.02) + f.u * cu + f.v * cv
					local size = f.u * (g * 0.92) + f.v * (g * 0.92) + f.n * 0.04
					local abs = Vector3.new(math.abs(size.X), math.abs(size.Y), math.abs(size.Z))
					addOn(p, "Pelo", abs, shade(p.Color, TONES[rng:NextInteger(1, #TONES)]), p.Material, CFrame.new(pos))
					used += 1
				end
			end
		end
	end
	return used
end

-- OLHOS NO ESTILO BLOCOS: os olhos eram colocados na superfície da cabeça REDONDA (inclinados pela curva);
-- na cabeça quadrada ficavam tortos, enterrados ou flutuando. Aqui cada camada do olho fica reta, de frente,
-- encostada na face da frente da cabeça (ou da máscara/mancha que estiver na frente), um pouco maior,
-- em camadas que não se tocam (sem piscar): Olho → Íris/Pálpebra → Pupila → Brilho.
local EYE_LAYER = { Olho = 0, Iris = 1, Palpebra = 1, Pupila = 2, Brilho = 3 }
local FACE_COVER = { Mascara = true, Mancha = true, PlacaTesta = true, Ponte = true }
local function flatEyes(model)
	local heads = {}
	for _, w in ipairs(model:GetDescendants()) do
		if w:IsA("Weld") and w.Part0 and w.Part1 and string.match(w.Part0.Name, "^Head%d$") then
			local list = heads[w.Part0] or {}
			heads[w.Part0] = list
			table.insert(list, w)
		end
	end
	for head, welds in pairs(heads) do
		-- frente da cara em cada ponto (x, y): a cabeça ou uma máscara/mancha na frente dela
		local covers = { { cf = CFrame.new(), size = head.Size } }
		for _, w in ipairs(welds) do
			if FACE_COVER[w.Part1.Name] then
				table.insert(covers, { cf = head.CFrame:ToObjectSpace(w.Part1.CFrame), size = w.Part1.Size })
			end
		end
		local function frontAt(x, y)
			local z = 0
			for _, c in ipairs(covers) do
				local q = c.cf.Position
				if math.abs(x - q.X) < c.size.X / 2 and math.abs(y - q.Y) < c.size.Y / 2 then
					z = math.min(z, q.Z - c.size.Z / 2)
				end
			end
			return z
		end
		for _, w in ipairs(welds) do
			local part = w.Part1
			local layer = EYE_LAYER[part.Name]
			if layer then
				local rel = head.CFrame:ToObjectSpace(part.CFrame)
				local pos = rel.Position
				if pos.Z < 0 and math.abs(pos.X) < head.Size.X * 0.5 then
					local xv = rel:VectorToWorldSpace(Vector3.new(1, 0, 0))
					local roll = math.atan2(xv.Y, math.abs(xv.X) > 1e-4 and xv.X or 1e-4)
					if math.abs(roll) > math.pi / 2 then
						roll -= math.sign(roll) * math.pi
					end
					local grow = part.Name == "Palpebra" and 1.05 or 1.15
					local depth = 0.04
					part.Size = Vector3.new(part.Size.X * grow, part.Size.Y * grow, depth)
					local z = frontAt(pos.X, pos.Y) - depth / 2 - 0.004 - layer * 0.022
					local newRel = CFrame.new(pos.X, pos.Y, z) * CFrame.Angles(0, 0, roll)
					part.CFrame = head.CFrame * newRel
					w.C0 = newRel
					w.C1 = CFrame.new()
				end
			end
		end
	end
end

-- cantos chanfrados (como o Adote um Cachorro): cada bloco grande vira 3 blocos cruzados no mesmo lugar.
-- Roda no FIM do Build (posições já prontas); os 2 blocos extras ficam soldados no principal e copiam cor/transparência.
local function chamfer(model, seed)
	local rng = Random.new(seed or 1)
	local blocks = {}
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p:GetAttribute("Bloco") and p.Transparency < 0.99 and not EYE_LAYER[p.Name] then
			table.insert(blocks, p)
		end
	end
	-- os maiores primeiro (ganham o pelo pixelado antes de acabar o limite)
	table.sort(blocks, function(a, b)
		return a.Size.X * a.Size.Y * a.Size.Z > b.Size.X * b.Size.Y * b.Size.Z
	end)
	local fur = FUR_MAX
	for _, p in ipairs(blocks) do
		do
			local s = p.Size
			local r = math.min(s.X, s.Y, s.Z) * 0.18
			local m = p.Material
			if fur > 0 and math.min(s.X, s.Y, s.Z) >= 0.45 and p.Transparency < 0.3 and not NO_FUR[p.Name]
				and m ~= Enum.Material.Neon and m ~= Enum.Material.Glass then
				fur -= furTiles(p, s, r, rng, math.min(fur, 14))
			end
			if p.Name == "Nariz" and s.X >= 0.12 then -- brilho no nariz
				addOn(p, "BrilhoNariz", Vector3.new(s.X * 0.3, 0.03, s.Z * 0.25), WHITE, Enum.Material.SmoothPlastic,
					CFrame.new(-s.X * 0.15, s.Y / 2 + 0.015, -s.Z * 0.1))
			end
			if r >= 0.03 then
				p.Size = Vector3.new(s.X, s.Y - 2 * r, s.Z - 2 * r)
				for _, sz in ipairs({ Vector3.new(s.X - 2 * r, s.Y, s.Z - 2 * r), Vector3.new(s.X - 2 * r, s.Y - 2 * r, s.Z) }) do
					local c = basePart("Part")
					c.Name = "Chanfro"
					c.Size = sz
					c.Color = p.Color
					c.Material = p.Material
					c.Transparency = p.Transparency
					c.Reflectance = p.Reflectance
					c.CastShadow = p.CastShadow
					c.CFrame = p.CFrame
					local weld = Instance.new("Weld")
					weld.Part0 = p
					weld.Part1 = c
					weld.Parent = c
					c.Parent = p.Parent
					p:GetPropertyChangedSignal("Transparency"):Connect(function()
						c.Transparency = p.Transparency
					end)
					p:GetPropertyChangedSignal("Color"):Connect(function()
						c.Color = p.Color
					end)
				end
			end
		end
	end
end

function Builder:Block(name, size, color, material)
	local p = basePart("Part")
	p.Name = name
	p.Size = size * self.S
	p.Color = color
	p.Material = material or self.Material
	return p
end

function Builder:Wedge(name, size, color, material)
	local p = basePart("WedgePart")
	p.Name = name
	p.Size = size * self.S
	p.Color = color
	p.Material = material or self.Material
	return p
end

-- Solda decorativa: offset em coordenadas do segmento (unidades antes da escala)
function Builder:Attach(segment, part, offset)
	local s = self.S
	local cf = offset or CFrame.new()
	cf = CFrame.new(cf.Position * s) * cf.Rotation
	part.CFrame = segment.CFrame * cf
	local weld = Instance.new("Weld")
	weld.Part0 = segment
	weld.Part1 = part
	weld.C0 = cf
	weld.Parent = part
	part.Parent = self.Model
	return part
end

-- Articulação animável. c0 = posição da junta no pai, c1 = posição da junta no filho (unidades)
function Builder:Joint(name, parent, child, c0, c1)
	local s = self.S
	local function scaled(cf)
		return CFrame.new(cf.Position * s) * cf.Rotation
	end
	local motor = Instance.new("Motor6D")
	motor.Name = name
	motor.Part0 = parent
	motor.Part1 = child
	motor.C0 = scaled(c0)
	motor.C1 = scaled(c1 or CFrame.new())
	child.CFrame = parent.CFrame * motor.C0 * motor.C1:Inverse()
	motor.Parent = parent
	child.Parent = self.Model
	return motor
end

-- Segmento invisível (pivô para cauda/asas)
function Builder:Pivot(name)
	local p = basePart("Part")
	p.Name = name
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.Transparency = 1
	return p
end

function Builder:E(parent, name, size, color, cf, material)
	return self:Attach(parent, self:Ellipsoid(name, size, color, material), cf)
end

function Builder:K(parent, name, size, color, cf, material)
	return self:Attach(parent, self:Block(name, size, color, material), cf)
end

function Builder:W(parent, name, size, color, cf, material)
	return self:Attach(parent, self:Wedge(name, size, color, material), cf)
end

-- CFrame em `a` olhando para `b` (sem degenerar quando a direção é vertical)
local function aim(a, b, upVec)
	local d = b - a
	if d.Magnitude < 1e-4 then
		return CFrame.new(a)
	end
	local up = upVec or Vector3.new(0, 1, 0)
	if math.abs(d.Unit:Dot(up.Unit)) > 0.97 then
		up = Vector3.new(0, 0, -1)
	end
	return CFrame.lookAt(a, b, up)
end

-- elipsoide esticado entre dois pontos; rx/ry = meia largura/meia altura
function Builder:Seg(parent, name, a, b, rx, ry, color, material, up)
	ry = ry or rx
	local len = (b - a).Magnitude
	local mid = (a + b) / 2
	return self:E(parent, name, V(rx * 2, ry * 2, len + math.min(rx, ry) * 1.3), color, aim(mid, b, up), material)
end

-- sequência de segmentos afinando (cauda, chifre, tentáculo)
function Builder:Chain(parent, name, pts, radii, color, material, tipColor)
	local parts = {}
	for i = 1, #pts - 1 do
		local c = (i == #pts - 1 and tipColor) or color
		table.insert(parts, self:Seg(parent, name .. i, pts[i], pts[i + 1], radii[i], radii[i], c, material))
	end
	return parts
end

-- triângulo isósceles no plano XY local de `cf` (base no centro, ponta em +Y)
function Builder:Tri(parent, name, cf, width, height, thick, color, material, nameB)
	local w2 = width / 2
	local a = self:W(parent, name, V(thick, height, w2), color, cf * CF(w2 / 2, height / 2, 0) * ANG(0, -PI / 2, 0), material)
	self:W(parent, nameB or name, V(thick, height, w2), color, cf * CF(-w2 / 2, height / 2, 0) * ANG(0, PI / 2, 0), material)
	return a
end

-- triângulo qualquer entre 3 pontos (2 cunhas): membranas de asa, nadadeiras, espinhos
function Builder:Triangle(parent, name, a, b, c, thick, color, material)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab).Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	local w1 = self:W(parent, name, V(thick, height, math.abs(ab:Dot(back))), color, CFrame.fromMatrix((a + b) / 2, right, up, back), material)
	self:W(parent, name, V(thick, height, math.abs(ac:Dot(back))), color, CFrame.fromMatrix((a + c) / 2, -right, up, -back), material)
	return w1
end

local function glow(part, color)
	part.Material = Enum.Material.Neon
	part.Color = color or part.Color
	part.CastShadow = false
	return part
end

local function emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	e.LightEmission = 0.6
	e.Texture = SPARKLE
	for k, v in pairs(props) do
		e[k] = v
	end
	e.Parent = parent
	return e
end

---------------------------------------------------------------- orelhas
-- Welds "Orelha" (peça principal, 1 por lado) e "OrelhaDentro" giram juntos em volta da base (Animator)
local function buildEars(b, head, look, hs, ax, ay, lite)
	local kind = look.ears or "floppy"
	if kind == "none" then
		return
	end
	local k = look.earSize or 1
	local ec = look.earColor or look.second
	local inner = look.earInner or PINK
	local tip = look.earTip
	for _, side in ipairs({ -1, 1 }) do
		if kind == "pointy" or kind == "big" or kind == "cropped" or kind == "swept" then
			local w, h, out, back = 0.4, 0.52, 0.3, 0.12
			if kind == "big" then
				w, h, out = 0.52, 0.72, 0.42
			elseif kind == "cropped" then
				w, h, out = 0.26, 0.66, 0.16
			elseif kind == "swept" then
				w, h, out, back = 0.32, 0.62, 0.35, 1.05
			end
			w, h = w * k * hs, h * k * hs
			local base = CF(side * ax * 0.55, ay * 0.62, 0.06 * hs) * ANG(back, 0, -side * out)
			b:Tri(head, "Orelha", base, w, h, 0.09 * hs, ec, nil, "OrelhaDentro")
			if tip then
				b:Tri(head, "OrelhaDentro", base * CF(0, h * 0.62, 0), w * 0.4, h * 0.38, 0.1 * hs, tip)
			end
			if not lite then
				b:Tri(head, "OrelhaDentro", base * CF(0, h * 0.06, -0.04 * hs), w * 0.6, h * 0.66, 0.05 * hs, inner, Enum.Material.SmoothPlastic)
			end
		elseif kind == "floppy" or kind == "long" then
			local len = (kind == "long" and 0.95 or 0.66) * k * hs
			local top = CF(side * ax * 0.78, ay * 0.42, 0.04 * hs) * ANG(0.12, 0, side * 0.22)
			local ear = b:E(head, "Orelha", V(0.17 * hs * k, len, 0.42 * hs * k), ec, top * CF(side * 0.04 * hs, -len * 0.42, 0))
			ear.Name = "Orelha"
			b:E(head, "OrelhaDentro", V(0.2 * hs * k, 0.2 * hs * k, 0.36 * hs * k), ec, top * CF(0, 0.02 * hs, 0))
			if tip then
				b:E(head, "OrelhaDentro", V(0.18 * hs * k, len * 0.45, 0.38 * hs * k), tip, top * CF(side * 0.045 * hs, -len * 0.7, 0))
			end
		elseif kind == "semi" then
			-- orelha de vira-lata: base em pé, ponta dobrada para a frente
			local w, h = 0.42 * k * hs, 0.32 * k * hs
			local base = CF(side * ax * 0.58, ay * 0.62, 0.04 * hs) * ANG(0.1, 0, -side * 0.5)
			b:Tri(head, "Orelha", base, w, h, 0.1 * hs, ec, nil, "OrelhaDentro")
			b:Tri(head, "OrelhaDentro", base * CF(0, h * 0.04, -0.04 * hs), w * 0.6, h * 0.8, 0.05 * hs, inner, Enum.Material.SmoothPlastic)
			b:Tri(head, "OrelhaDentro", base * CF(0, h * 0.92, 0) * ANG(-2.1, 0, 0), w * 0.66, h * 0.7, 0.1 * hs, tip or ec)
		elseif kind == "rose" then
			-- bulldog: orelhinha dobrada para trás, bem no alto e afastada
			local base = CF(side * ax * 0.72, ay * 0.62, 0.08 * hs) * ANG(-0.2, side * 0.5, -side * 1.15)
			b:E(head, "Orelha", V(0.16 * k, 0.3 * k, 0.34 * k) * hs, ec, base * CF(0, 0.12 * k * hs, 0))
			b:E(head, "OrelhaDentro", V(0.08 * k, 0.2 * k, 0.24 * k) * hs, inner, base * CF(side * -0.04 * hs, 0.1 * k * hs, -0.02 * hs))
		elseif kind == "pom" then
			local top = CF(side * ax * 0.8, ay * 0.3, 0.02 * hs)
			b:E(head, "Orelha", V(0.36, 0.55, 0.44) * hs * k, ec, top * CF(side * 0.05 * hs, -0.22 * hs, 0))
			b:E(head, "OrelhaDentro", V(0.32, 0.36, 0.4) * hs * k, ec, top * CF(side * 0.08 * hs, -0.52 * hs * k, 0.02 * hs))
		elseif kind == "plate" then
			-- robô: placas metálicas
			local base = CF(side * ax * 0.6, ay * 0.85, 0.08 * hs) * ANG(0.1, 0, -side * 0.2)
			b:Tri(head, "Orelha", base, 0.38 * k * hs, 0.5 * k * hs, 0.1 * hs, ec, Enum.Material.Metal, "OrelhaDentro")
			local light = b:Tri(head, "OrelhaDentro", base * CF(0, 0.05 * hs, -0.06 * hs), 0.18 * hs, 0.26 * hs, 0.04 * hs, look.eye)
			glow(light)
		end
	end
	if kind == "pom" then
		b:E(head, "Topete", V(0.62, 0.5, 0.62) * hs, look.second, CF(0, ay * 0.88, 0.04 * hs))
		b:E(head, "Topete", V(0.42, 0.38, 0.42) * hs, look.second, CF(0, ay * 1.18, 0.1 * hs))
	end
end

---------------------------------------------------------------- olhos
local function buildEyes(b, head, look, hs, surf, index)
	local H = look.head
	local style = look.eyes
	local mood = look.mood
	local e = (H.eyeSize or 1) * hs
	local gap = (H.eyeGap or 0.21) * hs
	local ey = (H.eyeY or 0.08) * hs
	local eyeColor = look.eye
	local lidColor = H.lid or H.cap or look.main
	local browColor = H.brows or shade(H.cap or look.main, 0.7)

	for _, side in ipairs({ -1, 1 }) do
		local base = surf(side * gap, ey, -0.03 * e)
		if style == "cute" then
			b:E(head, "Olho", V(0.2, 0.25, 0.1) * e, eyeColor, base, Enum.Material.SmoothPlastic)
			b:E(head, "Brilho", V(0.08, 0.08, 0.04) * e, WHITE, base * CF(-0.035 * e, 0.055 * e, -0.045 * e), Enum.Material.Neon)
			b:E(head, "Brilho", V(0.035, 0.035, 0.03) * e, WHITE, base * CF(0.04 * e, -0.06 * e, -0.04 * e), Enum.Material.Neon)
		elseif style == "white" then
			b:E(head, "Olho", V(0.24, 0.24, 0.1) * e, WHITE, base, Enum.Material.SmoothPlastic)
			b:E(head, "Iris", V(0.16, 0.18, 0.06) * e, eyeColor, base * CF(side * -0.01 * e, -0.005 * e, -0.035 * e), Enum.Material.SmoothPlastic)
			b:E(head, "Pupila", V(0.08, 0.1, 0.05) * e, DARK, base * CF(side * -0.01 * e, -0.005 * e, -0.05 * e), Enum.Material.SmoothPlastic)
			b:E(head, "Brilho", V(0.05, 0.05, 0.03) * e, WHITE, base * CF(-0.03 * e, 0.04 * e, -0.065 * e), Enum.Material.Neon)
		elseif style == "glow" then
			b:E(head, "Olho", V(0.25, 0.22, 0.1) * e, DARK, base, Enum.Material.SmoothPlastic)
			glow(b:E(head, "Iris", V(0.19, 0.16, 0.06) * e, eyeColor, base * CF(0, 0, -0.035 * e)))
			b:E(head, "Pupila", V(0.04, 0.12, 0.05) * e, DARK, base * CF(0, 0, -0.05 * e), Enum.Material.SmoothPlastic)
			b:E(head, "Brilho", V(0.045, 0.045, 0.03) * e, WHITE, base * CF(-0.04 * e, 0.035 * e, -0.06 * e), Enum.Material.Neon)
		elseif style == "skull" then
			b:E(head, "Olho", V(0.3, 0.32, 0.12) * e, DARK, base * ANG(0, 0, side * 0.3), Enum.Material.SmoothPlastic)
			glow(b:E(head, "Iris", V(0.11, 0.11, 0.06) * e, eyeColor, base * CF(0, -0.02 * e, -0.04 * e)))
		elseif style == "alien" then
			local cf = base * ANG(0, 0, side * 0.45)
			b:E(head, "Olho", V(0.38, 0.24, 0.12) * e, DARK, cf, Enum.Material.SmoothPlastic)
			b:E(head, "Brilho", V(0.1, 0.06, 0.04) * e, WHITE, cf * CF(-0.06 * e, 0.04 * e, -0.05 * e), Enum.Material.Neon)
			glow(b:E(head, "Iris", V(0.06, 0.06, 0.03) * e, eyeColor, cf * CF(0.08 * e, -0.03 * e, -0.05 * e)))
		elseif style == "bead" then
			b:E(head, "Olho", V(0.13, 0.13, 0.08) * e, DARK, base, Enum.Material.SmoothPlastic)
			b:E(head, "Brilho", V(0.04, 0.04, 0.03) * e, WHITE, base * CF(-0.02 * e, 0.025 * e, -0.035 * e), Enum.Material.Neon)
		end

		-- sobrancelha / pálpebra: é o que dá a expressão
		if style ~= "skull" and style ~= "alien" and style ~= "none" and not H.noBrows and (look.heads or 1) < 2 then
			local inner, outer, lift = 0.03, -0.01, 0.17
			if mood == "calm" then
				inner, outer = 0.0, 0.0
			elseif mood == "fierce" then
				inner, outer, lift = -0.045, 0.03, 0.15
			elseif mood == "evil" then
				inner, outer, lift = -0.07, 0.05, 0.14
			end
			local p1 = surf(side * (gap - 0.07 * e), ey + (lift + inner) * e, 0.0).Position
			local p2 = surf(side * (gap + 0.08 * e), ey + (lift + outer) * e, 0.0).Position
			b:Seg(head, "Sobrancelha", p1, p2, 0.035 * e, 0.035 * e, browColor)
		end
		if (mood == "fierce" or mood == "evil") and style ~= "skull" and style ~= "alien" and style ~= "bead" then
			local tilt = mood == "evil" and 0.45 or 0.3
			b:E(head, "Palpebra", V(0.3, 0.13, 0.1) * e, lidColor, base * CF(0, 0.1 * e, -0.03 * e) * ANG(0, 0, side * tilt))
		end
	end
	if look.extras.eyes3 and index == 1 then
		local cf = surf(0, ey + 0.27 * hs, -0.02 * hs)
		b:E(head, "Olho", V(0.15, 0.2, 0.08) * hs, DARK, cf, Enum.Material.SmoothPlastic)
		glow(b:E(head, "Iris", V(0.1, 0.14, 0.05) * hs, eyeColor, cf * CF(0, 0, -0.025 * hs)))
	end
	if look.extras.eyeGlow then
		local light = Instance.new("PointLight")
		light.Color = eyeColor
		light.Range = 6 * b.S
		light.Brightness = 1
		light.Parent = head
	end
end

---------------------------------------------------------------- chifres e enfeites de cabeça
local function buildHeadgear(b, head, look, hs, ax, ay, az, surf, index)
	local ex = look.extras
	local H = look.head
	if ex.horns then
		for _, side in ipairs({ -1, 1 }) do
			local s = side
			if ex.horns == "ram" then
				-- chifre de carneiro: espiral para trás e para baixo
				local pts, radii = {}, {}
				for i = 0, 6 do
					local a = i / 6 * PI * 1.35
					local r = (0.34 - i * 0.025) * hs
					table.insert(pts, V(s * (ax * 0.55 + i * 0.03 * hs), ay * 0.55 + math.sin(a) * r, 0.05 * hs + (1 - math.cos(a)) * r * 0.9))
					table.insert(radii, (0.12 - i * 0.012) * hs)
				end
				b:Chain(head, "Chifre", pts, radii, look.hornColor or BONE)
			elseif ex.horns == "demon" then
				local pts = {
					V(s * ax * 0.5, ay * 0.6, 0),
					V(s * ax * 0.95, ay * 1.05, 0.05 * hs),
					V(s * ax * 1.1, ay * 1.6, 0.1 * hs),
					V(s * ax * 0.9, ay * 2.05, 0.2 * hs),
				}
				b:Chain(head, "Chifre", pts, { 0.13 * hs, 0.1 * hs, 0.06 * hs }, look.hornColor or DARK, nil, look.second)
			elseif ex.horns == "dragon" then
				local pts = {
					V(s * ax * 0.45, ay * 0.7, -0.05 * hs),
					V(s * ax * 0.6, ay * 1.1, 0.3 * hs),
					V(s * ax * 0.7, ay * 1.3, 0.8 * hs),
					V(s * ax * 0.65, ay * 1.35, 1.15 * hs),
				}
				b:Chain(head, "Chifre", pts, { 0.12 * hs, 0.09 * hs, 0.05 * hs }, look.hornColor or BONE)
				b:Seg(
					head,
					"ChifreMenor",
					V(s * ax * 0.85, ay * 0.3, 0.1 * hs),
					V(s * ax * 1.15, ay * 0.55, 0.55 * hs),
					0.06 * hs,
					0.06 * hs,
					look.hornColor or BONE
				)
			elseif ex.horns == "small" then
				b:Seg(head, "Chifre", V(s * ax * 0.4, ay * 0.7, 0), V(s * ax * 0.5, ay * 1.2, 0.12 * hs), 0.08 * hs, 0.08 * hs, look.hornColor or BONE)
			elseif ex.horns == "void" then
				local pts = {
					V(s * ax * 0.45, ay * 0.75, 0.05 * hs),
					V(s * ax * 0.6, ay * 1.3, 0.35 * hs),
					V(s * ax * 0.5, ay * 1.6, 0.85 * hs),
					V(s * ax * 0.25, ay * 1.55, 1.25 * hs),
				}
				b:Chain(head, "Chifre", pts, { 0.11 * hs, 0.08 * hs, 0.05 * hs }, DARK, nil, look.second)
				glow(b:E(head, "ChifreAnel", V(0.2, 0.06, 0.2) * hs, look.second, CF(s * ax * 0.52, ay * 1.0, 0.18 * hs)))
			end
		end
	end
	if ex.helmet then
		-- kabuto (elmo samurai) com abas e crista dourada
		b:E(head, "Elmo", V(ax * 2.15, ay * 1.3, az * 2.1), ex.helmet, CF(0, ay * 0.55, 0.04 * hs), Enum.Material.SmoothPlastic)
		for _, side in ipairs({ -1, 1 }) do
			b:W(
				head,
				"ElmoAba",
				V(0.08, 0.32, 0.5) * hs,
				ex.helmet,
				CF(side * ax * 1.02, ay * 0.25, 0.12 * hs) * ANG(0, 0, side * 0.5),
				Enum.Material.SmoothPlastic
			)
			b:Tri(
				head,
				"Kuwagata",
				CF(side * 0.08 * hs, ay * 1.05, -az * 0.62) * ANG(-0.2, 0, -side * 0.55),
				0.14 * hs,
				0.6 * hs,
				0.05 * hs,
				GOLD,
				Enum.Material.Foil
			)
		end
		b:E(head, "ElmoFaixa", V(ax * 2.2, 0.1 * hs, az * 2.15), GOLD, CF(0, ay * 0.32, 0.04 * hs), Enum.Material.Foil)
	end
	if ex.headband then
		b:E(head, "Faixa", V(ax * 2.08, 0.15 * hs, az * 2.06), ex.headband, CF(0, ay * 0.5, 0.02 * hs), Enum.Material.Fabric)
		b:Seg(head, "FaixaPonta", V(0.05 * hs, ay * 0.5, az * 0.95), V(0.35 * hs, ay * 0.1, az * 2.3), 0.07 * hs, 0.025 * hs, ex.headband, Enum.Material.Fabric)
		b:Seg(
			head,
			"FaixaPonta",
			V(-0.05 * hs, ay * 0.5, az * 0.95),
			V(-0.25 * hs, ay * 0.35, az * 2.1),
			0.07 * hs,
			0.025 * hs,
			ex.headband,
			Enum.Material.Fabric
		)
		if ex.headbandMark then
			b:E(head, "FaixaPlaca", V(0.26, 0.12, 0.05) * hs, STEEL, surf(0, ay * 0.5, 0.01 * hs), Enum.Material.Metal)
		end
	end
	if ex.goggles then
		local g = ex.goggles
		for _, side in ipairs({ -1, 1 }) do
			local cf = surf(side * (H.eyeGap or 0.21) * hs, (H.eyeY or 0.08) * hs + 0.12 * hs, 0.02 * hs)
			b:E(head, "Oculos", V(0.3, 0.24, 0.1) * hs, DARK, cf, Enum.Material.SmoothPlastic)
			local lens = b:E(head, "Lente", V(0.22, 0.17, 0.06) * hs, g, cf * CF(0, 0, -0.04 * hs), Enum.Material.Glass)
			lens.Transparency = 0.2
		end
		b:E(head, "OculosTira", V(ax * 2.06, 0.08 * hs, az * 2.04), DARK, CF(0, (H.eyeY or 0.08) * hs + 0.12 * hs, 0.02 * hs) * ANG(-0.15, 0, 0))
	end
	if ex.hood then
		-- máscara ninja cobrindo focinho
		b:E(head, "Mascara", V(ax * 2.04, ay * 1.05, az * 2.02), ex.hood, CF(0, -ay * 0.38, 0.0), Enum.Material.Fabric)
	end
	if ex.antenna then
		for _, side in ipairs({ -1, 1 }) do
			local a = V(side * 0.18 * hs, ay * 0.85, 0.05 * hs)
			local t = V(side * 0.42 * hs, ay * 2.0, 0.2 * hs)
			if ex.robot then
				b:Seg(head, "Antena", a, t, 0.03 * hs, 0.03 * hs, C(60, 62, 72), Enum.Material.Metal)
			else
				b:Chain(head, "Antena", { a, V(side * 0.36 * hs, ay * 1.5, -0.05 * hs), t }, { 0.035 * hs, 0.03 * hs }, look.second)
			end
			glow(b:E(head, "AntenaLuz", V(0.16, 0.16, 0.16) * hs, ex.antenna, CF(t.X, t.Y, t.Z)))
		end
	end
	if ex.crest then
		for i = -2, 2 do
			local c = (i % 2 == 0) and look.second or look.belly
			local feather = b:Seg(
				head,
				"Crista",
				V(i * 0.06 * hs, ay * 0.8, 0.1 * hs),
				V(i * 0.2 * hs, ay * (2.3 - math.abs(i) * 0.3), (0.65 + math.abs(i) * 0.12) * hs),
				0.08 * hs,
				0.035 * hs,
				c
			)
			glow(feather)
		end
	end
	if ex.halo and index == 1 then
		for k = 0, 11 do
			local a = k / 12 * PI * 2
			glow(b:E(head, "Aureola", V(0.13, 0.08, 0.13) * hs, ex.halo, CF(math.cos(a) * 0.42 * hs, ay * 2.05, math.sin(a) * 0.42 * hs + 0.12 * hs)))
		end
	end
	if ex.tuft then
		-- topete espetado (filhote elétrico, storm wolf)
		for i = -1, 1 do
			b:Tri(head, "Topete", CF(i * 0.12 * hs, ay * 0.8, 0.05 * hs) * ANG(-0.45, 0, -i * 0.5), 0.2 * hs, 0.38 * hs, 0.08 * hs, ex.tuft)
		end
	end
	if H.plate then
		-- placa de armadura na testa (titã)
		b:E(head, "PlacaTesta", V(ax * 1.5, ay * 0.9, 0.3 * hs), H.plate, surf(0, ay * 0.55, -0.06 * hs) * ANG(-0.25, 0, 0), Enum.Material.Metal)
		glow(b:E(head, "PlacaJoia", V(0.16, 0.16, 0.08) * hs, look.eye, surf(0, ay * 0.6, 0.06 * hs) * ANG(0, 0, PI / 4)))
	end
	if ex.gem then
		local g = b:E(head, "Joia", V(0.16, 0.22, 0.08) * hs, ex.gem, surf(0, ay * 0.62, 0.0) * ANG(0, 0, PI / 4))
		glow(g)
	end
	if ex.icicles then
		for i = -2, 2 do
			local x = i * 0.1 * hs
			b:Seg(
				head,
				"Pingente",
				V(x, -ay * 0.75, -az * 0.95),
				V(x * 1.2, -ay * 1.3 - (2 - math.abs(i)) * 0.06 * hs, -az * 1.0),
				0.05 * hs,
				0.05 * hs,
				ex.icicles,
				Enum.Material.Ice
			)
		end
	end
	if ex.flameMane and index then
		for i = -1, 1 do
			local f = b:Seg(head, "Chama", V(i * 0.15 * hs, ay * 0.5, 0.2 * hs), V(i * 0.3 * hs, ay * 1.9, 0.85 * hs), 0.13 * hs, 0.13 * hs, look.second)
			glow(f)
		end
	end
	if ex.wraps then
		-- faixas de múmia na cabeça
		b:E(head, "Bandagem", V(ax * 2.06, 0.14 * hs, az * 2.05), ex.wraps, CF(0, ay * 0.45, 0) * ANG(0, 0, 0.12), Enum.Material.Fabric)
		b:E(head, "Bandagem", V(ax * 2.07, 0.12 * hs, az * 2.06), ex.wraps, CF(0, -ay * 0.05, 0) * ANG(0.15, 0, -0.18), Enum.Material.Fabric)
		b:E(head, "Bandagem", V(ax * 2.06, 0.12 * hs, az * 2.0), ex.wraps, CF(0, ay * 0.72, 0.05 * hs) * ANG(-0.2, 0, -0.1), Enum.Material.Fabric)
	end
	if ex.cracksHead then
		for i = -1, 1, 2 do
			local p1 = surf(i * 0.12 * hs, ay * 0.75, 0.0).Position
			local p2 = surf(i * 0.28 * hs, ay * 0.35, 0.0).Position
			glow(b:Seg(head, "Rachadura", p1, p2, 0.025 * hs, 0.025 * hs, ex.cracksHead))
		end
	end
end

---------------------------------------------------------------- cabeça
local function buildHead(b, torso, look, index, count, neckPos)
	local H = look.head
	local ex = look.extras
	local hs = H.size
	local mood = look.mood
	local yaw = 0
	if count == 2 then
		yaw = index == 1 and 0.35 or -0.35
	elseif count == 3 then
		yaw = ({ 0.5, 0, -0.5 })[index]
	end
	local hw, ht, hd = 0.95 * (H.w or 1), 0.9 * (H.tall or 1), 1.0 * (H.long or 1)
	local robot = ex.robot ~= nil
	if robot then
		hw, ht, hd = hw * 0.82, ht * 0.78, hd * 0.85
	end
	local ax, ay, az = hw * hs / 2, ht * hs / 2, hd * hs / 2
	local capC = H.cap or look.main

	local head
	if robot then
		head = b:Block("Head" .. index, V(hw, ht, hd) * hs, capC)
	else
		head = b:Ellipsoid("Head" .. index, V(hw, ht, hd) * hs, capC)
	end
	b:Joint("Neck" .. index, torso, head, CFrame.new(neckPos) * ANG(0, yaw, 0), CF(0, -0.12 * hs, 0.3 * hs))

	-- ponto na frente da cabeça (normal para fora; -Z do CFrame aponta para fora)
	local function surf(x, y, push)
		local z, n
		if robot then
			z = -az
			n = V(0, 0, -1)
		else
			local u = 1 - (x / ax) ^ 2 - (y / ay) ^ 2
			z = -az * math.sqrt(math.max(u, 0.03))
			n = V(x / (ax * ax), y / (ay * ay), z / (az * az)).Unit
		end
		local p = V(x, y, z) + n * (push or 0)
		return CFrame.lookAt(p, p + n)
	end

	-- rosto: bochechas claras/máscara/listra
	if H.face then
		b:E(head, "Mascara", V(hw * 0.94, ht * 0.62, hd * 0.8) * hs, H.face, CF(0, -0.13 * hs, -0.12 * hs))
	end
	if H.blaze then
		b:E(head, "Listra", V(0.16, 0.5, 0.06) * hs, H.blaze, surf(0, 0.12 * hs, -0.015 * hs))
	end
	if H.cheeks then
		for _, side in ipairs({ -1, 1 }) do
			b:Tri(head, "Bochecha", CF(side * ax * 0.78, -0.12 * hs, 0.05 * hs) * ANG(0, 0, -side * (PI / 2 + 0.35)), 0.34 * hs, 0.3 * hs, 0.12 * hs, H.cheeks)
		end
	end
	if H.wrinkles then
		local wc = shade(capC, 0.78)
		for i = 0, 1 do
			local y = (0.26 + i * 0.08) * hs
			b:Seg(head, "Ruga", surf(-0.13 * hs, y, 0).Position, surf(0.13 * hs, y + 0.02 * hs, 0).Position, 0.022 * hs, 0.022 * hs, wc)
		end
	end
	if H.spotEye then
		-- mancha em volta de um olho (dálmata / vira-lata)
		b:E(head, "Mancha", V(0.3, 0.28, 0.1) * hs, H.spotEye, surf(0.22 * hs, 0.12 * hs, -0.035 * hs))
	end

	-- focinho
	local sn = H.snout or 0.8
	local mLen = (0.3 + sn * 0.55) * hs
	local mw = 0.5 * (H.snoutW or 1) * hs
	local mh = (H.flat and 0.46 or 0.38) * hs
	local my = -0.14 * hs
	local mzBack = -az * 0.55
	local mz = mzBack - mLen * 0.5 + 0.1 * hs
	local tip = mz - mLen / 2
	local muzzleC = H.muzzle or look.belly
	if robot then
		b:K(head, "Focinho", V(mw * 0.9, mh * 0.85, mLen * 0.9), look.second, CF(0, my, mz + 0.05 * hs), Enum.Material.Metal)
		local visor = b:K(head, "Visor", V(hw * 0.86, 0.18, 0.06) * hs, look.eye, CF(0, 0.1 * hs, -az - 0.01 * hs))
		glow(visor)
		b:E(head, "Nariz", V(0.22, 0.14, 0.12) * hs, DARK, CF(0, my + mh * 0.5, tip - 0.01 * hs), Enum.Material.SmoothPlastic)
	elseif H.shark then
		-- focinho de tubarão: cone liso, boca larga embaixo
		b:Seg(head, "Focinho", V(0, 0.02 * hs, -az * 0.4), V(0, -0.02 * hs, tip - 0.06 * hs), mw * 0.52, mh * 0.62, capC)
		b:Seg(head, "Focinho", V(0, -0.16 * hs, -az * 0.4), V(0, -0.14 * hs, tip + 0.06 * hs), mw * 0.48, mh * 0.4, look.belly)
	else
		b:E(head, "Focinho", V(mw, mh, mLen), muzzleC, CF(0, my, mz))
		if not H.flat and not H.noBridge then
			-- ponte do focinho na cor da cabeça (focinho bicolor, bem "cachorro")
			b:E(head, "Ponte", V(mw * 0.78, mh * 0.62, mLen * 0.92), H.bridge or capC, CF(0, my + mh * 0.3, mz + mLen * 0.06))
		end
		-- "almofadinhas" do focinho (formam o W da boca)
		local jowl = H.jowls
		for _, side in ipairs({ -1, 1 }) do
			local size = jowl and V(mw * 0.6, mh * 1.0, mLen * 0.6) or V(mw * 0.58, mh * 0.75, mLen * 0.55)
			local y = jowl and my - mh * 0.34 or my - mh * 0.2
			b:E(head, "Labio", size, muzzleC, CF(side * mw * 0.25, y, tip + mLen * 0.3))
		end
		local nw = H.noseW or 1
		local nose = b:E(
			head,
			"Nariz",
			V(math.max(mw * 0.5, 0.24 * hs) * nw, 0.16 * hs, 0.17 * hs),
			H.nose or NOSE,
			CF(0, my + mh * (H.flat and 0.42 or 0.3), tip + 0.05 * hs) * ANG(H.flat and -0.5 or -0.15, 0, 0),
			Enum.Material.SmoothPlastic
		)
		if count < 2 then
			b:E(
				head,
				"Brilho",
				V(0.08, 0.04, 0.04) * hs,
				C(110, 105, 110),
				CF(-0.04 * hs, my + mh * (H.flat and 0.42 or 0.3) + 0.065 * hs, tip + 0.02 * hs),
				Enum.Material.SmoothPlastic
			)
		end
		local _ = nose
	end

	-- mandíbula (abre para morder/uivar/cuspir fogo)
	local under = H.underbite
	local jawLen = mLen * (under and 0.98 or 0.82)
	local jawW = mw * (under and 1.0 or 0.74)
	local jaw
	if robot then
		jaw = b:Block("Jaw" .. index, V(mw * 1.4, mh * 0.45, jawLen), look.second)
	else
		jaw = b:Ellipsoid("Jaw" .. index, V(jawW, mh * 0.5, jawLen), H.shark and look.belly or (H.jawColor or muzzleC))
	end
	b:Joint("Jaw" .. index, head, jaw, CF(0, my - mh * 0.32, mzBack + 0.06 * hs), CF(0, 0, jawLen * (under and 0.4 or 0.45)))
	-- boca escura por dentro
	if count < 2 then
		b:E(jaw, "Boca", V(jawW * 0.8, mh * 0.2, jawLen * 0.8), C(120, 40, 50), CF(0, mh * 0.18, -jawLen * 0.02), Enum.Material.SmoothPlastic)
	end
	local tongueOut = H.tongue or (mood == "happy" and not robot and not H.shark and not H.flat)
	if tongueOut then
		b:E(
			jaw,
			"Lingua",
			V(mw * 0.42, 0.06 * hs, jawLen * 0.75),
			TONGUE,
			CF(mw * 0.08, mh * 0.12, -jawLen * 0.42) * ANG(0.45, 0, 0),
			Enum.Material.SmoothPlastic
		)
	else
		b:E(jaw, "Lingua", V(jawW * 0.5, mh * 0.18, jawLen * 0.6), TONGUE, CF(0, mh * 0.18, -jawLen * 0.05), Enum.Material.SmoothPlastic)
	end
	local fierce = mood == "fierce" or mood == "evil"
	local toothC = H.toothColor or WHITE
	if H.shark then
		for i = -3, 3 do
			local x = i * mw * 0.24
			local z = tip + 0.12 * hs + math.abs(i) * 0.08 * hs
			b:W(head, "Dente", V(0.04, 0.14, 0.07) * hs, toothC, CF(x, -0.3 * hs, z) * ANG(PI, PI / 2 + i * 0.25, 0), Enum.Material.SmoothPlastic)
			b:W(
				jaw,
				"Dente",
				V(0.04, 0.12, 0.07) * hs,
				toothC,
				CF(i * jawW * 0.17, mh * 0.3, -jawLen * 0.35 + math.abs(i) * 0.06 * hs) * ANG(0, PI / 2 + i * 0.25, 0),
				Enum.Material.SmoothPlastic
			)
		end
	elseif H.skull then
		for i = -2, 2 do
			b:K(
				head,
				"Dente",
				V(0.07, 0.1, 0.05) * hs,
				BONE,
				CF(i * mw * 0.18, my - mh * 0.42, tip + 0.1 * hs + math.abs(i) * 0.05 * hs),
				Enum.Material.SmoothPlastic
			)
			b:K(
				jaw,
				"Dente",
				V(0.07, 0.09, 0.05) * hs,
				BONE,
				CF(i * jawW * 0.2, mh * 0.28, -jawLen * 0.36 + math.abs(i) * 0.05 * hs),
				Enum.Material.SmoothPlastic
			)
		end
	elseif not robot then
		if fierce or H.fangs then
			for _, side in ipairs({ -1, 1 }) do
				b:W(
					head,
					"Dente",
					V(0.04, 0.17, 0.08) * hs,
					toothC,
					CF(side * mw * 0.3, my - mh * 0.55, tip + mLen * 0.2) * ANG(PI, PI / 2, 0),
					Enum.Material.SmoothPlastic
				)
			end
		end
		if under then
			for _, side in ipairs({ -1, 1 }) do
				b:W(
					jaw,
					"Dente",
					V(0.05, 0.17, 0.08) * hs,
					toothC,
					CF(side * jawW * 0.3, mh * 0.35, -jawLen * 0.38) * ANG(0, PI / 2, 0),
					Enum.Material.SmoothPlastic
				)
			end
		end
	end

	-- olhos, orelhas, enfeites
	buildEyes(b, head, look, hs, surf, index)
	buildEars(b, head, look, hs, ax, ay, count >= 2)
	buildHeadgear(b, head, look, hs, ax, ay, az, surf, index)
	return head
end

---------------------------------------------------------------- cauda
local function buildTail(b, torso, look, B)
	local kind = look.tail or "curl"
	local ex = look.extras
	local pivot = b:Pivot("TailBase")
	b:Joint("Tail", torso, pivot, CF(0, B.h * 0.28, B.len * 0.44), CFrame.new())
	local t = (look.tailSize or 1) * math.clamp(B.h / 1.4, 0.8, 1.4)
	local main, second, belly = look.tailColor or look.main, look.second, look.belly
	local tipC = look.tailTip
	local function P(x, y, z)
		return V(x * t, y * t, z * t)
	end
	local function R(list)
		local out = {}
		for i, r in ipairs(list) do
			out[i] = r * t
		end
		return out
	end
	if kind == "curl" then
		b:Chain(
			pivot,
			"Rabo",
			{ P(0, 0, 0), P(0, 0.34, 0.2), P(0, 0.62, 0.12), P(0, 0.7, -0.16), P(0, 0.56, -0.3) },
			R({ 0.17, 0.17, 0.15, 0.12 }),
			main,
			nil,
			tipC or belly
		)
	elseif kind == "sickle" then
		b:Chain(pivot, "Rabo", { P(0, 0, 0), P(0, 0.42, 0.3), P(0, 0.85, 0.36), P(0, 1.12, 0.18) }, R({ 0.2, 0.27, 0.24 }), main, nil, tipC or belly)
		b:Seg(pivot, "RaboPelo", P(0, 0.35, 0.42), P(0, 0.85, 0.5), 0.18 * t, 0.2 * t, belly)
	elseif kind == "fluffy" then
		b:Chain(pivot, "Rabo", { P(0, 0, 0), P(0, 0.12, 0.45), P(0, 0.35, 0.9), P(0, 0.7, 1.22) }, R({ 0.17, 0.22, 0.2 }), main, nil, tipC)
		b:Seg(pivot, "RaboPelo", P(0, -0.06, 0.4), P(0, 0.08, 0.95), 0.15 * t, 0.2 * t, look.tailFeather or belly)
		b:Seg(pivot, "RaboPelo", P(0, 0.2, 0.95), P(0, 0.48, 1.3), 0.13 * t, 0.17 * t, look.tailFeather or belly)
	elseif kind == "thin" then
		b:Chain(pivot, "Rabo", { P(0, 0, 0), P(0, 0.3, 0.32), P(0, 0.7, 0.5), P(0, 1.02, 0.48) }, R({ 0.1, 0.085, 0.07 }), main, nil, tipC)
	elseif kind == "plume" then
		b:Chain(pivot, "Rabo", { P(0, 0, 0), P(0, 0.35, 0.25), P(0, 0.7, 0.35) }, R({ 0.09, 0.08 }), main)
		b:E(pivot, "RaboPompom", V(0.55, 0.55, 0.55) * t, look.second, CF(0, 0.85 * t, 0.4 * t))
	elseif kind == "stub" then
		b:E(pivot, "Rabo", V(0.3, 0.3, 0.34) * t, main, CF(0, 0.06 * t, 0.06 * t))
	elseif kind == "whip" then
		b:Chain(pivot, "Rabo", { P(0, 0, 0), P(0, 0.22, 0.5), P(0, 0.55, 0.98), P(0, 1.0, 1.22), P(0, 1.36, 1.12) }, R({ 0.13, 0.11, 0.09, 0.07 }), main)
		b:Tri(pivot, "Ferrao", CF(0, 1.36 * t, 1.12 * t) * ANG(-0.3, PI / 2, 0), 0.32 * t, 0.42 * t, 0.07 * t, second)
	elseif kind == "dragon" then
		local pts = { P(0, 0, 0), P(0, -0.25, 0.7), P(0, -0.38, 1.4), P(0, -0.28, 2.1), P(0, 0.02, 2.7) }
		b:Chain(pivot, "Rabo", pts, R({ 0.32, 0.26, 0.2, 0.14 }), main)
		for i = 1, 4 do
			local p = pts[i]:Lerp(pts[i + 1], 0.5)
			local r = ({ 0.32, 0.26, 0.2, 0.14 })[i] * t
			b:W(pivot, "RaboEspinho", V(0.08, 0.32, 0.36) * t * (1.1 - i * 0.12), look.spikeColor or second, CF(p.X, p.Y + r * 0.95, p.Z) * ANG(-0.15, 0, 0))
		end
		b:Triangle(pivot, "RaboLamina", P(0, 0.02, 2.6), P(0, 0.42, 3.05), P(0, -0.32, 3.12), 0.07 * t, look.spikeColor or second)
		b:Triangle(pivot, "RaboLamina", P(0, 0.42, 3.05), P(0, -0.32, 3.12), P(0, 0.08, 3.5), 0.07 * t, look.spikeColor or second)
	elseif kind == "shark" then
		b:Chain(pivot, "Rabo", { P(0, 0, 0), P(0, 0.06, 0.6), P(0, 0.12, 1.12) }, R({ 0.32, 0.2 }), main)
		b:Triangle(pivot, "Nadadeira", P(0, 0.05, 1.0), P(0, 0.2, 1.3), P(0, 1.05, 1.75), 0.08 * t, second)
		b:Triangle(pivot, "Nadadeira", P(0, 0.05, 1.0), P(0, 0.2, 1.3), P(0, -0.5, 1.55), 0.08 * t, second)
	elseif kind == "flame" then
		local fireC = ex.fire or second
		local outer = b:Seg(pivot, "Rabo", P(0, 0, 0), P(0, 0.9, 0.62), 0.27 * t, 0.27 * t, fireC)
		glow(outer)
		glow(b:Seg(pivot, "RaboChama", P(0, 0.12, 0.08), P(0, 0.72, 0.5), 0.16 * t, 0.16 * t, look.flameCore or belly))
		glow(b:Seg(pivot, "RaboChama", P(0, 0.8, 0.6), P(0, 1.42, 0.82), 0.13 * t, 0.13 * t, fireC))
		local fire = Instance.new("Fire")
		fire.Color = fireC
		fire.SecondaryColor = C(255, 220, 80)
		fire.Size = 3 * b.S
		fire.Heat = 6
		fire.Parent = outer
	elseif kind == "fan" then
		for i = -2, 2 do
			local c = (i % 2 == 0) and second or belly
			local feather = b:Seg(pivot, "Pena", P(0, 0.05, 0.1), P(i * 0.42, 0.75 - math.abs(i) * 0.1, 1.45 - math.abs(i) * 0.12), 0.17 * t, 0.06 * t, c)
			if ex.fire or ex.stars then
				glow(feather)
			end
		end
		b:Seg(pivot, "Rabo", P(0, 0, 0), P(0, 0.2, 0.45), 0.15 * t, 0.15 * t, main)
	elseif kind == "bolt" then
		local c = ex.bolts or ex.lines or second
		local pts = { P(0, 0, 0), P(0.22, 0.38, 0.25), P(-0.18, 0.62, 0.35), P(0.2, 0.98, 0.5), P(0, 1.3, 0.48) }
		local segs = b:Chain(pivot, "Raio", pts, R({ 0.11, 0.1, 0.1, 0.08 }), main)
		for i, s in ipairs(segs) do
			if i % 2 == 0 then
				glow(s, c)
			end
		end
	elseif kind == "bone" then
		-- vértebras numa espinha fina
		local pts = { P(0, 0, 0), P(0, 0.3, 0.38), P(0, 0.72, 0.62), P(0, 1.1, 0.66) }
		b:Chain(pivot, "Rabo", pts, R({ 0.06, 0.05, 0.04 }), BONE)
		for i = 1, 6 do
			local f = (i - 1) / 5 * 3
			local seg = math.min(math.floor(f) + 1, 3)
			local p = pts[seg]:Lerp(pts[seg + 1], f - seg + 1)
			b:E(pivot, "Vertebra", V(0.2, 0.2, 0.12) * t * (1 - i * 0.09), BONE, aim(p, pts[seg + 1]))
		end
	elseif kind == "bandage" then
		b:Chain(pivot, "Rabo", { P(0, 0, 0), P(0, 0.2, 0.4), P(0, 0.45, 0.8), P(0, 0.55, 1.12) }, R({ 0.12, 0.1, 0.08 }), main)
		b:Seg(pivot, "Bandagem", P(0, 0.5, 1.0), P(0.12, 0.1, 1.55), 0.07 * t, 0.02 * t, ex.bandages or BONE, Enum.Material.Fabric)
	elseif kind == "stars" then
		local pts = { P(0, 0, 0), P(0, 0.35, 0.35), P(0, 0.75, 0.55), P(0, 1.1, 0.45) }
		b:Chain(pivot, "Rabo", pts, R({ 0.16, 0.13, 0.1 }), main)
		for i = 2, 4 do
			local p = pts[i]
			glow(b:E(pivot, "Estrela", V(0.18, 0.18, 0.18) * t * (0.6 + i * 0.12), i == 4 and WHITE or second, CF(p.X, p.Y, p.Z) * ANG(0, 0, PI / 4)))
		end
	elseif kind == "tentacles" then
		for i = -1, 1 do
			local pts = { P(0, 0, 0), P(i * 0.25, 0.25, 0.5), P(i * 0.55, 0.15 + math.abs(i) * 0.1, 1.0), P(i * 0.7, 0.45, 1.4), P(i * 0.6, 0.75, 1.55) }
			local segs = b:Chain(pivot, "Tentaculo", pts, R({ 0.13, 0.1, 0.08, 0.06 }), main)
			glow(segs[#segs], second)
		end
	elseif kind == "rock" then
		b:Chain(pivot, "Rabo", { P(0, 0, 0), P(0, 0.2, 0.42), P(0, 0.38, 0.75) }, R({ 0.2, 0.16 }), main)
		b:K(pivot, "RaboPedra", V(0.36, 0.3, 0.36) * t, second, CF(0, 0.42 * t, 0.82 * t) * ANG(0.5, 0.6, 0.2), Enum.Material.Slate)
	elseif kind == "antenna" then
		b:Seg(pivot, "Rabo", P(0, 0, 0), P(0, 0.9, 0.55), 0.05 * t, 0.05 * t, STEEL, Enum.Material.Metal)
		b:E(pivot, "RaboJunta", V(0.24, 0.24, 0.24) * t, second, CF(0, 0, 0), Enum.Material.Metal)
		glow(b:E(pivot, "RaboLuz", V(0.2, 0.2, 0.2) * t, ex.robot or look.eye, CF(0, 0.95 * t, 0.58 * t)))
	elseif kind == "wisp" then
		local w = b:Seg(pivot, "Rabo", P(0, 0, 0), P(0, 0.6, 0.8), 0.25 * t, 0.25 * t, main)
		b:Seg(pivot, "RaboChama", P(0, 0.5, 0.7), P(0, 1.05, 1.25), 0.16 * t, 0.16 * t, look.second)
		local _ = w
	end
	return pivot
end

---------------------------------------------------------------- asas
local function buildWings(b, torso, look, B)
	local kind = look.extras.wings
	local ws = look.wingSize or 1
	for _, side in ipairs({ -1, 1 }) do
		local name = side < 0 and "WingL" or "WingR"
		local pivot = b:Pivot(name)
		b:Joint(name, torso, pivot, CF(side * B.w * 0.3, B.h * 0.42, -B.len * 0.12) * ANG(0, 0, side * 0.35), CFrame.new())
		local function P(x, y, z)
			return V(side * x * ws, y * ws, z * ws)
		end
		if kind == "dragon" then
			local bone = look.wingBone or look.main
			local mem = look.wingColor or look.second
			local shoulder, elbow, wrist = P(0, 0, 0), P(1.1, 0.55, 0.15), P(2.3, 1.0, 0.0)
			local f1, f2, f3, f4 = P(3.3, 0.45, 0.55), P(2.9, -0.15, 1.25), P(2.0, -0.35, 1.65), P(0.9, -0.1, 1.2)
			b:Seg(pivot, "AsaOsso", shoulder, elbow, 0.14 * ws, 0.14 * ws, bone)
			b:Seg(pivot, "AsaOsso", elbow, wrist, 0.11 * ws, 0.11 * ws, bone)
			for _, f in ipairs({ f1, f2, f3 }) do
				b:Seg(pivot, "AsaDedo", wrist, f, 0.06 * ws, 0.06 * ws, bone)
			end
			b:Triangle(pivot, "AsaMembrana", wrist, f1, f2, 0.05 * ws, mem, Enum.Material.SmoothPlastic)
			b:Triangle(pivot, "AsaMembrana", wrist, f2, f3, 0.05 * ws, mem, Enum.Material.SmoothPlastic)
			b:Triangle(pivot, "AsaMembrana", wrist, f3, f4, 0.05 * ws, mem, Enum.Material.SmoothPlastic)
			b:Triangle(pivot, "AsaMembrana", wrist, f4, shoulder, 0.05 * ws, mem, Enum.Material.SmoothPlastic)
			b:Seg(pivot, "AsaGarra", wrist, wrist + P(0.15, 0.35, -0.15), 0.05 * ws, 0.05 * ws, BONE)
		else
			-- asa de penas: braço subindo para fora; penas descem para trás, maiores na ponta
			local cols = look.wingColors or { look.belly, look.second, look.main }
			local elbow, tip = P(0.95, 0.75, 0.15), P(1.75, 1.55, 0.35)
			b:Seg(pivot, "AsaBraco", P(0, 0, 0), elbow, 0.26 * ws, 0.16 * ws, cols[1])
			b:Seg(pivot, "AsaBraco", elbow, tip, 0.2 * ws, 0.13 * ws, cols[1])
			for i = 0, 6 do
				local f = i / 6
				local root = P(0.2, 0.15, 0.1):Lerp(tip, f)
				local len = (0.85 + f * 1.0) * ws
				local dir = V(side * (0.1 + f * 0.55), -0.55 + f * 0.25, 1).Unit
				local normal = (tip - P(0, 0, 0)).Unit:Cross(dir)
				local feather = b:Seg(pivot, "Pena", root, root + dir * len, 0.22 * ws, 0.05 * ws, cols[2 + (i % 2)], nil, normal)
				if look.extras.fire then
					glow(feather)
				end
			end
			for i = 0, 3 do
				local root = P(0.3, 0.3, 0.12):Lerp(tip, i / 3)
				local d = V(side * 0.15, -0.3, 0.55)
				b:Seg(pivot, "PenaCobertura", root, root + d * ws, 0.24 * ws, 0.07 * ws, cols[1], nil, (tip - P(0, 0, 0)).Unit:Cross(d.Unit))
			end
		end
		-- COTOVELO da asa (junta "WingL2"/"WingR2"): a parte de fora dobra e chicoteia na batida.
		-- Tudo que fica além do cotovelo (mais para fora) passa para a parte de fora.
		local elbow = kind == "dragon" and P(1.1, 0.55, 0.15) or P(0.95, 0.75, 0.15)
		local outer = b:Pivot(name .. "2")
		b:Joint(name .. "2", pivot, outer, CF(elbow), CFrame.new())
		local limit = math.abs(elbow.X) * b.S * 0.92
		for _, w in ipairs(b.Model:GetDescendants()) do
			if w:IsA("Weld") and w.Part0 == pivot and w.Part1 then
				if pivot.CFrame:ToObjectSpace(w.Part1.CFrame).Position.X * side > limit then
					w.Part0 = outer
					w.C0 = outer.CFrame:ToObjectSpace(w.Part1.CFrame)
					w.C1 = CFrame.new()
				end
			end
		end
	end
end

---------------------------------------------------------------- corpo
-- posição lateral do pescoço de cada cabeça (2 e 3 cabeças abrem em leque)
local function headX(count, i, B)
	if count == 2 then
		return (i == 1 and -1 or 1) * B.w * 0.36
	elseif count == 3 then
		return (i - 2) * B.w * 0.44
	end
	return 0
end

-- ponto na superfície aproximada do tronco: a = ângulo em volta do eixo Z (0 = topo), fz = -0.5..0.5
local function bodySurf(B, a, fz, push)
	local rx, ry = B.w * 0.5, B.h * 0.5
	local z = fz * B.len
	local k = math.sqrt(math.max(0.05, 1 - (2 * fz) ^ 2))
	local p = V(math.sin(a) * rx * k, math.cos(a) * ry * k + B.h * 0.04, z)
	local n = V(p.X / (rx * rx), (p.Y - B.h * 0.04) / (ry * ry), z / (B.len * B.len * 0.25)).Unit
	p += n * (push or 0)
	return CFrame.lookAt(p, p + n)
end

local function buildBody(b, torso, look, B)
	local ex = look.extras
	local chest, haunch = B.chest or 1, B.haunch or 1
	local main, belly = look.main, look.belly
	local mat = look.material

	b:E(torso, "Peito", V(B.w * chest, B.h * 1.02 * chest, B.len * 0.56), main, CF(0, -B.h * 0.02 * chest, -B.len * 0.21))
	b:E(torso, "Quadril", V(B.w * 0.94 * haunch, B.h * 0.9 * haunch, B.len * 0.5), main, CF(0, B.h * 0.07, B.len * 0.25))
	-- peito/barriga claros
	if not ex.noBelly then
		b:E(torso, "Peitoral", V(B.w * 0.66 * chest, B.h * 0.74 * chest, B.len * 0.3), belly, CF(0, -B.h * 0.12 * chest, -B.len * 0.36 * (0.9 + chest * 0.1)))
		b:E(torso, "Barriga", V(B.w * 0.62, B.h * 0.34, B.len * 0.56), belly, CF(0, -B.h * 0.3, -B.len * 0.02))
	end
	if B.saddle then
		b:E(torso, "Sela", V(B.w * 0.9 * math.max(chest, 1) * 0.97, B.h * 0.55, B.len * 0.86), B.saddle, CF(0, B.h * 0.25, B.len * 0.02))
	end

	-- pescoço(s)
	local count = look.heads or 1
	local H = look.head
	for i = 1, count do
		local x = headX(count, i, B)
		local top = V(x * 1.15, B.h * 0.3 + (H.lift or 0) + ((count == 3 and i == 2) and 0.3 or 0), -B.len * 0.45 - (H.forward or 0))
		local base = V(x * 0.8, B.h * 0.08, -B.len * 0.3)
		local r = 0.3 * H.size * (H.neckW or 1)
		b:Seg(torso, "Pescoco", base, top, r * 1.05, r, look.neckColor or main)
		b:Seg(torso, "Garganta", base + V(0, -B.h * 0.12, -0.05), top + V(0, -0.22 * H.size, -0.1 * H.size), r * 0.8, r * 0.7, H.throat or belly)
		if ex.collar then
			local c = base:Lerp(top, 0.62)
			local coll =
				b:E(torso, "Coleira", V(r * 2.2, r * 2.15, 0.22), ex.collar, aim(c + (top - base).Unit * 0.05, top) * CF(0, 0, 0), Enum.Material.SmoothPlastic)
			local _ = coll
			if ex.spikedCollar then
				local dir = (top - base).Unit
				local cfc = aim(c, c + dir)
				local studs = count >= 2 and 2 or 4
				for k = 0, studs do
					local a = -PI / 2 + k * PI / studs
					local cf = cfc * ANG(0, 0, a) * CF(0, r * 1.12, 0)
					b:W(torso, "Tacha", V(0.1, 0.24, 0.16), STEEL, cf * ANG(PI / 2, 0, 0) * CF(0, 0.08, 0), Enum.Material.Metal)
				end
			elseif ex.tag ~= false then
				b:E(torso, "Plaquinha", V(0.2, 0.2, 0.06), GOLD, CF(c.X, c.Y - r * 1.05, c.Z - 0.12), Enum.Material.Foil)
			end
		end
		if ex.scarf then
			b:E(torso, "Cachecol", V(r * 2.4, r * 2.3, 0.4), ex.scarf, aim((top + base) / 2, top), Enum.Material.Fabric)
		end
	end
	if ex.scarf then
		b:Seg(
			torso,
			"CachecolPonta",
			V(B.w * 0.25, B.h * 0.32, -B.len * 0.3),
			V(B.w * 0.45, B.h * 0.55, B.len * 0.12),
			0.18,
			0.05,
			ex.scarf,
			Enum.Material.Fabric
		)
		b:Seg(
			torso,
			"CachecolPonta",
			V(B.w * 0.3, B.h * 0.38, -B.len * 0.25),
			V(B.w * 0.15, B.h * 0.72, B.len * 0.22),
			0.16,
			0.05,
			ex.scarf,
			Enum.Material.Fabric
		)
	end

	if ex.ruff then
		-- pelo do peito (golden, lobo, husky)
		for i = -1, 1 do
			b:Seg(torso, "PeloPeito", V(i * B.w * 0.2, -B.h * 0.05, -B.len * 0.42), V(i * B.w * 0.24, -B.h * 0.5, -B.len * 0.46), 0.22, 0.16, ex.ruff)
		end
	end
	if ex.fringe then
		-- franjas de pelo embaixo da barriga e atrás das coxas (golden)
		for i = 0, 2 do
			b:Seg(
				torso,
				"Franja",
				V(0, -B.h * 0.3, -B.len * 0.22 + i * B.len * 0.2),
				V(0, -B.h * 0.62, -B.len * 0.18 + i * B.len * 0.22),
				B.w * 0.3,
				0.16,
				ex.fringe
			)
		end
		for _, side in ipairs({ -1, 1 }) do
			b:Seg(torso, "Franja", V(side * B.w * 0.36, -B.h * 0.05, B.len * 0.4), V(side * B.w * 0.36, -B.h * 0.5, B.len * 0.48), 0.2, 0.24, ex.fringe)
		end
	end
	if ex.muscles then
		for _, side in ipairs({ -1, 1 }) do
			b:E(torso, "Ombro", V(B.w * 0.55, B.h * 0.85, B.len * 0.4), main, CF(side * B.w * 0.4, B.h * 0.1, -B.len * 0.26))
		end
		b:E(torso, "Trapezio", V(B.w * 0.8, B.h * 0.5, B.len * 0.36), main, CF(0, B.h * 0.42, -B.len * 0.3))
	end
	if ex.mane then
		local k = ex.spiky and 0.9 or 1
		b:E(torso, "Juba", V(B.w * 1.22 * k, B.h * 1.25 * k, B.len * 0.36), ex.mane, CF(0, B.h * 0.16, -B.len * 0.36))
		if ex.spiky then
			for i = -2, 2 do
				b:Tri(
					torso,
					"JubaEspeto",
					CF(i * B.w * 0.22, B.h * 0.55 - math.abs(i) * 0.12, -B.len * 0.3) * ANG(-0.9, 0, -i * 0.45),
					0.42,
					0.7 - math.abs(i) * 0.08,
					0.12,
					ex.mane
				)
			end
		end
	end
	if ex.spikes then
		local n = ex.spikeCount or 5
		for i = 0, n - 1 do
			local f = i / math.max(n - 1, 1)
			local z = -B.len * 0.34 + f * B.len * 0.72
			local h = (0.55 - f * 0.18) * (ex.spikeSize or 1)
			local y = B.h * 0.5 * math.sqrt(math.max(0.2, 1 - (2 * z / B.len) ^ 2)) + B.h * 0.1
			b:W(torso, "Espinho", V(0.1, h, h * 0.9), ex.spikes, CF(0, y + h * 0.4, z) * ANG(0.15, 0, 0), mat)
		end
	end
	if ex.fin then
		b:Triangle(torso, "Barbatana", V(0, B.h * 0.4, -B.len * 0.15), V(0, B.h * 0.4, B.len * 0.22), V(0, B.h * 0.5 + 1.3, B.len * 0.3), 0.14, look.second)
	end
	if ex.pecFins then
		for _, side in ipairs({ -1, 1 }) do
			b:Triangle(
				torso,
				"NadadeiraPeito",
				V(side * B.w * 0.42, -B.h * 0.15, -B.len * 0.28),
				V(side * B.w * 0.42, -B.h * 0.15, -B.len * 0.05),
				V(side * (B.w * 0.5 + 0.9), -B.h * 0.45, B.len * 0.12),
				0.08,
				look.second
			)
		end
	end
	if ex.gills then
		for _, side in ipairs({ -1, 1 }) do
			for i = 0, 2 do
				b:Seg(
					torso,
					"Guelra",
					V(side * B.w * 0.5, B.h * 0.25, -B.len * 0.38 + i * 0.16),
					V(side * B.w * 0.48, -B.h * 0.15, -B.len * 0.34 + i * 0.16),
					0.025,
					0.025,
					shade(look.main, 0.55)
				)
			end
		end
	end
	if ex.crystals then
		local list = {
			{ 0, 0.5, -0.18, 0, 1.1 },
			{ 0.32, 0.4, 0.05, -0.55, 0.85 },
			{ -0.32, 0.4, 0.1, 0.55, 0.8 },
			{ 0.1, 0.45, 0.3, -0.25, 0.7 },
			{ -0.15, 0.45, -0.38, 0.35, 0.75 },
			{ 0.4, 0.2, -0.3, -0.9, 0.55 },
		}
		for i, cfg in ipairs(list) do
			local h = cfg[5] * (ex.crystalSize or 1)
			local base = CF(cfg[1] * B.w, cfg[2] * B.h, cfg[3] * B.len) * ANG(0, i * 0.7, cfg[4])
			local c1 = b:Tri(torso, "Cristal", base, 0.38 * h, h, 0.3 * h, ex.crystals, Enum.Material.Glass)
			local c2 = b:Tri(torso, "Cristal", base * ANG(0, PI / 2, 0), 0.38 * h, h, 0.3 * h, ex.crystals, Enum.Material.Glass)
			c1.Transparency = 0.1
			c2.Transparency = 0.1
			if i % 2 == 1 then
				glow(c1)
			end
		end
	end
	if ex.armor then
		-- armadura em lâminas sobrepostas nas costas + ombreiras + rebites dourados
		local ac = ex.armor
		for i = 0, 2 do
			local z = -B.len * 0.24 + i * B.len * 0.22
			local band = shade(ac, 1 - i * 0.08)
			b:E(torso, "Armadura", V(B.w * 1.08, B.h * 0.66, B.len * 0.27), band, CF(0, B.h * 0.2 - i * 0.02, z) * ANG(-0.12, 0, 0), Enum.Material.Metal)
			b:E(torso, "Rebite", V(0.14, 0.14, 0.14), GOLD, CF(0, B.h * 0.55 - i * 0.02, z + B.len * 0.03), Enum.Material.Foil)
		end
		for _, side in ipairs({ -1, 1 }) do
			b:E(
				torso,
				"Ombreira",
				V(B.w * 0.26, B.h * 0.62, B.len * 0.3),
				ac,
				CF(side * B.w * 0.5, B.h * 0.08, -B.len * 0.3) * ANG(0, 0, side * 0.35),
				Enum.Material.Metal
			)
			b:E(
				torso,
				"OmbreiraBorda",
				V(B.w * 0.27, B.h * 0.14, B.len * 0.31),
				GOLD,
				CF(side * B.w * 0.47, -B.h * 0.18, -B.len * 0.3) * ANG(0, 0, side * 0.35),
				Enum.Material.Foil
			)
		end
	end
	if ex.samurai then
		-- sode (ombreiras em lâminas) + cinto
		for _, side in ipairs({ -1, 1 }) do
			for r = 0, 2 do
				b:K(
					torso,
					"Sode",
					V(0.08, 0.22, B.len * 0.28),
					r % 2 == 0 and ex.samurai or GOLD,
					CF(side * (B.w * 0.52 + r * 0.03), B.h * (0.25 - r * 0.2), -B.len * 0.24) * ANG(0, 0, side * 0.25),
					Enum.Material.SmoothPlastic
				)
			end
		end
		b:E(torso, "Obi", V(B.w * 1.02, B.h * 1.0, 0.3), ex.samurai, CF(0, B.h * 0.02, B.len * 0.05), Enum.Material.Fabric)
	end
	if ex.katana then
		local cf = CF(B.w * 0.58, B.h * 0.1, 0.1) * ANG(0.2, 0, 0)
		b:K(torso, "Katana", V(0.1, 0.18, 2.4), C(40, 30, 35), cf, Enum.Material.SmoothPlastic)
		b:K(torso, "Tsuba", V(0.14, 0.34, 0.08), GOLD, cf * CF(0, 0, -1.22), Enum.Material.Foil)
		b:K(torso, "Cabo", V(0.12, 0.16, 0.7), C(200, 40, 40), cf * CF(0, 0, -1.6), Enum.Material.Fabric)
	end
	if ex.spots then
		local rng = Random.new(ex.spotSeed or 7)
		for _ = 1, ex.spotCount or 12 do
			local a = rng:NextNumber(-2.4, 2.4)
			local cf = bodySurf(B, a, rng:NextNumber(-0.42, 0.42), 0.02)
			b:E(torso, "Mancha", V(0.34, 0.3, 0.12) * rng:NextNumber(0.7, 1.25), ex.spots, cf, Enum.Material.SmoothPlastic)
		end
	end
	if ex.patches then
		-- manchas grandes (vira-lata/bulldog malhado)
		b:E(torso, "Malha", V(B.w * 0.75, B.h * 0.7, B.len * 0.42), ex.patches, CF(B.w * 0.18, B.h * 0.2, B.len * 0.18))
	end
	if ex.ribs then
		for _, side in ipairs({ -1, 1 }) do
			for i = 0, 3 do
				local z = -B.len * 0.3 + i * B.len * 0.13
				b:Seg(
					torso,
					"Costela",
					V(side * B.w * 0.1, B.h * 0.5, z),
					V(side * B.w * 0.52, -B.h * 0.12, z - 0.05),
					0.07,
					0.05,
					ex.ribs,
					Enum.Material.SmoothPlastic
				)
			end
		end
		for i = 0, 5 do
			b:E(
				torso,
				"Vertebra",
				V(0.22, 0.18, 0.2),
				ex.ribs,
				CF(0, B.h * 0.52 - math.abs(i - 2.5) * 0.02, -B.len * 0.38 + i * B.len * 0.15),
				Enum.Material.SmoothPlastic
			)
		end
		b:E(torso, "Pelve", V(B.w * 0.7, 0.2, 0.4), ex.ribs, CF(0, B.h * 0.38, B.len * 0.3) * ANG(0.3, 0, 0), Enum.Material.SmoothPlastic)
	end
	if ex.bandages then
		for i = 0, 4 do
			b:E(
				torso,
				"Bandagem",
				V(B.w * 1.06, B.h * 1.06, 0.2),
				ex.bandages,
				CF(0, 0, -B.len * 0.36 + i * B.len * 0.18) * ANG(0.25 * (i % 2 == 0 and 1 or -1), 0, 0.1 * (i - 2)),
				Enum.Material.Fabric
			)
		end
		b:Seg(
			torso,
			"BandagemSolta",
			V(B.w * 0.45, B.h * 0.2, B.len * 0.1),
			V(B.w * 0.62, -B.h * 0.55, B.len * 0.2),
			0.12,
			0.03,
			ex.bandages,
			Enum.Material.Fabric
		)
	end
	if ex.usekh then
		-- colar egípcio
		b:E(torso, "Usekh", V(B.w * 0.9, B.h * 0.8, 0.3), ex.usekh, CF(0, B.h * 0.12, -B.len * 0.43) * ANG(-0.35, 0, 0), Enum.Material.Foil)
		b:E(torso, "UsekhAzul", V(B.w * 0.8, B.h * 0.66, 0.32), C(40, 90, 200), CF(0, B.h * 0.1, -B.len * 0.44) * ANG(-0.35, 0, 0), Enum.Material.SmoothPlastic)
	end
	if ex.lines or ex.bolts then
		local c = ex.lines or ex.bolts
		for _, side in ipairs({ -1, 1 }) do
			if ex.bolts then
				local pts = { { -0.38, 0.25 }, { -0.15, -0.15 }, { 0.05, 0.2 }, { 0.3, -0.2 } }
				for i = 1, #pts - 1 do
					local a = bodySurf(B, side * (PI / 2 - pts[i][2]), pts[i][1], 0.01).Position
					local d = bodySurf(B, side * (PI / 2 - pts[i + 1][2]), pts[i + 1][1], 0.01).Position
					glow(b:Seg(torso, "Raio", a, d, 0.06, 0.06, c))
				end
			else
				for k = 0, 1 do
					local a = bodySurf(B, side * (PI / 2 - 0.25 + k * 0.4), -0.32, 0.01).Position
					local d = bodySurf(B, side * (PI / 2 - 0.05 + k * 0.4), 0.35, 0.01).Position
					glow(b:Seg(torso, "Linha", a, d, 0.05, 0.05, c))
				end
			end
		end
	end
	if ex.cracks then
		local rng = Random.new(3)
		for i = 1, 8 do
			local side = i % 2 == 0 and -1 or 1
			local fz = rng:NextNumber(-0.38, 0.38)
			local a = side * rng:NextNumber(0.6, 2.0)
			local p1 = bodySurf(B, a, fz, 0.01).Position
			local p2 = bodySurf(B, a + side * rng:NextNumber(0.25, 0.5), fz + rng:NextNumber(-0.12, 0.12), 0.01).Position
			glow(b:Seg(torso, "Rachadura", p1, p2, 0.05, 0.05, ex.cracks))
		end
	end
	if ex.rocks then
		local rng = Random.new(11)
		for i = 1, 7 do
			local d = rng:NextNumber(0.4, 0.75)
			local cf = bodySurf(B, rng:NextNumber(-1.1, 1.1), rng:NextNumber(-0.38, 0.38), d * 0.12)
			b:K(
				torso,
				"Rocha" .. i,
				V(d, d * 0.75, d),
				i % 2 == 0 and look.second or look.belly,
				cf * ANG(rng:NextNumber(0, 3), rng:NextNumber(0, 3), 0),
				Enum.Material.Slate
			)
		end
	end
	if ex.robot then
		b:K(torso, "Painel", V(B.w * 0.75, B.h * 0.25, B.len * 0.58), look.second, CF(0, B.h * 0.4, 0), Enum.Material.Metal)
		glow(b:K(torso, "PainelLuz", V(B.w * 0.5, 0.06, B.len * 0.1), ex.robot, CF(0, B.h * 0.53, -B.len * 0.12)))
		glow(b:K(torso, "PainelLuz", V(B.w * 0.5, 0.06, B.len * 0.1), ex.robot, CF(0, B.h * 0.53, B.len * 0.08)))
		for _, side in ipairs({ -1, 1 }) do
			b:K(torso, "Placa", V(0.08, B.h * 0.5, B.len * 0.45), look.belly, CF(side * B.w * 0.5, 0, -B.len * 0.05), Enum.Material.Metal)
			glow(b:E(torso, "Luz", V(0.06, 0.18, 0.18), ex.robot, CF(side * B.w * 0.54, 0, -B.len * 0.05)))
		end
	end
	if ex.galaxy or ex.stars then
		local rng = Random.new(5)
		for _ = 1, 12 do
			local cf = bodySurf(B, rng:NextNumber(-2.2, 2.2), rng:NextNumber(-0.42, 0.42), 0.02)
			glow(b:E(torso, "Estrela", V(0.12, 0.12, 0.08), rng:NextNumber() < 0.5 and WHITE or look.second, cf * ANG(0, 0, PI / 4)))
		end
	end
	if ex.galaxy then
		glow(b:E(torso, "Nebulosa", V(B.w * 0.6, B.h * 0.45, B.len * 0.5), look.belly, CF(B.w * 0.24, B.h * 0.12, 0.1))).Transparency = 0.35
	end
	if ex.ring then
		-- anel planetário em volta do corpo
		for k = 0, 15 do
			local a = k / 16 * PI * 2
			local p = V(math.cos(a) * B.w * 1.15, 0, math.sin(a) * B.len * 0.62)
			local seg = b:E(torso, "Anel", V(0.12, 0.08, 0.55), ex.ring, CF(0, B.h * 0.1, 0) * ANG(0.25, 0, 0.2) * aim(p, p + V(-math.sin(a), 0, math.cos(a))))
			glow(seg)
		end
	end
	if ex.scales then
		for i = 0, 4 do
			b:E(torso, "Escama", V(B.w * 0.62, 0.14, 0.32), look.belly, CF(0, -B.h * 0.47, -B.len * 0.32 + i * B.len * 0.15), Enum.Material.SmoothPlastic)
		end
	end
	if ex.pustules then
		local rng = Random.new(9)
		for _ = 1, 6 do
			local cf = bodySurf(B, rng:NextNumber(-1.2, 1.2), rng:NextNumber(-0.35, 0.35), 0.02)
			local d = rng:NextNumber(0.25, 0.42)
			glow(b:E(torso, "Bolha", V(d, d, d * 0.7), ex.pustules, cf))
		end
		for i = 0, 2 do
			glow(b:E(torso, "Gota", V(0.12, 0.22, 0.12), ex.pustules, CF((i - 1) * 0.35, -B.h * 0.56, -B.len * 0.1 + i * 0.3)))
		end
	end
	if ex.icicleBack then
		for i = 0, 4 do
			local z = -B.len * 0.32 + i * B.len * 0.16
			local h = 0.7 - math.abs(i - 2) * 0.12
			b:Tri(torso, "Gelo", CF(0, B.h * 0.5, z) * ANG(-0.25, PI / 2, 0), 0.4, h, 0.18, ex.icicleBack, Enum.Material.Ice)
		end
	end
	if ex.rift then
		-- fenda do vazio no peito
		local cf = CF(0, -B.h * 0.02, -B.len * 0.48)
		glow(b:E(torso, "Fenda", V(0.5, 0.9, 0.12), look.second, cf))
		b:E(torso, "FendaCentro", V(0.26, 0.6, 0.14), DARK, cf * CF(0, 0, -0.04), Enum.Material.SmoothPlastic)
	end
	if ex.chains then
		for _, side in ipairs({ -1, 1 }) do
			for k = 0, 4 do
				local p = V(side * B.w * (0.52 - k * 0.02), B.h * (0.1 - k * 0.14) + 0.0, -B.len * 0.36 + k * 0.32)
				b:E(torso, "Corrente", V(0.08, 0.26, 0.38), GOLD, CF(p.X, p.Y, p.Z) * ANG(0.4, 0, k % 2 == 0 and 0 or PI / 2), Enum.Material.Foil)
			end
		end
	end
	if ex.wisps then
		for i = -1, 1 do
			local w = b:Seg(torso, "Fumacinha", V(i * B.w * 0.25, -B.h * 0.3, B.len * 0.1), V(i * B.w * 0.4, -B.h * 0.9, B.len * 0.35), 0.22, 0.22, look.second)
			w.Transparency = 0.35
		end
	end
end

---------------------------------------------------------------- patas
-- Cada perna é um Motor6D no ombro/quadril; coxa, canela, pata e dedos são soldados nela.
-- A ponta da pata fica exatamente no chão: chão = ombro - comprimento total.
local function buildLegs(b, torso, look, B)
	local L = look.legs
	local ex = look.extras
	local jy = -B.h * 0.1
	local Lt = L.len + B.h * 0.4 -- do ombro ao chão
	for _, def in ipairs({ { "LegFL", -1, -1 }, { "LegFR", 1, -1 }, { "LegBL", -1, 1 }, { "LegBR", 1, 1 } }) do
		local name, sx, sz = def[1], def[2], def[3]
		local front = sz < 0
		local thick = L.thick * (front and (L.front or 1) or (L.hind or 1))
		local bowed = front and L.bowed
		local jx = sx * B.w * (bowed and 0.36 or (front and 0.28 or 0.27))
		local jz = sz * B.len * (front and 0.3 or 0.31)
		local ul = Lt * 0.55
		local center = ul * 0.32
		local legC = L.color or look.main
		local robot = ex.robot ~= nil
		local bone = ex.ribs ~= nil

		local leg
		if robot then
			leg = b:Block(name, V(thick * 1.3, ul, thick * 1.4), legC)
		elseif bone then
			leg = b:Ellipsoid(name, V(thick * 1.1, ul, thick * 1.2), legC)
		elseif front then
			leg = b:Ellipsoid(name, V(thick * 1.35, ul, thick * 1.45), legC)
		else
			leg = b:Ellipsoid(name, V(thick * 1.55, ul * 1.08, thick * 1.95), legC)
		end
		b:Joint(name, torso, leg, CF(jx, jy, jz), CF(0, center, front and 0 or -thick * 0.15))
		-- coordenadas a partir do ombro (y para baixo até -Lt)
		local function J(x, y, z)
			return V(x, y + center, z + (front and 0 or thick * 0.15))
		end
		local ph = thick * 0.62
		local footX = bowed and sx * thick * 0.45 or 0
		local footZ = -thick * 0.25
		local footY = -Lt + ph * 0.5
		local lowerC = L.lower or legC

		-- canela
		if robot then
			b:K(leg, "Canela", V(thick * 0.9, Lt * 0.55, thick * 0.9), look.second, CF(J(0, -Lt * 0.68, -0.02)), Enum.Material.Metal)
			glow(b:E(leg, "Junta", V(thick * 1.15, thick * 1.15, thick * 1.15), ex.robot, CF(J(0, -Lt * 0.42, 0))))
		elseif front then
			b:Seg(leg, "Canela", J(0, -Lt * 0.35, 0), J(footX * 0.8, footY + ph * 0.3, -thick * 0.08), thick * 0.5, thick * 0.52, lowerC)
		else
			local hock = J(0, -Lt * 0.66, thick * 0.65)
			b:Seg(leg, "Canela", J(0, -Lt * 0.3, thick * 0.35), hock, thick * 0.58, thick * 0.62, lowerC)
			b:Seg(leg, "Canela", hock, J(0, footY + ph * 0.3, -thick * 0.02), thick * 0.45, thick * 0.47, lowerC)
		end
		if bone then
			b:E(leg, "Junta", V(thick * 0.95, thick * 0.95, thick * 0.95), BONE, CF(J(0, -Lt * 0.36, front and 0 or thick * 0.4)), Enum.Material.SmoothPlastic)
		end

		if ex.muscles and front then
			b:E(leg, "Antebraco", V(thick * 1.35, Lt * 0.32, thick * 1.4), legC, CF(J(footX * 0.4, -Lt * 0.55, -thick * 0.08)))
		end
		if L.bands and front then
			b:E(
				leg,
				"Pulseira",
				V(thick * 1.25, Lt * 0.1, thick * 1.3),
				L.bands,
				CF(J(footX * 0.7, footY + ph * 1.7, -thick * 0.06)),
				Enum.Material.SmoothPlastic
			)
		end
		-- meia (pata de outra cor subindo pela canela)
		local sockC = L.socks
		if sockC then
			local sh = (L.sockH or 0.35) * Lt
			b:Seg(
				leg,
				"Meia",
				J(footX * 0.9, footY + ph * 0.3, -thick * 0.06),
				J(footX * 0.7, footY + sh, front and -thick * 0.04 or thick * 0.1),
				thick * 0.54,
				thick * 0.56,
				sockC
			)
		end
		-- pelo atrás da perna (golden, husky)
		if L.feather and front then
			b:Seg(leg, "PeloPerna", J(0, -Lt * 0.25, thick * 0.4), J(0, -Lt * 0.62, thick * 0.75), thick * 0.4, thick * 0.55, L.feather)
		end
		if ex.poms then
			b:E(leg, "Pompom", V(thick * 2.1, thick * 1.8, thick * 2.1), look.second, CF(J(footX, footY + ph * 1.6, footZ * 0.4)))
			b:E(leg, "Pompom", V(thick * 1.9, ul * 0.55, thick * 2.1), look.second, CF(J(0, -ul * 0.25, 0)))
		end
		if ex.bandages then
			for k = 0, 1 do
				b:E(
					leg,
					"Bandagem",
					V(thick * 1.25, 0.14, thick * 1.3),
					ex.bandages,
					CF(J(0, -Lt * (0.4 + k * 0.25), 0.05)) * ANG(0.3 - k * 0.6, 0, 0),
					Enum.Material.Fabric
				)
			end
		end
		if ex.bolts and front then
			glow(b:E(leg, "Faisca", V(thick * 1.25, 0.1, thick * 1.3), ex.bolts, CF(J(footX, footY + ph * 1.5, 0))))
		end
		if ex.legFire then
			glow(b:Seg(leg, "Chama", J(footX, footY + ph * 0.5, thick * 0.2), J(footX, footY + ph * 2.4, thick * 0.9), thick * 0.45, thick * 0.45, ex.legFire))
		end

		-- pata + dedos
		local pawC = L.paw or sockC or (robot and look.second) or legC
		local pawMat = robot and Enum.Material.Metal or nil
		local pawCF = CF(J(footX, footY, footZ)) * ANG(0, bowed and sx * -0.35 or 0, 0)
		local paw
		if robot then
			paw = b:Block("Pata", V(thick * 1.3, ph, thick * 1.6) * 1, pawC)
		else
			paw = b:Ellipsoid("Pata", V(thick * 1.32, ph * 1.05, thick * 1.6), pawC, pawMat)
		end
		b:Attach(leg, paw, pawCF)
		if not L.noToes then
			for i = -1, 1 do
				local toe = pawCF * CF(i * thick * 0.38, -ph * 0.12, -thick * 0.62)
				if L.claws then
					b:W(
						leg,
						"Garra",
						V(thick * 0.16, thick * 0.32, thick * 0.4),
						L.claws,
						toe * CF(0, -ph * 0.05, -thick * 0.2) * ANG(0, 0, 0),
						Enum.Material.SmoothPlastic
					)
				end
				b:E(leg, "Dedo", V(thick * 0.44, ph * 0.78, thick * 0.5), pawC, toe, pawMat)
			end
		end
	end
	return L.len
end

-- JOELHOS (para a animação dobrar a perna): cada perna ganha uma junta Motor6D "Knee.." (KneeFL, KneeFR...).
-- Dianteira: "punho" (carpo) perto da pata; traseira: jarrete (hock), onde a canela dobra.
-- Roda no FIM do Build (depois dos pacotes): tudo que está soldado na perna ABAIXO da junta passa para a
-- parte de baixo, então enfeites de pacotes (vinhas, chamas, meias) também acompanham a pata.
-- Robôs ficam sem joelho (perna dura de propósito).
local function addKnees(b, model, torso, look, B)
	if look.extras.robot then
		return
	end
	local L = look.legs
	local Lt = L.len + B.h * 0.4 -- do ombro ao chão (igual ao buildLegs)
	local center = Lt * 0.55 * 0.32
	for _, name in ipairs({ "LegFL", "LegFR", "LegBL", "LegBR" }) do
		local motor = torso:FindFirstChild(name)
		local leg = motor and motor:IsA("Motor6D") and motor.Part1
		if leg then
			local front = name == "LegFL" or name == "LegFR"
			local thick = L.thick * (front and (L.front or 1) or (L.hind or 1))
			local zoff = front and 0 or thick * 0.15
			local knee = front and V(0, -Lt * 0.8 + center, -thick * 0.06 + zoff) or V(0, -Lt * 0.66 + center, thick * 0.65 + zoff)
			local suffix = string.sub(name, 4)
			local pivot = b:Pivot("Knee" .. suffix)
			b:Joint("Knee" .. suffix, leg, pivot, CF(knee), CF())
			local kneeY = knee.Y * b.S
			for _, w in ipairs(model:GetDescendants()) do
				if w:IsA("Weld") and w.Part0 == leg and w.Part1 then
					if leg.CFrame:ToObjectSpace(w.Part1.CFrame).Position.Y < kneeY then
						w.Part0 = pivot
						w.C0 = pivot.CFrame:ToObjectSpace(w.Part1.CFrame)
						w.C1 = CFrame.new()
					end
				end
			end
		end
	end
end

---------------------------------------------------------------- efeitos
local function addEffects(b, model, torso, look, rarity)
	local ex = look.extras
	local order = rarity and rarity.Order or 1
	-- (as auras de raridade grandes ficam no cliente: DogFX)
	if ex.aura then
		emitter(torso, {
			Name = "Aura",
			Color = ColorSequence.new(ex.aura),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4 * b.S), NumberSequenceKeypoint.new(1, 0) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(0.8, 1.4),
			Rate = order >= 5 and 8 or 4,
			Speed = NumberRange.new(1, 2.5),
			SpreadAngle = Vector2.new(180, 180),
		})
	end
	if order >= 5 then
		local light = Instance.new("PointLight")
		light.Color = ex.aura or rarity.Color
		light.Range = 10 * b.S
		light.Brightness = 0.8
		light.Parent = torso
	end
	if ex.smoke then
		emitter(torso, {
			Name = "Fumaca",
			Texture = SMOKE,
			LightEmission = 0,
			Color = ColorSequence.new(ex.smoke),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1 * b.S), NumberSequenceKeypoint.new(1, 2.5 * b.S) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(1, 1.6),
			Rate = 8,
			Speed = NumberRange.new(0.5, 1.5),
			SpreadAngle = Vector2.new(60, 60),
			Acceleration = Vector3.new(0, 1.5, 0),
		})
	end
	if ex.fire then
		local fire = Instance.new("Fire")
		fire.Color = ex.fire
		fire.SecondaryColor = C(255, 220, 80)
		fire.Size = 2.2 * b.S
		fire.Heat = 4
		fire.Parent = torso
	end
	if ex.bubbles then
		emitter(torso, {
			Name = "Bolhas",
			Color = ColorSequence.new(ex.bubbles),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2 * b.S), NumberSequenceKeypoint.new(1, 0.45 * b.S) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(1, 1.5),
			Rate = 8,
			Speed = NumberRange.new(1, 2),
			Acceleration = Vector3.new(0, 2, 0),
		})
	end
	if ex.stars then
		emitter(torso, {
			Name = "Estrelas",
			Color = ColorSequence.new(WHITE, look.second),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35 * b.S), NumberSequenceKeypoint.new(1, 0) }),
			Lifetime = NumberRange.new(1, 2),
			Rate = 10,
			Speed = NumberRange.new(0.3, 1),
			SpreadAngle = Vector2.new(180, 180),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-90, 90),
		})
	end
	if ex.trail then
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, 0.3, 0.5) * b.S
		a0.Parent = torso
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -0.3, 0.5) * b.S
		a1.Parent = torso
		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Color = ColorSequence.new(ex.trail)
		trail.LightEmission = 1
		trail.Lifetime = 0.35
		trail.Transparency = NumberSequence.new(0.2, 1)
		trail.Parent = torso
	end
	if ex.ghost then
		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" and p.Transparency < 1 and p.Material ~= Enum.Material.Neon then
				p.Transparency = math.max(p.Transparency, 0.3)
			end
		end
	end
end

---------------------------------------------------------------- API
local function defaults(look, rarity)
	local order = rarity and rarity.Order or 1
	look.extras = look.extras or {}
	if not look.mood then
		look.mood = order <= 2 and "happy" or (order == 3 and "calm" or "fierce")
	end
	if not look.eyes then
		if look.extras.eyeGlow then
			look.eyes = "glow"
		elseif look.mood == "happy" then
			look.eyes = "cute"
		else
			look.eyes = "white"
		end
	end
end

-- Retorna o Model do cachorro (sem Humanoid). options = { scale = number }
function DogBuilder.Build(speciesId, options)
	options = options or {}
	local species = DogData.Species[speciesId]
	assert(species, "Unknown species: " .. tostring(speciesId))
	local look = table.clone(species.Look)
	local rarity = Config.RARITY[species.Rarity]
	defaults(look, rarity)
	look.Rarity = species.Rarity
	local S = (look.scale or 1) * (options.scale or 1)
	local B = look.body

	local model = Instance.new("Model")
	model.Name = species.Name
	local b = Builder.new(model, S, look.material or Enum.Material.SmoothPlastic, options.style)

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(B.w, B.h, B.len) * S
	root.Transparency = 1
	root.CanCollide = true
	root.CanTouch = false
	root.CanQuery = true
	root.TopSurface = Enum.SurfaceType.Smooth
	root.BottomSurface = Enum.SurfaceType.Smooth
	root.CFrame = CFrame.new()
	root.Parent = model
	model.PrimaryPart = root

	local torso = b:Ellipsoid("Torso", Vector3.new(B.w * 0.86, B.h * 0.82, B.len * 0.9), look.main)
	b:Joint("Body", root, torso, CFrame.new(), CFrame.new())

	buildBody(b, torso, look, B)
	local hip = buildLegs(b, torso, look, B)
	local count = look.heads or 1
	for i = 1, count do
		local x = headX(count, i, B)
		local lift = (look.head.lift or 0) + ((count == 3 and i == 2) and 0.3 or 0)
		buildHead(b, torso, look, i, count, Vector3.new(x * 1.15, B.h * 0.3 + lift, -B.len * 0.45 - (look.head.forward or 0)))
	end
	buildTail(b, torso, look, B)
	if look.extras.wings then
		buildWings(b, torso, look, B)
	end
	addEffects(b, model, torso, look, rarity)
	-- gancho para pacotes: Look.build(builder, ctx) adiciona geometria própria usando
	-- b:Ellipsoid/b:Block/b:Wedge/b:Attach/b:Joint (offsets em unidades, a escala é aplicada pelo builder)
	if type(look.build) == "function" then
		local ok, err = pcall(look.build, b, { Model = model, Root = root, Torso = torso, Look = look, Body = B, Scale = S })
		if not ok then
			warn("[DogBuilder] build extra falhou em", speciesId, err)
		end
	end
	addKnees(b, model, torso, look, B)
	if b.Style == "Blocky" then
		local seed = 0
		for i = 1, #speciesId do
			seed = (seed * 31 + string.byte(speciesId, i)) % 1000003
		end
		flatEyes(model)
		chamfer(model, seed)
	end

	local float = look.extras.float or 0
	model:SetAttribute("Species", speciesId)
	model:SetAttribute("HipHeight", (hip + float) * S)
	model:SetAttribute("BaseScale", S)
	model:SetAttribute("Heads", count)
	model:SetAttribute("Float", float > 0)
	-- 🪽 com asas: o cachorro do jogador fica no chão e voa com espaço 2x (DogService.SetFlying)
	-- conta como "voador" quem tem asas OU flutuava (alguns pacotes fazem asas próprias no build)
	model:SetAttribute("Wings", look.extras.wings == true or float > 0)
	model:SetAttribute("GroundHip", hip * S)
	return model
end

-- Ovo decorado (para o ninho perto da casinha e para a tela de chocar)
function DogBuilder.Egg(eggId, scale)
	local egg = DogData.Eggs[eggId]
	local s = scale or 1
	local model = Instance.new("Model")
	model.Name = egg.Name
	local b = Builder.new(model, s, egg.Glass and Enum.Material.Glass or Enum.Material.SmoothPlastic, "Round") -- ovo sempre redondo
	local shell = b:Ellipsoid("Casca", Vector3.new(2, 2.6, 2), egg.Color)
	shell.Anchored = true
	shell.Massless = false
	shell.CanQuery = true
	if egg.Glass then
		shell.Transparency = 0.15
	end
	if egg.Shiny then
		shell.Reflectance = 0.25
	end
	shell.Parent = model
	model.PrimaryPart = shell
	local rng = Random.new(#eggId)
	for _ = 1, 7 do
		local a = rng:NextNumber(0, math.pi * 2)
		local y = rng:NextNumber(-0.7, 0.8)
		local r = math.sqrt(math.max(0.05, 1 - (y / 1.3) ^ 2))
		local spot = b:Ellipsoid("Pinta", Vector3.new(0.45, 0.45, 0.12) * rng:NextNumber(0.7, 1.2), egg.Spots, Enum.Material.SmoothPlastic)
		local pos = Vector3.new(math.cos(a) * r * 0.98, y, math.sin(a) * r * 0.98)
		b:Attach(shell, spot, CFrame.lookAt(pos, pos * 2))
	end
	if egg.Shiny then
		emitter(shell, {
			Color = ColorSequence.new(egg.Spots),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4 * s), NumberSequenceKeypoint.new(1, 0) }),
			Lifetime = NumberRange.new(0.6, 1.2),
			Rate = 6,
			Speed = NumberRange.new(1, 2),
			SpreadAngle = Vector2.new(180, 180),
		})
	end
	return model
end

return DogBuilder

--[[ ================================================================
     ARQUIVO: src/shared/DogData.lua
================================================================ ]]
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
			body = { len = 3, w = 1.4, h = 1.3 },
			legs = { len = 1.0, thick = 0.38, socks = C(248, 222, 180), sockH = 0.18 },
			head = { size = 1.4, snout = 0.8, lift = 0.4 },
			ears = "semi",
			tail = "curl",
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
				snoutW = 1.3,
				flat = true,
				forward = 0.1,
				lift = 0.3,
				muzzle = C(60, 48, 45),
				wrinkles = true,
				eyeSize = 1.25,
				eyeGap = 0.25,
				tongue = true,
			},
			ears = "rose",
			earSize = 0.95,
			tail = "curl",
			tailTip = C(226, 196, 148),
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
			head = { size = 1.25, snout = 0.8, snoutW = 0.7, lift = 0.55, brows = C(185, 105, 50), eyeSize = 1.2, neckW = 0.8 },
			ears = "big",
			earSize = 0.92,
			earInner = C(200, 120, 110),
			tail = "thin",
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
			head = { size = 1.25, snout = 0.95, snoutW = 0.7, lift = 0.55, nose = C(40, 35, 40), neckW = 0.8 },
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
				size = 1.4,
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
			head = { size = 1.3, snout = 1.15, snoutW = 0.7, lift = 0.6, brows = C(160, 90, 42), long = 1.05, neckW = 0.9 },
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
			head = { size = 1.45, snout = 0.9, lift = 0.45, muzzle = C(248, 214, 156), eyeSize = 1.1 },
			ears = "long",
			earSize = 0.95,
			earTip = C(214, 150, 70),
			tail = "fluffy",
			tailFeather = C(248, 214, 156),
			extras = { ruff = C(248, 214, 156), fringe = C(240, 196, 120) },
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
			head = { size = 1.35, snout = 0.95, lift = 0.5, spotEye = C(28, 28, 30), eyeGap = 0.22 },
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
			main = C(44, 34, 52),
			second = C(140, 20, 45),
			belly = C(58, 42, 62),
			eye = C(255, 40, 60),
			body = { len = 3.5, w = 2.4, h = 1.75, chest = 1.35 },
			legs = { len = 1.15, thick = 0.56, front = 1.15, claws = C(140, 20, 45), noToes = true },
			head = { size = 1.55, snout = 1.0, forward = 0.45, lift = 0.75, neckW = 0.85, muzzle = C(30, 24, 34) },
			mood = "evil",
			ears = "pointy",
			earInner = C(140, 20, 45),
			tail = "whip",
			tailSize = 1.3,
			spikeColor = C(140, 20, 45),
			heads = 3,
			extras = {
				smoke = C(60, 10, 30),
				spikedCollar = true,
				collar = C(90, 90, 100),
				spikes = C(140, 20, 45),
				mane = C(24, 18, 28),
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
}

-- Level alto melhora um pouco as chances: até +5 pontos tirados da raridade mais baixa e
-- divididos entre as duas mais altas do ovo.
-- Chances (%) de cada raridade para um ovo. Level alto melhora um pouco: até +5 pontos tirados da
-- raridade mais baixa e divididos entre as duas mais altas do ovo. Usado no sorteio e na tela do inventário.
local RARITY_ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }
function DogData.EggOdds(eggId, dogLevel)
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
		bonus = math.max(0, math.min(bonus, odds[lowest] - 1))
		odds[lowest] -= bonus
		odds[top] += bonus * 0.4
		odds[second] += bonus * 0.6
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

function DogData.RollRarity(eggId, dogLevel, rng)
	local list = DogData.EggOdds(eggId, dogLevel)
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

function DogData.RollSpecies(eggId, dogLevel)
	local rng = Random.new()
	local rarity = DogData.RollRarity(eggId, dogLevel, rng)
	local list = DogData.SpeciesOfRarity(rarity)
	return list[rng:NextInteger(1, #list)], rarity
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
DogData.ELEMENT_ORDER = { "Fire", "Ice", "Thunder", "Poison", "Water", "Shadow", "Earth", "Light" }
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

local powers = nil -- [speciesId] = { poder2, poder3 }
local function buildPowers()
	powers = {}
	local used = {}
	local order = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6 }
	local list = {}
	for id, sp in pairs(DogData.Species) do
		if not sp.BossOnly then
			table.insert(list, id)
		end
	end
	-- raros primeiro: os melhores ficam com os poderes "únicos"
	table.sort(list, function(a, b)
		local ra, rb = order[DogData.Species[a].Rarity] or 0, order[DogData.Species[b].Rarity] or 0
		if ra ~= rb then
			return ra > rb
		end
		return a < b
	end)
	local BIG = { "Rain", "Vortex", "Slam", "Beam" }
	local function nextElemental(element, preferBig, avoid)
		local best, bestUses = nil, math.huge
		local elems = { element }
		for _, e in ipairs(DogData.ELEMENT_ORDER) do
			if e ~= element then
				table.insert(elems, e)
			end
		end
		for pass = 1, 2 do
			for ei, e in ipairs(elems) do
				for _, sh in ipairs(preferBig and pass == 1 and BIG or DogData.SHAPE_ORDER) do
					local name = "El_" .. e .. "_" .. sh
					-- o elemento do cachorro vale mais (desempate)
					local uses = (used[name] or 0) * 10 + (ei == 1 and 0 or 1)
					if name ~= avoid and uses < bestUses then
						best, bestUses = name, uses
					end
				end
			end
			if best and bestUses < 10 then
				break
			end
		end
		used[best] = (used[best] or 0) + 1
		return best
	end
	for _, id in ipairs(list) do
		local sp = DogData.Species[id]
		local element = elementFor(id, sp)
		local big = sp.Rarity == "Mythic" or sp.Rarity == "Legendary"
		local p2 = sp.Special
		if (used[p2] or 0) > 0 or not DogData.Specials[p2] then
			p2 = nextElemental(element, big)
		else
			used[p2] = 1
		end
		-- poder 3 = ULTIMATE: sempre uma forma grande (Rain/Vortex/Slam/Beam) (pedido do dono)
		local p3 = sp.Power3 or nextElemental(element, true, p2)
		-- o 3 vira a versão ULTIMATE (combo em 3 fases) da forma grande escolhida
		local e3, s3 = string.match(p3, "^El_(%a+)_(%a+)$")
		if e3 and table.find(DogData.BIG_SHAPES, s3) then
			p3 = "Ult_" .. e3 .. "_" .. s3
		end
		local supreme = sp.Rarity == "Mythic" and ("Supreme_" .. element) or nil
		powers[id] = { p2, p3, supreme }
	end
end

-- { poder da habilidade 2, poder da habilidade 3 }
function DogData.PowersFor(speciesId)
	if not powers then
		buildPowers()
	end
	return powers[speciesId] or { "Pounce", "Charge" }
end

function DogData.ThirdPower(speciesId)
	return DogData.PowersFor(speciesId)[2]
end

return DogData

--[[ ================================================================
     ARQUIVO: src/shared/DogPacks/PackA.lua
================================================================ ]]
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
	return hs, 0.95 * (H.w or 1) * hs / 2, 0.9 * (H.tall or 1) * hs / 2, 1.0 * (H.long or 1) * hs / 2
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
			head = { size = 1.45, snout = 0.85, snoutW = 1.05, lift = 0.4, muzzle = WHITE, blaze = WHITE, eyeSize = 1.15 },
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
			head = { size = 1.45, snout = 0.75, lift = 0.55, blaze = WHITE, muzzle = WHITE, cheeks = WHITE, eyeSize = 1.1 },
			mood = "happy",
			ears = "big",
			earSize = 1.02,
			earInner = C(240, 170, 160),
			tail = "stub",
			tailColor = WHITE,
			extras = { ruff = WHITE },
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
				size = 1.25,
				snout = 1.15,
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
				size = 1.45,
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
			head = { size = 1.4, snout = 0.95, snoutW = 0.85, lift = 0.5, blaze = WHITE, muzzle = WHITE, eyeSize = 1.1 },
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
			head = { size = 1.2, snout = 1.3, snoutW = 0.6, long = 1.15, lift = 0.75, neckW = 0.7, eyeSize = 0.95 },
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

--[[ ================================================================
     ARQUIVO: src/shared/DogPacks/PackB.lua
================================================================ ]]
-- Pacote B: 7 Épicos + 6 Lendários. Cada um muda a ANATOMIA (silhueta, membros, postura),
-- não só a cor: perna de pau, cabeça de planta carnívora, esteiras de tanque, tentáculos no
-- lugar das patas, postura meio de pé (yeti/lobisomem), cauda de escorpião etc.
-- Formato de Species/Look: ver o topo de DogData.lua e DogBuilder.lua. A geometria própria fica em
-- Look.build(b, ctx) (b = Builder do DogBuilder; ctx = { Model, Root, Torso, Look, Body, Scale }).
-- Medidas em "unidades" do cachorro (o Builder aplica a escala). Convenção: o cachorro olha para -Z.
-- Poderes "B_*": server/Services/SpecialsPacks/PackB.lua; efeitos: client/EffectsPacks/PackB.lua.
local C = Color3.fromRGB
local PI = math.pi

local WHITE = C(250, 250, 250)
local DARK = C(24, 20, 22)
local GOLD = C(245, 195, 70)
local STEEL = C(170, 176, 188)
local WOOD = C(130, 88, 52)
local BONE = C(240, 232, 210)

local NEON = Enum.Material.Neon
local METAL = Enum.Material.Metal
local FABRIC = Enum.Material.Fabric
local SMOOTH = Enum.Material.SmoothPlastic
local GLASS = Enum.Material.Glass
local FOIL = Enum.Material.Foil

local LEGS = { "LegFL", "LegFR", "LegBL", "LegBR" }

local function V(x, y, z)
	return Vector3.new(x, y, z)
end

local function CF(x, y, z)
	return CFrame.new(x, y, z)
end

local function ANG(x, y, z)
	return CFrame.Angles(x, y, z)
end

---------------------------------------------------------------- utilidades de construção
local function glow(p, color)
	p.Material = NEON
	if color then
		p.Color = color
	end
	p.CastShadow = false
	return p
end

-- peças soldadas num segmento (opcionalmente só as com nome em `names`)
local function welded(model, seg, names)
	local list = {}
	for _, p in ipairs(model:GetChildren()) do
		if p:IsA("BasePart") then
			local w = p:FindFirstChildOfClass("Weld")
			if w and w.Part0 == seg and (names == nil or names[p.Name]) then
				table.insert(list, p)
			end
		end
	end
	return list
end

local function strip(model, seg, names)
	for _, p in ipairs(welded(model, seg, names)) do
		p:Destroy()
	end
end

local function set(...)
	local t = {}
	for _, n in ipairs({ ... }) do
		t[n] = true
	end
	return t
end

-- solda uma peça numa posição do MUNDO (CFrame em studs), convertendo para o espaço do segmento
local function _attachWorld(b, seg, part, worldCF)
	local rel = seg.CFrame:Inverse() * worldCF
	return b:Attach(seg, part, CFrame.new(rel.Position / b.S) * rel.Rotation)
end

-- CFrame em unidades no espaço de `seg` -> mundo
local function toWorld(b, seg, cf)
	return seg.CFrame * (CFrame.new(cf.Position * b.S) * cf.Rotation)
end

-- CFrame em unidades no espaço de `from` -> unidades no espaço de `to`
local function between(b, from, to, cf)
	local rel = to.CFrame:Inverse() * toWorld(b, from, cf)
	return CFrame.new(rel.Position / b.S) * rel.Rotation
end

local function headDims(look)
	local H = look.head
	local hs = H.size
	return hs, 0.95 * (H.w or 1) * hs / 2, 0.9 * (H.tall or 1) * hs / 2, (H.long or 1) * hs / 2
end

-- pontos no espaço da perna (y = 0 no ombro/quadril, -Lt no chão)
local function legFrame(look, B, front)
	local L = look.legs
	local thick = L.thick * (front and (L.front or 1) or (L.hind or 1))
	local Lt = L.len + B.h * 0.4
	local center = Lt * 0.55 * 0.32
	local zoff = front and 0 or thick * 0.15
	return function(x, y, z)
		return V(x, y + center, z + zoff)
	end, thick, Lt
end

-- Postura meio de pé: inclina o tronco (nariz para cima) sem tirar as patas do lugar.
-- Chamar POR ÚLTIMO no build (as outras peças usam os CFrames de antes da inclinação).
local function tilt(ctx, a)
	local body = ctx.Root:FindFirstChild("Body")
	if not body then
		return
	end
	body.C0 = ANG(a, 0, 0)
	for _, n in ipairs(LEGS) do
		local m = ctx.Torso:FindFirstChild(n)
		if m then
			m.C0 = ANG(-a, 0, 0) * m.C0
		end
	end
end

-- ponto na superfície aproximada do tronco (a = ângulo em volta de Z, 0 = topo; fz = -0.5..0.5)
local function bodyPoint(B, a, fz, push)
	local rx, ry = B.w * 0.5, B.h * 0.5
	local k = math.sqrt(math.max(0.05, 1 - (2 * fz) ^ 2))
	local p = V(math.sin(a) * rx * k, math.cos(a) * ry * k + B.h * 0.04, fz * B.len)
	local n = V(p.X / (rx * rx), (p.Y - B.h * 0.04) / (ry * ry), p.Z / (B.len * B.len * 0.25)).Unit
	p += n * (push or 0)
	return CFrame.lookAt(p, p + n)
end

-- chão no espaço do tronco
local function groundY(look, B)
	return -B.h / 2 - look.legs.len
end

---------------------------------------------------------------- builds
local Build = {}

-- Pirata: tricórnio, tapa-olho, casaco, perna de pau, gancho, âncora nas costas e papagaio no ombro
function Build.pirate(b, ctx)
	local model, torso, look, B = ctx.Model, ctx.Torso, ctx.Look, ctx.Body
	local head = model:FindFirstChild("Head1")
	local hs, ax, ay, az = headDims(look)
	local RED = C(170, 30, 35)
	local BLACK = C(30, 26, 28)
	if head then
		-- tricórnio
		local hat = CF(0, ay * 0.82, 0.05 * hs)
		b:E(head, "Chapeu", V(ax * 2.6, 0.16 * hs, az * 2.5), BLACK, hat, FABRIC)
		b:E(head, "ChapeuCopa", V(ax * 1.6, ay * 0.9, az * 1.5), BLACK, hat * CF(0, 0.22 * hs, 0.02 * hs), FABRIC)
		for i = 0, 2 do
			local a = i / 3 * PI * 2 + PI
			local cf = hat * ANG(0, a, 0) * CF(0, 0.08 * hs, -az * 1.05) * ANG(-1.0, 0, 0)
			b:K(head, "ChapeuAba", V(ax * 1.55, 0.36 * hs, 0.07 * hs), BLACK, cf * CF(0, 0.12 * hs, 0), FABRIC)
			b:K(head, "ChapeuBorda", V(ax * 1.58, 0.05 * hs, 0.08 * hs), GOLD, cf * CF(0, 0.3 * hs, 0), FOIL)
		end
		-- caveirinha na frente do chapéu
		local skull = hat * CF(0, 0.2 * hs, -az * 0.98)
		b:E(head, "Caveira", V(0.2, 0.18, 0.06) * hs, WHITE, skull, SMOOTH)
		b:Seg(head, "Ossinho", (skull * CF(-0.14 * hs, -0.12 * hs, 0)).Position, (skull * CF(0.14 * hs, -0.02 * hs, 0)).Position, 0.025 * hs, 0.025 * hs, WHITE)
		b:Seg(head, "Ossinho", (skull * CF(0.14 * hs, -0.12 * hs, 0)).Position, (skull * CF(-0.14 * hs, -0.02 * hs, 0)).Position, 0.025 * hs, 0.025 * hs, WHITE)
		-- tapa-olho (olho direito do cachorro = -X)
		local gap, ey = 0.21 * hs, 0.08 * hs
		local u = 1 - (gap / ax) ^ 2 - (ey / ay) ^ 2
		local ez = -az * math.sqrt(math.max(u, 0.03))
		b:E(head, "TapaOlho", V(0.3, 0.28, 0.1) * hs, BLACK, CF(-gap, ey, ez - 0.03 * hs), SMOOTH)
		b:E(head, "TapaOlhoTira", V(ax * 2.05, 0.05 * hs, az * 2.0), BLACK, CF(0, ey + 0.05 * hs, 0) * ANG(0, 0, 0.32), SMOOTH)
		-- argola de ouro na orelha
		for k = 0, 5 do
			local a = k / 6 * PI * 2
			b:E(head, "Brinco", V(0.06, 0.06, 0.06) * hs, GOLD, CF(ax * 1.02, -0.05 * hs + math.cos(a) * 0.09 * hs, 0.1 * hs + math.sin(a) * 0.09 * hs), FOIL)
		end
	end
	-- casaco vermelho com botões e faixa
	b:E(torso, "Casaco", V(B.w * 1.06, B.h * 1.04, B.len * 0.62), RED, CF(0, B.h * 0.02, -B.len * 0.15), FABRIC)
	b:E(torso, "Gola", V(B.w * 0.9, B.h * 0.5, 0.35), C(240, 230, 210), CF(0, B.h * 0.18, -B.len * 0.44) * ANG(-0.5, 0, 0), FABRIC)
	for i = 0, 2 do
		b:E(torso, "Botao", V(0.14, 0.14, 0.08), GOLD, CF(0, -B.h * 0.08 - i * 0.18, -B.len * 0.47 + i * 0.05) * ANG(-0.4, 0, 0), FOIL)
	end
	b:E(torso, "Faixa", V(B.w * 1.08, B.h * 1.06, 0.28), C(60, 40, 110), CF(0, 0, B.len * 0.14), FABRIC)
	-- âncora presa nas costas
	local anc = CF(B.w * 0.1, B.h * 0.62, B.len * 0.12) * ANG(0, 0, 0.35)
	b:K(torso, "Ancora", V(0.14, 0.14, 1.5), C(70, 72, 80), anc, METAL)
	b:K(torso, "Ancora", V(0.7, 0.12, 0.12), C(70, 72, 80), anc * CF(0, 0, -0.55), METAL)
	b:Seg(torso, "AncoraBraco", (anc * CF(0, 0, 0.75)).Position, (anc * CF(0.45, 0.05, 0.45)).Position, 0.08, 0.08, C(70, 72, 80), METAL)
	b:Seg(torso, "AncoraBraco", (anc * CF(0, 0, 0.75)).Position, (anc * CF(-0.45, 0.05, 0.45)).Position, 0.08, 0.08, C(70, 72, 80), METAL)
	b:E(torso, "AncoraArgola", V(0.3, 0.1, 0.3), C(70, 72, 80), anc * CF(0, 0, -0.85), METAL)
	-- papagaio no ombro esquerdo
	local pp = CF(B.w * 0.42, B.h * 0.56, -B.len * 0.24)
	b:E(torso, "Papagaio", V(0.42, 0.62, 0.42), C(40, 190, 70), pp * CF(0, 0.25, 0) * ANG(0.2, 0, 0))
	b:E(torso, "PapagaioBarriga", V(0.3, 0.42, 0.25), C(250, 210, 40), pp * CF(0, 0.2, -0.12) * ANG(0.2, 0, 0))
	b:E(torso, "PapagaioCabeca", V(0.34, 0.34, 0.36), C(220, 40, 40), pp * CF(0, 0.66, -0.06))
	b:W(torso, "PapagaioBico", V(0.1, 0.18, 0.16), C(250, 200, 60), pp * CF(0, 0.6, -0.26) * ANG(PI, 0, 0), SMOOTH)
	b:E(torso, "PapagaioOlho", V(0.07, 0.07, 0.05), DARK, pp * CF(0.12, 0.7, -0.15), SMOOTH)
	b:E(torso, "PapagaioOlho", V(0.07, 0.07, 0.05), DARK, pp * CF(-0.12, 0.7, -0.15), SMOOTH)
	b:Seg(torso, "PapagaioRabo", (pp * CF(0, 0.1, 0.15)).Position, (pp * CF(0, -0.35, 0.65)).Position, 0.1, 0.04, C(40, 110, 220))
	b:Seg(torso, "PapagaioAsa", (pp * CF(0.18, 0.45, 0)).Position, (pp * CF(0.22, 0.05, 0.25)).Position, 0.05, 0.12, C(40, 110, 220))
	-- perna de pau (traseira direita) e gancho (dianteira esquerda)
	local peg = model:FindFirstChild("LegBR")
	if peg then
		strip(model, peg, set("Canela", "Pata", "Dedo", "Garra", "Meia"))
		local J, thick, Lt = legFrame(look, B, false)
		b:Seg(peg, "PernaDePau", J(0, -Lt * 0.32, 0), J(0, -Lt, 0), thick * 0.24, thick * 0.24, WOOD, Enum.Material.Wood)
		b:E(peg, "PernaDePauAnel", V(thick * 0.85, thick * 0.3, thick * 0.85), GOLD, CF(J(0, -Lt * 0.36, 0)), FOIL)
		b:E(peg, "PernaDePauPonta", V(thick * 0.55, thick * 0.2, thick * 0.55), C(60, 45, 30), CF(J(0, -Lt + thick * 0.1, 0)), SMOOTH)
	end
	local hookLeg = model:FindFirstChild("LegFL")
	if hookLeg then
		strip(model, hookLeg, set("Pata", "Dedo", "Garra"))
		local J, thick, Lt = legFrame(look, B, true)
		local base = J(0, -Lt + thick * 0.95, -0.02)
		b:E(hookLeg, "Punho", V(thick * 1.3, thick * 0.45, thick * 1.3), C(90, 60, 40), CF(base), FABRIC)
		local pts = {
			base,
			base + V(0, -thick * 0.45, 0),
			base + V(0, -thick * 0.8, -thick * 0.3),
			base + V(0, -thick * 0.7, -thick * 0.75),
			base + V(0, -thick * 0.35, -thick * 0.85),
		}
		b:Chain(hookLeg, "Gancho", pts, { thick * 0.13, thick * 0.12, thick * 0.1, thick * 0.07 }, STEEL, METAL)
	end
end

-- Escorpião: corpo baixo e largo, carapaça em placas, pinças enormes à frente e cauda em arco com ferrão
function Build.scorpion(b, ctx)
	local model, torso, look, B = ctx.Model, ctx.Torso, ctx.Look, ctx.Body
	local shell, amber = look.main, look.second
	local plate = C(70, 55, 78)
	-- carapaça em placas sobrepostas
	for i = 0, 4 do
		local z = -B.len * 0.36 + i * B.len * 0.18
		b:E(
			torso,
			"Carapaca",
			V(B.w * (1.08 - math.abs(i - 2) * 0.06), B.h * 0.55, B.len * 0.26),
			i % 2 == 0 and plate or shell,
			CF(0, B.h * 0.33, z) * ANG(-0.15, 0, 0),
			SMOOTH
		)
		glow(b:E(torso, "CarapacaLinha", V(0.1, 0.06, B.len * 0.2), amber, CF(0, B.h * 0.62, z)))
	end
	-- pinças (braços saindo dos ombros para a frente)
	for _, side in ipairs({ -1, 1 }) do
		local sh = V(side * B.w * 0.45, B.h * 0.05, -B.len * 0.32)
		local elbow = V(side * B.w * 0.95, B.h * 0.0, -B.len * 0.5)
		local wrist = V(side * B.w * 0.75, -B.h * 0.05, -B.len * 0.82)
		b:Seg(torso, "BracoPinca", sh, elbow, 0.2, 0.17, shell)
		b:Seg(torso, "BracoPinca", elbow, wrist, 0.18, 0.15, plate)
		local palm = CFrame.lookAt(wrist, wrist + V(-side * 0.25, 0.05, -1))
		b:E(torso, "Pinca", V(0.62, 0.48, 0.85), shell, palm * CF(0, 0, -0.3))
		-- dedo de cima (fixo) e de baixo, abertos em V
		b:Chain(torso, "PincaDedo", {
			(palm * CF(side * 0.1, 0.1, -0.55)).Position,
			(palm * CF(side * 0.18, 0.28, -0.95)).Position,
			(palm * CF(side * 0.05, 0.18, -1.25)).Position,
		}, { 0.14, 0.09 }, plate, nil, amber)
		b:Chain(torso, "PincaDedo", {
			(palm * CF(-side * 0.08, -0.08, -0.55)).Position,
			(palm * CF(-side * 0.16, -0.25, -0.9)).Position,
			(palm * CF(-side * 0.02, -0.15, -1.15)).Position,
		}, { 0.12, 0.08 }, plate, nil, amber)
	end
	-- 2 pares de patinhas extras finas nas laterais
	local gy = groundY(look, B)
	for _, side in ipairs({ -1, 1 }) do
		for k = 0, 1 do
			local z = -B.len * 0.06 + k * B.len * 0.18
			local top = V(side * B.w * 0.42, -B.h * 0.05, z)
			local knee = V(side * B.w * 0.95, B.h * 0.12, z + 0.05)
			local foot = V(side * B.w * 1.1, gy + 0.08, z + 0.1)
			b:Seg(torso, "Patinha", top, knee, 0.09, 0.09, shell)
			b:Seg(torso, "Patinha", knee, foot, 0.07, 0.07, plate)
		end
	end
	-- cauda segmentada (no TailBase para balançar) em arco por cima das costas
	local tailBase = model:FindFirstChild("TailBase")
	if tailBase then
		strip(model, tailBase)
		local pts = {
			V(0, 0, 0),
			V(0, 0.55, 0.45),
			V(0, 1.25, 0.6),
			V(0, 1.95, 0.35),
			V(0, 2.4, -0.2),
			V(0, 2.45, -0.75),
		}
		local radii = { 0.3, 0.28, 0.26, 0.23, 0.2 }
		for i = 1, #pts - 1 do
			b:Seg(tailBase, "Cauda", pts[i], pts[i + 1], radii[i], radii[i], i % 2 == 0 and plate or shell)
			b:E(tailBase, "CaudaAnel", V(radii[i] * 2.3, radii[i] * 2.3, 0.12), amber, CFrame.lookAt(pts[i + 1], pts[i + 1] + (pts[i + 1] - pts[i])), SMOOTH)
		end
		local bulb = pts[#pts]
		glow(b:E(tailBase, "Ferrao", V(0.5, 0.45, 0.6), amber, CF(bulb.X, bulb.Y, bulb.Z - 0.15)))
		b:Chain(tailBase, "FerraoPonta", { bulb + V(0, -0.05, -0.35), bulb + V(0, -0.35, -0.65), bulb + V(0, -0.75, -0.7) }, { 0.12, 0.06 }, DARK)
		local l = Instance.new("PointLight")
		l.Color = amber
		l.Range = 8 * b.S
		l.Brightness = 1.2
		l.Parent = tailBase
	end
	-- quelíceras na frente da boca
	local head = model:FindFirstChild("Head1")
	if head then
		local hs, _, _, az = headDims(look)
		for _, side in ipairs({ -1, 1 }) do
			b:Chain(head, "Queliceras", {
				V(side * 0.18 * hs, -0.28 * hs, -az * 0.8),
				V(side * 0.3 * hs, -0.42 * hs, -az * 1.25),
				V(side * 0.12 * hs, -0.5 * hs, -az * 1.5),
			}, { 0.07 * hs, 0.05 * hs }, plate, nil, amber)
		end
	end
end

-- Dioneia: a cabeça VIRA uma planta carnívora (dois lobos com cílios que abrem com a mandíbula),
-- colar de pétalas, folhas nas costas, raízes nas patas e cauda de folha
function Build.flytrap(b, ctx)
	local model, torso, look, B = ctx.Model, ctx.Torso, ctx.Look, ctx.Body
	local green, red, light = look.main, look.second, look.belly
	local head = model:FindFirstChild("Head1")
	local jaw = model:FindFirstChild("Jaw1")
	if head and jaw then
		local hs = look.head.size
		strip(model, head)
		strip(model, jaw)
		head.Transparency = 1
		jaw.Transparency = 1
		local motor = head:FindFirstChild("Jaw1")
		local hinge = motor and CFrame.new(motor.C0.Position / b.S) or CF(0, -0.2 * hs, -0.2 * hs)
		hinge = hinge * CF(0, 0.08 * hs, 0.25 * hs)
		local function lobe(parent, up)
			local sgn = up and 1 or -1
			local open = up and 0.32 or -0.3
			local center = hinge * ANG(open, 0, 0) * CF(0, sgn * 0.1 * hs, -0.68 * hs)
			local function put(cf)
				if parent == head then
					return cf
				end
				return between(b, head, parent, cf)
			end
			b:E(parent, "Lobo", V(1.25, 0.42, 1.38) * hs, green, put(center))
			b:E(parent, "LoboDentro", V(1.12, 0.3, 1.24) * hs, red, put(center * CF(0, -sgn * 0.09 * hs, 0)), SMOOTH)
			-- pintinhas do lado de dentro
			for k = -1, 1 do
				b:E(
					parent,
					"LoboPinta",
					V(0.12, 0.05, 0.12) * hs,
					C(255, 120, 140),
					put(center * CF(k * 0.25 * hs, -sgn * 0.2 * hs, -0.1 * hs + math.abs(k) * 0.15 * hs)),
					SMOOTH
				)
			end
			-- cílios/dentes na borda
			local n = 11
			for k = 0, n - 1 do
				local a = -PI * 0.85 + k / (n - 1) * PI * 1.7
				local rim = center * CF(math.sin(a) * 0.6 * hs, -sgn * 0.07 * hs, -math.cos(a) * 0.66 * hs)
				local tip = rim * CF(math.sin(a) * 0.08 * hs, -sgn * 0.3 * hs, -math.cos(a) * 0.08 * hs)
				local ra, rb = put(rim).Position, put(tip).Position
				b:Seg(parent, "Cilio", ra, rb, 0.035 * hs, 0.035 * hs, C(250, 245, 200), SMOOTH)
			end
		end
		lobe(head, true)
		lobe(jaw, false)
		-- olhinhos em antenas em cima do lobo superior
		for _, side in ipairs({ -1, 1 }) do
			local a = hinge * ANG(0.32, 0, 0) * CF(side * 0.28 * hs, 0.22 * hs, -0.45 * hs)
			local t = a * CF(side * 0.12 * hs, 0.4 * hs, -0.05 * hs)
			b:Seg(head, "Antena", a.Position, t.Position, 0.05 * hs, 0.05 * hs, green)
			b:E(head, "Olho", V(0.24, 0.24, 0.24) * hs, C(255, 240, 120), t * CF(0, 0.08 * hs, 0), SMOOTH)
			b:E(head, "Pupila", V(0.1, 0.16, 0.06) * hs, DARK, t * CF(0, 0.08 * hs, -0.11 * hs), SMOOTH)
		end
	end
	-- colar de pétalas no pescoço
	local neck = V(0, B.h * 0.3, -B.len * 0.4)
	for k = 0, 9 do
		local a = k / 10 * PI * 2
		local cf = CF(neck.X, neck.Y, neck.Z) * ANG(-0.5, 0, 0) * ANG(0, 0, a) * CF(0, 0.55, 0) * ANG(0.5, 0, 0)
		b:Tri(torso, "Petala", cf, 0.55, 0.75, 0.08, k % 2 == 0 and C(240, 70, 120) or C(255, 150, 60))
	end
	-- folhas nas costas
	for i = 0, 3 do
		local z = -B.len * 0.25 + i * B.len * 0.18
		for _, side in ipairs({ -1, 1 }) do
			local cf = CF(side * B.w * 0.15, B.h * 0.45, z) * ANG(-0.4, 0, -side * (0.7 + i * 0.1))
			b:Tri(torso, "Folha", cf, 0.5, 0.9 - i * 0.08, 0.06, i % 2 == 0 and light or green)
		end
	end
	-- cauda de folha
	local tailBase = model:FindFirstChild("TailBase")
	if tailBase then
		strip(model, tailBase)
		b:Seg(tailBase, "Caule", V(0, 0, 0), V(0, 0.6, 0.55), 0.1, 0.1, green)
		b:Tri(tailBase, "FolhaRabo", CF(0, 0.55, 0.5) * ANG(-0.6, 0, 0), 0.7, 1.1, 0.06, light)
		b:E(tailBase, "Botao", V(0.4, 0.5, 0.4), red, CF(0, 0.75, 0.55))
	end
	-- raízes/vinhas em volta das patas
	for _, n in ipairs(LEGS) do
		local leg = model:FindFirstChild(n)
		if leg then
			local front = n == "LegFL" or n == "LegFR"
			local J, thick, Lt = legFrame(look, B, front)
			for k = 0, 2 do
				local y = -Lt * (0.25 + k * 0.22)
				b:E(
					leg,
					"Vinha",
					V(thick * 1.25, 0.1, thick * 1.3),
					C(60, 120, 45),
					CF(J(0, y, front and 0 or thick * 0.2)) * ANG(0.3 * (k % 2 == 0 and 1 or -1), 0, 0.2),
					SMOOTH
				)
			end
			for _, side in ipairs({ -1, 1 }) do
				b:Seg(leg, "Raiz", J(side * thick * 0.3, -Lt + thick * 0.2, 0), J(side * thick * 0.95, -Lt + 0.04, -thick * 0.3), 0.06, 0.06, C(110, 75, 45))
			end
		end
	end
end

-- DJ: fones gigantes, óculos neon, caixas de som nas costas, toca-discos, corrente com disco e tênis
function Build.dj(b, ctx)
	local model, torso, look, B = ctx.Model, ctx.Torso, ctx.Look, ctx.Body
	local cyan, pink = look.second, C(255, 60, 200)
	local head = model:FindFirstChild("Head1")
	local hs, ax, ay, az = headDims(look)
	if head then
		-- arco dos fones
		local pts = {}
		for k = 0, 6 do
			local a = -PI / 2 + k / 6 * PI
			table.insert(pts, V(math.sin(a) * ax * 1.2, ay * 0.15 + math.cos(a) * ay * 1.25, 0.05 * hs))
		end
		b:Chain(head, "FoneArco", pts, { 0.07 * hs, 0.07 * hs, 0.07 * hs, 0.07 * hs, 0.07 * hs, 0.07 * hs }, C(40, 40, 50))
		for _, side in ipairs({ -1, 1 }) do
			local cup = CF(side * ax * 1.18, 0.05 * hs, 0.05 * hs) * ANG(0, 0, side * PI / 2)
			b:E(head, "Fone", V(0.62, 0.32, 0.62) * hs, C(40, 40, 50), cup, SMOOTH)
			glow(b:E(head, "FoneLuz", V(0.5, 0.06, 0.5) * hs, side < 0 and cyan or pink, cup * CF(0, -side * 0.16 * hs, 0)))
		end
		-- óculos (viseira inteira) com borda neon
		local gy = (look.head.eyeY or 0.08) * hs
		local gz = -az * 0.86
		b:K(head, "Oculos", V(ax * 1.75, 0.2 * hs, 0.08 * hs), C(20, 20, 30), CF(0, gy + 0.02 * hs, gz) * ANG(-0.1, 0, 0), SMOOTH)
		glow(b:K(head, "OculosLuz", V(ax * 1.78, 0.04 * hs, 0.085 * hs), cyan, CF(0, gy + 0.12 * hs, gz) * ANG(-0.1, 0, 0)))
		glow(b:K(head, "OculosLuz", V(ax * 1.0, 0.03 * hs, 0.09 * hs), pink, CF(0, gy - 0.03 * hs, gz - 0.01 * hs) * ANG(-0.1, 0, 0)))
		-- topete espetado
		for i = -1, 1 do
			b:Tri(head, "Topete", CF(i * 0.14 * hs, ay * 0.8, 0.0) * ANG(-0.6, 0, -i * 0.4), 0.22 * hs, 0.45 * hs, 0.08 * hs, i == 0 and pink or look.main)
		end
	end
	-- corrente de ouro com disco de vinil
	local nk = V(0, B.h * 0.05, -B.len * 0.46)
	for k = 0, 7 do
		local a = -PI * 0.45 + k / 7 * PI * 0.9
		b:E(torso, "Corrente", V(0.14, 0.14, 0.14), GOLD, CF(nk.X + math.sin(a) * B.w * 0.36, nk.Y - math.cos(a) * 0.35 + 0.1, nk.Z + 0.05), FOIL)
	end
	local disc = CF(0, nk.Y - 0.42, nk.Z - 0.08) * ANG(PI / 2 - 0.25, 0, 0)
	b:E(torso, "Disco", V(0.62, 0.06, 0.62), C(20, 20, 24), disc, SMOOTH)
	glow(b:E(torso, "DiscoCentro", V(0.22, 0.07, 0.22), pink, disc))
	-- caixas de som nas costas
	for _, side in ipairs({ -1, 1 }) do
		local box = CF(side * B.w * 0.36, B.h * 0.72, B.len * 0.08)
		b:K(torso, "Caixa", V(0.62, 0.95, 0.72), C(30, 30, 38), box, SMOOTH)
		for k = 0, 1 do
			local cone = box * CF(side * 0.32, 0.22 - k * 0.42, 0) * ANG(0, 0, side * PI / 2)
			b:E(torso, "Alto", V(0.5 - k * 0.15, 0.08, 0.5 - k * 0.15), C(55, 55, 65), cone, SMOOTH)
			glow(b:E(torso, "AltoLuz", V(0.58 - k * 0.15, 0.05, 0.58 - k * 0.15), k == 0 and cyan or pink, cone * CF(0, -0.02, 0)))
			b:E(torso, "AltoMiolo", V(0.18, 0.12, 0.18), C(15, 15, 20), cone * CF(0, -side * 0.0, 0), SMOOTH)
		end
	end
	-- toca-discos entre as caixas
	local tt = CF(0, B.h * 0.66, B.len * 0.1)
	b:K(torso, "Mesa", V(0.7, 0.16, 0.8), C(45, 45, 55), tt, SMOOTH)
	b:E(torso, "Vinil", V(0.62, 0.05, 0.62), C(15, 15, 18), tt * CF(0, 0.1, 0), SMOOTH)
	glow(b:E(torso, "VinilSelo", V(0.2, 0.06, 0.2), cyan, tt * CF(0, 0.11, 0)))
	b:Seg(torso, "Agulha", (tt * CF(0.28, 0.14, 0.32)).Position, (tt * CF(0.08, 0.14, 0.05)).Position, 0.03, 0.03, STEEL, METAL)
	-- faixas neon no corpo
	for _, side in ipairs({ -1, 1 }) do
		local a = bodyPoint(B, side * 1.4, -0.3, 0.01).Position
		local c = bodyPoint(B, side * 1.6, 0.35, 0.01).Position
		glow(b:Seg(torso, "Faixa", a, c, 0.05, 0.05, side < 0 and cyan or pink))
	end
	-- tênis
	for _, n in ipairs(LEGS) do
		local leg = model:FindFirstChild(n)
		if leg then
			local front = n == "LegFL" or n == "LegFR"
			local J, thick, Lt = legFrame(look, B, front)
			local foot = J(0, -Lt, -thick * 0.25)
			b:K(leg, "Sola", V(thick * 1.5, thick * 0.22, thick * 2.0), WHITE, CF(foot + V(0, thick * 0.11, -thick * 0.08)), SMOOTH)
			glow(b:K(leg, "SolaLuz", V(thick * 1.52, thick * 0.05, thick * 2.02), front and cyan or pink, CF(foot + V(0, thick * 0.2, -thick * 0.08))))
		end
	end
	local l = Instance.new("PointLight")
	l.Color = cyan
	l.Range = 9 * b.S
	l.Brightness = 1
	l.Parent = torso
end

-- Cavaleiro: elmo fechado com pluma, peitoral, manto com brasão, escudo de um lado e lança do outro
function Build.knight(b, ctx)
	local model, torso, look, B = ctx.Model, ctx.Torso, ctx.Look, ctx.Body
	local steel, blue = C(185, 190, 200), C(40, 70, 170)
	local head = model:FindFirstChild("Head1")
	local hs, ax, ay, az = headDims(look)
	if head then
		strip(model, head, set("Sobrancelha", "Palpebra"))
		b:E(head, "Elmo", V(ax * 2.18, ay * 2.1, az * 2.08), steel, CF(0, 0.05 * hs, 0.02 * hs), METAL)
		-- fenda da viseira com olhos acesos
		local gy = (look.head.eyeY or 0.08) * hs
		b:E(head, "Viseira", V(ax * 2.0, 0.12 * hs, az * 2.0), DARK, CF(0, gy, -0.06 * hs), SMOOTH)
		for _, side in ipairs({ -1, 1 }) do
			glow(b:E(head, "OlhoElmo", V(0.12, 0.06, 0.05) * hs, look.eye, CF(side * 0.2 * hs, gy, -az * 1.07)))
		end
		b:K(head, "ElmoCrista", V(0.08 * hs, ay * 0.5, az * 2.0), steel, CF(0, ay * 0.95, 0), METAL)
		b:E(head, "ElmoFaixa", V(ax * 2.24, 0.08 * hs, az * 2.14), GOLD, CF(0, gy + 0.2 * hs, 0.02 * hs), FOIL)
		for i = 0, 3 do
			b:Seg(
				head,
				"Pluma",
				V(0, ay * 0.9, 0.1 * hs + i * 0.12 * hs),
				V(0, ay * (1.7 - i * 0.12), az * (1.3 + i * 0.25)),
				0.12 * hs,
				0.08 * hs,
				i % 2 == 0 and C(210, 30, 40) or C(240, 240, 240),
				FABRIC
			)
		end
	end
	-- peitoral e manto
	b:E(torso, "Peitoral", V(B.w * 1.02, B.h * 1.0, B.len * 0.42), steel, CF(0, B.h * 0.04, -B.len * 0.25), METAL)
	b:E(torso, "Manto", V(B.w * 1.1, B.h * 0.9, B.len * 0.66), blue, CF(0, B.h * 0.08, B.len * 0.14), FABRIC)
	b:E(torso, "MantoBorda", V(B.w * 1.12, 0.12, B.len * 0.68), GOLD, CF(0, -B.h * 0.32, B.len * 0.14), FOIL)
	for _, side in ipairs({ -1, 1 }) do
		b:E(torso, "Ombreira", V(B.w * 0.4, B.h * 0.5, B.len * 0.3), steel, CF(side * B.w * 0.46, B.h * 0.28, -B.len * 0.28) * ANG(0, 0, side * 0.4), METAL)
	end
	-- escudo (lado esquerdo, +X)
	local sh = CF(B.w * 0.64, -B.h * 0.02, -B.len * 0.04)
	b:E(torso, "EscudoBorda", V(0.14, 1.65, 1.35), GOLD, sh, FOIL)
	b:E(torso, "Escudo", V(0.2, 1.5, 1.2), blue, sh * CF(0.03, 0, 0), SMOOTH)
	b:E(torso, "EscudoCruz", V(0.24, 1.25, 0.2), GOLD, sh * CF(0.04, 0, 0), FOIL)
	b:E(torso, "EscudoCruz", V(0.24, 0.2, 0.9), GOLD, sh * CF(0.04, 0.2, 0), FOIL)
	b:E(torso, "EscudoBossa", V(0.2, 0.3, 0.3), STEEL, sh * CF(0.1, 0.2, 0), METAL)
	-- lança (lado direito, -X), apontando para a frente
	local lz = CF(-B.w * 0.62, B.h * 0.12, 0)
	b:Seg(torso, "Lanca", (lz * CF(0, 0, 1.0)).Position, (lz * CF(0, 0.15, -1.2)).Position, 0.1, 0.1, WOOD)
	b:E(torso, "LancaGuarda", V(0.6, 0.6, 0.5), steel, lz * CF(0, 0.15, -1.35), METAL)
	b:Chain(
		torso,
		"LancaPonta",
		{ (lz * CF(0, 0.15, -1.5)).Position, (lz * CF(0, 0.2, -2.6)).Position, (lz * CF(0, 0.22, -3.6)).Position },
		{ 0.2, 0.1 },
		steel,
		METAL
	)
	b:Seg(torso, "Flamula", (lz * CF(0, 0.3, -1.55)).Position, (lz * CF(0, 0.75, -1.25)).Position, 0.04, 0.2, C(210, 30, 40), FABRIC)
end

-- Tatu: casco em faixas por cima do corpo todo, escudo na cabeça e cauda blindada
function Build.armadillo(b, ctx)
	local model, torso, look, B = ctx.Model, ctx.Torso, ctx.Look, ctx.Body
	local band, band2 = C(150, 120, 100), C(120, 95, 80)
	for i = 0, 6 do
		local f = i / 6
		local z = -B.len * 0.42 + f * B.len * 0.84
		local k = math.sqrt(math.max(0.25, 1 - (2 * f - 1) ^ 2))
		b:E(
			torso,
			"Casco",
			V(B.w * 1.16 * (0.75 + 0.25 * k), B.h * 1.12 * (0.7 + 0.3 * k), B.len * 0.2),
			i % 2 == 0 and band or band2,
			CF(0, B.h * 0.14, z),
			SMOOTH
		)
		-- fileira de "escamas" no topo de cada faixa
		for s = -2, 2 do
			local a = s * 0.45
			local r = B.h * 0.56 * (0.7 + 0.3 * k)
			b:E(
				torso,
				"Escama",
				V(0.18, 0.1, 0.14),
				C(175, 145, 120),
				CF(math.sin(a) * B.w * 0.58 * (0.75 + 0.25 * k), B.h * 0.14 + math.cos(a) * r, z) * ANG(0, 0, -a),
				SMOOTH
			)
		end
	end
	local head = model:FindFirstChild("Head1")
	if head then
		local hs, ax, ay = headDims(look)
		b:E(head, "EscudoCabeca", V(ax * 1.5, 0.3 * hs, 0.9 * hs), band, CF(0, ay * 0.72, -0.05 * hs) * ANG(-0.15, 0, 0), SMOOTH)
	end
	local tailBase = model:FindFirstChild("TailBase")
	if tailBase then
		strip(model, tailBase)
		local pts = { V(0, 0, 0), V(0, -0.1, 0.4), V(0, -0.25, 0.8), V(0, -0.45, 1.15) }
		b:Chain(tailBase, "Rabo", pts, { 0.22, 0.17, 0.11 }, band)
		for i = 1, 3 do
			local p = pts[i]:Lerp(pts[i + 1], 0.5)
			b:E(tailBase, "RaboAnel", V(0.5 - i * 0.1, 0.5 - i * 0.1, 0.12), band2, CFrame.lookAt(p, pts[i + 1]), SMOOTH)
		end
	end
end

-- Dente-de-sabre: listras, presas enormes que passam do queixo, bochechas peludas e orelhas redondas
function Build.saber(b, ctx)
	local model, torso, look, B = ctx.Model, ctx.Torso, ctx.Look, ctx.Body
	local stripe = look.second
	for _, side in ipairs({ -1, 1 }) do
		for i = 0, 4 do
			local fz = -0.32 + i * 0.16
			local a = bodyPoint(B, side * 0.35, fz, 0.02).Position
			local c = bodyPoint(B, side * (1.3 + (i % 2) * 0.2), fz + 0.05, 0.02).Position
			b:Seg(torso, "Listra", a, c, 0.08, 0.08, stripe, SMOOTH)
		end
	end
	local head = model:FindFirstChild("Head1")
	if head then
		local hs, ax, ay, az = headDims(look)
		local H = look.head
		-- presas de sabre (na cabeça: ficam paradas quando a boca abre)
		local mw = 0.5 * (H.snoutW or 1) * hs
		local sn = H.snout or 0.8
		local mLen = (0.3 + sn * 0.55) * hs
		local mz = -az * 0.55 - mLen * 0.5 + 0.1 * hs
		for _, side in ipairs({ -1, 1 }) do
			local top = V(side * mw * 0.28, -0.2 * hs, mz - mLen * 0.2)
			b:Chain(head, "Sabre", {
				top,
				top + V(side * 0.03 * hs, -0.35 * hs, -0.06 * hs),
				top + V(0, -0.72 * hs, 0.02 * hs),
				top + V(-side * 0.02 * hs, -0.92 * hs, 0.14 * hs),
			}, { 0.075 * hs, 0.06 * hs, 0.035 * hs }, BONE, SMOOTH)
		end
		-- listras na testa
		for i = -1, 1 do
			b:Seg(head, "ListraTesta", V(i * 0.15 * hs, ay * 0.95, -az * 0.2), V(i * 0.22 * hs, ay * 0.5, -az * 0.75), 0.04 * hs, 0.04 * hs, stripe, SMOOTH)
		end
		-- orelhas redondas
		for _, side in ipairs({ -1, 1 }) do
			local e = CF(side * ax * 0.62, ay * 0.82, 0.05 * hs) * ANG(0, 0, -side * 0.35)
			b:E(head, "Orelha", V(0.34, 0.34, 0.12) * hs, look.main, e)
			b:E(head, "OrelhaDentro", V(0.2, 0.2, 0.08) * hs, look.belly, e * CF(0, -0.02 * hs, -0.04 * hs))
		end
		-- suíças peludas
		for _, side in ipairs({ -1, 1 }) do
			b:Seg(head, "Suica", V(side * ax * 0.8, -0.12 * hs, -0.05 * hs), V(side * ax * 1.12, -0.35 * hs, 0.12 * hs), 0.12 * hs, 0.08 * hs, look.belly)
		end
	end
	-- anéis escuros na cauda
	local tailBase = model:FindFirstChild("TailBase")
	if tailBase then
		local t = math.clamp(B.h / 1.4, 0.8, 1.4)
		local pts = { V(0, 0, 0), V(0, 0.3, 0.32), V(0, 0.7, 0.5), V(0, 1.02, 0.48) }
		for i = 1, 3 do
			local p = pts[i]:Lerp(pts[i + 1], 0.55) * t
			b:E(tailBase, "RaboAnel", V(0.24, 0.24, 0.1) * t, stripe, CFrame.lookAt(p, pts[i + 1] * t), SMOOTH)
		end
	end
end

-- Astronauta: capacete-bolha de vidro, mochila a jato com chamas, painel no peito e botas
function Build.astronaut(b, ctx)
	local model, torso, look, B = ctx.Model, ctx.Torso, ctx.Look, ctx.Body
	local orange, gray = look.second, C(120, 124, 135)
	local head = model:FindFirstChild("Head1")
	if head then
		local hs, ax, ay, az = headDims(look)
		local bubble = b:E(head, "Capacete", V(ax * 2.9, ay * 2.9, az * 2.9), C(200, 230, 255), CF(0, 0.08 * hs, -0.12 * hs), GLASS)
		bubble.Transparency = 0.72
		bubble.CastShadow = false
		b:E(head, "CapaceteBrilho", V(0.3, 0.12, 0.05) * hs, WHITE, CF(-ax * 0.7, ay * 0.95, -az * 1.15) * ANG(0.4, 0, 0.6), NEON).Transparency = 0.3
		b:Seg(head, "Antena", V(ax * 0.7, ay * 1.2, 0.2 * hs), V(ax * 0.95, ay * 2.1, 0.35 * hs), 0.03 * hs, 0.03 * hs, gray, METAL)
		glow(b:E(head, "AntenaLuz", V(0.14, 0.14, 0.14) * hs, C(255, 60, 60), CF(ax * 0.95, ay * 2.15, 0.35 * hs)))
	end
	-- anel do capacete no pescoço
	local count = 1
	local H = look.head
	local top = V(0, B.h * 0.3 + (H.lift or 0), -B.len * 0.45 - (H.forward or 0))
	local base = V(0, B.h * 0.08, -B.len * 0.3)
	local c = base:Lerp(top, 0.6)
	local r = 0.3 * H.size * (H.neckW or 1)
	b:E(torso, "AnelCapacete", V(r * 2.7, r * 2.7, 0.28), gray, CFrame.lookAt(c, top), METAL)
	b:E(torso, "AnelLaranja", V(r * 2.75, r * 2.75, 0.1), orange, CFrame.lookAt(c, top) * CF(0, 0, 0.1), SMOOTH)
	local _ = count
	-- mochila a jato
	local pack = CF(0, B.h * 0.55, B.len * 0.1)
	b:K(torso, "Mochila", V(B.w * 0.8, 0.9, B.len * 0.42), C(225, 228, 235), pack, SMOOTH)
	b:K(torso, "MochilaFaixa", V(B.w * 0.82, 0.14, B.len * 0.44), orange, pack * CF(0, 0.2, 0), SMOOTH)
	for _, side in ipairs({ -1, 1 }) do
		local tank = pack * CF(side * B.w * 0.3, 0.1, B.len * 0.12)
		b:E(torso, "Tanque", V(0.45, 1.3, 0.45), gray, tank, METAL)
		b:E(torso, "Bocal", V(0.35, 0.3, 0.35), C(60, 60, 70), tank * CF(0, -0.68, 0), METAL)
		local flame = glow(b:E(torso, "Chama", V(0.28, 0.55, 0.28), C(255, 170, 60), tank * CF(0, -1.0, 0)))
		local fire = Instance.new("Fire")
		fire.Color = C(255, 150, 50)
		fire.SecondaryColor = C(255, 240, 150)
		fire.Size = 1.2 * b.S
		fire.Heat = -4
		fire.Parent = flame
	end
	-- painel no peito
	local panel = CF(0, -B.h * 0.05, -B.len * 0.47) * ANG(-0.35, 0, 0)
	b:K(torso, "Painel", V(0.7, 0.45, 0.12), C(210, 214, 222), panel, SMOOTH)
	local cols = { C(255, 60, 60), C(60, 220, 90), C(60, 160, 255) }
	for i = 1, 3 do
		glow(b:E(torso, "Botao", V(0.12, 0.12, 0.06), cols[i], panel * CF((i - 2) * 0.2, 0.06, -0.07)))
	end
	-- bandeirinha no ombro (azul com estrela)
	b:K(torso, "Bandeira", V(0.08, 0.32, 0.45), C(40, 80, 200), CF(B.w * 0.5, B.h * 0.22, -B.len * 0.25), SMOOTH)
	b:E(torso, "BandeiraEstrela", V(0.06, 0.14, 0.14), WHITE, CF(B.w * 0.53, B.h * 0.22, -B.len * 0.25), NEON)
	-- listras laranja nas pernas e botas
	for _, n in ipairs(LEGS) do
		local leg = model:FindFirstChild(n)
		if leg then
			local front = n == "LegFL" or n == "LegFR"
			local J, thick, Lt = legFrame(look, B, front)
			b:E(leg, "Faixa", V(thick * 1.3, 0.12, thick * 1.35), orange, CF(J(0, -Lt * 0.38, front and 0 or thick * 0.4)), SMOOTH)
			b:E(leg, "Bota", V(thick * 1.25, thick * 0.9, thick * 1.35), C(110, 112, 122), CF(J(0, -Lt + thick * 0.75, -thick * 0.05)), SMOOTH)
		end
	end
end

-- Yeti: enorme, peludo, meio de pé (braços longos), chifrinhos de gelo e cristais nos ombros
function Build.yeti(b, ctx)
	local model, torso, look, B = ctx.Model, ctx.Torso, ctx.Look, ctx.Body
	local fur, ice = look.main, C(170, 225, 255)
	-- tufos de pelo caindo pelos lados e costas
	for _, side in ipairs({ -1, 1 }) do
		for i = 0, 4 do
			local fz = -0.36 + i * 0.18
			local cf = bodyPoint(B, side * (1.2 + (i % 2) * 0.25), fz, 0.0)
			b:Seg(torso, "Tufo", cf.Position, cf.Position + V(side * 0.3, -0.75, 0.15), 0.28, 0.2, i % 2 == 0 and fur or look.belly)
		end
	end
	for i = 0, 3 do
		local cf = bodyPoint(B, (i % 2 == 0 and 0.3 or -0.3), -0.3 + i * 0.2, 0.0)
		b:Tri(torso, "TufoCostas", cf * ANG(-PI / 2, 0, 0) * ANG(-0.5, 0, 0), 0.6, 0.6, 0.15, fur)
	end
	-- cristais de gelo nos ombros
	for _, side in ipairs({ -1, 1 }) do
		for k = 0, 2 do
			local base = CF(side * B.w * (0.35 + k * 0.08), B.h * 0.48 - k * 0.05, -B.len * (0.32 - k * 0.1)) * ANG(-0.3, 0, -side * (0.4 + k * 0.2))
			local cr = b:Tri(torso, "Cristal", base, 0.3, 0.7 - k * 0.12, 0.2, ice, GLASS)
			cr.Transparency = 0.15
		end
	end
	-- braços: pelagem grossa e antebraço enorme
	for _, n in ipairs({ "LegFL", "LegFR" }) do
		local leg = model:FindFirstChild(n)
		if leg then
			local J, thick, Lt = legFrame(look, B, true)
			b:E(leg, "Antebraco", V(thick * 1.55, Lt * 0.4, thick * 1.6), fur, CF(J(0, -Lt * 0.58, 0)))
			b:Seg(leg, "PeloBraco", J(0, -Lt * 0.2, thick * 0.5), J(0, -Lt * 0.75, thick * 0.9), thick * 0.5, thick * 0.6, look.belly)
		end
	end
	local head = model:FindFirstChild("Head1")
	if head then
		local hs, ax, ay, az = headDims(look)
		for _, side in ipairs({ -1, 1 }) do
			b:Chain(head, "Chifre", {
				V(side * ax * 0.55, ay * 0.6, 0.05 * hs),
				V(side * ax * 0.95, ay * 1.15, 0.1 * hs),
				V(side * ax * 0.85, ay * 1.6, -0.05 * hs),
			}, { 0.12 * hs, 0.07 * hs }, ice, GLASS)
		end
		-- franja de pelo sobre a testa
		for i = -2, 2 do
			b:Seg(head, "Franja", V(i * 0.12 * hs, ay * 0.95, -az * 0.3), V(i * 0.16 * hs, ay * 0.45, -az * 0.95), 0.1 * hs, 0.07 * hs, fur)
		end
		for _, side in ipairs({ -1, 1 }) do
			b:Seg(head, "Bochecha", V(side * ax * 0.85, 0, -0.1 * hs), V(side * ax * 1.15, -ay * 0.6, 0.1 * hs), 0.16 * hs, 0.12 * hs, fur)
		end
	end
	tilt(ctx, 0.3)
end

-- Lobisomem: corcunda meio de pé, juba espetada, garras enormes e calça rasgada
function Build.werewolf(b, ctx)
	local model, torso, look, B = ctx.Model, ctx.Torso, ctx.Look, ctx.Body
	local pants = C(80, 50, 120)
	-- calça rasgada no quadril
	b:E(torso, "Calca", V(B.w * 1.02, B.h * 0.95, B.len * 0.46), pants, CF(0, B.h * 0.0, B.len * 0.26), FABRIC)
	for i = -3, 3 do
		local x = i * B.w * 0.14
		b:W(torso, "Rasgo", V(0.08, 0.35, 0.25), pants, CF(x, -B.h * 0.48, B.len * 0.12 + math.abs(i) * 0.05) * ANG(0, PI / 2, PI), FABRIC)
	end
	for _, n in ipairs({ "LegBL", "LegBR" }) do
		local leg = model:FindFirstChild(n)
		if leg then
			local J, thick, Lt = legFrame(look, B, false)
			b:E(leg, "Calca", V(thick * 1.75, Lt * 0.45, thick * 2.1), pants, CF(J(0, -Lt * 0.2, thick * 0.2)), FABRIC)
			for k = -1, 1 do
				b:W(leg, "Rasgo", V(0.06, 0.3, 0.2), pants, CF(J(k * thick * 0.5, -Lt * 0.47, thick * 0.25)) * ANG(0, PI / 2 + k * 0.4, PI), FABRIC)
			end
		end
	end
	-- garras enormes nas patas da frente
	for _, n in ipairs({ "LegFL", "LegFR" }) do
		local leg = model:FindFirstChild(n)
		if leg then
			local J, thick, Lt = legFrame(look, B, true)
			for k = -1, 1 do
				local a = J(k * thick * 0.38, -Lt + thick * 0.3, -thick * 0.7)
				b:Chain(
					leg,
					"Garra",
					{ a, a + V(k * 0.03, 0.02, -thick * 0.45), a + V(k * 0.05, -thick * 0.22, -thick * 0.75) },
					{ thick * 0.09, thick * 0.05 },
					BONE,
					SMOOTH
				)
			end
			b:Seg(leg, "PeloCotovelo", J(0, -Lt * 0.3, thick * 0.4), J(0, -Lt * 0.45, thick * 1.1), thick * 0.35, thick * 0.25, look.second)
		end
	end
	-- tufos nas bochechas
	local head = model:FindFirstChild("Head1")
	if head then
		local hs, ax = headDims(look)
		for _, side in ipairs({ -1, 1 }) do
			for k = 0, 1 do
				b:Tri(
					head,
					"Suica",
					CF(side * ax * 0.85, -0.12 * hs - k * 0.15 * hs, 0.05 * hs) * ANG(0, 0, -side * (PI / 2 + 0.3 + k * 0.3)),
					0.3 * hs,
					0.45 * hs,
					0.08 * hs,
					look.main
				)
			end
		end
	end
	tilt(ctx, 0.42)
end

-- Polvo: manto gigante atrás da cabeça, patas viram tentáculos com ventosas, tentáculos extras
function Build.octopus(b, ctx)
	local model, torso, look, B = ctx.Model, ctx.Torso, ctx.Look, ctx.Body
	local main, pink = look.main, look.belly
	local head = model:FindFirstChild("Head1")
	if head then
		local hs, ax, ay, az = headDims(look)
		local mantle = CF(0, ay * 1.15, az * 0.9) * ANG(0.55, 0, 0)
		b:E(head, "Manto", V(ax * 2.2, ay * 2.0, az * 2.9), main, mantle * CF(0, 0, 0.3 * hs))
		local rng = Random.new(4)
		for _ = 1, 7 do
			local a = rng:NextNumber(-1.2, 1.2)
			local y = rng:NextNumber(-0.2, 0.7)
			local z = rng:NextNumber(-0.3, 0.9)
			b:E(
				head,
				"Pinta",
				V(0.2, 0.2, 0.08) * hs * rng:NextNumber(0.7, 1.3),
				look.second,
				mantle * CF(math.sin(a) * ax * 1.05, y * ay + math.cos(a) * ay * 0.35, z * az) * ANG(0, a, 0),
				SMOOTH
			)
		end
	end
	-- patas viram tentáculos (continuam balançando no Motor6D da perna)
	for _, n in ipairs(LEGS) do
		local leg = model:FindFirstChild(n)
		if leg then
			local front = n == "LegFL" or n == "LegFR"
			strip(model, leg, set("Canela", "Pata", "Dedo", "Garra", "Meia"))
			leg.Transparency = 1
			local J, thick, Lt = legFrame(look, B, front)
			local sx = (n == "LegFL" or n == "LegBL") and -1 or 1
			local sz = front and -1 or 1
			local pts = {
				J(0, 0.1, 0),
				J(sx * 0.08, -Lt * 0.4, sz * 0.05),
				J(sx * 0.25, -Lt * 0.78, sz * 0.12),
				J(sx * 0.6, -Lt + thick * 0.28, sz * 0.25),
				J(sx * 1.05, -Lt + thick * 0.22, sz * 0.4),
				J(sx * 1.3, -Lt + thick * 0.55, sz * 0.38),
			}
			local radii = { thick * 0.62, thick * 0.55, thick * 0.45, thick * 0.34, thick * 0.22 }
			b:Chain(leg, "Tentaculo", pts, radii, main)
			for k = 3, 5 do
				local p = pts[k]:Lerp(pts[k + 1], 0.5)
				b:E(leg, "Ventosa", V(radii[k] * 0.9, radii[k] * 0.35, radii[k] * 0.9), pink, CF(p.X, p.Y - radii[k] * 0.75, p.Z), SMOOTH)
			end
		end
	end
	-- tentáculos extras saindo das costas, curvados para cima
	for _, side in ipairs({ -1, 1 }) do
		for k = 0, 1 do
			local z = -B.len * 0.05 + k * B.len * 0.3
			local s = V(side * B.w * 0.4, B.h * 0.2, z)
			local pts = {
				s,
				s + V(side * 0.6, 0.2, 0.1),
				s + V(side * 1.0, 0.75, 0.25),
				s + V(side * 0.95, 1.35, 0.15),
				s + V(side * 0.6, 1.55, -0.05),
			}
			b:Chain(torso, "TentaculoExtra", pts, { 0.26, 0.22, 0.16, 0.1 }, main, nil, look.second)
			for j = 2, 3 do
				local p = pts[j]:Lerp(pts[j + 1], 0.5)
				b:E(torso, "Ventosa", V(0.14, 0.14, 0.08), pink, CF(p.X - side * 0.12, p.Y, p.Z), SMOOTH)
			end
		end
	end
	-- cauda: dois tentáculos
	local tailBase = model:FindFirstChild("TailBase")
	if tailBase then
		strip(model, tailBase)
		for _, side in ipairs({ -1, 1 }) do
			b:Chain(
				tailBase,
				"Tentaculo",
				{ V(0, 0, 0), V(side * 0.3, -0.1, 0.5), V(side * 0.55, 0.1, 1.0), V(side * 0.4, 0.5, 1.25) },
				{ 0.22, 0.16, 0.1 },
				main,
				nil,
				look.second
			)
		end
	end
end

-- Tanque: esteiras no lugar das patas, torre com canhão longo nas costas, capacete e escapamento
function Build.tank(b, ctx)
	local model, torso, look, B = ctx.Model, ctx.Torso, ctx.Look, ctx.Body
	local olive, dark = look.main, look.second
	local track = C(45, 45, 48)
	-- some com as patas (os Motor6D continuam, sem peças)
	for _, n in ipairs(LEGS) do
		local leg = model:FindFirstChild(n)
		if leg then
			strip(model, leg)
			leg.Transparency = 1
		end
	end
	local gy = groundY(look, B)
	local th = 0.95 -- altura da esteira
	local tl = B.len * 1.05
	for _, side in ipairs({ -1, 1 }) do
		local x = side * (B.w * 0.5 + 0.22)
		local cy = gy + th / 2
		b:K(torso, "Esteira", V(0.55, th * 0.72, tl * 0.82), track, CF(x, cy, 0), SMOOTH)
		for _, e in ipairs({ -1, 1 }) do
			b:E(torso, "EsteiraPonta", V(0.55, th, th), track, CF(x, cy, e * tl * 0.41), SMOOTH)
		end
		-- rodas
		for k = 0, 4 do
			local z = -tl * 0.4 + k * tl * 0.2
			b:E(torso, "Roda", V(0.6, th * 0.62, th * 0.62), C(90, 95, 80), CF(x + side * 0.03, cy, z), METAL)
			b:E(torso, "RodaMiolo", V(0.64, th * 0.22, th * 0.22), C(160, 160, 150), CF(x + side * 0.03, cy, z), METAL)
		end
		-- sapatas
		for k = 0, 9 do
			local z = -tl * 0.45 + k * tl * 0.1
			b:K(torso, "Sapata", V(0.6, 0.1, tl * 0.06), C(30, 30, 32), CF(x, gy + 0.05, z), SMOOTH)
		end
		-- para-lama
		b:K(torso, "ParaLama", V(0.75, 0.12, tl * 1.02), dark, CF(x, gy + th + 0.06, 0), METAL)
		b:E(torso, "Estrela", V(0.06, 0.4, 0.4), WHITE, CF(side * (B.w * 0.5 + 0.05), B.h * 0.05, B.len * 0.1), SMOOTH)
	end
	-- placas laterais ligando corpo e esteiras
	b:K(torso, "Casco", V(B.w * 1.15, 0.4, B.len * 0.95), dark, CF(0, -B.h * 0.38, 0), METAL)
	-- torre com canhão
	local tur = CF(0, B.h * 0.72, B.len * 0.14)
	b:E(torso, "Torre", V(B.w * 0.85, 0.7, B.len * 0.45), olive, tur, METAL)
	b:K(torso, "Escotilha", V(0.5, 0.12, 0.5), dark, tur * CF(0.2, 0.36, 0.15), METAL)
	local barrel0 = tur * CF(0, 0.2, -B.len * 0.18) * ANG(0.2, 0, 0)
	b:E(torso, "Mantelete", V(0.6, 0.5, 0.4), olive, barrel0 * CF(0, 0, 0.05), METAL)
	b:Seg(torso, "Canhao", barrel0.Position, (barrel0 * CF(0, 0, -B.len * 0.95)).Position, 0.15, 0.15, dark, METAL)
	b:Seg(torso, "CanhaoBoca", (barrel0 * CF(0, 0, -B.len * 0.88)).Position, (barrel0 * CF(0, 0, -B.len * 1.04)).Position, 0.24, 0.24, C(40, 42, 40), METAL)
	-- escapamento
	for _, side in ipairs({ -1, 1 }) do
		b:Seg(
			torso,
			"Escapamento",
			V(side * B.w * 0.3, B.h * 0.3, B.len * 0.42),
			V(side * B.w * 0.32, B.h * 0.75, B.len * 0.48),
			0.1,
			0.1,
			C(60, 60, 60),
			METAL
		)
	end
	local head = model:FindFirstChild("Head1")
	if head then
		local hs, ax, ay, az = headDims(look)
		b:E(head, "Capacete", V(ax * 2.15, ay * 1.4, az * 2.1), C(80, 60, 40), CF(0, ay * 0.5, 0.05 * hs), FABRIC)
		for _, side in ipairs({ -1, 1 }) do
			b:E(head, "CapaceteAba", V(0.12, 0.5, 0.4) * hs, C(80, 60, 40), CF(side * ax * 1.02, 0.05 * hs, 0.1 * hs), FABRIC)
		end
	end
end

-- Feiticeiro: chapéu pontudo torto, barba longa, túnica com estrelas, cajado com orbe e orbes flutuando
function Build.wizard(b, ctx)
	local model, torso, look, B = ctx.Model, ctx.Torso, ctx.Look, ctx.Body
	local robe, star = look.second, C(255, 220, 90)
	local head = model:FindFirstChild("Head1")
	if head then
		local hs, ax, ay, az = headDims(look)
		local brim = CF(0, ay * 0.72, 0.05 * hs)
		b:E(head, "Chapeu", V(ax * 3.0, 0.14 * hs, az * 3.0), robe, brim, FABRIC)
		local pts = {
			V(0, ay * 0.75, 0.05 * hs),
			V(0, ay * 1.6, 0.15 * hs),
			V(0, ay * 2.35, 0.35 * hs),
			V(0.1 * hs, ay * 2.85, 0.7 * hs),
			V(0.15 * hs, ay * 2.9, 1.0 * hs),
		}
		b:Chain(head, "ChapeuCone", pts, { 0.62 * hs, 0.44 * hs, 0.26 * hs, 0.1 * hs }, robe, FABRIC)
		b:E(head, "ChapeuFaixa", V(ax * 2.1, 0.12 * hs, az * 2.1), star, brim * CF(0, 0.1 * hs, 0), FOIL)
		for i = 1, 3 do
			local p = pts[i]:Lerp(pts[i + 1], 0.5)
			glow(b:E(head, "Estrela", V(0.14, 0.14, 0.05) * hs, star, CF(p.X + 0.3 * hs * (1 - i * 0.25), p.Y, p.Z - 0.2 * hs) * ANG(0, 0.6, PI / 4)))
		end
		-- barba longa embaixo do focinho
		local H = look.head
		local sn = H.snout or 0.8
		local mLen = (0.3 + sn * 0.55) * hs
		local mz = -az * 0.55 - mLen * 0.5 + 0.1 * hs
		b:Chain(head, "Barba", {
			V(0, -0.3 * hs, mz + 0.1 * hs),
			V(0, -0.7 * hs, mz + 0.05 * hs),
			V(0, -1.1 * hs, mz + 0.15 * hs),
			V(0, -1.35 * hs, mz + 0.35 * hs),
		}, { 0.3 * hs, 0.24 * hs, 0.12 * hs }, WHITE)
		for _, side in ipairs({ -1, 1 }) do
			b:Seg(
				head,
				"Bigode",
				V(side * 0.1 * hs, -0.12 * hs, mz - mLen * 0.3),
				V(side * 0.45 * hs, -0.35 * hs, mz - mLen * 0.1),
				0.06 * hs,
				0.05 * hs,
				WHITE
			)
		end
	end
	-- túnica cobrindo o corpo, com estrelas e luas
	b:E(torso, "Tunica", V(B.w * 1.12, B.h * 1.08, B.len * 0.98), robe, CF(0, B.h * 0.04, 0), FABRIC)
	b:E(torso, "TunicaBarra", V(B.w * 1.16, B.h * 0.3, B.len * 1.0), star, CF(0, -B.h * 0.38, 0), FOIL)
	local rng = Random.new(8)
	for _ = 1, 9 do
		local cf = bodyPoint(B, rng:NextNumber(-1.6, 1.6), rng:NextNumber(-0.4, 0.4), 0.08)
		glow(b:E(torso, "Estrela", V(0.18, 0.18, 0.06), star, cf * ANG(0, 0, PI / 4)))
	end
	-- capuz/gola alta atrás do pescoço
	b:E(torso, "Gola", V(B.w * 0.95, B.h * 0.75, 0.4), robe, CF(0, B.h * 0.42, -B.len * 0.3) * ANG(0.35, 0, 0), FABRIC)
	-- cajado (lado direito) com orbe
	local sx, sz = -B.w * 0.65, -B.len * 0.2
	local gy = groundY(look, B)
	b:Seg(torso, "Cajado", V(sx, gy + 0.05, sz), V(sx, B.h * 1.7, sz - 0.1), 0.09, 0.09, WOOD)
	b:Chain(torso, "CajadoGarra", { V(sx, B.h * 1.7, sz - 0.1), V(sx - 0.25, B.h * 1.95, sz - 0.1), V(sx - 0.1, B.h * 2.25, sz - 0.1) }, { 0.07, 0.05 }, WOOD)
	local orb = glow(b:E(torso, "Orbe", V(0.5, 0.5, 0.5), look.eye, CF(sx + 0.05, B.h * 2.0, sz - 0.1)))
	local l = Instance.new("PointLight")
	l.Color = look.eye
	l.Range = 10 * b.S
	l.Brightness = 1.5
	l.Parent = orb
	-- orbezinhos flutuando em volta
	for k = 0, 2 do
		local a = k / 3 * PI * 2 + 0.4
		glow(
			b:E(
				torso,
				"OrbeMenor",
				V(0.24, 0.24, 0.24),
				k == 1 and C(255, 120, 230) or look.eye,
				CF(math.cos(a) * B.w * 0.9, B.h * 0.95, math.sin(a) * B.len * 0.45)
			)
		)
	end
end

---------------------------------------------------------------- espécies
local Species = {
	------------------------------------------------------------ ÉPICOS
	pirate_dog = {
		Name = "Pirate Dog",
		Rarity = "Epic",
		Role = "Raider",
		Special = "B_AnchorHook",
		Stats = { HP = 1.15, Atk = 1.25, Speed = 17 },
		Look = {
			scale = 1.15,
			main = C(150, 98, 58),
			second = C(105, 66, 38),
			belly = C(240, 215, 175),
			eye = C(40, 28, 20),
			body = { len = 2.9, w = 1.45, h = 1.35, chest = 1.1 },
			legs = { len = 1.0, thick = 0.38, socks = C(240, 215, 175), sockH = 0.18 },
			head = { size = 1.45, snout = 0.85, lift = 0.45, muzzle = C(240, 215, 175), jowls = true },
			mood = "fierce",
			eyes = "white",
			ears = "floppy",
			earColor = C(95, 60, 35),
			tail = "thin",
			build = Build.pirate,
		},
	},
	scorpion_dog = {
		Name = "Scorpion Dog",
		Rarity = "Epic",
		Role = "Poison",
		Special = "B_Stinger",
		Stats = { HP = 1.15, Atk = 1.25, Speed = 17 },
		Look = {
			scale = 1.15,
			main = C(52, 40, 60),
			second = C(255, 170, 40),
			belly = C(90, 72, 95),
			eye = C(255, 180, 40),
			body = { len = 3.0, w = 1.8, h = 1.15, chest = 1.05, haunch = 0.95 },
			legs = { len = 0.7, thick = 0.34, claws = C(255, 170, 40), noToes = false },
			head = { size = 1.3, snout = 0.6, snoutW = 1.1, lift = 0.15, forward = 0.2, muzzle = C(70, 55, 78) },
			mood = "evil",
			eyes = "glow",
			ears = "none",
			tail = "stub",
			extras = { eyes3 = true, eyeGlow = true, noBelly = true },
			build = Build.scorpion,
		},
	},
	flytrap_dog = {
		Name = "Flytrap Dog",
		Rarity = "Epic",
		Role = "Ambush",
		Special = "B_VineSnare",
		Stats = { HP = 1.2, Atk = 1.2, Speed = 16 },
		Look = {
			scale = 1.15,
			main = C(85, 165, 60),
			second = C(205, 40, 65),
			belly = C(160, 215, 95),
			eye = C(255, 230, 60),
			body = { len = 2.8, w = 1.4, h = 1.3 },
			legs = { len = 1.0, thick = 0.36, paw = C(110, 75, 45) },
			head = { size = 1.55, snout = 0.6, lift = 0.6, neckW = 0.6 },
			neckColor = C(70, 140, 50),
			mood = "evil",
			ears = "none",
			tail = "stub",
			build = Build.flytrap,
		},
	},
	dj_dog = {
		Name = "DJ Dog",
		Rarity = "Epic",
		Role = "Rhythm",
		Special = "B_BassDrop",
		Stats = { HP = 1.05, Atk = 1.3, Speed = 19 },
		Look = {
			scale = 1.0,
			main = C(58, 52, 80),
			second = C(0, 240, 220),
			belly = C(120, 112, 150),
			eye = C(255, 255, 255),
			body = { len = 2.7, w = 1.3, h = 1.25 },
			legs = { len = 1.05, thick = 0.34, paw = C(255, 60, 200) },
			head = { size = 1.45, snout = 0.8, lift = 0.5, muzzle = C(120, 112, 150) },
			mood = "happy",
			eyes = "cute",
			ears = "floppy",
			earColor = C(40, 36, 58),
			tail = "thin",
			tailTip = C(0, 240, 220),
			build = Build.dj,
		},
	},
	knight_dog = {
		Name = "Knight Dog",
		Rarity = "Epic",
		Role = "Defender",
		Special = "B_ShieldLance",
		Stats = { HP = 1.4, Atk = 1.1, Speed = 15 },
		Look = {
			scale = 1.25,
			main = C(160, 112, 72),
			second = C(120, 80, 50),
			belly = C(225, 200, 160),
			eye = C(120, 220, 255),
			body = { len = 3.0, w = 1.55, h = 1.45, chest = 1.1 },
			legs = { len = 1.05, thick = 0.44, lower = C(175, 180, 192), paw = C(150, 155, 168) },
			head = { size = 1.45, snout = 0.85, lift = 0.5 },
			mood = "fierce",
			eyes = "white",
			ears = "none",
			tail = "thin",
			build = Build.knight,
		},
	},
	armadillo_dog = {
		Name = "Armadillo Dog",
		Rarity = "Epic",
		Role = "Roller",
		Special = "B_RollingBall",
		Stats = { HP = 1.5, Atk = 1.0, Speed = 16 },
		Look = {
			scale = 0.95,
			main = C(205, 170, 140),
			second = C(150, 120, 100),
			belly = C(240, 215, 190),
			eye = C(30, 22, 20),
			body = { len = 2.6, w = 1.5, h = 1.3, chest = 0.95 },
			legs = { len = 0.6, thick = 0.34, claws = C(70, 60, 55) },
			head = {
				size = 1.15,
				snout = 1.25,
				snoutW = 0.6,
				lift = 0.15,
				forward = 0.2,
				long = 1.15,
				nose = C(200, 120, 120),
			},
			mood = "calm",
			eyes = "bead",
			ears = "big",
			earSize = 0.72,
			earColor = C(200, 160, 135),
			tail = "stub",
			build = Build.armadillo,
		},
	},
	saber_dog = {
		Name = "Sabertooth Dog",
		Rarity = "Epic",
		Role = "Predator",
		Special = "B_SaberMaul",
		Stats = { HP = 1.1, Atk = 1.35, Speed = 18 },
		Look = {
			scale = 1.35,
			main = C(232, 150, 58),
			second = C(45, 32, 26),
			belly = C(250, 240, 225),
			eye = C(255, 200, 40),
			body = { len = 3.2, w = 1.6, h = 1.5, chest = 1.25, haunch = 0.85 },
			legs = {
				len = 1.0,
				thick = 0.48,
				front = 1.15,
				claws = C(250, 245, 230),
				socks = C(250, 240, 225),
				sockH = 0.15,
			},
			head = {
				size = 1.5,
				snout = 0.6,
				snoutW = 1.2,
				lift = 0.35,
				w = 1.1,
				muzzle = C(250, 240, 225),
				cheeks = C(250, 240, 225),
			},
			mood = "fierce",
			eyes = "white",
			ears = "none",
			tail = "thin",
			tailTip = C(45, 32, 26),
			extras = { muscles = true },
			build = Build.saber,
		},
	},
	------------------------------------------------------------ LENDÁRIOS
	astronaut_dog = {
		Name = "Astro Dog",
		Rarity = "Legendary",
		Role = "Space",
		Special = "B_RocketBarrage",
		Stats = { HP = 1.2, Atk = 1.35, Speed = 18 },
		Look = {
			scale = 1.2,
			main = C(238, 240, 245),
			second = C(255, 120, 30),
			belly = C(222, 225, 232),
			eye = C(40, 30, 30),
			body = { len = 2.8, w = 1.55, h = 1.45 },
			legs = { len = 0.95, thick = 0.44, lower = C(230, 232, 238) },
			head = {
				size = 1.4,
				snout = 0.75,
				lift = 0.55,
				cap = C(205, 150, 90),
				muzzle = C(245, 225, 195),
				bridge = C(205, 150, 90),
			},
			mood = "happy",
			eyes = "cute",
			ears = "floppy",
			earColor = C(170, 115, 65),
			tail = "thin",
			tailColor = C(205, 150, 90),
			extras = { float = 0.7 },
			build = Build.astronaut,
		},
	},
	yeti_dog = {
		Name = "Yeti Dog",
		Rarity = "Legendary",
		Role = "Ice Colossus",
		Special = "B_Avalanche",
		Stats = { HP = 1.55, Atk = 1.2, Speed = 15 },
		Look = {
			scale = 1.55,
			main = C(240, 244, 250),
			second = C(150, 175, 210),
			belly = C(252, 253, 255),
			eye = C(80, 200, 255),
			body = { len = 2.8, w = 2.0, h = 1.8, chest = 1.4, haunch = 0.8 },
			legs = {
				len = 1.15,
				thick = 0.5,
				front = 1.45,
				hind = 0.85,
				claws = C(170, 225, 255),
				feather = C(252, 253, 255),
			},
			head = {
				size = 1.45,
				snout = 0.5,
				snoutW = 1.1,
				lift = 0.45,
				forward = 0.1,
				face = C(125, 145, 180),
				muzzle = C(135, 155, 190),
				brows = C(252, 253, 255),
				jowls = true,
				neckW = 1.2,
			},
			mood = "fierce",
			eyes = "glow",
			ears = "none",
			tail = "stub",
			extras = { mane = C(245, 248, 252), eyeGlow = true, aura = C(190, 235, 255) },
			build = Build.yeti,
		},
	},
	werewolf_dog = {
		Name = "Werewolf Dog",
		Rarity = "Legendary",
		Role = "Night Beast",
		Special = "B_LunarFrenzy",
		Stats = { HP = 1.2, Atk = 1.45, Speed = 20 },
		Look = {
			scale = 1.45,
			main = C(92, 82, 88),
			second = C(62, 54, 60),
			belly = C(160, 145, 135),
			eye = C(255, 215, 60),
			body = { len = 2.9, w = 1.55, h = 1.6, chest = 1.35, haunch = 0.8 },
			legs = { len = 1.25, thick = 0.42, front = 1.25, claws = BONE },
			head = {
				size = 1.4,
				snout = 1.15,
				snoutW = 0.85,
				lift = 0.65,
				forward = 0.1,
				long = 1.05,
				muzzle = C(160, 145, 135),
				fangs = true,
				brows = C(62, 54, 60),
			},
			mood = "evil",
			eyes = "glow",
			ears = "pointy",
			earSize = 1.25,
			earInner = C(120, 80, 90),
			tail = "fluffy",
			tailFeather = C(62, 54, 60),
			extras = { mane = C(70, 62, 68), spiky = true, eyeGlow = true, aura = C(200, 200, 255) },
			build = Build.werewolf,
		},
	},
	octopus_dog = {
		Name = "Octopus Dog",
		Rarity = "Legendary",
		Role = "Abyssal",
		Special = "B_InkTentacles",
		Stats = { HP = 1.3, Atk = 1.35, Speed = 16 },
		Look = {
			scale = 1.35,
			main = C(175, 70, 145),
			second = C(110, 40, 100),
			belly = C(255, 185, 210),
			eye = C(255, 225, 90),
			body = { len = 2.6, w = 1.6, h = 1.4 },
			legs = { len = 1.0, thick = 0.42 },
			head = { size = 1.55, snout = 0.7, lift = 0.45, muzzle = C(215, 120, 175) },
			mood = "fierce",
			eyes = "white",
			ears = "none",
			tail = "stub",
			extras = { aura = C(255, 120, 200) },
			build = Build.octopus,
		},
	},
	tank_dog = {
		Name = "Tank Dog",
		Rarity = "Legendary",
		Role = "Artillery",
		Special = "B_TankShell",
		Stats = { HP = 1.5, Atk = 1.3, Speed = 14 },
		Look = {
			scale = 1.35,
			main = C(98, 112, 72),
			second = C(70, 80, 52),
			belly = C(120, 130, 95),
			eye = C(255, 90, 60),
			body = { len = 3.2, w = 1.8, h = 1.35 },
			legs = { len = 0.75, thick = 0.5 },
			head = {
				size = 1.4,
				snout = 0.85,
				lift = 0.35,
				forward = 0.15,
				cap = C(150, 115, 80),
				muzzle = C(215, 190, 150),
				bridge = C(150, 115, 80),
			},
			mood = "fierce",
			eyes = "white",
			ears = "none",
			tail = "antenna",
			extras = { goggles = C(120, 200, 255) },
			build = Build.tank,
		},
	},
	wizard_dog = {
		Name = "Wizard Dog",
		Rarity = "Legendary",
		Role = "Arcane",
		Special = "B_ArcaneOrbs",
		Stats = { HP = 1.15, Atk = 1.45, Speed = 17 },
		Look = {
			scale = 1.2,
			main = C(205, 205, 215),
			second = C(75, 50, 165),
			belly = C(238, 238, 245),
			eye = C(120, 220, 255),
			body = { len = 2.8, w = 1.4, h = 1.35 },
			legs = { len = 1.0, thick = 0.36 },
			head = { size = 1.45, snout = 0.85, lift = 0.55, brows = C(250, 250, 250) },
			mood = "calm",
			eyes = "white",
			ears = "long",
			earColor = C(170, 170, 185),
			tail = "fluffy",
			extras = { float = 0.9 },
			build = Build.wizard,
		},
	},
}

return {
	Species = Species,
	Order = {
		"pirate_dog",
		"scorpion_dog",
		"flytrap_dog",
		"dj_dog",
		"knight_dog",
		"armadillo_dog",
		"saber_dog",
		"astronaut_dog",
		"yeti_dog",
		"werewolf_dog",
		"octopus_dog",
		"tank_dog",
		"wizard_dog",
	},
	Specials = {
		B_AnchorHook = { Name = "Captain's Anchor", Desc = "Spins the anchor, hurls it at the target, reels it back and smashes it into the ground." },
		B_Stinger = { Name = "Stinger", Desc = "Raises its tail and stings three times; the target is poisoned and slowed." },
		B_VineSnare = { Name = "Flytrap Snap", Desc = "Vines trap the target; the plant head chomps it and leaves an acid puddle." },
		B_BassDrop = { Name = "Bass Drop", Desc = "Three sound beats push the target back and the final DROP stuns the area." },
		B_ShieldLance = { Name = "Shield & Lance", Desc = "Raises its shield (blocks damage) and counters with lance thrusts." },
		B_RollingBall = { Name = "Armored Ball", Desc = "Curls into an armored ball, bounces on the target again and again and cracks the ground." },
		B_SaberMaul = { Name = "Saber Fury", Desc = "A paralyzing roar, a pounce, X-claws and a saber bite that makes it bleed." },
		B_RocketBarrage = { Name = "Rocket Rain", Desc = "Fires up its jetpack, flies up and launches curving rockets at the target." },
		B_Avalanche = { Name = "Avalanche", Desc = "Lifts a giant snowball and throws it: it explodes and freezes." },
		B_LunarFrenzy = { Name = "Lunar Fury", Desc = "Howls at the moon, attacks with life-stealing claws and finishes with an uppercut." },
		B_InkTentacles = { Name = "Ink & Tentacles", Desc = "Spits blinding ink, tentacles burst from the ground, squeeze the target and slam it down." },
		B_TankShell = { Name = "Heavy Artillery", Desc = "Aims with a laser, fires a huge shell (recoil!) and sets the ground on fire." },
		B_ArcaneOrbs = { Name = "Arcane Orbs", Desc = "Three orbs spin, fly at the target and a magic seal opens beneath it and explodes." },
	},
}

--[[ ================================================================
     ARQUIVO: src/shared/DogPacks/PackC.lua
================================================================ ]]
-- Pacote C: 13 cachorros MÍTICOS absurdos, reconhecíveis só pela silhueta.
-- Hidra de 5 cabeças, dragão-esqueleto, kraken, relógio, buraco negro minúsculo, serafim de 6 asas,
-- golem de cristal gigante, fênix de gelo, colosso do trovão, unicórnio arco-íris, samurai oni,
-- mecha gigante e cachorro planeta com anéis e lua.
--
-- Geometria extra vem de Look.build(b, ctx) (ver DogBuilder). Peças que giram/balançam são presas a
-- pivôs com atributos lidos pelo cliente (EffectsPacks/PackC):
--   CSpin  = Vector3 (rad/s em X, Y, Z) giro contínuo do Weld do pivô
--   CWave  = Vector3 (amplitude em rad nos eixos X, Y, Z) balanço senoidal; CFreq = rad/s; CPhase = fase
-- O modelo recebe o atributo "CAnim" para o cliente saber que precisa animar.
local C = Color3.fromRGB
local PI = math.pi
local ANG = CFrame.Angles

local NEON = Enum.Material.Neon
local GLASS = Enum.Material.Glass
local METAL = Enum.Material.Metal
local SMOOTH = Enum.Material.SmoothPlastic

local WHITE = C(250, 250, 250)
local BONE = C(236, 228, 204)
local GOLD = C(245, 195, 70)
local DARK = C(24, 20, 22)
local STEEL = C(170, 176, 188)

local function V(x, y, z)
	return Vector3.new(x, y, z)
end

local function CF(x, y, z)
	if type(x) ~= "number" then
		return CFrame.new(x)
	end
	return CFrame.new(x, y, z)
end

local function glow(p, color)
	p.Material = NEON
	if color then
		p.Color = color
	end
	p.CastShadow = false
	return p
end

-- pivô invisível que gira (CSpin) ou balança (CWave) no cliente
local function spinPivot(b, parent, name, cf, w)
	local p = b:Pivot(name)
	b:Attach(parent, p, cf)
	p:SetAttribute("CSpin", w)
	return p
end

local function wavePivot(b, parent, name, cf, amp, freq, phase)
	local p = b:Pivot(name)
	b:Attach(parent, p, cf)
	p:SetAttribute("CWave", amp)
	p:SetAttribute("CFreq", freq)
	p:SetAttribute("CPhase", phase or 0)
	return p
end

-- anel segmentado no plano XZ local de cf
local function ring(b, parent, name, cf, radius, segs, thick, height, color, mat)
	local arc = 2 * PI * radius / segs * 1.12
	local list = {}
	for i = 1, segs do
		local a = i / segs * PI * 2
		local p = b:K(parent, name, V(thick, height, arc), color, cf * ANG(0, a, 0) * CF(radius, 0, 0), mat)
		table.insert(list, p)
	end
	return list
end

-- engrenagem: disco + dentes, no plano XZ local de cf
local function gear(b, parent, name, cf, radius, teeth, thick, color)
	b:E(parent, name, V(radius * 2, thick, radius * 2), color, cf, METAL)
	b:E(parent, name .. "Eixo", V(radius * 0.5, thick * 1.6, radius * 0.5), DARK, cf, METAL)
	for i = 1, teeth do
		local a = i / teeth * PI * 2
		b:K(parent, name .. "Dente", V(radius * 0.32, thick * 0.9, radius * 0.24), color, cf * ANG(0, a, 0) * CF(radius * 1.02, 0, 0), METAL)
	end
end

-- tentáculo: começa em (0,0,0) do pivô e cresce para +X local, curvando para -Y e enrolando na ponta
local function tentacle(b, pivot, name, len, r0, color, sucker, curl, n)
	n = n or 6
	local pts = { V(0, 0, 0) }
	local dir = V(1, 0.25, 0).Unit
	local step = len / n
	local p = V(0, 0, 0)
	for k = 1, n do
		local a = -(curl or 0.45) * (k / n) ^ 1.4 * 1.6
		local c, s = math.cos(a), math.sin(a)
		local d = V(dir.X * c - dir.Y * s, dir.X * s + dir.Y * c, 0)
		p = p + d * step * (1.12 - k / n * 0.4)
		table.insert(pts, p)
	end
	local radii = {}
	for k = 1, n do
		radii[k] = r0 * (1 - (k - 1) / n * 0.8)
	end
	b:Chain(pivot, name, pts, radii, color)
	if sucker then
		for k = 2, n - 1 do
			local m = (pts[k] + pts[k + 1]) / 2
			local r = radii[k]
			b:E(pivot, name .. "Ventosa", V(r * 0.9, r * 0.5, r * 0.9), sucker, CF(m.X, m.Y - r * 0.82, m.Z), SMOOTH)
		end
	end
	return pts
end

-- asa de penas (cópia própria, para asas extras); P(x,y,z) no espaço do pivô
local function featherWing(b, pivot, side, ws, cols, eyeColor)
	local function P(x, y, z)
		return V(side * x * ws, y * ws, z * ws)
	end
	local elbow, tip = P(0.95, 0.75, 0.15), P(1.75, 1.55, 0.35)
	b:Seg(pivot, "AsaBraco", P(0, 0, 0), elbow, 0.26 * ws, 0.16 * ws, cols[1])
	b:Seg(pivot, "AsaBraco", elbow, tip, 0.2 * ws, 0.13 * ws, cols[1])
	for i = 0, 5 do
		local f = i / 5
		local root = P(0.2, 0.15, 0.1):Lerp(tip, f)
		local len = (0.85 + f * 1.0) * ws
		local dir = V(side * (0.1 + f * 0.55), -0.55 + f * 0.25, 1).Unit
		local normal = (tip - P(0, 0, 0)).Unit:Cross(dir)
		b:Seg(pivot, "Pena", root, root + dir * len, 0.22 * ws, 0.05 * ws, cols[2 + (i % 2)], nil, normal)
		if eyeColor and i % 2 == 1 then
			-- olhos nas penas (serafim)
			local at = root + dir * len * 0.55 + normal * 0.07 * ws * side
			local cf = CFrame.lookAt(at, at + normal * side)
			b:E(pivot, "OlhoAsa", V(0.24, 0.16, 0.06) * ws, WHITE, cf, SMOOTH)
			glow(b:E(pivot, "OlhoAsaIris", V(0.1, 0.1, 0.04) * ws, eyeColor, cf * CF(0, 0, -0.025 * ws)))
		end
	end
end

-- Copia uma cabeça inteira (cabeça + mandíbula + tudo soldado nelas) para outra posição.
-- Usado pela hidra (5 cabeças). Motores copiados são renomeados (o Animator só anima Neck/Jaw 1..3).
local function cloneHead(ctx, src, name, cf)
	local model, torso = ctx.Model, ctx.Torso
	local joints = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Weld") or d:IsA("Motor6D") then
			table.insert(joints, d)
		end
	end
	local set, list = { [src] = true }, { src }
	local grew = true
	while grew do
		grew = false
		for _, j in ipairs(joints) do
			local p0, p1 = j.Part0, j.Part1
			if p0 and p1 and set[p0] and not set[p1] then
				set[p1] = true
				table.insert(list, p1)
				grew = true
			end
		end
	end
	local T = cf * src.CFrame:Inverse()
	local map = {}
	for _, p in ipairs(list) do
		map[p] = p:Clone()
	end
	for p, c in pairs(map) do
		c.CFrame = T * p.CFrame
		for _, j in ipairs(c:GetChildren()) do
			if j:IsA("Weld") or j:IsA("Motor6D") then
				local p0, p1 = j.Part0, j.Part1
				if p0 and map[p0] then
					j.Part0 = map[p0]
				end
				if p1 and map[p1] then
					j.Part1 = map[p1]
				end
				if j:IsA("Motor6D") then
					j.Name = "C" .. j.Name
				end
			end
		end
	end
	for _, c in pairs(map) do
		c.Parent = model
	end
	local head = map[src]
	head.Name = name
	local w = Instance.new("Weld")
	w.Part0 = torso
	w.Part1 = head
	w.C0 = torso.CFrame:Inverse() * head.CFrame
	w.Parent = head
	return head
end

local function eachPart(model, test, fn)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and test(d.Name) then
			fn(d)
		end
	end
end

local function named(list)
	local set = {}
	for _, n in ipairs(list) do
		set[n] = true
	end
	return function(n)
		return set[n] == true
	end
end

-- ponto na superfície do tronco (elipsoide aproximado): a = ângulo em volta de Z (0 = topo), fz -0.5..0.5
local function bodyPoint(B, a, fz, push)
	local rx, ry = B.w * 0.5, B.h * 0.5
	local k = math.sqrt(math.max(0.05, 1 - (2 * fz) ^ 2))
	local p = V(math.sin(a) * rx * k, math.cos(a) * ry * k + B.h * 0.04, fz * B.len)
	local n = V(p.X / (rx * rx), (p.Y - B.h * 0.04) / (ry * ry), p.Z / (B.len * B.len * 0.25)).Unit
	p = p + n * (push or 0)
	return CFrame.lookAt(p, p + n)
end

local function neckTop(look, B, x)
	local H = look.head
	return V(x or 0, B.h * 0.3 + (H.lift or 0), -B.len * 0.45 - (H.forward or 0))
end

local RAINBOW = { C(255, 70, 80), C(255, 160, 50), C(255, 230, 70), C(90, 220, 110), C(80, 170, 255), C(170, 100, 255) }

local Species = {}

------------------------------------------------------------------------ HIDRA
Species.hydra_hound = {
	Name = "Five-Headed Hydra",
	Rarity = "Mythic",
	Role = "Regen",
	Special = "C_HydraFrenzy",
	Stats = { HP = 1.65, Atk = 1.4, Speed = 15 },
	Look = {
		scale = 2.1,
		main = C(40, 112, 78),
		second = C(190, 230, 80),
		belly = C(214, 206, 140),
		eye = C(255, 220, 40),
		body = { len = 3.6, w = 2.1, h = 1.7, chest = 1.2, haunch = 0.95 },
		legs = { len = 0.95, thick = 0.5, claws = BONE, noToes = true },
		head = { size = 1.15, snout = 1.15, snoutW = 0.8, long = 1.12, lift = 1.9, forward = 0.7, neckW = 0.62, brows = C(190, 230, 80) },
		mood = "evil",
		ears = "swept",
		earColor = C(190, 230, 80),
		earInner = C(30, 80, 55),
		tail = "dragon",
		tailSize = 1.2,
		spikeColor = C(190, 230, 80),
		heads = 3,
		extras = { scales = true, spikes = C(190, 230, 80), spikeCount = 6, horns = "small", eyeGlow = true, aura = C(150, 255, 120) },
		build = function(b, ctx)
			local model, torso, B, look = ctx.Model, ctx.Torso, ctx.Body, ctx.Look
			local S = ctx.Scale
			local hs = look.head.size
			local srcs = { model:FindFirstChild("Head1"), model:FindFirstChild("Head3") }
			for i, side in ipairs({ -1, 1 }) do
				local src = srcs[i]
				if src then
					local top = V(side * B.w * 1.05, B.h * 0.3 + look.head.lift - 0.85, -B.len * 0.28)
					local base = V(side * B.w * 0.36, B.h * 0.12, -B.len * 0.22)
					local mid = V(side * B.w * 0.95, B.h * 0.15, -B.len * 0.2)
					local r = 0.3 * hs * look.head.neckW
					b:Chain(torso, "PescocoHidra", { base, mid, top }, { r * 1.15, r }, look.main)
					b:Seg(torso, "GargantaHidra", mid + V(0, -0.15, -0.12), top + V(0, -0.25, -0.12), r * 0.75, r * 0.6, look.belly)
					local yaw = -side * 1.0
					local cf = torso.CFrame * CF(top * S) * ANG(0, yaw, 0) * CF(0, 0.12 * hs * S, -0.3 * hs * S)
					cloneHead(ctx, src, "Head" .. (3 + i), cf)
				end
			end
			-- cristas de espinhos ao longo dos pescoços do meio
			for _, x in ipairs({ -1, 0, 1 }) do
				local top = neckTop(look, B, x * B.w * 0.44 * 1.15)
				local base = V(x * B.w * 0.44 * 0.8, B.h * 0.08, -B.len * 0.3)
				for k = 1, 3 do
					local p = base:Lerp(top, k / 4) + V(0, 0.28, 0.12)
					b:W(torso, "EspinhoPescoco", V(0.06, 0.32, 0.26), look.second, CF(p) * ANG(0.5, 0, 0))
				end
			end
		end,
	},
}

------------------------------------------------------------------------ DRAGÃO-ESQUELETO
Species.bone_dragon = {
	Name = "Bone Dragon",
	Rarity = "Mythic",
	Role = "Undead",
	Special = "C_BoneCage",
	Stats = { HP = 1.35, Atk = 1.55, Speed = 18 },
	Look = {
		scale = 1.9,
		main = C(30, 70, 66),
		second = C(90, 255, 200),
		belly = C(30, 70, 66),
		eye = C(90, 255, 200),
		body = { len = 3.4, w = 1.25, h = 1.25, chest = 1.1, haunch = 0.85 },
		legs = { len = 1.25, thick = 0.24, color = BONE, claws = C(90, 255, 200), noToes = true },
		head = { size = 1.35, snout = 1.25, snoutW = 0.75, long = 1.12, lift = 0.75, forward = 0.25, cap = BONE, muzzle = BONE, skull = true, neckW = 0.6 },
		neckColor = BONE,
		mood = "evil",
		eyes = "skull",
		ears = "none",
		tail = "bone",
		tailSize = 1.3,
		tailColor = BONE,
		hornColor = BONE,
		wingSize = 1.35,
		wingBone = BONE,
		wingColor = C(40, 110, 95),
		extras = {
			ribs = BONE,
			noBelly = true,
			wings = "dragon",
			horns = "dragon",
			smoke = C(40, 160, 130),
			eyeGlow = true,
			aura = C(90, 255, 200),
		},
		build = function(b, ctx)
			local model, torso, B = ctx.Model, ctx.Torso, ctx.Body
			-- corpo vira "alma" translúcida dentro das costelas, com coração verde aceso
			eachPart(model, named({ "Torso", "Peito", "Quadril" }), function(p)
				p.Transparency = 0.55
				p.Material = GLASS
				p.CastShadow = false
			end)
			eachPart(model, named({ "AsaMembrana" }), function(p)
				p.Transparency = 0.35
			end)
			glow(b:E(torso, "Coracao", V(0.55, 0.6, 0.5), C(90, 255, 200), CF(0, 0, -B.len * 0.18)))
			glow(b:E(torso, "Alma", V(0.3, 0.3, 0.9), C(200, 255, 235), CF(0, 0.05, B.len * 0.08))).Transparency = 0.3
			-- espinha dorsal com espetos de osso
			for i = 0, 5 do
				local z = -B.len * 0.36 + i * B.len * 0.15
				local h = 0.55 - math.abs(i - 2) * 0.07
				b:W(torso, "EspetoOsso", V(0.08, h, h * 0.8), BONE, CF(0, B.h * 0.55 + h * 0.45, z) * ANG(0.3, 0, 0), SMOOTH)
			end
			-- esterno
			b:Seg(torso, "Esterno", V(0, -B.h * 0.2, -B.len * 0.36), V(0, -B.h * 0.25, -B.len * 0.02), 0.09, 0.06, BONE, SMOOTH)
		end,
	},
}

------------------------------------------------------------------------ KRAKEN
Species.kraken_hound = {
	Name = "Kraken Dog",
	Rarity = "Mythic",
	Role = "Abyssal",
	Special = "C_KrakenGrab",
	Stats = { HP = 1.55, Atk = 1.4, Speed = 15 },
	Look = {
		scale = 1.85,
		main = C(150, 45, 95),
		second = C(255, 150, 185),
		belly = C(250, 195, 210),
		eye = C(255, 215, 50),
		body = { len = 3.2, w = 1.9, h = 1.6, chest = 1.15 },
		legs = { len = 0.85, thick = 0.42, noToes = true },
		head = { size = 1.6, snout = 0.55, snoutW = 0.9, w = 1.1, tall = 1.05, lift = 0.5, forward = 0.2, eyeSize = 1.35, muzzle = C(190, 80, 125) },
		mood = "fierce",
		ears = "none",
		tail = "tentacles",
		tailSize = 1.3,
		extras = { bubbles = C(170, 230, 255), eyeGlow = true, aura = C(255, 120, 200), spots = C(205, 90, 140), spotCount = 14 },
		build = function(b, ctx)
			local model, torso, B, look = ctx.Model, ctx.Torso, ctx.Body, ctx.Look
			model:SetAttribute("CAnim", true)
			local head = model:FindFirstChild("Head1")
			local hs = look.head.size
			if head then
				-- manto de polvo saindo do topo da cabeça para trás
				local manto = b:E(head, "Manto", V(1.05, 1.15, 1.6) * hs, look.main, CF(0, 0.55 * hs, 0.55 * hs) * ANG(0.55, 0, 0))
				local _ = manto
				for i = 1, 5 do
					local a = i * 1.3
					b:E(
						head,
						"MantoPinta",
						V(0.22, 0.16, 0.22) * hs,
						look.second,
						CF(math.cos(a) * 0.35 * hs, 0.85 * hs + math.sin(a) * 0.12 * hs, (0.5 + i * 0.1) * hs) * ANG(0.5, 0, 0),
						SMOOTH
					)
				end
				-- barba de tentáculos embaixo do focinho (estilo Cthulhu)
				for i = -2, 2 do
					local piv = wavePivot(
						b,
						head,
						"BarbaPivo",
						CF(i * 0.14 * hs, -0.42 * hs, -0.55 * hs) * ANG(0, PI / 2 + i * 0.25, -1.25),
						V(0, 0.15, 0.25),
						2.2,
						i * 0.9
					)
					tentacle(b, piv, "Barba", (0.75 - math.abs(i) * 0.1) * hs, 0.09 * hs, look.main, look.belly, 0.7, 4)
				end
			end
			-- 6 tentáculos gigantes saindo dos lados do corpo
			for _, side in ipairs({ -1, 1 }) do
				for k = 0, 2 do
					local z = -B.len * 0.25 + k * B.len * 0.25
					local cf = CF(side * B.w * 0.42, -B.h * 0.05 + k * 0.05, z) * ANG(0, side < 0 and PI or 0, 0) * ANG(0, (k - 1) * 0.5 * side, -0.25)
					local piv = wavePivot(b, torso, "TentaculoPivo", cf, V(0.15, 0.12, 0.2), 1.6, k * 1.7 + side)
					tentacle(b, piv, "Tentaculo", 2.6 - k * 0.2, 0.3, look.main, look.belly, 0.8, 6)
				end
			end
		end,
	},
}

------------------------------------------------------------------------ RELÓGIO
Species.chrono_hound = {
	Name = "Chrono Dog",
	Rarity = "Mythic",
	Role = "Time",
	Special = "C_TimeStop",
	Stats = { HP = 1.3, Atk = 1.5, Speed = 18 },
	Look = {
		scale = 1.45,
		material = METAL,
		main = C(200, 158, 78),
		second = C(130, 86, 44),
		belly = C(246, 236, 210),
		eye = C(110, 220, 255),
		body = { len = 3.0, w = 1.55, h = 1.5 },
		legs = { len = 1.05, thick = 0.36, paw = C(130, 86, 44), noToes = true },
		head = { size = 1.4, snout = 0.85, lift = 0.5, muzzle = C(246, 236, 210), eyeSize = 1.1 },
		mood = "calm",
		ears = "none",
		tail = "stub",
		extras = { eyeGlow = true, aura = C(120, 220, 255) },
		build = function(b, ctx)
			local model, torso, B, look = ctx.Model, ctx.Torso, ctx.Body, ctx.Look
			model:SetAttribute("CAnim", true)
			local ivory, brass, bronze = look.belly, look.main, look.second
			-- mostradores nos dois lados do corpo com ponteiros girando
			for _, side in ipairs({ -1, 1 }) do
				local center = V(side * B.w * 0.47, B.h * 0.04, -B.len * 0.05)
				local face = CF(center) * ANG(0, 0, side * PI / 2) -- eixo Y local = normal para fora
				b:E(torso, "Mostrador", V(1.55, 0.14, 1.55), ivory, face, SMOOTH)
				ring(b, torso, "Moldura", face, 0.8, 18, 0.14, 0.2, brass, METAL)
				for h = 1, 12 do
					local a = h / 12 * PI * 2
					local big = h % 3 == 0
					b:K(torso, "Marca", V(big and 0.08 or 0.05, 0.05, big and 0.2 or 0.12), DARK, face * ANG(0, a, 0) * CF(0, 0.08, -0.62), SMOOTH)
				end
				glow(b:E(torso, "Centro", V(0.14, 0.1, 0.14), C(120, 220, 255), face * CF(0, 0.1, 0)))
				local hour = spinPivot(b, torso, "Ponteiro", face * CF(0, 0.09, 0), V(0, -0.5 * side, 0))
				b:K(hour, "PonteiroHora", V(0.09, 0.04, 0.42), DARK, CF(0, 0, -0.18), SMOOTH)
				local minute = spinPivot(b, torso, "Ponteiro", face * CF(0, 0.11, 0), V(0, -3 * side, 0))
				b:K(minute, "PonteiroMinuto", V(0.06, 0.04, 0.62), DARK, CF(0, 0, -0.28), SMOOTH)
				-- engrenagem girando no quadril
				local gcf = CF(side * B.w * 0.4, B.h * 0.18, B.len * 0.3) * ANG(0, 0, side * PI / 2)
				local g = spinPivot(b, torso, "Engrenagem", gcf, V(0, 1.2 * side, 0))
				gear(b, g, "Engrenagem", CFrame.new(), 0.42, 9, 0.12, bronze)
			end
			-- chave de corda nas costas
			local key = spinPivot(b, torso, "Chave", CF(0, B.h * 0.5, B.len * 0.08), V(0, 1.6, 0))
			b:K(key, "ChaveEixo", V(0.16, 0.7, 0.16), brass, CF(0, 0.3, 0), METAL)
			for _, side in ipairs({ -1, 1 }) do
				b:E(key, "ChaveAsa", V(0.75, 0.55, 0.14), brass, CF(side * 0.4, 0.75, 0), METAL)
				b:E(key, "ChaveFuro", V(0.32, 0.24, 0.16), bronze, CF(side * 0.42, 0.75, 0), METAL)
			end
			-- pêndulo balançando embaixo da barriga
			local pend = wavePivot(b, torso, "Pendulo", CF(0, -B.h * 0.35, 0.1), V(0, 0, 0.45), 3.2, 0)
			b:K(pend, "PenduloHaste", V(0.07, 0.75, 0.07), brass, CF(0, -0.38, 0), METAL)
			b:E(pend, "PenduloDisco", V(0.55, 0.55, 0.12), GOLD, CF(0, -0.85, 0), Enum.Material.Foil)
			-- sinos de despertador no lugar das orelhas + martelinho
			local head = model:FindFirstChild("Head1")
			if head then
				local hs = look.head.size
				for _, side in ipairs({ -1, 1 }) do
					local cfb = CF(side * 0.3 * hs, 0.5 * hs, 0.05 * hs) * ANG(0, 0, -side * 0.55)
					b:E(head, "Sino", V(0.55, 0.5, 0.55) * hs, brass, cfb * CF(0, 0.12 * hs, 0), METAL)
					b:E(head, "SinoBorda", V(0.6, 0.08, 0.6) * hs, bronze, cfb * CF(0, -0.1 * hs, 0), METAL)
					b:E(head, "SinoPe", V(0.08, 0.2, 0.08) * hs, bronze, cfb * CF(0, 0.42 * hs, 0), METAL)
				end
				local ham = wavePivot(b, head, "Martelo", CF(0, 0.55 * hs, 0.1 * hs), V(0, 0, 0.35), 14, 0)
				b:K(ham, "MarteloHaste", V(0.04, 0.32, 0.04) * hs, DARK, CF(0, 0.14 * hs, 0), METAL)
				b:E(ham, "MarteloBola", V(0.12, 0.12, 0.12) * hs, bronze, CF(0, 0.32 * hs, 0), METAL)
				-- monóculo
				local eye = CF(0.21 * hs, 0.08 * hs, -0.42 * hs)
				ring(b, head, "Monoculo", eye * ANG(PI / 2, 0, 0), 0.15 * hs, 10, 0.03 * hs, 0.03 * hs, GOLD, Enum.Material.Foil)
				b:Seg(
					head,
					"MonoculoCorrente",
					eye.Position + V(0.12, -0.1, 0) * hs,
					V(0.45, -0.35, 0.05) * hs,
					0.015 * hs,
					0.015 * hs,
					GOLD,
					Enum.Material.Foil
				)
			end
			-- ampulheta na cauda
			local tail = model:FindFirstChild("TailBase")
			if tail then
				local base = CF(0, 0.35, 0.35) * ANG(-0.5, 0, 0)
				b:E(tail, "AmpulhetaTampa", V(0.55, 0.1, 0.55), bronze, base, METAL)
				b:E(tail, "AmpulhetaTampa", V(0.55, 0.1, 0.55), bronze, base * CF(0, 0.9, 0), METAL)
				local g1 = b:E(tail, "AmpulhetaVidro", V(0.45, 0.45, 0.45), C(220, 240, 255), base * CF(0, 0.25, 0), GLASS)
				local g2 = b:E(tail, "AmpulhetaVidro", V(0.45, 0.45, 0.45), C(220, 240, 255), base * CF(0, 0.65, 0), GLASS)
				g1.Transparency = 0.45
				g2.Transparency = 0.45
				glow(b:E(tail, "Areia", V(0.3, 0.2, 0.3), C(255, 210, 110), base * CF(0, 0.15, 0)))
				glow(b:E(tail, "Areia", V(0.05, 0.4, 0.05), C(255, 210, 110), base * CF(0, 0.45, 0)))
				for _, s in ipairs({ -1, 1 }) do
					b:K(tail, "AmpulhetaHaste", V(0.04, 0.9, 0.04), bronze, base * CF(s * 0.24, 0.45, 0), METAL)
				end
			end
		end,
	},
}

------------------------------------------------------------------------ BURACO NEGRO (minúsculo)
Species.singularity_pup = {
	Name = "Singularity Pup",
	Rarity = "Mythic",
	Role = "Gravity",
	Special = "C_EventHorizon",
	Stats = { HP = 1.2, Atk = 1.65, Speed = 21 },
	Look = {
		scale = 0.5,
		main = C(10, 8, 18),
		second = C(255, 150, 50),
		belly = C(18, 14, 30),
		eye = C(255, 255, 255),
		body = { len = 1.7, w = 1.5, h = 1.5 },
		legs = { len = 0.6, thick = 0.34, noToes = true, paw = C(255, 150, 50) },
		head = { size = 1.45, snout = 0.45, snoutW = 0.9, lift = 0.25, eyeSize = 1.5, muzzle = C(26, 20, 40) },
		mood = "calm",
		eyes = "glow",
		ears = "big",
		earInner = C(255, 150, 50),
		tail = "wisp",
		extras = { float = 2.2, stars = true, eyeGlow = true, aura = C(255, 160, 70) },
		build = function(b, ctx)
			local model, torso = ctx.Model, ctx.Torso
			model:SetAttribute("CAnim", true)
			-- disco de acreção inclinado girando (laranja → amarelo → branco)
			local tilt = CF(0, 0.05, 0) * ANG(0.35, 0, 0.25)
			local disk = spinPivot(b, torso, "Acrecao", tilt, V(0, 2.4, 0))
			ring(b, disk, "Disco", CFrame.new(), 2.5, 26, 0.5, 0.06, C(255, 120, 40), NEON)
			ring(b, disk, "Disco", CFrame.new(), 2.0, 22, 0.45, 0.07, C(255, 200, 80), NEON)
			ring(b, disk, "Disco", CFrame.new(), 1.55, 18, 0.3, 0.08, C(255, 250, 230), NEON)
			-- destroços presos na órbita
			for i = 1, 5 do
				local a = i / 5 * PI * 2 + 0.4
				b:K(
					disk,
					"Destroco",
					V(0.32, 0.26, 0.3) * (0.6 + (i % 3) * 0.25),
					C(110, 100, 120),
					CF(math.cos(a) * 2.95, 0.1, math.sin(a) * 2.95) * ANG(i, i * 2, 0),
					Enum.Material.Slate
				)
			end
			-- anel de fótons (vertical, sempre "de frente")
			ring(b, torso, "AnelFoton", CF(0, 0.05, 0) * ANG(PI / 2, 0, 0), 1.25, 20, 0.08, 0.06, C(255, 240, 210), NEON)
			-- jatos polares
			local up = tilt.Rotation * V(0, 1, 0)
			for _, s in ipairs({ 1, -1 }) do
				local a = up * 0.7 * s
				local t = up * 2.6 * s
				local jet = glow(b:Seg(torso, "Jato", a, t, 0.12, 0.12, C(190, 160, 255)))
				jet.Transparency = 0.2
				glow(b:Seg(torso, "JatoBrilho", a, a:Lerp(t, 0.6), 0.22, 0.22, C(120, 80, 255))).Transparency = 0.55
			end
		end,
	},
}

------------------------------------------------------------------------ SERAFIM (6 asas)
Species.seraph_hound = {
	Name = "Six-Winged Seraph",
	Rarity = "Mythic",
	Role = "Holy",
	Special = "C_Judgement",
	Stats = { HP = 1.45, Atk = 1.4, Speed = 17 },
	Look = {
		scale = 1.55,
		main = C(252, 250, 244),
		second = C(255, 212, 95),
		belly = C(255, 255, 252),
		eye = C(255, 236, 150),
		body = { len = 3.0, w = 1.4, h = 1.4 },
		legs = { len = 1.0, thick = 0.36, paw = C(255, 212, 95) },
		head = { size = 1.4, snout = 0.8, lift = 0.55, eyeSize = 1.05 },
		mood = "calm",
		ears = "floppy",
		earSize = 1.15,
		earTip = C(255, 212, 95),
		tail = "plume",
		wingSize = 1.35,
		wingColors = { C(255, 255, 252), C(255, 246, 220), C(255, 220, 130) },
		extras = { wings = "feather", halo = C(255, 225, 110), float = 2.4, stars = true, gem = C(120, 200, 255), eyeGlow = true, aura = C(255, 230, 140) },
		build = function(b, ctx)
			local model, torso, B, look = ctx.Model, ctx.Torso, ctx.Body, ctx.Look
			model:SetAttribute("CAnim", true)
			local cols = look.wingColors
			for _, side in ipairs({ -1, 1 }) do
				-- par de cima: sobe e cobre por cima da cabeça
				local up =
					wavePivot(b, torso, "AsaCima", CF(side * B.w * 0.22, B.h * 0.48, -B.len * 0.28) * ANG(-0.55, 0, side * 0.75), V(0, 0, 0.12), 2.2, side)
				featherWing(b, up, side, 0.95, cols, C(90, 170, 255))
				-- par de baixo: desce cobrindo as patas
				local low =
					wavePivot(b, torso, "AsaBaixo", CF(side * B.w * 0.42, -B.h * 0.05, B.len * 0.12) * ANG(0.35, 0, side * -1.75), V(0, 0, 0.1), 1.8, side + 1)
				featherWing(b, low, side, 0.9, cols, C(90, 170, 255))
			end
			-- roda sagrada de olhos girando em volta do corpo (ofanim)
			local wheel = spinPivot(b, torso, "Roda", CF(0, 0.1, 0) * ANG(0, 0, PI / 2), V(0, 0.9, 0))
			ring(b, wheel, "RodaAro", CFrame.new(), 2.3, 24, 0.14, 0.16, GOLD, Enum.Material.Foil)
			for i = 1, 6 do
				local a = i / 6 * PI * 2
				local cf = ANG(0, a, 0) * CF(2.3, 0, 0) * ANG(0, PI / 2, 0)
				b:E(wheel, "RodaOlho", V(0.42, 0.28, 0.12), WHITE, cf, SMOOTH)
				glow(b:E(wheel, "RodaIris", V(0.18, 0.18, 0.08), C(90, 170, 255), cf * CF(0, 0, 0.04)))
				glow(b:E(wheel, "RodaIris", V(0.18, 0.18, 0.08), C(90, 170, 255), cf * CF(0, 0, -0.04)))
			end
		end,
	},
}

------------------------------------------------------------------------ GOLEM DE CRISTAL (gigante)
Species.crystal_golem = {
	Name = "Crystal Golem",
	Rarity = "Mythic",
	Role = "Colossus",
	Special = "C_CrystalPrison",
	Stats = { HP = 1.85, Atk = 1.25, Speed = 13 },
	Look = {
		scale = 2.75,
		material = Enum.Material.Slate,
		main = C(72, 76, 96),
		second = C(80, 245, 225),
		belly = C(98, 102, 124),
		eye = C(110, 255, 240),
		body = { len = 3.1, w = 2.4, h = 2.0, chest = 1.45, haunch = 0.8 },
		legs = { len = 1.15, thick = 0.6, front = 1.45, hind = 0.85, noToes = true, claws = C(80, 245, 225) },
		head = { size = 1.2, snout = 0.55, snoutW = 1.25, w = 1.2, flat = true, lift = 0.15, forward = 0.3, brows = C(80, 245, 225), muzzle = C(98, 102, 124) },
		mood = "fierce",
		ears = "none",
		tail = "rock",
		extras = {
			rocks = true,
			cracks = C(80, 245, 225),
			cracksHead = C(80, 245, 225),
			eyeGlow = true,
			aura = C(80, 245, 225),
			muscles = true,
			tag = false,
		},
		build = function(b, ctx)
			local model, torso, B, look = ctx.Model, ctx.Torso, ctx.Body, ctx.Look
			local cry = look.second
			-- espigões gigantes de cristal nas costas
			local list = {
				{ 0, 0.5, -0.12, 0, 2.4 },
				{ 0.36, 0.42, -0.25, -0.5, 1.7 },
				{ -0.36, 0.42, -0.2, 0.5, 1.8 },
				{ 0.22, 0.45, 0.18, -0.3, 1.4 },
				{ -0.2, 0.45, 0.22, 0.35, 1.25 },
				{ 0.05, 0.42, 0.38, 0.1, 0.9 },
			}
			for i, c in ipairs(list) do
				local h = c[5]
				local base = CF(c[1] * B.w, c[2] * B.h, c[3] * B.len) * ANG(0.15, i * 0.8, c[4])
				local body = b:K(torso, "CristalGigante", V(0.5 * h * 0.45, h * 0.7, 0.5 * h * 0.45), cry, base * CF(0, h * 0.35, 0), GLASS)
				body.Transparency = 0.15
				for k = 0, 3 do
					local tip = b:W(
						torso,
						"CristalPonta",
						V(0.5 * h * 0.45 * 0.5, h * 0.35, 0.5 * h * 0.45 * 0.5),
						cry,
						base * CF(0, h * 0.7, 0) * ANG(0, k * PI / 2, 0) * CF(0, h * 0.175, 0.5 * h * 0.45 * 0.25) * ANG(0, PI, 0),
						GLASS
					)
					tip.Transparency = 0.15
				end
				if i % 2 == 1 then
					glow(b:K(torso, "CristalNucleo", V(0.1, h * 0.6, 0.1) * 1.4, C(220, 255, 255), base * CF(0, h * 0.4, 0)))
				end
			end
			-- núcleo no peito
			glow(b:E(torso, "Nucleo", V(0.7, 0.7, 0.3), cry, CF(0, -B.h * 0.02, -B.len * 0.5)))
			b:E(torso, "NucleoMoldura", V(1.0, 1.0, 0.25), C(50, 52, 66), CF(0, -B.h * 0.02, -B.len * 0.47))
			-- pedregulhos nos ombros
			for _, side in ipairs({ -1, 1 }) do
				b:K(torso, "Pedregulho", V(1.1, 0.9, 1.0), C(60, 62, 80), CF(side * B.w * 0.55, B.h * 0.4, -B.len * 0.28) * ANG(0.3, side * 0.5, side * 0.4))
				local sc = b:K(torso, "CristalOmbro", V(0.3, 1.0, 0.3), cry, CF(side * B.w * 0.62, B.h * 0.75, -B.len * 0.28) * ANG(0, 0, -side * 0.55), GLASS)
				sc.Transparency = 0.15
			end
			-- punhos de pedra nas patas da frente
			for _, name in ipairs({ "LegFL", "LegFR" }) do
				local leg = model:FindFirstChild(name)
				if leg then
					local sy = leg.Size.Y / ctx.Scale
					b:K(leg, "Punho", V(0.95, 0.75, 1.0), C(60, 62, 80), CF(0, -sy * 0.62, -0.05) * ANG(0.1, 0.3, 0))
					glow(b:K(leg, "PunhoCristal", V(0.18, 0.5, 0.18), cry, CF(0, -sy * 0.3, -0.38) * ANG(-0.5, 0, 0)))
				end
			end
		end,
	},
}

------------------------------------------------------------------------ FÊNIX DE GELO
Species.frost_phoenix = {
	Name = "Ice Phoenix",
	Rarity = "Mythic",
	Role = "Rebirth",
	Special = "C_GlacialRebirth",
	Stats = { HP = 1.4, Atk = 1.45, Speed = 19 },
	Look = {
		scale = 1.55,
		main = C(205, 238, 255),
		second = C(80, 165, 255),
		belly = C(250, 254, 255),
		eye = C(170, 240, 255),
		body = { len = 3.0, w = 1.3, h = 1.3 },
		legs = { len = 1.05, thick = 0.3, claws = C(80, 165, 255), paw = C(140, 200, 255) },
		head = { size = 1.35, snout = 1.25, snoutW = 0.55, lift = 0.65, muzzle = C(150, 210, 255), nose = C(50, 110, 200) },
		mood = "fierce",
		ears = "swept",
		earColor = C(80, 165, 255),
		earInner = C(220, 245, 255),
		tail = "fan",
		wingSize = 1.4,
		wingColors = { C(240, 250, 255), C(150, 215, 255), C(80, 160, 255) },
		extras = {
			wings = "feather",
			crest = true,
			float = 1.8,
			icicleBack = C(190, 235, 255),
			icicles = C(200, 240, 255),
			eyeGlow = true,
			aura = C(150, 220, 255),
		},
		build = function(b, ctx)
			local model, torso, B, look = ctx.Model, ctx.Torso, ctx.Body, ctx.Look
			model:SetAttribute("CAnim", true)
			-- penas viram vidro de gelo
			eachPart(model, named({ "Pena", "Crista" }), function(p)
				p.Material = GLASS
				p.Transparency = 0.12
			end)
			-- coroa de gelo
			local head = model:FindFirstChild("Head1")
			if head then
				local hs = look.head.size
				for i = -2, 2 do
					local h = (0.55 - math.abs(i) * 0.1) * hs
					local sp = b:W(
						head,
						"CoroaGelo",
						V(0.06, h, 0.2) * 1,
						C(200, 245, 255),
						CF(i * 0.13 * hs, 0.4 * hs + h * 0.5, 0.05 * hs) * ANG(0, PI / 2, i * 0.25),
						Enum.Material.Ice
					)
					sp.Transparency = 0.1
				end
			end
			-- floco de neve no peito
			local cf = CF(0, -B.h * 0.05, -B.len * 0.47)
			for k = 0, 2 do
				glow(b:K(torso, "Floco", V(0.07, 0.75, 0.05), C(220, 250, 255), cf * ANG(0, 0, k * PI / 3)))
			end
			-- três plumas longas de gelo na cauda balançando
			local tail = model:FindFirstChild("TailBase")
			if tail then
				for i = -1, 1 do
					local piv = wavePivot(b, tail, "PlumaPivo", CF(i * 0.18, 0.1, 0.3) * ANG(0, PI / 2 + i * 0.35, 0.55), V(0, 0.12, 0.2), 2.5, i)
					local pts = { V(0, 0, 0), V(1.0, -0.3, 0), V(2.0, -0.35, 0), V(2.9, -0.1, 0) }
					b:Chain(piv, "Pluma", pts, { 0.13, 0.1, 0.08 }, i == 0 and look.second or C(150, 215, 255))
					local tip = b:E(piv, "PlumaPonta", V(0.7, 0.18, 0.4), C(230, 250, 255), CF(3.15, -0.05, 0), GLASS)
					glow(tip, C(200, 245, 255))
				end
			end
		end,
	},
}

------------------------------------------------------------------------ COLOSSO DO TROVÃO (gigante)
Species.thunder_colossus = {
	Name = "Thunder Colossus",
	Rarity = "Mythic",
	Role = "Colossus",
	Special = "C_ThunderWall",
	Stats = { HP = 1.75, Atk = 1.35, Speed = 14 },
	Look = {
		scale = 3.0,
		main = C(46, 52, 82),
		second = C(255, 225, 60),
		belly = C(88, 98, 142),
		eye = C(255, 250, 170),
		body = { len = 3.4, w = 2.4, h = 2.0, chest = 1.45, haunch = 0.85 },
		legs = { len = 1.3, thick = 0.6, front = 1.2, claws = C(255, 225, 60), noToes = true },
		head = { size = 1.45, snout = 0.9, snoutW = 1.2, w = 1.1, forward = 0.4, lift = 0.6, jowls = true, brows = C(255, 225, 60), neckW = 1.1 },
		mood = "fierce",
		ears = "cropped",
		earInner = C(255, 225, 60),
		tail = "bolt",
		tailSize = 1.2,
		extras = { muscles = true, bolts = C(255, 225, 60), mane = C(120, 128, 160), spiky = true, eyeGlow = true, aura = C(255, 230, 90) },
		build = function(b, ctx)
			local model, torso, B, look = ctx.Model, ctx.Torso, ctx.Body, ctx.Look
			model:SetAttribute("CAnim", true)
			local yellow = look.second
			-- nuvem de tempestade flutuando sobre as costas (gira devagar)
			local cloud = spinPivot(b, torso, "Nuvem", CF(0, B.h * 0.5 + 1.7, B.len * 0.05), V(0, 0.35, 0))
			local puffs = {
				{ 0, 0, 0, 1.6 },
				{ 0.9, -0.1, 0.4, 1.2 },
				{ -0.9, -0.05, 0.3, 1.25 },
				{ 0.4, 0.35, -0.6, 1.1 },
				{ -0.5, 0.3, -0.5, 1.0 },
				{ 0.2, 0.1, 1.0, 1.05 },
				{ -0.3, -0.25, -1.0, 0.95 },
			}
			for i, p in ipairs(puffs) do
				b:E(cloud, "NuvemBolo", V(p[4] * 1.3, p[4], p[4] * 1.2), i % 2 == 0 and C(150, 155, 175) or C(105, 110, 132), CF(p[1], p[2], p[3]), SMOOTH)
			end
			-- raios saindo da nuvem até as costas
			for _, x in ipairs({ -0.7, 0.6 }) do
				local pts = { V(x, -0.5, 0.1), V(x + 0.35, -0.95, 0.3), V(x - 0.1, -1.3, -0.1), V(x + 0.2, -1.75, 0.15) }
				for k = 1, #pts - 1 do
					glow(b:Seg(cloud, "RaioNuvem", pts[k], pts[k + 1], 0.07, 0.07, yellow))
				end
			end
			-- chifres para-raios
			local head = model:FindFirstChild("Head1")
			if head then
				local hs = look.head.size
				for _, side in ipairs({ -1, 1 }) do
					local a = V(side * 0.25 * hs, 0.35 * hs, 0.05 * hs)
					local t = V(side * 0.45 * hs, 1.25 * hs, 0.2 * hs)
					b:Seg(head, "ParaRaio", a, t, 0.06 * hs, 0.06 * hs, STEEL, METAL)
					for k = 1, 3 do
						local p = a:Lerp(t, k / 4)
						b:E(head, "ParaRaioAnel", V(0.16, 0.05, 0.16) * hs, C(90, 92, 105), CF(p), METAL)
					end
					glow(b:E(head, "ParaRaioPonta", V(0.2, 0.2, 0.2) * hs, yellow, CF(t)))
				end
			end
			-- braceletes de ferro com runa acesa nas patas da frente
			for _, name in ipairs({ "LegFL", "LegFR" }) do
				local leg = model:FindFirstChild(name)
				if leg then
					local s = leg.Size / ctx.Scale
					b:E(leg, "Bracelete", V(s.X * 1.15, 0.35, s.Z * 1.15), C(80, 84, 98), CF(0, -s.Y * 0.2, 0), METAL)
					glow(b:E(leg, "BraceleteRuna", V(s.X * 1.18, 0.08, s.Z * 1.18), yellow, CF(0, -s.Y * 0.2, 0)))
				end
			end
		end,
	},
}

------------------------------------------------------------------------ UNICÓRNIO ARCO-ÍRIS
Species.rainbow_unicorn = {
	Name = "Rainbow Unicorn",
	Rarity = "Mythic",
	Role = "Prism",
	Special = "C_RainbowBridge",
	Stats = { HP = 1.3, Atk = 1.5, Speed = 20 },
	Look = {
		scale = 1.5,
		main = C(255, 252, 255),
		second = C(255, 160, 220),
		belly = C(255, 246, 252),
		eye = C(110, 70, 190),
		body = { len = 3.0, w = 1.25, h = 1.35 },
		legs = { len = 1.4, thick = 0.3, paw = C(255, 205, 90), sockH = 0.3 },
		head = { size = 1.35, snout = 1.05, snoutW = 0.78, lift = 0.95, long = 1.1, eyeSize = 1.25, muzzle = C(255, 225, 240) },
		mood = "happy",
		eyes = "cute",
		ears = "pointy",
		earSize = 0.85,
		earInner = C(255, 160, 220),
		tail = "stub",
		extras = { stars = true, aura = C(255, 170, 240), trail = C(255, 200, 250) },
		build = function(b, ctx)
			local model, torso, B, look = ctx.Model, ctx.Torso, ctx.Body, ctx.Look
			model:SetAttribute("CAnim", true)
			local head = model:FindFirstChild("Head1")
			local hs = look.head.size
			if head then
				-- chifre espiral dourado
				local base = V(0, 0.36 * hs, -0.22 * hs)
				local tip = V(0, 1.35 * hs, -0.62 * hs)
				local n = 5
				for k = 0, n - 1 do
					local a, c = base:Lerp(tip, k / n), base:Lerp(tip, (k + 1) / n)
					local r = 0.13 * hs * (1 - k / n * 0.8)
					b:Seg(head, "Chifre", a, c, r, r, k % 2 == 0 and C(255, 225, 120) or C(255, 250, 235), Enum.Material.Foil)
				end
				glow(b:E(head, "ChifreBrilho", V(0.1, 0.1, 0.1) * hs, WHITE, CF(tip)))
			end
			-- crina arco-íris descendo pelo pescoço
			local top = neckTop(look, B, 0)
			local nb = V(0, B.h * 0.2, -B.len * 0.28)
			for i, col in ipairs(RAINBOW) do
				local u = (i - 1) / (#RAINBOW - 1)
				local root = top:Lerp(nb, u) + V(0, 0.42, 0.28)
				local piv = wavePivot(b, torso, "CrinaPivo", CF(root) * ANG(0, PI / 2, -0.4 - u * 0.5), V(0.1, 0.08, 0.1), 3.5, i * 0.6)
				b:Chain(piv, "Crina", { V(0, 0, 0), V(0.45, 0.15, 0.25), V(0.9, -0.2, 0.15) }, { 0.2, 0.14 }, col)
			end
			-- topete arco-íris na testa
			if head then
				for i = 1, 3 do
					b:Seg(
						head,
						"Topete",
						V((i - 2) * 0.12 * hs, 0.38 * hs, 0.05 * hs),
						V((i - 2) * 0.3 * hs, 0.15 * hs, -0.35 * hs),
						0.1 * hs,
						0.08 * hs,
						RAINBOW[i * 2 - 1]
					)
				end
			end
			-- cauda de 6 mechas coloridas
			local tail = model:FindFirstChild("TailBase")
			if tail then
				for i, col in ipairs(RAINBOW) do
					local x = (i - 3.5) * 0.09
					local piv = wavePivot(b, tail, "CaudaPivo", CF(x, 0.05, 0.1) * ANG(0, PI / 2, 0.2 + (i - 3.5) * 0.06), V(0, 0.2, 0.15), 3, i * 0.4)
					b:Chain(piv, "CaudaMecha", { V(0, 0, 0), V(0.7, 0.25, 0), V(1.4, -0.3, 0), V(1.9, -0.9, 0) }, { 0.13, 0.11, 0.07 }, col)
				end
			end
		end,
	},
}

------------------------------------------------------------------------ SAMURAI ONI
Species.demon_samurai = {
	Name = "Oni Samurai",
	Rarity = "Mythic",
	Role = "Blades",
	Special = "C_FlyingBlades",
	Stats = { HP = 1.35, Atk = 1.6, Speed = 18 },
	Look = {
		scale = 1.7,
		main = C(52, 22, 30),
		second = C(220, 35, 45),
		belly = C(36, 28, 36),
		eye = C(255, 225, 60),
		body = { len = 3.2, w = 1.6, h = 1.5, chest = 1.2 },
		legs = { len = 1.1, thick = 0.4, claws = GOLD, noToes = true },
		head = {
			size = 1.45,
			snout = 0.75,
			snoutW = 1.15,
			lift = 0.6,
			muzzle = C(205, 30, 40),
			jowls = true,
			fangs = true,
			brows = GOLD,
			toothColor = C(255, 245, 220),
		},
		mood = "evil",
		ears = "pointy",
		earColor = C(40, 18, 25),
		earInner = C(220, 35, 45),
		tail = "whip",
		spikeColor = C(220, 35, 45),
		extras = { helmet = C(28, 24, 30), samurai = C(30, 26, 34), smoke = C(120, 10, 20), eyeGlow = true, aura = C(255, 40, 50) },
		build = function(b, ctx)
			local model, torso, B, look = ctx.Model, ctx.Torso, ctx.Body, ctx.Look
			model:SetAttribute("CAnim", true)
			local red = look.second
			-- chifres de oni saindo do elmo + lua crescente dourada (maedate)
			local head = model:FindFirstChild("Head1")
			if head then
				local hs = look.head.size
				for _, side in ipairs({ -1, 1 }) do
					b:Chain(
						head,
						"ChifreOni",
						{ V(side * 0.25, 0.4, 0.0) * hs, V(side * 0.42, 0.75, 0.1) * hs, V(side * 0.38, 1.05, 0.3) * hs },
						{ 0.1 * hs, 0.06 * hs },
						C(255, 240, 210)
					)
				end
				for k = -3, 3 do
					local a = k * 0.32
					local p = V(math.sin(a) * 0.55, 0.62 + math.cos(a) * 0.45, -0.38) * hs
					b:K(head, "Maedate", V(0.2, 0.12, 0.05) * hs, GOLD, CF(p) * ANG(0, 0, -a), Enum.Material.Foil)
				end
			end
			-- quatro braços demoníacos nas costas, cada um com uma katana
			local arms = {
				{ -1, 0.35, -0.2, 0.9, -0.3 },
				{ 1, 0.35, -0.2, 0.9, -0.3 },
				{ -1, 0.15, 0.2, 0.55, 0.4 },
				{ 1, 0.15, 0.2, 0.55, 0.4 },
			}
			for i, a in ipairs(arms) do
				local side = a[1]
				local cf = CF(side * B.w * 0.35, B.h * a[2], B.len * a[3]) * ANG(a[5], 0, 0)
				local piv = wavePivot(b, torso, "BracoOniPivo", cf, V(0.1, 0.08, 0.1), 1.4, i * 1.3)
				piv:SetAttribute("CBlade", i)
				local sh, el, hand = V(0, 0, 0), V(side * 0.9, a[4], 0.1), V(side * 1.5, a[4] + 0.6, -0.4)
				b:Seg(piv, "BracoOni", sh, el, 0.17, 0.15, C(140, 20, 30))
				b:Seg(piv, "BracoOni", el, hand, 0.14, 0.12, C(140, 20, 30))
				glow(b:Seg(piv, "BracoOniVeia", sh + V(0, 0.08, 0), el + V(0, 0.08, 0), 0.04, 0.04, red))
				b:E(piv, "MaoOni", V(0.32, 0.3, 0.32), C(110, 15, 25), CF(hand))
				-- katana: cabo, tsuba e lâmina apontando para cima/para fora
				local dir = V(side * 0.35, 1, -0.45).Unit
				local hilt = CFrame.lookAt(hand, hand + dir)
				b:K(piv, "KatanaCabo", V(0.1, 0.1, 0.55), C(30, 20, 25), hilt * CF(0, 0, 0.12), Enum.Material.Fabric)
				b:K(piv, "KatanaTsuba", V(0.3, 0.3, 0.05), GOLD, hilt * CF(0, 0, -0.18), Enum.Material.Foil)
				b:K(piv, "KatanaLamina", V(0.05, 0.16, 2.0), C(220, 225, 235), hilt * CF(0, 0, -1.18), METAL)
				glow(b:K(piv, "KatanaFio", V(0.03, 0.04, 1.95), C(255, 60, 60), hilt * CF(0, -0.09, -1.18)))
			end
		end,
	},
}

------------------------------------------------------------------------ MECHA (gigante)
Species.mecha_hound = {
	Name = "Omega Mecha Dog",
	Rarity = "Mythic",
	Role = "Artillery",
	Special = "C_MissileBarrage",
	Stats = { HP = 1.7, Atk = 1.4, Speed = 14 },
	Look = {
		scale = 2.6,
		material = METAL,
		main = C(205, 210, 220),
		second = C(58, 62, 78),
		belly = C(255, 140, 30),
		eye = C(80, 230, 255),
		body = { len = 3.4, w = 2.1, h = 1.75, chest = 1.25 },
		legs = { len = 1.35, thick = 0.52, front = 1.1 },
		head = { size = 1.35, snout = 0.95, lift = 0.5, forward = 0.25 },
		mood = "fierce",
		ears = "cropped",
		earColor = C(58, 62, 78),
		earInner = C(255, 140, 30),
		tail = "antenna",
		extras = { robot = C(80, 230, 255), eyeGlow = true, aura = C(80, 230, 255), tag = false },
		build = function(b, ctx)
			local model, torso, B, look = ctx.Model, ctx.Torso, ctx.Body, ctx.Look
			model:SetAttribute("CAnim", true)
			local dark, orange, cyan = look.second, look.belly, C(80, 230, 255)
			-- casulos de mísseis nos ombros
			for _, side in ipairs({ -1, 1 }) do
				local pod = CF(side * B.w * 0.55, B.h * 0.55, -B.len * 0.2) * ANG(-0.25, 0, 0)
				b:K(torso, "CasuloMissil", V(0.9, 0.7, 1.3), dark, pod, METAL)
				b:K(torso, "CasuloFaixa", V(0.92, 0.12, 1.32), orange, pod * CF(0, 0.2, 0), SMOOTH)
				for r = 0, 1 do
					for c = -1, 1 do
						local m = pod * CF(c * 0.26, -0.1 + r * 0.28, -0.66)
						b:K(torso, "MissilTubo", V(0.22, 0.22, 0.08), C(30, 32, 40), m, METAL)
						b:E(torso, "MissilPonta", V(0.15, 0.15, 0.22), C(230, 50, 40), m * CF(0, 0, -0.06), SMOOTH)
					end
				end
			end
			-- canhão nas costas
			local can = CF(0, B.h * 0.62, B.len * 0.12)
			b:K(torso, "CanhaoBase", V(0.8, 0.45, 0.9), dark, can, METAL)
			b:K(torso, "CanhaoCano", V(0.32, 0.32, 2.4), C(150, 155, 168), can * CF(0, 0.3, -0.9), METAL)
			glow(b:K(torso, "CanhaoBoca", V(0.36, 0.36, 0.1), cyan, can * CF(0, 0.3, -2.1)))
			for k = 0, 2 do
				b:K(torso, "CanhaoAnel", V(0.42, 0.42, 0.12), dark, can * CF(0, 0.3, -0.4 - k * 0.5), METAL)
			end
			-- propulsores atrás
			for _, side in ipairs({ -1, 1 }) do
				local j = CF(side * B.w * 0.3, B.h * 0.15, B.len * 0.48)
				b:K(torso, "Propulsor", V(0.5, 0.5, 0.6), dark, j, METAL)
				glow(b:E(torso, "PropulsorFogo", V(0.36, 0.36, 0.8), cyan, j * CF(0, 0, 0.55))).Transparency = 0.2
			end
			-- reator no peito e faixas de alerta
			glow(b:E(torso, "Reator", V(0.6, 0.6, 0.2), cyan, CF(0, -B.h * 0.02, -B.len * 0.5)))
			b:K(torso, "ReatorMoldura", V(0.85, 0.85, 0.15), dark, CF(0, -B.h * 0.02, -B.len * 0.47), METAL)
			for _, side in ipairs({ -1, 1 }) do
				for k = 0, 3 do
					b:K(
						torso,
						"Alerta",
						V(0.06, 0.2, 0.32),
						k % 2 == 0 and orange or DARK,
						CF(side * B.w * 0.53, -B.h * 0.25, -B.len * 0.15 + k * 0.32) * ANG(0.6, 0, 0),
						SMOOTH
					)
				end
			end
			-- crista em V dourada na cabeça
			local head = model:FindFirstChild("Head1")
			if head then
				local hs = look.head.size
				for _, side in ipairs({ -1, 1 }) do
					b:K(
						head,
						"CristaV",
						V(0.08, 0.7, 0.06) * hs,
						GOLD,
						CF(side * 0.18 * hs, 0.55 * hs, -0.42 * hs) * ANG(0, 0, -side * 0.75),
						Enum.Material.Foil
					)
				end
				b:K(head, "CristaVBase", V(0.16, 0.16, 0.08) * hs, C(230, 50, 40), CF(0, 0.35 * hs, -0.44 * hs), SMOOTH)
			end
		end,
	},
}

------------------------------------------------------------------------ PLANETA
Species.planet_hound = {
	Name = "Planet Dog",
	Rarity = "Mythic",
	Role = "Cosmic",
	Special = "C_MoonFall",
	Stats = { HP = 1.55, Atk = 1.4, Speed = 16 },
	Look = {
		scale = 1.7,
		main = C(55, 125, 215),
		second = C(85, 180, 90),
		belly = C(55, 125, 215),
		eye = C(30, 30, 40),
		body = { len = 2.6, w = 2.6, h = 2.6 },
		legs = { len = 0.55, thick = 0.36, color = C(85, 180, 90), noToes = true },
		head = { size = 1.3, snout = 0.75, lift = -0.35, forward = 0.1, eyeSize = 1.2, cap = C(85, 180, 90), muzzle = C(235, 225, 190) },
		mood = "happy",
		eyes = "cute",
		ears = "floppy",
		earColor = C(60, 140, 70),
		tail = "curl",
		tailColor = C(85, 180, 90),
		extras = { float = 1.3, noBelly = true, stars = true, aura = C(150, 200, 255), tag = false },
		build = function(b, ctx)
			local model, torso, B = ctx.Model, ctx.Torso, ctx.Body
			model:SetAttribute("CAnim", true)
			-- continentes, desertos e calotas polares
			local land = {
				{ 0.8, -0.1, 0.9, C(85, 180, 90) },
				{ -0.9, 0.15, 1.0, C(85, 180, 90) },
				{ 1.9, 0.2, 0.8, C(200, 175, 110) },
				{ -2.0, -0.15, 0.75, C(70, 160, 80) },
				{ 2.6, -0.3, 0.6, C(85, 180, 90) },
				{ -2.7, 0.3, 0.55, C(200, 175, 110) },
				{ 0.3, 0.32, 0.6, C(70, 160, 80) },
			}
			for _, l in ipairs(land) do
				local cf = bodyPoint(B, l[1], l[2], -0.08)
				b:E(torso, "Continente", V(l[3] * 1.3, l[3], 0.3), l[4], cf, SMOOTH)
			end
			b:E(torso, "Calota", V(1.3, 0.35, 1.3), WHITE, CF(0, B.h * 0.47, 0.1), SMOOTH)
			b:E(torso, "Calota", V(1.1, 0.3, 1.1), WHITE, CF(0, -B.h * 0.47, 0.1), SMOOTH)
			for i = 1, 3 do
				local cf = bodyPoint(B, i * 1.9 - 3, -0.2 + i * 0.12, 0.05)
				b:E(torso, "Nuvem", V(1.2, 0.35, 0.15), WHITE, cf, SMOOTH).Transparency = 0.25
			end
			-- anéis de Saturno (giram devagar)
			local rings = spinPivot(b, torso, "Aneis", CF(0, 0, 0) * ANG(0.3, 0, 0.28), V(0, 0.4, 0))
			ring(b, rings, "Anel", CFrame.new(), 2.45, 26, 0.55, 0.06, C(235, 210, 160), SMOOTH)
			ring(b, rings, "Anel", CFrame.new(), 3.05, 30, 0.45, 0.05, C(205, 170, 120), SMOOTH)
			ring(b, rings, "Anel", CFrame.new(), 3.5, 32, 0.25, 0.04, C(250, 235, 200), SMOOTH)
			-- lua em órbita com crateras
			local orbit = spinPivot(b, torso, "Orbita", CF(0, 0.6, 0) * ANG(-0.2, 0, 0.15), V(0, 0.9, 0))
			local moon = CF(4.3, 0, 0)
			b:E(orbit, "Lua", V(0.95, 0.95, 0.95), C(200, 200, 210), moon, Enum.Material.Slate)
			for k = 1, 4 do
				local a = k * 1.6
				local n = V(math.cos(a), math.sin(a * 1.3) * 0.6, math.sin(a)).Unit
				b:E(orbit, "Cratera", V(0.24, 0.24, 0.08), C(150, 150, 160), moon * CFrame.lookAt(n * 0.45, n * 2), SMOOTH)
			end
			-- satélite do lado oposto
			local sat = CF(-3.9, 0.3, 0)
			b:K(orbit, "Satelite", V(0.25, 0.25, 0.35), STEEL, sat, METAL)
			b:K(orbit, "SatelitePainel", V(0.9, 0.04, 0.25), C(40, 70, 160), sat, SMOOTH)
		end,
	},
}

local Order = {
	"hydra_hound",
	"bone_dragon",
	"kraken_hound",
	"chrono_hound",
	"singularity_pup",
	"seraph_hound",
	"crystal_golem",
	"frost_phoenix",
	"thunder_colossus",
	"rainbow_unicorn",
	"demon_samurai",
	"mecha_hound",
	"planet_hound",
}

local Specials = {
	C_HydraFrenzy = {
		Name = "Hydra Frenzy",
		Desc = "All five heads stretch like snakes and bite from five sides. Every bite that lands restores HP.",
	},
	C_BoneCage = {
		Name = "Bone Cage",
		Desc = "Falls apart into a pile of bones, rebuilds under the target and a giant rib cage bursts from the ground and snaps shut on it.",
	},
	C_KrakenGrab = {
		Name = "Kraken Grab",
		Desc = "Giant tentacles burst from the ground, grab the target, lift it up and smash it down. Ends with a blast of ink.",
	},
	C_TimeStop = {
		Name = "Time Stop",
		Desc = "A giant clock appears in the sky and time stops. It strikes the frozen target from every side and everything explodes when time resumes.",
	},
	C_EventHorizon = {
		Name = "Event Horizon",
		Desc = "The pup becomes a black hole: it sucks in the target, grinds it in orbit and spits it far away through a white hole.",
	},
	C_Judgement = {
		Name = "Divine Judgement",
		Desc = "Spreads its six wings, six pillars of light surround the target, sweep to the center and become a holy column. Heals a little.",
	},
	C_CrystalPrison = {
		Name = "Crystal Prison",
		Desc = "Punches the ground and a giant crystal traps the target; the golem leaps and shatters the prison with its body.",
	},
	C_GlacialRebirth = {
		Name = "Glacial Rebirth",
		Desc = "Turns into an invulnerable ice egg and heals; the egg cracks and bursts into a freezing storm of ice feathers.",
	},
	C_ThunderWall = {
		Name = "Thunder Wall",
		Desc = "The cloud on its back zaps it; with every stomp a wall of lightning marches across the ground to the target.",
	},
	C_RainbowBridge = {
		Name = "Rainbow Bridge",
		Desc = "A rainbow forms in the sky, it gallops across it and lands horn-first on the target in a burst of color.",
	},
	C_FlyingBlades = {
		Name = "Oni Blades",
		Desc = "The four katanas fly from its demon arms, spin around the target slicing, then return for a final X slash.",
	},
	C_MissileBarrage = {
		Name = "Missile Barrage",
		Desc = "Opens its pods and fires 12 homing missiles that rise and rain down on the target; ends with a cannon blast.",
	},
	C_MoonFall = {
		Name = "Moonfall",
		Desc = "The moon leaves orbit, grows in the sky and crashes onto the target, leaving a crater; its rings become a shockwave.",
	},
}

return { Species = Species, Order = Order, Specials = Specials }
```
