-- Trilha sonora do jogo (arquivos em Musica/, veja Musica/LEIAME_MUSICA.md).
-- Depois de enviar cada .ogg no Creator Hub, cole aqui o número do asset (0 = ainda não enviado: não toca nada).
local MusicConfig = {}

MusicConfig.Tracks = {
	Main = 88201156878848 --[[ID_Music]], -- Musica/tema_principal.ogg  (loop, 2:17)
	Arena = 99117411893408 --[[ID_Music]], -- Musica/arena.ogg          (loop, 1:29)
	Boss = 119035567510005 --[[ID_Music]], -- Musica/boss.ogg            (loop, 1:28)
}

MusicConfig.Jingles = {
	LevelUp = 112107001604772 --[[ID_Music]], -- Musica/jingle_level_up.ogg
	Hatch = 79950861250342 --[[ID_Music]], -- Musica/jingle_ovo.ogg
	Victory = 95655959545310 --[[ID_Music]], -- Musica/jingle_vitoria.ogg
}

MusicConfig.MusicVolume = 0.45 -- volume das trilhas em loop (0 a 1)
MusicConfig.JingleVolume = 0.6 -- volume dos jingles
MusicConfig.Crossfade = 1.6 -- segundos da troca suave entre trilhas
MusicConfig.DuckDuringJingle = 0.35 -- fator do volume da trilha enquanto um jingle toca

return MusicConfig
