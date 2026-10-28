-- ¿Se puede poner una defensa premium aquí? Lo usan el servidor (para aceptar) y la pantalla
-- de colocar (para pintar la vista previa de verde o rojo).
--
-- Las posiciones son dentro del terreno: x y z de -100 a 100, con la caja fuerte en { 0, 0 }.
-- No se puede encimar en:
--   - los lugares marcados de Config/Buildings (lo tengas comprado o no) y sus botones
--   - la caja fuerte, el muro y el lugar donde apareces
--   - otras defensas premium ya colocadas

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Buildings = require(ReplicatedStorage.Shared.Config.Buildings)
local Waves = require(ReplicatedStorage.Shared.Config.Waves)

local Placement = {}

local EDGE = 96 -- hasta dónde se puede poner (el terreno llega a 100)
local BUTTON_RADIUS = 3.5
-- Medio ancho y medio fondo de cada construcción (como están en Builder.luau)
local HALF_SIZE = {
	Armory = Vector2.new(7.5, 8.5),
	GasStation = Vector2.new(8.5, 5.5),
	Infirmary = Vector2.new(8, 6),
	Workshop = Vector2.new(6.5, 5.5),
	Radar = Vector2.new(3, 3),
	Lab = Vector2.new(7.5, 6.5),
	SniperTower = Vector2.new(3.3, 4.5),
	Turret = Vector2.new(3.5, 3.5),
	Barricade = Vector2.new(8, 1.7),
	Wire = Vector2.new(8.5, 1.5),
	FireTrench = Vector2.new(33, 2),
	Mine = Vector2.new(1.5, 1.5),
}

-- Los lugares marcados: rectángulos (con su giro) y círculos
type Rect = { x: number, z: number, half: Vector2, rot: number }
local rects: { Rect } = {}
local circles: { { x: number, z: number, r: number } } = {
	{ x = 0, z = 0, r = 8 }, -- la caja fuerte
	{ x = 0, z = -16, r = 4 }, -- donde apareces
}
for _, item in Buildings.list do
	if item.kind then
		local half = HALF_SIZE[item.kind] or Vector2.new(8, 8)
		table.insert(rects, { x = item.at[1], z = item.at[2], half = half, rot = item.rot or 0 })
	end
	local button = item.button or item.at
	table.insert(circles, { x = button[1], z = button[2], r = BUTTON_RADIUS })
end

-- ¿Un círculo en (x, z) de radio r toca el rectángulo?
local function touchesRect(rect: Rect, x: number, z: number, r: number): boolean
	local angle = math.rad(rect.rot)
	local dx, dz = x - rect.x, z - rect.z
	-- Al sistema del rectángulo (al revés de su giro)
	local lx = dx * math.cos(angle) - dz * math.sin(angle)
	local lz = dx * math.sin(angle) + dz * math.cos(angle)
	return math.abs(lx) < rect.half.X + r and math.abs(lz) < rect.half.Y + r
end

-- placed: las que ya están colocadas: { { key, x, z } } con su radio en radiusOf
-- Devuelve si se puede y, si no, por qué
function Placement.Check(x: number, z: number, radius: number, placed: { any }?, radiusOf: ((string) -> number)?): (boolean, string?)
	if math.abs(x) > EDGE - radius or math.abs(z) > EDGE - radius then
		return false, "Fuera de tu terreno"
	end
	-- El muro: un cuadrado a wallInset del centro
	local inset = Waves.wallInset
	local nearX = math.abs(math.abs(x) - inset) < radius + 1.5 and math.abs(z) < inset + radius + 1
	local nearZ = math.abs(math.abs(z) - inset) < radius + 1.5 and math.abs(x) < inset + radius + 1
	if nearX or nearZ then
		return false, "Encima del muro"
	end
	for _, circle in circles do
		if (Vector2.new(x, z) - Vector2.new(circle.x, circle.z)).Magnitude < circle.r + radius then
			return false, "Lugar reservado"
		end
	end
	for _, rect in rects do
		if touchesRect(rect, x, z, radius) then
			return false, "Lugar reservado"
		end
	end
	for _, other in placed or {} do
		local otherRadius = if radiusOf then radiusOf(other.key) else 5
		if (Vector2.new(x, z) - Vector2.new(other.x, other.z)).Magnitude < otherRadius + radius then
			return false, "Ya hay otra defensa"
		end
	end
	return true, nil
end

return Placement
