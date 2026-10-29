-- Las olas de zombis (Config/Waves). Cada jugador tiene las suyas, en su propio terreno.
--
-- 1. Al entrar empieza la cuenta regresiva (atributo "WaveIn"). Al llegar a 0 empieza la ola
--    que le toca (atributo "Wave"): aparecen zombis afuera del terreno, por uno o varios lados.
-- 2. Cada zombi camina derecho hacia el muro. Si algo le tapa el paso (un pedazo del muro o
--    una barricada, ver WallService) lo golpea hasta romperlo. Ya adentro, va por la caja
--    fuerte y la golpea. Si pasa junto a un jugador, también lo golpea.
-- 3. Las defensas: el alambre lo frena y lastima, las minas explotan cuando pasa cerca, las
--    zanjas encendidas lo queman, las torretas le disparan solas (si lo tienen enfrente) y las
--    torres, si tienen francotirador.
-- 4. Zombis especiales (Waves.special): el trepador se salta el muro y sube a las torres por
--    el francotirador, el demoledor va por los edificios y el saboteador por torres y torretas.
-- 5. Si eliminas a todos, pasas la ola: premio, récord y descanso hasta la siguiente. Si
--    destruyen tu caja fuerte, se llevan parte de su dinero y vuelves a la ola 1.
-- Mientras hay ola, el atributo "WaveEnemies" dice cuántos zombis quedan (lo lee el HUD).

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Buildings = require(ReplicatedStorage.Shared.Config.Buildings)
local Format = require(ReplicatedStorage.Shared.Format)
local Settings = require(ReplicatedStorage.Shared.Config.Settings)
local Research = require(ReplicatedStorage.Shared.Config.Research)
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
	lastSwing: number, -- último golpe que se vio (el efecto sale uno por segundo)
	dps: number, -- su daño por segundo
	lastPosition: Vector3,
	stuckSince: number,
	detour: Vector3?,
	detourUntil: number,
	special: any, -- su tipo en Waves.special (nil = zombi normal)
	targetId: string?, -- la construcción a la que va (zombis especiales)
	climbing: boolean, -- trepando: lo mueve climb(), no piensa
	onTower: string?, -- el trepador ya está arriba de esta torre
	exploded: boolean, -- el explosivo ya explotó (no da premio)
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
local templates: { [string]: Model } = {} -- un zombi de cada tipo, para clonarlo

-- El zombi de cada tipo: piel verde, y la camisa y el tamaño de su tipo
local function getTemplate(special): Model?
	local key = if special then special.key else "Normal"
	if templates[key] then
		return templates[key]
	end
	local description = Instance.new("HumanoidDescription")
	local skin = Color3.fromRGB(110, 150, 90)
	local shirt = if special then special.shirt else Color3.fromRGB(90, 80, 70)
	local pants = Color3.fromRGB(50, 55, 70)
	description.HeadColor = skin
	description.LeftArmColor = skin
	description.RightArmColor = skin
	description.TorsoColor = shirt
	description.LeftLegColor = pants
	description.RightLegColor = pants
	local scale = if special then special.scale else 1
	description.HeightScale = scale
	description.WidthScale = scale
	description.DepthScale = scale
	description.HeadScale = scale
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok then
		warn("[Olas] No se pudo crear el zombi:", model)
		return nil
	end
	model.Name = "Zombi"
	-- El explosivo trae una bomba roja que brilla en el pecho
	local torso = model:FindFirstChild("UpperTorso") :: BasePart?
	if special and special.explode and torso then
		local bomb = Instance.new("Part")
		bomb.Name = "Bomba"
		bomb.Shape = Enum.PartType.Ball
		bomb.Size = Vector3.new(1.2, 1.2, 1.2)
		bomb.Color = Color3.fromRGB(255, 60, 40)
		bomb.Material = Enum.Material.Neon
		bomb.CanCollide = false
		bomb.Massless = true
		bomb.CFrame = torso.CFrame * CFrame.new(0, 0, -0.7)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = torso
		weld.Part1 = bomb
		weld.Parent = bomb
		bomb.Parent = model
		local glow = Instance.new("PointLight")
		glow.Color = bomb.Color
		glow.Range = 8
		glow.Parent = bomb
	end
	templates[key] = model
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

