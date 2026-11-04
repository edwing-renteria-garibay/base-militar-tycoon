-- Cómo se ve cada tipo de zombi (WaveService los viste una vez, en su plantilla). Todos son
-- gente de la base que se infectó: soldados, obreros, científicos... cada tipo con lo suyo, y
-- todos con los ojos que brillan del color de su tipo.
--
-- Las piezas van pegadas (WeldConstraint) a las partes del cuerpo y no estorban: no chocan y
-- las balas las atraviesan (CanQuery = false), así el tiro en la cabeza sigue contando.

local ZombieLooks = {}

local OLIVE = Color3.fromRGB(70, 78, 50)
local DARK = Color3.fromRGB(35, 36, 38)
local METAL = Color3.fromRGB(95, 98, 104)
local RUST = Color3.fromRGB(120, 70, 40)
local BONE = Color3.fromRGB(225, 215, 190)
local BLOOD = Color3.fromRGB(90, 20, 20)

-- Pega una pieza a una parte del cuerpo. offset se mide desde el centro de esa parte, en
-- fracciones de su tamaño, y size en studs para un zombi normal (cabeza de 1.2): en uno más
-- grande todo crece igual
local function add(
	model: Model,
	partName: string,
	size: Vector3,
	offset: Vector3,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?,
	rotation: CFrame?
): Part?
	local body = model:FindFirstChild(partName) :: BasePart?
	if not body then
		return nil
	end
	local scale = body.Size
	local head = model:FindFirstChild("Head") :: BasePart?
	local factor = if head then head.Size.Y / 1.2 else 1
	local p = Instance.new("Part")
	p.Name = "Detalle"
	p.Size = size * factor
	p.Shape = shape or Enum.PartType.Block
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CFrame = body.CFrame * CFrame.new(offset.X * scale.X, offset.Y * scale.Y, offset.Z * scale.Z) * (rotation or CFrame.new())
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = p
	weld.Parent = p
	p.Parent = model
	return p
end

local function glowing(p: Part?, color: Color3, range: number)
	if p then
		p.Material = Enum.Material.Neon
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = range
		light.Brightness = 1
		light.Parent = p
	end
end

-- Ojos que brillan (el frente de la cabeza es -Z)
local function eyes(model: Model, color: Color3)
	for _, x in { -0.18, 0.18 } do
		local eye = add(model, "Head", Vector3.new(0.16, 0.1, 0.06), Vector3.new(x, 0.08, -0.5), color, Enum.Material.Neon)
		if eye and x > 0 then
			glowing(eye, color, 5)
		end
	end
	-- Boca rota
	add(model, "Head", Vector3.new(0.4, 0.08, 0.05), Vector3.new(0, -0.22, -0.5), BLOOD)
end

-- Ropa rota y costillas que se asoman
local function torn(model: Model)
	add(model, "UpperTorso", Vector3.new(0.5, 0.6, 0.06), Vector3.new(0.18, -0.05, -0.5), Color3.fromRGB(150, 70, 60))
	for i = 0, 2 do
		add(model, "UpperTorso", Vector3.new(0.4, 0.06, 0.07), Vector3.new(0.18, 0.12 - i * 0.12, -0.52), BONE)
	end
	add(model, "LeftUpperArm", Vector3.new(0.3, 0.3, 0.05), Vector3.new(0, 0, -0.52), BLOOD)
end

local function helmet(model: Model, color: Color3)
	add(model, "Head", Vector3.new(0.75, 1.35, 1.35), Vector3.new(0, 0.38, 0), color, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder, CFrame.Angles(0, 0, math.rad(90)))
	add(model, "Head", Vector3.new(1.5, 0.1, 1.5), Vector3.new(0, 0.12, -0.02), color, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder, CFrame.Angles(0, 0, math.rad(90)))
end

local LOOKS = {}

