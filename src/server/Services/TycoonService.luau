-- El corazón del tycoon: los botones de compra, las construcciones y la caja fuerte.
--
-- 1. Cada segundo, la base de cada jugador genera dinero (la suma de "income" de lo que ha
--    construido) y lo deja en su caja fuerte.
-- 2. Al pisar el botón verde de la caja fuerte, ese dinero pasa a su cuenta.
-- 3. Al pisar el botón de una construcción con dinero suficiente, se compra: el botón se va,
--    la construcción aparece con una animación y sale el botón de la siguiente.
--
-- Solo el dueño del terreno puede usar sus botones.
--
-- Con el garaje, el letrero de su entrada saca un jeep (JeepService). Al terminar toda la base
-- sale el botón de Renacer: la base se reinicia y desde entonces todo genera más.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Buildings = require(ReplicatedStorage.Shared.Config.Buildings)
local Format = require(ReplicatedStorage.Shared.Format)
local Builder = require(script.Parent.Parent.Builder)
local DataService = require(script.Parent.DataService)
local JeepService = require(script.Parent.JeepService)
local PlotService = require(script.Parent.PlotService)

local notice = ReplicatedStorage.Remotes.Notice :: RemoteEvent

local VAULT_AT = CFrame.new(-45, 0, -48) -- dónde va la caja fuerte dentro del terreno
local AFFORD = Color3.fromRGB(60, 200, 90) -- botón: te alcanza
local TOO_EXPENSIVE = Color3.fromRGB(170, 60, 60) -- botón: todavía no te alcanza
local BUILD_TIME = 0.6 -- segundos que tarda la animación al construir
local REBIRTH_COLOR = Color3.fromRGB(230, 180, 50)

local TycoonService = {}

type Button = { part: BasePart, item: any }
type State = {
	owner: Player,
	plot: PlotService.Plot,
	buttons: { [string]: Button },
	vaultText: TextLabel,
	rebirthButton: BasePart?,
}

local states: { [Player]: State } = {}
local lastWarning: { [Player]: number } = {} -- para no repetir "te falta dinero" a cada paso
local lastCollect: { [Player]: number } = {}

local function placeOf(plot: PlotService.Plot, spot: { number }, rot: number?): CFrame
	return plot.cframe * CFrame.new(spot[1], 0, spot[2]) * CFrame.Angles(0, math.rad(rot or 0), 0)
end

-- Cuánto multiplica el dinero cada renacimiento: 0 = x1, 1 = x1.5, 2 = x2...
local function multiplierOf(rebirths: number): number
	return 1 + rebirths * Buildings.rebirth.bonusPerRebirth
end

-- El dinero por segundo que genera la base de un jugador (con lo de sus renacimientos)
local function incomeOf(profile: DataService.Profile): number
	local total = 0
	for id in profile.owned do
		local item = Buildings.byId[id]
		if item then
			total += item.income
		end
	end
	return math.floor(total * multiplierOf(profile.rebirths))
end

local function ownsEverything(profile: DataService.Profile): boolean
	for _, item in Buildings.list do
		if not profile.owned[item.id] then
			return false
		end
	end
	return true
end

-- Un letrero que se activa manteniendo E (o tocándolo en celular). Solo lo puede usar el dueño
local function prompt(parent: Instance, action: string, owner: Player, hold: number, onUse: () -> ())
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.HoldDuration = hold
	p.MaxActivationDistance = 14
	p.RequiresLineOfSight = false
	p.Triggered:Connect(function(who)
		if who == owner then
			onUse()
		end
	end)
	p.Parent = parent
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

