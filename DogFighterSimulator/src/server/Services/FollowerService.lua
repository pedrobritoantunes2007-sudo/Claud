-- 🧍 O BONECO SEGUE O CACHORRO (2026-10-25, pedido do dono: "quando ele vira um cachorro, o boneco do player vai ficar
-- seguindo o cachorro"). Enquanto o jogador É o cachorro, o avatar dele (Players:CreateHumanoidModelFromUserId) anda
-- atrás do cachorro, como um dono passeando — todo mundo vê. Atravessa tudo (não esbarra em ninguém nem trava o
-- caminho), corre para alcançar e aparece atrás do cachorro quando fica longe (portal, voo, outra ilha). Some quando o
-- jogador vira a pessoa (Z), está na Boss Tower ou o cachorro desmaiou. O contrário (pessoa → o cachorro segue) fica
-- no DogService (petRoutine).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Fighters = require(script.Parent.Fighters)
local ZoneGeo = require(script.Parent.ZoneGeo)

local FollowerService = {}

local GAP = 7 -- studs atrás do cachorro
local SIDE = 2.5 -- um pouco de lado (não fica escondido atrás do cachorro grande)
local TELEPORT = 70 -- mais longe que isso: aparece atrás do cachorro
local TICK = 0.15
-- animações padrão do Roblox (quando o avatar não traz as dele)
local ANIMS = {
	R15 = { idle = "rbxassetid://507766666", walk = "rbxassetid://507777826", run = "rbxassetid://507767714" },
	R6 = { idle = "rbxassetid://180435571", walk = "rbxassetid://180426354", run = "rbxassetid://180426354" },
}

local DogService -- (carregado no Start: o DogService também usa este módulo)
local folder
local list = {} -- player -> { Model, Hum, Root, Parts, Tracks, Playing }

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

-- animação do Animate do próprio avatar (pacotes de animação), ou a padrão
local function animId(model, rig, name, child)
	local animate = model:FindFirstChild("Animate")
	local holder = animate and animate:FindFirstChild(name)
	local anim = holder and (holder:FindFirstChild(child) or holder:FindFirstChildOfClass("Animation"))
	if anim and anim:IsA("Animation") and anim.AnimationId ~= "" then
		return anim.AnimationId
	end
	return ANIMS[rig][name]
end

local function build(player)
	local ok, model = pcall(Players.CreateHumanoidModelFromUserId, Players, player.UserId)
	if not (ok and model) then
		return nil
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not (hum and root) or not player.Parent then
		model:Destroy()
		return nil
	end
	local rig = hum.RigType == Enum.HumanoidRigType.R6 and "R6" or "R15"
	local ids = {
		idle = animId(model, rig, "idle", "Animation1"),
		walk = animId(model, rig, "walk", "WalkAnim"),
		run = animId(model, rig, "run", "RunAnim"),
	}
	model.Name = player.Name .. "_Boneco"
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BaseScript") then
			d:Destroy()
		end
	end
	local parts = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.Massless = d ~= root
			table.insert(parts, d)
		end
	end
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.BreakJointsOnDeath = false
	hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	model:SetAttribute("Owner", player.UserId)
	model:SetAttribute("Kind", "follower")
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = hum
	local rec = { Model = model, Hum = hum, Root = root, Parts = parts, Tracks = {}, Playing = nil }
	for name, id in pairs(ids) do
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local okT, track = pcall(animator.LoadAnimation, animator, anim)
		if okT and track then
			track.Looped = true
			rec.Tracks[name] = track
		end
	end
	local function play(name)
		if rec.Playing == name then
			return
		end
		if rec.Playing and rec.Tracks[rec.Playing] then
			rec.Tracks[rec.Playing]:Stop(0.2)
		end
		rec.Playing = name
		local track = rec.Tracks[name]
		if track then
			track:Play(0.2)
		end
	end
	rec.Play = play
	play("idle")
	hum.Running:Connect(function(speed)
		play(speed > 18 and "run" or speed > 0.6 and "walk" or "idle")
	end)
	return rec
end

local function hide(rec)
	if rec and rec.Model and rec.Model.Parent then
		rec.Model.Parent = nil
	end
end

-- aparece atrás do cachorro, no chão (nil se não tem chão ali: sobre o mar, voando)
local function place(rec, dog)
	local look = flat(dog.Root.CFrame.LookVector)
	look = look.Magnitude > 0.1 and look.Unit or Vector3.new(0, 0, -1)
	local spot = dog.Root.Position - look * GAP + Vector3.new(-look.Z, 0, look.X) * SIDE
	local ground = ZoneGeo.Ground(spot, dog.Root.Position.Y + 12, 60)
	if not ground then
		return false
	end
	local height = rec.Hum.HipHeight + rec.Root.Size.Y / 2
	rec.Model:PivotTo(CFrame.lookAt(ground + Vector3.new(0, height, 0), ground + Vector3.new(0, height, 0) + look))
	if rec.Model.Parent ~= folder then
		rec.Model.Parent = folder
		pcall(rec.Root.SetNetworkOwner, rec.Root, nil)
	end
	return true
end

local function follow(player, rec)
	local dog = DogService.GetFighter(player)
	local ok = Fighters.Alive(dog)
		and player.Character == dog.Model
		and not player:GetAttribute("HumanMode")
		and not player:GetAttribute("InTower")
	if not ok then
		hide(rec)
		return
	end
	if not rec.Model.Parent then
		place(rec, dog)
		return
	end
	-- (atravessa tudo: o Humanoid às vezes religa a colisão das partes)
	for _, part in ipairs(rec.Parts) do
		if part.CanCollide then
			part.CanCollide = false
		end
	end
	local me, target = rec.Root.Position, dog.Root.Position
	local dist = Fighters.FlatDistance(me, target)
	if dist > TELEPORT or math.abs(me.Y - target.Y) > 40 then
		if not place(rec, dog) then
			rec.Hum:MoveTo(me) -- cachorro voando sobre o mar: espera na beira
		end
		return
	end
	if dist > GAP + 1.5 then
		local look = flat(dog.Root.CFrame.LookVector)
		look = look.Magnitude > 0.1 and look.Unit or flat(target - me).Unit
		local goal = target - look * GAP + Vector3.new(-look.Z, 0, look.X) * SIDE
		local dogSpeed = dog.Humanoid.WalkSpeed
		rec.Hum.WalkSpeed = math.clamp(math.max(16, dogSpeed) * (dist > 20 and 1.35 or 1.05), 16, 90)
		rec.Hum:MoveTo(goal)
	else
		rec.Hum:MoveTo(me)
	end
end

function FollowerService.Start()
	if Config.AVATAR_FOLLOWS == false then
		return
	end
	DogService = require(script.Parent.DogService)
	folder = workspace:FindFirstChild("Seguidores") or Instance.new("Folder")
	folder.Name = "Seguidores"
	folder.Parent = workspace
	local building = {}
	Players.PlayerRemoving:Connect(function(player)
		building[player] = nil
		local rec = list[player]
		list[player] = nil
		if rec and rec.Model then
			rec.Model:Destroy()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(TICK)
			for _, player in ipairs(Players:GetPlayers()) do
				local rec = list[player]
				if rec then
					local ok, err = pcall(follow, player, rec)
					if not ok then
						warn("[FollowerService]", err)
					end
				elseif not building[player] and Fighters.Alive(DogService.GetFighter(player)) and not player:GetAttribute("HumanMode") then
					-- monta o boneco uma vez (pode demorar: pede o avatar ao Roblox)
					building[player] = true
					task.spawn(function()
						local made = build(player)
						if made and player.Parent then
							list[player] = made
						elseif made then
							made.Model:Destroy()
						end
						task.delay(made and 0 or 30, function()
							building[player] = nil -- (falhou: tenta de novo daqui a pouco)
						end)
					end)
				end
			end
		end
	end)
end

return FollowerService
