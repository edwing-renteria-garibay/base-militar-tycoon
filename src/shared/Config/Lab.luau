-- El laboratorio infestado (src/server/Services/LabService.luau): uno por servidor, al final de
-- la calle. Para llegar a la frecuencia de la cura hay que cruzar un laberinto de túneles de
-- metal (con techo) lleno de zombis. Solo entra quien ya pasó la ola "minRecord" (en Studio entra cualquiera, para
-- probarlo). Con la frecuencia, tu caja fuerte se vuelve antena y transmite la cura (victoria).

local Lab = {}

Lab.minRecord = 25
Lab.cells = 8 -- el laberinto es de cells x cells cuadros
Lab.cellSize = 18 -- studs de cada cuadro
Lab.wallHeight = 14
Lab.seed = 2025 -- el laberinto se arma igual en todos los servidores (cámbialo para otro)
Lab.holdTime = 3 -- segundos que hay que mantener E para tomar la frecuencia

-- Los zombis de adentro: siempre hay "alive" (salen otros en cuadros lejos de los jugadores)
Lab.zombies = {
	alive = 24,
	health = 900,
	speed = 13,
	damage = 20, -- por golpe a un jugador (uno por segundo)
	sight = 60, -- a esta distancia te ven (si no hay pared en medio)
	respawn = 2, -- segundos entre uno nuevo y el siguiente
	-- Parte de ellos son infecciosos (verdes): su golpe te infecta (pierdes vida hasta usar un
	-- antídoto, Waves.infection). ¡Lleva antídotos!
	infectShare = 0.5,
	infectColor = Color3.fromRGB(90, 200, 60),
}

-- Las tarjetas: están escondidas en callejones sin salida del laberinto. Sin las "count" no
-- pasas la puerta láser del laboratorio. Hay que juntarlas otra vez para cada frecuencia
Lab.cards = { count = 3, holdTime = 1 }

-- El guardián: un zombi enorme que cuida la terminal (mientras viva, no puedes tomar la
-- frecuencia). Su golpe infecta. Si lo matan, vuelve a salir a los "respawn" segundos
Lab.guardian = { health = 6000, speed = 11, damage = 45, scale = 2.2, respawn = 90, reward = 20000 }

-- La alarma: al tomar la frecuencia suena y por "duration" segundos todos los zombis del
-- laberinto te huelen (te persiguen aunque haya paredes) y salen "extra" más
Lab.alarm = { duration = 45, extra = 16, smell = 250 }

-- La transmisión: en la antena se tarda "duration" segundos y mientras tanto llega a tu base
-- una ola final (zombis de la ola "level", uno cada "spawnEvery" s, y jefes). Si destruyen tu
-- caja fuerte, la transmisión falla (no pierdes la frecuencia: puedes volver a intentarlo)
Lab.final = { duration = 60, zombies = 40, spawnEvery = 1.4, level = 30, bosses = 2 }

-- La victoria: tu base vuelve a empezar, pero cada victoria da para siempre este extra de dinero
Lab.victoryBonus = 0.5 -- +50% por cada vez que transmites la cura

return Lab
