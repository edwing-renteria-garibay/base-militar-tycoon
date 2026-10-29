-- Poner barricadas de concreto donde quieras (Config/Barricades), como el muro: el botón
-- BARRICADAS (o la tecla H) activa el modo. Haz clic donde empieza la hilera y otra vez donde
-- termina: se pone una hilera de 1 a 3 pedazos. La siguiente empieza donde terminó la anterior,
-- así vas dibujando la forma que quieras (cuadrado, triángulo...). Si la punta queda cerca de
-- otra barricada, se une a ella. Verde = se puede, rojo = no. El servidor revisa todo otra vez
-- y cobra (TycoonService).

local ContextActionService = game:GetService("ContextActionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Barricades = require(ReplicatedStorage.Shared.Config.Barricades)
local Premium = require(ReplicatedStorage.Shared.Config.Premium)
local Format = require(ReplicatedStorage.Shared.Format)
local Placement = require(ReplicatedStorage.Shared.Placement)
local Menus = require(script.Parent.Parent.Menus)

local barricadeRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Barricade") :: RemoteEvent
local player = Players.LocalPlayer
local mouse = player:GetMouse()

local OK_COLOR = Color3.fromRGB(80, 220, 100)
local BAD_COLOR = Color3.fromRGB(230, 70, 60)

local BarricadesUI = {}

local active = false
local start: Vector2? = nil -- donde empieza la hilera (dentro del terreno)
local rowEnd: Vector2? = nil -- donde terminaría
local valid = false
local ghost: Folder
local marker: Part
local pieces: { Part } = {}
local bar: Frame
local infoLabel: TextLabel

-- Las hileras que ya tienes (las publica el servidor)
local function decode(attribute: string): { any }
	local ok, list = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute(attribute) or "[]")
	return if ok and type(list) == "table" then list else {}
end

local function radiusOf(key: string): number
	local item = Premium.byKey[key]
	return if item then item.radius else 5
end

local function ghostPart(size: Vector3): Part
	local p = Instance.new("Part")
	p.Size = size
	p.Material = Enum.Material.Neon
	p.Transparency = 0.5
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = ghost
	return p
end

local function hideGhost()
	marker.Transparency = 1
	for _, piece in pieces do
		piece.Transparency = 1
	end
end

local function stop()
	active = false
	start, rowEnd = nil, nil
	bar.Visible = false
	hideGhost()
end

local function begin()
	active = true
	start = nil
	bar.Visible = true
	-- Guarda el arma, para que el clic no dispare
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:UnequipTools()
	end
end

local function confirm()
	if not active then
		return
	end
	local center = player:GetAttribute("PlotCenter")
	if typeof(center) ~= "CFrame" then
		return
	end
	local here = center:PointToObjectSpace(mouse.Hit.Position)
	local point = Vector2.new(here.X, here.Z)
	if not start then
		-- Primer clic: donde empieza (pegado a la punta de otra barricada si está cerca)
		local a = Placement.Row(point, point, Placement.RowPoints(decode("Barricades")))
		start = a
		return
	end
	if rowEnd and valid then
		local from = start :: Vector2
		barricadeRemote:FireServer(from.X, from.Y, rowEnd.X, rowEnd.Y)
		start = rowEnd -- la siguiente sigue desde aquí
	end
end

