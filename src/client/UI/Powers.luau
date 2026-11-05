-- Lo comprado con Robux que se usa durante la ola (Config/Store): la bomba (tecla N) y el ataque
-- aéreo (tecla J). Sus botones salen a la derecha solo si tienes y hay zombis. Abajo dice
-- cuántas vidas extra tienes y los consumibles que te duran (Waves.pickups). El servidor revisa
-- todo otra vez (WaveService).

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Waves = require(ReplicatedStorage.Shared.Config.Waves)
local Layout = require(script.Parent.Parent.Layout)

local powerRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Power") :: RemoteEvent
local player = Players.LocalPlayer

local PowersUI = {}

-- Cada botón: qué manda al servidor, su atributo (cuántas tiene), su texto, tecla y color
local POWERS = {
	{ what = "nuke", attribute = "Nukes", text = "BOMBA", key = Enum.KeyCode.N, pad = Enum.KeyCode.DPadUp, color = Color3.fromRGB(190, 50, 40) },
	{
		what = "strike",
		attribute = "Strikes",
		text = "ATAQUE AÉREO",
		key = Enum.KeyCode.J,
		pad = Enum.KeyCode.ButtonR3, -- (con control: presionar el stick derecho)
		color = Color3.fromRGB(200, 120, 40),
	},
}

function PowersUI.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Poderes"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local column = Instance.new("Frame")
	column.AnchorPoint = Vector2.new(1, 0.5)
	column.Position = UDim2.new(1, -12, 0.5, 0)
	if Layout.touch then
		-- En celular a la derecha están los botones de disparar: arriba, junto al MENÚ
		column.AnchorPoint = Vector2.new(1, 0)
		column.Position = UDim2.new(1, -140, 0, 8)
	end
	column.Size = UDim2.fromOffset(190, 240)
	column.BackgroundTransparency = 1
	column.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = column

	local buttons = {}
	for i, power in POWERS do
		local button = Instance.new("TextButton")
		button.LayoutOrder = i
		button.Size = UDim2.fromOffset(190, 46)
		button.BackgroundColor3 = power.color
		button.Font = Enum.Font.GothamBlack
		button.TextSize = 16
		button.TextColor3 = Color3.new(1, 1, 1)
		button.Visible = false
		button.Parent = column
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = button
		local function use()
			if button.Visible then
				powerRemote:FireServer(power.what)
			end
		end
		button.Activated:Connect(use)
		ContextActionService:BindAction("Power_" .. power.what, function(_, state)
			if state ~= Enum.UserInputState.Begin or not button.Visible then
				return Enum.ContextActionResult.Pass
			end
			use()
			return Enum.ContextActionResult.Sink
		end, false, power.key, power.pad)
		buttons[power] = button
	end

	local lives = Instance.new("TextLabel")
	lives.LayoutOrder = 10
	lives.Size = UDim2.fromOffset(190, 26)
	lives.BackgroundTransparency = 1
	lives.Font = Enum.Font.GothamBold
	lives.TextSize = 16
	lives.TextColor3 = Color3.fromRGB(255, 210, 60)
	lives.TextStrokeTransparency = 0.5
	lives.TextXAlignment = Enum.TextXAlignment.Right
	lives.Parent = column

	-- Los consumibles que te duran, con los segundos que les quedan
	local buffs = {}
	for i, kind in Waves.pickups.kinds do
		local label = Instance.new("TextLabel")
		label.LayoutOrder = 20 + i
		label.Size = UDim2.fromOffset(190, 24)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBlack
		label.TextSize = 16
		label.TextColor3 = kind.color
		label.TextStrokeTransparency = 0.4
		label.TextXAlignment = Enum.TextXAlignment.Right
		label.Visible = false
		label.Parent = column
		buffs[kind] = label
	end
	task.spawn(function()
		while true do
			for kind, label in buffs do
				local left = (player:GetAttribute("Buff_" .. kind.key) or 0) - workspace:GetServerTimeNow()
				label.Visible = left > 0
				label.Text = string.format("%s · %ds", kind.name, math.ceil(left))
			end
			task.wait(0.2)
		end
	end)

	local function redraw()
		local fighting = (player:GetAttribute("WaveEnemies") or 0) > 0
		for power, button in buttons do
			local count = player:GetAttribute(power.attribute) or 0
			button.Visible = fighting and count > 0
			button.Text = string.format("%s · %s (%d)", power.text, power.key.Name, count)
		end
		local extra = player:GetAttribute("Lives") or 0
		lives.Visible = extra > 0
		lives.Text = string.format("Vidas extra: %d", extra)
	end
	for _, attribute in { "WaveEnemies", "Nukes", "Strikes", "Lives" } do
		player:GetAttributeChangedSignal(attribute):Connect(redraw)
	end
	redraw()
end

return PowersUI
