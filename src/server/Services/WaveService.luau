-- Las olas de enemigos (Config/Waves). Cada jugador tiene las suyas, en su propio terreno.
--
-- 1. Cuando ya tiene Waves.startAfter, empieza la cuenta regresiva (atributo "WaveIn").
-- 2. Al llegar a 0, aparecen enemigos en la calle, frente a su base, uno tras otro. Caminan
--    hasta el portón y luego a la caja fuerte. El que llega se roba una parte del dinero de la
--    caja (Waves.stealShare) y se va.
-- 3. El jugador los elimina con su rifle (WeaponService) y sus construcciones de defensa
--    (Waves.defenders) les disparan solas. Cada baja da un premio, y eliminar a toda la ola da
--    uno más grande.
-- Mientras hay ola, el atributo "WaveEnemies" dice cuántos enemigos quedan (lo lee el HUD).

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local Settings = require(ReplicatedStorage.Shared.Config.Settings)
local Waves = require(ReplicatedStorage.Shared.Config.Waves)
local Effects = require(script.Parent.Parent.Effects)
local DataService = require(script.Parent.DataService)
local TycoonService = require(script.Parent.TycoonService)

local notice = ReplicatedStorage.Remotes.Notice :: RemoteEvent

-- El camino de los enemigos dentro del terreno (x, z): la calle, el portón y la caja fuerte
local PATH = { { 0, -80 }, { 0, -60 }, { -45, -54 } }
local SPAWN_SPREAD = 14 -- aparecen repartidos a lo ancho de la calle
-- En modo de prueba las olas llegan cada 30 segundos, para no esperar
local INTERVAL = if Settings.Testing.enabled then 30 else Waves.interval

local WaveService = {}

-- killed: ya no cuenta como vivo · stole: llegó a la caja fuerte (no da premio)
type Enemy = { model: Model, humanoid: Humanoid, killed: boolean, stole: boolean }
type State = {
	nextWave: number, -- os.clock() en que empieza la siguiente ola
	enemies: { Enemy },
	active: boolean,
	spawning: boolean,
	lastDefense: number,
}

local states: { [Player]: State } = {}
local template: Model? = nil -- el soldado enemigo, para clonarlo

-- Premio en "segundos de lo que genera tu base"
local function rewardOf(player: Player, seconds: number): number
	return math.max(Waves.minimumReward, TycoonService.IncomeOf(player) * seconds)
end

local function getTemplate(): Model?
	if template then
		return template
	end
	local description = Instance.new("HumanoidDescription")
	local skin = Color3.fromRGB(204, 160, 120)
	local uniform = Color3.fromRGB(120, 40, 36)
	local pants = Color3.fromRGB(45, 40, 38)
	description.HeadColor = skin
	description.TorsoColor = uniform
	description.LeftArmColor = uniform
	description.RightArmColor = uniform
	description.LeftLegColor = pants
	description.RightLegColor = pants
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok then
		warn("[Olas] No se pudo crear el soldado enemigo:", model)
		return nil
	end
	model.Name = "Enemigo"
	-- Casco rojo para que se distingan de lejos
	local head = model:FindFirstChild("Head") :: BasePart?
	if head then
		local helmet = Instance.new("Part")
		helmet.Name = "Casco"
		helmet.Shape = Enum.PartType.Ball
		helmet.Size = Vector3.new(1.5, 1.5, 1.5)
		helmet.Color = Color3.fromRGB(150, 30, 30)
		helmet.Material = Enum.Material.Metal
		helmet.CanCollide = false
		helmet.Massless = true
		helmet.CFrame = head.CFrame * CFrame.new(0, 0.35, 0)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = helmet
		weld.Parent = helmet
		helmet.Parent = model
	end
	template = model
	return model
end

local function aliveCount(state: State): number
	local count = 0
	for _, enemy in state.enemies do
		if not enemy.killed and enemy.model.Parent then
			count += 1
		end
	end
	return count
end

-- Un enemigo camina por PATH. Si llega a la caja fuerte, roba y desaparece
local function walk(player: Player, plot, enemy: Enemy)
	for _, spot in PATH do
		local goal = (plot.cframe * CFrame.new(spot[1], 0, spot[2])).Position
		local reached = false
		for _ = 1, 4 do -- MoveTo se rinde a los 8 segundos: se lo volvemos a pedir
			if enemy.killed or not enemy.model.Parent then
				return
			end
			enemy.humanoid:MoveTo(goal)
			reached = enemy.humanoid.MoveToFinished:Wait()
			if reached then
				break
			end
		end
	end
	if enemy.killed or not enemy.model.Parent then
		return
	end
	local stolen = TycoonService.Steal(player, Waves.stealShare)
	enemy.killed = true
	enemy.stole = true
	enemy.model:Destroy()
	notice:FireClient(player, string.format("¡Un enemigo se robó %s de tu caja fuerte!", Format.Money(stolen)), "bad")
end