-- Cada fotograma: dibuja la hilera que pondrías, de start hasta donde apunta el mouse
local function update()
	local center = player:GetAttribute("PlotCenter")
	if not active or typeof(center) ~= "CFrame" then
		return
	end
	local here = center:PointToObjectSpace(mouse.Hit.Position)
	local point = Vector2.new(here.X, here.Z)
	local points = Placement.RowPoints(decode("Barricades"))
	local a, b, count = Placement.Row(start or point, point, points)
	if not start then
		count = 0
	end
	-- La marca de donde empieza (o empezaría)
	marker.Transparency = 0.3
	marker.Color = OK_COLOR
	marker.CFrame = center * CFrame.new(a.X, 2.5, a.Y)
	rowEnd = if count > 0 then b else nil
	valid = count > 0 and Placement.CheckRow(a, b, decode("PremiumPlaced"), radiusOf)
	for i, piece in pieces do
		if i > count then
			piece.Transparency = 1
		else
			local from, to = a:Lerp(b, (i - 1) / count), a:Lerp(b, i / count)
			local length = (to - from).Magnitude
			piece.Size = Vector3.new(1.8, 4.5, math.max(length - 0.3, 0.1))
			piece.CFrame = center
				* CFrame.lookAt(Vector3.new(from.X, 2.3, from.Y), Vector3.new(to.X, 2.3, to.Y))
				* CFrame.new(0, 0, -length / 2)
			piece.Color = if valid then OK_COLOR else BAD_COLOR
			piece.Transparency = 0.5
		end
	end
	if not start then
		infoLabel.Text = "Clic donde empieza la hilera"
	elseif count == 0 then
		infoLabel.Text = "Clic donde termina (hasta 3 pedazos)"
	else
		infoLabel.Text = string.format(
			"%d pedazo%s: %s · clic para ponerla",
			count,
			if count == 1 then "" else "s",
			Format.Money(count * Barricades.price)
		)
	end
end

local function button(parent: Instance, text: string, color: Color3, x: number): TextButton
	local b = Instance.new("TextButton")
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.Position = UDim2.new(x, 0, 0.5, 0)
	b.Size = UDim2.new(0.3, 0, 0, 40)
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

function BarricadesUI.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Barricadas"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	ghost = Instance.new("Folder")
	ghost.Name = "VistaPreviaBarricadas"
	ghost.Parent = workspace
	marker = ghostPart(Vector3.new(2.6, 5, 2.6))
	for _ = 1, Barricades.maxPerRow do
		table.insert(pieces, ghostPart(Vector3.one))
	end
	hideGhost()

	-- Junto al botón de colocar
	local open = Instance.new("TextButton")
	open.AnchorPoint = Vector2.new(0, 1)
	open.Position = UDim2.new(0, 352, 1, -12)
	open.Size = UDim2.fromOffset(190, 44)
	open.BackgroundColor3 = Color3.fromRGB(150, 150, 145)
	open.Font = Enum.Font.GothamBlack
	open.Text = "BARRICADAS · H"
	open.TextSize = 18
	open.TextColor3 = Color3.fromRGB(25, 25, 25)
	open.Parent = gui
	local openCorner = Instance.new("UICorner")
	openCorner.CornerRadius = UDim.new(0, 10)
	openCorner.Parent = open

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
	infoLabel = Instance.new("TextLabel")
	infoLabel.Size = UDim2.new(1, 0, 0, 30)
	infoLabel.BackgroundTransparency = 1
	infoLabel.Font = Enum.Font.GothamBold
	infoLabel.TextSize = 16
	infoLabel.TextColor3 = Color3.new(1, 1, 1)
	infoLabel.Parent = bar
	local row = Instance.new("Frame")
	row.Position = UDim2.fromOffset(0, 30)
	row.Size = UDim2.new(1, 0, 0, 56)
	row.BackgroundTransparency = 1
	row.Parent = bar
	local put = button(row, "Poner", Color3.fromRGB(60, 160, 70), 0.18)
	local cut = button(row, "Nueva hilera", Color3.fromRGB(80, 90, 110), 0.5)
	local done = button(row, "Terminar", Color3.fromRGB(150, 50, 50), 0.82)
	Menus.Register(done) -- mientras pones barricadas, el mouse queda libre

	local function toggle()
		if active then
			stop()
		else
			begin()
		end
	end
	open.Activated:Connect(toggle)
	ContextActionService:BindAction("Barricades", function(_, state)
		if state == Enum.UserInputState.Begin then
			toggle()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.H)
	-- En celular: toca el piso para marcar y "Poner" para ponerla
	put.Activated:Connect(confirm)
	cut.Activated:Connect(function()
		start = nil -- la siguiente empieza en otro lado
	end)
	done.Activated:Connect(stop)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not active then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			confirm()
		elseif input.UserInputType == Enum.UserInputType.Touch and not start then
			confirm()
		end
	end)
	RunService.RenderStepped:Connect(update)
end

return BarricadesUI
