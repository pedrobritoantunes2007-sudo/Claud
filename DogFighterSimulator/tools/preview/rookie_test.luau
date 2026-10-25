-- 🍼 Teste do REFORÇO DE INICIANTE (2026-10-24, o dono: "deixa o cachorro um pouco mais forte, o nosso, mas somente no
-- início, porque eu comecei e não consegui matar nenhum cachorro, morri várias vezes").
-- Conta (sem Roblox) quantos selvagens da 🌻 Puppy Meadows um cachorro Comum Lv 1 derruba antes de cair, com e sem o
-- reforço (Config.ROOKIE): o jogador acerta 60% dos golpes do combo; os selvagens mordem 1x por segundo.
-- Uso: python3 tools/preview/run_shared.py tools/preview/rookie_test.luau
local Islands = require(Shared.Islands)
local fails = 0
local function check(ok, msg)
	if not ok then
		fails += 1
		print("FALHOU: " .. msg)
	end
end

local R = Config.ROOKIE
check(Config.RookieBoost(1) == 1 and Config.RookieBoost(R.Full) == 1, "reforço inteiro no começo")
check(math.abs(Config.RookieBoost((R.Full + R.End) / 2) - 0.5) < 1e-6, "metade no meio do caminho")
check(Config.RookieBoost(R.End) == 0 and Config.RookieBoost(60) == 0, "sem reforço depois do Lv " .. R.End)
check(Config.MaxAttackers(1) == R.MaxAttackers and Config.MaxAttackers(R.End) == Config.AGGRO_MAX, "selvagens juntos: " .. R.MaxAttackers .. " no começo, " .. Config.AGGRO_MAX .. " depois")
for lv = 1, R.End do
	check(Config.MaxAttackers(lv + 1) >= Config.MaxAttackers(lv), "selvagens juntos nunca diminuem com o level")
end

-- cachorro Comum de ficha média
local common = nil
for _, id in ipairs(DogData.SpeciesOfRarity("Common")) do
	local sp = DogData.Species[id]
	if sp.Stats.HP == 1 and sp.Stats.Atk == 1 then
		common = sp
		break
	end
end
common = common or DogData.Species[DogData.SpeciesOfRarity("Common")[1]]
local def = Islands.List.common
local WILD = 0.75 -- NPCService DEFAULT_MULT
local COMBO = (Config.MELEE_COMBO[1] + Config.MELEE_COMBO[2] + Config.MELEE_COMBO[3])
local GAP = (Config.MELEE_GAP[1] + Config.MELEE_GAP[2] + Config.MELEE_GAP[3])
local ACC = 0.6

-- quantos selvagens (levels da ilha, em média) o jogador Lv `lv` derruba antes de cair
local function killsPerLife(lv, boost)
	local me = Config.Stats(common, lv)
	local b = boost and Config.RookieBoost(lv) or 0
	local atkMult = 1 + R.Atk * b
	local defMult = 1 - R.Def * b
	local maxAtk = boost and Config.MaxAttackers(lv) or Config.AGGRO_MAX
	local myDps = me.Atk * COMBO / GAP * ACC * atkMult
	local hp = me.MaxHP
	local kills, t = 0, 0
	local wildLv = (def.Levels[1] + def.Levels[2]) / 2
	local w = Config.Stats(common, math.floor(wildLv + 0.5))
	local wHP, wAtk = w.MaxHP * WILD, w.Atk * WILD
	-- 3 selvagens por perto no começo (ilha com 40), até maxAtk mordendo junto
	local around = 3
	local cur = wHP
	while hp > 0 and t < 300 do
		local biting = math.min(maxAtk, around)
		local dt = 0.1
		hp -= biting * wAtk * defMult * dt
		cur -= myDps * dt
		if cur <= 0 then
			kills += 1
			cur = wHP
		end
		t += dt
	end
	return kills, t
end

for _, lv in ipairs({ 1, 3, 5, 8, 12, 15 }) do
	local k0, t0 = killsPerLife(lv, false)
	local k1, t1 = killsPerLife(lv, true)
	print(string.format("Lv %2d: sem reforço %d selvagens (cai em %.1f s) · com reforço %d (cai em %.1f s) · reforço %.0f%%", lv, k0, t0, k1, t1, Config.RookieBoost(lv) * 100))
	if lv == 1 then
		check(k0 <= 1, "sem reforço o Lv 1 já devia sofrer (o dono não matava nenhum)")
		check(k1 >= Config.TUTORIAL.Kills, "com reforço o Lv 1 derruba os " .. Config.TUTORIAL.Kills .. " do tutorial numa vida só")
	end
	-- ⚖️ (2026-10-25, o dono: "meu inicial tá muito forte") equilibrado: nunca um massacre
	check(k1 <= 5, string.format("Lv %d com reforço não fica forte demais (%d por vida)", lv, k1))
	if lv >= R.End then
		check(k0 == k1, "depois do Lv " .. R.End .. " nada muda")
	end
end
print(fails == 0 and "OK: reforço de iniciante" or ("FALHAS: " .. fails))
