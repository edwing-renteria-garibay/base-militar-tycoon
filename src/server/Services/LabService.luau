-- El laboratorio infestado (Config/Lab): al final de la calle, un laberinto de túneles de metal
-- lleno de zombis (la mitad, infecciosos: te contagian y necesitas antídotos). Al fondo, en el laboratorio, está la terminal con la frecuencia de la cura (mantén
-- E). Quien la tiene (profile.frequency) puede transmitir la cura desde su caja fuerte, que se
-- vuelve antena (VictoryService).
--
-- El laberinto se arma igual en cada servidor (Lab.seed): se "cava" con una búsqueda en
-- profundidad, así siempre hay un solo camino de la entrada (oeste) a la salida (este).
--
-- Los zombis de adentro no van a tu base: te persiguen si te ven (sin pared en medio) y, si
-- no, rondan su cuadro. Siempre hay Lab.zombies.alive.
--
-- Para tomar la frecuencia:
-- 1. Junta Lab.cards.count tarjetas, escondidas en callejones sin salida del laberinto (sin
--    ellas, la puerta láser del laboratorio te regresa). Atributo "LabCards".
-- 2. Mata al guardián que cuida la terminal (Lab.guardian).
-- 3. Al tomarla suena la alarma (Lab.alarm): todos los zombis te huelen. ¡Corre a tu base!

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lab = require(ReplicatedStorage.Shared.Config.Lab)
local Settings = require(ReplicatedStorage.Shared.Config.Settings)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local RankService = require(script.Parent.RankService)
local WaveService = require(script.Parent.WaveService)

local notice = ReplicatedStorage.Remotes.Notice :: RemoteEvent

local METAL = Color3.fromRGB(88, 92, 98)
local DARK = Color3.fromRGB(40, 42, 46)
local ALARM = Color3.fromRGB(255, 40, 30)
local CURE = Color3.fromRGB(90, 255, 140)

local LabService = {}

type LabZombie = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	home: Vector3,
	lastHit: number,
	infects: boolean,
}

local origin: CFrame -- el centro del laberinto
local exitSpot: Vector3 -- el cuadro de la salida (ahí te regresa la puerta láser)
local guardianSpot: CFrame -- donde sale el guardián
local cardsOf: { [Player]: { [number]: boolean } } = {}
local guardian: LabZombie? = nil
local guardianDiedAt = -math.huge
local alarmUntil = 0
local alarmTarget: Player? = nil
local alarmLamps: { PointLight } = {}
local half: number -- medio ancho del laberinto
local folder: Folder
local zombies: { LabZombie } = {}
local cellCenters: { Vector3 } = {}

