-- Los "dibujos" de cada construcción, hechos con bloques (sin modelos de la Toolbox).
-- Cada uno recibe un Model vacío y "o", el punto del piso donde va (con su giro). Todas las
-- piezas se colocan relativas a ese punto: o * CFrame.new(x, y, z). El frente es -Z.
--
-- Para agregar una construcción nueva: escribe aquí su función en Builder.kinds y ponla en
-- Config/Buildings con ese kind.

local CollectionService = game:GetService("CollectionService")

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

-- Un grupo de piezas que gira sobre su eje vertical: aspas, radar, torretas. Lo hace girar
-- cada jugador en su pantalla (src/client/Spinner.luau), así no gasta al servidor.
-- speed: radianes por segundo. Después de agregarle piezas hay que fijar su WorldPivot (el eje)
local function spinner(m: Model, speed: number): Model
	local group = Instance.new("Model")
	group.Name = "Gira"
	group:SetAttribute("SpinSpeed", speed)
	CollectionService:AddTag(group, "Spin")
	group.Parent = m
	return group
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
	part(m, o, Vector3.new(9.5, 0.4, 9.5), at(0, 19.4, 0), DARK_OLIVE, Enum.Material.DiamondPlate)
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
	part(m, o, Vector3.new(28, 1, 16), at(0, 10.5, 0), DARK_METAL, Enum.Material.DiamondPlate)
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
	part(m, o, Vector3.new(8, 6, 0.3), at(0, 3.6, -6.1), METAL, Enum.Material.DiamondPlate)
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

-- Etapa 3 -----------------------------------------------------------------------------------

function Builder.kinds.FuelTanks(m: Model, o: CFrame)
	part(m, o, Vector3.new(12, 0.6, 10), at(0, 0.3, 0), CONCRETE, Enum.Material.Concrete)
	for i, x in { -4, 0, 4 } do
		part(m, o, Vector3.new(0.6, 1, 8), at(x, 1.1, 0), DARK_METAL, Enum.Material.Metal)
		local color = if i == 2 then RED else WHITE
		part(m, o, Vector3.new(9, 3.4, 3.4), at(x, 3, 0) * FACING, color, Enum.Material.Metal, Enum.PartType.Cylinder)
	end
end

function Builder.kinds.GasStation(m: Model, o: CFrame)
	part(m, o, Vector3.new(16, 0.4, 10), at(0, 0.2, 0), CONCRETE, Enum.Material.Concrete)
	for _, x in { -7, 7 } do
		for _, z in { -4, 4 } do
			part(m, o, Vector3.new(0.6, 7.6, 0.6), at(x, 4.2, z), WHITE, Enum.Material.Metal)
		end
	end
	local roof = part(m, o, Vector3.new(17, 1, 11), at(0, 8.5, 0), RED, Enum.Material.Metal)
	label(roof, "GASOLINERA")
	for _, x in { -3, 3 } do
		part(m, o, Vector3.new(1.4, 3, 1), at(x, 1.9, 0), RED, Enum.Material.Metal)
		local screen = part(m, o, Vector3.new(1, 0.6, 0.1), at(x, 2.8, -0.55), Color3.fromRGB(80, 255, 100), Enum.Material.Neon)
		screen.CanCollide = false
	end
end

function Builder.kinds.Workshop(m: Model, o: CFrame)
	part(m, o, Vector3.new(12, 0.4, 10), at(0, 0.2, 0), CONCRETE, Enum.Material.Concrete)
	for _, x in { -5.5, 5.5 } do
		for _, z in { -4.5, 4.5 } do
			part(m, o, Vector3.new(0.6, 7, 0.6), at(x, 3.9, z), DARK_METAL, Enum.Material.Metal)
		end
	end
	part(m, o, Vector3.new(13, 0.6, 11), at(0, 7.6, 0), DARK_METAL, Enum.Material.DiamondPlate)
	part(m, o, Vector3.new(8, 3, 2), at(0, 1.9, 4), WOOD, Enum.Material.WoodPlanks)
	for i = 0, 3 do
		part(m, o, Vector3.new(0.9, 2.6, 2.6), at(-4, 0.85 + i * 0.9, -2) * UPRIGHT, Color3.fromRGB(25, 25, 25), Enum.Material.Rubber, Enum.PartType.Cylinder)
	end
	part(m, o, Vector3.new(2, 2.4, 1.4), at(3.5, 1.6, -2), RED, Enum.Material.Metal)
end

