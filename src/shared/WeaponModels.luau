-- La forma de cada arma (Config/Weapons), hecha con piezas. Son las mismas de Escuadrón Cero.
--
-- Cada pieza se mide desde el punto donde la mano derecha agarra el arma:
--   X = hacia la derecha · Y = hacia arriba · Z negativo = hacia el frente (hacia donde dispara)
-- La primera pieza de cada arma es el cuerpo: se vuelve la Handle de la herramienta.
-- muzzle: la boca del cañón (de ahí salen el fogonazo y la bala)
-- leftHand: dónde va la mano izquierda (ver TwoHands en el servidor, y los brazos de
--   src/client/ViewModel.luau en primera persona)
-- view: dónde queda el arma en primera persona, medido desde la cámara
-- kick, kickAngle: cuánto se va hacia atrás (studs) y cuánto sube (grados) al disparar
--
-- La usan el servidor (el arma que todos ven en tu mano) y el cliente (el arma en primera
-- persona).

local WeaponModels = {}

local rad = math.rad

-- Colores y materiales
local BLACK = { Color3.fromRGB(34, 34, 36), Enum.Material.Metal }
local STEEL = { Color3.fromRGB(78, 80, 84), Enum.Material.Metal }
local POLYMER = { Color3.fromRGB(44, 44, 42), Enum.Material.SmoothPlastic }
local OLIVE = { Color3.fromRGB(78, 82, 58), Enum.Material.SmoothPlastic }
local OLIVE_DARK = { Color3.fromRGB(56, 60, 42), Enum.Material.Metal }
local WOOD = { Color3.fromRGB(92, 60, 38), Enum.Material.Wood }
local BRASS = { Color3.fromRGB(200, 160, 70), Enum.Material.Metal }
local SHELL_RED = { Color3.fromRGB(170, 35, 30), Enum.Material.SmoothPlastic }
local GLASS = { Color3.fromRGB(120, 160, 170), Enum.Material.Glass }
local GLOW_RED = { Color3.fromRGB(255, 50, 50), Enum.Material.Neon }

-- Un cilindro de Roblox es largo en X; girado 90° queda a lo largo de Z (como un cañón)
local ALONG_Z = CFrame.Angles(0, rad(90), 0)

export type Piece = {
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	cylinder: boolean?,
}

export type Spec = {
	pieces: { Piece },
	muzzle: CFrame,
	leftHand: CFrame,
	view: CFrame,
	kick: number,
	kickAngle: number,
}

local function box(name: string, size: Vector3, cframe: CFrame, look): Piece
	return { name = name, size = size, cframe = cframe, color = look[1], material = look[2] }
end

-- Cilindro a lo largo de Z: (largo, grosor)
local function tube(name: string, length: number, thickness: number, position: Vector3, look): Piece
	return {
		name = name,
		size = Vector3.new(length, thickness, thickness),
		cframe = CFrame.new(position) * ALONG_Z,
		color = look[1],
		material = look[2],
		cylinder = true,
	}
end

local V = Vector3.new
local C = CFrame.new

