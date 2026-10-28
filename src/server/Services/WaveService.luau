-- Las olas de zombis (Config/Waves). Cada jugador tiene las suyas, en su propio terreno.
--
-- 1. Al entrar empieza la cuenta regresiva (atributo "WaveIn"). Al llegar a 0 empieza la ola
--    que le toca (atributo "Wave"): aparecen zombis afuera del terreno, por uno o varios lados.
-- 2. Cada zombi camina derecho hacia el muro. Si algo le tapa el paso (un pedazo del muro o
--    una barricada, ver WallService) lo golpea hasta romperlo. Ya adentro, va por la caja
--    fuerte y la golpea. Si pasa junto a un jugador, también lo golpea.
-- 3. Las defensas: el alambre lo frena y lastima, las minas explotan cuando pasa cerca, las
--    zanjas encendidas lo queman, y las torres y torretas le disparan solas.
-- 4. Si eliminas a todos, pasas la ola: premio, récord y descanso hasta la siguiente. Si
--    destruyen tu caja fuerte, se llevan parte de su dinero y vuelves a la ola 1.
-- Mientras hay ola, el atributo "WaveEnemies" dice cuántos zombis quedan (lo lee el HUD).

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Buildings = require(ReplicatedStorage.Shared.Config.Buildings)
local Format = require(ReplicatedStorage.Shared.Format)
local Settings = require(ReplicatedStorage.Shared.Config.Settings)
local Waves = require(ReplicatedStorage.Shared.Config.Waves)
local Effects = require(script.Parent.Parent.Effects)
local DataService = require(script.Parent.DataService)
local TycoonService = require(script.Parent.TycoonService)
local WallService = require(script.Parent.WallService)

local notice = ReplicatedStorage.Remotes.Notice :: RemoteEvent

local TICK = 0.25 -- cada cuánto piensan los zombis
local testing = Settings.Testing.enabled
local FIRST_DELAY = if testing then Waves.testingFirstDelay else Waves.firstDelay
local BREAK_TIME = if testing then Waves.testingBreakTime else Waves.breakTime
local REACH = 4 -- qué tan lejos alcanza a golpear un zombi lo que tiene enfrente
local VAULT_REACH = 7 -- a esta distancia del centro ya está golpeando la caja fuerte
local WIRE_HALF = Vector2.new(8.5, 2.5) -- medio ancho y medio fondo del alambre (Builder.Wire)
local TRENCH_HALF = Vector2.new(30, 2.5) -- lo mismo para la zanja (Builder.FireTrench)

local WaveService = {}

type Zombie = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	side: CFrame, -- el lado por el que llegó: su frente (-Z) mira hacia afuera
	lane: number, -- su "carril": la x por la que camina derecho hacia el muro
	speed: number,
	lastHit: number,
	lastPosition: Vector3,
	stuckSince: number,
	detour: Vector3?,
	detourUntil: number,
}
type State = {
	nextWave: number, -- os.clock() en que empieza la siguiente ola
	zombies: { Zombie },
	active: boolean,
	spawning: boolean,
	waveId: number, -- cambia en cada ola, para que el que va saliendo sepa si ya acabó
	lastShot: { [string]: number }, -- última vez que disparó cada torre o torreta
}

local states: { [Player]: State } = {}
local template: Model? = nil -- el zombi, para clonarlo

local function getTemplate(): Model?
	if template then
		return template
	end
	local description = Instance.new("HumanoidDescription")
	local skin = Color3.fromRGB(110, 150, 90)
	local shirt = Color3.fromRGB(90, 80, 70)
	local pants = Color3.fromRGB(50, 55, 70)
	description.HeadColor = skin
	description.LeftArmColor = skin
	description.RightArmColor = skin
	description.TorsoColor = shirt
	description.LeftLegColor = pants
	description.RightLegColor = pants
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok then
		warn("[Olas] No se pudo crear el zombi:", model)
		return nil
	end
	model.Name = "Zombi"
	template = model
	return model
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function isAlive(zombie: Zombie): boolean
	return zombie.model.Parent ~= nil and zombie.humanoid.Health > 0
end

local function aliveCount(state: State): number
	local count = 0
	for _, zombie in state.zombies do
		if isAlive(zombie) then
			count += 1
		end
	end
	return count
end