-- Pone una construcción en el terreno. Con animate, las piezas bajan del cielo y aparecen
local function build(state: State, item, animate: boolean, player: Player?)
	local model = Builder.Build(item.kind, placeOf(state.plot, item.at, item.rot))
	model.Name = item.id
	if animate then
		-- Solo si su botón estaba en el mismo lugar (el muro y el portón tienen el botón aparte)
		if player and item.button == nil then
			moveOutOfTheWay(player, model)
		end
		for _, piece in model:GetDescendants() do
			if piece:IsA("BasePart") then
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
	model.Parent = state.plot.contents

	-- El garaje: su entrada tiene el letrero para sacar el jeep
	if item.id == "Garaje" then
		local door = model:FindFirstChild("Puerta")
		if door then
			local spot = placeOf(state.plot, item.at, item.rot) * CFrame.new(0, 0, -Buildings.jeepFromGarage)
			prompt(door, "Sacar jeep", state.owner, 0, function()
				JeepService.Spawn(state.owner, spot, state.plot.contents)
			end)
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
	build(state, item, true, player)
	player:SetAttribute("Income", incomeOf(profile))
	if Buildings.IsLastOfStage(item.id) then
		local stage = Buildings.stages[item.stage]
		notice:FireClient(player, string.format("¡Etapa %s completa!", stage.name), "great")
	else
		notice:FireClient(player, string.format("Construiste: %s", item.name), "good")
	end
	refreshButtons(player)
end

local function makeButton(player: Player, state: State, item)
	local spot = item.button or item.at
	local text = string.format("%s\n%s", item.name, if item.price == 0 then "GRATIS" else Format.Money(item.price))
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

local function rebirth(player: Player)
	local state = states[player]
	local profile = DataService.Get(player)
	if not state or not profile or not ownsEverything(profile) then
		return
	end
	JeepService.Remove(player)
	state.plot.contents:ClearAllChildren()
	states[player] = nil
	DataService.Rebirth(player)
	TycoonService.Setup(player, state.plot)
	local text = string.format("¡Renaciste! Ahora todo genera x%g", multiplierOf(profile.rebirths))
	notice:FireClient(player, text, "great")
end

local function makeRebirthButton(player: Player, state: State, profile: DataService.Profile)
	local nextMultiplier = multiplierOf(profile.rebirths + 1)
	local text = string.format("RENACER\nTodo genera x%g", nextMultiplier)
	local part = Builder.Button(placeOf(state.plot, Buildings.rebirth.at), text)
	part.Color = REBIRTH_COLOR
	part.Size = Vector3.new(0.6, 8, 8)
	-- Se mantiene presionado: así nadie renace por pisarlo sin querer
	prompt(part, "Renacer (pierdes la base)", player, 2, function()
		rebirth(player)
	end)
	part.Parent = state.plot.contents
	state.rebirthButton = part
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
	if not state.rebirthButton and ownsEverything(profile) then
		makeRebirthButton(player, state, profile)
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

-- Prepara el terreno de un jugador que acaba de llegar: caja fuerte, lo que ya había
-- construido (sin animación) y los botones
function TycoonService.Setup(player: Player, plot: PlotService.Plot)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local vault, pad, vaultText = Builder.Vault(plot.cframe * VAULT_AT)
	vault.Parent = plot.contents
	pad.Touched:Connect(function(hit)
		if hit.Parent and Players:GetPlayerFromCharacter(hit.Parent) == player then
			collect(player)
		end
	end)
	local state: State = { owner = player, plot = plot, buttons = {}, vaultText = vaultText }
	states[player] = state
	for _, item in Buildings.list do
		if profile.owned[item.id] then
			build(state, item, false)
		end
	end
	vaultText.Text = Format.Money(profile.vault)
	player:SetAttribute("Income", incomeOf(profile))
	refreshButtons(player)
end

function TycoonService.Cleanup(player: Player)
	JeepService.Remove(player)
	states[player] = nil
	lastWarning[player] = nil
	lastCollect[player] = nil
end

function TycoonService.Start()
	JeepService.Start()
	DataService.MoneyChanged.Event:Connect(refreshButtons)
	-- Cada segundo, cada base genera su dinero y lo deja en la caja fuerte
	task.spawn(function()
		while true do
			task.wait(1)
			for player, state in states do
				local profile = DataService.Get(player)
				if profile then
					profile.vault += incomeOf(profile)
					state.vaultText.Text = Format.Money(profile.vault)
				end
			end
		end
	end)
end

return TycoonService
