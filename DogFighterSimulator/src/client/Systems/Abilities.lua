-- 🐾 Barra de habilidades (embaixo, no meio): 1 = Mordida (ou tiro pela boca dos atiradores), 2 = Poder da espécie, 3 = Poder do tipo,
-- Q = Esquiva (impulso no cliente + invencibilidade curta no servidor), 4 = ESPECIAL (Épico para cima, 2026-10: não
-- enche mais batendo — é uma habilidade com recarga um pouco maior).
-- Visual 🎨 CARTOON (2026-10-24, pedido do dono: "não quero 3D, quero cartoon"): botões redondos chapados em 2 tons
-- com o ícone DESENHADO do golpe (UI/Icons: fogo, gelo, raio...), recarga em "pizza" escura que vai abrindo, tecla no
-- canto (PC) e o nome embaixo. Menores que antes (o HUD não pode tampar o jogo).
-- PC: clique ou teclas 1/2/3/Q. Controle: X / Y / B / L1. Celular: botões redondos.
-- Quem decide alvo, dano e recarga é o servidor (remote UseAbility; recargas nos atributos CD1/CD2).
-- A mordida e a esquiva também tocam a animação NA HORA neste cliente (Animator), sem esperar o servidor.
-- 🎯 PC: o golpe vai para onde a SETINHA aponta (o cachorro vira para ela e a direção vai junto no UseAbility).
-- 🐾 1 de quem não atira = combo pata DIREITA → pata ESQUERDA → MORDIDA (toca na hora; o servidor confere).
-- ✨ Poderes (2, 3, 4) saem no ponto da setinha, mesmo sem inimigo (o ponto vai junto no UseAbility). 2026-10: saem NA
-- HORA e o cachorro continua andando (o servidor só segura o corpo nas arrancadas curtas da habilidade).
-- 📱 Celular/controle: o golpe vai para onde o analógico aponta (DogControl.AimDirection).
-- ✈️ Voando: Q = parafuso de avião (DogControl.BarrelRoll) e a mordida não dá o bote para a frente.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local DogData = require(ReplicatedStorage.Shared.DogData)
local UI = script.Parent.Parent:WaitForChild("UI")
local Kit = require(UI:WaitForChild("Kit"))
local Icons = require(UI:WaitForChild("Icons"))
local Net = require(script.Parent.Parent:WaitForChild("Net"))
local Animator = require(script.Parent.Parent:WaitForChild("Animator"))
local DogControl = require(script.Parent:WaitForChild("DogControl"))
local Effects = require(script.Parent.Parent:WaitForChild("Effects"))

local Abilities = {}

-- 🔊 (2026-10-25) som na hora do golpe (mesmo errando; o acerto toca a mordida que vem do servidor)
local function sfx(name: string, where: any, opts: any)
	local module = script.Parent:FindFirstChild("Sfx")
	if module then
		pcall(function()
			require(module).Play(name, where, opts)
		end)
	end
end
local make = Kit.make
local player = Players.LocalPlayer

local INK = Icons.INK
local LUCKY = Enum.Font.LuckiestGuy

local function inkStroke(parent, thickness)
	return make("UIStroke", {
		Color = INK,
		Thickness = thickness or 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	}, parent)
end

-- texto com contorno escuro; maxSize > 0 = encolhe para caber (nomes de golpe compridos)
local function label(parent, text, size, props, maxSize)
	local l = make("TextLabel", {
		BackgroundTransparency = 1,
		Font = LUCKY,
		Text = text,
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = size,
		TextScaled = maxSize ~= nil,
	}, parent)
	for k, v in pairs(props) do
		l[k] = v
	end
	if maxSize then
		make("UITextSizeConstraint", { MaxTextSize = maxSize }, l)
	end
	make("UIStroke", { Color = INK, Thickness = math.max(1.5, size * 0.17), ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }, l)
	return l
end