-- Soldado infectado: casco con una abolladura, chaleco y placas de identificación
LOOKS.Normal = function(model: Model)
	helmet(model, OLIVE)
	add(model, "UpperTorso", Vector3.new(2.1, 1.3, 1.15), Vector3.new(0, 0.05, 0), Color3.fromRGB(60, 66, 44), Enum.Material.Fabric)
	add(model, "UpperTorso", Vector3.new(0.2, 0.3, 0.05), Vector3.new(-0.15, 0.25, -0.58), METAL, Enum.Material.Metal) -- placas
	torn(model)
	eyes(model, Color3.fromRGB(255, 220, 60))
end

-- Trepador: encapuchado y con garras largas
LOOKS.Trepador = function(model: Model)
	add(model, "Head", Vector3.new(1.4, 1.4, 1.4), Vector3.new(0, 0.12, 0.12), Color3.fromRGB(60, 30, 80), Enum.Material.Fabric)
	for _, hand in { "LeftHand", "RightHand" } do
		for _, x in { -0.3, 0, 0.3 } do
			add(model, hand, Vector3.new(0.08, 0.6, 0.08), Vector3.new(x, -0.9, -0.2), BONE, Enum.Material.SmoothPlastic, nil, CFrame.Angles(math.rad(-25), 0, 0))
		end
	end
	torn(model)
	eyes(model, Color3.fromRGB(200, 90, 255))
end

-- Demoledor: obrero con casco naranja, placas de metal y varillas de construcción en la espalda
LOOKS.Demoledor = function(model: Model)
	helmet(model, Color3.fromRGB(240, 140, 20))
	add(model, "UpperTorso", Vector3.new(2, 1.1, 0.25), Vector3.new(0, 0.05, -0.55), METAL, Enum.Material.DiamondPlate)
	for _, arm in { "LeftUpperArm", "RightUpperArm" } do
		add(model, arm, Vector3.new(1.1, 0.5, 1.1), Vector3.new(0, 0.45, 0), RUST, Enum.Material.CorrodedMetal)
	end
	for _, x in { -0.25, 0.1, 0.35 } do
		add(model, "UpperTorso", Vector3.new(0.12, 2.4, 0.12), Vector3.new(x, 0.6, 0.55), RUST, Enum.Material.CorrodedMetal, nil, CFrame.Angles(0, 0, math.rad(x * 40)))
	end
	eyes(model, Color3.fromRGB(255, 140, 30))
end

-- Saboteador: máscara de gas con filtros y una mochila con cables
LOOKS.Saboteador = function(model: Model)
	add(model, "Head", Vector3.new(0.9, 0.7, 0.3), Vector3.new(0, -0.05, -0.45), DARK, Enum.Material.Rubber)
	for _, x in { -0.3, 0.3 } do
		add(model, "Head", Vector3.new(0.35, 0.3, 0.3), Vector3.new(x, -0.3, -0.55), DARK, Enum.Material.Metal, Enum.PartType.Cylinder, CFrame.Angles(0, math.rad(90), 0))
	end
	add(model, "UpperTorso", Vector3.new(1.4, 1.4, 0.7), Vector3.new(0, 0, 0.75), Color3.fromRGB(90, 85, 30), Enum.Material.Fabric)
	glowing(add(model, "UpperTorso", Vector3.new(0.3, 0.3, 0.1), Vector3.new(0.3, 0.3, 1.1), Color3.fromRGB(255, 40, 30)), Color3.fromRGB(255, 40, 30), 4)
	eyes(model, Color3.fromRGB(255, 240, 80)) -- (brillan a través de la máscara)
end

-- Corrosivo: lleno de ampollas verdes que brillan
LOOKS.Explosivo = function(model: Model)
	local green = Color3.fromRGB(140, 255, 70)
	for _, spot in {
		{ "Head", Vector3.new(0.4, 0.3, -0.35) },
		{ "Head", Vector3.new(-0.35, 0.45, 0.2) },
		{ "LeftUpperArm", Vector3.new(0, 0.1, -0.45) },
		{ "RightLowerArm", Vector3.new(0.3, 0, -0.3) },
		{ "UpperTorso", Vector3.new(-0.35, 0.3, -0.5) },
		{ "LowerTorso", Vector3.new(0.3, 0, -0.5) },
	} do
		add(model, spot[1], Vector3.new(0.3, 0.3, 0.3), spot[2], green, Enum.Material.Neon, Enum.PartType.Ball)
	end
	torn(model)
	eyes(model, green)
