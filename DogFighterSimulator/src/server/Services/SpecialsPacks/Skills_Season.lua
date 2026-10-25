-- 🎟️ HABILIDADES DOS EXCLUSIVOS DO PASSE DE TEMPORADA (2026-10-25). Cada exclusivo usa os poderes de um cachorro que
-- já existe, com nome e cor próprios (Shared/Skills.lua): SK_<exclusivo>_N roda o SK_<base>_N na hora (os pacotes de
-- poderes carregam em qualquer ordem, então a ligação é feita quando o poder é usado).
local SkillKit = require(script.Parent.Parent.SkillKit)

-- exclusivo → cachorro de onde vêm os poderes
local BASE = {
	aurora_pup = "frost_phoenix",
}

return function(Specials, _Fighters)
	for id, base in pairs(BASE) do
		for slot = 2, 4 do
			local mine, theirs = "SK_" .. id .. "_" .. slot, "SK_" .. base .. "_" .. slot
			SkillKit.Ids[mine] = slot
			Specials[mine] = function(f, t)
				local fn = Specials[theirs]
				if fn then
					fn(f, t)
				end
			end
		end
	end
end
