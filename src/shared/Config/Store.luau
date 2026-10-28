-- Lo que se vende con Robux, y el premio diario.
--
-- Pases de juego (Game Passes): se compran una vez y son para siempre. Paquetes (Developer
-- Products): se pueden comprar las veces que quieran. Los dos se crean en el Creator
-- Dashboard (ver docs/aprende/02-olas-y-tienda.md) y aquí se pone su ID. Los que tengan
-- id = 0 salen en la tienda como "Próximamente".

local Store = {}

Store.passes = {
	{ key = "x2", id = 0, name = "x2 Dinero", robux = 299, description = "Tu base genera el doble para siempre" },
	{
		key = "AutoCobrar",
		id = 0,
		name = "Auto-cobrar",
		robux = 199,
		description = "El dinero entra solo, sin ir a la caja fuerte",
	},
	{ key = "VIP", id = 0, name = "VIP", robux = 249, description = "+20% de dinero y nombre dorado" },
	{ key = "JeepOro", id = 0, name = "Jeep dorado", robux = 149, description = "Tu jeep sale de oro" },
}

Store.vipBonus = 0.2 -- el VIP genera 20% más

Store.products = {
	{
		key = "Bolsa",
		id = 0,
		name = "Bolsa de dinero",
		robux = 49,
		seconds = 600, -- da lo que genera tu base en 10 minutos...
		minimum = 2000, -- ...y nunca menos de esto
	},
}

-- Premio diario: al entrar una vez al día. Si entras días seguidos sube; si faltas un día
-- vuelve a empezar. Da "minutos de lo que genera tu base" (día 1 = 2 minutos...), y nunca
-- menos de minimum
Store.daily = {
	minutes = { 2, 3, 4, 5, 6, 8, 10 },
	minimum = 200,
}

return Store