function Builder.kinds.Factory(m: Model, o: CFrame)
	part(m, o, Vector3.new(23, 0.6, 25), at(0, 0.3, 0), CONCRETE, Enum.Material.Concrete)
	part(m, o, Vector3.new(22, 12, 24), at(0, 6.6, 0), METAL, Enum.Material.DiamondPlate)
	-- Techo de "dientes de sierra", como las fábricas de verdad
	for _, z in { -8, 0, 8 } do
		part(m, o, Vector3.new(22, 0.4, 8.6), at(0, 14, z) * CFrame.Angles(math.rad(-25), 0, 0), DARK_METAL, Enum.Material.Metal)
		part(m, o, Vector3.new(22, 3.6, 0.2), at(0, 14.4, z + 3.9), GLASS, Enum.Material.Glass)
	end
	for _, x in { -7, 7 } do
		local chimney = part(m, o, Vector3.new(10, 1.8, 1.8), at(x, 17, 8) * UPRIGHT, STONE, Enum.Material.Brick, Enum.PartType.Cylinder)
		local smoke = Instance.new("Smoke")
		smoke.Size = 3
		smoke.RiseVelocity = 5
		smoke.Opacity = 0.15
		smoke.Parent = chimney
	end
	part(m, o, Vector3.new(10, 8, 0.3), at(0, 4.6, -12.1), DARK_METAL, Enum.Material.DiamondPlate)
	local sign = part(m, o, Vector3.new(14, 2, 0.2), at(0, 10, -12.15), DARK_OLIVE)
	label(sign, "FÁBRICA DE JEEPS", YELLOW)
end

function Builder.kinds.Truck(m: Model, o: CFrame)
	part(m, o, Vector3.new(6, 1, 18), at(0, 1.8, 0), DARK_METAL, Enum.Material.Metal)
	part(m, o, Vector3.new(6, 4.5, 5), at(0, 4.5, -6.5), OLIVE, Enum.Material.Metal)
	part(m, o, Vector3.new(5, 1.8, 0.2), at(0, 5.3, -9.05), GLASS, Enum.Material.Glass)
	part(m, o, Vector3.new(6.4, 6, 12), at(0, 5.3, 3), DARK_OLIVE, Enum.Material.Fabric)
	for _, x in { -3.2, 3.2 } do
		for _, z in { -6.5, 2, 6 } do
			part(m, o, Vector3.new(1, 2.6, 2.6), at(x, 1.3, z), Color3.fromRGB(25, 25, 25), Enum.Material.Rubber, Enum.PartType.Cylinder)
		end
	end
end

-- Etapa 4 -----------------------------------------------------------------------------------

function Builder.kinds.Bunker(m: Model, o: CFrame)
	part(m, o, Vector3.new(12, 4, 10), at(0, 2, 0), CONCRETE, Enum.Material.Concrete)
	part(m, o, Vector3.new(14, 1.5, 12), at(0, 4.6, 0), DARK_OLIVE, Enum.Material.Ground)
	part(m, o, Vector3.new(8, 0.8, 0.2), at(0, 3, -5.05), Color3.fromRGB(15, 15, 15))
	part(m, o, Vector3.new(3, 3, 0.2), at(4, 1.5, -5.05), DARK_METAL, Enum.Material.Metal)
	for i = 0, 4 do
		part(m, o, Vector3.new(1.9, 0.9, 1.3), at(-4 + i * 2, 0.45, -6.5), SAND, Enum.Material.Fabric)
	end
end

-- La torreta solo dispara hacia su frente (Waves.turretArc; su alcance lo marca RangeMarks).
-- Su "Cabeza" la gira el servidor hacia el zombi al que dispara (WaveService)
function Builder.kinds.Turret(m: Model, o: CFrame)
	part(m, o, Vector3.new(7, 0.6, 7), at(0, 0.3, 0), CONCRETE, Enum.Material.Concrete)
	part(m, o, Vector3.new(3, 5, 5), at(0, 2.1, 0) * UPRIGHT, DARK_METAL, Enum.Material.Metal, Enum.PartType.Cylinder)
	local head = Instance.new("Model")
	head.Name = "Cabeza"
	head.Parent = m
	part(head, o, Vector3.new(4, 2.4, 4.5), at(0, 4.8, 0), OLIVE, Enum.Material.Metal)
	for _, x in { -0.8, 0.8 } do
		part(head, o, Vector3.new(6, 0.5, 0.5), at(x, 5, -5) * FACING, DARK_METAL, Enum.Material.Metal, Enum.PartType.Cylinder)
	end
	head.WorldPivot = o * at(0, 4.8, 0)
