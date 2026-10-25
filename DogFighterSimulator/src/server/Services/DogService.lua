-- O cachorro equipado de cada jogador: vive na casinha (come sozinho nas tigelas), anda até a Arena
-- quando o jogador desafia um cachorro (clique) ou liga PvP/Caça, volta para casa, desmaia e renasce.
-- Nas ilhas os selvagens atacam quem chega perto (CombatService) e o jogador bate em quem quiser (UseAbility:
-- patas+mordida ou tiro longe, poderes soltos na setinha). Também cuida de escolher o
-- primeiro cachorro, equipar, favoritar, renomear, libertar e das recompensas de luta (Cash + XP).
--
-- Nocaute (Arena, PvP, Boss Tower, caiu no vazio): o duelo acaba, o modo da Arena desliga e o cachorro SEMPRE
-- renasce na casinha depois de Config.KO_RESPAWN s com Config.KO_RESPAWN_HP da vida. Enquanto não estiver com a
-- vida cheia o Model tem o atributo Recovering = true: cada refeição na tigela recupera Config.RECOVER_PER_MEAL.
-- Ele só volta para a Arena quando o jogador escolher outro alvo (ou ligar o PvP).
-- Um watchdog (a cada WATCHDOG s) recria o cachorro de quem está carregado e ficou sem cachorro vivo.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Config = require(ReplicatedStorage.Shared.Config)
local DogData = require(ReplicatedStorage.Shared.DogData)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Islands = require(ReplicatedStorage.Shared.Islands)
local Village = require(ReplicatedStorage.Shared.Village)
local Variants = require(ReplicatedStorage.Shared.Variants)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local Fighters = require(script.Parent.Fighters)
local CombatService = require(script.Parent.CombatService)
local ZoneGeo = require(script.Parent.ZoneGeo)
local CloneService = require(script.Parent.CloneService)

local DogService = {}
-- definida mais abaixo (boneco do jogador na frente da casinha); declarada aqui para o Spawn
DogService.ParkAvatar = function(_player, avatar)
	avatar:Destroy()
end

local remotes
local S = {} -- [player] = { Fighter, State, Mode, Gen, Pending, Recover = { Uid, Pct }, LoadedAt }
local starting = {} -- [player] = true enquanto ChooseStarter roda (o filtro de texto faz yield)
local pvpWins = {} -- [winner] = { [userIdDoPerdedor] = { os.clock(), ... } } (anti-farm de PvP)

local WATCHDOG = 5 -- s entre verificações de "jogador sem cachorro"
local KO_REMOVE = 1.6 -- s que o corpo desmaiado fica no chão antes de sumir

-- Multiplicadores de gamepass (carregado só quando usado; sem o serviço tudo é 1)
local monetization
local function passMult(player, fn)
	if monetization == nil then
		local ok, m = pcall(require, script.Parent.MonetizationService)
		monetization = ok and m or false
	end
	if not (monetization and type(monetization[fn]) == "function") then
		return 1
	end
	local ok, v = pcall(monetization[fn], player)
	return (ok and type(v) == "number") and v or 1
end
local function mults(player)
	return passMult(player, "CashMult"), passMult(player, "XPMult")
end
DogService.Mults = mults

local function state(player)
	local s = S[player]
	if not s then
		s = { State = "none", Mode = "off", Gen = 0 }
		-- jogador que já saiu: devolve um estado descartável (não vaza memória em S)
		if player.Parent then
			S[player] = s
		end
	end
	return s
end

function DogService.GetFighter(player)
	local s = S[player]
	return s and s.Fighter
end

function DogService.GetState(player)
	return state(player)
end

-- 💨 comprou o Speedy Paws agora: o cachorro em campo já corre mais (sem renascer)
function DogService.RefreshSpeed(player)
	local f = DogService.GetFighter(player)
	if not (f and Fighters.Alive(f)) then
		return
	end
	f.Stats.Speed = Config.Stats(f.Species, f.Level).Speed * Config.PLAYER_SPEED_MULT * passMult(player, "SpeedMult")
	f.Model:SetAttribute("BaseSpeed", f.Stats.Speed)
	f.Humanoid.WalkSpeed = f.Stats.Speed * (f.SpeedMult or 1)
end

---------------------------------------------------------------- movimento
-- Anda até um ponto; devolve false se a rotina foi cancelada
local function headPos(f)
	return f.Root.Position + Vector3.new(0, f.Root.Size.Y + 1, 0)
end

---------------------------------------------------------------- recuperação (depois do nocaute)
local function setRecovering(f, value)
	f.Recovering = value or nil
	if f.Model.Parent then
		f.Model:SetAttribute("Recovering", value or nil)
	end
end

-- Vida cheia: acabou a recuperação
local function finishRecovery(player, f, silent)
	local s = state(player)
	if s.Recover and s.Recover.Uid == f.Uid then
		s.Recover = nil
	end
	if f.Recovering then
		setRecovering(f, false)
		if not silent and player.Parent then
			remotes.Notify:FireClient(player, "💪 " .. f.DisplayName .. " is back to full HP!", "gold")
		end
	end
end

-- Cura uma fração da vida máxima (refeição durante a recuperação)
local function heal(player, f, fraction)
	if not Fighters.Alive(f) then
		return
	end
	local hum = f.Humanoid
	hum.Health = math.min(hum.MaxHealth, hum.Health + hum.MaxHealth * fraction)
	if hum.Health >= hum.MaxHealth - 0.5 then
		finishRecovery(player, f)
	end
end

local function setState(player, newState)
	local s = state(player)
	s.Gen += 1
	s.State = newState
	s.Training = false
	player:SetAttribute("DogState", newState)
	player:SetAttribute("Training", false)
	return s.Gen
end

---------------------------------------------------------------- controle (o jogador É o cachorro)
-- auto = true: o servidor controla (ida/volta da Arena, luta automática, torre do boss) e o cliente
-- desliga os controles (atributo AutoControl). auto = false: o jogador anda com o cachorro.
local function setControl(player, f, auto)
	if not (f and f.Root and f.Root.Parent) then
		return
	end
	pcall(function()
		if auto then
			f.Root:SetNetworkOwner(nil)
		else
			f.Root:SetNetworkOwner(player)
		end
	end)
	if auto then
		f.Model:SetAttribute("LookAt", nil) -- servidor no comando: o olhar volta a ser automático
	end
	player:SetAttribute("AutoControl", auto)
end
DogService.SetControl = setControl

-- ⚡ habilidade do jogador (SkillKit, mira): o servidor só segura o corpo durante os movimentos curtos dela. Contador
-- (f.Grabs): 2 habilidades ao mesmo tempo só devolvem o corpo quando a última termina de se mexer.
local function castControl(player, f)
	if f.CastControl then
		return
	end
	f.CastControl = function(delta)
		local before = f.Grabs or 0
		local after = math.max(0, before + delta)
		f.Grabs = after
		if before == 0 and after > 0 then
			setControl(player, f, true)
		elseif before > 0 and after == 0 then
			local st = S[player]
			if st and st.Fighter == f and Fighters.Alive(f) then
				setControl(player, f, false)
			end
		end
	end
end

-- 🪽 Voo (só cachorros com asas/voadores): o servidor só liga o estado (atributo Flying no modelo e
-- no jogador); quem voa de verdade é o cliente (DogControl: LinearVelocity, sobe/desce, para onde
-- a câmera olha) e o Animator mostra a pose "Fly" batendo as asas.
local function setFlying(player, f, on)
	local model = f.Model
	if not (model:GetAttribute("Wings") and Fighters.Alive(f)) then
		return
	end
	f.Humanoid.HipHeight = model:GetAttribute("GroundHip") or f.HipHeight
	model:SetAttribute("Float", false)
	model:SetAttribute("Flying", on or nil)
	player:SetAttribute("Flying", on)
	if on then
		Fighters.Fx("Shockwave", { Position = f.Root.Position - Vector3.new(0, f.Humanoid.HipHeight, 0), Radius = 7, Color = Color3.fromRGB(235, 245, 255) })
	end
end
DogService.SetFlying = setFlying

---------------------------------------------------------------- rotinas
local homeRoutine

-- Uma batida no estande: XP (com gamepass), efeito no boneco e cura se estiver "Recuperando".
-- fraction = parte do XP de uma batida (1 = automática, Config.TRAIN_CLICK_XP = botão TRAIN)
local function trainHit(player, f, fraction)
	local stand = PlotService.GetStand(player)
	if not stand then
		return
	end
	local _, xpMult = mults(player)
	local xp = math.max(1, math.floor(stand.XP * fraction * xpMult + 0.5))
	Fighters.Melee(f) -- treina o combo: pata direita, pata esquerda, mordida
	Fighters.Fx("Hit", { Model = stand.Model })
	-- batidas do botão TRAIN não contam na missão de batidas (senão autoclicker termina a missão)
	DataService.GiveXP(player, xp, fraction >= 1 and "food" or "train")
	Fighters.Fx("XP", { Position = headPos(f), Amount = xp })
	if f.Recovering then
		heal(player, f, Config.RECOVER_PER_HIT * fraction)
	end
end

-- 🏃 Gamepass "Fast Training" (chave FastEggs): batidas mais rápidas
local function trainSpeed(player)
	if monetization == nil then
		mults(player)
	end
	if monetization and type(monetization.TrainSpeedMult) == "function" then
		local ok, v = pcall(monetization.TrainSpeedMult, player)
		if ok and type(v) == "number" and v > 0 then
			return v
		end
	end
	return 1
end

