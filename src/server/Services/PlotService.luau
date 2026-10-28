-- El mapa y los terrenos. Hay una calle en medio y 3 terrenos de cada lado (Settings.plotCount).
-- Cada jugador que entra recibe un terreno libre; al salir, el terreno se limpia y queda libre.
--
-- Cada terreno es un cuadrado de 200 x 200. Su CFrame está en el centro (donde va la caja
-- fuerte), mirando hacia la calle: así todas las
-- construcciones se colocan igual en cualquier terreno (ver Config/Buildings, "at").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Settings = require(ReplicatedStorage.Shared.Config.Settings)

local PlotService = {}

export type Plot = {
	index: number,
	cframe: CFrame, -- centro del piso del terreno; su frente (-Z) mira a la calle
	owner: Player?,
	contents: Folder, -- lo que se construye en él (se borra al quedar libre)
	sign: TextLabel,
}

-- El terreno es un cuadrado de 200 x 200 con la caja fuerte en el centro. El muro va a 70 del
-- centro (Config/Waves, wallInset); afuera del muro queda el anillo de las defensas (alambre,
-- minas, barricadas, zanjas) y más afuera aparecen los zombis.
local PLOT_SIZE = 200
local ROAD_WIDTH = 40
local SPACING = 230 -- distancia entre terrenos del mismo lado (deja pasillo para los zombis)
local ROAD_GAP = 10 -- distancia entre la calle y la orilla del terreno
local SPAWN = CFrame.new(0, 3, -16) -- dónde apareces dentro de tu terreno (junto a la caja)

local plots: { Plot } = {}

local function block(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function buildWorld()
	local world = Instance.new("Folder")
	world.Name = "Mapa"
	world.Parent = workspace
	local perSide = math.ceil(Settings.plotCount / 2)
	local length = perSide * SPACING + 120
	local depth = 2 * (PLOT_SIZE + ROAD_GAP) + ROAD_WIDTH + 160
	block(world, "Pasto", Vector3.new(length, 2, depth), CFrame.new(0, -1, 0), Color3.fromRGB(90, 110, 60), Enum.Material.Grass)
	block(world, "Calle", Vector3.new(length, 0.2, ROAD_WIDTH), CFrame.new(0, 0.1, 0), Color3.fromRGB(60, 60, 62), Enum.Material.Asphalt)
	for x = -length / 2 + 10, length / 2 - 10, 20 do
		block(world, "Raya", Vector3.new(8, 0.05, 0.6), CFrame.new(x, 0.22, 0), Color3.fromRGB(230, 200, 60), Enum.Material.SmoothPlastic)
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(0, 0.5, 0)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0 -- sin escudo al aparecer
	spawn.Parent = world
	return world, perSide
end

local function createPlot(world: Folder, index: number, perSide: number): Plot
	local row = if index <= perSide then 1 else -1
	local column = (index - 1) % perSide
	local x = (column - (perSide - 1) / 2) * SPACING
	local z = row * (ROAD_WIDTH / 2 + ROAD_GAP + PLOT_SIZE / 2)
	-- Los terrenos de un lado miran a -Z y los del otro a +Z: los dos hacia la calle
	local cframe = CFrame.new(x, 1, z) * CFrame.Angles(0, if row == 1 then 0 else math.pi, 0)

	local model = Instance.new("Model")
	model.Name = "Terreno" .. index
	model.Parent = world
	block(
		model,
		"Piso",
		Vector3.new(PLOT_SIZE, 1, PLOT_SIZE),
		cframe * CFrame.new(0, -0.5, 0),
		Color3.fromRGB(110, 120, 80),
		Enum.Material.Ground
	)

	-- Letrero con el nombre del dueño, enfrente, más alto que el muro
	block(model, "Poste", Vector3.new(0.6, 12, 0.6), cframe * CFrame.new(-30, 6, -60), Color3.fromRGB(80, 55, 35), Enum.Material.Wood)
	local board = block(model, "Letrero", Vector3.new(14, 4, 0.4), cframe * CFrame.new(-30, 13, -60), Color3.fromRGB(40, 43, 36), Enum.Material.Wood)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = board
	local sign = Instance.new("TextLabel")
	sign.Size = UDim2.fromScale(1, 1)
	sign.BackgroundTransparency = 1
	sign.Font = Enum.Font.GothamBlack
	sign.TextScaled = true
	sign.TextColor3 = Color3.fromRGB(230, 200, 60)
	sign.Text = "Terreno libre"
	sign.Parent = gui

	local contents = Instance.new("Folder")
	contents.Name = "Base"
	contents.Parent = model

	return { index = index, cframe = cframe, owner = nil, contents = contents, sign = sign }
end

-- Le da al jugador un terreno libre (o nil si están todos ocupados)
function PlotService.Claim(player: Player): Plot?
	for _, plot in plots do
		if plot.owner == nil then
			plot.owner = player
			plot.sign.Text = "Base de " .. player.DisplayName
			-- Cada vez que aparece, va a su terreno
			player.CharacterAdded:Connect(function(character)
				local root = character:WaitForChild("HumanoidRootPart", 5)
				if root and plot.owner == player then
					task.wait() -- deja que Roblox lo ponga en el spawn primero
					character:PivotTo(plot.cframe * SPAWN)
				end
			end)
			if player.Character then
				player.Character:PivotTo(plot.cframe * SPAWN)
			end
			return plot
		end
	end
	return nil
end

-- Los VIP tienen estrellas en su letrero
function PlotService.SetVIP(player: Player)
	for _, plot in plots do
		if plot.owner == player then
			plot.sign.Text = "★ Base de " .. player.DisplayName .. " ★"
		end
	end
end

function PlotService.Release(player: Player)
	for _, plot in plots do
		if plot.owner == player then
			plot.owner = nil
			plot.contents:ClearAllChildren()
			plot.sign.Text = "Terreno libre"
		end
	end
end

function PlotService.Start()
	Players.CharacterAutoLoads = true
	local world, perSide = buildWorld()
	for i = 1, Settings.plotCount do
		table.insert(plots, createPlot(world, i, perSide))
	end
end

return PlotService