local function spawnZombie(player: Player, state: State, side, n: number)
	local plot = TycoonService.GetPlot(player)
	local base = getTemplate()
	if not plot or not base then
		return
	end
	local sideFrame = plot.cframe * CFrame.Angles(0, math.rad(side.rot), 0)
	local lane = math.random(-Waves.spawnSpread, Waves.spawnSpread)
	local model = base:Clone()
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local speed = Waves.SpeedOf(n)
	humanoid.MaxHealth = Waves.HealthOf(n)
	humanoid.Health = humanoid.MaxHealth
	humanoid.WalkSpeed = speed
	humanoid.DisplayName = "Zombi"
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
	CollectionService:AddTag(model, "Enemy") -- así le hacen daño las armas del jugador
	-- Aparece afuera, mirando hacia la base
	model:PivotTo(sideFrame * CFrame.new(lane, 3, -Waves.spawnDistance) * CFrame.Angles(0, math.pi, 0))
	if TycoonService.Has(player, "radar") then
		local highlight = Instance.new("Highlight")
		highlight.FillColor = Color3.fromRGB(255, 60, 60)
		highlight.FillTransparency = 0.6
		highlight.OutlineColor = Color3.fromRGB(255, 60, 60)
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop -- se ve a través de las paredes
		highlight.Parent = model
	end
	model.Parent = plot.contents -- si el jugador sale, se borran con su terreno
	root:SetNetworkOwner(nil) -- los mueve el servidor
	local zombie: Zombie = {
		model = model,
		humanoid = humanoid,
		root = root,
		side = sideFrame,
		lane = lane,
		speed = speed,
		lastHit = 0,
		lastPosition = root.Position,
		stuckSince = os.clock(),
		detour = nil,
		detourUntil = 0,
	}
	table.insert(state.zombies, zombie)
	humanoid.Died:Connect(function()
		local reward = Waves.KillReward(n)
		DataService.AddMoney(player, reward)
		notice:FireClient(player, "Zombi eliminado: +" .. Format.Money(reward), "money")
		Debris:AddItem(model, 2)
	end)
end

