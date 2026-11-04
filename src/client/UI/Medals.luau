-- Tu rango y tus medallas (Config/Ranks): el botón MEDALLAS (o la tecla M) abre la lista. Las
-- que ya ganaste salen doradas. Arriba: tu rango, cuántos zombis llevas y cuántos te faltan
-- para el siguiente. Los datos los publica el servidor (RankService).

local ContextActionService = game:GetService("ContextActionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ranks = require(ReplicatedStorage.Shared.Config.Ranks)
local Menus = require(script.Parent.Parent.Menus)

local player = Players.LocalPlayer

local GOLD = Color3.fromRGB(230, 180, 50)
local LOCKED = Color3.fromRGB(120, 120, 120)

local MedalsUI = {}

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function label(parent: Instance, text: string, size: UDim2, textSize: number, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Font = Enum.Font.GothamBold
	l.Text = text
	l.TextSize = textSize
	l.TextColor3 = color
	l.TextWrapped = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent = parent
	return l
end

function MedalsUI.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Medallas"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Parent = player:WaitForChild("PlayerGui")

	local open = Instance.new("TextButton")
	open.AnchorPoint = Vector2.new(0, 1)
	open.Position = UDim2.new(0, 702, 1, -12)
	open.Size = UDim2.fromOffset(160, 44)
	open.BackgroundColor3 = GOLD
	open.Font = Enum.Font.GothamBlack
	open.Text = "MEDALLAS · M"
	open.TextSize = 18
	open.TextColor3 = Color3.fromRGB(30, 30, 30)
	open.Parent = gui
	corner(open, 10)

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.9, 0.8)
	panel.BackgroundColor3 = Color3.fromRGB(24, 26, 22)
	panel.Visible = false
	panel.Parent = gui
	corner(panel, 12)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(520, 480)
	limit.Parent = panel
	local rankLabel = label(panel, "", UDim2.new(1, -70, 0, 30), 24, GOLD)
	rankLabel.Font = Enum.Font.GothamBlack
	rankLabel.Position = UDim2.fromOffset(16, 8)
	local killsLabel = label(panel, "", UDim2.new(1, -70, 0, 20), 14, Color3.new(1, 1, 1))
	killsLabel.Position = UDim2.fromOffset(16, 40)
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
	corner(close, 8)
	Menus.Register(close)

	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(12, 70)
	list.Size = UDim2.new(1, -24, 1, -82)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local function redraw()
		local kills = player:GetAttribute("Kills") or 0
		local rank, nextRank = Ranks.Of(kills)
		rankLabel.Text = "Rango: " .. rank.name
		killsLabel.Text = if nextRank
			then string.format("%d zombis · te faltan %d para %s", kills, nextRank.kills - kills, nextRank.name)
			else string.format("%d zombis · ¡rango más alto!", kills)
		local ok, owned = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("Medals") or "{}")
		if not ok or type(owned) ~= "table" then
			owned = {}
		end
		for _, child in list:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		for i, medal in Ranks.medals do
			local has = owned[medal.key] == true
			local row = Instance.new("Frame")
			row.LayoutOrder = i
			row.Size = UDim2.new(1, -8, 0, 48)
			row.BackgroundColor3 = Color3.fromRGB(42, 46, 38)
			row.Parent = list
			corner(row, 8)
			local title = label(row, (if has then "★ " else "☆ ") .. medal.name, UDim2.new(1, -16, 0, 22), 17, if has then GOLD else LOCKED)
			title.Font = Enum.Font.GothamBlack
			title.Position = UDim2.fromOffset(10, 4)
			local info = label(row, medal.description, UDim2.new(1, -16, 0, 18), 13, if has then Color3.new(1, 1, 1) else LOCKED)
			info.Position = UDim2.fromOffset(10, 26)
		end
	end

	local function toggle()
		panel.Visible = not panel.Visible
		if panel.Visible then
			redraw()
		end
	end
	open.Activated:Connect(toggle)
	close.Activated:Connect(function()
		panel.Visible = false
	end)
	ContextActionService:BindAction("Medals", function(_, state)
		if state == Enum.UserInputState.Begin then
			toggle()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.M)
	for _, attribute in { "Kills", "Medals" } do
		player:GetAttributeChangedSignal(attribute):Connect(function()
			if panel.Visible then
				redraw()
			end
		end)
	end
end

return MedalsUI
