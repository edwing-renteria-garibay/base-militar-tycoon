-- Todo lo que se compra en la base, cada cosa en su lugar marcado.
--
-- El terreno es un cuadrado con la caja fuerte en el centro { 0, 0 }. El frente (la calle)
-- es -Z. El muro va a 70 del centro (Config/Waves, wallInset) y afuera del muro queda el
-- anillo de defensas. Los zombis llegan desde más afuera, por uno o varios lados.
--
-- Cada cosa tiene:
--   id       nombre interno (no lo cambies después de publicar: así se guarda)
--   name     lo que ve el jugador
--   price    cuánto cuesta
--   kind     qué dibujo usa (src/server/Builder.luau). Sin kind = es una mejora, no se dibuja
--   at       dónde va: { x, z }
--   rot      giro en grados (opcional)
--   button   dónde sale su botón, si no es en el mismo lugar (opcional; lo de afuera del muro
--            tiene el botón adentro, para que no tengas que salir)
--   requires lo que necesitas tener antes (opcional)
--   defense  si dispara sola a los zombis: { damage, range, cooldown, sound } (opcional)
--   oneUse   se gasta al usarse (las minas): al explotar, su botón vuelve a salir
--   effect   para qué sirve (lo leen los servicios): "vault", "wall", "armory", "heal",
--            "damage", "repair", "radar", "fire", "wire", "mine", "barricade"

local Buildings = {}

Buildings.list = {}

local function add(item)
	table.insert(Buildings.list, item)
	return item
end

-- Mejoras de la caja fuerte: cada nivel genera más dinero (Waves.vaultIncome)
local vaultPrices = { 500, 2500, 10000, 40000 }
for level = 2, 5 do
	add({
		id = "Caja" .. level,
		name = "Caja fuerte nivel " .. level,
		price = vaultPrices[level - 1],
		at = { 16, 0 },
		requires = if level > 2 then "Caja" .. (level - 1) else nil,
		effect = "vault",
		level = level,
	})
end

-- Mejoras del muro: más vida (Waves.wallHealth)
add({ id = "Muro2", name = "Muro de concreto", price = 3000, at = { -16, 0 }, effect = "wall", level = 2 })
add({
	id = "Muro3",
	name = "Muro reforzado",
	price = 20000,
	at = { -16, 0 },
	requires = "Muro2",
	effect = "wall",
	level = 3,
})

-- Edificios con función
add({
	id = "Armeria",
	name = "Armería (armas y munición)",
	price = 1500,
	kind = "Armory",
	at = { 38, -30 },
	effect = "armory",
})
add({
	id = "Gasolinera",
	name = "Gasolinera (zanjas de fuego)",
	price = 2000,
	kind = "GasStation",
	at = { -38, -30 },
	effect = "fire",
})
add({ id = "Enfermeria", name = "Enfermería (te cura)", price = 2500, kind = "Infirmary", at = { 0, 40 }, effect = "heal" })
add({ id = "Taller", name = "Taller (repara el muro solo)", price = 4000, kind = "Workshop", at = { -38, 30 }, effect = "repair" })
add({ id = "Radar", name = "Radar (ves a los zombis)", price = 6000, kind = "Radar", at = { 38, 30 }, effect = "radar" })

-- Laboratorio: más daño para todo (Waves.labBonus). Las mejoras salen junto a él
add({
	id = "Laboratorio",
	name = "Laboratorio (+25% de daño)",
	price = 5000,
	kind = "Lab",
	at = { 38, 2 },
	effect = "damage",
	level = 2,
})
add({
	id = "Lab3",
	name = "Investigación (+50% de daño)",
	price = 15000,
	at = { 24, 2 },
	requires = "Laboratorio",
	effect = "damage",
	level = 3,
})
add({
	id = "Lab4",
	name = "Investigación avanzada (x2 daño)",
	price = 40000,
	at = { 24, 2 },
	requires = "Lab3",
	effect = "damage",
	level = 4,
})

-- Torres de francotirador, una en cada esquina
local towerPrices = { 1500, 3000, 5000, 8000 }
for i, corner in { { -60, -60 }, { 60, -60 }, { -60, 60 }, { 60, 60 } } do
	add({
		id = "Torre" .. i,
		name = "Torre de francotirador",
		price = towerPrices[i],
		kind = "SniperTower",
		at = corner,
		defense = { damage = 40, range = 160, cooldown = 1.5, sound = "Sniper" },
	})
end

-- Lo de cada lado. Frente = la calle; luego derecha, atrás e izquierda
Buildings.sides = {
	{ key = "Frente", name = "frente", rot = 0 },
	{ key = "Derecha", name = "derecha", rot = -90 },
	{ key = "Atras", name = "atrás", rot = 180 },
	{ key = "Izquierda", name = "izquierda", rot = 90 },
}

-- Gira un punto { x, z } del lado de enfrente al lado que mira hacia rot grados
local function turn(x: number, z: number, rot: number): { number }
	local r = math.rad(rot)
	local nx = x * math.cos(r) + z * math.sin(r)
	local nz = -x * math.sin(r) + z * math.cos(r)
	return { math.floor(nx * 100 + 0.5) / 100, math.floor(nz * 100 + 0.5) / 100 }
end

local turretPrices = { 2500, 4000, 6000, 4000 }
for i, side in Buildings.sides do
	local function place(x: number, z: number)
		return turn(x, z, side.rot)
	end
	add({
		id = "Torreta_" .. side.key,
		name = "Torreta (" .. side.name .. ")",
		price = turretPrices[i],
		kind = "Turret",
		at = place(0, -58),
		rot = side.rot,
		defense = { damage = 15, range = 90, cooldown = 0.6, sound = "AssaultRifle" },
	})
	for j, x in { -40, 40 } do
		add({
			id = "Barricada_" .. side.key .. j,
			name = "Barricada de concreto",
			price = 500,
			kind = "Barricade",
			at = place(x, -77),
			rot = side.rot,
			button = place(x, -64),
			effect = "barricade",
		})
	end
	for j, x in { -20, 20 } do
		add({
			id = "Alambre_" .. side.key .. j,
			name = "Alambre de púas",
			price = 300,
			kind = "Wire",
			at = place(x, -83),
			rot = side.rot,
			button = place(x, -64),
			effect = "wire",
		})
	end
	add({
		id = "Zanja_" .. side.key,
		name = "Zanja de gasolina",
		price = 1500,
		kind = "FireTrench",
		at = place(0, -89),
		rot = side.rot,
		button = place(0, -66),
		requires = "Gasolinera",
		effect = "fire",
	})
	for j, x in { -9, 9 } do
		add({
			id = "Mina_" .. side.key .. j,
			name = "Mina",
			price = 150,
			kind = "Mine",
			at = place(x, -95),
			rot = side.rot,
			button = place(x, -64),
			effect = "mine",
			oneUse = true,
		})
	end
end

-- Para buscar rápido por id
Buildings.byId = {}
for _, item in Buildings.list do
	Buildings.byId[item.id] = item
end

-- El nivel de algo (caja fuerte, muro, laboratorio) según las mejoras que tiene: 1 si ninguna
function Buildings.LevelOf(owned: { [string]: boolean }, effect: string): number
	local level = 1
	for id in owned do
		local item = Buildings.byId[id]
		if item and item.effect == effect and item.level and item.level > level then
			level = item.level
		end
	end
	return level
end

return Buildings
