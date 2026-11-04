-- La pantalla de CONTROLES: qué tecla o botón hace qué, para PC, PlayStation, Xbox y celular.
-- Sale sola la primera vez que apareces; luego con la tecla C o el botón "CONTROLES".
-- Abre en la pestaña del aparato con el que juegas.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Layout = require(script.Parent.Parent.Layout)
local Menus = require(script.Parent.Parent.Menus)

local player = Players.LocalPlayer

local ControlsUI = {}

local BACKGROUND = Color3.fromRGB(24, 26, 22)
local ROW = Color3.fromRGB(40, 44, 38)
local GOLD = Color3.fromRGB(230, 180, 50)

-- Cada fila: qué hace y con qué (PC, PlayStation, Xbox, celular). "" = no aplica
local ROWS = {
	{ "Moverse", "W A S D", "Stick izquierdo", "Stick izquierdo", "Stick de la izquierda" },
	{ "Mirar", "Mouse", "Stick derecho", "Stick derecho", "Arrastra el dedo" },
	{ "Saltar", "Espacio", "Equis (✕)", "A", "Botón de saltar" },
	{ "Correr", "Shift", "L3 (presiona el stick)", "LS (presiona el stick)", "Botón Correr" },
	{ "Disparar", "Clic izquierdo", "R2", "RT", "Toca la pantalla" },
	{ "Apuntar con mira", "Clic derecho", "L2", "LT", "" },
	{ "Recargar", "R", "Cuadrado (□)", "X", "Botón Recargar" },
	{ "Cambiar de arma", "1 al 9", "L1 / R1", "LB / RB", "Barra de abajo" },
	{ "Primera / tercera persona", "V", "Triángulo (△)", "Y", "" },
	{ "Comprar, cobrar, curarte", "Mantén E", "Mantén Cuadrado", "Mantén X", "Mantén el botón que sale" },
	{ "Transmitir la cura", "Mantén F", "Mantén Triángulo", "Mantén Y", "Mantén el botón que sale" },
	{ "Tienda", "B", "Flecha abajo", "Flecha abajo", "MENÚ > Tienda" },
	{ "Colocar defensas", "G (R gira, clic pone)", "Flecha derecha (gira), R2 pone", "Flecha derecha (gira), RT pone", "MENÚ > Colocar" },
	{ "Barricadas", "H (clic pone)", "Flecha izquierda, R2 pone", "Flecha izquierda, RT pone", "MENÚ > Barricadas" },
	{ "Bomba (si tienes)", "N", "Flecha arriba", "Flecha arriba", "Botón a la derecha" },
	{ "Ataque aéreo (si tienes)", "J", "R3 (presiona el stick)", "RS (presiona el stick)", "Botón a la derecha" },
	{ "Medallas", "M", "Select y elige", "View y elige", "MENÚ > Medallas" },
	{ "Invitar amigos", "I", "", "", "MENÚ > Invitar" },
	{ "Ver controles", "C", "Select y elige", "View y elige", "MENÚ > Controles" },
	{ "Moverte en un menú", "Mouse", "Stick y Equis (Círculo sale)", "Stick y A (B sale)", "Toca" },
}
local TABS = { "PC", "PlayStation", "Xbox", "Celular" }