local function spawnEnemy(player: Player, state: State, health: number, index: number)
	local plot = TycoonService.GetPlot(player)
	local base = getTemplate()
	if not plot or not base then
		return
	end
	local model = base:Clone()
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.MaxHealth = health
	humanoid.Health = health
	humanoid.WalkSpeed = Waves.enemySpeed
	humanoid.DisplayName = "Enemigo"
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
	CollectionService:AddTag(model, "Enemy")
	local offset = (index % 3 - 1) * SPAWN_SPREAD / 2
	model:PivotTo(plot.cframe * CFrame.new(offset, 3, -90))
	model.Parent = plot.contents -- si el jugador sale o renace, se borran con su terreno
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root:SetNetworkOwner(nil) -- los mueve el servidor
	end
	local enemy: Enemy = { model = model, humanoid = humanoid, killed = false, stole = false }
	table.insert(state.enemies, enemy)
	humanoid.Died:Connect(function()
		if enemy.killed then
			return
		end
		enemy.killed = true
		local reward = rewardOf(player, Waves.killSeconds)
		DataService.AddMoney(player, reward)
		notice:FireClient(player, "Enemigo eliminado: +" .. Format.Money(reward), "money")
		Debris:AddItem(model, 2)
	end)
	task.spawn(walk, player, plot, enemy)
end

local function startWave(player: Player, state: State)
	local stage = TycoonService.StageOf(player)
	local count = math.min(Waves.baseEnemies + math.max(stage - 1, 0), Waves.maxEnemies)
	local health = Waves.enemyHealth + math.max(stage - 1, 0) * Waves.healthPerStage
	state.active = true
	state.spawning = true
	state.enemies = {}
	player:SetAttribute("WaveIn", nil)
	player:SetAttribute("WaveEnemies", count)
	notice:FireClient(player, string.format("¡Ataque enemigo! %d soldados vienen por tu dinero", count), "bad")
	task.spawn(function()
		for i = 1, count do
			if states[player] ~= state then
				return -- el jugador se fue
			end
			spawnEnemy(player, state, health, i)
			task.wait(1.5)
		end
		state.spawning = false
	end)
end

local function finishWave(player: Player, state: State)
	-- Cuántos eliminó (los que robaron, o se borraron al renacer, no cuentan)
	local killed = 0
	for _, enemy in state.enemies do
		if not enemy.stole and enemy.humanoid.Health <= 0 then
			killed += 1
		end
	end
	local total = #state.enemies
	state.active = false
	state.enemies = {}
	state.nextWave = os.clock() + INTERVAL
	player:SetAttribute("WaveEnemies", nil)
	if total > 0 and killed == total then
		local reward = rewardOf(player, Waves.waveSeconds)
		DataService.AddMoney(player, reward)
		notice:FireClient(player, "¡Defendiste tu base! +" .. Format.Money(reward), "great")
	end
end

-- Las construcciones de defensa disparan al enemigo vivo más cercano dentro de su alcance
local function defend(player: Player, state: State)
	local plot = TycoonService.GetPlot(player)
	if not plot then
		return
	end
	for id, stats in Waves.defenders do
		local building = plot.contents:FindFirstChild(id)
		if building and building:IsA("Model") then
			local from = building:GetPivot().Position + Vector3.new(0, 8, 0)
			local best: Enemy? = nil
			local bestDistance = stats.range
			for _, enemy in state.enemies do
				local root = enemy.model:FindFirstChild("HumanoidRootPart") :: BasePart?
				if not enemy.killed and root and enemy.humanoid.Health > 0 then
					local distance = (root.Position - from).Magnitude
					if distance < bestDistance then
						best = enemy
						bestDistance = distance
					end
				end
			end
			if best then
				local root = best.model:FindFirstChild("HumanoidRootPart") :: BasePart
				Effects.Tracer(from, root.Position, Color3.fromRGB(255, 140, 60))
				best.humanoid:TakeDamage(stats.damage)
			end
		end
	end
end

local function tick(player: Player, state: State)
	local profile = DataService.Get(player)
	if not profile or not profile.owned[Waves.startAfter] or not TycoonService.GetPlot(player) then
		player:SetAttribute("WaveIn", nil)
		state.nextWave = os.clock() + INTERVAL -- la cuenta empieza cuando ya hay base
		return
	end
	if not state.active then
		local remaining = state.nextWave - os.clock()
		if remaining <= 0 then
			startWave(player, state)
		else
			player:SetAttribute("WaveIn", math.ceil(remaining))
		end
		return
	end
	local alive = aliveCount(state)
	player:SetAttribute("WaveEnemies", if state.spawning then math.max(alive, 1) else alive)
	if not state.spawning and alive == 0 then
		finishWave(player, state)
		return
	end
	if os.clock() - state.lastDefense >= Waves.defenderCooldown then
		state.lastDefense = os.clock()
		defend(player, state)
	end
end

function WaveService.Start()
	local function onPlayer(player: Player)
		states[player] = {
			nextWave = os.clock() + INTERVAL,
			enemies = {},
			active = false,
			spawning = false,
			lastDefense = 0,
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
			task.wait(0.5)
			for player, state in states do
				tick(player, state)
			end
		end
	end)
end

return WaveService
