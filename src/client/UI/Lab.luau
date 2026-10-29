-- La pantalla del Laboratorio: se abre con su letrero (mantener E). Muestra lo que se puede
-- investigar (Config/Research), en qué nivel vas y cuánto falta para lo que se investiga.
-- Lo revisa el servidor (ResearchService) por el RemoteEvent "Research".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local Research = require(ReplicatedStorage.Shared.Config.Research)
local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local Menus = require(script.Parent.Parent.Menus)
local Sfx = require(script.Parent.Parent.Sfx)

local researchRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Research") :: RemoteEvent
local player = Players.LocalPlayer

local BACKGROUND = Color3.fromRGB(24, 26, 22)
local CARD = Color3.fromRGB(42, 46, 38)
local BUY = Color3.fromRGB(60, 160, 70)
local BUSY = Color3.fromRGB(70, 110, 160)
local OWNED = Color3.fromRGB(90, 90, 96)
local GOLD = Color3.fromRGB(90, 255, 120)

local LabUI = {}

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
	local busyKey = player:GetAttribute("ResearchKey")
	local ends = player:GetAttribute("ResearchEnds") or 0
	for i, line in Research.lines do
		local level = player:GetAttribute("Research_" .. line.key) or 0
		local name = string.format("%s (nivel %d/%d)", line.name, level, #line.levels)
		local nextLevel = line.levels[level + 1]
		if busyKey == line.key then
			local left = math.max(0, ends - os.time())
			row(i, name, line.description, string.format("Investigando\n%d:%02d", left // 60, left % 60), BUSY, nil)
		elseif not nextLevel then
			row(i, name, line.description, "Al máximo", OWNED, nil)
		elseif busyKey then
			row(i, name, line.description, "Espera a que\ntermine", OWNED, nil)
		else
			local label = string.format("%s\n%d s", Format.Money(nextLevel.price), nextLevel.time)
			row(i, name, line.description, label, BUY, function()
				researchRemote:FireServer("start", line.key)
			end)
		end
	end
end

function LabUI.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Lab"
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
	limit.MaxSize = Vector2.new(540, 340)
	limit.Parent = panel
	local title = text(panel, "Laboratorio", UDim2.new(1, -60, 0, 44), 26, Enum.Font.GothamBlack)
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

	researchRemote.OnClientEvent:Connect(function(action: string)
		if action == "open" then
			panel.Visible = true
			redraw()
		end
	end)
	close.Activated:Connect(function()
		panel.Visible = false
	end)
	-- La cuenta regresiva: se redibuja cada segundo mientras está abierta
	task.spawn(function()
		while true do
			task.wait(1)
			redraw()
		end
	end)
end

return LabUI