end

function Builder.kinds.Radar(m: Model, o: CFrame)
	part(m, o, Vector3.new(6, 3, 6), at(0, 1.5, 0), DARK_OLIVE, Enum.Material.Metal)
	part(m, o, Vector3.new(6, 1, 1), at(0, 6, 0) * UPRIGHT, METAL, Enum.Material.Metal, Enum.PartType.Cylinder)
	local dish = spinner(m, 1)
	part(dish, o, Vector3.new(0.6, 7, 7), at(0, 10, -0.5) * FACING * CFrame.Angles(0, 0, math.rad(15)), WHITE, Enum.Material.Metal, Enum.PartType.Cylinder)
	part(dish, o, Vector3.new(0.3, 0.3, 3), at(0, 10, -2.2), DARK_METAL, Enum.Material.Metal)
	dish.WorldPivot = o * at(0, 10, 0)
	local beacon = part(m, o, Vector3.new(0.6, 0.6, 0.6), at(2.5, 3.3, -2.5), Color3.fromRGB(80, 255, 100), Enum.Material.Neon)
	light(beacon, Color3.fromRGB(80, 255, 100), 8)
end

function Builder.kinds.AmmoDepot(m: Model, o: CFrame)
	part(m, o, Vector3.new(12, 0.4, 10), at(0, 0.2, 0), CONCRETE, Enum.Material.Concrete)
	part(m, o, Vector3.new(10, 5, 8), at(0, 2.9, 0.5), DARK_OLIVE, Enum.Material.Concrete)
	part(m, o, Vector3.new(11, 1.4, 9), at(0, 6, 0.5), OLIVE, Enum.Material.Ground)
	part(m, o, Vector3.new(4, 4, 0.3), at(0, 2.4, -3.6), DARK_METAL, Enum.Material.Metal)
	local sign = part(m, o, Vector3.new(6, 1, 0.2), at(0, 4.9, -3.65), DARK_METAL)
	label(sign, "POLVORÍN", RED)
	local lamp = part(m, o, Vector3.new(0.6, 0.6, 0.6), at(3.5, 4.5, -3.7), RED, Enum.Material.Neon)
	light(lamp, RED, 8)
	part(m, o, Vector3.new(2, 2, 3), at(-4, 1.4, -5), OLIVE, Enum.Material.Metal)
	part(m, o, Vector3.new(2, 2, 3), at(-4, 3.4, -5), OLIVE, Enum.Material.Metal)
end

function Builder.kinds.SniperTower(m: Model, o: CFrame)
	for _, corner in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		part(m, o, Vector3.new(0.6, 24, 0.6), at(corner[1] * 2.2, 12, corner[2] * 2.2), DARK_METAL, Enum.Material.Metal)
	end
	for y = 4, 20, 4 do
		part(m, o, Vector3.new(4.8, 0.3, 4.8), at(0, y, 0), METAL, Enum.Material.Metal)
	end
	part(m, o, Vector3.new(6, 0.5, 6), at(0, 24.2, 0), DARK_WOOD, Enum.Material.WoodPlanks)
	for i = 0, 2 do
		part(m, o, Vector3.new(1.8, 0.9, 1.2), at(-2 + i * 2, 24.9, -2.6), SAND, Enum.Material.Fabric)
	end
	part(m, o, Vector3.new(6.6, 0.4, 6.6), at(0, 28, 0), DARK_OLIVE, Enum.Material.Fabric)
	for _, corner in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		part(m, o, Vector3.new(0.3, 3.4, 0.3), at(corner[1] * 2.8, 26.2, corner[2] * 2.8), DARK_WOOD, Enum.Material.Wood)
	end
end

function Builder.kinds.Tank(m: Model, o: CFrame)
	local tread = Color3.fromRGB(30, 30, 28)
	for _, x in { -4, 4 } do
		part(m, o, Vector3.new(2.2, 2.6, 13), at(x, 1.3, 0), tread, Enum.Material.Metal)
	end
	part(m, o, Vector3.new(6, 2.4, 12), at(0, 2.4, 0), OLIVE, Enum.Material.Metal)
	part(m, o, Vector3.new(10.4, 0.4, 13.4), at(0, 2.8, 0), DARK_OLIVE, Enum.Material.Metal)
	local turret = spinner(m, 0.15)
	part(turret, o, Vector3.new(6, 2.2, 6.5), at(0, 4.1, 0.5), OLIVE, Enum.Material.Metal)
	part(turret, o, Vector3.new(9, 0.8, 0.8), at(0, 4.3, -6.5) * FACING, DARK_METAL, Enum.Material.Metal, Enum.PartType.Cylinder)
	part(turret, o, Vector3.new(1.6, 0.8, 1.6), at(1.5, 5.6, 1.5) * UPRIGHT, DARK_METAL, Enum.Material.Metal, Enum.PartType.Cylinder)
	turret.WorldPivot = o * at(0, 4.1, 0.5)
	part(m, o, Vector3.new(0.15, 1.2, 1.2), at(5.25, 2.4, 0), WHITE)