local function block(size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = folder
	return p
end

-- El centro del cuadro (i, j): i va de oeste (0) a este, j de norte (0) a sur
local function cellCenter(i: number, j: number): CFrame
	local size = Lab.cellSize
	return origin * CFrame.new(-half + size / 2 + i * size, 0, -half + size / 2 + j * size)
end

-- Cava el laberinto: devuelve open[i][j] = { east = bool, south = bool } (pasillos abiertos)
local function carve(n: number): { { { east: boolean, south: boolean } } }
	local random = Random.new(Lab.seed)
	local open, seen = {}, {}
	for i = 0, n - 1 do
		open[i] = {}
		seen[i] = {}
		for j = 0, n - 1 do
			open[i][j] = { east = false, south = false }
		end
	end
	local stack = { { 0, math.floor(n / 2) } }
	seen[0][math.floor(n / 2)] = true
	while #stack > 0 do
		local top = stack[#stack]
		local i, j = top[1], top[2]
		local options = {}
		for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			local a, b = i + d[1], j + d[2]
			if a >= 0 and a < n and b >= 0 and b < n and not seen[a][b] then
				table.insert(options, { a, b })
			end
		end
		if #options == 0 then
			table.remove(stack)
		else
			local pick = options[random:NextInteger(1, #options)]
			local a, b = pick[1], pick[2]
			if a > i then
				open[i][j].east = true
			elseif a < i then
				open[a][b].east = true
			elseif b > j then
				open[i][j].south = true
			else
				open[a][b].south = true
			end
			seen[a][b] = true
			table.insert(stack, pick)
		end
	end
	return open
end

local function wall(center: CFrame, length: number, alongX: boolean)
	local height = Lab.wallHeight
	local size = if alongX then Vector3.new(length + 2, height, 2) else Vector3.new(2, height, length + 2)
	block(size, center * CFrame.new(0, height / 2, 0), METAL, Enum.Material.DiamondPlate)
	-- Una franja oscura abajo, de lámina vieja
	local trim = if alongX then Vector3.new(length + 2.1, 1.2, 2.1) else Vector3.new(2.1, 1.2, length + 2.1)
	block(trim, center * CFrame.new(0, 0.6, 0), DARK, Enum.Material.CorrodedMetal)
end

-- Cuántos pasillos tiene abiertos el cuadro (i, j)
local function openings(open, n: number, mid: number, i: number, j: number): number
	local count = 0
	if i < n - 1 and open[i][j].east then
		count += 1
	end
	if i > 0 and open[i - 1][j].east then
		count += 1
	end
	if j < n - 1 and open[i][j].south then
		count += 1
	end
	if j > 0 and open[i][j - 1].south then
		count += 1
	end
	if j == mid and (i == 0 or i == n - 1) then
		count += 1 -- la entrada y la salida
	end
	return count
end

-- Una tarjeta: cada jugador toma la suya (se queda para los demás)
local function makeCard(index: number, spot: CFrame)
	local card = block(Vector3.new(1.6, 0.2, 1.1), spot * CFrame.new(0, 3, 0) * CFrame.Angles(0, 0, math.rad(20)), Color3.fromRGB(60, 160, 255), Enum.Material.Neon)
	card.Name = "Tarjeta"
	card.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = card.Color
	light.Range = 10
	light.Parent = card
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Tomar tarjeta"
	prompt.ObjectText = string.format("Tarjeta %d de %d", index, Lab.cards.count)
	prompt.HoldDuration = Lab.cards.holdTime
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = card
	prompt.Triggered:Connect(function(player)
		local mine = cardsOf[player] or {}
		cardsOf[player] = mine
		if mine[index] then
			notice:FireClient(player, "Ya tienes esta tarjeta", "good")
			return
		end
		mine[index] = true
		local count = 0
		for _ in mine do
			count += 1
		end
		player:SetAttribute("LabCards", count)
		local text = if count >= Lab.cards.count
			then "¡Tienes todas las tarjetas! Ya abre la puerta del laboratorio"
			else string.format("Tarjeta %d de %d", count, Lab.cards.count)
		notice:FireClient(player, text, "great")
	end)
end

-- Las tarjetas van en callejones sin salida, lo más lejos posible de la entrada y entre ellas
local function placeCards(open, n: number, mid: number)
	local ends = {}
	for i = 0, n - 1 do
		for j = 0, n - 1 do
			if openings(open, n, mid, i, j) == 1 then
				table.insert(ends, { i = i, j = j, far = i + math.abs(j - mid) })
			end
		end
	end
	table.sort(ends, function(a, b)
		return a.far > b.far
	end)
	local chosen = {}
	for _, spot in ends do
		local apart = true
		for _, other in chosen do
			if math.abs(spot.i - other.i) + math.abs(spot.j - other.j) < 4 then
				apart = false
			end
		end
		if apart and #chosen < Lab.cards.count then
			table.insert(chosen, spot)
		end
	end
	for _, spot in ends do -- si no alcanzan los lejanos, cualquiera
		if #chosen < Lab.cards.count and not table.find(chosen, spot) then
			table.insert(chosen, spot)
		end
	end
	for index, spot in chosen do
		makeCard(index, cellCenter(spot.i, spot.j))
	end
end

-- Como pista de aterrizaje: focos rojos a las orillas de la calle, de los terrenos hasta la
-- entrada del laberinto, y una hilera al centro en la última parte
local function runway()
	local lights = Instance.new("Folder")
	lights.Name = "Pista"
	lights.Parent = folder
	local entrance = origin.Position.X - half
	local count = 0
	local function bulb(x: number, z: number)
		count += 1
		local p = Instance.new("Part")
		p.Name = "Foco"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.Size = Vector3.new(0.9, 0.5, 0.9)
		p.CFrame = CFrame.new(x, 0.45, z)
		p.Color = ALARM
		p.Material = Enum.Material.Neon
		p.Parent = lights
		if count % 4 == 0 then -- luz en uno de cada cuatro (muchas luces hacen lento el juego)
			local light = Instance.new("PointLight")
			light.Color = ALARM
			light.Range = 9
			light.Brightness = 1.2
			light.Parent = p
		end
	end
	for x = -PlotService.roadEnd + 10, entrance - 4, 16 do
		bulb(x, -21)
		bulb(x, 21)
	end
	for x = PlotService.roadEnd - 120, entrance - 8, 8 do
		bulb(x, 0)
	end
end

local function build()
	local n, size = Lab.cells, Lab.cellSize
	half = n * size / 2
	origin = CFrame.new(PlotService.roadEnd + 40 + half, 1, 0)
	folder = Instance.new("Folder")
	folder.Name = "LaboratorioInfestado"
	folder.Parent = workspace

	-- Piso: el camino desde la calle, el laberinto y el laboratorio del fondo
	block(Vector3.new(2 * half + 200, 2, 2 * half + 80), origin * CFrame.new(40, -1, 0), Color3.fromRGB(70, 80, 55), Enum.Material.Grass)
	block(Vector3.new(60, 0.2, 30), origin * CFrame.new(-half - 30, 0.1, 0), Color3.fromRGB(60, 60, 62), Enum.Material.Asphalt)
	block(Vector3.new(2 * half, 0.2, 2 * half), origin * CFrame.new(0, 0.1, 0), DARK, Enum.Material.Metal)

	local open = carve(n)
	local mid = math.floor(n / 2)
	for i = 0, n - 1 do
		for j = 0, n - 1 do
			local c = cellCenter(i, j)
			table.insert(cellCenters, c.Position + Vector3.new(0, 3, 0))
			if i < n - 1 and not open[i][j].east then
				wall(c * CFrame.new(size / 2, 0, 0), size, false)
			end
			if j < n - 1 and not open[i][j].south then
				wall(c * CFrame.new(0, 0, size / 2), size, true)
			end
			-- Una lámpara en el techo de cada cuadro: roja de alarma o blanca que apenas alumbra
			local alarm = (i + j) % 2 == 0
			local color = if alarm then ALARM else Color3.fromRGB(200, 210, 220)
			local lamp = block(Vector3.new(1.4, 0.4, 1.4), c * CFrame.new(0, Lab.wallHeight - 0.2, 0), color, Enum.Material.Neon)
			lamp.CanCollide = false
			local light = Instance.new("PointLight")
			light.Color = color
			light.Range = 20
			light.Brightness = if alarm then 1.5 else 0.8
			light.Parent = lamp
			if alarm then
				table.insert(alarmLamps, light) -- parpadean cuando suena la alarma
			end
		end
	end
	-- El borde, con la entrada al oeste y la salida al este (en el cuadro de en medio)
	for k = 0, n - 1 do
		if k ~= mid then
			wall(cellCenter(0, k) * CFrame.new(-size / 2, 0, 0), size, false)
			wall(cellCenter(n - 1, k) * CFrame.new(size / 2, 0, 0), size, false)
		end
		wall(cellCenter(k, 0) * CFrame.new(0, 0, -size / 2), size, true)
		wall(cellCenter(k, n - 1) * CFrame.new(0, 0, size / 2), size, true)
	end
	-- El techo: son túneles (no se ve el cielo ni se puede saltar por arriba)
	block(Vector3.new(2 * half + 2, 1, 2 * half + 2), origin * CFrame.new(0, Lab.wallHeight + 0.5, 0), DARK, Enum.Material.DiamondPlate)
	runway()
	placeCards(open, n, mid)
	-- Letrero en la entrada
	local sign = block(Vector3.new(16, 4, 0.5), origin * CFrame.new(-half - 4, Lab.wallHeight + 3, 0) * CFrame.Angles(0, math.rad(90), 0), DARK, Enum.Material.Metal)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.Parent = sign
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBlack
	text.TextScaled = true
	text.TextColor3 = ALARM
	text.Text = string.format("LABORATORIO INFESTADO · OLA %d+", Lab.minRecord)
	text.Parent = gui

	-- El laboratorio del fondo, pegado a la salida del laberinto: cerrado por todos lados menos
	-- por ahí, así no se puede llegar rodeando
	local exit = cellCenter(n - 1, mid)
	exitSpot = exit.Position + Vector3.new(0, 3, 0)
	local labCenter = exit * CFrame.new(size / 2 + 17, 0, 0)
	guardianSpot = labCenter * CFrame.new(0, 4, 0)
	-- La puerta láser: barras rojas en la salida del laberinto (sin tarjetas te regresa)
	for y = 1.5, Lab.wallHeight - 1.5, 2.5 do
		local laser = block(Vector3.new(0.3, 0.3, size), exit * CFrame.new(size / 2, y, 0), ALARM, Enum.Material.Neon)
		laser.CanCollide = false
		laser.CanQuery = false
	end
	block(Vector3.new(34, 1, 30), labCenter * CFrame.new(0, 0.5, 0), Color3.fromRGB(200, 200, 195), Enum.Material.SmoothPlastic)
	for _, z in { -15, 15 } do
		block(Vector3.new(34, 12, 1), labCenter * CFrame.new(0, 6, z), Color3.fromRGB(220, 222, 220), Enum.Material.SmoothPlastic)
	end
	block(Vector3.new(1, 12, 30), labCenter * CFrame.new(17, 6, 0), Color3.fromRGB(220, 222, 220), Enum.Material.SmoothPlastic)
	block(Vector3.new(34, 1, 31), labCenter * CFrame.new(0, 12.5, 0), DARK, Enum.Material.Metal)
	local terminal = block(Vector3.new(3, 5, 6), labCenter * CFrame.new(12, 3.5, 0), DARK, Enum.Material.Metal)
	terminal.Name = "Terminal" -- la marca de OBJETIVO apunta aquí (client/ObjectiveMarker)
	local screen = block(Vector3.new(0.2, 3, 5), labCenter * CFrame.new(10.4, 4, 0), CURE, Enum.Material.Neon)
	screen.CanCollide = false
	local glow = Instance.new("PointLight")
	glow.Color = CURE
	glow.Range = 26
	glow.Brightness = 2
	glow.Parent = screen
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Tomar la frecuencia de la cura"
	prompt.ObjectText = "Terminal"
	prompt.HoldDuration = Lab.holdTime
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = terminal
	prompt.Triggered:Connect(function(player)
		local profile = DataService.Get(player)
		if not profile then
			return
		end
		if profile.frequency then
			notice:FireClient(player, "Ya tienes la frecuencia: transmítela desde tu caja fuerte", "good")
			return
		end
		if guardian and guardian.humanoid.Health > 0 then
			notice:FireClient(player, "¡Primero acaba con el guardián!", "bad")
			return
		end
		profile.frequency = true
		-- Las tarjetas se gastan, y suena la alarma: todos los zombis te persiguen
		cardsOf[player] = nil
		player:SetAttribute("LabCards", 0)
		alarmUntil = os.clock() + Lab.alarm.duration
		alarmTarget = player
		notice:FireClient(player, "¡ALARMA! Todos los zombis del laboratorio te huelen: ¡corre a tu base!", "bad")
		player:SetAttribute("Frequency", true)
		RankService.Count(player, "frequencies") -- (y la marca de objetivo pasa a tu caja)
		notice:FireClient(player, "¡Tienes la frecuencia de la cura! Vuelve a tu base y mantén F junto a la antena", "great")
	end)
end

local function canEnter(player: Player): boolean
	local profile = DataService.Get(player)
	return Settings.Testing.enabled or (profile ~= nil and profile.record >= Lab.minRecord)
end

-- ¿Está dentro (del laberinto o del laboratorio del fondo)?
local function insideLab(position: Vector3): boolean
	local here = origin:PointToObjectSpace(position)
	return here.X > -half - 1 and here.X < half + 40 and math.abs(here.Z) < half + 1
end

-- ¿Está dentro del laboratorio del fondo (pasando la puerta láser)?
local function insideBuilding(position: Vector3): boolean
	local here = origin:PointToObjectSpace(position)
	return here.X > half + 0.5 and here.X < half + 40 and math.abs(here.Z) < 16
end

-- El guardián: un zombi enorme junto a la terminal
local function spawnGuardian()
	local base = WaveService.ZombieTemplate()
	if not base then
		return
	end
	local config = Lab.guardian
	local model = base:Clone()
	model:ScaleTo(config.scale)
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	humanoid.MaxHealth = config.health
	humanoid.Health = config.health
	humanoid.WalkSpeed = config.speed
	humanoid.DisplayName = "GUARDIÁN"
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
	model:SetAttribute("Boss", true) -- cuenta para Cazajefes
	CollectionService:AddTag(model, "Enemy")
	local colors = model:FindFirstChildOfClass("BodyColors")
	if colors then
		colors:Destroy()
	end
	for _, piece in model:GetDescendants() do
		if piece:IsA("BasePart") and piece.Name ~= "HumanoidRootPart" and not piece:FindFirstAncestorOfClass("Accessory") then
			piece.Color = piece.Color:Lerp(Lab.zombies.infectColor, 0.7)
		end
	end
	local glow = Instance.new("PointLight")
	glow.Color = Lab.zombies.infectColor
	glow.Range = 16
	glow.Brightness = 2
	glow.Parent = root
	model:PivotTo(guardianSpot)
	model.Parent = folder
	root:SetNetworkOwner(nil)
	local zombie = { model = model, humanoid = humanoid, root = root, home = guardianSpot.Position, lastHit = 0, infects = true }
	guardian = zombie
	humanoid.Died:Connect(function()
		guardianDiedAt = os.clock()
		Debris:AddItem(model, 3)
		-- Premio para los que estaban adentro peleando
		for _, player in Players:GetPlayers() do
			local playerRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if playerRoot and insideBuilding(playerRoot.Position) then
				DataService.AddMoney(player, config.reward)
				notice:FireClient(player, "¡Mataste al GUARDIÁN! Toma la frecuencia de la terminal", "great")
			end
		end
	end)
end

local function spawnZombie()
	local base = WaveService.ZombieTemplate()
	if not base or #cellCenters == 0 then
		return
	end
	-- En un cuadro donde no haya nadie cerca
	local spot = nil
	for _ = 1, 10 do
		local candidate = cellCenters[math.random(#cellCenters)]
		local near = false
		for _, player in Players:GetPlayers() do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and (root.Position - candidate).Magnitude < 30 then
				near = true
			end
		end
		if not near then
			spot = candidate
			break
		end
	end
	if not spot then
		return
	end
	local model = base:Clone()
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	humanoid.MaxHealth = Lab.zombies.health
	humanoid.Health = Lab.zombies.health
	humanoid.WalkSpeed = Lab.zombies.speed
	local infects = math.random() < Lab.zombies.infectShare
	humanoid.DisplayName = if infects then "Zombi infeccioso" else "Zombi del laboratorio"
	if infects then
		-- Verdes y con un brillo: estos te contagian
		local colors = model:FindFirstChildOfClass("BodyColors")
		if colors then
			colors:Destroy() -- si no, Roblox les vuelve a poner sus colores
		end
		for _, piece in model:GetDescendants() do
			if piece:IsA("BasePart") and piece.Name ~= "HumanoidRootPart" and not piece:FindFirstAncestorOfClass("Accessory") then
				piece.Color = piece.Color:Lerp(Lab.zombies.infectColor, 0.6)
			end
		end
		local glow = Instance.new("PointLight")
		glow.Color = Lab.zombies.infectColor
		glow.Range = 8
		glow.Parent = root
	end
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
	CollectionService:AddTag(model, "Enemy")
	model:PivotTo(CFrame.new(spot))
	model.Parent = folder
	root:SetNetworkOwner(nil)
	local zombie = { model = model, humanoid = humanoid, root = root, home = spot, lastHit = 0, infects = infects }
	table.insert(zombies, zombie)
	humanoid.Died:Connect(function()
		Debris:AddItem(model, 2)
	end)
end

-- ¿Lo ve? (sin pared en medio)
local function sees(zombie: LabZombie, target: BasePart): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { folder }
	local from = zombie.root.Position
	local result = workspace:Raycast(from, target.Position - from, params)
	return result == nil or result.Instance:IsDescendantOf(target.Parent :: Instance)
end

local function think(zombie: LabZombie, now: number)
	local best, bestDistance = nil, Lab.zombies.sight
	-- Con la alarma, persiguen a quien tomó la frecuencia aunque haya paredes
	if zombie ~= guardian and now < alarmUntil and alarmTarget then
		local character = alarmTarget.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 then
			local distance = (root.Position - zombie.root.Position).Magnitude
			if distance < Lab.alarm.smell then
				best, bestDistance = { root = root, humanoid = humanoid, player = alarmTarget }, distance
			end
		end
	end
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 then
			local distance = (root.Position - zombie.root.Position).Magnitude
			local reach = if zombie == guardian then 30 else math.huge -- el guardián no sale lejos
			if distance < bestDistance and distance < reach and sees(zombie, root) then
				best, bestDistance = { root = root, humanoid = humanoid, player = player }, distance
			end
		end
	end
	if best then
		zombie.humanoid:MoveTo(best.root.Position)
		if bestDistance < (if zombie == guardian then 8 else 5) and now - zombie.lastHit >= 1 then
			zombie.lastHit = now
			best.humanoid:TakeDamage(if zombie == guardian then Lab.guardian.damage else Lab.zombies.damage)
			if zombie.infects and not best.player:GetAttribute("Infected") and best.humanoid.Health > 0 then
				best.player:SetAttribute("Infected", true) -- InfectionService le quita vida
				notice:FireClient(best.player, "¡Te infectaron! Usa un antídoto", "bad")
			end
		end
	elseif zombie == guardian then
		zombie.humanoid:MoveTo(zombie.home) -- vuelve a cuidar la terminal
	elseif (zombie.root.Position - zombie.home).Magnitude > 6 or math.random() < 0.1 then
		local wander = Vector3.new(math.random(-5, 5), 0, math.random(-5, 5))
		zombie.humanoid:MoveTo(zombie.home + wander)
	end
end

function LabService.Start()
	build()
	-- Los que no han pasado la ola 25 no pueden entrar: los saca a la entrada
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, player in Players:GetPlayers() do
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root and insideLab(root.Position) and not canEnter(player) then
					player.Character:PivotTo(origin * CFrame.new(-half - 12, 4, 0) * CFrame.Angles(0, math.rad(-90), 0))
					notice:FireClient(player, string.format("Solo entra quien ya pasó la ola %d", Lab.minRecord), "bad")
				elseif root and insideBuilding(root.Position) and (player:GetAttribute("LabCards") or 0) < Lab.cards.count then
					-- La puerta láser: sin todas las tarjetas, te regresa
					player.Character:PivotTo(CFrame.new(exitSpot) * CFrame.Angles(0, math.rad(90), 0))
					local text = string.format(
						"La puerta láser necesita %d tarjetas (tienes %d): búscalas en los callejones del laberinto",
						Lab.cards.count,
						player:GetAttribute("LabCards") or 0
					)
					notice:FireClient(player, text, "bad")
				end
			end
		end
	end)
	-- Los zombis: piensan cada 0.3 s y salen otros hasta llegar a Lab.zombies.alive
	task.spawn(function()
		local lastSpawn = 0
		while true do
			task.wait(0.3)
			local now = os.clock()
			for i = #zombies, 1, -1 do
				local zombie = zombies[i]
				if zombie.model.Parent == nil or zombie.humanoid.Health <= 0 then
					table.remove(zombies, i)
				else
					local ok, err = pcall(think, zombie, now)
					if not ok then
						warn("[Laboratorio] Error:", err)
					end
				end
			end
			-- Con la alarma salen más, y más seguido
			local alarm = now < alarmUntil
			local cap = Lab.zombies.alive + (if alarm then Lab.alarm.extra else 0)
			local every = if alarm then 0.4 else Lab.zombies.respawn
			if #zombies < cap and now - lastSpawn >= every then
				lastSpawn = now
				spawnZombie()
			end
			-- El guardián vuelve a salir un rato después de que lo matan
			if (not guardian or guardian.humanoid.Health <= 0) and now - guardianDiedAt >= Lab.guardian.respawn then
				guardianDiedAt = now -- (por si no se pudo crear: lo intenta otra vez después)
				spawnGuardian()
				if guardian then
					table.insert(zombies, guardian)
				end
			end
			-- Las luces rojas parpadean con la alarma
			for _, light in alarmLamps do
				light.Brightness = if alarm and math.floor(now * 3) % 2 == 0 then 4 else 1.5
			end
		end
	end)
end

return LabService
