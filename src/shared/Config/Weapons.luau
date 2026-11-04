-- Las armas del jugador. El Rifle lo tiene todo el mundo y no se le acaban las balas; las
-- demás se compran en la Armería (y ahí mismo su munición).
--
--   damage    daño por bala (lo sube lo investigado en el Laboratorio, Config/Research)
--   pellets   balas por disparo (la escopeta); spread = qué tanto se abren, en grados
--   cooldown  segundos entre disparos (mantén el clic para disparar seguido)
--   range     alcance en studs
--   sound     su sonido de disparo (Config/Sounds, fire)
--   recoil    grados que sube la mira al disparar (escopeta y francotirador)
--   zoom      campo de visión al apuntar con clic derecho (el normal es 70)
--   ammo      la munición: cuántas balas trae cada paquete y cuánto cuesta. Sin ammo = infinita
--   magazine  balas por cargador; al vaciarlo se recarga solo (o con la tecla R)
--   reload    segundos que tarda en recargar
--   headshot  cuánto multiplica el daño un tiro en la cabeza (si no dice, Weapons.headshot)
--   modPrice  lo que cuesta cada mejora de esta arma en la Armería (Weapons.mods)
--
-- Su forma (las piezas) está en src/shared/WeaponModels.luau, con el mismo id.
--
-- No cambies el id de un arma después de publicar: así se guarda quién la compró.

local Weapons = {}

Weapons.list = {
	{
		id = "Rifle",
		name = "Rifle",
		description = "Balas infinitas",
		price = 0,
		damage = 34,
		cooldown = 0.3,
		range = 300,
		sound = "AssaultRifle",
		magazine = 30,
		reload = 1.8,
		modPrice = 1500,
	},
	{
		id = "Escopeta",
		name = "Escopeta",
		description = "6 balas por tiro, de cerca destroza",
		price = 2500,
		damage = 20,
		pellets = 6,
		spread = 5,
		cooldown = 0.8,
		range = 90,
		sound = "Shotgun",
		recoil = 6,
		magazine = 6,
		reload = 2.4,
		modPrice = 2000,
		ammo = { amount = 24, price = 150 },
	},
	{
		id = "Ametralladora",
		name = "Ametralladora",
		description = "Dispara muy rápido",
		price = 6000,
		damage = 28,
		cooldown = 0.09,
		range = 250,
		sound = "AssaultRifle",
		magazine = 60,
		reload = 3,
		modPrice = 3000,
		ammo = { amount = 200, price = 300 },
	},
	{
		id = "Francotirador",
		name = "Rifle de francotirador",
		description = "Un tiro, un zombi",
		price = 10000,
		damage = 300,
		cooldown = 1.3,
		range = 700,
		sound = "Sniper",
		recoil = 4,
		headshot = 3,
		magazine = 5,
		reload = 2.5,
		modPrice = 4000,
		zoom = 18,
		ammo = { amount = 15, price = 200 },
	},
}

-- Un tiro en la cabeza hace este múltiplo del daño (el rifle mata de un tiro en la cabeza a los
-- zombis de la ola 1)
Weapons.headshot = 2

-- Mejoras que se compran en la Armería para cada arma (una vez cada una; se guardan para siempre)
--   magazine  multiplica las balas del cargador
--   recoil, spread  multiplican el retroceso y lo que se abren las balas (menos = más preciso)
--   headshot  multiplica el daño de los tiros en la cabeza
Weapons.mods = {
	{ key = "Cargador", name = "Cargador grande", description = "+50% de balas por cargador", magazine = 1.5 },
	{
		key = "Mira",
		name = "Mira precisa",
		description = "La mitad de retroceso y dispersión, +25% de daño en la cabeza",
		recoil = 0.5,
		spread = 0.5,
		headshot = 1.25,
	},
}
Weapons.modById = {}
for _, mod in Weapons.mods do
	Weapons.modById[mod.key] = mod
end

-- Cuánto vale una estadística del arma con sus mejoras. has(modKey) dice si tiene esa mejora
function Weapons.Stat(weapon, stat: string, has: (string) -> boolean): number
	local base = if stat == "headshot" then weapon.headshot or Weapons.headshot else weapon[stat] or 0
	for _, mod in Weapons.mods do
		if mod[stat] and has(mod.key) then
			base *= mod[stat]
		end
	end
	return if stat == "magazine" then math.floor(base) else base
end

Weapons.byId = {}
for _, weapon in Weapons.list do
	Weapons.byId[weapon.id] = weapon
end

return Weapons
