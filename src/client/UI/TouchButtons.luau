-- Los botones de la pantalla en celular y tablet, alrededor del botón de saltar de Roblox
-- (como en Escuadrón Cero):
--
--              Cámara
--     Correr          Recargar
--          Apuntar
--            DISPARAR   (Saltar)
--
-- Disparar es un stick, como en Escuadrón Cero (y como en los juegos de disparos de celular):
-- al tocarlo dispara a la mira del centro y, mientras mueves el dedo, la mira se mueve lo mismo
-- (más lento sobre un zombi, para no pasarte). Al soltarlo la bolita regresa al centro. Con la
-- escopeta y el francotirador el tiro sale al soltar, así acomodas la mira sin gastar la bala. Apuntar solo sale con armas con zoom (francotirador). Correr se toca una
-- vez para correr y otra para parar. Llaman a las mismas funciones que las teclas (Actions).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Actions = require(script.Parent.Parent.Actions)
local Camera = require(script.Parent.Parent.Camera)
local Crosshair = require(script.Parent.Parent.Crosshair)
local Layout = require(script.Parent.Parent.Layout)
local Menus = require(script.Parent.Parent.Menus)
local Sprint = require(script.Parent.Parent.Sprint)
local Weapon = require(script.Parent.Parent.Weapon)

local player = Players.LocalPlayer

local BUTTON = Color3.fromRGB(20, 20, 20)
local FIRE = Color3.fromRGB(170, 40, 40)
local ACTIVE = Color3.fromRGB(230, 170, 50) -- Correr prendido / zoom puesto
local TEXT = Color3.new(1, 1, 1)
local STICK_BASE = Color3.fromRGB(40, 40, 40) -- como el fondo del stick de caminar

-- Stick de Disparar: grados que gira la mira por cada punto que mueves el dedo
local LOOK_SPEED = 0.3
local VERTICAL = 0.6 -- arriba y abajo giran más lento: el pulgar se va hacia arriba sin querer
local AIM_FRICTION = 0.45 -- con la mira sobre un zombi gira más lento
local KNOB_SIZE = 38
local SINGLE_SHOT = 0.5 -- armas que tardan esto o más entre tiros disparan al soltar

-- Dónde va cada botón: el centro, medido desde el centro del botón de saltar, y su tamaño
local LAYOUT = {
	Fire = { x = -100, y = -15, size = 72 },
	Reload = { x = -15, y = -90, size = 56 },
	Aim = { x = -95, y = -100, size = 56 },
	Sprint = { x = -165, y = -140, size = 52 },
	Camera = { x = -15, y = -165, size = 46 },
}

local TouchButtons = {}

local function makeButton(parent: Instance, key: string, text: string, color: Color3): TextButton
	local spot = LAYOUT[key]
	local button = Instance.new("TextButton")
	button.Name = key
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = UDim2.fromOffset(spot.x, spot.y)
	button.Size = UDim2.fromOffset(spot.size, spot.size)
	button.BackgroundColor3 = color
	button.BackgroundTransparency = 0.35
	button.AutoButtonColor = false
	button.Font = Enum.Font.GothamBold
	button.Text = text
	button.TextColor3 = TEXT
	button.TextScaled = true
	button.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = TEXT
	stroke.Thickness = 2
	stroke.Transparency = 0.4
	stroke.Parent = button
	local padding = Instance.new("UIPadding")
	for _, side in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
		(padding :: any)[side] = UDim.new(0, 7)
	end
	padding.Parent = button
	local textSize = Instance.new("UITextSizeConstraint")
	textSize.MaxTextSize = if key == "Fire" then 16 else 13
	textSize.Parent = button
	return button
end

-- Llama a onPress cuando el dedo toca el botón y a onRelease cuando lo suelta (aunque lo
-- suelte fuera del botón)
-- onMove, si se da, recibe dónde está el dedo en la pantalla mientras se mueve
local function onTouch(
	button: GuiButton,
	onPress: (InputObject) -> (),
	onRelease: ((InputObject) -> ())?,
	onMove: ((Vector2) -> ())?
)
	button.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local normal = button.BackgroundTransparency
		button.BackgroundTransparency = normal - 0.25 -- se ve apretado
		onPress(input)
		local moved
		if onMove then
			onMove(Vector2.new(input.Position.X, input.Position.Y))
			moved = input:GetPropertyChangedSignal("Position"):Connect(function()
				onMove(Vector2.new(input.Position.X, input.Position.Y))
			end)
		end
		local connection
		connection = input:GetPropertyChangedSignal("UserInputState"):Connect(function()
			local state = input.UserInputState
			if state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
				connection:Disconnect()
				if moved then
					moved:Disconnect()
				end
				button.BackgroundTransparency = normal
				if onRelease then
					onRelease(input)
				end
			end
		end)
	end)
end

-- ¿Hay un zombi justo en la mira (el centro de la pantalla)?
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local function enemyInSight(): boolean
	local camera = workspace.CurrentCamera
	rayParams.FilterDescendantsInstances = { camera, player.Character :: Instance }
	local result = workspace:Raycast(camera.CFrame.Position, camera.CFrame.LookVector * 400, rayParams)
	local model = result and result.Instance:FindFirstAncestorOfClass("Model")
	while model do
		if CollectionService:HasTag(model, "Enemy") then
			return true
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return false
end

local function humanoid(): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

