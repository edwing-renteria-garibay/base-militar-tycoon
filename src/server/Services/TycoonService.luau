-- El corazón del juego: la caja fuerte, los botones de compra y lo que hace cada construcción.
--
-- 1. La caja fuerte está en el centro del terreno. Cada segundo junta dinero según su nivel
--    (Waves.vaultIncome) y al pisar su botón verde ese dinero pasa a tu cuenta.
-- 2. Cada cosa de Config/Buildings tiene su lugar marcado con un botón. Al pisarlo con dinero
--    suficiente se compra: el botón se va y la construcción aparece con una animación. Lo de
--    afuera del muro tiene su botón adentro, junto al muro.
-- 3. Lo que hace cada cosa ("effect"):
--      vault, wall          mejoran la caja fuerte o el muro (WallService)
--      barricade            se rompe y se repara como el muro
--      mine                 se gasta al explotar (WaveService) y su botón vuelve a salir
--      fire                 la gasolinera tiene un letrero para encender las zanjas
--      armory               la armería tiene un letrero que abre su tienda (WeaponService)
--      heal                 la enfermería te cura si estás cerca
--      damage               el laboratorio sube el daño de todo (Waves.labBonus)
--      repair               el taller repara el muro solo, poco a poco
--      radar                los zombis se ven a través de las paredes (WaveService)
--    Las torres y torretas ("defense") las hace disparar WaveService.
-- 4. Mantén E junto a la caja fuerte para reparar el muro y las barricadas con dinero.
--
-- Solo el dueño del terreno puede usar sus botones y letreros.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Buildings = require(ReplicatedStorage.Shared.Config.Buildings)
local Store = require(ReplicatedStorage.Shared.Config.Store)
local Waves = require(ReplicatedStorage.Shared.Config.Waves)
local Format = require(ReplicatedStorage.Shared.Format)
local Builder = require(script.Parent.Parent.Builder)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local WallService = require(script.Parent.WallService)

local notice = ReplicatedStorage.Remotes.Notice :: RemoteEvent
local armoryRemote = ReplicatedStorage.Remotes.Armory :: RemoteEvent

local AFFORD = Color3.fromRGB(60, 200, 90) -- botón: te alcanza
local TOO_EXPENSIVE = Color3.fromRGB(170, 60, 60) -- botón: todavía no te alcanza
local BUILD_TIME = 0.6 -- segundos que tarda la animación al construir

local TycoonService = {}

type Button = { part: BasePart, item: any }
type State = {
	owner: Player,
	plot: PlotService.Plot,
	buttons: { [string]: Button },
	vaultText: TextLabel,
	vaultHealth: number,
	repairPrompt: ProximityPrompt,
	firePrompt: ProximityPrompt?,
	fireUntil: number, -- os.clock() hasta el que arden las zanjas
	fireReady: number, -- os.clock() desde el que se pueden volver a encender
}

local states: { [Player]: State } = {}
local lastWarning: { [Player]: number } = {} -- para no repetir "te falta dinero" a cada paso
local lastCollect: { [Player]: number } = {}

local function placeOf(plot: PlotService.Plot, spot: { number }, rot: number?): CFrame
	return plot.cframe * CFrame.new(spot[1], 0, spot[2]) * CFrame.Angles(0, math.rad(rot or 0), 0)
end

-- El dinero por segundo que junta la caja fuerte, con los pases del jugador (los pone
-- StoreService como atributos: "Pass_x2", "Pass_VIP"...)
local function incomeOf(player: Player, profile: DataService.Profile): number
	local level = Buildings.LevelOf(profile.owned, "vault")
	local multiplier = 1
	if player:GetAttribute("Pass_x2") then
		multiplier *= 2
	end
	if player:GetAttribute("Pass_VIP") then
		multiplier *= 1 + Store.vipBonus
	end
	return math.floor(Waves.vaultIncome[level] * multiplier)
end

local function hasEffect(profile: DataService.Profile, effect: string): boolean
	for id in profile.owned do
		local item = Buildings.byId[id]
		if item and item.effect == effect then
			return true
		end
	end
	return false
end

-- Un letrero que se activa manteniendo E (o tocándolo en celular). Solo lo puede usar el dueño
local function prompt(parent: Instance, action: string, owner: Player, hold: number, onUse: () -> ()): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.HoldDuration = hold
	p.MaxActivationDistance = 18
	p.RequiresLineOfSight = false
	p.Triggered:Connect(function(who)
		if who == owner then
			onUse()
		end
	end)
	p.Parent = parent
	return p
end

