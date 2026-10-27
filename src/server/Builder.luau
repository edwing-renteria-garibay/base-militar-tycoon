-- Los "dibujos" de cada construcción, hechos con bloques (sin modelos de la Toolbox).
-- Cada uno recibe un Model vacío y "o", el punto del piso donde va (con su giro). Todas las
-- piezas se colocan relativas a ese punto: o * CFrame.new(x, y, z). El frente es -Z.
--
-- Para agregar una construcción nueva: escribe aquí su función en Builder.kinds y ponla en
-- Config/Buildings con ese kind.

local Builder = {}

local OLIVE = Color3.fromRGB(86, 92, 62)
local DARK_OLIVE = Color3.fromRGB(56, 60, 42)
local SAND = Color3.fromRGB(196, 170, 120)
local WOOD = Color3.fromRGB(125, 90, 58)
local DARK_WOOD = Color3.fromRGB(80, 55, 35)
local METAL = Color3.fromRGB(110, 114, 120)
local DARK_METAL = Color3.fromRGB(50, 52, 56)
local CONCRETE = Color3.fromRGB(150, 150, 145)
local STONE = Color3.fromRGB(100, 98, 95)
local RED = Color3.fromRGB(180, 40, 40)
local WHITE = Color3.fromRGB(235, 235, 230)
local GLASS = Color3.fromRGB(120, 170, 200)
local YELLOW = Color3.fromRGB(220, 180, 40)

local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2) -- un cilindro de Roblox está acostado en X: esto lo para
local FACING = CFrame.Angles(0, math.pi / 2, 0) -- un disco de frente (mirando a -Z)

local function at(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z)
end

