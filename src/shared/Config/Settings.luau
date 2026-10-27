-- Ajustes generales del juego. Cambia estos números y vuelve a publicar.

local Settings = {}

-- Modo de prueba: empiezas con mucho dinero y no se guarda nada. Apágalo antes de publicar
Settings.Testing = {
	enabled = false,
	startMoney = 100000,
}

Settings.startMoney = 0 -- con lo que empieza un jugador nuevo
Settings.plotCount = 6 -- terrenos en el mapa (pon el servidor de 6 jugadores en el Dashboard)
Settings.saveKey = "BaseMilitarPerfiles" -- nombre del DataStore. Si lo cambias, todos empiezan de cero
Settings.autosave = 120 -- cada cuántos segundos se guarda a todos

return Settings
