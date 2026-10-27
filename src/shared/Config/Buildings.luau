-- Todo lo que se puede construir en la base, en el orden en que se desbloquea.
--
-- Cada construcción tiene:
--   id      nombre interno (no lo cambies después de publicar: así se guarda)
--   name    lo que ve el jugador
--   stage   la etapa a la que pertenece (Buildings.stages)
--   price   cuánto cuesta
--   income  cuánto dinero suma por segundo a la base
--   kind    qué dibujo usa (src/server/Builder.luau)
--   at      dónde va dentro del terreno: { x, z }. El terreno mide 130 de ancho (x de -65 a 65)
--           y 230 de fondo: el frente (la calle) está en z = -65 y el fondo en z = 165.
--           Las etapas 1 y 2 van de z = -65 a 65, y las etapas 3 a 5 de z = 65 a 165
--   rot     giro en grados (opcional)
--   button  dónde sale su botón, si no es en el mismo lugar (opcional)
--
-- El botón de una construcción aparece cuando ya tienes la anterior de la lista.
-- Al terminar la última sale el botón de Renacer (Buildings.rebirth).

local Buildings = {}

Buildings.stages = {
	{ id = 1, name = "Campamento" },
	{ id = 2, name = "Cuartel" },
	{ id = 3, name = "Motor" },
	{ id = 4, name = "Defensa" },
	{ id = 5, name = "Comando" },
}

-- Renacer: al terminar toda la base puedes reiniciarla (pierdes la base y el dinero) a cambio
-- de que, desde entonces, todo genere más. Cada renacimiento suma bonusPerRebirth:
-- 1 renacimiento = x1.5, 2 = x2, 3 = x2.5...
Buildings.rebirth = {
	bonusPerRebirth = 0.5,
	at = { 0, 60 }, -- dónde sale su botón
}

-- El jeep sale enfrente del garaje (id "Garaje"), a esta distancia
Buildings.jeepFromGarage = 14

