-- 🎵 TRILHA 2 (2026-10-25) — GERADO por Musica/gerar_trilha2.py, não edite à mão.
-- As músicas ficam em 3 pacotes de áudio (o Roblox limita quantos áudios a conta envia por mês); cada música é
-- um trecho tocado com PlaybackRegion + LoopRegion (loop perfeito). O PUBLICAR.bat envia os pacotes e põe os IDs.
-- Pacote com ID 0 = ainda não enviado: o jogo usa a trilha antiga (Shared/MusicConfig).
local MusicPacks = {}

MusicPacks.Packs = {
	MusicA = 0 --[[ID_Music]], -- Musica/musicas_a.ogg
	MusicB = 0 --[[ID_Music]], -- Musica/musicas_b.ogg
	MusicC = 0 --[[ID_Music]], -- Musica/musicas_c.ogg
}

-- [nome] = { Pack, Start (s), Length (s), Loop }
MusicPacks.Songs = {
	Village = { Pack = "MusicA", Start = 0.250000, Length = 108.000000, Loop = true },
	Sunny = { Pack = "MusicA", Start = 108.750000, Length = 118.857143, Loop = true },
	Meadows = { Pack = "MusicA", Start = 228.107143, Length = 91.428571, Loop = true },
	Adventure = { Pack = "MusicB", Start = 0.250000, Length = 92.444444, Loop = true },
	Mystic = { Pack = "MusicB", Start = 93.194444, Length = 115.555556, Loop = true },
	Arena = { Pack = "MusicB", Start = 209.250000, Length = 86.666667, Loop = true },
	Boss = { Pack = "MusicC", Start = 0.250000, Length = 83.200000, Loop = true },
	LevelUp = { Pack = "MusicC", Start = 83.950000, Length = 3.799977, Loop = false },
	Victory = { Pack = "MusicC", Start = 88.249977, Length = 5.470975, Loop = false },
	Gotcha = { Pack = "MusicC", Start = 94.220952, Length = 4.399977, Loop = false },
	RareWin = { Pack = "MusicC", Start = 99.120930, Length = 6.800000, Loop = false },
	Unlock = { Pack = "MusicC", Start = 106.420930, Length = 4.369229, Loop = false },
}

return MusicPacks