end

-- Etapa 5 -----------------------------------------------------------------------------------

function Builder.kinds.Helipad(m: Model, o: CFrame)
	part(m, o, Vector3.new(20, 0.6, 20), at(0, 0.3, 0), Color3.fromRGB(70, 70, 72), Enum.Material.Concrete)
	part(m, o, Vector3.new(1.4, 0.05, 9), at(-3, 0.62, 0), WHITE)
	part(m, o, Vector3.new(1.4, 0.05, 9), at(3, 0.62, 0), WHITE)
	part(m, o, Vector3.new(4.6, 0.05, 1.4), at(0, 0.62, 0), WHITE)
	for _, x in { -9.3, 9.3 } do
		for _, z in { -9.3, 9.3 } do
			local lamp = part(m, o, Vector3.new(0.8, 0.5, 0.8), at(x, 0.85, z), YELLOW, Enum.Material.Neon)
			light(lamp, YELLOW, 6)
		end
	end
end

function Builder.kinds.Helicopter(m: Model, o: CFrame)
	local y = 0.6 -- encima del helipuerto
	for _, x in { -2, 2 } do
		part(m, o, Vector3.new(0.4, 0.4, 10), at(x, y + 0.2, 0), DARK_METAL, Enum.Material.Metal)
		part(m, o, Vector3.new(0.3, 1.6, 0.3), at(x, y + 1.2, -2.5), DARK_METAL, Enum.Material.Metal)
		part(m, o, Vector3.new(0.3, 1.6, 0.3), at(x, y + 1.2, 2.5), DARK_METAL, Enum.Material.Metal)
	end
	part(m, o, Vector3.new(5, 4, 10), at(0, y + 4, 0), OLIVE, Enum.Material.Metal)
	part(m, o, Vector3.new(4.4, 2.6, 0.2), at(0, y + 4.4, -5.05), GLASS, Enum.Material.Glass)
	part(m, o, Vector3.new(1.4, 1.4, 11), at(0, y + 4.8, 10), OLIVE, Enum.Material.Metal)
	part(m, o, Vector3.new(0.3, 3, 1.6), at(0, y + 6, 15), DARK_OLIVE, Enum.Material.Metal)
	part(m, o, Vector3.new(1, 1.4, 1.4), at(0, y + 6.6, 0) * UPRIGHT, DARK_METAL, Enum.Material.Metal, Enum.PartType.Cylinder)
	local rotor = spinner(m, 6)
	part(rotor, o, Vector3.new(24, 0.15, 1), at(0, y + 7.4, 0), DARK_METAL, Enum.Material.Metal)
	part(rotor, o, Vector3.new(1, 0.15, 24), at(0, y + 7.4, 0), DARK_METAL, Enum.Material.Metal)
	rotor.WorldPivot = o * at(0, y + 7.4, 0)
end

function Builder.kinds.Hangar(m: Model, o: CFrame)
	part(m, o, Vector3.new(25, 0.6, 19), at(0, 0.3, 0), CONCRETE, Enum.Material.Concrete)
	part(m, o, Vector3.new(24, 10, 18), at(0, 5.6, 0), METAL, Enum.Material.DiamondPlate)
	-- Techo redondeado: un cilindro acostado de lado a lado
	part(m, o, Vector3.new(24, 18, 8), at(0, 10.6, 0), METAL, Enum.Material.DiamondPlate, Enum.PartType.Cylinder)
	part(m, o, Vector3.new(16, 9, 0.3), at(0, 5.1, -9.1), DARK_METAL, Enum.Material.DiamondPlate)
	local sign = part(m, o, Vector3.new(12, 2, 0.2), at(0, 12, -9.15), DARK_OLIVE)
	label(sign, "HANGAR", YELLOW)
end