-- recarga em "pizza": duas metades com degradê de corte girando. set(f): f = parte escura (1 = tudo, 0 = livre)
local function pie(parent)
	local holder = make("Frame", { Name = "Pie", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 5 }, parent)
	local cuts = {}
	for _, sideName in ipairs({ "L", "R" }) do
		local clip = make("Frame", {
			Name = sideName,
			Position = UDim2.fromScale(sideName == "L" and 0 or 0.5, 0),
			Size = UDim2.fromScale(0.5, 1),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			ZIndex = 5,
		}, holder)
		local disc = make("Frame", {
			Position = UDim2.fromScale(sideName == "L" and 0 or -1, 0),
			Size = UDim2.fromScale(2, 1),
			BackgroundColor3 = Color3.fromRGB(15, 10, 30),
			BackgroundTransparency = 0.28,
			BorderSizePixel = 0,
			ZIndex = 5,
		}, clip)
		Kit.Corner(disc, 999)
		cuts[sideName] = make("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.499, 0),
				NumberSequenceKeypoint.new(0.5, 1),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}, disc)
	end
	return function(f)
		f = math.clamp(f, 0, 1)
		holder.Visible = f > 0.002
		-- ângulo já liberado (horário, a partir das 12h): metade direita primeiro, depois a esquerda
		local a = 360 * (1 - f)
		if a <= 180 then
			cuts.R.Rotation = 180 + a
			cuts.L.Rotation = 0
		else
			cuts.R.Rotation = 0
			cuts.L.Rotation = a - 180
		end
	end
end

