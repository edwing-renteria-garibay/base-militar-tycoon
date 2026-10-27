-- La pantalla: arriba al centro tu dinero y cuánto genera tu base por segundo (y el multiplicador
-- si ya renaciste), y en medio los avisos que manda el servidor ("Construiste: Fogata", "+$120", "Te faltan $300"...).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Buildings = require(ReplicatedStorage.Shared.Config.Buildings)
local Format = require(ReplicatedStorage.Shared.Format)

local notice = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notice") :: RemoteEvent
local player = Players.LocalPlayer

local COLORS = {
	good = Color3.fromRGB(255, 255, 255),
	great = Color3.fromRGB(255, 210, 60),
	money = Color3.fromRGB(120, 255, 140),
	bad = Color3.fromRGB(255, 110, 100),
}

local HUD = {}

local gui: ScreenGui
local moneyLabel: TextLabel
local incomeLabel: TextLabel
local notices: Frame

local function newLabel(parent: Instance, size: UDim2, textSize: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Size = size
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextSize = textSize
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.Parent = parent
	return label
end

local function update()
	moneyLabel.Text = Format.Money(player:GetAttribute("Money") or 0)
	local text = string.format("+%s por segundo", Format.Money(player:GetAttribute("Income") or 0))
	-- Cada renacimiento suma x0.5 (Config/Buildings, rebirth)
	local rebirths = player:GetAttribute("Rebirths") or 0
	if rebirths > 0 then
		text ..= string.format("  ·  x%g", 1 + rebirths * Buildings.rebirth.bonusPerRebirth)
	end
	incomeLabel.Text = text
end

local function showNotice(text: string, kind: string?)
	local label = newLabel(notices, UDim2.new(1, 0, 0, 34), 26)
	label.Text = text
	label.TextColor3 = COLORS[kind or "good"] or COLORS.good
	label.LayoutOrder = -math.floor(os.clock() * 1000) -- el más nuevo arriba
	task.delay(2.5, function()
		local fade = TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 })
		fade:Play()
		fade.Completed:Wait()
		label:Destroy()
	end)
end

function HUD.Start()
	gui = Instance.new("ScreenGui")
	gui.Name = "HUD"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local top = Instance.new("Frame")
	top.AnchorPoint = Vector2.new(0.5, 0)
	top.Position = UDim2.new(0.5, 0, 0, 8)
	top.Size = UDim2.fromOffset(260, 64)
	top.BackgroundColor3 = Color3.fromRGB(24, 26, 22)
	top.BackgroundTransparency = 0.25
	top.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = top
	moneyLabel = newLabel(top, UDim2.new(1, 0, 0, 40), 32)
	moneyLabel.TextColor3 = COLORS.money
	incomeLabel = newLabel(top, UDim2.new(1, 0, 0, 20), 16)
	incomeLabel.Position = UDim2.fromOffset(0, 40)
	incomeLabel.Font = Enum.Font.GothamBold

	notices = Instance.new("Frame")
	notices.AnchorPoint = Vector2.new(0.5, 0)
	notices.Position = UDim2.new(0.5, 0, 0.25, 0)
	notices.Size = UDim2.fromOffset(500, 200)
	notices.BackgroundTransparency = 1
	notices.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = notices

	update()
	player:GetAttributeChangedSignal("Money"):Connect(update)
	player:GetAttributeChangedSignal("Income"):Connect(update)
	player:GetAttributeChangedSignal("Rebirths"):Connect(update)
	notice.OnClientEvent:Connect(showNotice)
end

return HUD