-- O JOGADOR anda com o cachorro por todo lugar. Esta rotina só observa onde ele está:
--   • perto do 🪵 estande da casinha: treina sozinho (1 batida a cada TRAIN_HIT_TIME s; 🥊 TRAIN dá extras)
--   • dentro da Arena: zona "arena" (pode morder/usar poder nos cachorros de lá — habilidades 1 e 2)
--   • saiu da Arena: a luta acaba.
local TRAIN_RANGE = 8
homeRoutine = function(player)
	local gen = setState(player, "home")
	local s = state(player)
	local f = s.Fighter
	if not f then
		return
	end
	f.Zone = "home"
	f.Controlled = true
	f.Mode = s.Mode
	f.Target = nil
	s.InPvP = false
	-- em casa ele descansa: volta com a vida cheia (menos depois de um nocaute: aí recupera treinando)
	if Fighters.Alive(f) and not f.Recovering then
		f.Humanoid.Health = f.Humanoid.MaxHealth
	end
	Fighters.RefreshLabel(f)
	setControl(player, f, false)
	task.spawn(function()
		while s.Gen == gen and Fighters.Alive(f) do
			-- 🏝️ área de luta: entra/sai andando (ilha de raridade, Reino das Nuvens ou chão do Coliseu)
			local island = Islands.At(f.Root.Position, 20)
			if not island and Layout.InArena(f.Root.Position) then
				island = "colosseum"
			end
			-- 🛡️ barreira invisível do PvP: quem estava no PvP do Coliseu não sai VOANDO (o cliente já segura — DogControl;
			-- aqui é a garantia se escapou no atraso da rede): volta para dentro. Andando pelos portões pode sair.
			local nearArena = (f.Root.Position - Layout.ARENA_CENTER).Magnitude < Layout.ARENA_RADIUS + Layout.ARENA_CEILING
			if s.InPvP and nearArena and island ~= "colosseum" and Fighters.ColosseumPvP() and player:GetAttribute("Flying") then
				local back = Layout.ArenaClamp(f.Root.Position, 4)
				f.Model:PivotTo(CFrame.new(back) * f.Root.CFrame.Rotation)
				f.Root.AssemblyLinearVelocity = Vector3.zero
				island = "colosseum"
			end
			local inArena = island ~= nil
			local zone = inArena and "arena" or "home"
			if f.Zone ~= zone or f.Island ~= island then
				if zone == "home" or f.Island ~= island then
					Fighters.EndDuel(f)
					f.Target = nil
				end
				f.Zone = zone
				f.Island = island
				s.State = zone
				player:SetAttribute("DogState", zone)
			end
			-- ⚔️ PvP automático (2026-10, pedido do dono): liga ao pisar no chão do Coliseu (com o 🌍 Super Boss dormindo)
			-- e desliga ao sair. O "⚔️" aparece no nome (Fighters.RefreshLabel) e o atributo ArenaMode vai para as telas
			local mode = (island == "colosseum" and Fighters.ColosseumPvP()) and "pvp" or "pve"
			if f.Mode ~= mode then
				local was = f.Mode
				f.Mode = mode
				s.Mode = mode
				player:SetAttribute("ArenaMode", mode)
				Fighters.RefreshLabel(f)
				if mode == "pvp" then
					remotes.Notify:FireClient(player, "⚔️ COLOSSEUM PvP is ON! Everyone vs everyone — and no flying out!", "red")
				elseif was == "pvp" and island ~= "colosseum" then
					remotes.Notify:FireClient(player, "🕊️ You left the PvP zone.", "green")
				end
			end
			s.InPvP = mode == "pvp"
			-- 💚 sem casinha (Config.HOUSES = false): a vida volta sozinha fora de briga
			local hum = f.Humanoid
			if hum.Health < hum.MaxHealth and not f.Duel and os.clock() - (f.LastHurtAt or 0) > Config.REGEN_DELAY then
				heal(player, f, (inArena and Config.REGEN_FIELD or Config.REGEN_SAFE) * 0.3)
			end
			local stand = not inArena and PlotService.GetStand(player)
			local near = stand and Fighters.FlatDistance(stand.Position, f.Root.Position) <= TRAIN_RANGE or false
			if near ~= s.Training then
				s.Training = near
				player:SetAttribute("Training", near)
			end
			if near then
				task.wait(Config.TRAIN_HIT_TIME / trainSpeed(player))
				if s.Gen ~= gen or not Fighters.Alive(f) then
					return
				end
				if s.Training then
					trainHit(player, f, 1)
				end
			else
				task.wait(0.3)
			end
		end
	end)
end

---------------------------------------------------------------- spawn
-- 🏝️ (2026-10: sem casinha) onde o cachorro nasce/renasce: na entrada da ilha onde o jogador estava (perto do
-- NPC das missões), na Praça dos Portais (ilha principal/Coliseu) ou — quem acabou de entrar ou está na vila — na
-- praça da 🏡 Pawville (ilha de entrada). Com Config.HOUSES ligado volta a ser a casinha.
-- 🏟️ praça do spawn da ilha principal, virado para o Coliseu (o meio da ilha)
local function plazaCFrame()
	local pos = Layout.SPAWN_PLAZA
	local ground = ZoneGeo.Ground(pos + Vector3.new(0, 4, 0), pos.Y + 320, 700) or pos
	local flat = Vector3.new(-ground.X, 0, -ground.Z)
	return CFrame.lookAt(ground, ground + (flat.Magnitude > 1 and flat.Unit or Vector3.new(0, 0, -1)))
end
DogService.PlazaCFrame = plazaCFrame

-- 🏡 pracinha do spawn da Pawville, olhando para o portão do canil
local function villageCFrame()
	local sp = Village.SPAWN
	local cf = Village.LocalCF(sp.X, Village.GROUND_Y, sp.Z, sp.Ry)
	local ground = ZoneGeo.Ground(cf.Position + Vector3.new(0, 4, 0), cf.Position.Y + 60, 120)
	if ground and ground.Y > cf.Position.Y - 3 then
		return CFrame.new(ground) * cf.Rotation
	end
	return cf
end
DogService.VillageCFrame = villageCFrame

local function homeCFrame(player)
	local plotCf = PlotService.CFrame(player)
	if plotCf then
		return plotCf * Layout.PLOT.DogSpawn
	end
	local island = player:GetAttribute("Island")
	if not ((island and Islands.List[island]) or island == "main" or island == "colosseum") then
		return villageCFrame()
	end
	local pos = (island and Islands.List[island]) and Islands.ArrivalPoint(island) or Layout.SPAWN_PLAZA
	local ground = ZoneGeo.Ground(pos + Vector3.new(0, 4, 0), pos.Y + 320, 700) or pos
	local face = Vector3.new(0, 0, -1)
	if not (island and Islands.List[island]) then
		-- na praça: virado para o Coliseu (o meio da ilha)
		local flat = Vector3.new(-ground.X, 0, -ground.Z)
		face = flat.Magnitude > 1 and flat.Unit or face
	end
	return CFrame.lookAt(ground, ground + face)
end
DogService.HomeCFrame = homeCFrame

local function despawn(player)
	local s = state(player)
	s.Gen += 1
	if s.Fighter then
		Fighters.Remove(s.Fighter)
		s.Fighter = nil
	end
end

function DogService.Spawn(player, at, keepPlace, trainerOnly)
	if not player.Parent then
		return nil
	end
	-- era a pessoa (Z): o cachorro aparece onde ela está
	if not at and player:GetAttribute("HumanMode") then
		local avatar = player.Character
		local aroot = avatar and avatar:FindFirstChild("HumanoidRootPart")
		if aroot then
			at = CFrame.new(aroot.Position - Vector3.new(0, 3, 0)) * aroot.CFrame.Rotation
		end
	end
	-- trocar de cachorro: o novo aparece onde o antigo estava
	local old = state(player).Fighter
	if not at and keepPlace and Fighters.Alive(old) then
		at = CFrame.new(old.Root.Position - Vector3.new(0, old.HipHeight + old.Root.Size.Y / 2, 0)) * old.Root.CFrame.Rotation
	end
	despawn(player)
	local data = DataService.Get(player)
	local dog = data and data.Equipped and data.Dogs[data.Equipped]
	if not dog then
		return nil
	end
	local s = state(player)
	local cf = at or homeCFrame(player)
	local f = Fighters.Spawn({
		SpeciesId = dog.Species,
		Level = dog.Level,
		Kind = "player",
		SpeedBonus = passMult(player, "SpeedMult"), -- 💨 passe Speedy Paws (+ acessórios de velocidade)
		Owner = player,
		DisplayName = dog.Name,
		CFrame = cf,
		Zone = "home",
		Variant = Variants.IsSpecial(dog) and { Shiny = dog.Shiny, Tier = dog.Tier } or nil, -- ✨🥇🌈
		Accessories = type(data.Acc) == "table" and data.Acc.On or nil, -- 🎩 todo mundo vê
	})
	f.Uid = dog.Id
	f.Mode = s.Mode
	Fighters.RefreshLabel(f)
	f.Controlled = true
	s.Fighter = f
	s.Pending = nil
	-- recuperando de um nocaute: renasce/troca de lugar com a mesma vida baixa (não vira cura grátis)
	local recover = s.Recover
	if recover and recover.Uid == dog.Id then
		f.Humanoid.Health = math.max(1, math.floor(f.Humanoid.MaxHealth * math.clamp(recover.Pct, 0.01, 1)))
		setRecovering(f, true)
	end
	-- 💚 lembra quando apanhou (a vida só volta sozinha depois de Config.REGEN_DELAY s sem apanhar)
	local lastHP = f.Humanoid.Health
	f.Humanoid.HealthChanged:Connect(function(hp)
		if hp < lastHP - 0.5 then
			f.LastHurtAt = os.clock()
		end
		lastHP = hp
	end)
	f.Humanoid.HealthChanged:Connect(function(hp)
		if not f.Recovering or f.Dead or f.Removed then
			return
		end
		local pct = hp / math.max(1, f.Humanoid.MaxHealth)
		if s.Recover and s.Recover.Uid == f.Uid and hp > 0 then
			s.Recover.Pct = pct
		end
		-- recuperou de outro jeito (descanso na Arena, fim da luta do boss): acaba a recuperação
		if pct >= 0.999 then
			finishRecovery(player, f)
		end
	end)
	player:SetAttribute("DogModel", f.Model.Name)
	if trainerOnly then
		-- 🧍 jogador é a pessoa: este cachorro NÃO é o personagem, anda sozinho (treina no estande)
		f.Model:SetAttribute("BaseSpeed", f.Stats.Speed)
		setControl(player, f, true)
		player:SetAttribute("AutoControl", false)
		return f
	end
	player:SetAttribute("HumanMode", nil) -- virou cachorro de novo (Z ou escolheu um cachorro no DOGS)
	-- 🐶 o cachorro é o personagem do jogador (o avatar some). Começa no controle do servidor;
	-- homeRoutine passa para o jogador.
	f.Model:SetAttribute("BaseSpeed", f.Stats.Speed)
	setFlying(player, f, false) -- começa no chão
	local previous = player.Character
	player.Character = f.Model
	-- o Roblox pode apagar o personagem antigo na troca: o boneco da casinha é uma CÓPIA nova do avatar
	if previous and previous ~= f.Model and previous.Parent and not Fighters.List[previous] then
		previous:Destroy()
	end
	task.spawn(DogService.ParkAvatar, player)
	setControl(player, f, true)
	return f
