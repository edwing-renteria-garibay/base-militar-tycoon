-- Las olas de zombis y todo lo que sirve para defenderte de ellas. Cambia estos números para
-- hacer el juego más fácil o más difícil.
--
-- Las olas van numeradas: la 1 es fácil y cada una trae más zombis, con más vida y más
-- rápidos, y por más lados. Tu récord es la ola más alta que has pasado. Si los zombis
-- destruyen tu caja fuerte, vuelves a la ola 1.

local Waves = {}

-- Tiempos (en segundos). En modo de prueba (Config/Settings) son más cortos
Waves.firstDelay = 60 -- al entrar, antes de la primera ola
Waves.breakTime = 40 -- descanso entre una ola y la siguiente
Waves.testingFirstDelay = 20
Waves.testingBreakTime = 15

-- Cómo es la ola número n
function Waves.CountOf(n: number): number -- cuántos zombis
	return math.min(4 + 2 * n, 40)
end
function Waves.HealthOf(n: number): number -- vida de cada zombi
	return 60 + 25 * n
end
function Waves.SpeedOf(n: number): number -- velocidad (un jugador camina a 16)
	return math.min(8 + 0.4 * n, 14)
end
function Waves.SidesOf(n: number): number -- por cuántos lados atacan (1 a 4)
	if n <= 2 then
		return 1
	elseif n <= 5 then
		return 2
	elseif n <= 9 then
		return 3
	end
	return 4
end

Waves.spawnDistance = 105 -- a qué distancia del centro aparecen (afuera del terreno)
Waves.spawnSpread = 50 -- se reparten a lo ancho: de -50 a 50
Waves.spawnEvery = 1 -- segundos entre un zombi y el siguiente

-- Lo que hacen los zombis
Waves.zombieDps = 20 -- daño por segundo a muros, barricadas y la caja fuerte
Waves.playerHit = 15 -- daño por golpe a un jugador (un golpe por segundo)

-- La caja fuerte
Waves.vaultHealth = 2000
Waves.lossShare = 0.25 -- si la destruyen, se llevan esta parte del dinero que tenía adentro
Waves.vaultIncome = { 5, 15, 40, 100, 250 } -- dinero por segundo según su nivel (1 a 5)

-- Premios
function Waves.KillReward(n: number): number -- por cada zombi en la ola n
	return 4 + n
end
function Waves.WaveReward(n: number): number -- por pasar la ola n
	return 100 * n
end

-- Tu rifle según el nivel de arma (1 = el de siempre, 2 = Armería, 3 = Arsenal):
-- daño por disparo y segundos entre disparos
Waves.rifle = {
	{ damage = 34, cooldown = 0.3 },
	{ damage = 50, cooldown = 0.2 },
	{ damage = 70, cooldown = 0.12 },
}
Waves.rifleRange = 300

-- El muro: vida de cada pedazo según su nivel (1 = madera, 2 = concreto, 3 = reforzado)
Waves.wallHealth = { 200, 600, 1500 }
Waves.wallInset = 70 -- distancia del centro al muro
Waves.barricadeHealth = 800

-- Reparar: el taller repara solo esta parte de la vida cada segundo; a mano cuesta esto por
-- cada punto de vida
Waves.workshopRepair = 0.03
Waves.repairCost = 0.5

-- Defensas de afuera del muro
Waves.wire = { slow = 0.4, dps = 8 } -- el alambre frena (40% de su velocidad) y lastima
Waves.mine = { damage = 200, radius = 12, trigger = 5 } -- explota al pisarla; se gasta
Waves.fire = { dps = 40, duration = 10, cooldown = 60 } -- las zanjas de gasolina encendidas

return Waves