-- Una por cada arma de Config/Weapons (mismo id)
WeaponModels.Specs = {
	-- Rifle de asalto, estilo militar con riel arriba
	Rifle = {
		pieces = {
			box("Receiver", V(0.28, 0.38, 1.3), C(0, 0.32, -0.25), BLACK),
			box("Rail", V(0.2, 0.08, 1.9), C(0, 0.55, -0.6), STEEL),
			box("Handguard", V(0.32, 0.34, 1.0), C(0, 0.3, -1.4), OLIVE),
			tube("Barrel", 0.9, 0.12, V(0, 0.33, -2.3), BLACK),
			tube("FlashHider", 0.22, 0.17, V(0, 0.33, -2.85), STEEL),
			box("FrontSight", V(0.06, 0.24, 0.08), C(0, 0.62, -1.75), BLACK),
			box("RearSight", V(0.16, 0.14, 0.14), C(0, 0.65, 0.2), BLACK),
			box("Magazine", V(0.2, 0.62, 0.32), C(0, -0.1, -0.55) * CFrame.Angles(rad(14), 0, 0), POLYMER),
			box("Grip", V(0.2, 0.46, 0.24), C(0, -0.05, 0.05) * CFrame.Angles(rad(-18), 0, 0), POLYMER),
			box("Trigger", V(0.05, 0.14, 0.05), C(0, 0.06, -0.15), STEEL),
			box("Stock", V(0.24, 0.32, 0.9), C(0, 0.27, 0.85), OLIVE),
			box("ButtPad", V(0.26, 0.5, 0.12), C(0, 0.2, 1.32), POLYMER),
			-- Mira de punto rojo sobre el riel
			box("SightBase", V(0.2, 0.08, 0.34), C(0, 0.63, -0.3), BLACK),
			box("SightTop", V(0.24, 0.04, 0.3), C(0, 0.92, -0.3), BLACK),
			box("SightLeft", V(0.03, 0.26, 0.3), C(-0.105, 0.8, -0.3), BLACK),
			box("SightRight", V(0.03, 0.26, 0.3), C(0.105, 0.8, -0.3), BLACK),
			box("RedDot", V(0.03, 0.03, 0.02), C(0, 0.8, -0.4), GLOW_RED),
			box("Sling", V(0.04, 0.12, 0.12), C(-0.16, 0.2, 1.1), STEEL),
		},
		muzzle = C(0, 0.33, -3.0),
		leftHand = C(0, 0.15, -1.45),
		view = C(0.62, -0.78, -1.3) * CFrame.Angles(0, rad(5), 0),
		kick = 0.1,
		kickAngle = 1.2,
	},
	-- Escopeta de corredera, con madera
	Escopeta = {
		pieces = {
			box("Receiver", V(0.3, 0.4, 1.1), C(0, 0.3, -0.3), BLACK),
			tube("Barrel", 2.0, 0.16, V(0, 0.42, -1.85), BLACK),
			tube("Tube", 1.6, 0.16, V(0, 0.22, -1.7), STEEL),
			box("Pump", V(0.3, 0.26, 0.7), C(0, 0.22, -1.6), WOOD),
			box("Stock", V(0.24, 0.36, 1.1), C(0, 0.18, 0.75) * CFrame.Angles(rad(8), 0, 0), WOOD),
			box("Grip", V(0.2, 0.42, 0.24), C(0, -0.05, 0.08) * CFrame.Angles(rad(-20), 0, 0), BLACK),
			box("Bead", V(0.05, 0.06, 0.05), C(0, 0.53, -2.8), STEEL),
			-- Cartuchos de repuesto en el costado
			box("ShellHolder", V(0.04, 0.24, 0.62), C(-0.17, 0.3, -0.3), BLACK),
			box("Shell1", V(0.08, 0.18, 0.1), C(-0.21, 0.3, -0.52), SHELL_RED),
			box("Shell2", V(0.08, 0.18, 0.1), C(-0.21, 0.3, -0.37), SHELL_RED),
			box("Shell3", V(0.08, 0.18, 0.1), C(-0.21, 0.3, -0.22), SHELL_RED),
			box("Shell4", V(0.08, 0.18, 0.1), C(-0.21, 0.3, -0.07), SHELL_RED),
		},
		muzzle = C(0, 0.42, -2.9),
		leftHand = C(0, 0.1, -1.6),
		view = C(0.6, -0.8, -1.3) * CFrame.Angles(0, rad(5), 0),
		kick = 0.3,
		kickAngle = 8,
	},
	-- Ametralladora ligera: cañón grueso con agujeros, caja de balas, cinta y bípode
	Ametralladora = {
		pieces = {
			box("Receiver", V(0.34, 0.44, 1.5), C(0, 0.32, -0.3), OLIVE_DARK),
			box("TopCover", V(0.3, 0.1, 1.2), C(0, 0.59, -0.35), BLACK),
			tube("Jacket", 1.3, 0.24, V(0, 0.34, -1.7), BLACK),
			box("JacketHoles", V(0.26, 0.04, 1.1), C(0, 0.47, -1.7), STEEL),
			tube("Barrel", 0.8, 0.13, V(0, 0.34, -2.75), BLACK),
			tube("FlashHider", 0.26, 0.2, V(0, 0.34, -3.2), STEEL),
			box("CarryHandle", V(0.08, 0.08, 0.6), C(0, 0.8, -0.4), BLACK),
			box("HandleLeg", V(0.08, 0.16, 0.08), C(0, 0.69, -0.65), BLACK),
			box("AmmoBox", V(0.5, 0.5, 0.5), C(-0.4, 0.05, -0.45), OLIVE),
			box("Belt", V(0.18, 0.06, 0.34), C(-0.17, 0.42, -0.45) * CFrame.Angles(0, 0, rad(-30)), BRASS),
			box("Grip", V(0.2, 0.46, 0.24), C(0, -0.05, 0.05) * CFrame.Angles(rad(-18), 0, 0), POLYMER),
			box("Trigger", V(0.05, 0.14, 0.05), C(0, 0.06, -0.15), STEEL),
			box("Stock", V(0.26, 0.4, 1.0), C(0, 0.24, 0.9), OLIVE_DARK),
			box("ButtPad", V(0.28, 0.52, 0.12), C(0, 0.2, 1.42), POLYMER),
			box("BipodLeft", V(0.06, 0.6, 0.06), C(-0.12, 0.05, -2.2) * CFrame.Angles(rad(-35), 0, rad(-10)), BLACK),
			box("BipodRight", V(0.06, 0.6, 0.06), C(0.12, 0.05, -2.2) * CFrame.Angles(rad(-35), 0, rad(10)), BLACK),
		},
		muzzle = C(0, 0.34, -3.35),
		leftHand = C(0, 0.15, -1.4),
		view = C(0.62, -0.82, -1.3) * CFrame.Angles(0, rad(5), 0),
		kick = 0.06,
		kickAngle = 0.8,
	},
	-- Francotirador: cañón largo y mira telescópica
	Francotirador = {
		pieces = {
			box("Receiver", V(0.26, 0.36, 1.2), C(0, 0.32, -0.2), BLACK),
			tube("Barrel", 2.8, 0.14, V(0, 0.36, -2.2), BLACK),
			tube("Brake", 0.3, 0.22, V(0, 0.36, -3.65), STEEL),
			tube("Scope", 1.3, 0.26, V(0, 0.78, -0.3), BLACK),
			tube("ScopeFront", 0.12, 0.34, V(0, 0.78, -1.0), BLACK),
			tube("ScopeBack", 0.12, 0.3, V(0, 0.78, 0.4), BLACK),
			box("MountFront", V(0.1, 0.18, 0.1), C(0, 0.58, -0.6), STEEL),
			box("MountBack", V(0.1, 0.18, 0.1), C(0, 0.58, 0.05), STEEL),
			box("Stock", V(0.24, 0.42, 1.2), C(0, 0.2, 0.95), OLIVE),
			box("Cheek", V(0.22, 0.12, 0.6), C(0, 0.46, 0.85), OLIVE),
			box("Magazine", V(0.2, 0.36, 0.3), C(0, 0.0, -0.45), POLYMER),
			box("Grip", V(0.2, 0.45, 0.24), C(0, -0.05, 0.08) * CFrame.Angles(rad(-18), 0, 0), POLYMER),
			-- El cerrojo (la palanca para cargar) y la lente de la mira
			box("Bolt", V(0.26, 0.06, 0.06), C(0.2, 0.4, 0.15), STEEL),
			box("BoltKnob", V(0.12, 0.12, 0.12), C(0.36, 0.38, 0.15), BLACK),
			box("ScopeLens", V(0.24, 0.24, 0.02), C(0, 0.78, -1.07), GLASS),
		},
		muzzle = C(0, 0.36, -3.85),
		leftHand = C(0, 0.15, -1.3),
		view = C(0.6, -0.8, -1.2) * CFrame.Angles(0, rad(5), 0),
		kick = 0.35,
		kickAngle = 9,
	},
} :: { [string]: Spec }
local SPECS = WeaponModels.Specs

