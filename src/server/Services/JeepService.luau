-- El jeep que sale del garaje: cada jugador puede tener uno. Lo saca con el letrero del garaje
-- y se maneja con W/A/S/D (o el stick en celular), como cualquier asiento de Roblox.
--
-- Conducción "arcade" (la misma idea que en Escuadrón Cero): en lugar de simular motor y
-- ruedas, dos restricciones de física empujan el chasis. LinearVelocity lo lleva hacia
-- delante o atrás sin derrapar y AngularVelocity lo hace girar y lo mantiene derecho.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local JeepService = {}

local MAX_SPEED = 50 -- studs por segundo hacia delante
local REVERSE_SPEED = 20 -- en reversa
local TURN_RATE = 2.4 -- radianes por segundo al girar
local RUN_OVER_SPEED = 15 -- a partir de esta velocidad, el jeep atropella enemigos...
local RUN_OVER_DAMAGE = 150 -- ...y les quita esto de vida

local OLIVE = Color3.fromRGB(85, 92, 60)
local OLIVE_DARK = Color3.fromRGB(64, 70, 46)
local DARK = Color3.fromRGB(35, 35, 35)
local GOLD = Color3.fromRGB(230, 180, 50) -- con el pase "Jeep dorado"

local jeeps: { [Player]: Model } = {}

-- Una pieza soldada al chasis; offset es su posición relativa al chasis
local function addPart(model: Model, chassis: BasePart, className: string, size: Vector3, offset: CFrame, color: Color3): BasePart
	local part = Instance.new(className) :: BasePart
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.Metal
	part.Massless = true -- solo el chasis pesa; así el manejo es predecible
	part.CFrame = chassis.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = chassis
	weld.Part1 = part
	weld.Parent = part
	part.Parent = model
	return part
end

local function build(cframe: CFrame, golden: boolean): Model
	local model = Instance.new("Model")
	model.Name = "Jeep"
	local chassis = Instance.new("Part")
	chassis.Name = "Chassis"
	chassis.Size = Vector3.new(7, 1.5, 11)
	chassis.Color = if golden then GOLD else OLIVE
	chassis.Material = Enum.Material.Metal
	chassis.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0)
	chassis.CFrame = cframe
	chassis.RootPriority = 1
	chassis.Parent = model
	-- Atropellar enemigos de las olas (las ruedas y la carrocería van soldadas al chasis)
	chassis.Touched:Connect(function(hit)
		local enemy = hit:FindFirstAncestorOfClass("Model")
		if not enemy or not CollectionService:HasTag(enemy, "Enemy") then
			return
		end
		local humanoid = enemy:FindFirstChildOfClass("Humanoid")
		local speed = chassis.AssemblyLinearVelocity.Magnitude
		if humanoid and humanoid.Health > 0 and speed >= RUN_OVER_SPEED then
			humanoid:TakeDamage(RUN_OVER_DAMAGE)
		end
	end)
	model.PrimaryPart = chassis

	-- Ruedas: cilindros soldados que tocan el suelo un poco por debajo del chasis
	for _, x in { -3.9, 3.9 } do
		for _, z in { -3.8, 3.8 } do
			local wheel = addPart(model, chassis, "Part", Vector3.new(1.4, 3.4, 3.4), CFrame.new(x, -0.8, z), DARK)
			wheel.Shape = Enum.PartType.Cylinder
			wheel.Material = Enum.Material.Rubber
			wheel.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0)
		end
	end
	-- Carrocería
	local trim = if golden then GOLD else OLIVE_DARK
	addPart(model, chassis, "Part", Vector3.new(7, 1.2, 3), CFrame.new(0, 1.3, -4), trim) -- cofre
	addPart(model, chassis, "Part", Vector3.new(7, 2, 0.4), CFrame.new(0, 1.7, 5.3), trim) -- atrás
	local glass = addPart(model, chassis, "Part", Vector3.new(6.4, 2, 0.2), CFrame.new(0, 2.8, -2.4), Color3.fromRGB(120, 170, 200))
	glass.Material = Enum.Material.Glass
	glass.Transparency = 0.4
	for _, x in { -3.4, 3.4 } do
		addPart(model, chassis, "Part", Vector3.new(0.3, 3.5, 0.3), CFrame.new(x, 3, 1.5), DARK) -- barra antivuelco
	end
	addPart(model, chassis, "Part", Vector3.new(7, 0.3, 0.3), CFrame.new(0, 4.8, 1.5), DARK)
	for _, x in { -2.5, 2.5 } do
		local lamp = addPart(model, chassis, "Part", Vector3.new(1, 0.6, 0.1), CFrame.new(x, 1.3, -5.55), Color3.fromRGB(255, 240, 200))
		lamp.Material = Enum.Material.Neon
	end

	-- Asientos (el frente de un asiento es su lado -Z, igual que el del chasis)
	local seat = addPart(model, chassis, "VehicleSeat", Vector3.new(2, 1, 2), CFrame.new(-1.5, 1.25, -0.8), DARK) :: VehicleSeat
	seat.Name = "DriverSeat"
	seat.MaxSpeed = 0 -- la velocidad la controla este script, no el asiento
	addPart(model, chassis, "Seat", Vector3.new(2, 1, 2), CFrame.new(1.5, 1.25, -0.8), DARK)
	addPart(model, chassis, "Seat", Vector3.new(2, 1, 2), CFrame.new(0, 1.25, 3.5), DARK)

	-- Motor: restricciones que el servidor ajusta en cada fotograma (update)
	local attachment = Instance.new("Attachment")
	attachment.Parent = chassis
	local drive = Instance.new("LinearVelocity")
	drive.Name = "Drive"
	drive.Attachment0 = attachment
	drive.RelativeTo = Enum.ActuatorRelativeTo.World
	drive.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	drive.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	drive.MaxAxesForce = Vector3.new(1e6, 0, 1e6) -- 0 en Y: la gravedad sigue funcionando
	drive.VectorVelocity = Vector3.zero
	drive.Parent = chassis
	local steering = Instance.new("AngularVelocity")
	steering.Name = "Steering"
	steering.Attachment0 = attachment
	steering.RelativeTo = Enum.ActuatorRelativeTo.World
	steering.MaxTorque = 1e7
	steering.AngularVelocity = Vector3.zero
	steering.Parent = chassis
	return model
