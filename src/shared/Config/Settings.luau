-- Ajustes generales del juego. Cambia estos números y vuelve a publicar.

local Settings = {}

-- Modo de prueba: empiezas con mucho dinero y no se guarda nada. Se prende solo al darle
-- Play en Studio; en el juego publicado siempre está apagado (ya no hay que cambiarlo a mano)
Settings.Testing = {
	enabled = game:GetService("RunService"):IsStudio(),
	startMoney = 10000000, -- alcanza para toda la base
	premium = 2, -- de cada defensa premium, para probar a colocarlas sin pagar Robux
}

Settings.startMoney = 0 -- con lo que empieza un jugador nuevo
Settings.plotCount = 6 -- terrenos en el mapa (pon el servidor de 6 jugadores en el Dashboard)
Settings.saveKey = "BaseMilitarPerfiles" -- nombre del DataStore. Si lo cambias, todos empiezan de cero
Settings.autosave = 120 -- cada cuántos segundos se guarda a todos

return Settings