local function corner(target: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = target
end

local function text(parent: Instance, value: string, size: UDim2, textSize: number, font: Enum.Font?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Font = font or Enum.Font.GothamBold
	l.Text = value
	l.TextSize = textSize
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextWrapped = true
	l.Parent = parent
	return l
end

-- ¿Con qué juega? (para abrir en esa pestaña)
local function defaultTab(): number
	if Layout.touch then
		return 4
	end
	local last = UserInputService:GetLastInputType()
	if last.Name:match("^Gamepad") or (not UserInputService.KeyboardEnabled and UserInputService.GamepadEnabled) then
		-- Roblox nombra los botones según el control: en PlayStation la A se llama "ButtonCross"
		local ok, name = pcall(UserInputService.GetStringForKeyCode, UserInputService, Enum.KeyCode.ButtonA)
		if ok and type(name) == "string" and name:find("Cross") then
			return 2
		end
		return 3
	end
	return 1
end

function ControlsUI.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Controles"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	gui.Parent = player:WaitForChild("PlayerGui")

	local open = Instance.new("TextButton")
	open.Size = UDim2.fromOffset(160, 44)
	open.BackgroundColor3 = Color3.fromRGB(80, 90, 110)
	open.Font = Enum.Font.GothamBlack
	open.Text = "CONTROLES · C"
	open.TextSize = 18
	open.TextColor3 = Color3.new(1, 1, 1)
	corner(open, 10)
	Layout.Dock(open, 6)

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.92, 0.86)
	panel.BackgroundColor3 = BACKGROUND
	panel.Visible = false
	panel.Parent = gui
	corner(panel, 12)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(640, 520)
	limit.Parent = panel
	local title = text(panel, "Controles", UDim2.new(1, -60, 0, 40), 24, Enum.Font.GothamBlack)
	title.Position = UDim2.fromOffset(16, 6)
	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -10, 0, 8)
	close.Size = UDim2.fromOffset(36, 36)
	close.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
	close.Font = Enum.Font.GothamBlack
	close.Text = "X"
	close.TextSize = 18
	close.TextColor3 = Color3.new(1, 1, 1)
	close.Parent = panel
	corner(close, 8)
	Menus.Register(close) -- suelta el mouse mientras se ve

	-- Las pestañas
	local tabs = Instance.new("Frame")
	tabs.Position = UDim2.fromOffset(12, 50)
	tabs.Size = UDim2.new(1, -24, 0, 34)
	tabs.BackgroundTransparency = 1
	tabs.Parent = panel
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 6)
	tabLayout.Parent = tabs

	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(12, 92)
	list.Size = UDim2.new(1, -24, 1, -104)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local tabButtons = {}
	local function show(tab: number)
		for i, b in tabButtons do
			b.BackgroundColor3 = if i == tab then GOLD else ROW
			b.TextColor3 = if i == tab then Color3.fromRGB(30, 30, 30) else Color3.new(1, 1, 1)
		end
		for _, child in list:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		for i, row in ROWS do
			local how = row[tab + 1]
			if how ~= "" then
				local line = Instance.new("Frame")
				line.LayoutOrder = i
				line.Size = UDim2.new(1, -8, 0, 30)
				line.BackgroundColor3 = ROW
				line.Parent = list
				corner(line, 6)
				local what = text(line, row[1], UDim2.new(0.45, -10, 1, 0), 15)
				what.Position = UDim2.fromOffset(10, 0)
				local key = text(line, how, UDim2.new(0.55, -10, 1, 0), 15, Enum.Font.GothamBlack)
				key.Position = UDim2.new(0.45, 0, 0, 0)
				key.TextColor3 = GOLD
			end
		end
	end
	for i, name in TABS do
		local b = Instance.new("TextButton")
		b.LayoutOrder = i
		b.Size = UDim2.new(0.25, -5, 1, 0)
		b.Font = Enum.Font.GothamBlack
		b.Text = name
		b.TextScaled = true
		b.Parent = tabs
		corner(b, 8)
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 6)
		pad.PaddingBottom = UDim.new(0, 6)
		pad.Parent = b
		b.Activated:Connect(function()
			show(i)
		end)
		tabButtons[i] = b
	end

	local function toggle()
		panel.Visible = not panel.Visible
		if panel.Visible then
			show(defaultTab())
		end
	end
	open.Activated:Connect(toggle)
	close.Activated:Connect(function()
		panel.Visible = false
	end)
	ContextActionService:BindAction("Controls", function(_, state)
		if state == Enum.UserInputState.Begin then
			toggle()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.C)

	-- La primera vez que entras, se abren solos
	task.delay(3, function()
		if not panel.Visible then
			toggle()
		end
	end)
end

return ControlsUI