local function part(
	model: Model,
	o: CFrame,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = o * offset
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- Un letrero con texto en la cara de enfrente de una pieza
local function label(target: BasePart, text: string, color: Color3?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = target
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.BackgroundTransparency = 1
	textLabel.Font = Enum.Font.GothamBlack
	textLabel.Text = text
	textLabel.TextScaled = true
	textLabel.TextColor3 = color or WHITE
	textLabel.Parent = gui
	return textLabel
end

local function light(target: BasePart, color: Color3, range: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = 1.5
	l.Parent = target
end

Builder.kinds = {}

-- Etapa 1 -----------------------------------------------------------------------------------

function Builder.kinds.Flag(m: Model, o: CFrame)
	part(m, o, Vector3.new(3, 1, 3), at(0, 0.5, 0), CONCRETE, Enum.Material.Concrete)
	part(m, o, Vector3.new(14, 0.4, 0.4), at(0, 8, 0) * UPRIGHT, METAL, Enum.Material.Metal, Enum.PartType.Cylinder)
	part(m, o, Vector3.new(0.1, 3, 5), at(0, 13, 2.6), OLIVE, Enum.Material.Fabric)
	part(m, o, Vector3.new(0.15, 1.2, 1.2), at(0, 13, 2.6), YELLOW, Enum.Material.Neon)
end

function Builder.kinds.Sandbags(m: Model, o: CFrame)
	for layer = 0, 1 do
		for i = 0, 5 - layer do
			local x = -5 + i * 2 + layer
			part(m, o, Vector3.new(1.9, 0.9, 1.3), at(x, 0.45 + layer * 0.9, 0), SAND, Enum.Material.Fabric)
		end
	end
end

function Builder.kinds.Tent(m: Model, o: CFrame)
	part(m, o, Vector3.new(8, 0.2, 10), at(0, 0.1, 0), DARK_OLIVE, Enum.Material.Fabric)
	local slope = math.rad(45)
	part(m, o, Vector3.new(5.7, 0.2, 10), at(-2, 2, 0) * CFrame.Angles(0, 0, slope), OLIVE, Enum.Material.Fabric)
	part(m, o, Vector3.new(5.7, 0.2, 10), at(2, 2, 0) * CFrame.Angles(0, 0, -slope), OLIVE, Enum.Material.Fabric)
	part(m, o, Vector3.new(0.3, 4.4, 0.3), at(0, 2.2, -5), DARK_WOOD, Enum.Material.Wood)
	part(m, o, Vector3.new(0.3, 4.4, 0.3), at(0, 2.2, 5), DARK_WOOD, Enum.Material.Wood)
end

function Builder.kinds.Campfire(m: Model, o: CFrame)
	for i = 1, 8 do
		local angle = i * math.pi / 4
		part(m, o, Vector3.new(0.9, 0.6, 0.9), at(math.cos(angle) * 2, 0.3, math.sin(angle) * 2), STONE)
	end
	local log = Vector3.new(3, 0.5, 0.5)
	part(m, o, log, at(0, 0.4, 0) * CFrame.Angles(0, math.rad(45), 0), DARK_WOOD, Enum.Material.Wood, Enum.PartType.Cylinder)
	part(m, o, log, at(0, 0.6, 0) * CFrame.Angles(0, math.rad(-45), 0), DARK_WOOD, Enum.Material.Wood, Enum.PartType.Cylinder)
	local flame = part(m, o, Vector3.new(0.8, 1.2, 0.8), at(0, 1.2, 0), Color3.fromRGB(255, 140, 40), Enum.Material.Neon)
	flame.Transparency = 0.3
	flame.CanCollide = false
	local fire = Instance.new("Fire")
	fire.Size = 4
	fire.Heat = 6
	fire.Parent = flame
	light(flame, Color3.fromRGB(255, 160, 80), 16)
	-- Troncos para sentarse
	part(m, o, Vector3.new(4, 0.8, 0.8), at(0, 0.4, -4), WOOD, Enum.Material.Wood, Enum.PartType.Cylinder)
	part(m, o, Vector3.new(4, 0.8, 0.8), at(0, 0.4, 4), WOOD, Enum.Material.Wood, Enum.PartType.Cylinder)
end

function Builder.kinds.Crates(m: Model, o: CFrame)
	local crate = Vector3.new(3, 3, 3)
	part(m, o, crate, at(-2, 1.5, 0), WOOD, Enum.Material.WoodPlanks)
	part(m, o, crate, at(1.6, 1.5, 0.5) * CFrame.Angles(0, math.rad(12), 0), WOOD, Enum.Material.WoodPlanks)
	part(m, o, crate, at(-0.4, 4.5, 0.2) * CFrame.Angles(0, math.rad(-8), 0), WOOD, Enum.Material.WoodPlanks)
	local barrel = Vector3.new(3.4, 2, 2)
	part(m, o, barrel, at(4.5, 1.7, -2) * UPRIGHT, OLIVE, Enum.Material.Metal, Enum.PartType.Cylinder)
	part(m, o, barrel, at(4.5, 1.7, 0.5) * UPRIGHT, RED, Enum.Material.Metal, Enum.PartType.Cylinder)
end

function Builder.kinds.Radio(m: Model, o: CFrame)
	part(m, o, Vector3.new(5, 0.6, 5), at(0, 0.3, 0), CONCRETE, Enum.Material.Concrete)
	for _, corner in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		part(m, o, Vector3.new(0.3, 18, 0.3), at(corner[1] * 0.8, 9.6, corner[2] * 0.8), METAL, Enum.Material.Metal)
	end
	for y = 3, 18, 3 do
		part(m, o, Vector3.new(1.9, 0.2, 1.9), at(0, y, 0), METAL, Enum.Material.Metal)
	end
	part(m, o, Vector3.new(0.3, 3.5, 3.5), at(0, 15, -1.2) * FACING, WHITE, Enum.Material.Metal, Enum.PartType.Cylinder)
	local beacon = part(m, o, Vector3.new(0.6, 0.6, 0.6), at(0, 19, 0), RED, Enum.Material.Neon)
	light(beacon, RED, 10)
	part(m, o, Vector3.new(3, 3, 3), at(-3.5, 1.5, 1), DARK_METAL, Enum.Material.Metal)
end

function Builder.kinds.Watchtower(m: Model, o: CFrame)
	for _, corner in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		part(m, o, Vector3.new(0.8, 14, 0.8), at(corner[1] * 3.5, 7, corner[2] * 3.5), WOOD, Enum.Material.Wood)
		part(m, o, Vector3.new(0.4, 4.6, 0.4), at(corner[1] * 3.8, 16.9, corner[2] * 3.8), WOOD, Enum.Material.Wood)
	end
	part(m, o, Vector3.new(8.4, 0.6, 8.4), at(0, 14.3, 0), DARK_WOOD, Enum.Material.WoodPlanks)
	for _, side in { -1, 1 } do
		part(m, o, Vector3.new(8, 1.2, 0.3), at(0, 15.2, side * 4), WOOD, Enum.Material.Wood)
		part(m, o, Vector3.new(0.3, 1.2, 8), at(side * 4, 15.2, 0), WOOD, Enum.Material.Wood)
	end
	part(m, o, Vector3.new(9.5, 0.4, 9.5), at(0, 19.4, 0), DARK_OLIVE, Enum.Material.CorrugatedPlate)
	part(m, o, Vector3.new(2, 14, 0.3), at(0, 7, -4.2), DARK_WOOD, Enum.Material.Wood)
	local lamp = part(m, o, Vector3.new(1, 1, 1), at(0, 15.5, -3.6), WHITE, Enum.Material.Neon)
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Front
	spot.Range = 40
	spot.Angle = 50
	spot.Brightness = 2
	spot.Parent = lamp
end

-- Etapa 2 -----------------------------------------------------------------------------------

function Builder.kinds.Generator(m: Model, o: CFrame)
	part(m, o, Vector3.new(7, 0.4, 5), at(0, 0.2, 0), CONCRETE, Enum.Material.Concrete)
	part(m, o, Vector3.new(6, 4, 4), at(0, 2.4, 0), YELLOW, Enum.Material.Metal)
	part(m, o, Vector3.new(6.2, 0.4, 4.2), at(0, 4.6, 0), DARK_METAL, Enum.Material.Metal)
	local exhaust =
		part(m, o, Vector3.new(3, 0.6, 0.6), at(2, 6.2, 1) * UPRIGHT, DARK_METAL, Enum.Material.Metal, Enum.PartType.Cylinder)
	part(m, o, Vector3.new(2, 1.2, 0.2), at(-1.5, 2.8, -2.05), DARK_METAL, Enum.Material.Metal)
	local led = part(m, o, Vector3.new(0.3, 0.3, 0.1), at(-1.5, 3.1, -2.15), Color3.fromRGB(80, 255, 100), Enum.Material.Neon)
	light(led, Color3.fromRGB(80, 255, 100), 6)
	local smoke = Instance.new("Smoke")
	smoke.Size = 1
	smoke.RiseVelocity = 3
	smoke.Opacity = 0.1
	smoke.Parent = exhaust
end

function Builder.kinds.Barracks(m: Model, o: CFrame)
	part(m, o, Vector3.new(27, 0.6, 15), at(0, 0.3, 0), CONCRETE, Enum.Material.Concrete)
	part(m, o, Vector3.new(26, 9.4, 14), at(0, 5.3, 0), OLIVE, Enum.Material.Concrete)
	part(m, o, Vector3.new(28, 1, 16), at(0, 10.5, 0), DARK_METAL, Enum.Material.CorrugatedPlate)
	part(m, o, Vector3.new(4, 7, 0.3), at(0, 4.1, -7.1), DARK_WOOD, Enum.Material.Wood)
	for _, x in { -10, -5, 5, 10 } do
		part(m, o, Vector3.new(3, 2.5, 0.2), at(x, 6, -7.05), GLASS, Enum.Material.Glass)
	end
	local sign = part(m, o, Vector3.new(9, 1.6, 0.2), at(0, 8.8, -7.15), DARK_OLIVE)
	label(sign, "CUARTEL")
end

function Builder.kinds.Armory(m: Model, o: CFrame)
	part(m, o, Vector3.new(15, 0.6, 13), at(0, 0.3, 0), CONCRETE, Enum.Material.Concrete)
	part(m, o, Vector3.new(14, 9, 12), at(0, 5.1, 0), DARK_OLIVE, Enum.Material.Metal)
	part(m, o, Vector3.new(15, 0.8, 13), at(0, 10, 0), DARK_METAL, Enum.Material.Metal)
	part(m, o, Vector3.new(8, 6, 0.3), at(0, 3.6, -6.1), METAL, Enum.Material.CorrugatedPlate)
	local sign = part(m, o, Vector3.new(10, 1.6, 0.2), at(0, 8, -6.15), DARK_METAL)
	label(sign, "ARMERÍA", YELLOW)
	part(m, o, Vector3.new(3, 3, 3), at(-5.5, 2.1, -8), OLIVE, Enum.Material.Metal)
	part(m, o, Vector3.new(3, 2, 3), at(5.5, 1.6, -8), OLIVE, Enum.Material.Metal)
end

function Builder.kinds.Range(m: Model, o: CFrame)
	part(m, o, Vector3.new(12, 0.2, 26), at(0, 0.1, 0), SAND, Enum.Material.Ground)
	for _, x in { -2, 2 } do
		part(m, o, Vector3.new(0.4, 3, 6), at(x, 1.5, -10), DARK_WOOD, Enum.Material.Wood)
	end
	part(m, o, Vector3.new(12, 1, 0.6), at(0, 0.5, -7), DARK_WOOD, Enum.Material.Wood)
	part(m, o, Vector3.new(14, 6, 3), at(0, 3, 13), DARK_OLIVE, Enum.Material.Ground)
	for _, x in { -4, 0, 4 } do
		part(m, o, Vector3.new(0.3, 3, 0.3), at(x, 1.5, 9), DARK_WOOD, Enum.Material.Wood)
		part(m, o, Vector3.new(0.2, 3, 3), at(x, 4, 9) * FACING, WHITE, nil, Enum.PartType.Cylinder)
		part(m, o, Vector3.new(0.25, 1.8, 1.8), at(x, 4, 8.95) * FACING, RED, nil, Enum.PartType.Cylinder)
	end
end

function Builder.kinds.MessHall(m: Model, o: CFrame)
	part(m, o, Vector3.new(19, 0.6, 13), at(0, 0.3, 0), CONCRETE, Enum.Material.Concrete)
	part(m, o, Vector3.new(18, 7.4, 12), at(0, 4.3, 0), WOOD, Enum.Material.WoodPlanks)
	part(m, o, Vector3.new(19.5, 0.8, 13.5), at(0, 8.4, 0), DARK_WOOD, Enum.Material.Wood)
	part(m, o, Vector3.new(3.5, 6, 0.3), at(0, 3.6, -6.1), DARK_WOOD, Enum.Material.Wood)
	for _, x in { -6, 6 } do
		part(m, o, Vector3.new(3, 2, 0.2), at(x, 5, -6.05), GLASS, Enum.Material.Glass)
	end
	local chimney = part(m, o, Vector3.new(1.6, 4, 1.6), at(6, 10.5, 3), STONE, Enum.Material.Brick)
	local smoke = Instance.new("Smoke")
	smoke.Size = 2
	smoke.RiseVelocity = 4
	smoke.Opacity = 0.15
	smoke.Parent = chimney
	local sign = part(m, o, Vector3.new(8, 1.4, 0.2), at(0, 7.3, -6.15), DARK_WOOD)
	label(sign, "COMEDOR")
end

-- El muro va en las orillas del terreno: atrás y a los lados (el frente lo cierra el portón)
function Builder.kinds.Wall(m: Model, o: CFrame)
	part(m, o, Vector3.new(130, 8, 2), at(0, 4, 4), CONCRETE, Enum.Material.Concrete)
	for _, side in { -1, 1 } do
		part(m, o, Vector3.new(2, 8, 128), at(side * 64, 4, -60), CONCRETE, Enum.Material.Concrete)
	end
end

function Builder.kinds.Gate(m: Model, o: CFrame)
	for _, side in { -1, 1 } do
		part(m, o, Vector3.new(52, 8, 2), at(side * 38, 4, 0), CONCRETE, Enum.Material.Concrete)
		part(m, o, Vector3.new(3, 11, 3), at(side * 11.5, 5.5, 0), DARK_METAL, Enum.Material.Metal)
	end
	local beam = part(m, o, Vector3.new(26, 2.4, 2), at(0, 12, 0), DARK_OLIVE, Enum.Material.Metal)
	-- El letrero mira a la calle (-Z)
	label(beam, "BASE MILITAR", YELLOW)
	part(m, o, Vector3.new(3.5, 4.5, 3.5), at(15, 2.25, 5), OLIVE, Enum.Material.Concrete)
	part(m, o, Vector3.new(4, 0.4, 4), at(15, 4.7, 5), DARK_METAL, Enum.Material.Metal)
	local boom = part(m, o, Vector3.new(0.6, 0.6, 12), at(7, 6, 1.5) * CFrame.Angles(math.rad(70), 0, 0), RED)
	boom.CanCollide = false
end

-- Lo que trae todo terreno al reclamarlo ---------------------------------------------------

-- La caja fuerte: junta el dinero que genera la base. Devuelve el modelo, el botón para
-- cobrar y el texto que muestra cuánto hay
function Builder.Vault(o: CFrame): (Model, BasePart, TextLabel)
	local m = Instance.new("Model")
	m.Name = "CajaFuerte"
	local body = part(m, o, Vector3.new(6, 7, 5), at(0, 3.5, 0), DARK_METAL, Enum.Material.Metal)
	part(m, o, Vector3.new(0.4, 4, 4), at(0, 3.5, -2.6) * FACING, METAL, Enum.Material.Metal, Enum.PartType.Cylinder)
	part(m, o, Vector3.new(0.6, 0.4, 2.6), at(0, 3.5, -2.9) * CFrame.Angles(0, 0, math.rad(45)), YELLOW, Enum.Material.Metal)
	local pad = part(m, o, Vector3.new(6, 0.4, 4), at(0, 0.2, -5.5), Color3.fromRGB(60, 200, 90), Enum.Material.Neon)
	pad.Name = "Cobrar"
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 80)
	gui.StudsOffset = Vector3.new(0, 6, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 90
	gui.Parent = body
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBlack
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(120, 255, 140)
	text.TextStrokeTransparency = 0.4
	text.Text = "$0"
	text.Parent = gui
	return m, pad, text
end

-- Un botón redondo en el piso con el nombre y el precio arriba
function Builder.Button(o: CFrame, title: string): (BasePart, TextLabel)
	local button = Instance.new("Part")
	button.Name = "Boton"
	button.Anchored = true
	button.Shape = Enum.PartType.Cylinder
	button.Size = Vector3.new(0.6, 5, 5)
	button.CFrame = o * at(0, 0.3, 0) * UPRIGHT
	button.Material = Enum.Material.Neon
	button.Color = Color3.fromRGB(60, 200, 90)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 70)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.MaxDistance = 70
	gui.Parent = button
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextColor3 = WHITE
	text.TextStrokeTransparency = 0.3
	text.Text = title
	text.Parent = gui
	return button, text
end

-- Arma una construcción y la devuelve (sin ponerla en el mundo)
function Builder.Build(kind: string, o: CFrame): Model
	local m = Instance.new("Model")
	local draw = Builder.kinds[kind]
	if draw then
		draw(m, o)
	else
		warn("[Builder] No hay dibujo para", kind)
		part(m, o, Vector3.new(4, 4, 4), at(0, 2, 0), RED)
	end
	return m
end

return Builder