function Builder.kinds.CommandCenter(m: Model, o: CFrame)
	part(m, o, Vector3.new(23, 0.6, 15), at(0, 0.3, 0), CONCRETE, Enum.Material.Concrete)
	part(m, o, Vector3.new(22, 8, 14), at(0, 4.6, 0), DARK_OLIVE, Enum.Material.Concrete)
	part(m, o, Vector3.new(14, 6, 10), at(0, 11.6, 1), CONCRETE, Enum.Material.Concrete)
	part(m, o, Vector3.new(13, 3, 0.2), at(0, 12, -4.05), GLASS, Enum.Material.Glass)
	part(m, o, Vector3.new(15, 0.6, 11), at(0, 14.9, 1), DARK_METAL, Enum.Material.Metal)
	part(m, o, Vector3.new(8, 0.4, 0.4), at(4, 19.2, 3) * UPRIGHT, METAL, Enum.Material.Metal, Enum.PartType.Cylinder)
	local beacon = part(m, o, Vector3.new(0.6, 0.6, 0.6), at(4, 23.4, 3), RED, Enum.Material.Neon)
	light(beacon, RED, 10)
	part(m, o, Vector3.new(4, 6, 0.3), at(0, 3.6, -7.1), DARK_METAL, Enum.Material.Metal)
	local sign = part(m, o, Vector3.new(14, 1.6, 0.2), at(0, 7.4, -7.15), DARK_METAL)
	label(sign, "CENTRO DE MANDO", YELLOW)
end

function Builder.kinds.SatDish(m: Model, o: CFrame)
	part(m, o, Vector3.new(8, 1, 8), at(0, 0.5, 0), CONCRETE, Enum.Material.Concrete)
	part(m, o, Vector3.new(5, 2, 2), at(0, 3.5, 0) * UPRIGHT, DARK_METAL, Enum.Material.Metal, Enum.PartType.Cylinder)
	local dish = spinner(m, 0.1)
	-- El plato mira al cielo, inclinado hacia el frente
	part(dish, o, Vector3.new(0.8, 12, 12), at(0, 8, 0) * CFrame.Angles(math.rad(-30), 0, 0) * UPRIGHT, WHITE, Enum.Material.Metal, Enum.PartType.Cylinder)
	part(dish, o, Vector3.new(0.4, 6, 0.4), at(0, 10.5, -1.5), DARK_METAL, Enum.Material.Metal)
	dish.WorldPivot = o * at(0, 8, 0)
end

function Builder.kinds.BigFlag(m: Model, o: CFrame)
	part(m, o, Vector3.new(8, 2, 8), at(0, 1, 0), CONCRETE, Enum.Material.Concrete)
	part(m, o, Vector3.new(6, 1, 6), at(0, 2.5, 0), STONE, Enum.Material.Concrete)
	part(m, o, Vector3.new(40, 1, 1), at(0, 23, 0) * UPRIGHT, METAL, Enum.Material.Metal, Enum.PartType.Cylinder)
	part(m, o, Vector3.new(1.4, 1.4, 1.4), at(0, 43.5, 0), YELLOW, Enum.Material.Metal, Enum.PartType.Ball)
	part(m, o, Vector3.new(0.2, 9, 15), at(0, 38, 8), OLIVE, Enum.Material.Fabric)
	local star = part(m, o, Vector3.new(0.3, 4, 4), at(0, 38, 8), YELLOW, Enum.Material.Neon)
	light(star, YELLOW, 20)
end

-- Enfermería: carpa blanca con cruz roja. Cerca de ella te curas (TycoonService)
function Builder.kinds.Infirmary(m: Model, o: CFrame)
	part(m, o, Vector3.new(16, 0.4, 12), at(0, 0.2, 0), CONCRETE, Enum.Material.Concrete)
	part(m, o, Vector3.new(14, 7, 10), at(0, 3.9, 1), WHITE, Enum.Material.Fabric)
	part(m, o, Vector3.new(15, 0.8, 11), at(0, 7.8, 1), Color3.fromRGB(200, 200, 195), Enum.Material.Fabric)
	part(m, o, Vector3.new(4, 5.5, 0.3), at(0, 3.15, -4.1), Color3.fromRGB(180, 210, 220), Enum.Material.Glass)
	for _, size in { Vector3.new(1.2, 4, 0.2), Vector3.new(4, 1.2, 0.2) } do
		local cross = part(m, o, size, at(0, 9.8, -4.1), RED, Enum.Material.Neon)
		cross.CanCollide = false
	end
	part(m, o, Vector3.new(0.4, 2.6, 0.4), at(0, 9, -4), DARK_METAL, Enum.Material.Metal)
	for _, x in { -4.5, 4.5 } do
		part(m, o, Vector3.new(2.4, 0.8, 5), at(x, 1.4, 1), WHITE, Enum.Material.Fabric) -- camillas
	end
