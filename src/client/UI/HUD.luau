-- La pantalla: arriba al centro tu dinero y cuánto junta tu caja fuerte por segundo; debajo,
-- la ola (cuánto falta o cuántos zombis quedan) y la vida de tu caja fuerte, tu muro y tu
-- personaje; en medio, los avisos que manda el servidor ("Construiste: Mina", "+$120"...).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage.Shared.Format)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

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
local bars: Frame
local ammoLabel: TextLabel
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

-- Una barra con texto: verde, amarilla o roja según lo que le queda (share de 0 a 1)
local function makeBar(order: number): (Frame, Frame, TextLabel)
	local bar = Instance.new("Frame")
	bar.Size = UDim2.fromOffset(240, 18)
	bar.BackgroundColor3 = Color3.fromRGB(24, 26, 22)
	bar.BackgroundTransparency = 0.25
	bar.LayoutOrder = order
	bar.Parent = bars
	local fill = Instance.new("Frame")
	fill.BorderSizePixel = 0
	fill.Parent = bar
	local label = newLabel(bar, UDim2.fromScale(1, 1), 13)
	label.Font = Enum.Font.GothamBold
	return bar, fill, label
end

local function paint(fill: Frame, share: number)
	fill.Size = UDim2.fromScale(math.clamp(share, 0, 1), 1)
	fill.BackgroundColor3 = if share > 0.5
		then Color3.fromRGB(80, 200, 100)
		elseif share > 0.25 then Color3.fromRGB(230, 180, 50)
		else Color3.fromRGB(220, 70, 60)
end

-- La vida de la caja fuerte: una barra que se pone roja cuando le queda poca
local function updateVault()
	local health = player:GetAttribute("VaultHealth")
	local max = player:GetAttribute("VaultMax")
	if not health or not max or max <= 0 then
		vaultBar.Visible = false
		return
	end
	vaultBar.Visible = true
	paint(vaultFill, health / max)
	vaultLabel.Text = string.format("Caja fuerte %d / %d", health, max)
end

-- Abajo a la izquierda: las balas del arma que traes en la mano (el Rifle no se acaba)
local function updateAmmo()
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	local weapon = tool and Weapons.byId[tool.Name]
	if not weapon then
		ammoLabel.Visible = false
		return
	end
	ammoLabel.Visible = true
	if weapon.ammo then
		local ammo = player:GetAttribute("Ammo_" .. weapon.id) or 0
		ammoLabel.Text = string.format("%s: %d balas", weapon.name, ammo)
		ammoLabel.TextColor3 = if ammo > 0 then Color3.new(1, 1, 1) else COLORS.bad
	else
		ammoLabel.Text = weapon.name .. ": ∞"
		ammoLabel.TextColor3 = Color3.new(1, 1, 1)
	end
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

	-- Todo en la esquina de arriba a la izquierda, para que no tape el centro de la pantalla
	local top = Instance.new("Frame")
	top.Position = UDim2.fromOffset(12, 8)
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
	waveLabel.Position = UDim2.fromOffset(12, 76)
	waveLabel.TextXAlignment = Enum.TextXAlignment.Left
	waveLabel.Visible = false

	-- Debajo de la ola: la caja fuerte, el muro y tu vida
	bars = Instance.new("Frame")
	bars.Position = UDim2.fromOffset(22, 102)
	bars.Size = UDim2.fromOffset(240, 62)
	bars.BackgroundTransparency = 1
	bars.Parent = gui
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 4)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = bars
	vaultBar, vaultFill, vaultLabel = makeBar(1)
	vaultBar.Visible = false
	local wallBar, wallFill, wallLabel = makeBar(2)
	wallBar.Visible = false
	local function updateWall()
		local share = player:GetAttribute("WallHealth")
		wallBar.Visible = share ~= nil
		if share then
			paint(wallFill, share / 100)
			wallLabel.Text = string.format("Muro %d%%", share)
		end
	end
	updateWall()
	player:GetAttributeChangedSignal("WallHealth"):Connect(updateWall)
	local lifeBar, lifeFill, lifeLabel = makeBar(3)
	lifeBar.Visible = false
	local function watchLife(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
		if not humanoid then
			return
		end
		local function updateLife()
			lifeBar.Visible = true
			paint(lifeFill, humanoid.Health / humanoid.MaxHealth)
			lifeLabel.Text = string.format("Tu vida %d / %d", math.ceil(humanoid.Health), humanoid.MaxHealth)
		end
		updateLife()
		humanoid.HealthChanged:Connect(updateLife)
	end
	player.CharacterAdded:Connect(watchLife)
	if player.Character then
		task.spawn(watchLife, player.Character)
	end

	ammoLabel = newLabel(gui, UDim2.fromOffset(300, 30), 22)
	ammoLabel.AnchorPoint = Vector2.new(0, 1)
	ammoLabel.Position = UDim2.new(0, 14, 1, -64) -- encima del botón de la tienda
	ammoLabel.TextXAlignment = Enum.TextXAlignment.Left
	ammoLabel.Visible = false
	task.spawn(function()
		while true do
			updateAmmo()
			task.wait(0.2)
		end
	end)

	notices = Instance.new("Frame")
	notices.AnchorPoint = Vector2.new(0.5, 0)
	notices.Position = UDim2.new(0.5, 0, 0, 8) -- arriba en medio
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