local function spawnZombie(player: Player, state: State, side, n: number, special)
	local plot = TycoonService.GetPlot(player)
	local base = getTemplate(special)
	if not plot or not base then
		return
	end
	local sideFrame = plot.cframe * CFrame.Angles(0, math.rad(side.rot), 0)
	local lane = math.random(-Waves.spawnSpread, Waves.spawnSpread)
	local model = base:Clone()
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local speed = Waves.SpeedOf(n) * (if special then special.speed else 1)
	humanoid.MaxHealth = Waves.HealthOf(n) * (if special then special.health else 1)
	humanoid.Health = humanoid.MaxHealth
	humanoid.WalkSpeed = speed
	humanoid.DisplayName = if special then "Zombi " .. special.name else "Zombi"
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
		lastSwing = 0,
		dps = Waves.DpsOf(n) * (if special then special.dps else 1),
		lastPosition = root.Position,
		stuckSince = os.clock(),
		detour = nil,
		detourUntil = 0,
		special = special,
		targetId = nil,
		climbing = false,
		onTower = nil,
		exploded = false,
	}
	table.insert(state.zombies, zombie)
	humanoid.Died:Connect(function()
		if zombie.exploded then
			Debris:AddItem(model, 0.5)
			return
		end
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

-- Qué tipo es el zombi número i de la ola n: uno de cada "every" es especial
local function specialOf(i: number, n: number)
	for _, special in Waves.special do
		if n >= special.from and i % special.every == 0 then
			return special
		end
	end
	return nil
end

local function startWave(player: Player, state: State, n: number)
	local count = Waves.CountOf(n)
	local sides, sideText = pickSides(Waves.SidesOf(n))
	-- No se avisa qué tipos de zombis vienen: hay que fijarse en quién te ataca
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
			spawnZombie(player, state, sides[(i - 1) % #sides + 1], n, specialOf(i, n))
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

-- Mueve a un zombi por varios puntos, sin física (así trepa muros y torres). Mientras, no
-- piensa. Al terminar, si stay es false, vuelve a caminar
local function climb(zombie: Zombie, path: { Vector3 }, stay: boolean)
	zombie.climbing = true
	zombie.root.Anchored = true
	task.spawn(function()
		local stepTime = Waves.climbTime / #path
		for _, point in path do
			local start = zombie.root.CFrame
			local look = flat(point - start.Position)
			local goal = if look.Magnitude > 0.1 then CFrame.lookAt(point, point + look) else start.Rotation + point
			for step = 1, 10 do
				if not isAlive(zombie) then
					return
				end
				zombie.model:PivotTo(start:Lerp(goal, step / 10))
				task.wait(stepTime / 10)
			end
		end
		zombie.climbing = false
		if not stay and isAlive(zombie) then
			zombie.root.Anchored = false
		end
	end)
end

-- La construcción a la que va un zombi especial (nil si ya no queda ninguna: va a la caja)
local function targetOf(player: Player, zombie: Zombie): Model?
	local special = zombie.special
	if not special or not special.target then
		return nil
	end
	if zombie.targetId and TycoonService.IsWorking(player, zombie.targetId) then
		return TycoonService.ModelOf(player, zombie.targetId)
	end
	local candidates = TycoonService.Targets(player, special.target)
	-- Los trepadores prefieren las torres que tienen francotirador
	if special.target == "tower" then
		local manned = {}
		for _, candidate in candidates do
			if TycoonService.SniperOf(player, candidate.id) then
				table.insert(manned, candidate)
			end
		end
		if #manned > 0 then
			candidates = manned
		end
	end
	local best, bestDistance = nil, math.huge
	for _, candidate in candidates do
		local distance = ((candidate.model:GetBoundingBox()).Position - zombie.root.Position).Magnitude
		if distance < bestDistance then
			best, bestDistance = candidate, distance
		end
	end
	zombie.targetId = best and best.id
	return best and best.model
end

-- ¿Ya está junto a la construcción? (según su tamaño)
local function reached(zombie: Zombie, target: Model): boolean
	local box, size = target:GetBoundingBox()
	return flat(box.Position - zombie.root.Position).Magnitude < math.max(size.X, size.Z) / 2 + REACH
end

-- El trepador arriba de una torre: golpea al francotirador y, sin él, a la torre
local function attackTower(player: Player, zombie: Zombie, damage: number)
	local id = zombie.onTower :: string
	local tower = TycoonService.ModelOf(player, id)
	if not tower or not TycoonService.IsWorking(player, id) then
		zombie.onTower = nil -- la torre se cayó: él también
		zombie.targetId = nil
		zombie.root.Anchored = false
		return
	end
	local sniper = TycoonService.SniperOf(player, id)
	local humanoid = sniper and sniper:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:TakeDamage(damage)
	else
		WallService.Damage(tower, damage)
	end
end

-- Se ve y se oye cuando un zombi golpea algo (uno por segundo)
local function swing(zombie: Zombie, point: Vector3, now: number)
	if now - zombie.lastSwing >= 1 then
		zombie.lastSwing = now
		Effects.Hit(point)
	end
end

-- ¿Hay un jugador junto a él?
local function nearPlayer(zombie: Zombie): boolean
	for _, other in Players:GetPlayers() do
		local root = other.Character and other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and (root.Position - zombie.root.Position).Magnitude < REACH + 1 then
			return true
		end
	end
	return false
end

-- El zombi explosivo explota: daña lo que se rompe, a los jugadores y a la caja fuerte que
-- estén cerca, y se muere. Devuelve true si destruyó la caja fuerte
local function explode(player: Player, zombie: Zombie, center: Vector3): boolean
	local blast = zombie.special.explode
	local position = zombie.root.Position
	zombie.exploded = true
	Effects.Explosion(position, blast.radius)
	local folder = WallService.Folder(player)
	if folder then
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { folder }
		local done = {}
		for _, piece in workspace:GetPartBoundsInRadius(position, blast.radius, params) do
			local target = WallService.TargetOf(piece)
			if target and not done[target] then
				done[target] = true
				WallService.Damage(target, blast.damage)
			end
		end
	end
	for _, other in Players:GetPlayers() do
		local root = other.Character and other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = other.Character and other.Character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and (root.Position - position).Magnitude < blast.radius then
			humanoid:TakeDamage(blast.playerDamage)
		end
	end
	zombie.humanoid.Health = 0
	if flat(position - center).Magnitude < blast.radius then
		return TycoonService.DamageVault(player, blast.damage) <= 0
	end
	return false
end

-- Un zombi piensa: ¿a quién golpeo?, si no, ¿hacia dónde camino?
-- Devuelve true si destruyó la caja fuerte
local function think(player: Player, zombie: Zombie, center: Vector3, params: RaycastParams, now: number): boolean
	if zombie.climbing then
		return false
	end
	local special = zombie.special
	local damage = zombie.dps * TICK
	if zombie.onTower then
		attackTower(player, zombie, damage)
		return false
	end
	local position = zombie.root.Position
	local explosive = special ~= nil and special.explode ~= nil
	if explosive and nearPlayer(zombie) then
		return explode(player, zombie, center)
	end
	if hitPlayers(zombie, now) then
		return false
	end
	local target = targetOf(player, zombie)
	-- Ya llegó a lo que busca: la caja fuerte o su construcción
	if not target and flat(position - center).Magnitude < VAULT_REACH then
		if explosive then
			return explode(player, zombie, center)
		end
		zombie.humanoid:MoveTo(position)
		swing(zombie, center + Vector3.new(0, 3, 0), now)
		return TycoonService.DamageVault(player, damage) <= 0
	end
	if target and reached(zombie, target) then
		zombie.humanoid:MoveTo(position)
		if special.target == "tower" then
			-- Sube por la torre hasta donde está el francotirador
			local top = (target:GetBoundingBox()).Position
			local away = flat(position - top)
			away = if away.Magnitude > 0.1 then away.Unit * 1.5 else Vector3.zero
			local platform = Vector3.new(top.X, position.Y + 24.5, top.Z) + away
			zombie.onTower = zombie.targetId
			climb(zombie, { position + Vector3.new(0, 24.5, 0), platform }, true)
		else
			swing(zombie, position + flat((target:GetBoundingBox()).Position - position).Unit * 2, now)
			WallService.Damage(target, damage)
		end
		return false
	end
	-- Afuera del muro camina derecho por su carril; ya adentro, va a lo que busca
	local here = zombie.side:PointToObjectSpace(position)
	local inset = Waves.wallInset
	local inside = if target then (target:GetBoundingBox()).Position else center
	local goal = if here.Z < -(inset - 6)
		then (zombie.side * CFrame.new(zombie.lane, 0, -(inset - 10))).Position
		else inside
	local direction = flat(goal - position)
	if direction.Magnitude < 0.1 then
		return false
	end
	direction = direction.Unit
	local blocker = blockerAhead(zombie, direction, params)
	if blocker and explosive then
		return explode(player, zombie, center)
	end
	if blocker then
		zombie.humanoid:MoveTo(position)
		zombie.stuckSince = now
		if special and special.target == "tower" and blocker.Name == "Muro" and blocker:IsA("BasePart") then
			-- El trepador no rompe el muro: se lo salta
			local height = Vector3.new(0, blocker.Size.Y, 0)
			climb(zombie, { position + height, position + height + direction * 6, position + direction * 6 }, false)
		else
			swing(zombie, position + direction * 2, now)
			WallService.Damage(blocker, damage)
		end
		return false
	end
	-- Si lleva rato atorado en algo que no se rompe, lo rodea
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
	for _, defender in TycoonService.Defenders(player) do
		local id, item, building = defender.id, defender.item, defender.model
		local stats = item.defense
		-- Las torres solo disparan con francotirador, y nada roto dispara
		local sniper = if item.kind == "SniperTower" then TycoonService.SniperOf(player, id) else nil
		local manned = item.kind ~= "SniperTower" or sniper ~= nil
		if
			manned
			and TycoonService.IsWorking(player, id)
			and now - (state.lastShot[id] or 0) >= stats.cooldown
		then
			local box, size = building:GetBoundingBox()
			local from = box.Position + Vector3.new(0, size.Y / 2 - 1.5, 0) -- desde arriba
			local sniperHead = sniper and sniper:FindFirstChild("Head") :: BasePart?
			if sniperHead then
				from = sniperHead.Position
			end
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
				if sniper then
					-- El francotirador voltea hacia el zombi
					local pivot = sniper:GetPivot().Position
					sniper:PivotTo(CFrame.lookAt(pivot, Vector3.new(target.X, pivot.Y, target.Z)))
					-- y la bala sale de la boca de su rifle
					local tip = sniper:FindFirstChild("Muzzle", true) :: Attachment?
					if tip then
						from = tip.WorldPosition
					end
				end
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
	-- Lo investigado en el Laboratorio (Config/Research)
	applyTraps(player, state, trapsOf(player), Research.Bonus(profile.research, "Explosivos"))
	defend(player, state, now, Research.Bonus(profile.research, "Torretas"))

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
