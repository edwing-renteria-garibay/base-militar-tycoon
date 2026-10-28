-- Las armas del jugador. El Rifle lo tiene todo el mundo y no se le acaban las balas; las
-- demás se compran en la Armería (y ahí mismo su munición).
--
--   damage    daño por bala (el Laboratorio lo multiplica, ver Waves.labBonus)
--   pellets   balas por disparo (la escopeta); spread = qué tanto se abren, en grados
--   cooldown  segundos entre disparos (mantén el clic para disparar seguido)
--   range     alcance en studs
--   sound     su sonido de disparo (Config/Sounds, fire)
--   ammo      la munición: cuántas balas trae cada paquete y cuánto cuesta. Sin ammo = infinita
--   size      largo del arma (solo para dibujarla)
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
		size = 3,
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
		ammo = { amount = 24, price = 150 },
		size = 3.4,
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
		ammo = { amount = 200, price = 300 },
		size = 4,
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
		ammo = { amount = 15, price = 200 },
		size = 5,
	},
}

Weapons.byId = {}
for _, weapon in Weapons.list do
	Weapons.byId[weapon.id] = weapon
end

return Weapons
