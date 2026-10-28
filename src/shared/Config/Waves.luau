-- Las olas de enemigos: cada cierto tiempo llegan soldados enemigos por la calle e intentan
-- robar tu caja fuerte. Los detienes con tu rifle y con tus construcciones de defensa.

local Waves = {}

Waves.startAfter = "Torre" -- las olas empiezan cuando ya tienes esta construcción (fin de la etapa 1)
Waves.interval = 150 -- segundos entre una ola y la siguiente

-- Cuántos enemigos llegan: base + uno más por cada etapa que hayas alcanzado (hasta max)
Waves.baseEnemies = 2
Waves.maxEnemies = 8
Waves.enemyHealth = 100 -- vida en la etapa 1...
Waves.healthPerStage = 50 -- ...y esto más por cada etapa siguiente
Waves.enemySpeed = 9 -- un jugador camina a 16

Waves.stealShare = 0.25 -- parte de la caja fuerte que se roba cada enemigo que llega a ella
-- Premios en "segundos de lo que genera tu base" (así sirven igual al principio que al final)
Waves.killSeconds = 4 -- por cada enemigo eliminado
Waves.waveSeconds = 30 -- por eliminar a toda la ola
Waves.minimumReward = 50 -- lo menos que da un premio

-- Tu rifle: daño por disparo, segundos entre disparos y alcance en studs
Waves.rifle = { damage = 34, cooldown = 0.25, range = 300 }

-- Construcciones que disparan solas a los enemigos: daño por disparo y alcance en studs
Waves.defenders = {
	Torre = { damage = 10, range = 70 },
	Bunker = { damage = 15, range = 60 },
	Torreta1 = { damage = 30, range = 100 },
	Torreta2 = { damage = 30, range = 100 },
	Francotirador = { damage = 60, range = 160 },
	Tanque = { damage = 90, range = 110 },
	Helicoptero = { damage = 50, range = 200 },
}
Waves.defenderCooldown = 1.5 -- segundos entre disparos de cada construcción

return Waves
