-- La tienda de la Armería: se abre con el letrero de la armería (mantener E). Muestra las armas
-- de Config/Weapons: las que no tienes se compran y a las que tienes se les compra munición.
-- Las compras las revisa el servidor (WeaponService) por el RemoteEvent "Armory".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local Menus = require(script.Parent.Parent.Menus)
local Sfx = require(script.Parent.Parent.Sfx)

local armoryRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Armory") :: RemoteEvent
local player = Players.LocalPlayer

local BACKGROUND = Color3.fromRGB(24, 26, 22)
local CARD = Color3.fromRGB(42, 46, 38)
local BUY = Color3.fromRGB(60, 160, 70)
local AMMO = Color3.fromRGB(190, 140, 40)
local OWNED = Color3.fromRGB(90, 90, 96)
local GOLD = Color3.fromRGB(230, 180, 50)

local ArmoryUI = {}

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

-- Una fila: nombre, descripción y el botón
local function row(order: number, name: string, description: string, buttonText: string, color: Color3, onBuy: (() -> ())?)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, -8, 0, 64)
	frame.BackgroundColor3 = CARD
	frame.LayoutOrder = order
	frame.Parent = list
	corner(frame, 8)
	local title = text(frame, name, UDim2.new(1, -160, 0, 26), 18, Enum.Font.GothamBlack)
	title.Position = UDim2.fromOffset(12, 6)
	title.TextColor3 = GOLD
	local info = text(frame, description, UDim2.new(1, -160, 0, 28), 13)
	info.Position = UDim2.fromOffset(12, 30)
	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -10, 0.5, 0)
	button.Size = UDim2.fromOffset(136, 44)
	button.BackgroundColor3 = color
	button.Font = Enum.Font.GothamBlack
	button.Text = buttonText
	button.TextSize = 14
	button.TextWrapped = true
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Parent = frame
	corner(button, 6)
	if onBuy then
		button.Activated:Connect(function()
			Sfx.PlayLocal(Sounds.buy)
			onBuy()
		end)
	else
		button.AutoButtonColor = false
	end
end

local function redraw()
	if not panel.Visible then
		return
	end
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local x2 = player:GetAttribute("Pass_MunicionX2") == true
	for i, weapon in Weapons.list do
		local owned = player:GetAttribute("Weapon_" .. weapon.id) == true
		local stats = string.format("Daño %d · %s", weapon.damage * (weapon.pellets or 1), weapon.description)
		if not owned then
			row(i, weapon.name, stats, "Comprar\n" .. Format.Money(weapon.price), BUY, function()
				armoryRemote:FireServer("weapon", weapon.id)
			end)
		elseif weapon.ammo then
			local amount = weapon.ammo.amount * (if x2 then 2 else 1)
			local have = player:GetAttribute("Ammo_" .. weapon.id) or 0
			local name = string.format("%s (%d balas)", weapon.name, have)
			local label = string.format("+%d balas\n%s", amount, Format.Money(weapon.ammo.price))
			row(i, name, stats, label, AMMO, function()
				armoryRemote:FireServer("ammo", weapon.id)
			end)
		else
			row(i, weapon.name, stats, "Ya la tienes", OWNED, nil)
		end
	end
end

function ArmoryUI.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Armory"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Parent = player:WaitForChild("PlayerGui")

	panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.9, 0.8)
	panel.BackgroundColor3 = BACKGROUND
	panel.Visible = false
	panel.Parent = gui
	corner(panel, 12)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(540, 420)
	limit.Parent = panel
	local title = text(panel, "Armería", UDim2.new(1, -60, 0, 44), 26, Enum.Font.GothamBlack)
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

	armoryRemote.OnClientEvent:Connect(function(action: string)
		if action == "open" then
			panel.Visible = true
			redraw()
		end
	end)
	close.Activated:Connect(function()
		panel.Visible = false
	end)
	-- Al comprar se redibuja (ya la tienes, cuántas balas te quedan)
	for _, weapon in Weapons.list do
		player:GetAttributeChangedSignal("Weapon_" .. weapon.id):Connect(redraw)
		player:GetAttributeChangedSignal("Ammo_" .. weapon.id):Connect(redraw)
	end
	player:GetAttributeChangedSignal("Pass_MunicionX2"):Connect(redraw)
end

return ArmoryUI