local function makePart(piece: Piece): Part
	local part = Instance.new("Part")
	part.Name = piece.name
	part.Size = piece.size
	part.Color = piece.color
	part.Material = piece.material
	if piece.cylinder then
		part.Shape = Enum.PartType.Cylinder
	end
	part.CanCollide = false
	part.CanQuery = false -- las balas lo atraviesan
	part.CanTouch = false
	part.Massless = true
	return part
end

-- Hace la herramienta (Tool) de un arma de Config/Weapons, con todas sus piezas soldadas a la
-- Handle, el punto "Muzzle" (la boca del cañón) y "LeftHandGrip" (para la mano izquierda)
function WeaponModels.MakeTool(weapon): Tool
	local tool = Instance.new("Tool")
	tool.Name = weapon.id
	tool.ToolTip = weapon.name
	tool.CanBeDropped = false
	local spec = SPECS[weapon.id] or SPECS.Rifle
	local body = spec.pieces[1]
	local handle = makePart(body)
	handle.Name = "Handle"
	handle.Parent = tool
	-- Tool.Grip dice dónde queda la mano respecto a la Handle
	tool.Grip = body.cframe:Inverse()
	for i = 2, #spec.pieces do
		local part = makePart(spec.pieces[i])
		-- Una Weld guarda la posición de la pieza respecto a la Handle (C0)
		local weld = Instance.new("Weld")
		weld.Part0 = handle
		weld.Part1 = part
		weld.C0 = body.cframe:Inverse() * spec.pieces[i].cframe
		weld.Parent = part
		part.Parent = handle
	end
	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.CFrame = body.cframe:Inverse() * spec.muzzle
	muzzle.Parent = handle
	local leftGrip = Instance.new("Attachment")
	leftGrip.Name = "LeftHandGrip"
	leftGrip.Position = (body.cframe:Inverse() * spec.leftHand).Position
	leftGrip.Parent = handle
	return tool
end

-- Cliente: las piezas sueltas (sin soldar) para moverlas cada fotograma en primera persona.
-- Devuelve las piezas y dónde va cada una, medido desde la mano.
function WeaponModels.BuildLoose(id: string): ({ BasePart }, { CFrame })
	local spec = SPECS[id] or SPECS.Rifle
	local parts, offsets = {}, {}
	for _, piece in spec.pieces do
		local part = makePart(piece)
		part.Anchored = true
		part.CastShadow = false
		table.insert(parts, part)
		table.insert(offsets, piece.cframe)
	end
	return parts, offsets
end

return WeaponModels
