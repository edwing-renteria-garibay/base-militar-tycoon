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
		recoil = 7,
		zoom = 18,
		ammo = { amount = 15, price = 200 },
	},
}

Weapons.byId = {}
for _, weapon in Weapons.list do
	Weapons.byId[weapon.id] = weapon
end

return Weapons
