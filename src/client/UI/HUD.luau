-- La pantalla: arriba al centro tu dinero y cuánto junta tu caja fuerte por segundo; debajo,
-- la ola (cuánto falta o cuántos zombis quedan) y la vida de tu caja fuerte; en medio, los
-- avisos que manda el servidor ("Construiste: Mina", "+$120", "Te faltan $300"...).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

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
local waveLabel: TextLabel
local vaultBar: Frame
local vaultFill: Frame
local vaultLabel: TextLabel
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
	local record = player:GetAttribute("Record") or 0
	if record > 0 then
		text ..= string.format("  ·  Récord: ola %d", record)
	end
	incomeLabel.Text = text
end

-- Debajo del dinero: cuánto falta para la siguiente ola, o cuántos zombis quedan
local function updateWave()
	local wave = player:GetAttribute("Wave") or 1
	local enemies = player:GetAttribute("WaveEnemies")
	local waveIn = player:GetAttribute("WaveIn")
	if enemies then
		waveLabel.Text = string.format("¡OLA %d! Zombis: %d", wave, enemies)
		waveLabel.TextColor3 = COLORS.bad
		waveLabel.Visible = true
	elseif waveIn then
		waveLabel.Text = string.format("Ola %d en %d:%02d", wave, waveIn // 60, waveIn % 60)
		waveLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
		waveLabel.Visible = true
	else
		waveLabel.Visible = false
	end
end

-- La vida de la caja fuerte: una barra que se pone roja cuando le queda poca
local function updateVault()
	local health = player:GetAttribute("VaultHealth")
	local max = player:GetAttribute("VaultMax")
	if not health or not max or max <= 0 then
		vaultBar.Visible = false
		return
	end
	local share = math.clamp(health / max, 0, 1)
	vaultBar.Visible = true
	vaultFill.Size = UDim2.fromScale(share, 1)
	vaultFill.BackgroundColor3 = if share > 0.5
		then Color3.fromRGB(80, 200, 100)
		elseif share > 0.25 then Color3.fromRGB(230, 180, 50)
		else Color3.fromRGB(220, 70, 60)
	vaultLabel.Text = string.format("Caja fuerte %d / %d", health, max)
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

	waveLabel = newLabel(gui, UDim2.fromOffset(360, 24), 18)
	waveLabel.AnchorPoint = Vector2.new(0.5, 0)
	waveLabel.Position = UDim2.new(0.5, 0, 0, 78)
	waveLabel.Visible = false

	vaultBar = Instance.new("Frame")
	vaultBar.AnchorPoint = Vector2.new(0.5, 0)
	vaultBar.Position = UDim2.new(0.5, 0, 0, 104)
	vaultBar.Size = UDim2.fromOffset(240, 18)
	vaultBar.BackgroundColor3 = Color3.fromRGB(24, 26, 22)
	vaultBar.BackgroundTransparency = 0.25
	vaultBar.Visible = false
	vaultBar.Parent = gui
	vaultFill = Instance.new("Frame")
	vaultFill.BorderSizePixel = 0
	vaultFill.Parent = vaultBar
	vaultLabel = newLabel(vaultBar, UDim2.fromScale(1, 1), 13)
	vaultLabel.Font = Enum.Font.GothamBold

	notices = Instance.new("Frame")
	notices.AnchorPoint = Vector2.new(0.5, 0)
	notices.Position = UDim2.new(0.5, 0, 0.25, 0)
	notices.Size = UDim2.new(0.95, 0, 0, 200) -- en celular no cabían 500 de ancho
	notices.BackgroundTransparency = 1
	notices.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = notices

	update()
	player:GetAttributeChangedSignal("Money"):Connect(update)
	player:GetAttributeChangedSignal("Income"):Connect(update)
	player:GetAttributeChangedSignal("Record"):Connect(update)
	notice.OnClientEvent:Connect(showNotice)
	updateWave()
	player:GetAttributeChangedSignal("WaveIn"):Connect(updateWave)
	player:GetAttributeChangedSignal("WaveEnemies"):Connect(updateWave)
	player:GetAttributeChangedSignal("Wave"):Connect(updateWave)
	updateVault()
	player:GetAttributeChangedSignal("VaultHealth"):Connect(updateVault)
	player:GetAttributeChangedSignal("VaultMax"):Connect(updateVault)
end

return HUD
