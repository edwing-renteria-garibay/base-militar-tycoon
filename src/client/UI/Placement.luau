-- Colocar defensas premium (Config/Premium): el botón COLOCAR, abajo a la izquierda, abre un
-- menú con cada defensa, cuántas tienes sin poner y para comprar más con Robux. Al elegir una
-- aparece una vista previa que sigue a tu mouse (en
-- celular, toca el piso donde la quieres): verde = se puede, rojo = no (Placement.Check).
-- R o "Girar" la gira, clic o "Colocar" la pone. El servidor revisa todo otra vez
-- (TycoonService).

local ContextActionService = game:GetService("ContextActionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local MarketplaceService = game:GetService("MarketplaceService")

local Premium = require(ReplicatedStorage.Shared.Config.Premium)
local Store = require(ReplicatedStorage.Shared.Config.Store)
local Placement = require(ReplicatedStorage.Shared.Placement)
local Menus = require(script.Parent.Parent.Menus)

local placeRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Place") :: RemoteEvent
local player = Players.LocalPlayer
local mouse = player:GetMouse()

local OK_COLOR = Color3.fromRGB(80, 220, 100)
local BAD_COLOR = Color3.fromRGB(230, 70, 60)

local PlacementUI = {}

local openButton: TextButton
local menu: Frame
local menuList: Frame
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
	openButton.Visible = true
end

local function start(item)
	stop()
	current = item
	rotation = 0
	ghost = makeGhost(item)
	nameLabel.Text = string.format("%s (%d)", item.name, countOf(item))
	bar.Visible = true
	menu.Visible = false
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

-- Las que ya están colocadas (las publica el servidor), para no encimarlas
local function placedList(): { any }
	local ok, list = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("PremiumPlaced") or "[]")
	return if ok and type(list) == "table" then list else {}
end

local function radiusOf(key: string): number
	local item = Premium.byKey[key]
	return if item then item.radius else 5
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
	valid = Placement.Check(spot.X, spot.Y, current.radius, placedList(), radiusOf)
	local place = center * CFrame.new(spot.X, 0.3, spot.Y) * CFrame.Angles(0, math.rad(rotation), 0)
	local disc = ghost:FindFirstChild("Disco") :: BasePart
	local arrow = ghost:FindFirstChild("Flecha") :: BasePart
	disc.CFrame = place * CFrame.Angles(0, 0, math.pi / 2)
	disc.Color = if valid then OK_COLOR else BAD_COLOR
	arrow.CFrame = place * CFrame.new(0, 0.3, -current.radius / 2)
end

-- El producto de Robux que da esta defensa (Config/Store), si ya tiene ID
local function productOf(item): any
	for _, product in Store.products do
		if product.kind == "defense" and product.key == item.key then
			return product
		end
	end
	return nil
end

-- El menú: una fila por defensa, con cuántas tienes, "Colocar" y "Comprar"
local function redrawMenu()
	for _, child in menuList:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for i, item in Premium.list do
		local count = countOf(item)
		local card = Instance.new("Frame")
		card.Size = UDim2.new(1, 0, 0, 70)
		card.BackgroundColor3 = Color3.fromRGB(42, 46, 38)
		card.LayoutOrder = i
		card.Parent = menuList
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = card
		local title = Instance.new("TextLabel")
		title.Position = UDim2.fromOffset(12, 6)
		title.Size = UDim2.new(0.55, -12, 0, 24)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBlack
		title.TextSize = 17
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextColor3 = Color3.fromRGB(230, 180, 50)
		title.Text = string.format("%s · tienes %d", item.name, count)
		title.Parent = card
		local info = Instance.new("TextLabel")
		info.Position = UDim2.fromOffset(12, 32)
		info.Size = UDim2.new(0.55, -12, 0, 32)
		info.BackgroundTransparency = 1
		info.Font = Enum.Font.GothamBold
		info.TextSize = 13
		info.TextWrapped = true
		info.TextXAlignment = Enum.TextXAlignment.Left
		info.TextColor3 = Color3.new(1, 1, 1)
		info.Text = item.description or ""
		info.Parent = card
		local put = button(
			card,
			if count > 0 then "Colocar" else "No tienes",
			if count > 0 then OK_COLOR else Color3.fromRGB(90, 90, 96),
			0.69
		)
		put.Size = UDim2.new(0.2, 0, 0, 40)
		if count > 0 then
			put.Activated:Connect(function()
				start(item)
			end)
		end
		local product = productOf(item)
		local ready = product and product.id ~= 0
		local label = if ready then product.robux .. " Robux" else "Próximamente"
		local buy = button(card, label, if ready then Color3.fromRGB(230, 180, 50) else Color3.fromRGB(90, 90, 96), 0.89)
		buy.Size = UDim2.new(0.18, 0, 0, 40)
		if ready then
			buy.Activated:Connect(function()
				MarketplaceService:PromptProductPurchase(player, product.id)
			end)
		end
	end