end

-- Cada fotograma: leer el asiento del conductor y ajustar el motor
local function update(model: Model)
	local chassis = model.PrimaryPart
	local seat = model:FindFirstChild("DriverSeat") :: VehicleSeat?
	if not chassis or not seat then
		return
	end
	local drive = chassis:FindFirstChild("Drive") :: LinearVelocity
	local steering = chassis:FindFirstChild("Steering") :: AngularVelocity
	local hasDriver = seat.Occupant ~= nil
	local throttle = if hasDriver then seat.ThrottleFloat else 0 -- W = 1, S = -1
	local steer = if hasDriver then seat.SteerFloat else 0 -- D = 1, A = -1

	local forward = if throttle >= 0 then throttle * MAX_SPEED else throttle * REVERSE_SPEED
	local look = chassis.CFrame.LookVector
	local flatForward = Vector3.new(look.X, 0, look.Z)
	if flatForward.Magnitude > 0.01 then
		drive.VectorVelocity = flatForward.Unit * forward
	end
	-- Como un coche: gira más cuanto más rápido va, y al revés en reversa
	local speed = chassis.AssemblyLinearVelocity:Dot(look)
	local turnFactor = math.clamp(math.abs(speed) / 12, 0, 1) * math.sign(speed)
	steering.AngularVelocity = Vector3.new(0, -steer * TURN_RATE * turnFactor, 0)
end

-- Saca un jeep nuevo en cframe (si ya tenía uno, el viejo desaparece)
function JeepService.Spawn(player: Player, cframe: CFrame, parent: Instance)
	JeepService.Remove(player)
	local model = build(cframe + Vector3.new(0, 3, 0), player:GetAttribute("Pass_JeepOro") == true)
	model.Parent = parent
	model.PrimaryPart:SetNetworkOwner(nil) -- el servidor maneja la física del jeep
	jeeps[player] = model
end

function JeepService.Remove(player: Player)
	local model = jeeps[player]
	if model then
		model:Destroy()
		jeeps[player] = nil
	end
end

function JeepService.Start()
	RunService.Heartbeat:Connect(function()
		for player, model in jeeps do
			if model.Parent then
				update(model)
			else
				jeeps[player] = nil -- se borró con el terreno
			end
		end
	end)
end

return JeepService
