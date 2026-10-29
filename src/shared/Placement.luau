-- ¿Se puede poner una defensa premium (o una barricada) aquí? Lo usan el servidor (para
-- aceptar) y la pantalla de colocar (para pintar la vista previa de verde o rojo).
--
-- Las posiciones son dentro del terreno: x y z de -100 a 100, con la caja fuerte en { 0, 0 }.
-- No se puede encimar en:
--   - los lugares marcados de Config/Buildings (lo tengas comprado o no) y sus botones
--   - la caja fuerte, el muro y el lugar donde apareces
--   - otras defensas premium ya colocadas

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Barricades = require(ReplicatedStorage.Shared.Config.Barricades)
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

-- Barricadas ---------------------------------------------------------------------------------

local BARRICADE_RADIUS = 1.8 -- medio grueso de una barricada

-- La punta de barricada más cercana a p (si está a menos de Barricades.snap), o p
local function snap(p: Vector2, points: { Vector2 }): Vector2
	local best, bestDistance = p, Barricades.snap
	for _, point in points do
		local distance = (point - p).Magnitude
		if distance < bestDistance then
			best, bestDistance = point, distance
		end
	end
	return best
end

-- Una hilera de barricadas de a hacia b: se une a las puntas cercanas (points) y se ajusta a
-- pedazos enteros. Devuelve dónde empieza, dónde termina y cuántos pedazos tiene (0 = nada)
function Placement.Row(a: Vector2, b: Vector2, points: { Vector2 }): (Vector2, Vector2, number)
	local seg, most = Barricades.segment, Barricades.maxPerRow
	a = snap(a, points)
	local joined = snap(b, points)
	if joined ~= b and joined ~= a then
		-- Termina en otra barricada: los pedazos se estiran un poco para llegar justo
		local length = (joined - a).Magnitude
		if length >= seg * 0.5 and length <= seg * most + Barricades.snap then
			return a, joined, math.clamp(math.floor(length / seg + 0.5), 1, most)
		end
	end
	local length = (b - a).Magnitude
	if length < seg * 0.5 then
		return a, a, 0
	end
	local count = math.clamp(math.floor(length / seg + 0.5), 1, most)
	return a, a + (b - a).Unit * count * seg, count
end

-- ¿Se puede poner una barricada de a a b? (revisa puntos a lo largo, cada 2 studs)
function Placement.CheckRow(a: Vector2, b: Vector2, placed: { any }?, radiusOf: ((string) -> number)?): (boolean, string?)
	local length = (b - a).Magnitude
	local steps = math.max(1, math.ceil(length / 2))
	for i = 0, steps do
		local p = a:Lerp(b, i / steps)
		local ok, reason = Placement.Check(p.X, p.Y, BARRICADE_RADIUS, placed, radiusOf)
		if not ok then
			return false, reason
		end
	end
	return true, nil
end

-- Las puntas de todas las hileras (para unirse a ellas). rows: { { ax, az, bx, bz, n } }
function Placement.RowPoints(rows: { any }): { Vector2 }
	local points = {}
	for _, row in rows do
		local a, b = Vector2.new(row[1], row[2]), Vector2.new(row[3], row[4])
		for i = 0, row[5] do
			table.insert(points, a:Lerp(b, i / row[5]))
		end
	end
	return points
end

return Placement
