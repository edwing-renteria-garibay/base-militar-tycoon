-- El laboratorio infestado (src/server/Services/LabService.luau): uno por servidor, al final de
-- la calle. Para llegar a la frecuencia de la cura hay que cruzar un laberinto de metal lleno
-- de zombis. Solo entra quien ya pasó la ola "minRecord" (en Studio entra cualquiera, para
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
}

-- La victoria: tu base vuelve a empezar, pero cada victoria da para siempre este extra de dinero
Lab.victoryBonus = 0.5 -- +50% por cada vez que transmites la cura

return Lab
