-- Los botones de la pantalla en celular y tablet, alrededor del botón de saltar de Roblox
-- (como en Escuadrón Cero):
--
--              Cámara
--     Correr          Recargar
--          Apuntar
--            DISPARAR   (Saltar)
--
-- Disparar hace lo mismo que el clic izquierdo: dispara el arma que traes, a la mira del centro
-- de la pantalla (mientras lo mantienes, sigue disparando). Así puedes mirar arrastrando el
-- dedo sin disparar. Apuntar solo sale con armas con zoom (francotirador). Correr se toca una
-- vez para correr y otra para parar. Llaman a las mismas funciones que las teclas (Actions).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Actions = require(script.Parent.Parent.Actions)
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

-- Dónde va cada botón: el centro, medido desde el centro del botón de saltar, y su tamaño
local LAYOUT = {
	Fire = { x = -105, y = -15, size = 84 },
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
local function onTouch(button: TextButton, onPress: (InputObject) -> (), onRelease: ((InputObject) -> ())?)
	button.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		button.BackgroundTransparency = 0.1 -- se ve apretado
		onPress(input)
		local connection
		connection = input:GetPropertyChangedSignal("UserInputState"):Connect(function()
			local state = input.UserInputState
			if state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
				connection:Disconnect()
				button.BackgroundTransparency = 0.35
				if onRelease then
					onRelease(input)
				end
			end
		end)
	end)
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

	local fire = makeButton(cluster, "Fire", "Disparar", FIRE)
	local firing = false
	onTouch(fire, function()
		firing = true
		Weapon.SetTrigger(true)
	end, function()
		firing = false
		Weapon.SetTrigger(false)
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
				firing = false
			end
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