function Abilities.Start(HUD)
	local touch = Kit.IsTouch()
	-- (2026-10-24: menores) PC botão 56 / nome 10; celular botão 78 / nome 14 (pixels de design)
	local SIZE = touch and 78 or 56
	local GAP = touch and 12 or 10
	local LABEL = touch and 14 or 10
	local BOTTOM = touch and 8 or 10
	local gui, root = Kit.Screen("Abilities", 7)
	local bar = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -BOTTOM), -- embaixo, no meio (pedido do dono)
		Size = UDim2.fromOffset(SIZE * 5 + GAP * 4, SIZE + LABEL + 8),
		BackgroundTransparency = 1,
	}, root)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, GAP),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, bar)

	-- impulso de verdade: o Humanoid freia o AssemblyLinearVelocity no mesmo quadro, então usamos uma
	-- LinearVelocity por um instante (a física do personagem é deste cliente)
	local function burst(root, velocity, duration)
		local att = Instance.new("Attachment")
		att.Name = "BurstAtt"
		att.Parent = root
		local lv = Instance.new("LinearVelocity")
		lv.Name = "Burst"
		lv.Attachment0 = att
		lv.RelativeTo = Enum.ActuatorRelativeTo.World
		lv.MaxForce = 1e7
		lv.VectorVelocity = velocity
		lv.Parent = root
		task.delay(duration, function()
			lv:Destroy()
			att:Destroy()
		end)
	end

	local busy = {}
	local rollSide = 1
	local dashDir: Vector3? = nil -- direção do último dash (vai para o servidor: o dano sai no caminho)
	-- 🐾 combo de perto (mesma conta do servidor): 1 = pata direita, 2 = pata esquerda, 3 = mordida
	local comboStep, comboAt = 0, -10
	local function dodgeImpulse()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		if not (root and hum) or player:GetAttribute("AutoControl") then
			return false
		end
		if (player:GetAttribute("CD4") or 0) > workspace:GetServerTimeNow() then
			return false
		end
		-- ✈️ voando: parafuso de avião para o lado da tecla A/D (sem tecla: alterna os lados)
		if player:GetAttribute("Flying") then
			local typing = UserInputService:GetFocusedTextBox() ~= nil
			if not typing and UserInputService:IsKeyDown(Enum.KeyCode.D) then
				rollSide = 1
			elseif not typing and UserInputService:IsKeyDown(Enum.KeyCode.A) then
				rollSide = -1
			else
				rollSide = -rollSide
			end
			if DogControl.BarrelRoll(rollSide) then
				Animator.PlayDodge(character, root.CFrame.RightVector * rollSide)
				return true
			end
		end
		-- 💨 DASH (2026-10, pedido do dono: "onde estiver o analógico o cachorro vai naquela direção ou até lá"):
		-- na direção do analógico (WASD/controle/celular); parado, para a setinha — e só até ela, se estiver perto
		local dir = Vector3.new(hum.MoveDirection.X, 0, hum.MoveDirection.Z)
		local time = Config.DASH_TIME
		if dir.Magnitude < 0.1 then
			local aimDir = DogControl.AimDirection() or root.CFrame.LookVector
			dir = Vector3.new(aimDir.X, 0, aimDir.Z)
			local point = DogControl.AimPoint()
			if point then
				local dist = Vector3.new(point.X - root.Position.X, 0, point.Z - root.Position.Z).Magnitude
				time = math.clamp(dist / Config.DASH_SPEED, 0.08, Config.DASH_TIME)
			end
		end
		dir = dir.Magnitude > 0.01 and dir.Unit or Vector3.new(0, 0, -1)
		dashDir = dir
		burst(root, dir * Config.DASH_SPEED, time)
		DogControl.FaceDirection(dir, time + 0.1)
		Animator.PlayDodge(character, dir, true)
		return true
	end
	-- 🔓 nível que libera cada botão (2 = Lv.10, 3 = Lv.25, 5 = Supremo Lv.50); nil = sempre liberado
	local UNLOCK_INDEX = { [2] = 1, [3] = 2, [5] = 3 }
	local function lockedLevel(slot)
		local index = UNLOCK_INDEX[slot]
		local character = player.Character
		if not index or not character then
			return nil
		end
		local need = Config.PowerUnlockLevel(index, character:GetAttribute("Rarity"))
		if (character:GetAttribute("DogLevel") or 1) < need then
			return need
		end
		return nil
	end
	local function use(slot)
		if busy[slot] then
			return
		end
		local need = lockedLevel(slot)
		if need then
			HUD.Toast("🔒 This power unlocks at Lv." .. need .. "!", "red")
			return
		end
		dashDir = nil
		if slot == 4 and not dodgeImpulse() then
			return
		end
		if slot == 4 then
			sfx("Whoosh", player.Character, { Volume = 0.45, Pitch = 1.15 })
		end
		-- 🎯 PC: mira na setinha (o cachorro vira para ela agora; o servidor escolhe o alvo naquela direção)
		local aimDir = nil
		if slot ~= 4 and not player:GetAttribute("AutoControl") then
			aimDir = DogControl.AimDirection()
			if aimDir then
				DogControl.FaceAim()
			end
		end
		-- mordida: pequeno bote para a frente (sensação de golpe); tiro pela boca: só abre a boca
		-- (o tiro em si vem do servidor, efeito "MouthShot"). Voando não tem bote (quem empurra é o voo).
		if slot == 1 and (player:GetAttribute("CD1") or 0) <= workspace:GetServerTimeNow() then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and not player:GetAttribute("AutoControl") then
				local look = aimDir or root.CFrame.LookVector
				local flat = Vector3.new(look.X, 0, look.Z)
				if DogData.ShotFor(character:GetAttribute("Species")) then
					Animator.PlayBite(character, 1) -- atirador: só abre a boca
				else
					local now = os.clock()
					comboStep = now - comboAt <= Config.MELEE_COMBO_WINDOW and comboStep % 3 + 1 or 1
					comboAt = now
					Effects.Melee(character, comboStep, 1, true)
					sfx("Whoosh", root, { Volume = comboStep == 3 and 0.4 or 0.26, Pitch = 1.15 + 0.1 * comboStep, Gap = 0.08 })
					if flat.Magnitude > 0.01 and not player:GetAttribute("Flying") then
						burst(root, flat.Unit * (comboStep == 3 and 30 or 14), 0.12)
					end
				end
			end
		end
		busy[slot] = true
		task.spawn(function()
			local ok, message = Net.Invoke("UseAbility", slot, slot == 4 and dashDir or aimDir, slot ~= 1 and slot ~= 4 and DogControl.AimPoint() or nil)
			busy[slot] = nil
			if not ok and type(message) == "string" and message ~= "" then
				HUD.Toast(message, "red")
			end
		end)
	end

	local slots = {}
	-- 2 tons chapados (corte reto, sem degradê): a cor clara em cima, a escura embaixo
	local function paintSlot(slot, iconName)
		local c1, c2 = Icons.Colors(iconName)
		slot.Colors = { c1, c2 }
		slot.Gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, c1),
			ColorSequenceKeypoint.new(0.56, c1),
			ColorSequenceKeypoint.new(0.561, c2),
			ColorSequenceKeypoint.new(1, c2),
		})
		Icons.Set(slot.Icon, iconName)
	end
	local function slotButton(i, key, iconName, name)
		local holder = make("Frame", { Name = "Slot" .. i, LayoutOrder = i, Size = UDim2.fromOffset(SIZE, SIZE + LABEL + 8), BackgroundTransparency = 1 }, bar)
		local pop = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(SIZE / 2, SIZE / 2),
			Size = UDim2.fromOffset(SIZE, SIZE),
			BackgroundTransparency = 1,
		}, holder)
		local popScale = make("UIScale", {}, pop)
		local shadow = make("Frame", {
			Position = UDim2.fromOffset(0, 3),
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = INK,
			BorderSizePixel = 0,
			ZIndex = 1,
		}, pop)
		Kit.Corner(shadow, 999)
		inkStroke(shadow)
		local button = make("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",
			ZIndex = 2,
		}, pop)
		Kit.Corner(button, 999)
		local stroke = inkStroke(button, 2.5)
		local gradient = make("UIGradient", { Rotation = 90 }, button)
		local icon = Icons.Make(button, iconName, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.48),
			Size = UDim2.fromScale(0.7, 0.7),
			ZIndex = 3,
		})
		local setPie = pie(button)
		local cdText = label(button, "", math.floor(SIZE * 0.32), {
			Size = UDim2.fromScale(1, 1),
			ZIndex = 6,
		})
		if not touch then
			local keyChip = make("Frame", {
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, 4, 1, 3),
				Size = UDim2.fromOffset(19, 19),
				BackgroundColor3 = Color3.fromRGB(59, 47, 134),
				BorderSizePixel = 0,
				ZIndex = 7,
			}, button)
			Kit.Corner(keyChip, 6)
			inkStroke(keyChip, 2)
			label(keyChip, key, 10, { Size = UDim2.fromScale(1, 1), ZIndex = 8 })
		end
		local nameLabel = label(holder, name, LABEL, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, SIZE + 5),
			Size = UDim2.fromOffset(SIZE + GAP, LABEL + 2),
		}, LABEL)
		-- 🔓 cadeado: poder ainda não liberado pelo nível do cachorro (Config.POWER_UNLOCK)
		local lock = make("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(20, 16, 34),
			BackgroundTransparency = 0.25,
			BorderSizePixel = 0,
			ZIndex = 6,
			Visible = false,
		}, button)
		Kit.Corner(lock, 999)
		local lockText = Icons.Make(lock, "lock", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.1),
			Size = UDim2.fromScale(0.42, 0.42),
			ZIndex = 7,
		})
		local lockLevel = label(lock, "Lv.10", math.floor(SIZE * 0.24), {
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.fromScale(1, 0.4),
			ZIndex = 7,
			TextColor3 = Color3.fromRGB(255, 214, 90),
		})
		local _ = lockText
		button.MouseButton1Down:Connect(function()
			Kit.Tween(popScale, 0.06, { Scale = 0.9 })
		end)
		button.InputEnded:Connect(function()
			Kit.Tween(popScale, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
		end)
		button.Activated:Connect(function()
			use(i)
		end)
		local slot = {
			Holder = holder,
			Button = button,
			Icon = icon,
			Gradient = gradient,
			Stroke = stroke,
			SetPie = setPie,
			CdText = cdText,
			Label = nameLabel,
			Lock = lock,
			LockLevel = lockLevel,
		}
		slots[i] = slot
		paintSlot(slot, iconName)
		return slot
	end
	slotButton(1, "1", "fang", "ATTACK")
	slotButton(2, "2", "star", "POWER")
	slotButton(3, "3", "bolt", "POWER")
	slotButton(4, "Q", "wind", "DASH")
	slotButton(5, "4", "crown", "SPECIAL") -- 👑 ESPECIAL (Épico para cima): recarga um pouco maior
	slots[4].Holder.LayoutOrder = 6 -- esquiva por último; o Supremo (5) fica entre o 3 e ela
	-- ✈️ dica do voo de avião (PC, só enquanto voa). Antes aqui ficava o "CTRL = free the mouse" da câmera
	-- travada, que saiu (o mouse agora é sempre livre e o cachorro olha para a setinha).
	local flyHint = nil
	if not touch then
		flyHint = label(root, "MOUSE = steer · W/S = speed · SHIFT = boost · C = down · Q = barrel roll · F = land", 10, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -(BOTTOM + SIZE + LABEL + 10)),
			Size = UDim2.fromOffset(520, 16),
			Font = Enum.Font.FredokaOne,
			TextColor3 = Color3.fromRGB(201, 193, 230),
			Visible = false,
		})
	end

	local lastSpecies = nil
	local function refreshDog()
		local character = player.Character
		local isDog = character ~= nil and character:GetAttribute("Kind") == "player"
		gui.Enabled = isDog
		local speciesId = isDog and character:GetAttribute("Species") or nil
		if speciesId == lastSpecies then
			return
		end
		lastSpecies = speciesId
		local species = speciesId and DogData.Species[speciesId]
		-- 1 = ATTACK (pata direita, pata esquerda, mordida) ou o tiro pela boca dos atiradores (vai bem longe)
		local shotName, shot = DogData.ShotFor(speciesId)
		paintSlot(slots[1], shotName and Icons.ForShot(shotName) or "fang")
		slots[1].Label.Text = shot and string.upper(shot.Name) or "ATTACK"
		local pw = species and DogData.PowersFor(speciesId)
		local sp = pw and DogData.Specials[pw[1]]
		paintSlot(slots[2], Icons.ForPower(pw and pw[1], sp))
		slots[2].Label.Text = sp and string.upper(sp.Name) or "POWER"
		-- 👑 Especial: a partir do Épico (2026-10); o botão mostra o nome do Especial do cachorro
		slots[5].Holder.Visible = species ~= nil and Config.HasSupreme(species.Rarity)
		local sup = pw and pw[3] and DogData.Specials[pw[3]]
		slots[5].Label.Text = sup and string.upper((sup.Name:gsub("^SUPREME%s+", ""))) or "SPECIAL"
		local third = speciesId and DogData.ThirdPower(speciesId)
		local sp3 = third and DogData.Specials[third]
		paintSlot(slots[3], Icons.ForPower(third, sp3))
		slots[3].Label.Text = string.upper(sp3 and sp3.Name or (third and third:gsub("(%l)(%u)", "%1 %2") or "POWER"))
	end

	RunService.Heartbeat:Connect(function()
		refreshDog()
		if not gui.Enabled then
			return
		end
		if flyHint then
			flyHint.Visible = player:GetAttribute("Flying") == true
		end
		local now = workspace:GetServerTimeNow()
		local auto = player:GetAttribute("AutoControl") == true
		-- 🔓 cadeados (nível do cachorro)
		for slotIndex in pairs(UNLOCK_INDEX) do
			local s = slots[slotIndex]
			local need = lockedLevel(slotIndex)
			s.Lock.Visible = need ~= nil
			if need then
				s.LockLevel.Text = "Lv." .. need
			end
		end
		for i = 1, 5 do
			local s = slots[i]
			local endsAt = player:GetAttribute("CD" .. i) or 0
			local left = endsAt - now
			-- duração total = o que faltava quando a recarga começou
			if s.EndsAt ~= endsAt then
				s.EndsAt = endsAt
				s.Total = math.max(0.3, left)
			end
			local total = s.Total or 1
			if left > 0 then
				s.SetPie(left / total)
				s.CdText.Text = left >= 1 and (tostring(math.ceil(left)) .. "s") or ""
			else
				s.SetPie(auto and 1 or 0)
				s.CdText.Text = ""
			end
		end
	end)

	-- a barra de itens do Roblox usa as teclas 1–9 (e marca o aperto como "processado"): o jogo não usa
	-- ferramentas, então ela fica desligada e as teclas valem mesmo "processadas" (menos digitando no chat)
	task.spawn(function()
		for _ = 1, 10 do
			if pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, false) then
				break
			end
			task.wait(1)
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not gui.Enabled or UserInputService:GetFocusedTextBox() then
			return
		end
		if processed and input.UserInputType ~= Enum.UserInputType.Keyboard and input.UserInputType ~= Enum.UserInputType.Gamepad1 then
			return
		end
		local k = input.KeyCode
		if k == Enum.KeyCode.One or k == Enum.KeyCode.ButtonX then
			use(1)
		elseif k == Enum.KeyCode.Two or k == Enum.KeyCode.ButtonY then
			use(2)
		elseif k == Enum.KeyCode.Three or k == Enum.KeyCode.ButtonB then
			use(3)
		elseif k == Enum.KeyCode.Q or k == Enum.KeyCode.ButtonL1 then
			use(4)
		elseif k == Enum.KeyCode.Four or k == Enum.KeyCode.ButtonR2 then
			use(5)
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 and not touch then
			use(1)
		end
	end)
end

return Abilities
