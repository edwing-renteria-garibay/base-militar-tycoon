-- Cámara, igual que en Escuadrón Cero: primera persona y tercera persona "sobre el hombro" con
-- la tecla V (Y en mando).
--
-- En las dos vistas el mouse queda fijo en el centro de la pantalla, donde está la mira (menos
-- con un menú abierto, ver Menus). En tercera persona el personaje gira para mirar hacia donde
-- mira la cámara.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Menus = require(script.Parent.Menus)

local player = Players.LocalPlayer

local THIRD_PERSON_DISTANCE = 10 -- studs de la cámara al personaje
local SHOULDER_OFFSET = Vector3.new(2, 0.5, 0) -- la cámara un poco a la derecha y arriba

local Camera = {}

local firstPerson = true
local recoil = 0 -- grados que la mira debe estar levantada por el retroceso; baja sola
local recoilApplied = 0 -- grados que ya se le sumaron a la cámara

-- Retroceso: levanta la mira unos grados (Weapon lo llama al disparar)
function Camera.Kick(degrees: number)
	recoil += degrees
end

function Camera.IsFirstPerson(): boolean
	return firstPerson
end

local function getHumanoid(): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function apply()
	local humanoid = getHumanoid()
	if firstPerson then
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		player.CameraMinZoomDistance = 0.5
		player.CameraMaxZoomDistance = 0.5
		if humanoid then
			humanoid.CameraOffset = Vector3.zero
			humanoid.AutoRotate = true
		end
	else
		player.CameraMode = Enum.CameraMode.Classic
		-- Mínimo y máximo iguales: la distancia queda fija (la rueda del mouse no la cambia).
		-- Primero el máximo, para que el mínimo nunca quede por encima de él
		player.CameraMaxZoomDistance = THIRD_PERSON_DISTANCE
		player.CameraMinZoomDistance = THIRD_PERSON_DISTANCE
		if humanoid then
			humanoid.CameraOffset = SHOULDER_OFFSET
		end
	end
end

local function onToggle(_name: string, state: Enum.UserInputState)
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	firstPerson = not firstPerson
	apply()
	return Enum.ContextActionResult.Sink
end

function Camera.Start()
	ContextActionService:BindAction("ToggleCamera", onToggle, false, Enum.KeyCode.V, Enum.KeyCode.ButtonY)

	-- Al reaparecer, el personaje es nuevo: se vuelve a aplicar la vista elegida
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid")
		apply()
	end)
	apply()

	-- Después de la cámara de Roblox, en cada fotograma
	RunService:BindToRenderStep("TycoonCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
		-- Retroceso: la cámara de Roblox sigue desde donde quedó, así que solo se le suma la
		-- diferencia de cada fotograma. Primero sube de golpe y luego baja poco a poco.
		recoil = if recoil > 0.01 then recoil * math.exp(-8 * dt) else 0
		local delta = recoil - recoilApplied
		if math.abs(delta) > 0.0001 then
			local camera = workspace.CurrentCamera
			camera.CFrame *= CFrame.Angles(math.rad(delta), 0, 0)
			recoilApplied = recoil
		end
		if firstPerson then
			return -- en primera persona Roblox ya fija el mouse y gira al personaje
		end
		-- Mouse fijo en el centro (en celular no hay mouse y no hace falta), menos con un menú
		-- abierto
		if UserInputService.MouseEnabled then
			UserInputService.MouseBehavior = if Menus.AnyOpen()
				then Enum.MouseBehavior.Default
				else Enum.MouseBehavior.LockCenter
		end
		local humanoid = getHumanoid()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not humanoid or not root or humanoid.Health <= 0 then
			return
		end
		if humanoid.SeatPart then
			humanoid.AutoRotate = true
			return
		end
		-- El personaje mira hacia donde mira la cámara
		humanoid.AutoRotate = false
		local look = workspace.CurrentCamera.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude > 0.01 then
			root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
		end
	end)
end

return Camera