-- Una pieza invisible donde poner un letrero (los modelos no tienen una pieza "principal")
local function promptSpot(model: Model, cframe: CFrame): BasePart
	local spot = Instance.new("Part")
	spot.Name = "Letrero"
	spot.Anchored = true
	spot.CanCollide = false
	spot.CanQuery = false
	spot.Transparency = 1
	spot.Size = Vector3.new(1, 1, 1)
	spot.CFrame = cframe
	spot.Parent = model
	return spot
end

local function isAvailable(profile: DataService.Profile, item): boolean
	return not profile.owned[item.id] and (item.requires == nil or profile.owned[item.requires] == true)
end

-- Si el jugador está parado donde va a salir la construcción, lo mueve enfrente de ella
-- (si no, las piezas lo empujan y lo tiran)
local function moveOutOfTheWay(player: Player, model: Model)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not root then
		return
	end
	local box, size = model:GetBoundingBox()
	local here = box:PointToObjectSpace(root.Position)
	local margin = 2
	if math.abs(here.X) < size.X / 2 + margin and math.abs(here.Z) < size.Z / 2 + margin then
		local front = box * CFrame.new(here.X, 0, -size.Z / 2 - 5)
		local spot = Vector3.new(front.Position.X, root.Position.Y, front.Position.Z)
		character:PivotTo(CFrame.lookAt(spot, Vector3.new(box.Position.X, spot.Y, box.Position.Z)))
	end
end

local ignite: (Player) -> ()