end

-- Laboratorio: edificio con ventanales y tubos verdes
function Builder.kinds.Lab(m: Model, o: CFrame)
	part(m, o, Vector3.new(15, 0.6, 13), at(0, 0.3, 0), CONCRETE, Enum.Material.Concrete)
	part(m, o, Vector3.new(14, 8, 12), at(0, 4.6, 0), WHITE, Enum.Material.SmoothPlastic)
	part(m, o, Vector3.new(15, 0.8, 13), at(0, 9, 0), DARK_METAL, Enum.Material.Metal)
	for _, x in { -4, 4 } do
		part(m, o, Vector3.new(4, 3, 0.2), at(x, 5.5, -6.05), GLASS, Enum.Material.Glass)
	end
	part(m, o, Vector3.new(3, 6, 0.3), at(0, 3.6, -6.1), DARK_METAL, Enum.Material.Metal)
	local sign = part(m, o, Vector3.new(9, 1.4, 0.2), at(0, 7.9, -6.15), DARK_METAL)
	label(sign, "LABORATORIO", Color3.fromRGB(90, 255, 120))
	for _, x in { -5, -3 } do
		local tube = part(m, o, Vector3.new(4, 1.2, 1.2), at(x, 11.4, 3) * UPRIGHT, GLASS, Enum.Material.Glass, Enum.PartType.Cylinder)
		tube.Transparency = 0.3
		local liquid = part(m, o, Vector3.new(2.6, 0.9, 0.9), at(x, 11, 3) * UPRIGHT, Color3.fromRGB(90, 255, 120), Enum.Material.Neon, Enum.PartType.Cylinder)
		liquid.CanCollide = false
	end
	part(m, o, Vector3.new(0.4, 5, 0.4), at(5, 11.5, 3), METAL, Enum.Material.Metal)
	part(m, o, Vector3.new(3, 0.3, 3), at(5, 14, 3), METAL, Enum.Material.Metal)
end

-- Defensas premium (Config/Premium) ---------------------------------------------------------

-- Torreta pesada: dispara a todos lados. Su "Cabeza" la gira el servidor (WaveService)
function Builder.kinds.HeavyTurret(m: Model, o: CFrame)
	part(m, o, Vector3.new(9, 0.8, 9), at(0, 0.4, 0), DARK_METAL, Enum.Material.DiamondPlate)
	for _, x in { -3.6, 3.6 } do
		part(m, o, Vector3.new(0.8, 0.5, 8), at(x, 1, 0), YELLOW, Enum.Material.Metal)
	end
	part(m, o, Vector3.new(4, 6, 6), at(0, 3.5, 0) * UPRIGHT, DARK_METAL, Enum.Material.Metal, Enum.PartType.Cylinder)
	local head = Instance.new("Model")
	head.Name = "Cabeza"
	head.Parent = m
	part(head, o, Vector3.new(5.5, 3, 6), at(0, 7, 0), RED, Enum.Material.Metal)
	part(head, o, Vector3.new(5.7, 0.4, 6.2), at(0, 8.6, 0), DARK_METAL, Enum.Material.Metal)
	for _, x in { -1.2, 0, 1.2 } do
		part(head, o, Vector3.new(7, 0.6, 0.6), at(x, 7.2, -6.3) * FACING, DARK_METAL, Enum.Material.Metal, Enum.PartType.Cylinder)
	end
	local lamp = part(head, o, Vector3.new(0.6, 0.6, 0.6), at(0, 9.1, 0), YELLOW, Enum.Material.Neon)
	light(lamp, YELLOW, 8)
	head.WorldPivot = o * at(0, 7, 0)
end

-- Barricada de acero: como la de concreto, pero más larga y aguanta mucho más
function Builder.kinds.SteelBarricade(m: Model, o: CFrame)
	part(m, o, Vector3.new(14, 1.2, 3.4), at(0, 0.6, 0), CONCRETE, Enum.Material.Concrete)
	part(m, o, Vector3.new(14, 4.4, 1.2), at(0, 3.4, 0), METAL, Enum.Material.DiamondPlate)
	for _, x in { -6, -2, 2, 6 } do
		part(m, o, Vector3.new(0.6, 5.4, 2.4), at(x, 3, 0), DARK_METAL, Enum.Material.Metal)
	end
	for _, x in { -4, 0, 4 } do
		part(m, o, Vector3.new(1.6, 0.5, 0.1), at(x, 4.5, -0.65), YELLOW, Enum.Material.SmoothPlastic)
	end