end

local function respawnAndResume(player, keepPlace)
	if not player.Parent then
		return
	end
	if player:GetAttribute("InTower") then
		-- o BossService decide onde renascer na torre
		DogService.OnTowerRespawn(player)
		return
	end
	local f = DogService.Spawn(player, nil, keepPlace)
	if f then
		-- (2026-10-25, o dono: "quando eu troco de cachorro quando já sou um cachorro fica travado e não consigo mexer")
		-- o cachorro novo nasce no controle do servidor e só a rotina devolve o controle ao jogador. Antes, trocando
		-- numa ilha (Mode "pve"), ia para uma rotina da Arena que não fazia nada (State já era "arena"): ficava preso.
		-- A rotina livre é uma só: sempre recomeça ela para o cachorro novo.
		homeRoutine(player)
	end
end
DogService.Respawn = respawnAndResume

function DogService.OnTowerRespawn(_player)
	-- substituído pelo BossService: recoloca o cachorro na torre
end

function DogService.OnTowerKO(player)
	-- substituído pelo BossService: tira o jogador da torre (o cachorro desmaiado volta para casa)
	player:SetAttribute("InTower", nil)
end

---------------------------------------------------------------- nocaute / renascimento
-- Renasce na casinha depois do nocaute. Se falhar (terreno/dados ainda não prontos, erro ao montar o modelo),
-- libera o pendente e o watchdog tenta de novo em alguns segundos.
local function koRespawn(player, token)
	local s = S[player]
	if not (s and s.Pending == token and player.Parent) then
		return
	end
	if player:GetAttribute("InTower") then
		local ok, err = pcall(DogService.OnTowerKO, player)
		if not ok then
			warn("[DogService] OnTowerKO", err)
			player:SetAttribute("InTower", nil)
		end
	end
	local ok, f = pcall(DogService.Spawn, player)
	if ok and f then
		homeRoutine(player)
		remotes.Notify:FireClient(player, "🩹 " .. f.DisplayName .. " woke up! Stay out of fights for a moment to recover HP.", "gold")
	else
		if not ok then
			warn("[DogService] falha ao renascer o cachorro de", player.Name, f)
		end
		if s.Pending == token then
			s.Pending = nil -- o watchdog tenta de novo
		end
	end
end

-- O cachorro do jogador desmaiou (ou sumiu): encerra tudo e agenda o renascimento em casa
local function knockout(player, victim)
	local s = state(player)
	s.Gen += 1
	s.State = "ko"
	player:SetAttribute("DogState", "ko")
	s.Mode = "off"
	s.InPvP = false
	player:SetAttribute("ArenaMode", "off")
	s.Recover = { Uid = victim.Uid, Pct = Config.KO_RESPAWN_HP }
	local token = {}
	s.Pending = token
	pcall(Fighters.EndDuel, victim)
	task.delay(KO_REMOVE, function()
		if s.Fighter == victim then
			s.Fighter = nil
		end
		if not victim.Removed then
			pcall(Fighters.Remove, victim)
		end
	end)
	-- 💖 passe Quick Revive: volta mais cedo (o HUD conta pelo RespawnAt)
	local backIn = Config.KO_RESPAWN * passMult(player, "ReviveMult")
	player:SetAttribute("RespawnAt", workspace:GetServerTimeNow() + backIn)
	task.delay(backIn, koRespawn, player, token)
	if player.Parent then
		remotes.Notify:FireClient(player, "💫 " .. victim.DisplayName .. " fainted! Back in " .. math.ceil(backIn) .. "s.", "red")
	end
end

-- Watchdog: jogador carregado (Started) sem cachorro vivo e sem renascimento pendente ganha o cachorro em casa
local function watchdog(player)
	local data = DataService.Get(player)
	if not (data and data.Started and data.Equipped and player.Parent) or starting[player] then
		return
	end
	local s = state(player)
	if not s.LoadedAt then
		s.LoadedAt = os.clock()
	end
	if s.Pending or os.clock() - s.LoadedAt < 4 or player:GetAttribute("HumanMode") then
		return
	end
	local f = s.Fighter
	if Fighters.Alive(f) then
		s.Suspect = nil
		return
	end
	-- só age se o problema continuar na verificação seguinte (o evento Died pode estar a caminho)
	local key = f or "none"
	if s.Suspect ~= key then
		s.Suspect = key
		return
	end
	s.Suspect = nil
	if f and not f.Removed then
		-- morreu sem passar pelo fluxo de nocaute (ex.: vida zerada sem o evento Died)
		warn("[DogService] watchdog: cachorro de", player.Name, "sem vida e sem renascimento — nocaute forçado")
		f.Dead = true
		Fighters.List[f.Model] = nil
		knockout(player, f)
		return
	end
	s.Fighter = nil
	if player:GetAttribute("InTower") then
		DogService.OnTowerRespawn(player)
		if Fighters.Alive(s.Fighter) then
			return
		end
		pcall(DogService.OnTowerKO, player)
	end
	warn("[DogService] watchdog: recriando o cachorro de", player.Name, "(estado " .. tostring(s.State) .. ")")
	if DogService.Spawn(player) then
		homeRoutine(player)
	end
end

---------------------------------------------------------------- recompensas
-- Cash + XP para o dono do vencedor (já com os multiplicadores de gamepass) e o aviso "+$X +Y XP"
local function payWin(player, killer, victim, cash, xp, source)
	local cashMult, xpMult = mults(player)
	cash = cash > 0 and math.max(1, math.floor(cash * cashMult)) or 0
	xp = math.max(1, math.floor(xp * xpMult))
	if cash > 0 then
		DataService.AddCash(player, cash, source)
	end
	-- XP vai para o cachorro equipado: só se o vencedor ainda é ele
	local data = DataService.Get(player)
	local gaveXP = data and data.Equipped == killer.Uid
	if gaveXP then
		DataService.GiveXP(player, xp, source)
	end
	local at = victim.Root.Position + Vector3.new(0, 3, 0)
	if cash > 0 then
		Fighters.Fx("Cash", { Position = at, Amount = cash, Player = player.UserId })
	end
	if gaveXP and Fighters.Alive(killer) then
		Fighters.Fx("XP", { Position = headPos(killer), Amount = xp })
	end
	return cash, gaveXP and xp or 0
end