-- Pone una construcción en el terreno. Con animate, las piezas bajan del cielo y aparecen
local function build(state: State, item, animate: boolean)
	if not item.kind then
		return -- es una mejora: no se dibuja
	end
	local player = state.owner
	local o = placeOf(state.plot, item.at, item.rot)
	local model = Builder.Build(item.kind, o)
	model.Name = item.id
	if item.effect == "barricade" then
		WallService.Add(player, model, Waves.barricadeHealth) -- la pone en "Rompibles"
	else
		model.Parent = state.plot.contents
	end

	if item.effect == "armory" then
		local spot = promptSpot(model, o * CFrame.new(0, 3, -8))
		prompt(spot, "Abrir armería", player, 0, function()
			armoryRemote:FireClient(player, "open")
		end)
	elseif item.kind == "GasStation" then
		local spot = promptSpot(model, o * CFrame.new(0, 3, -3))
		state.firePrompt = prompt(spot, "Encender zanjas", player, 0.5, function()
			ignite(player)
		end)
	end

	if animate then
		-- Solo si su botón estaba en el mismo lugar (lo de afuera del muro lo tiene aparte)
		if item.button == nil then
			moveOutOfTheWay(player, model)
		end
		for _, piece in model:GetDescendants() do
			if piece:IsA("BasePart") and piece.Name ~= "Letrero" and piece.Name ~= "Llama" then
				local target = piece.CFrame
				local transparency = piece.Transparency
				local collides = piece.CanCollide
				piece.CFrame = target + Vector3.new(0, 6, 0)
				piece.Transparency = 1
				piece.CanCollide = false -- mientras baja no empuja a nadie
				local info = TweenInfo.new(BUILD_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
				local tween = TweenService:Create(piece, info, { CFrame = target, Transparency = transparency })
				tween.Completed:Connect(function()
					piece.CanCollide = collides
				end)
				tween:Play()
			end
		end
	end
end

local refreshButtons: (Player) -> ()

local function buy(player: Player, item)
	local state = states[player]
	local profile = DataService.Get(player)
	if not state or not profile or not isAvailable(profile, item) then
		return
	end
	if not DataService.Spend(player, item.price) then
		local now = os.clock()
		if now - (lastWarning[player] or 0) > 2 then
			lastWarning[player] = now
			local missing = item.price - profile.money
			notice:FireClient(player, string.format("Te faltan %s", Format.Money(missing)), "bad")
		end
		return
	end
	profile.owned[item.id] = true
	local button = state.buttons[item.id]
	if button then
		button.part:Destroy()
		state.buttons[item.id] = nil
	end
	build(state, item, true)
	if item.effect == "wall" then
		WallService.SetLevel(player, Buildings.LevelOf(profile.owned, "wall"))
	end
	player:SetAttribute("Income", incomeOf(player, profile))
	notice:FireClient(player, string.format("Construiste: %s", item.name), "good")
	refreshButtons(player)
end

local function makeButton(player: Player, state: State, item)
	local spot = item.button or item.at
	local text = string.format("%s\n%s", item.name, Format.Money(item.price))
	local part = Builder.Button(placeOf(state.plot, spot), text)
	part.Touched:Connect(function(hit)
		local character = hit.Parent
		if character and Players:GetPlayerFromCharacter(character) == player then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				buy(player, item)
			end
		end
	end)
	part.Parent = state.plot.contents
	state.buttons[item.id] = { part = part, item = item }
end

-- Crea los botones que faltan y los pinta verde (te alcanza) o rojo (todavía no)
refreshButtons = function(player: Player)
	local state = states[player]
	local profile = DataService.Get(player)
	if not state or not profile then
		return
	end
	for _, item in Buildings.list do
		if isAvailable(profile, item) and not state.buttons[item.id] then
			makeButton(player, state, item)
		end
	end
	for _, button in state.buttons do
		button.part.Color = if profile.money >= button.item.price then AFFORD else TOO_EXPENSIVE
	end
end

local function collect(player: Player)
	local profile = DataService.Get(player)
	local state = states[player]
	if not profile or not state or profile.vault < 1 then
		return
	end
	local now = os.clock()
	if now - (lastCollect[player] or 0) < 0.5 then
		return
	end
	lastCollect[player] = now
	local amount = math.floor(profile.vault)
	profile.vault -= amount
	DataService.AddMoney(player, amount)
	state.vaultText.Text = Format.Money(profile.vault)
	notice:FireClient(player, "+" .. Format.Money(amount), "money")
end

-- Repara el muro y las barricadas con dinero: todo lo que alcance
local function repair(player: Player)
	local profile = DataService.Get(player)
	local missing = WallService.Missing(player)
	if not profile or missing < 1 then
		notice:FireClient(player, "Tus defensas están como nuevas", "good")
		return
	end
	local affordable = math.floor(profile.money / Waves.repairCost)
	if affordable < 1 then
		notice:FireClient(player, "No tienes dinero para reparar", "bad")
		return
	end
	local used = WallService.Repair(player, math.min(missing, affordable))
	local cost = math.ceil(used * Waves.repairCost)
	DataService.Spend(player, math.min(cost, profile.money))
	notice:FireClient(player, string.format("Reparaste tus defensas: -%s", Format.Money(cost)), "good")
end

local function vaultHealthChanged(state: State)
	state.owner:SetAttribute("VaultHealth", math.ceil(state.vaultHealth))
	state.owner:SetAttribute("VaultMax", Waves.vaultHealth)
end

-- Enciende todas las zanjas de gasolina un rato (Waves.fire)
ignite = function(player: Player)
	local state = states[player]
	local profile = DataService.Get(player)
	if not state or not profile then
		return
	end
	local now = os.clock()
	if now < state.fireReady then
		local text = string.format("La gasolina se recarga en %d s", math.ceil(state.fireReady - now))
		notice:FireClient(player, text, "bad")
		return
	end
	local trenches = {}
	for _, item in Buildings.list do
		if item.kind == "FireTrench" and profile.owned[item.id] then
			local model = state.plot.contents:FindFirstChild(item.id)
			if model then
				table.insert(trenches, model)
			end
		end
	end
	if #trenches == 0 then
		notice:FireClient(player, "Primero compra zanjas de gasolina (botones junto al muro)", "bad")
		return
	end
	state.fireUntil = now + Waves.fire.duration
	state.fireReady = now + Waves.fire.cooldown
	for _, model in trenches do
		for _, flame in model:GetChildren() do
			if flame.Name == "Llama" then
				local fire = Instance.new("Fire")
				fire.Size = 9
				fire.Heat = 12
				fire.Parent = flame
				local glow = Instance.new("PointLight")
				glow.Color = Color3.fromRGB(255, 140, 50)
				glow.Range = 14
				glow.Parent = flame
				Debris:AddItem(fire, Waves.fire.duration)
				Debris:AddItem(glow, Waves.fire.duration)
			end
		end
	end
	notice:FireClient(player, "¡Zanjas encendidas!", "great")
end

-- La enfermería cura al dueño si está cerca
local function heal(state: State)
	local character = state.owner.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local infirmary = state.plot.contents:FindFirstChild("Enfermeria")
	if not root or not humanoid or humanoid.Health <= 0 or not infirmary or not infirmary:IsA("Model") then
		return
	end
	if (root.Position - infirmary:GetPivot().Position).Magnitude < Waves.healRange then
		humanoid.Health = math.min(humanoid.Health + Waves.heal, humanoid.MaxHealth)
	end
end

-- Prepara el terreno de un jugador que acaba de llegar: caja fuerte, muro, lo que ya había
-- construido (sin animación) y los botones
function TycoonService.Setup(player: Player, plot: PlotService.Plot)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local vault, pad, vaultText = Builder.Vault(plot.cframe)
	vault.Parent = plot.contents
	pad.Touched:Connect(function(hit)
		if hit.Parent and Players:GetPlayerFromCharacter(hit.Parent) == player then
			collect(player)
		end
	end)
	local body = (vaultText.Parent :: Instance).Parent :: BasePart -- el texto está en un letrero del cuerpo
	local repairPrompt = prompt(body, "Reparar defensas", player, 0.5, function()
		repair(player)
	end)
	local state: State = {
		owner = player,
		plot = plot,
		buttons = {},
		vaultText = vaultText,
		vaultHealth = Waves.vaultHealth,
		repairPrompt = repairPrompt,
		fireUntil = 0,
		fireReady = 0,
	}
	states[player] = state
	WallService.Setup(player, plot, Buildings.LevelOf(profile.owned, "wall"))
	for _, item in Buildings.list do
		if profile.owned[item.id] then
			build(state, item, false)
		end
	end
	vaultText.Text = Format.Money(profile.vault)
	vaultHealthChanged(state)
	player:SetAttribute("Income", incomeOf(player, profile))
	refreshButtons(player)
end

-- Para las olas y la tienda ----------------------------------------------------------------

-- Lo que junta por segundo la caja fuerte de un jugador (0 si no tiene terreno)
function TycoonService.IncomeOf(player: Player): number
	local profile = DataService.Get(player)
	return if profile then incomeOf(player, profile) else 0
end

-- El terreno de un jugador (nil si todavía no tiene)
function TycoonService.GetPlot(player: Player): PlotService.Plot?
	local state = states[player]
	return state and state.plot
end

-- ¿Tiene algo con este effect? ("radar", "repair"...)
function TycoonService.Has(player: Player, effect: string): boolean
	local profile = DataService.Get(player)
	return profile ~= nil and hasEffect(profile, effect)
end

-- ¿Están encendidas sus zanjas?
function TycoonService.FireActive(player: Player): boolean
	local state = states[player]
	return state ~= nil and os.clock() < state.fireUntil
end

-- Dónde está una cosa de Config/Buildings en el terreno del jugador
function TycoonService.PlaceOf(player: Player, item): CFrame?
	local state = states[player]
	return state and placeOf(state.plot, item.at, item.rot)
end

-- Se gastó algo de un solo uso (una mina): desaparece y su botón vuelve a salir
function TycoonService.Consume(player: Player, id: string)
	local state = states[player]
	local profile = DataService.Get(player)
	if not state or not profile then
		return
	end
	profile.owned[id] = nil
	local model = state.plot.contents:FindFirstChild(id)
	if model then
		model:Destroy()
	end
	refreshButtons(player)
end

-- Un zombi golpea la caja fuerte. Devuelve la vida que le queda
function TycoonService.DamageVault(player: Player, amount: number): number
	local state = states[player]
	if not state then
		return 0
	end
	state.vaultHealth = math.max(state.vaultHealth - amount, 0)
	vaultHealthChanged(state)
	return state.vaultHealth
end

-- Destruyeron la caja fuerte: se llevan una parte de lo que tenía y todo queda como nuevo
-- para volver a empezar. Devuelve cuánto se llevaron
function TycoonService.LoseVault(player: Player): number
	local state = states[player]
	local profile = DataService.Get(player)
	if not state or not profile then
		return 0
	end
	local lost = math.floor(profile.vault * Waves.lossShare)
	profile.vault -= lost
	state.vaultText.Text = Format.Money(profile.vault)
	state.vaultHealth = Waves.vaultHealth
	vaultHealthChanged(state)
	WallService.RepairAll(player)
	return lost
end

function TycoonService.Cleanup(player: Player)
	WallService.Cleanup(player)
	states[player] = nil
	lastWarning[player] = nil
	lastCollect[player] = nil
end

function TycoonService.Start()
	DataService.MoneyChanged.Event:Connect(refreshButtons)
	-- Cada segundo: la caja fuerte junta dinero, el taller repara y se actualizan los letreros
	task.spawn(function()
		while true do
			task.wait(1)
			for player, state in states do
				local profile = DataService.Get(player)
				if profile then
					local income = incomeOf(player, profile)
					player:SetAttribute("Income", income) -- por si compró un pase
					if player:GetAttribute("Pass_AutoCobrar") then
						DataService.AddMoney(player, income) -- con el pase, directo a su cuenta
					else
						profile.vault += income
					end
					state.vaultText.Text = Format.Money(profile.vault)
					if hasEffect(profile, "heal") then
						heal(state)
					end
					if hasEffect(profile, "repair") then
						WallService.RepairShare(player, Waves.workshopRepair)
					end
					local missing = WallService.Missing(player)
					state.repairPrompt.ObjectText = if missing >= 1
						then "Cuesta " .. Format.Money(math.ceil(missing * Waves.repairCost))
						else "Todo en buen estado"
					if state.firePrompt then
						local wait = state.fireReady - os.clock()
						state.firePrompt.ObjectText = if wait > 0
							then string.format("Recargando: %d s", math.ceil(wait))
							else "Lista"
					end
				end
			end
		end
	end)
end

return TycoonService