function TouchButtons.Start()
	if not Layout.touch then
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "TouchButtons"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 3
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Todos los botones cuelgan de un punto en el centro del botón de saltar. Roblox lo pone
	-- en un lugar distinto (y más grande) en pantallas grandes, como las tablets
	local cluster = Instance.new("Frame")
	cluster.BackgroundTransparency = 1
	cluster.Size = UDim2.fromOffset(0, 0)
	cluster.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = cluster
	local function place()
		local size = gui.AbsoluteSize
		local small = math.min(size.X, size.Y) <= 500
		cluster.Position = if small then UDim2.new(1, -60, 1, -55) else UDim2.new(1, -110, 1, -150)
		scale.Scale = if small then 1 else 1.3
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
	place()

	-- El stick: el círculo de fondo (fire) y la bolita que sigue al dedo (knob)
	local fire = makeButton(cluster, "Fire", "", STICK_BASE)
	fire.BackgroundTransparency = 0.5
	local knob = Instance.new("TextLabel")
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.fromScale(0.5, 0.5)
	knob.Size = UDim2.fromOffset(KNOB_SIZE, KNOB_SIZE)
	knob.BackgroundColor3 = FIRE
	knob.BackgroundTransparency = 0.25
	knob.Font = Enum.Font.GothamBold
	knob.Text = "Disparar"
	knob.TextColor3 = TEXT
	knob.TextScaled = true
	knob.Parent = fire
	local knobCorner = Instance.new("UICorner")
	knobCorner.CornerRadius = UDim.new(0.5, 0)
	knobCorner.Parent = knob
	local knobPadding = Instance.new("UIPadding")
	knobPadding.PaddingLeft = UDim.new(0, 4)
	knobPadding.PaddingRight = UDim.new(0, 4)
	knobPadding.Parent = knob
	local knobText = Instance.new("UITextSizeConstraint")
	knobText.MaxTextSize = 11
	knobText.Parent = knob
	-- Donde pusiste el dedo (la bolita se mueve desde ahí) y dónde estaba en el último
	-- movimiento (la mira gira lo que se movió desde entonces)
	local origin: Vector2? = nil
	local last: Vector2? = nil
	local firing: string? = nil
	local function resetKnob()
		origin = nil
		last = nil
		knob.Position = UDim2.fromScale(0.5, 0.5)
	end
	onTouch(fire, function()
		local weapon = Weapon.Equipped()
		if weapon and weapon.cooldown >= SINGLE_SHOT then
			firing = "release" -- tiro por tiro: sale al soltar
		else
			firing = "hold"
			Weapon.SetTrigger(true)
		end
	end, function(input)
		if firing == "hold" then
			Weapon.SetTrigger(false)
		elseif firing == "release" and input.UserInputState == Enum.UserInputState.End then
			Weapon.SetTrigger(true) -- un solo tiro
			Weapon.SetTrigger(false)
		end
		firing = nil
		resetKnob()
	end, function(position)
		-- La mira gira lo que se movió el dedo (más lento con zoom o sobre un zombi)
		if last then
			local delta = position - last
			local speed = LOOK_SPEED * workspace.CurrentCamera.FieldOfView / 70
			if enemyInSight() then
				speed *= AIM_FRICTION
			end
			Camera.Look(delta.X * speed, -delta.Y * speed * VERTICAL)
		end
		last = position
		-- La bolita sigue al dedo sin salirse del círculo
		local radius = fire.AbsoluteSize.X / 2
		origin = origin or position
		local offset = position - (origin :: Vector2)
		if offset.Magnitude > radius then
			offset = offset.Unit * radius
		end
		local knobOffset = offset / scale.Scale -- (AbsoluteSize ya trae el UIScale)
		knob.Position = UDim2.new(0.5, knobOffset.X, 0.5, knobOffset.Y)
	end)

	local reload = makeButton(cluster, "Reload", "Recargar", BUTTON)
	onTouch(reload, function(input)
		Actions.Call("Recargar", Enum.UserInputState.Begin, input)
	end)

	local aim = makeButton(cluster, "Aim", "Apuntar", BUTTON)
	onTouch(aim, function(input)
		Actions.Call("Scope", Enum.UserInputState.Begin, input)
	end)

	local sprint = makeButton(cluster, "Sprint", "Correr", BUTTON)
	onTouch(sprint, function(input)
		Actions.Call("Sprint", Enum.UserInputState.Begin, input)
	end)

	local camera = makeButton(cluster, "Camera", "Cámara", BUTTON)
	onTouch(camera, function(input)
		Actions.Call("ToggleCamera", Enum.UserInputState.Begin, input)
	end)

	RunService.RenderStepped:Connect(function()
		-- Con un menú abierto o muerto, los botones se esconden
		local h = humanoid()
		cluster.Visible = not Menus.AnyOpen() and h ~= nil and h.Health > 0
		if not cluster.Visible then
			if firing then
				Weapon.SetTrigger(false) -- se abrió un menú con el dedo en el gatillo: se suelta
				firing = nil
			end
			resetKnob()
			return
		end
		local weapon = Weapon.Equipped()
		fire.Visible = weapon ~= nil
		reload.Visible = weapon ~= nil
		aim.Visible = weapon ~= nil and weapon.zoom ~= nil
		aim.TextColor3 = if Crosshair.IsScoped() then ACTIVE else TEXT
		sprint.TextColor3 = if Sprint.IsToggled() then ACTIVE else TEXT
	end)
end

return TouchButtons
