-- Colocar defensas premium (Config/Premium): si tienes alguna sin poner, sale el botón
-- COLOCAR abajo a la izquierda. Al tocarlo aparece una vista previa que sigue a tu mouse (en
-- celular, toca el piso donde la quieres): verde = se puede, rojo = no (Placement.Check).
-- R o "Girar" la gira, clic o "Colocar" la pone. El servidor revisa todo otra vez
-- (TycoonService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Premium = require(ReplicatedStorage.Shared.Config.Premium)
local Placement = require(ReplicatedStorage.Shared.Placement)

local placeRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Place") :: RemoteEvent
local player = Players.LocalPlayer
local mouse = player:GetMouse()

local OK_COLOR = Color3.fromRGB(80, 220, 100)
local BAD_COLOR = Color3.fromRGB(230, 70, 60)

local PlacementUI = {}

local openButton: TextButton
local bar: Frame
local nameLabel: TextLabel
local ghost: Model? = nil
local current: any = nil -- la defensa que estás colocando (de Premium.list)
local rotation = 0
local spot: Vector2? = nil -- dónde quedaría, dentro del terreno
local valid = false

local function countOf(item): number
	return player:GetAttribute("Premium_" .. item.key) or 0
end

local function totalCount(): number
	local total = 0
	for _, item in Premium.list do
		total += countOf(item)
	end
	return total
end

local function button(parent: Instance, text: string, color: Color3, x: number): TextButton
	local b = Instance.new("TextButton")
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.Position = UDim2.new(x, 0, 0.5, 0)
	b.Size = UDim2.new(0.22, 0, 0, 40)
	b.BackgroundColor3 = color
	b.Font = Enum.Font.GothamBlack
	b.Text = text
	b.TextScaled = true
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = b
	return b
end

-- La vista previa: un disco del tamaño que ocupa y una flecha hacia su frente
local function makeGhost(item): Model
	local model = Instance.new("Model")
	model.Name = "VistaPrevia"
	local disc = Instance.new("Part")
	disc.Name = "Disco"
	disc.Shape = Enum.PartType.Cylinder
	disc.Size = Vector3.new(0.4, item.radius * 2, item.radius * 2)
	disc.Material = Enum.Material.Neon
	disc.Transparency = 0.5
	disc.Anchored = true
	disc.CanCollide = false
	disc.CanQuery = false
	disc.Parent = model
	local arrow = Instance.new("Part")
	arrow.Name = "Flecha"
	arrow.Size = Vector3.new(0.8, 0.5, item.radius)
	arrow.Material = Enum.Material.Neon
	arrow.Color = Color3.new(1, 1, 1)
	arrow.Anchored = true
	arrow.CanCollide = false
	arrow.CanQuery = false
	arrow.Parent = model
	model.Parent = workspace
	return model
end

local function stop()
	if ghost then
		ghost:Destroy()
		ghost = nil
	end
	current = nil
	spot = nil
	bar.Visible = false
	openButton.Visible = totalCount() > 0
end

local function start(item)
	stop()
	current = item
	rotation = 0
	ghost = makeGhost(item)
	nameLabel.Text = string.format("%s (%d)", item.name, countOf(item))
	bar.Visible = true
	openButton.Visible = false
	-- Guarda el arma, para que el clic no dispare
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:UnequipTools()
	end
end

-- La siguiente defensa que tienes sin colocar (para "Cambiar")
local function nextItem(after): any
	local startIndex = if after then table.find(Premium.list, after) or 0 else 0
	for step = 1, #Premium.list do
		local item = Premium.list[(startIndex + step - 1) % #Premium.list + 1]
		if countOf(item) > 0 then
			return item
		end
	end
	return nil
end

local function confirm()
	if current and spot and valid then
		placeRemote:FireServer(current.key, spot.X, spot.Y, rotation)
		stop()
	end
end

-- Cada fotograma: mover la vista previa a donde apunta el mouse (o donde tocaste)
local function update()
	local center = player:GetAttribute("PlotCenter")
	if not ghost or not current or typeof(center) ~= "CFrame" then
		return
	end
	mouse.TargetFilter = ghost
	local here = center:PointToObjectSpace(mouse.Hit.Position)
	spot = Vector2.new(math.floor(here.X + 0.5), math.floor(here.Z + 0.5))
	valid = Placement.Check(spot.X, spot.Y, current.radius)
	local place = center * CFrame.new(spot.X, 0.3, spot.Y) * CFrame.Angles(0, math.rad(rotation), 0)
	local disc = ghost:FindFirstChild("Disco") :: BasePart
	local arrow = ghost:FindFirstChild("Flecha") :: BasePart
	disc.CFrame = place * CFrame.Angles(0, 0, math.pi / 2)
	disc.Color = if valid then OK_COLOR else BAD_COLOR
	arrow.CFrame = place * CFrame.new(0, 0.3, -current.radius / 2)
end

function PlacementUI.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Placement"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Junto al botón de la tienda
	openButton = Instance.new("TextButton")
	openButton.AnchorPoint = Vector2.new(0, 1)
	openButton.Position = UDim2.new(0, 142, 1, -12)
	openButton.Size = UDim2.fromOffset(150, 44)
	openButton.BackgroundColor3 = OK_COLOR
	openButton.Font = Enum.Font.GothamBlack
	openButton.TextSize = 18
	openButton.TextColor3 = Color3.fromRGB(20, 30, 20)
	openButton.Visible = false
	openButton.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = openButton

	bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -70)
	bar.Size = UDim2.new(0.9, 0, 0, 90)
	bar.BackgroundColor3 = Color3.fromRGB(24, 26, 22)
	bar.BackgroundTransparency = 0.2
	bar.Visible = false
	bar.Parent = gui
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(560, 90)
	limit.Parent = bar
	nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0, 30)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 16
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.Parent = bar
	local row = Instance.new("Frame")
	row.Position = UDim2.fromOffset(0, 30)
	row.Size = UDim2.new(1, 0, 0, 56)
	row.BackgroundTransparency = 1
	row.Parent = bar
	local change = button(row, "Cambiar", Color3.fromRGB(80, 90, 110), 0.13)
	local turn = button(row, "Girar", Color3.fromRGB(80, 90, 110), 0.38)
	local put = button(row, "Colocar", Color3.fromRGB(60, 160, 70), 0.63)
	local cancel = button(row, "Cancelar", Color3.fromRGB(150, 50, 50), 0.88)

	local function refresh()
		local total = totalCount()
		openButton.Text = string.format("COLOCAR (%d)", total)
		if current then
			if countOf(current) <= 0 then
				stop()
			else
				nameLabel.Text = string.format("%s (%d)", current.name, countOf(current))
			end
		else
			openButton.Visible = total > 0
		end
	end
	for _, item in Premium.list do
		player:GetAttributeChangedSignal("Premium_" .. item.key):Connect(refresh)
	end
	refresh()

	openButton.Activated:Connect(function()
		local item = nextItem(nil)
		if item then
			start(item)
		end
	end)
	change.Activated:Connect(function()
		local item = nextItem(current)
		if item and item ~= current then
			start(item)
		end
	end)
	turn.Activated:Connect(function()
		rotation = (rotation + 90) % 360
	end)
	put.Activated:Connect(confirm)
	cancel.Activated:Connect(stop)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not current then
			return
		end
		if input.KeyCode == Enum.KeyCode.R then
			rotation = (rotation + 90) % 360
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			confirm() -- con mouse, el clic la pone; en celular se usa el botón "Colocar"
		end
	end)
	RunService.RenderStepped:Connect(update)
end

return PlacementUI
