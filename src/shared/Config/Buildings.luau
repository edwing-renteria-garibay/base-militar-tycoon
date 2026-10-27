-- Todo lo que se puede construir en la base, en el orden en que se desbloquea.
--
-- Cada construcción tiene:
--   id      nombre interno (no lo cambies después de publicar: así se guarda)
--   name    lo que ve el jugador
--   stage   la etapa a la que pertenece (Buildings.stages)
--   price   cuánto cuesta
--   income  cuánto dinero suma por segundo a la base
--   kind    qué dibujo usa (src/server/Builder.luau)
--   at      dónde va dentro del terreno: { x, z }. El terreno mide 130 x 130; el centro es
--           { 0, 0 } y el frente (la calle) está en z = -65
--   rot     giro en grados (opcional)
--   button  dónde sale su botón, si no es en el mismo lugar (opcional)
--
-- El botón de una construcción aparece cuando ya tienes la anterior de la lista.

local Buildings = {}

Buildings.stages = {
	{ id = 1, name = "Campamento" },
	{ id = 2, name = "Cuartel" },
}

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
		at = { 0, 60 },
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
