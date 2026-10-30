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
-- Daño por segundo de un zombi a muros, construcciones y la caja fuerte en la ola n (sube
-- con cada ola; los especiales lo multiplican)
function Waves.DpsOf(n: number): number
	return 15 + 5 * n
end
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

-- Las torretas solo disparan hacia su frente: este es su ángulo de vista, en grados (45 = 22.5
-- a cada lado)
Waves.turretArc = 45

-- La enfermería cura esto por segundo si estás cerca (a menos de healRange studs)
Waves.heal = 20
Waves.healRange = 16
-- Botiquines: se compran en la enfermería (mantén E) y se usan desde la barra de abajo, donde
-- sea. Cada uno cura "heal" de vida. Puedes cargar hasta "max"
Waves.medkit = { price = 200, heal = 60, max = 5 }
-- Infección (la del zombi corrosivo): te quita dps de vida por segundo hasta que usas un
-- antídoto (se compran en la enfermería) o mueres. Los botiquines curan vida, no la infección
Waves.infection = { dps = 2 }
Waves.antidote = { price = 300, max = 3 }

-- El muro: vida de cada pedazo según su nivel (1 = madera, 2 = concreto, 3 = reforzado)
Waves.wallHealth = { 200, 600, 1500 }
Waves.wallInset = 70 -- distancia del centro al muro

-- Vida de las construcciones (los zombis también las rompen). Rota, una construcción deja de
-- funcionar hasta que la reparas
Waves.buildingHealth = {
	Barricade = 800,
	SniperTower = 1500,
	Turret = 800,
	HeavyTurret = 2000, -- las premium (Config/Premium)
	SteelBarricade = 3000,
	default = 1000,
}

-- Los francotiradores que contratas en las torres (mantén E al pie de la torre). Si mueren
-- (por un zombi trepador, o por un disparo tuyo) hay que volver a contratarlos
Waves.sniper = { price = 500, health = 150 }

-- Zombis especiales: a partir de la ola "from", uno de cada "every" zombis es de ese tipo.
--   health, speed, dps  multiplican la vida, la velocidad y el daño de un zombi normal
--   target              a qué va: "tower" (torres y su francotirador; además trepa el muro),
--                       "building" (edificios) o "defense" (torres y torretas). Sin target
--                       va a la caja fuerte, como uno normal
--   explode             explota al llegar al muro, a algo que le tape el paso, a la caja o a
--                       un jugador: daño a lo que esté en radius (y playerDamage a jugadores).
--                       Con infect, los jugadores que alcanza quedan infectados (Waves.infection)
Waves.special = {
	{
		key = "Trepador",
		name = "trepador",
		from = 3,
		every = 5,
		health = 0.7,
		speed = 1.3,
		dps = 1,
		target = "tower",
		shirt = Color3.fromRGB(110, 60, 140),
		scale = 0.9,
	},
	{
		key = "Demoledor",
		name = "demoledor",
		from = 4,
		every = 7,
		health = 3,
		speed = 0.7,
		dps = 3,
		target = "building",
		shirt = Color3.fromRGB(220, 110, 30),
		scale = 1.4,
	},
	{
		key = "Saboteador",
		name = "saboteador",
		from = 5,
		every = 6,
		health = 1.2,
		speed = 1.1,
		dps = 2,
		target = "defense",
		shirt = Color3.fromRGB(200, 190, 40),
		scale = 1,
	},
	{
		key = "Explosivo", -- (no cambiar la key; en el juego se llama "corrosivo")
		name = "corrosivo",
		from = 6,
		every = 8,
		health = 0.8,
		speed = 1.2,
		dps = 1,
		shirt = Color3.fromRGB(90, 140, 40),
		scale = 1.1,
		explode = { damage = 400, radius = 12, playerDamage = 50, infect = true },
	},
}
Waves.climbTime = 2 -- segundos que tarda un trepador en subir el muro o una torre
Waves.emptyTowerDamage = 2 -- arriba de una torre sin francotirador, la rompe así de más rápido

-- Reparar: el taller repara solo esta parte de la vida cada segundo, pero solo en el descanso
-- entre olas; a mano cuesta esto por cada punto de vida
Waves.workshopRepair = 0.02
Waves.repairCost = 0.5

-- Defensas de afuera del muro
Waves.wire = { slow = 0.4, dps = 8 } -- el alambre frena (40% de su velocidad) y lastima
Waves.mine = { damage = 200, radius = 12, trigger = 5 } -- explota al pisarla; se gasta
Waves.fire = { dps = 40, duration = 10, cooldown = 60 } -- las zanjas de gasolina encendidas

return Waves
