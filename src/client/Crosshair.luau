-- La mira en el centro de la pantalla, igual que en Escuadrón Cero: cuatro rayitas y un punto.
-- Se pone roja un instante (y suena un aviso) cuando el servidor confirma que le diste a un
-- zombi. También la mira del francotirador: clic derecho (o L2 en mando) para hacer zoom.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local Camera = require(script.Parent.Camera)
local Menus = require(script.Parent.Menus)
local Sfx = require(script.Parent.Sfx)
local ViewModel = require(script.Parent.ViewModel)

local hitRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Hit") :: RemoteEvent

local player = Players.LocalPlayer

local NORMAL_COLOR = Color3.new(1, 1, 1)
local HIT_COLOR = Color3.fromRGB(255, 60, 60)
local HIT_TIME = 0.25 -- segundos que dura el rojo al acertar
local NORMAL_FOV = 70

local Crosshair = {}

local scoped = false
local selfHidden = false -- con zoom en tercera persona tu personaje se esconde (solo para ti)
local scopeFrame: Frame

-- El arma en la mano y sus datos, si está vivo
local function equipped(): (Tool?, any)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local tool = character and character:FindFirstChildOfClass("Tool")
	if not humanoid or humanoid.Health <= 0 or not tool then
		return nil, nil
	end
	return tool, Weapons.byId[tool.Name]
end

local function setScoped(value: boolean)
	scoped = value
	scopeFrame.Visible = value
	ViewModel.SetScoped(value)
	if not value then
		UserInputService.MouseDeltaSensitivity = 1
	end
end

local function onScope(_name: string, state: Enum.UserInputState)
	local tool, weapon = equipped()
	if not tool or not weapon or not weapon.zoom or Menus.AnyOpen() then
		return Enum.ContextActionResult.Pass
	end
	if state == Enum.UserInputState.Begin then
		setScoped(not scoped)
	end
	return Enum.ContextActionResult.Sink
end

-- Un rectángulo pequeño, centrado en (x, y) respecto al centro de la mira
local function makeBar(parent: Instance, x: number, y: number, width: number, height: number): Frame
	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(0.5, 0.5)
	bar.Position = UDim2.fromOffset(x, y)
	bar.Size = UDim2.fromOffset(width, height)
	bar.BorderSizePixel = 0
	bar.BackgroundColor3 = NORMAL_COLOR
	bar.Parent = parent
	return bar
end

-- Con zoom en tercera persona tu cuerpo taparía la mira: se esconde solo en tu pantalla
local function hideSelf(hide: boolean)
	if not hide and not selfHidden then
		return
	end
	selfHidden = hide
	local character = player.Character
	if not character then
		return
	end
	-- (en primera persona el arma de la mano la esconde ViewModel: esa no se toca)
	local tool = if Camera.IsFirstPerson() then character:FindFirstChildOfClass("Tool") else nil
	for _, part in character:GetDescendants() do
		if (part:IsA("BasePart") or part:IsA("Decal")) and not (tool and part:IsDescendantOf(tool)) then
			part.LocalTransparencyModifier = if hide then 1 else 0
		end
	end
end

function Crosshair.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Crosshair"
	gui.IgnoreGuiInset = true -- así las coordenadas coinciden con las del mouse
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	gui.Parent = player:WaitForChild("PlayerGui")

	local cross = Instance.new("Frame")
	cross.BackgroundTransparency = 1
	cross.Size = UDim2.fromOffset(0, 0)
	cross.Parent = gui
	local bars = {
		makeBar(cross, 0, -10, 2, 8),
		makeBar(cross, 0, 10, 2, 8),
		makeBar(cross, -10, 0, 8, 2),
		makeBar(cross, 10, 0, 8, 2),
		makeBar(cross, 0, 0, 2, 2),
	}

	-- La mira del francotirador: un círculo transparente rodeado de negro y una cruz
	scopeFrame = Instance.new("Frame")
	scopeFrame.Name = "Scope"
	scopeFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	scopeFrame.Size = UDim2.fromScale(0.9, 0.9)
	scopeFrame.BackgroundTransparency = 1
	scopeFrame.Visible = false
	scopeFrame.Parent = gui
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.Parent = scopeFrame
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = scopeFrame
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2000
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Parent = scopeFrame
	for _, size in { UDim2.new(1, 0, 0, 2), UDim2.new(0, 2, 1, 0) } do
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.Position = UDim2.fromScale(0.5, 0.5)
		line.Size = size
		line.BackgroundColor3 = Color3.new(0, 0, 0)
		line.BorderSizePixel = 0
		line.Parent = scopeFrame
	end

	ContextActionService:BindAction("Scope", onScope, false, Enum.UserInputType.MouseButton2, Enum.KeyCode.ButtonL2)

	local lastHit = -math.huge
	hitRemote.OnClientEvent:Connect(function()
		lastHit = os.clock()
		Sfx.PlayLocal(Sounds.hit)
	end)

	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		local tool, weapon = equipped()
		local menuOpen = Menus.AnyOpen()
		cross.Visible = tool ~= nil and weapon ~= nil and not menuOpen and not scoped
		-- Con la mira visible se esconde la flecha del mouse (menos con un menú abierto)
		UserInputService.MouseIconEnabled = menuOpen or not (cross.Visible or scoped)

		-- El mouse está fijo en el centro del área de juego (un poco más abajo que el centro de
		-- la pantalla, por la barra de arriba): la mira va justo ahí, donde apunta el disparo
		local point = if UserInputService.MouseEnabled
			then UserInputService:GetMouseLocation()
			else camera.ViewportSize / 2
		cross.Position = UDim2.fromOffset(point.X, point.Y)
		local color = if os.clock() - lastHit < HIT_TIME then HIT_COLOR else NORMAL_COLOR
		for _, bar in bars do
			bar.BackgroundColor3 = color
		end

		-- Zoom: se quita solo si cambias de arma, abres un menú o mueres
		if scoped and (not weapon or not weapon.zoom or menuOpen) then
			setScoped(false)
		end
		local fov = if scoped then weapon.zoom else NORMAL_FOV
		camera.FieldOfView += (fov - camera.FieldOfView) * 0.35
		if scoped then
			-- Con zoom el mouse gira más despacio, para poder apuntar fino
			UserInputService.MouseDeltaSensitivity = camera.FieldOfView / NORMAL_FOV
			scopeFrame.Position = UDim2.fromOffset(point.X, point.Y)
		end
		hideSelf(scoped and not Camera.IsFirstPerson())
	end)
end

return Crosshair