end

-- Teletransportador: grietas de luz azul por todo el cuerpo y chispas
LOOKS.Teletransportador = function(model: Model)
	local cyan = Color3.fromRGB(80, 230, 255)
	for _, crack in {
		{ "UpperTorso", Vector3.new(0.08, 0.9, 0.05), Vector3.new(-0.1, 0, -0.52), 20 },
		{ "UpperTorso", Vector3.new(0.08, 0.6, 0.05), Vector3.new(0.25, 0.1, -0.52), -30 },
		{ "Head", Vector3.new(0.06, 0.5, 0.05), Vector3.new(0.3, 0.1, -0.5), 15 },
		{ "LeftUpperArm", Vector3.new(0.06, 0.8, 0.05), Vector3.new(0, 0, -0.52), 10 },
		{ "RightUpperLeg", Vector3.new(0.06, 0.8, 0.05), Vector3.new(0, 0, -0.52), -10 },
	} do
		add(model, crack[1], crack[2], crack[3], cyan, Enum.Material.Neon, nil, CFrame.Angles(0, 0, math.rad(crack[4])))
	end
	local torso = model:FindFirstChild("UpperTorso")
	if torso then
		local sparks = Instance.new("ParticleEmitter")
		sparks.Color = ColorSequence.new(cyan)
		sparks.LightEmission = 1
		sparks.Size = NumberSequence.new(0.15)
		sparks.Lifetime = NumberRange.new(0.4, 0.8)
		sparks.Rate = 8
		sparks.Speed = NumberRange.new(1, 3)
		sparks.SpreadAngle = Vector2.new(180, 180)
		sparks.Parent = torso
	end
	eyes(model, cyan)
end

-- Kamikaze: chaleco de explosivos (cartuchos rojos con cinta)
LOOKS.Kamikaze = function(model: Model)
	for _, x in { -0.35, -0.12, 0.12, 0.35 } do
		add(model, "UpperTorso", Vector3.new(0.3, 0.8, 0.3), Vector3.new(x, -0.1, -0.6), Color3.fromRGB(170, 30, 25), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder, CFrame.Angles(0, 0, math.rad(90)))
	end
	add(model, "UpperTorso", Vector3.new(2.05, 0.15, 1.15), Vector3.new(0, -0.1, 0), Color3.fromRGB(40, 40, 40))
	add(model, "Head", Vector3.new(1.3, 0.25, 1.3), Vector3.new(0, 0.15, 0), Color3.fromRGB(160, 30, 30), Enum.Material.Fabric) -- paliacate
	torn(model)
	eyes(model, Color3.fromRGB(255, 60, 40))
end

-- El jefe: cuernos, hombreras con picos y un núcleo rojo en el pecho
LOOKS.Jefe = function(model: Model)
	local red = Color3.fromRGB(255, 40, 30)
	for _, x in { -0.35, 0.35 } do
		add(model, "Head", Vector3.new(0.2, 0.7, 0.2), Vector3.new(x, 0.6, 0), BONE, Enum.Material.SmoothPlastic, nil, CFrame.Angles(0, 0, math.rad(-x * 60)))
	end
	for _, arm in { "LeftUpperArm", "RightUpperArm" } do
		add(model, arm, Vector3.new(1.3, 0.6, 1.3), Vector3.new(0, 0.5, 0), DARK, Enum.Material.DiamondPlate)
		for _, z in { -0.3, 0.3 } do
			add(model, arm, Vector3.new(0.15, 0.6, 0.15), Vector3.new(0, 0.9, z), METAL, Enum.Material.Metal)
		end
	end
	add(model, "UpperTorso", Vector3.new(1.8, 1.1, 0.25), Vector3.new(0, 0.05, -0.55), DARK, Enum.Material.DiamondPlate)
	glowing(add(model, "UpperTorso", Vector3.new(0.5, 0.5, 0.3), Vector3.new(0, 0.05, -0.75), red, Enum.Material.Neon, Enum.PartType.Ball), red, 12)
	eyes(model, red)