Buildings.list = {
	-- Etapa 1: Campamento (unos 4 minutos)
	{ id = "Bandera", name = "Bandera", stage = 1, price = 0, income = 1, kind = "Flag", at = { -30, -30 } },
	{
		id = "Sacos",
		name = "Sacos de arena",
		stage = 1,
		price = 25,
		income = 1,
		kind = "Sandbags",
		at = { 0, -42 },
	},
	{
		id = "Tienda",
		name = "Tienda de campaña",
		stage = 1,
		price = 60,
		income = 1,
		kind = "Tent",
		at = { 25, -30 },
		rot = 90,
	},
	{ id = "Fogata", name = "Fogata", stage = 1, price = 120, income = 1, kind = "Campfire", at = { 5, -22 } },
	{
		id = "Cajas",
		name = "Cajas de suministros",
		stage = 1,
		price = 200,
		income = 2,
		kind = "Crates",
		at = { -15, -18 },
	},
	{
		id = "Radio",
		name = "Antena de radio",
		stage = 1,
		price = 350,
		income = 2,
		kind = "Radio",
		at = { 48, -48 },
	},
	{
		id = "Torre",
		name = "Torre de vigilancia",
		stage = 1,
		price = 500,
		income = 2,
		kind = "Watchtower",
		at = { 48, -15 },
	},

	-- Etapa 2: Cuartel (unos 10 minutos)
	{
		id = "Generador",
		name = "Generador",
		stage = 2,
		price = 1000,
		income = 5,
		kind = "Generator",
		at = { -48, -5 },
		rot = 90,
	},
	{
		id = "Cuartel",
		name = "Cuartel",
		stage = 2,
		price = 1500,
		income = 6,
		kind = "Barracks",
		at = { -22, 22 },
	},
	{
		id = "Armeria",
		name = "Armería",
		stage = 2,
		price = 2000,
		income = 7,
		kind = "Armory",
		at = { 22, 12 },
	},
	{
		id = "CampoTiro",
		name = "Campo de tiro",
		stage = 2,
		price = 2500,
		income = 8,
		kind = "Range",
		at = { 45, 35 },
	},
	{
		id = "Comedor",
		name = "Comedor",
		stage = 2,
		price = 3000,
		income = 9,
		kind = "MessHall",
		at = { -42, 48 },
	},
	{
		id = "Muro",
		name = "Muro de concreto",
		stage = 2,
		price = 4000,
		income = 10,
		kind = "Wall",
		at = { 0, 160 },
		button = { 0, 45 },
	},
	{
		id = "Porton",
		name = "Portón de entrada",
		stage = 2,
		price = 5000,
		income = 15,
		kind = "Gate",
		at = { 0, -64 },
		button = { 0, -56 },
	},

	-- Etapa 3: Motor (unos 15 minutos). Con el garaje puedes sacar un jeep
	{ id = "Tanques", name = "Tanques de gasolina", stage = 3, price = 8000, income = 20, kind = "FuelTanks", at = { -48, 76 } },
	{ id = "Gasolinera", name = "Gasolinera", stage = 3, price = 11000, income = 25, kind = "GasStation", at = { -22, 80 } },
	{ id = "Garaje", name = "Garaje (jeep)", stage = 3, price = 15000, income = 30, kind = "Garage", at = { 5, 84 } },
	{ id = "Taller", name = "Taller mecánico", stage = 3, price = 20000, income = 35, kind = "Workshop", at = { 30, 80 } },
	{ id = "Fabrica", name = "Fábrica de jeeps", stage = 3, price = 28000, income = 45, kind = "Factory", at = { 50, 88 } },
	{ id = "Camion", name = "Camión de carga", stage = 3, price = 36000, income = 45, kind = "Truck", at = { -48, 100 }, rot = 90 },

	-- Etapa 4: Defensa (unos 30 minutos)
	{ id = "Bunker", name = "Búnker", stage = 4, price = 50000, income = 60, kind = "Bunker", at = { -18, 112 } },
	{ id = "Torreta1", name = "Torreta izquierda", stage = 4, price = 70000, income = 70, kind = "Turret", at = { -56, 128 } },
	{ id = "Torreta2", name = "Torreta derecha", stage = 4, price = 90000, income = 80, kind = "Turret", at = { 56, 128 } },
	{ id = "Radar", name = "Radar", stage = 4, price = 120000, income = 100, kind = "Radar", at = { 25, 112 } },
	{ id = "Polvorin", name = "Polvorín", stage = 4, price = 160000, income = 120, kind = "AmmoDepot", at = { -36, 132 } },
	{
		id = "Francotirador",
		name = "Torre de francotirador",
		stage = 4,
		price = 200000,
		income = 150,
		kind = "SniperTower",
		at = { 55, 108 },
	},
	{ id = "Tanque", name = "Tanque de guerra", stage = 4, price = 260000, income = 200, kind = "Tank", at = { 0, 130 } },

	-- Etapa 5: Comando (unos 40 minutos)
	{ id = "Helipuerto", name = "Helipuerto", stage = 5, price = 350000, income = 300, kind = "Helipad", at = { 32, 148 } },
	{
		id = "Helicoptero",
		name = "Helicóptero",
		stage = 5,
		price = 450000,
		income = 350,
		kind = "Helicopter",
		at = { 32, 148 },
		button = { 32, 134 },
	},
	{ id = "Hangar", name = "Hangar", stage = 5, price = 600000, income = 400, kind = "Hangar", at = { -40, 152 } },
	{
		id = "Mando",
		name = "Centro de mando",
		stage = 5,
		price = 800000,
		income = 500,
		kind = "CommandCenter",
		at = { -2, 154 },
	},
	{
		id = "Satelite",
		name = "Antena satelital",
		stage = 5,
		price = 1000000,
		income = 600,
		kind = "SatDish",
		at = { 56, 154 },
	},
	{
		id = "BanderaGigante",
		name = "Bandera gigante",
		stage = 5,
		price = 1500000,
		income = 1000,
		kind = "BigFlag",
		at = { 8, 100 },
	},
}

-- Para buscar rápido por id, y lo que pide cada una (la anterior de la lista)
Buildings.byId = {}
for i, item in Buildings.list do
	Buildings.byId[item.id] = item
	item.requires = if i > 1 then Buildings.list[i - 1].id else nil
end

-- ¿Es la última de su etapa?
function Buildings.IsLastOfStage(id: string): boolean
	for i, item in Buildings.list do
		if item.id == id then
			local nextItem = Buildings.list[i + 1]
			return nextItem == nil or nextItem.stage ~= item.stage
		end
	end
	return false
end

return Buildings