end

-- Defensas de afuera del muro ----------------------------------------------------------------
-- Sus medidas tienen que coincidir con las zonas que revisa WaveService (alambre y zanja)

-- Barricada de concreto: tapa el paso hasta que los zombis la rompen (WallService)
function Builder.kinds.Barricade(m: Model, o: CFrame)
	for _, x in { -4, 4 } do
		part(m, o, Vector3.new(7.8, 1.6, 3.4), at(x, 0.8, 0), CONCRETE, Enum.Material.Concrete)
		part(m, o, Vector3.new(7.8, 2.6, 1.8), at(x, 2.9, 0), CONCRETE, Enum.Material.Concrete)
		part(m, o, Vector3.new(2, 0.5, 0.1), at(x, 3.4, -0.95), YELLOW, Enum.Material.SmoothPlastic)
	end
end

-- Un pedazo de barricada de las que pones donde quieras (Config/Barricades): o es el centro de
-- la barricada en el piso, mirando a lo largo de ella. Lleva un poste en cada punta: donde se
-- juntan dos barricadas, sus postes quedan uno encima del otro y se ve unido
function Builder.BarricadeSegment(o: CFrame, length: number): Model
	local m = Instance.new("Model")
	m.Name = "Barricada"
	part(m, o, Vector3.new(3.4, 1.6, length), at(0, 0.8, 0), CONCRETE, Enum.Material.Concrete)
	part(m, o, Vector3.new(1.8, 2.6, length), at(0, 2.9, 0), CONCRETE, Enum.Material.Concrete)
	for _, z in { -length / 2, length / 2 } do
		part(m, o, Vector3.new(2.6, 4.8, 2.6), at(0, 2.4, z), STONE, Enum.Material.Concrete)
	end
	for _, x in { -0.95, 0.95 } do
		part(m, o, Vector3.new(0.1, 0.5, math.max(length - 3, 0.5)), at(x, 3.4, 0), YELLOW, Enum.Material.SmoothPlastic)
	end
	return m
end

-- Alambre de púas: 16 de ancho. No tapa el paso (se puede atravesar), pero frena y lastima
function Builder.kinds.Wire(m: Model, o: CFrame)
	for x = -8, 8, 4 do
		local post = part(m, o, Vector3.new(0.4, 3.4, 0.4), at(x, 1.7, 0), DARK_WOOD, Enum.Material.Wood)
		post.CanCollide = false
	end
	for _, y in { 1, 2, 3 } do
		for _, z in { -0.6, 0.6 } do
			local wire = part(m, o, Vector3.new(16, 0.12, 0.12), at(0, y, z), METAL, Enum.Material.Metal)
			wire.CanCollide = false
		end
	end
	-- Rollos de alambre en el piso
	for x = -6, 6, 4 do
		local coil = part(m, o, Vector3.new(3.6, 1.6, 1.6), at(x, 0.8, 0), DARK_METAL, Enum.Material.Metal, Enum.PartType.Cylinder)
		coil.Transparency = 0.5
		coil.CanCollide = false
	end
end

-- Zanja de gasolina: 60 de ancho y 4 de fondo. Las "Llama" son donde sale el fuego al
-- encenderla (TycoonService)
function Builder.kinds.FireTrench(m: Model, o: CFrame)
	local trench = part(m, o, Vector3.new(60, 0.2, 4), at(0, 0.1, 0), Color3.fromRGB(35, 30, 25), Enum.Material.Ground)
	trench.CanCollide = false
	local fuel = part(m, o, Vector3.new(58, 0.1, 2.6), at(0, 0.22, 0), Color3.fromRGB(70, 50, 90), Enum.Material.Glass)
	fuel.Transparency = 0.3
	fuel.CanCollide = false
	for x = -27, 27, 6 do
		local flame = part(m, o, Vector3.new(1, 1, 1), at(x, 1, 0), RED)
		flame.Name = "Llama"
		flame.Transparency = 1
		flame.CanCollide = false
		flame.CanQuery = false
	end
	for _, x in { -31.5, 31.5 } do
		part(m, o, Vector3.new(3, 2.4, 2.4), at(x, 1.5, 0) * UPRIGHT, RED, Enum.Material.Metal, Enum.PartType.Cylinder)
	end
end

