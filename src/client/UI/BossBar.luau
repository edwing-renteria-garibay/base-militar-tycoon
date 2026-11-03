-- La barra de vida del JEFE (Waves.boss): sale abajo en medio mientras está vivo. El servidor
-- pone su vida en los atributos "BossHealth" y "BossMax" (WaveService).

local Players = game:GetService("Players")

local player = Players.LocalPlayer

local BossBar = {}

function BossBar.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "BarraJefe"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 1, -120)
	frame.Size = UDim2.new(0.5, 0, 0, 26)
	frame.BackgroundColor3 = Color3.fromRGB(30, 10, 10)
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = gui
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(520, 26)
	limit.Parent = frame
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = frame
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(200, 30, 30)
	fill.BorderSizePixel = 0
	fill.Parent = frame
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 6)
	fillCorner.Parent = fill
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 16
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Parent = frame

	local function redraw()
		local health = player:GetAttribute("BossHealth")
		local max = player:GetAttribute("BossMax") or 1
		frame.Visible = health ~= nil
		if health then
			fill.Size = UDim2.fromScale(math.clamp(health / max, 0, 1), 1)
			label.Text = string.format("JEFE  %d / %d", health, max)
		end
	end
	player:GetAttributeChangedSignal("BossHealth"):Connect(redraw)
	redraw()
end

return BossBar