end

-- Científico del laboratorio infestado: bata blanca manchada y lentes
LOOKS.Cientifico = function(model: Model)
	add(model, "UpperTorso", Vector3.new(2.1, 1.25, 1.15), Vector3.new(0, 0, 0), Color3.fromRGB(230, 230, 225), Enum.Material.Fabric)
	add(model, "LowerTorso", Vector3.new(2.1, 1.3, 1.15), Vector3.new(0, -0.3, 0), Color3.fromRGB(230, 230, 225), Enum.Material.Fabric)
	add(model, "UpperTorso", Vector3.new(0.6, 0.5, 0.05), Vector3.new(-0.2, -0.1, -0.53), Color3.fromRGB(110, 170, 60)) -- mancha
	add(model, "Head", Vector3.new(0.8, 0.12, 0.05), Vector3.new(0, 0.08, -0.53), DARK) -- lentes
	eyes(model, Color3.fromRGB(150, 255, 120))
end

-- La postura de zombi: un brazo estirado hacia ti, el otro con su arma, encorvado y con la
-- cabeza de lado (girando las articulaciones, Motor6D)
function ZombieLooks.Pose(model: Model)
	local function bend(partName: string, jointName: string, rotation: CFrame)
		local part = model:FindFirstChild(partName)
		local joint = part and part:FindFirstChild(jointName)
		if joint and joint:IsA("Motor6D") then
			joint.C0 *= rotation
		end
	end
	bend("LeftUpperArm", "LeftShoulder", CFrame.Angles(math.rad(80), 0, math.rad(-8)))
	bend("RightUpperArm", "RightShoulder", CFrame.Angles(math.rad(35), 0, math.rad(10)))
	bend("LeftLowerArm", "LeftElbow", CFrame.Angles(math.rad(15), 0, 0))
	bend("UpperTorso", "Waist", CFrame.Angles(math.rad(-14), math.rad(6), 0))
	bend("Head", "Neck", CFrame.Angles(math.rad(-8), 0, math.rad(16)))
end

-- Al morir cae como muñeco de trapo en vez de deshacerse en piezas: cada articulación se
-- vuelve una rótula floja
function ZombieLooks.Ragdoll(model: Model)
	for _, joint in model:GetDescendants() do
		if joint:IsA("Motor6D") and joint.Part0 and joint.Part1 and joint.Name ~= "Root" then
			local a0 = Instance.new("Attachment")
			a0.CFrame = joint.C0
			a0.Parent = joint.Part0
			local a1 = Instance.new("Attachment")
			a1.CFrame = joint.C1
			a1.Parent = joint.Part1
			local socket = Instance.new("BallSocketConstraint")
			socket.Attachment0 = a0
			socket.Attachment1 = a1
			socket.LimitsEnabled = true
			socket.TwistLimitsEnabled = true
			socket.UpperAngle = 60
			socket.TwistLowerAngle = -30
			socket.TwistUpperAngle = 30
			socket.Parent = joint.Part1
			joint:Destroy()
		end
	end
	for _, piece in model:GetDescendants() do
		if piece:IsA("BasePart") and piece.Name ~= "HumanoidRootPart" and piece.Name ~= "Detalle" and piece.Name ~= "ArmaZombi" then
			piece.CanCollide = true -- para que caiga al piso y no lo atraviese
		end
	end
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root.CanCollide = false
	end
end

-- Viste a un zombi según su tipo (key: Normal, Trepador, Jefe...)
function ZombieLooks.Dress(model: Model, key: string)
	local look = LOOKS[key] or LOOKS.Normal
	local ok, err = pcall(look, model)
	if not ok then
		warn("[Zombis] No se pudo vestir a", key, err) -- el zombi sale igual, sin adornos
	end
end

return ZombieLooks