-- Mina: explota cuando un zombi pasa cerca (WaveService) y se gasta
function Builder.kinds.Mine(m: Model, o: CFrame)
	local body = part(m, o, Vector3.new(0.5, 2.6, 2.6), at(0, 0.25, 0) * UPRIGHT, DARK_OLIVE, Enum.Material.Metal, Enum.PartType.Cylinder)
	body.CanCollide = false
	local dot = part(m, o, Vector3.new(0.3, 0.3, 0.3), at(0, 0.55, 0), RED, Enum.Material.Neon)
	dot.CanCollide = false
	light(dot, RED, 4)
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

-- Un pedazo del muro (WallService). level: 1 = madera, 2 = concreto, 3 = reforzado
local WALL_LOOK = {
	{ color = WOOD, material = Enum.Material.WoodPlanks, height = 8 },
	{ color = CONCRETE, material = Enum.Material.Concrete, height = 10 },
	{ color = DARK_METAL, material = Enum.Material.DiamondPlate, height = 12 },
}
-- door = es la puerta de ese lado: verde militar, con letrero de los dos lados. WallService la
-- pone en el grupo de choque "Puerta", que los jugadores atraviesan y los zombis no
function Builder.WallSegment(o: CFrame, width: number, level: number, door: boolean?): Part
	local look = WALL_LOOK[level] or WALL_LOOK[1]
	local p = Instance.new("Part")
	p.Name = if door then "Puerta" else "Muro"
	p.Anchored = true
	p.Size = Vector3.new(width, look.height, 2)
	p.CFrame = o * at(0, look.height / 2, 0)
	p.Color = if door then OLIVE else look.color
	p.Material = if door then Enum.Material.DiamondPlate else look.material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if door then
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local gui = Instance.new("SurfaceGui")
			gui.Face = face
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 20
			gui.Parent = p
			local text = Instance.new("TextLabel")
			text.AnchorPoint = Vector2.new(0.5, 0.5)
			text.Position = UDim2.fromScale(0.5, 0.5)
			text.Size = UDim2.fromScale(0.9, 0.25)
			text.BackgroundTransparency = 1
			text.Font = Enum.Font.GothamBlack
			text.Text = "PUERTA"
			text.TextScaled = true
			text.TextColor3 = YELLOW
			text.Parent = gui
		end
	end
	return p
end

-- Rayas amarillas en el piso que marcan hasta dónde dispara una torreta: un arco de "arc"
-- grados hacia su frente (con sus dos orillas), o un círculo si arc es 360. plot es el centro
-- del terreno: afuera de él el pasto está 1 stud más abajo
function Builder.RangeMarks(plot: CFrame, o: CFrame, range: number, arc: number): Model
	local m = Instance.new("Model")
	local function groundAt(point: Vector3): Vector3
		local here = plot:PointToObjectSpace(point)
		local outside = math.abs(here.X) > 100 or math.abs(here.Z) > 100
		return (plot * CFrame.new(here.X, if outside then -0.9 else 0.12, here.Z)).Position
	end
	local function line(from: Vector3, to: Vector3)
		local a, b = groundAt(from), groundAt(to)
		local length = (b - a).Magnitude
		if length < 0.1 then
			return
		end
		local p = part(m, CFrame.lookAt(a, b), Vector3.new(0.35, 0.05, length), at(0, 0, -length / 2), YELLOW, Enum.Material.Neon)
		p.Transparency = 0.55
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
	end
	local function pointAt(angle: number, distance: number): Vector3
		return (o * CFrame.Angles(0, math.rad(angle), 0) * CFrame.new(0, 0, -distance)).Position
	end
	local steps = math.max(math.ceil(arc / 6), 4)
	for i = 0, steps - 1 do
		local a1 = -arc / 2 + arc * i / steps
		local a2 = -arc / 2 + arc * (i + 1) / steps
		line(pointAt(a1, range), pointAt(a2, range))
	end
	if arc < 360 then
		line(pointAt(-arc / 2, 4), pointAt(-arc / 2, range))
		line(pointAt(arc / 2, 4), pointAt(arc / 2, range))
	end
	return m
end

-- Arma una construcción y la devuelve (sin ponerla en el mundo)
function Builder.Build(kind: string, o: CFrame): Model
	local m = Instance.new("Model")
	local draw = Builder.kinds[kind]
	if draw then
		-- Si un dibujo tiene un error, se avisa en Output pero el juego sigue
		local ok, err = pcall(draw, m, o)
		if not ok then
			warn("[Builder] Error al dibujar", kind, err)
		end
	else
		warn("[Builder] No hay dibujo para", kind)
		part(m, o, Vector3.new(4, 4, 4), at(0, 2, 0), RED)
	end
	return m
end

return Builder