-- Elige al azar por qué lados atacan: "el frente y la derecha"
local function pickSides(count: number)
	local sides = table.clone(Buildings.sides)
	for i = #sides, 2, -1 do
		local j = math.random(i)
		sides[i], sides[j] = sides[j], sides[i]
	end
	local chosen, names = {}, {}
	for i = 1, count do
		table.insert(chosen, sides[i])
		table.insert(names, "la " .. sides[i].name)
	end
	local text = names[1]
	if #names > 1 then
		text = table.concat(names, ", ", 1, #names - 1) .. " y " .. names[#names]
	end
	return chosen, (text:gsub("la frente", "el frente"):gsub("la atrás", "atrás"))
end

local function startWave(player: Player, state: State, n: number)
	local count = Waves.CountOf(n)
	local sides, sideText = pickSides(Waves.SidesOf(n))
	state.active = true
	state.spawning = true
	state.zombies = {}
	state.waveId += 1
	local waveId = state.waveId
	player:SetAttribute("WaveIn", nil)
	player:SetAttribute("WaveEnemies", count)
	notice:FireClient(player, string.format("¡Ola %d! %d zombis por %s", n, count, sideText), "bad")
	task.spawn(function()
		for i = 1, count do
			if states[player] ~= state or state.waveId ~= waveId then
				return -- el jugador se fue o perdió
			end
			spawnZombie(player, state, sides[(i - 1) % #sides + 1], n)
			task.wait(Waves.spawnEvery)
		end
		state.spawning = false
	end)
end

local function finishWave(player: Player, state: State, n: number)
	local profile = DataService.Get(player)
	state.active = false
	state.zombies = {}
	state.nextWave = os.clock() + BREAK_TIME
	player:SetAttribute("WaveEnemies", nil)
	local newRecord = profile ~= nil and n > profile.record
	local reward = Waves.WaveReward(n)
	DataService.AddMoney(player, reward)
	DataService.WaveCleared(player, n)
	notice:FireClient(player, string.format("¡Pasaste la ola %d! +%s", n, Format.Money(reward)), "great")
	if newRecord then
		notice:FireClient(player, string.format("¡Nuevo récord: ola %d!", n), "great")
	end
end

-- Destruyeron la caja fuerte: se acaba la ola y vuelve a la 1
local function defeat(player: Player, state: State)
	state.active = false
	state.spawning = false
	state.waveId += 1 -- deja de salir el resto de la ola
	for _, zombie in state.zombies do
		zombie.model:Destroy()
	end
	state.zombies = {}
	state.nextWave = os.clock() + BREAK_TIME
	player:SetAttribute("WaveEnemies", nil)
	DataService.ResetWave(player)
	local lost = TycoonService.LoseVault(player)
	local text = string.format("¡Los zombis destruyeron tu caja fuerte y se llevaron %s! Vuelves a la ola 1", Format.Money(lost))
	notice:FireClient(player, text, "bad")
end

-- Lo que el jugador tiene construido afuera del muro, ya con su lugar en el mundo
type Traps = { wires: { CFrame }, trenches: { CFrame }, mines: { { id: string, position: Vector3 } } }

local function trapsOf(player: Player): Traps
	local traps: Traps = { wires = {}, trenches = {}, mines = {} }
	local profile = DataService.Get(player)
	if not profile then
		return traps
	end
	for id in profile.owned do
		local item = Buildings.byId[id]
		local place = item and TycoonService.PlaceOf(player, item)
		if place then
			if item.effect == "wire" then
				table.insert(traps.wires, place)
			elseif item.kind == "FireTrench" then
				table.insert(traps.trenches, place)
			elseif item.effect == "mine" then
				table.insert(traps.mines, { id = id, position = place.Position })
			end
		end
	end
	return traps
end

local function inside(place: CFrame, half: Vector2, position: Vector3): boolean
	local here = place:PointToObjectSpace(position)
	return math.abs(here.X) <= half.X and math.abs(here.Z) <= half.Y
end

-- ¿Qué tiene enfrente que pueda romper? Tres rayos: al centro y a los lados
local function blockerAhead(zombie: Zombie, direction: Vector3, params: RaycastParams): Instance?
	local position = zombie.root.Position
	local across = Vector3.new(-direction.Z, 0, direction.X)
	for _, offset in { 0, 1.2, -1.2 } do
		local from = position - direction + across * offset
		local result = workspace:Raycast(from, direction * (REACH + 1), params)
		if result then
			local target = WallService.TargetOf(result.Instance)
			if target then
				return target
			end
		end
	end
	return nil
end

-- Golpea a un jugador que esté junto a él (uno por segundo)
local function hitPlayers(zombie: Zombie, now: number): boolean
	if now - zombie.lastHit < 1 then
		return false
	end
	for _, other in Players:GetPlayers() do
		local character = other.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 and (root.Position - zombie.root.Position).Magnitude < REACH + 1 then
			zombie.lastHit = now
			humanoid:TakeDamage(Waves.playerHit)
			return true
		end
	end
	return false
end

-- Un zombi piensa: ¿a quién golpeo?, si no, ¿hacia dónde camino?
-- Devuelve true si destruyó la caja fuerte
local function think(player: Player, zombie: Zombie, center: Vector3, params: RaycastParams, now: number): boolean
	local position = zombie.root.Position
	if hitPlayers(zombie, now) then
		return false
	end
	-- Ya llegó a la caja fuerte
	if flat(position - center).Magnitude < VAULT_REACH then
		zombie.humanoid:MoveTo(position)
		return TycoonService.DamageVault(player, Waves.zombieDps * TICK) <= 0
	end
	-- Afuera del muro camina derecho por su carril; ya adentro, va a la caja fuerte
	local here = zombie.side:PointToObjectSpace(position)
	local inset = Waves.wallInset
	local goal = if here.Z < -(inset - 6)
		then (zombie.side * CFrame.new(zombie.lane, 0, -(inset - 10))).Position
		else center
	local direction = flat(goal - position)
	if direction.Magnitude < 0.1 then
		return false
	end
	direction = direction.Unit
	local blocker = blockerAhead(zombie, direction, params)
	if blocker then
		zombie.humanoid:MoveTo(position)
		WallService.Damage(blocker, Waves.zombieDps * TICK)
		zombie.stuckSince = now
		return false
	end
	-- Si lleva rato atorado en algo que no se rompe (un edificio), lo rodea
	if (position - zombie.lastPosition).Magnitude > 1 then
		zombie.lastPosition = position
		zombie.stuckSince = now
	elseif now - zombie.stuckSince > 2 and now > zombie.detourUntil then
		local across = Vector3.new(-direction.Z, 0, direction.X) * (if math.random() < 0.5 then 10 else -10)
		zombie.detour = position + across - direction * 4
		zombie.detourUntil = now + 1.5
		zombie.stuckSince = now
	end
	if zombie.detour and now < zombie.detourUntil then
		zombie.humanoid:MoveTo(zombie.detour)
	else
		zombie.humanoid:MoveTo(goal)
	end
	return false
end

-- Alambre, zanjas y minas
local function applyTraps(player: Player, state: State, traps: Traps, bonus: number)
	local burning = TycoonService.FireActive(player)
	for _, zombie in state.zombies do
		if isAlive(zombie) then
			local position = zombie.root.Position
			local slowed = false
			for _, wire in traps.wires do
				if inside(wire, WIRE_HALF, position) then
					slowed = true
				end
			end
			zombie.humanoid.WalkSpeed = if slowed then zombie.speed * Waves.wire.slow else zombie.speed
			if slowed then
				zombie.humanoid:TakeDamage(Waves.wire.dps * TICK * bonus)
			end
			if burning then
				for _, trench in traps.trenches do
					if inside(trench, TRENCH_HALF, position) then
						zombie.humanoid:TakeDamage(Waves.fire.dps * TICK * bonus)
						break
					end
				end
			end
		end
	end
	for _, mine in traps.mines do
		local triggered = false
		for _, zombie in state.zombies do
			if isAlive(zombie) and flat(zombie.root.Position - mine.position).Magnitude < Waves.mine.trigger then
				triggered = true
				break
			end
		end
		if triggered then
			Effects.Explosion(mine.position, Waves.mine.radius)
			for _, zombie in state.zombies do
				if isAlive(zombie) and (zombie.root.Position - mine.position).Magnitude < Waves.mine.radius then
					zombie.humanoid:TakeDamage(Waves.mine.damage * bonus)
				end
			end
			TycoonService.Consume(player, mine.id)
		end
	end
end

-- ¿Lo ve la torreta? Solo dispara hacia su frente, dentro de Waves.turretArc grados
local function inSight(facing: Vector3, from: Vector3, target: Vector3): boolean
	local direction = flat(target - from)
	if direction.Magnitude < 0.1 then
		return true
	end
	local cosine = flat(facing).Unit:Dot(direction.Unit)
	return cosine >= math.cos(math.rad(Waves.turretArc / 2))
end

-- Las torres y torretas disparan al zombi vivo más cercano dentro de su alcance (las torretas,
-- solo si lo tienen enfrente)
local function defend(player: Player, state: State, now: number, bonus: number)
	local plot = TycoonService.GetPlot(player)
	local profile = DataService.Get(player)
	if not plot or not profile then
		return
	end
	for id in profile.owned do
		local item = Buildings.byId[id]
		local stats = item and item.defense
		local building = stats and plot.contents:FindFirstChild(id)
		if building and building:IsA("Model") and now - (state.lastShot[id] or 0) >= stats.cooldown then
			local box, size = building:GetBoundingBox()
			local from = box.Position + Vector3.new(0, size.Y / 2 - 1.5, 0) -- desde arriba
			local facing = if item.kind == "Turret" then (TycoonService.PlaceOf(player, item) :: CFrame).LookVector else nil
			local best: Zombie? = nil
			local bestDistance = stats.range
			for _, zombie in state.zombies do
				if isAlive(zombie) and (not facing or inSight(facing, from, zombie.root.Position)) then
					local distance = (zombie.root.Position - from).Magnitude
					if distance < bestDistance then
						best = zombie
						bestDistance = distance
					end
				end
			end
			if best then
				state.lastShot[id] = now
				local target = best.root.Position
				-- La torreta gira su cabeza hacia el zombi
				local head = building:FindFirstChild("Cabeza")
				if head and head:IsA("Model") then
					local pivot = head:GetPivot().Position
					head:PivotTo(CFrame.lookAt(pivot, Vector3.new(target.X, pivot.Y, target.Z)))
					local muzzle = head:GetPivot() * CFrame.new(0, 0.2, -8)
					from = muzzle.Position
				end
				Effects.Shot(from, target, stats.sound, "flesh")
				best.humanoid:TakeDamage(stats.damage * bonus)
			end
		end
	end
end

local function tick(player: Player, state: State)
	local profile = DataService.Get(player)
	local plot = TycoonService.GetPlot(player)
	local folder = WallService.Folder(player)
	if not profile or not plot or not folder then
		player:SetAttribute("WaveIn", nil)
		state.nextWave = os.clock() + FIRST_DELAY -- la cuenta empieza cuando ya tiene terreno
		return
	end
	local n = profile.wave
	player:SetAttribute("Wave", n)
	local now = os.clock()
	if not state.active then
		local remaining = state.nextWave - now
		if remaining <= 0 then
			startWave(player, state, n)
		else
			player:SetAttribute("WaveIn", math.ceil(remaining))
		end
		return
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { folder }
	local center = plot.cframe.Position
	for _, zombie in state.zombies do
		if isAlive(zombie) and think(player, zombie, center, params, now) then
			defeat(player, state)
			return
		end
	end
	local bonus = Waves.labBonus[Buildings.LevelOf(profile.owned, "damage")] or 1
	applyTraps(player, state, trapsOf(player), bonus)
	defend(player, state, now, bonus)

	local alive = aliveCount(state)
	player:SetAttribute("WaveEnemies", if state.spawning then math.max(alive, 1) else alive)
	if not state.spawning and alive == 0 then
		finishWave(player, state, n)
	end
end

function WaveService.Start()
	local function onPlayer(player: Player)
		states[player] = {
			nextWave = os.clock() + FIRST_DELAY,
			zombies = {},
			active = false,
			spawning = false,
			waveId = 0,
			lastShot = {},
		}
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(TICK)
			for player, state in states do
				local ok, err = pcall(tick, player, state)
				if not ok then
					warn("[Olas] Error:", err)
				end
			end
		end
	end)
end

return WaveService