end

function PlacementUI.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Placement"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Junto al botón de la tienda
	openButton = Instance.new("TextButton")
	openButton.AnchorPoint = Vector2.new(0, 1)
	openButton.Position = UDim2.new(0, 152, 1, -12)
	openButton.Size = UDim2.fromOffset(190, 44)
	openButton.BackgroundColor3 = OK_COLOR
	openButton.Font = Enum.Font.GothamBlack
	openButton.TextSize = 18
	openButton.TextColor3 = Color3.fromRGB(20, 30, 20)
	openButton.Visible = false
	openButton.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = openButton

	menu = Instance.new("Frame")
	menu.AnchorPoint = Vector2.new(0.5, 0.5)
	menu.Position = UDim2.fromScale(0.5, 0.5)
	menu.Size = UDim2.fromScale(0.9, 0.7)
	menu.BackgroundColor3 = Color3.fromRGB(24, 26, 22)
	menu.Visible = false
	menu.Parent = gui
	local menuCorner = Instance.new("UICorner")
	menuCorner.CornerRadius = UDim.new(0, 12)
	menuCorner.Parent = menu
	local menuLimit = Instance.new("UISizeConstraint")
	menuLimit.MaxSize = Vector2.new(560, 300)
	menuLimit.Parent = menu
	local menuTitle = Instance.new("TextLabel")
	menuTitle.Position = UDim2.fromOffset(16, 6)
	menuTitle.Size = UDim2.new(1, -70, 0, 40)
	menuTitle.BackgroundTransparency = 1
	menuTitle.Font = Enum.Font.GothamBlack
	menuTitle.TextSize = 22
	menuTitle.TextXAlignment = Enum.TextXAlignment.Left
	menuTitle.TextColor3 = Color3.new(1, 1, 1)
	menuTitle.Text = "Defensas premium"
	menuTitle.Parent = menu
	local menuClose = Instance.new("TextButton")
	menuClose.AnchorPoint = Vector2.new(1, 0)
	menuClose.Position = UDim2.new(1, -10, 0, 10)
	menuClose.Size = UDim2.fromOffset(36, 36)
	menuClose.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
	menuClose.Font = Enum.Font.GothamBlack
	menuClose.Text = "X"
	menuClose.TextSize = 18
	menuClose.TextColor3 = Color3.new(1, 1, 1)
	menuClose.Parent = menu
	Menus.Register(menuClose) -- en primera persona suelta el mouse mientras se ve el menú
	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = menuClose
	menuClose.Activated:Connect(function()
		menu.Visible = false
	end)
	menuList = Instance.new("Frame")
	menuList.Position = UDim2.fromOffset(12, 54)
	menuList.Size = UDim2.new(1, -24, 1, -64)
	menuList.BackgroundTransparency = 1
	menuList.Parent = menu
	local menuLayout = Instance.new("UIListLayout")
	menuLayout.Padding = UDim.new(0, 8)
	menuLayout.SortOrder = Enum.SortOrder.LayoutOrder
	menuLayout.Parent = menuList

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
	Menus.Register(cancel) -- al colocar, el mouse queda libre para escoger el lugar

	local function refresh()
		local total = totalCount()
		openButton.Text = string.format("COLOCAR (%d) · G", total)
		if current then
			if countOf(current) <= 0 then
				stop()
			else
				nameLabel.Text = string.format("%s (%d)", current.name, countOf(current))
			end
		end
		if menu.Visible then
			redrawMenu()
		end
	end
	for _, item in Premium.list do
		player:GetAttributeChangedSignal("Premium_" .. item.key):Connect(refresh)
	end
	refresh()

	openButton.Visible = true
	local function toggleMenu()
		menu.Visible = not menu.Visible
		if menu.Visible then
			redrawMenu()
		end
	end
	openButton.Activated:Connect(toggleMenu)
	-- Con la tecla G también (en primera persona el mouse está fijo y no llega al botón)
	ContextActionService:BindAction("PlacementMenu", function(_, state)
		if state == Enum.UserInputState.Begin and not current then
			toggleMenu()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.G)
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