local function onKilled(victim, killer)
	-- dono do cachorro derrotado: nocaute e renascimento em casa
	if victim.Kind == "player" and victim.Owner then
		local owner = victim.Owner
		local s = S[owner]
		if s and s.Fighter == victim then
			knockout(owner, victim)
		end
	end

	if not (killer and killer.Kind == "player" and killer.Owner and killer.Owner.Parent) then
		return
	end
	local player = killer.Owner
	local data = DataService.Get(player)
	if not data then
		return
	end
	if victim.Kind == "npc" then
		-- 💵 (2026-10, pedido do dono, "tipo Blox Fruits"): o DINHEIRO vem das MISSÕES do NPC da ilha
		-- (QuestService). Selvagem sozinho não paga Cash e dá só Config.WILD_XP_MULT do XP de antes.
		local _, baseXP = Config.KillReward(victim.Level, victim.Stats.Power, killer.Level)
		local _, xp = payWin(player, killer, victim, 0, baseXP * Config.WILD_XP_MULT, "npc")
		data.Kills += 1
		DataService.MarkDirty(player)
		local quest = data.Quest
		local hint = (quest and quest.Island == (victim.Def and victim.Def.Island)) and "" or "  (take a 📜 mission for 💵)"
		remotes.Notify:FireClient(
			player,
			string.format("🏆 %s beat %s! +%s XP%s", killer.DisplayName, victim.DisplayName, Config.Format(xp), hint),
			"gold"
		)
	elseif victim.Kind == "player" and victim.Owner and victim.Owner ~= player then
		-- anti-farm: vencer o mesmo jogador de novo em pouco tempo paga cada vez menos (contas alt)
		local now = os.clock()
		local byLoser = pvpWins[player] or {}
		pvpWins[player] = byLoser
		local recent = {}
		for _, t in ipairs(byLoser[victim.Owner.UserId] or {}) do
			if now - t < Config.PVP_REPEAT_WINDOW then
				table.insert(recent, t)
			end
		end
		local repeats = #recent
		table.insert(recent, now)
		byLoser[victim.Owner.UserId] = recent
		local mult = 0.5 ^ repeats
		local baseCash, baseXP = Config.KillReward(victim.Level, victim.Stats.Power, killer.Level)
		local cash, xp = payWin(player, killer, victim, baseCash * Config.PVP_CASH_MULT * mult, baseXP * Config.PVP_XP_MULT * mult, "pvp")
		local rating = repeats < 2 and Config.RATING_WIN or 0
		data.Kills += 1
		data.Rating += rating
		data.Streak += 1
		data.BestStreak = math.max(data.BestStreak, data.Streak)
		remotes.Notify:FireClient(
			player,
			string.format(
				"🏆 You beat %s! +$%s +%s XP  +%d Rating  🔥 %d win streak",
				victim.DisplayName,
				Config.Format(cash),
				Config.Format(xp),
				rating,
				data.Streak
			) .. (repeats > 0 and "  (same opponent: reduced reward)" or ""),
			"gold"
		)
		local loserData = DataService.Get(victim.Owner)
		if loserData then
			loserData.Rating = math.max(0, loserData.Rating - (repeats < 2 and Config.RATING_LOSS or 0))
			loserData.Streak = 0
			DataService.MarkDirty(victim.Owner)
		end
		DataService.MarkDirty(player)
	end
end

---------------------------------------------------------------- remotes
local function filterName(player, text)
	if type(text) ~= "string" then
		return nil, "Invalid name"
	end
	text = text:gsub("^%s+", ""):gsub("%s+$", ""):gsub("[%c]", "")
	local len = utf8.len(text)
	if not len or len == 0 then
		return nil, "Type a name"
	end
	if len > Config.NAME_MAX then
		return nil, "Max " .. Config.NAME_MAX .. " letters"
	end
	local ok, result = pcall(function()
		return TextService:FilterStringAsync(text, player.UserId):GetNonChatStringForBroadcastAsync()
	end)
	if not ok then
		return nil, "Couldn't check the name right now, try again"
	end
	if result:find("#") then
		return nil, "That name isn't allowed, try another one"
	end
	return result
end

