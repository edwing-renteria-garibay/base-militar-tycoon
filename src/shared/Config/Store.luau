-- Lo que se vende con Robux, y el premio diario.
--
-- Pases de juego (Game Passes): se compran una vez y son para siempre. Paquetes (Developer
-- Products): se pueden comprar las veces que quieran. Los dos se crean en el Creator
-- Dashboard (ver docs/aprende/02-olas-y-tienda.md) y aquí se pone su ID. Los que tengan
-- id = 0 salen en la tienda como "Próximamente".

local Store = {}

Store.passes = {
	{ key = "x2", id = 0, name = "x2 Dinero", robux = 299, description = "Tu caja fuerte junta el doble para siempre" },
	{
		key = "AutoCobrar",
		id = 0,
		name = "Auto-cobrar",
		robux = 199,
		description = "El dinero entra solo, sin ir a la caja fuerte",
	},
	{ key = "VIP", id = 0, name = "VIP", robux = 249, description = "+20% de dinero y nombre dorado" },
	{
		key = "MunicionX2",
		id = 0,
		name = "Munición x2",
		robux = 149,
		description = "Cada paquete de munición de la armería trae el doble",
	},
}

Store.vipBonus = 0.2 -- el VIP genera 20% más

-- Qué da cada paquete (kind):
--   "money"     dinero
--   "defense"   amount defensas premium (Config/Premium, misma key) que se colocan donde quieras
--   "antidote"  amount antídotos
--   "nuke"      una bomba que mata a todos los zombis de la ola (botón durante la ola, o N)
--   "airstrike" un ataque aéreo sobre el lado con más zombis (botón durante la ola, o J)
--   "life"      una vida extra: si destruyen tu caja fuerte, repites esa ola en vez de volver
--               a la 1 (se usa sola)
--   "repair"    repara en seguida el muro, las barricadas, los edificios y la caja fuerte
--   "squad"     llegan soldados que pelean contigo una ola (Store.squad)
--   "starter"   el paquete inicial (Store.starter); once = solo se puede comprar una vez
Store.products = {
	{
		key = "Bolsa",
		kind = "money",
		id = 0,
		name = "Bolsa de dinero",
		robux = 49,
		seconds = 600, -- da lo que genera tu base en 10 minutos...
		minimum = 2000, -- ...y nunca menos de esto
	},
	{
		key = "TorretaPesada",
		kind = "defense",
		id = 0,
		name = "Torreta pesada",
		robux = 99,
		description = "Dispara a todos lados. La pones donde quieras",
	},
	{
		key = "BarricadaAcero",
		kind = "defense",
		id = 0,
		name = "Barricada de acero",
		robux = 49,
		description = "Aguanta 3,000 golpes. La pones donde quieras",
	},
	{
		key = "Mina",
		kind = "defense",
		amount = 3,
		id = 0,
		name = "3 minas",
		robux = 39,
		description = "Las pones donde quieras, también dentro de tu base",
	},
	{
		key = "Antidotos",
		kind = "antidote",
		amount = 3,
		id = 0,
		name = "3 antídotos",
		robux = 25,
		description = "Te quitan la infección del zombi corrosivo",
	},
	{
		key = "Bomba",
		kind = "nuke",
		id = 0,
		name = "Bomba: matar a todos",
		robux = 79,
		description = "Acaba con todos los zombis de la ola (úsala con N)",
	},
	{
		key = "VidaExtra",
		kind = "life",
		id = 0,
		name = "Vida extra",
		robux = 49,
		description = "Si destruyen tu caja fuerte, sigues en esa ola",
	},
	{
		key = "Reparacion",
		kind = "repair",
		id = 0,
		name = "Reparación total",
		robux = 25,
		description = "Todo tu muro, barricadas, edificios y caja fuerte al 100% en seguida",
	},
	{
		key = "Refuerzos",
		kind = "squad",
		id = 0,
		name = "Refuerzos",
		robux = 49,
		description = "3 soldados pelean contigo durante una ola",
	},
	{
		key = "AtaqueAereo",
		kind = "airstrike",
		id = 0,
		name = "Ataque aéreo",
		robux = 35,
		description = "Bombardea el lado con más zombis (úsalo con J)",
	},
	{
		key = "PaqueteInicial",
		kind = "starter",
		once = true,
		id = 0,
		name = "Paquete inicial",
		robux = 99,
		description = "$25,000 + torreta pesada + 3 botiquines. Solo una vez",
	},
}

-- Los refuerzos: soldados junto a la caja fuerte que disparan solos (como una torreta)
Store.squad = { count = 3, damage = 30, range = 110, cooldown = 0.35, sound = "AssaultRifle" }

-- El ataque aéreo: explosiones a lo largo del lado, afuera del muro. Mata a los zombis que
-- alcanza
Store.airstrike = { bombs = 8, radius = 22 }

-- El paquete inicial
Store.starter = { money = 25000, defense = "TorretaPesada", medkits = 3 }

-- Premio diario: al entrar una vez al día. Si entras días seguidos sube; si faltas un día
-- vuelve a empezar. Da "minutos de lo que genera tu base" (día 1 = 2 minutos...), y nunca
-- menos de minimum
Store.daily = {
	minutes = { 2, 3, 4, 5, 6, 8, 10 },
	minimum = 200,
}

return Store
