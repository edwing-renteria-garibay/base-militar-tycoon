-- La tienda de Robux: un botón "Tienda" arriba a la izquierda que abre la lista de pases y
-- la bolsa de dinero (Config/Store). Las ventanas de compra son de Roblox; cuando termina la
-- compra, el servidor da lo comprado (StoreService). En Studio, lo que aún no tiene ID sale
-- con un botón "Probar" que lo da gratis, para probarlo antes de publicar.

local MarketplaceService = game:GetService("MarketplaceService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Format = require(ReplicatedStorage.Shared.Format)
local Store = require(ReplicatedStorage.Shared.Config.Store)
local Menus = require(script.Parent.Parent.Menus)

local powerRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Power") :: RemoteEvent
local player = Players.LocalPlayer
local testing = RunService:IsStudio()

local BACKGROUND = Color3.fromRGB(24, 26, 22)
local CARD = Color3.fromRGB(42, 46, 38)
local BUY = Color3.fromRGB(60, 160, 70)
local OWNED = Color3.fromRGB(90, 90, 96)
local GOLD = Color3.fromRGB(230, 180, 50)
local TEST = Color3.fromRGB(200, 120, 40)

local StoreUI = {}

local panel: Frame
local list: ScrollingFrame

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function text(parent: Instance, value: string, size: UDim2, textSize: number, font: Enum.Font?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = size
	label.Font = font or Enum.Font.GothamBold
	label.Text = value
	label.TextSize = textSize
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

-- Una fila: nombre, descripción y el botón de comprar
local function row(order: number, name: string, description: string, buttonText: string, color: Color3, onBuy: (() -> ())?)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, -8, 0, 64)
	frame.BackgroundColor3 = CARD
	frame.LayoutOrder = order
	frame.Parent = list
	corner(frame, 8)
	local title = text(frame, name, UDim2.new(1, -140, 0, 26), 18, Enum.Font.GothamBlack)
	title.Position = UDim2.fromOffset(12, 6)
	title.TextColor3 = GOLD
	local info = text(frame, description, UDim2.new(1, -140, 0, 28), 13)
	info.Position = UDim2.fromOffset(12, 30)
	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -10, 0.5, 0)
	button.Size = UDim2.fromOffset(116, 40)
	button.BackgroundColor3 = color
	button.Font = Enum.Font.GothamBlack
	button.Text = buttonText
	button.TextSize = 16
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Parent = frame
	corner(button, 6)
	if onBuy then
		button.Activated:Connect(onBuy)
	else
		button.AutoButtonColor = false
	end
end

local function redraw()
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for i, pass in Store.passes do
		if player:GetAttribute("Pass_" .. pass.key) then
			row(i, pass.name, pass.description, "Ya lo tienes", OWNED, nil)
		elseif pass.id == 0 then
			row(i, pass.name, pass.description, "Próximamente", OWNED, nil)
		else
			row(i, pass.name, pass.description, pass.robux .. " Robux", BUY, function()
				MarketplaceService:PromptGamePassPurchase(player, pass.id)
			end)
		end
	end
	for i, product in Store.products do
		local description = product.description
		if product.kind == "money" then
			local income = player:GetAttribute("Income") or 0
			local amount = math.max(product.minimum, income * product.seconds)
			description = string.format("Recibes %s ahora mismo", Format.Money(amount))
		end
		if product.once and player:GetAttribute("Starter") then
			row(100 + i, product.name, description, "Ya lo tienes", OWNED, nil)
		elseif product.id == 0 and testing then
			row(100 + i, product.name, description, "Probar", TEST, function()
				powerRemote:FireServer("test", product.key)
			end)
		elseif product.id == 0 then
			row(100 + i, product.name, description, "Próximamente", OWNED, nil)
		else
			row(100 + i, product.name, description, product.robux .. " Robux", BUY, function()
				MarketplaceService:PromptProductPurchase(player, product.id)
			end)
		end
	end
end

function StoreUI.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Store"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Abajo a la izquierda (arriba a la izquierda están los botones de Roblox)
	local open = Instance.new("TextButton")
	open.AnchorPoint = Vector2.new(0, 1)
	open.Position = UDim2.new(0, 12, 1, -12)
	open.Size = UDim2.fromOffset(130, 44)
	open.BackgroundColor3 = GOLD
	open.Font = Enum.Font.GothamBlack
	open.Text = "TIENDA (B)"
	open.TextSize = 20
	open.TextColor3 = Color3.fromRGB(30, 30, 30)
	open.Parent = gui
	corner(open, 10)

	panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.9, 0.8)
	panel.BackgroundColor3 = BACKGROUND
	panel.Visible = false
	panel.Parent = gui
	corner(panel, 12)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(520, 460)
	limit.Parent = panel
	local title = text(panel, "Tienda", UDim2.new(1, -60, 0, 44), 26, Enum.Font.GothamBlack)
	title.Position = UDim2.fromOffset(16, 6)
	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -10, 0, 10)
	close.Size = UDim2.fromOffset(36, 36)
	close.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
	close.Font = Enum.Font.GothamBlack
	close.Text = "X"
	close.TextSize = 18
	close.TextColor3 = Color3.new(1, 1, 1)
	close.Parent = panel
	Menus.Register(close) -- en primera persona suelta el mouse mientras se ve el menú
	corner(close, 8)

	list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(12, 56)
	list.Size = UDim2.new(1, -24, 1, -68)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local function toggle()
		panel.Visible = not panel.Visible
		if panel.Visible then
			redraw()
		end
	end
	open.Activated:Connect(toggle)
	-- Con la tecla B también (en primera persona el mouse está fijo y no llega al botón)
	ContextActionService:BindAction("Store", function(_, state)
		if state == Enum.UserInputState.Begin then
			toggle()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.B, Enum.KeyCode.DPadDown)
	close.Activated:Connect(function()
		panel.Visible = false
	end)
	-- Al comprar un pase o el paquete inicial se redibuja ("Ya lo tienes")
	local function refresh()
		if panel.Visible then
			redraw()
		end
	end
	for _, pass in Store.passes do
		player:GetAttributeChangedSignal("Pass_" .. pass.key):Connect(refresh)
	end
	player:GetAttributeChangedSignal("Starter"):Connect(refresh)
end

return StoreUI