-- 🎓 (2026-10) o primeiro cachorro vem do sorteio do Prof. Barkley (StarterService): aqui só cria o cachorro sorteado,
-- com o nome filtrado, e faz ele nascer em `at` (na frente do professor). Ninguém escolhe mais pelo remote antigo.
local function grantStarter(player, speciesId, name, at)
	local data = DataService.Get(player)
	if not data then
		return false, "Loading..."
	end
	if data.Started then
		return false, "You already have a dog!"
	end
	if type(speciesId) ~= "string" or not DogData.Species[speciesId] then
		return false, "Invalid dog"
	end
	-- o filtro de nome faz yield: sem esta trava, dois cliques ganhavam dois starters
	if starting[player] or not DataService.Throttle(player, "ChooseStarter", 1) then
		return false, "Please wait..."
	end
	starting[player] = true
	local filtered, err = filterName(player, name)
	starting[player] = nil
	if not filtered then
		return false, err
	end
	if DataService.Get(player) ~= data or data.Started then
		return false, "You already have a dog!"
	end
	local dog = DataService.AddDog(player, speciesId, filtered)
	if not dog then
		return false, "Couldn't create the dog"
	end
	data.Equipped = dog.Id
	data.Started = true
	data.NextEggAt = os.time() + Config.EGG_INTERVAL
	DataService.MarkDirty(player)
	if DataService.SaveNow then
		DataService.SaveNow(player)
	end
	PlotService.Render(player)
	-- 🧭 no TUTORIAL da guia (2026-10-23, pedido do dono: "quando você ganha você ainda não vira o cachorro, mas esse
	-- cachorro equipado fica te seguindo"): o jogador continua a PESSOA (modo 🧍, como o Z) e o cliente mostra o
	-- cachorro andando atrás dele (Systems/GuideTour); ele vira o cachorro na 1ª ilha (TutorialService "dog").
	if (tonumber(data.Tutorial) or 0) < 99 then
		player:SetAttribute("HumanMode", true)
		player:SetAttribute("DogState", "human")
		state(player).State = "human"
		return true, filtered
	end
	if DogService.Spawn(player, at) then
		homeRoutine(player)
	end
	return true, filtered
end
DogService.GrantStarter = grantStarter

local function equipDog(player, uid)
	local data = DataService.Get(player)
	if not (data and type(uid) == "string" and data.Dogs[uid]) then
		return false, "Invalid dog"
	end
	if data.Equipped == uid then
		return true, "Already equipped"
	end
	if not DataService.Throttle(player, "EquipDog", 1) then
		return false, "Easy! Wait a second."
	end
	-- trocar de cachorro respawna com vida cheia: não pode virar fuga/cura no meio da luta
	local s = state(player)
	local f = s.Fighter
	if s.State == "ko" or s.Pending then
		return false, "Wait for your dog to wake up before switching."
	end
	if Fighters.Alive(f) then
		if f.Zone == "boss" then
			return false, "You can't switch dogs during a boss fight!"
		end
		if f.Duel and Fighters.Alive(f.Duel) and f.Zone == "arena" then
			return false, "Finish (or cancel) the current fight before switching dogs."
		end
	end
	data.Equipped = uid
	DataService.MarkDirty(player)
	PlotService.Render(player)
	respawnAndResume(player, true)
	return true, "🐶 " .. data.Dogs[uid].Name .. " equipped!"
end

local function favoriteDog(player, uid, value)
	if not DataService.Throttle(player, "FavoriteDog", 0.1) then
		return false
	end
	local data = DataService.Get(player)
	local dog = data and type(uid) == "string" and data.Dogs[uid]
	if not dog then
		return false
	end
	dog.Fav = value == true
	DataService.MarkDirty(player)
	return true
end

local function renameDog(player, uid, name)
	local data = DataService.Get(player)
	local dog = data and type(uid) == "string" and data.Dogs[uid]
	if not dog then
		return false, "Invalid dog"
	end
	if not DataService.Throttle(player, "RenameDog", 2) then
		return false, "Wait a bit before renaming again."
	end
	local filtered, err = filterName(player, name)
	if not filtered then
		return false, err
	end
	-- o filtro fez yield: confere se o cachorro ainda existe
	if DataService.Get(player) ~= data or data.Dogs[uid] ~= dog then
		return false, "Invalid dog"
	end
	dog.Name = filtered
	DataService.MarkDirty(player)
	local f = DogService.GetFighter(player)
	if f and f.Uid == uid then
		f.DisplayName = filtered
		Fighters.RefreshLabel(f)
		PlotService.Render(player)
	end
	return true, filtered
end

local function releaseDog(player, uid)
	local data = DataService.Get(player)
	local dog = data and type(uid) == "string" and data.Dogs[uid]
	if not dog then
		return false, "Invalid dog"
	end
	if data.Equipped == uid then
		return false, "You can't release your equipped dog"
	end
	if dog.Fav then
		return false, "Unfavorite it before releasing"
	end
	if DogData.Species[dog.Species] and DogData.Species[dog.Species].Rarity == "Divine" then
		return false, "☀️ DIVINE dogs can't be released!"
	end
	if not DataService.Throttle(player, "ReleaseDog", 0.15) then
		return false, "Easy!"
	end
	local rarity = Config.RARITY[DogData.Species[dog.Species].Rarity]
	local cashMult = mults(player)
	-- (✨ shiny / 🥇 Gold / 🌈 Rainbow valem mais — Shared/Variants)
	local cash = math.floor(rarity.Release * (1 + dog.Level * 0.05) * cashMult * Variants.ValueMult(dog))
	data.Dogs[uid] = nil
	DataService.AddCash(player, cash, "release")
	return true, "Released! +$" .. Config.Format(cash)
end

-- 💰 Venda em massa (menu DOGS): vende os cachorros das raridades escolhidas.
-- Nunca vende o equipado nem os favoritos ⭐. keepBest = guarda o de maior level de cada espécie
-- (assim o jogador nunca perde um cachorro do Index). Lendário e Mítico: só os REPETIDOS, sempre
-- guardando o melhor de cada espécie, mesmo com keepBest desligado.
local SELLABLE = { Common = true, Uncommon = true, Rare = true, Epic = true, Legendary = true, Mythic = true }
local ALWAYS_KEEP_ONE = Config.RARITY.Legendary.Order
local function sellDogs(player, action, rarities, keepBest)
	local data = DataService.Get(player)
	if not (data and data.Started) or type(rarities) ~= "table" then
		return false, "Invalid"
	end
	if action ~= "preview" and action ~= "sell" then
		return false, "Invalid"
	end
	if not DataService.Throttle(player, "SellDogs", action == "sell" and 1 or 0.2) then
		return false, "Easy!"
	end
	keepBest = keepBest ~= false
	-- o melhor de cada espécie (maior level) fica, se keepBest
	local best = {}
	for uid, dog in pairs(data.Dogs) do
		local b = best[dog.Species]
		if not b or dog.Level > data.Dogs[b].Level then
			best[dog.Species] = uid
		end
	end
	local cashMult = mults(player)
	local toSell, total = {}, 0
	for uid, dog in pairs(data.Dogs) do
		local species = DogData.Species[dog.Species]
		local rarityId = species and species.Rarity
		if
			rarityId
			and SELLABLE[rarityId]
			and rarities[rarityId] == true
			and uid ~= data.Equipped
			and not dog.Fav
			and not Variants.IsSpecial(dog) -- (✨ shiny / 🥇 Gold / 🌈 Rainbow nunca saem na venda em massa)
			and (best[dog.Species] ~= uid or not (keepBest or Config.RARITY[rarityId].Order >= ALWAYS_KEEP_ONE))
		then
			table.insert(toSell, uid)
			total += math.floor(Config.RARITY[rarityId].Release * (1 + dog.Level * 0.05) * cashMult)
		end
	end
	if action == "preview" then
		return true, { Count = #toSell, Cash = total }
	end
	if #toSell == 0 then
		return false, "Nothing to sell"
	end
	for _, uid in ipairs(toSell) do
		data.Dogs[uid] = nil
	end
	DataService.AddCash(player, total, "release")
	DataService.MarkDirty(player)
	return true, { Count = #toSell, Cash = total }
end

-- (2026-10) o modo da Arena ficou AUTOMÁTICO: o PvP liga sozinho no chão do Coliseu (homeRoutine). O pedido antigo
-- do cliente (botão ⚔️ PvP do MAP, que saiu) não faz mais nada.
local function setArenaMode(_player, _mode) end

-- Jogador clicou num cachorro e confirmou "LUTAR". target = Model em workspace.Cachorros
-- (nil = parar a luta atual contra NPC). Retorna (ok, mensagem).
local function challengeTarget(player, target)
	if not DataService.Throttle(player, "ChallengeTarget", 0.25) then
		return false, "Easy!"
	end
	local s = state(player)
	local f = s.Fighter
	if target == nil then
		if f and f.Duel then
			if f.Duel.Kind == "player" then
				return false, "You can't run from a PvP duel! Go HOME if you want to give up."
			end
			Fighters.EndDuel(f)
			return true, "Fight canceled."
		end
		return true, ""
	end
	if typeof(target) ~= "Instance" or not target:IsA("Model") then
		return false, "Invalid target."
	end
	if player:GetAttribute("InTower") then
		return false, "Leave the Boss Tower first."
	end
	if not Fighters.Alive(f) then
		return false, (s.State == "ko" or s.Pending) and "Your dog fainted... wait for it to come back." or "You don't have a dog equipped yet."
	end
	if s.State ~= "home" and s.State ~= "toHome" and s.State ~= "toArena" and s.State ~= "arena" then
		return false, "Your dog can't fight right now."
	end
	local enemy = Fighters.List[target]
	if not Fighters.Alive(enemy) then
		return false, "That dog isn't available."
	end
	if enemy == f or enemy.Owner == player then
		return false, "That's your dog! 🐶"
	end
	if enemy.Kind == "boss" then
		return false, Config.BOSS_TOWER and "Bosses are only in the Boss Tower 🏰" or "🌍 The Super Boss fights everyone in the Colosseum — just get close!"
	end
	if enemy.Zone ~= "arena" then
		return false, "That dog isn't in a fighting area."
	end
	if f.Zone ~= "arena" or f.Island ~= enemy.Island then
		return false, "Walk over to that dog's island first! 🏝️"
	end
	if enemy.Kind == "player" then
		-- ⚔️ no Coliseu o PvP é automático (todos contra todos): não tem desafio, é só atacar
		if enemy.Island ~= "colosseum" then
			return false, "PvP is only inside the ⚔️ Colosseum!"
		end
		if not Fighters.ColosseumPvP() then
			return false, "The 🌍 Super Boss is awake! Team up against it — no PvP now."
		end
		return true, "⚔️ Colosseum PvP is ON — everyone vs everyone. Just attack!"
	elseif enemy.Kind ~= "npc" then
		return false, "Invalid target."
	end
	if f.Duel == enemy then
		return true, "Already fighting " .. enemy.DisplayName .. "!"
	end
	if enemy.Duel and enemy.Duel ~= f and Fighters.Alive(enemy.Duel) then
		return false, enemy.DisplayName .. " is already fighting another dog. Pick another one!"
	end
	Fighters.SetDuel(f, enemy)
	return true, "⚔️ Go bite " .. enemy.DisplayName .. "! (click / 1 = Bite, 2 = Power)"
end

---------------------------------------------------------------- 🧍 boneco parado na frente da casinha
-- Enquanto o jogador é o cachorro, o avatar dele fica de pé na frente da casinha (ancorado).
local parked = {} -- [player] = modelo do avatar
game:GetService("Players").PlayerRemoving:Connect(function(player)
	parked[player] = nil
end)
function DogService.ParkAvatar(player)
	if not Config.HOUSES then
		return -- 2026-10: sem casinha, o boneco não fica parado em lugar nenhum
	end
	if parked[player] and parked[player].Parent then
		return -- já está na frente da casinha
	end
	local ok, avatar = pcall(function()
		return game:GetService("Players"):CreateHumanoidModelFromUserId(player.UserId)
	end)
	-- (pode demorar: confere de novo se ainda faz sentido)
	if not (ok and avatar) or not player.Parent or player:GetAttribute("HumanMode") then
		if ok and avatar then
			avatar:Destroy()
		end
		return
	end
	local folder = PlotService.Folder(player)
	local plotCf = PlotService.CFrame(player)
	local root = avatar:FindFirstChild("HumanoidRootPart")
	if not (folder and plotCf and root) then
		avatar:Destroy()
		return
	end
	if parked[player] then
		parked[player]:Destroy()
	end
	for _, d in ipairs(avatar:GetDescendants()) do
		if d:IsA("BaseScript") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	local hum = avatar:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayName = player.DisplayName
	end
	local hip = hum and hum.HipHeight or 2
	local spot = PlotService.Snap(plotCf * Layout.PLOT.OwnerSpot)
	avatar:PivotTo(spot + Vector3.new(0, hip + root.Size.Y / 2, 0))
	avatar.Name = "AvatarDono"
	avatar.Parent = folder
	parked[player] = avatar
end

local function unparkAvatar(player)
	if parked[player] then
		parked[player]:Destroy()
		parked[player] = nil
	end
end

-- Enquanto o jogador é a pessoa, o cachorro anda sozinho até o 🪵 estande e treina.
local function moveTo(f, position, timeout, isCurrent)
	local t0 = os.clock()
	f.Humanoid:MoveTo(position)
	while os.clock() - t0 < timeout and isCurrent() and Fighters.Alive(f) do
		if Fighters.FlatDistance(f.Root.Position, position) < 2.5 then
			return true
		end
		f.Humanoid:MoveTo(position)
		task.wait(0.25)
	end
	return false
end

-- 🐾 pessoa (Z) sem casinha: o cachorro anda atrás dela como um pet (fica em "home": ninguém briga com ele)
local function petRoutine(player)
	local gen = setState(player, "human")
	local s = state(player)
	local f = s.Fighter
	if not Fighters.Alive(f) then
		return
	end
	f.Zone = "home"
	f.Island = nil
	f.Controlled = true
	f.Target = nil
	setControl(player, f, true)
	player:SetAttribute("AutoControl", false) -- o jogador (pessoa) não está travado
	task.spawn(function()
		while s.Gen == gen and Fighters.Alive(f) do
			local avatar = player.Character
			local aroot = avatar and avatar ~= f.Model and avatar:FindFirstChild("HumanoidRootPart")
			local ahum = avatar and avatar:FindFirstChildOfClass("Humanoid")
			if aroot and ahum then
				local d = Fighters.FlatDistance(aroot.Position, f.Root.Position)
				local back = aroot.Position - aroot.CFrame.LookVector * 5 + aroot.CFrame.RightVector * 3
				if d > 70 or math.abs(aroot.Position.Y - f.Root.Position.Y) > 40 then
					local g = ZoneGeo.Ground(back, aroot.Position.Y + 10, 60)
					if g then
						Fighters.Teleport(f, g)
					end
				elseif d > 8 then
					f.Humanoid.WalkSpeed = math.max(f.Stats.Speed, ahum.WalkSpeed * (d > 20 and 1.5 or 1.15))
					f.Humanoid:MoveTo(back)
				else
					Fighters.Stop(f)
				end
			end
			task.wait(0.25)
		end
	end)
end

local function trainerRoutine(player)
	local gen = setState(player, "human")
	local s = state(player)
	local f = s.Fighter
	if not Fighters.Alive(f) then
		return
	end
	f.Zone = "home"
	f.Controlled = true
	f.Target = nil
	setControl(player, f, true)
	player:SetAttribute("AutoControl", false) -- o jogador (pessoa) não está travado
	local function current()
		return s.Gen == gen
	end
	task.spawn(function()
		while current() and Fighters.Alive(f) do
			local stand = PlotService.GetStand(player)
			if not stand then
				task.wait(1)
			elseif Fighters.FlatDistance(stand.Spot, f.Root.Position) > 3 then
				s.Training = false
				player:SetAttribute("Training", false)
				local plotCf = PlotService.CFrame(player)
				local lp = plotCf and plotCf:PointToObjectSpace(f.Root.Position)
				if lp and lp.X < 12 then
					moveTo(f, stand.Path, 10, current)
				end
				moveTo(f, stand.Spot, 8, current)
			else
				Fighters.Stop(f)
				Fighters.Face(f, stand.Position)
				s.Training = true
				player:SetAttribute("Training", true)
				task.wait(Config.TRAIN_HIT_TIME / trainSpeed(player))
				if current() and Fighters.Alive(f) then
					trainHit(player, f, 1)
				end
			end
		end
	end)
end

---------------------------------------------------------------- 🧍 Z: pessoa ⇄ cachorro
-- Pessoa: o cachorro some e o avatar do Roblox aparece no mesmo lugar (dá para andar e escolher outro
-- cachorro no DOGS — equipar já transforma). Z de novo: vira o cachorro equipado onde a pessoa está.
local function toggleHuman(player)
	if not DataService.Throttle(player, "ToggleHuman", 1) then
		return
	end
	local data = DataService.Get(player)
	if not (data and data.Started) or player:GetAttribute("InTower") then
		return
	end
	local s = state(player)
	if s.State == "ko" or s.Pending or starting[player] then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local at = root and root.Position
	if player:GetAttribute("HumanMode") then
		-- pessoa → cachorro
		local cf = at and CFrame.new(at - Vector3.new(0, 3, 0)) * root.CFrame.Rotation or nil
		local f = DogService.Spawn(player, cf) -- o avatar vai para a frente da casinha (ParkAvatar)
		if f then
			homeRoutine(player)
		end
		return
	end
	-- cachorro → pessoa
	local f = s.Fighter
	if Fighters.Alive(f) and f.Duel and Fighters.Alive(f.Duel) and f.Duel.Kind == "player" then
		remotes.Notify:FireClient(player, "Finish your PvP fight first!", "red")
		return
	end
	player:SetAttribute("HumanMode", true)
	player:SetAttribute("Training", false)
	player:SetAttribute("Flying", false)
	player:SetAttribute("AutoControl", false)
	unparkAvatar(player)
	despawn(player)
	-- 1) volta a ser a pessoa onde o cachorro estava
	local ok = pcall(player.LoadCharacter, player)
	local avatar = player.Character
	if ok and avatar and at then
		avatar:PivotTo(CFrame.new(at + Vector3.new(0, 3, 0)))
	end
	-- 2) um cachorro NOVO (não é o personagem) nasce na frente da casinha e vai treinar; sem casinha (2026-10-25,
	-- pedido do dono) ele vira PET e segue a pessoa
	local plotCf = PlotService.CFrame(player)
	local trainer = plotCf and DogService.Spawn(player, plotCf * Layout.PLOT.DogSpawn, false, true)
	local pet = nil
	if trainer then
		trainerRoutine(player)
	elseif Config.AVATAR_FOLLOWS ~= false and at then
		local ground = ZoneGeo.Ground(at + Vector3.new(4, 0, 4), at.Y + 10, 60)
		pet = DogService.Spawn(player, CFrame.new(ground or at), false, true)
		if pet then
			petRoutine(player)
		end
	end
	if not (trainer or pet) then
		s.State = "human"
		player:SetAttribute("DogState", "human")
	end
	remotes.Notify:FireClient(
		player,
		trainer and "🧍 You're you again! Your dog went to train 🥊. Press Z to be your dog."
			or pet and "🧍 You're you again! Your dog follows you 🐾. Press Z to be your dog."
			or "🧍 You're you again! Press Z to be your dog.",
		"gold"
	)
end

-- 🧭 tutorial: a pessoa vira o cachorro equipado ali mesmo (igual ao Z de pessoa → cachorro)
function DogService.BecomeDog(player)
	if not player:GetAttribute("HumanMode") then
		return false
	end
	toggleHuman(player)
	return true
end

---------------------------------------------------------------- 🐾 habilidades (o jogador luta)
-- 1 = ataque: pata direita → pata esquerda → mordida (ou o tiro pela boca dos atiradores, que vai bem longe para a
-- setinha); 2/3 = poderes e 5 = Supremo — saem onde a setinha está, com ou sem inimigo (alvo invisível,
-- Fighters.Marker), em qualquer lugar; 4 = esquiva. Bater num cachorro vira o alvo principal (duelo); PvP só
-- no Coliseu e só se os dois estiverem com PvP ligado.

local function canFight(player, f, enemy)
	if not Fighters.Alive(enemy) or enemy == f or enemy.Owner == player then
		return false
	end
	-- 🤡 clone de outro jogador: pode bater nele quando poderia bater no dono dele (PvP do Coliseu)
	if enemy.CloneOf then
		return Fighters.Alive(enemy.CloneOf) and canFight(player, f, enemy.CloneOf)
	end
	-- Boss Tower: todo mundo contra o boss (sem duelos)
	if f.Zone == "boss" then
		return enemy.Zone == "boss" and Fighters.Hostile(f, enemy)
	end
	if enemy.Zone ~= "arena" or f.Zone ~= "arena" or enemy.Island ~= f.Island then
		return false
	end
	if enemy.Kind == "player" then
		-- ⚔️ PvP automático: todos contra todos no chão do Coliseu, menos com o 🌍 Super Boss acordado
		return f.Island == "colosseum" and Fighters.ColosseumPvP()
	elseif enemy.Kind == "boss" then
		return true -- 🌍 Boss do Mundo: todos podem bater ao mesmo tempo
	end
	-- 😠 selvagens (2026-10): qualquer um da ilha, mesmo se já estiver brigando com outro cachorro
	return enemy.Kind == "npc"
end

-- golpe de perto: só quem está na FRENTE da setinha (aimDir; sem ela, a frente do cachorro), até
-- Config.MELEE_AIM_CONE graus para cada lado — o mais perto e mais na frente. Atrás e do lado ninguém é escolhido
-- sozinho (2026-10, pedido do dono: "não quero que vá automático, onde a seta estiver ele faz")
local function pickEnemy(player, f, range, aimDir)
	local look = aimDir or f.Root.CFrame.LookVector
	look = Vector3.new(look.X, 0, look.Z)
	look = look.Magnitude > 0.01 and look.Unit or Vector3.new(0, 0, -1)
	local cone = math.cos(math.rad(Config.MELEE_AIM_CONE))
	local best, bestScore = nil, math.huge
	for _, other in pairs(Fighters.List) do
		if canFight(player, f, other) then
			local rel = other.Root.Position - f.Root.Position
			rel = Vector3.new(rel.X, 0, rel.Z)
			local dist = rel.Magnitude - other.Radius - f.Radius
			local front = rel.Magnitude > 0.1 and rel.Unit:Dot(look) or 1
			-- (encostado, com os corpos já se tocando, vale até 90° para o lado)
			if dist <= range and (front >= cone or (dist <= 0.5 and front > 0)) then
				local score = dist - front * 4
				if score < bestScore then
					best, bestScore = other, score
				end
			end
		end
	end
	return best
end

-- 🎯 tiro pela boca: o PRIMEIRO inimigo na linha do tiro (com uma folga de mira que abre com a distância).
-- No chão a linha é reta (horizontal); voando vale a direção 3D da setinha.
local function firstInLine(player, f, origin, dir, range, threeD)
	local best, bestAlong = nil, math.huge
	for _, other in pairs(Fighters.List) do
		if canFight(player, f, other) then
			local rel = other.Root.Position - origin
			if not threeD then
				rel = Vector3.new(rel.X, 0, rel.Z)
			end
			local along = rel:Dot(dir)
			if along > -other.Radius and along < range + other.Radius and along < bestAlong then
				local miss = (rel - dir * along).Magnitude
				if miss < other.Radius + Config.SHOT_AIM_WIDTH + along * 0.03 then
					best, bestAlong = other, along
				end
			end
		end
	end
	return best
end

-- ✨ onde o poder sai: o ponto da setinha (no chão, até POWER_REACH do cachorro). Sem setinha (celular/
-- controle): 18 studs na direção do analógico (ou à frente do cachorro). Nas ilhas, fica dentro da ilha.
local function powerPoint(f, aimPoint, aimDir)
	local origin = f.Root.Position
	local p = aimPoint
	if not p then
		-- celular/controle: na direção do analógico (o cliente manda) ou para onde o cachorro está virado
		local look = aimDir or f.Root.CFrame.LookVector
		look = Vector3.new(look.X, 0, look.Z)
		p = origin + (look.Magnitude > 0.01 and look.Unit or Vector3.new(0, 0, -1)) * 18
	end
	local d = Vector3.new(p.X - origin.X, 0, p.Z - origin.Z)
	if d.Magnitude > Config.POWER_REACH then
		p = Vector3.new(origin.X, p.Y, origin.Z) + d.Unit * Config.POWER_REACH
	end
	p = ZoneGeo.Clamp(f, p, 5)
	return ZoneGeo.Ground(p, math.max(p.Y, origin.Y) + 30, 120) or p
end

local function engage(_player, f, enemy)
	-- selvagem que apanha vira para brigar com quem bateu nele
	if enemy.Kind == "npc" then
		enemy.Aggro = f
	end
	-- (⚔️ jogador contra jogador no Coliseu é todos contra todos: sem duelo marcado)
	if f.Duel == enemy or f.Zone == "boss" or enemy.Kind == "boss" or enemy.Kind == "player" then
		return
	end
	Fighters.SetDuel(f, enemy)
end

-- 💨 o DASH machuca quem estiver no caminho: do ponto de saída até onde o cachorro está agora (com folga), cada
-- inimigo uma vez. O corpo é do cliente (o servidor vê a posição com um atrasinho), então olha um pouco a mais.
-- dir = direção do dash que o cliente mandou (quem fica atrás dela não leva)
local DASH_COLOR = Color3.fromRGB(200, 240, 255)
local function dashHits(player, f, dir)
	local start = f.Root.Position
	local look = dir or f.Root.CFrame.LookVector
	look = Vector3.new(look.X, 0, look.Z)
	look = look.Magnitude > 0.01 and look.Unit or Vector3.new(0, 0, -1)
	local hit = {}
	local t0 = os.clock()
	while os.clock() - t0 < Config.DASH_TIME + 0.3 do
		task.wait(0.05)
		if not Fighters.Alive(f) then
			return
		end
		local here = f.Root.Position
		local seg = Vector3.new(here.X - start.X, 0, here.Z - start.Z)
		for _, other in pairs(Fighters.List) do
			if not hit[other] and canFight(player, f, other) then
				local rel = Vector3.new(other.Root.Position.X - start.X, 0, other.Root.Position.Z - start.Z)
				local reach = other.Radius + f.Radius + Config.DASH_HIT_WIDTH
				local u = seg.Magnitude > 0.1 and math.clamp(rel:Dot(seg) / seg:Dot(seg), 0, 1) or 0
				if (rel - seg * u).Magnitude <= reach and rel:Dot(look) > -reach * 0.5 then
					hit[other] = true
					engage(player, f, other)
					local d = seg.Magnitude > 0.5 and seg.Unit or look
					Fighters.Damage(f, other, f.Stats.Atk * Config.DASH_DAMAGE, { Knockback = d * 38 + Vector3.new(0, 14, 0), Color = DASH_COLOR })
					Fighters.Fx("Impact", { Position = other.Root.Position, Radius = 5, Color = DASH_COLOR })
					Fighters.Fx("Shake", { Position = other.Root.Position, Intensity = 0.2, Radius = 16, Duration = 0.12 })
				end
			end
		end
	end
end

-- aim = direção da setinha do mouse (já validada, unitária) ou nil (celular/controle: a frente do cachorro);
-- aimPoint = ponto da setinha no mundo (poderes) ou nil
local function useAbility(player, slot, aim, aimPoint)
	local s = S[player]
	local f = s and s.Fighter
	if not Fighters.Alive(f) or player:GetAttribute("AutoControl") or f.Busy then
		return false
	end
	if Fighters.IsFrozen(f) then
		return false, "❄️ Frozen!"
	end
	local now = os.clock()
	if slot == 1 then
		if now < (f.NextAttack or 0) then
			return false
		end
		local fighting = f.Zone == "arena" or f.Zone == "boss"
		if DogData.ShotFor(f.SpeciesId) then
			-- 🎯 cachorro ATIRADOR: a bola vai BEM LONGE para onde a setinha aponta (ou para a frente) e acerta o
			-- primeiro inimigo no caminho. COMBO: o 3º tiro seguido (até 1,6 s entre eles) é grande e empurra longe.
			local flying = f.Model:GetAttribute("Flying") == true
			local dir = aim or f.Root.CFrame.LookVector
			if not flying then
				dir = Vector3.new(dir.X, 0, dir.Z)
			end
			dir = dir.Magnitude > 0.01 and dir.Unit or Vector3.new(0, 0, -1)
			if now - (f.LastBiteAt or 0) <= 1.6 then
				f.Combo = (f.Combo or 0) % 3 + 1
			else
				f.Combo = 1
			end
			f.LastBiteAt = now
			local combo = f.Combo
			local mult = combo == 1 and 1 or combo == 2 and 1.2 or 1.8
			local enemy = fighting and firstInLine(player, f, f.Root.Position, dir, Config.SHOT_RANGE, flying) or nil
			if enemy then
				engage(player, f, enemy)
				CombatService.Shoot(f, enemy, mult, combo == 3)
				if combo == 3 then
					Fighters.Fx("Damage", { Position = enemy.Root.Position + Vector3.new(0, enemy.Root.Size.Y + 3, 0), Amount = "COMBO x3!", Color = Color3.fromRGB(255, 200, 60) })
				end
			else
				CombatService.Shoot(f, nil, mult, combo == 3, f.Root.Position + dir * Config.SHOT_RANGE)
			end
			if combo == 3 then
				f.NextAttack = math.max(f.NextAttack or 0, now + 0.8)
			end
		else
			-- 🐾 combo de perto (pedido do dono): pata DIREITA → pata ESQUERDA → MORDIDA (finalizador). O combo
			-- anda a cada golpe (acertando ou não), igual à animação que o cliente já tocou na hora do clique.
			if now - (f.LastBiteAt or 0) <= Config.MELEE_COMBO_WINDOW then
				f.Combo = (f.Combo or 0) % 3 + 1
			else
				f.Combo = 1
			end
			f.LastBiteAt = now
			local step = f.Combo
			Fighters.Melee(f, step)
			CloneService.Melee(f, step, aim) -- 🤡 clones do palhaço batem junto
			local enemy = fighting and pickEnemy(player, f, Config.MELEE_REACH, aim) or nil
			if enemy then
				engage(player, f, enemy)
				if step == 3 then
					Fighters.SetAction(f, "Dash", 0.25)
				end
				CombatService.Melee(f, enemy, step, Config.MELEE_COMBO[step])
				if step == 3 and Fighters.Alive(enemy) then
					local d = enemy.Root.Position - f.Root.Position
					d = Vector3.new(d.X, 0, d.Z)
					d = d.Magnitude > 0.1 and d.Unit or f.Root.CFrame.LookVector
					Fighters.Knock(enemy, d * 55 + Vector3.new(0, 25, 0), 0.25)
					Fighters.Fx("Impact", { Position = enemy.Root.Position, Radius = 7, Color = Color3.fromRGB(255, 220, 120), Heavy = true })
					Fighters.Fx("Damage", { Position = enemy.Root.Position + Vector3.new(0, enemy.Root.Size.Y + 3, 0), Amount = "COMBO x3!", Color = Color3.fromRGB(255, 200, 60) })
					Fighters.Fx("Shake", { Position = enemy.Root.Position, Intensity = 0.4, Radius = 20, Duration = 0.2 })
				else
					Fighters.Fx("Shake", { Position = enemy.Root.Position, Intensity = 0.15, Radius = 14, Duration = 0.12 })
				end
			end
			f.NextAttack = now + Config.MELEE_GAP[step]
		end
		player:SetAttribute("CD1", workspace:GetServerTimeNow() + (f.NextAttack - now))
		return true
	elseif slot == 2 or slot == 3 or slot == 5 then
		-- ✨ (2026-10, pedido do dono) poder funciona em qualquer lugar e SEM inimigo: sai onde a setinha está
		local key = "NextPower" .. slot
		if now < (f[key] or 0) or now < (f.NextCast or 0) then
			return false
		end
		-- 🔓 poder liberado pelo NÍVEL do cachorro (depende da raridade: Config.POWER_UNLOCK_BY_RARITY)
		local need = Config.PowerUnlockLevel(slot == 5 and 3 or slot - 1, f.Species.Rarity)
		if (f.Level or 1) < need then
			return false, "🔒 This power unlocks at Lv." .. need .. "!"
		end
		-- 👑 5 = ESPECIAL (tecla 4, Épico para cima). (2026-10, pedido do dono) não tem mais barra para encher: é uma
		-- habilidade como as outras, com a recarga um pouco maior (Config.SpecialCooldown)
		if slot == 5 and not Config.HasSupreme(f.Species.Rarity) then
			return false, "👑 The SPECIAL power unlocks at EPIC dogs and above!"
		end
		-- 2 = habilidade 2, 3 = habilidade 3, 5 = Especial (shared/Skills.lua); recarga pela raridade
		-- (Config.SKILL_TIER.Cooldown = { tecla 2, tecla 3 }; poder antigo sem catálogo: a de antes)
		local name = DogData.PowersFor(f.SpeciesId)[slot == 5 and 3 or slot - 1]
		if not name then
			return false
		end
		local info = DogData.Specials[name]
		local tier = Config.SkillTier(f.Species.Rarity)
		local cd
		if slot == 5 then
			cd = Config.SpecialCooldown(f.Species.Rarity)
		elseif info and info.Skill then
			cd = tier.Cooldown[slot - 1] or tier.Cooldown[1]
		else
			cd = CombatService.SpecialCooldown(f) * (slot == 3 and 1.6 or 1)
		end
		-- 🎯 (2026-10, pedido do dono: "onde estiver a seta o ataque vai, não quero que vá automático") o alvo é
		-- SEMPRE o ponto da setinha (celular/controle: na direção do analógico) — um alvo invisível que acerta quem
		-- estiver em volta. Ninguém é escolhido sozinho.
		local point = powerPoint(f, aimPoint, aim)
		local marker = Fighters.Marker(f, point)
		CloneService.Cast(f, name, point) -- 🤡 os clones soltam a mesma habilidade, ao lado da setinha
		f[key] = now + cd
		f.NextCast = now + Config.SKILL_GAP
		player:SetAttribute("CD" .. slot, workspace:GetServerTimeNow() + cd)
		if slot == 5 then
			f.Supreming = true
		end
		-- ✨ brilho rápido na cor da raridade (sem a preparação de antes: o poder sai NA HORA)
		local color = Config.RARITY[f.Species.Rarity].Color
		local feet = f.Root.Position - Vector3.new(0, f.Humanoid.HipHeight + f.Root.Size.Y / 2, 0)
		Fighters.Fx("Shockwave", { Position = feet, Radius = slot == 5 and 12 or 7, Color = color, Thick = slot == 5 })
		if slot == 5 then
			Fighters.Fx("Shake", { Position = f.Root.Position, Intensity = 0.5, Radius = 40, Duration = 0.3 })
		end
		if info and info.Skill then
			-- ⚡ habilidade nova (SkillKit): o jogador CONTINUA no controle; o servidor só segura o corpo nos movimentos
			-- curtos da habilidade (f.CastControl). Dá para morder e soltar outro poder enquanto este acontece.
			f.Casting = (f.Casting or 0) + 1
			castControl(player, f)
			CombatService.RunSpecial(f, marker, function()
				Fighters.RemoveMarker(marker)
				f.Casting = math.max(0, (f.Casting or 1) - 1)
				if slot == 5 then
					f.Supreming = nil
				end
				-- garantia: nenhum movimento ficou segurando o corpo
				if (f.Casting or 0) == 0 and (f.Grabs or 0) > 0 then
					f.CastControl(-(f.Grabs or 0))
				end
			end, name, true)
			return true
		end
		-- poder antigo (o golpe próprio de alguns Míticos, Specials.lua): ele mesmo move o cachorro, então o servidor
		-- segura o corpo enquanto ele roda — mas sem a preparação de antes (sai na hora)
		setControl(player, f, true)
		f.Controlled = false
		task.defer(function()
			local function giveBack()
				Fighters.RemoveMarker(marker)
				f.Supreming = nil
				f.Controlled = true
				local st = S[player]
				if st and st.Fighter == f and Fighters.Alive(f) then
					setControl(player, f, false)
				end
			end
			if not Fighters.Alive(f) then
				giveBack()
				return
			end
			CombatService.RunSpecial(f, marker, giveBack, name)
		end)
		return true
	elseif slot == 4 then
		-- 💨 DASH (Q): o cliente dá o impulso (a física é dele) na direção do analógico ou da setinha; o servidor dá a
		-- invencibilidade curta e o dano em quem ficar no caminho (dashHits)
		if now < (f.NextDodge or 0) then
			return false
		end
		f.NextDodge = now + Config.DASH_COOLDOWN
		f.DodgeUntil = now + 0.45
		player:SetAttribute("CD4", workspace:GetServerTimeNow() + Config.DASH_COOLDOWN)
		Fighters.SetAction(f, "Dash", 0.3)
		Fighters.Fx("Streak", { Model = f.Model, Width = 1.4, Lifetime = 0.3, Color = DASH_COLOR })
		if f.Zone == "arena" or f.Zone == "boss" then
			task.spawn(dashHits, player, f, aim)
		end
		CloneService.Dash(f, aim) -- 🤡 os clones dão a dash junto
		return true
	end
	return false
end

---------------------------------------------------------------- level up
local function onLevelUp(player, dog, oldLevel)
	local f = DogService.GetFighter(player)
	if f and f.Uid == dog.Id and Fighters.Alive(f) then
		local stats = Config.Stats(f.Species, dog.Level, f.Variant)
		stats.Speed *= Config.PLAYER_SPEED_MULT * passMult(player, "SpeedMult") -- (igual ao Fighters.Spawn do cachorro do jogador)
		local pct = f.Humanoid.Health / f.Humanoid.MaxHealth
		f.Stats = stats
		f.Level = dog.Level
		f.Humanoid.MaxHealth = stats.MaxHP
		f.Humanoid.Health = math.max(1, stats.MaxHP * pct)
		Fighters.RefreshLabel(f)
		Fighters.Fx("LevelUp", { Model = f.Model })
	end
	remotes.LevelUp:FireClient(player, dog.Name, dog.Species, oldLevel, dog.Level)
	-- 🔓 poder novo liberado neste nível (Lv.10 / 25 / 50): aviso dourado com o nome do poder
	local species = DogData.Species[dog.Species]
	local powers = species and DogData.PowersFor(dog.Species)
	if powers then
		for i = 1, 3 do
			local need = Config.PowerUnlockLevel(i, species.Rarity)
			local name = powers[i]
			if name and oldLevel < need and dog.Level >= need and (i < 3 or Config.HasSupreme(species.Rarity)) then
				local info = DogData.Specials[name]
				local key = i == 3 and "4" or tostring(i + 1)
				remotes.Notify:FireClient(player, "🔓 NEW POWER UNLOCKED: " .. (info and info.Name or name) .. " (key " .. key .. ")!", "gold")
			end
		end
	end
end

function DogService.Start(r)
	remotes = r
	remotes.ChooseStarter.OnServerInvoke = function()
		return false, "Talk to 🎓 Prof. Barkley in the Pawville Kennel to get your first dog!"
	end
	remotes.EquipDog.OnServerInvoke = equipDog
	remotes.UseAbility.OnServerInvoke = function(player, slot, aim, aimPoint)
		if type(slot) ~= "number" or not DataService.Throttle(player, "UseAbility", 0.08) then
			return false
		end
		-- 🎯 mira da setinha (PC): só uma direção; qualquer coisa estranha vira "sem mira" (frente do cachorro)
		if typeof(aim) == "Vector3" and aim.Magnitude > 0.01 and aim.Magnitude < 1e5 then
			aim = aim.Unit
		else
			aim = nil
		end
		-- ✨ ponto da setinha (poderes): só um ponto razoável perto do cachorro
		local st = S[player]
		local root = st and st.Fighter and st.Fighter.Root
		if not (typeof(aimPoint) == "Vector3" and aimPoint.Magnitude < 1e6 and root and (aimPoint - root.Position).Magnitude < 1000) then
			aimPoint = nil
		end
		return useAbility(player, slot, aim, aimPoint)
	end
	-- 👀 para onde o cachorro do jogador olha (setinha do mouse): vira o atributo "LookAt" do modelo e o
	-- Animator de todo mundo vira a cabeça dele para lá. Limite: ~10x por segundo, ponto perto do cachorro.
	remotes.LookAt.OnServerEvent:Connect(function(player, point)
		if typeof(point) ~= "Vector3" or not (point.Magnitude < 1e6) then
			return
		end
		local st = S[player]
		local f = st and st.Fighter
		if not (Fighters.Alive(f) and f.Model.Parent) or player:GetAttribute("AutoControl") then
			return
		end
		if (point - f.Root.Position).Magnitude > 1500 or not DataService.Throttle(player, "LookAt", 0.1) then
			return
		end
		f.Model:SetAttribute("LookAt", point)
	end)
	remotes.ToggleHuman.OnServerEvent:Connect(toggleHuman)
	-- 🪽 espaço 2x: voa / pousa (só com asas e com o jogador no controle)
	remotes.ToggleFly.OnServerEvent:Connect(function(player)
		local st = S[player]
		local f = st and st.Fighter
		if not (Fighters.Alive(f) and f.Model:GetAttribute("Wings")) or player:GetAttribute("AutoControl") then
			return
		end
		if not DataService.Throttle(player, "ToggleFly", 0.4) then
			return
		end
		setFlying(player, f, not f.Model:GetAttribute("Flying"))
	end)
	-- 🥊 botão TRAIN: batida extra enquanto o cachorro está no estande
	remotes.TrainClick.OnServerEvent:Connect(function(player)
		local st = S[player]
		local f = st and st.Fighter
		if not (st and st.Training and Fighters.Alive(f)) then
			return
		end
		if not DataService.Throttle(player, "TrainClick", 1 / Config.TRAIN_CLICK_RATE) then
			return
		end
		trainHit(player, f, Config.TRAIN_CLICK_XP)
	end)
	remotes.FavoriteDog.OnServerInvoke = favoriteDog
	remotes.RenameDog.OnServerInvoke = renameDog
	remotes.ReleaseDog.OnServerInvoke = releaseDog
	remotes.SellDogs.OnServerInvoke = sellDogs
	remotes.SetArenaMode.OnServerEvent:Connect(setArenaMode)
	remotes.ChallengeTarget.OnServerInvoke = challengeTarget

	Fighters.Killed.Event:Connect(onKilled)
	-- avisa quando o adversário some no meio do duelo (saiu do jogo, trocou de cachorro, foi para a torre)
	Fighters.DuelEnded.Event:Connect(function(a, b)
		for _, pair in ipairs({ { a, b }, { b, a } }) do
			local gone, stay = pair[1], pair[2]
			if gone.Removed and Fighters.Alive(stay) and stay.Kind == "player" and stay.Owner and stay.Owner.Parent then
				remotes.Notify:FireClient(stay.Owner, "🏳️ " .. gone.DisplayName .. " left the fight.", "gold")
			end
		end
	end)
	DataService.LevelUp.Event:Connect(onLevelUp)
	DataService.Loaded.Event:Connect(function(player, data)
		player:SetAttribute("ArenaMode", "off")
		state(player).LoadedAt = os.clock()
		if data.Started then
			-- 🏡 SPAWN (2026-10-23, pedido do dono: "a pessoa nasça na ilha onde você consegue o cachorro"): todo mundo
			-- nasce na PAWVILLE, na pracinha do spawn (quem é novo vira cachorro só no tutorial — TutorialService).
			task.wait(0.5)
			if player.Parent and not DogService.GetFighter(player) and DogService.Spawn(player, villageCFrame()) then
				homeRoutine(player)
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(WATCHDOG)
			for _, player in ipairs(Players:GetPlayers()) do
				local ok, err = pcall(watchdog, player)
				if not ok then
					warn("[DogService] watchdog", player.Name, err)
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		despawn(player)
		S[player] = nil
		starting[player] = nil
		pvpWins[player] = nil
	end)
end

return DogService
