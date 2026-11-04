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
--      fire                 la gasolinera tiene un letrero para encender las zanjas llenas
--                           (se llenan con el bidón que das en el depósito, ver Waves.fuel)
--      armory               la armería tiene un letrero que abre su tienda (WeaponService)
--      heal                 la enfermería te cura si estás cerca
--      lab                  el laboratorio tiene un letrero que abre lo que se investiga
--                           (ResearchService)
--      fuel                 el depósito guarda el combustible que genera la gasolinera
--      radar                los zombis se ven a través de las paredes (WaveService)
--    Las torres y torretas ("defense") las hace disparar WaveService.
-- 4. Mantén E junto a la caja fuerte para reparar el muro y las barricadas con dinero.
-- 4b. Cada jugador tiene UN edificio gratis, el que él elija: mientras no lo use, los botones
--    de los edificios dicen "¡GRATIS!" y el primero que pise no le cobra (profile.freeUsed).
-- 5. Las defensas premium (Config/Premium, se compran con Robux) las coloca el jugador donde
--    quiera con la pantalla de colocar (RemoteEvent "Place"), si Placement.Check lo permite.
--
-- Solo el dueño del terreno puede usar sus botones y letreros.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Barricades = require(ReplicatedStorage.Shared.Config.Barricades)
local Lab = require(ReplicatedStorage.Shared.Config.Lab)
local Buildings = require(ReplicatedStorage.Shared.Config.Buildings)
local Premium = require(ReplicatedStorage.Shared.Config.Premium)
local Placement = require(ReplicatedStorage.Shared.Placement)
local Store = require(ReplicatedStorage.Shared.Config.Store)
local Waves = require(ReplicatedStorage.Shared.Config.Waves)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local Format = require(ReplicatedStorage.Shared.Format)
local Builder = require(script.Parent.Parent.Builder)
local Lamps = require(script.Parent.Parent.Lamps)
local TwoHands = require(script.Parent.Parent.TwoHands)
local WeaponModels = require(ReplicatedStorage.Shared.WeaponModels)
local DataService = require(script.Parent.DataService)
local RankService = require(script.Parent.RankService)
local PlotService = require(script.Parent.PlotService)
local WallService = require(script.Parent.WallService)

local notice = ReplicatedStorage.Remotes.Notice :: RemoteEvent
local armoryRemote = ReplicatedStorage.Remotes.Armory :: RemoteEvent
local placeRemote = ReplicatedStorage.Remotes.Place :: RemoteEvent
local researchRemote = ReplicatedStorage.Remotes.Research :: RemoteEvent
local barricadeRemote = ReplicatedStorage.Remotes.Barricade :: RemoteEvent

local AFFORD = Color3.fromRGB(60, 200, 90) -- botón: te alcanza
local TOO_EXPENSIVE = Color3.fromRGB(170, 60, 60) -- botón: todavía no te alcanza
local BUILD_TIME = 0.6 -- segundos que tarda la animación al construir

local TycoonService = {}

type Button = { part: BasePart, item: any, label: TextLabel }
type State = {
	owner: Player,
	plot: PlotService.Plot,
	buttons: { [string]: Button },
	vaultText: TextLabel,
	vaultHealth: number,
	repairPrompt: ProximityPrompt,
	firePrompt: ProximityPrompt?,
	fuelPrompt: ProximityPrompt?,
	fireUntil: number, -- os.clock() hasta el que arden las zanjas
	fuel: number, -- combustible guardado en el depósito (Waves.fuel)
	models: { [string]: Model }, -- lo construido, por id
	items: { [string]: any }, -- y qué es cada cosa (de Config/Buildings o Config/Premium)
	snipers: { [string]: Model }, -- el francotirador de cada torre (si tiene)
	hirePrompts: { [string]: ProximityPrompt },
}

local states: { [Player]: State } = {}
local lastWarning: { [Player]: number } = {} -- para no repetir "te falta dinero" a cada paso
local lastCollect: { [Player]: number } = {}

local function placeOf(plot: PlotService.Plot, spot: { number }, rot: number?): CFrame
	return plot.cframe * CFrame.new(spot[1], 0, spot[2]) * CFrame.Angles(0, math.rad(rot or 0), 0)
end

-- Lo que suma por segundo una cosa comprada (Waves.buildingIncome). Las mejoras de la caja no
-- suman: esas suben el nivel
local function incomeFrom(item): number
	return if item.effect == "vault" then 0 else math.floor(item.price * Waves.buildingIncome)
end

-- El dinero por segundo que junta la caja fuerte: su nivel más lo que has comprado, con los
-- pases del jugador (los pone StoreService como atributos: "Pass_x2", "Pass_VIP"...)
local function incomeOf(player: Player, profile: DataService.Profile): number
	local level = Buildings.LevelOf(profile.owned, "vault")
	local base = Waves.vaultIncome[level]
	for id in profile.owned do
		local item = Buildings.byId[id]
		if item then
			base += incomeFrom(item)
		end
	end
	-- las barricadas también cuentan
	for _, row in profile.barricades do
		base += math.floor(row[5] * Barricades.price * Waves.buildingIncome)
	end
	local multiplier = 1
	if player:GetAttribute("Pass_x2") then
		multiplier *= 2
	end
	if player:GetAttribute("Pass_VIP") then
		multiplier *= 1 + Store.vipBonus
	end
	-- Mientras más lejos vas en las olas, más junta
	multiplier *= 1 + Waves.incomePerWave * (profile.wave - 1)
	-- y cada vez que transmitiste la cura (Config/Lab), para siempre
	multiplier *= 1 + Lab.victoryBonus * profile.victories
	return math.floor(base * multiplier)
end

-- El letrero de la caja fuerte: lo que tiene adentro y cuánto junta por segundo
local function showVault(state: State, profile: DataService.Profile)
	state.vaultText.Text = string.format(
		"%s\n+%s por segundo",
		Format.Money(profile.vault),
		Format.Money(incomeOf(state.owner, profile))
	)
end

-- ¿Funciona? Una construcción rota (vida 0, ver WallService) no funciona hasta repararla
local function working(model: Instance?): boolean
	return model ~= nil and (model:GetAttribute("Health") or 1) > 0
end

-- Las trampas (alambre, minas, zanjas) no se rompen; todo lo demás que se dibuja, sí
local function isBreakable(item): boolean
	return item.kind ~= nil and item.effect ~= "wire" and item.effect ~= "mine" and item.kind ~= "FireTrench"
end

-- ¿Tiene algo con este effect que esté funcionando? (las mejoras sin dibujo siempre funcionan)
local function hasEffect(state: State, profile: DataService.Profile, effect: string): boolean
	for id in profile.owned do
		local item = Buildings.byId[id]
		if item and item.effect == effect and (item.kind == nil or working(state.models[id])) then
			return true
		end
	end
	return false
end

-- Un letrero que se activa manteniendo E (o tocándolo en celular). Solo lo puede usar el dueño.
-- Si la construcción donde está se rompe, el letrero dice "Destruido" y no hace nada hasta que
-- la reparas
local function prompt(parent: Instance, action: string, owner: Player, hold: number, onUse: () -> ()): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.HoldDuration = hold
	p.MaxActivationDistance = 18
	p.RequiresLineOfSight = false
	local building = parent:FindFirstAncestorOfClass("Model")
	p.Triggered:Connect(function(who)
		if who ~= owner then
			return
		end
		if building and not working(building) then
			notice:FireClient(owner, "Está destruido: repáralo en la caja fuerte", "bad")
			return
		end
		onUse()
	end)
	if building then
		building:GetAttributeChangedSignal("Health"):Connect(function()
			p.ActionText = if working(building) then action else "Destruido"
		end)
	end
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

-- Si el jugador está parado donde va a salir la construcción, lo mueve a un lado de ella (si
-- no, las piezas lo empujan y lo tiran). Lo pone del lado de la caja fuerte, para no sacarlo
-- del muro (las torretas miran hacia afuera)
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
		-- Los 4 lados de la construcción; se queda con el más cercano al centro del terreno
		local sides = {
			(box * CFrame.new(here.X, 0, -size.Z / 2 - 5)).Position,
			(box * CFrame.new(here.X, 0, size.Z / 2 + 5)).Position,
			(box * CFrame.new(-size.X / 2 - 5, 0, here.Z)).Position,
			(box * CFrame.new(size.X / 2 + 5, 0, here.Z)).Position,
		}
		local center = player:GetAttribute("PlotCenter")
		local side = sides[1]
		if typeof(center) == "CFrame" then
			for _, option in sides do
				if (option - center.Position).Magnitude < (side - center.Position).Magnitude then
					side = option
				end
			end
		end
		local spot = Vector3.new(side.X, root.Position.Y, side.Z)
		character:PivotTo(CFrame.lookAt(spot, Vector3.new(box.Position.X, spot.Y, box.Position.Z)))
	end
end

local ignite: (Player) -> ()
local takeCan: (State) -> ()
local fillTrench: (State, Model) -> ()
local premiumItem: (any) -> any
local drawRange: (State, any, Model) -> ()
local publishPremium: (Player, DataService.Profile) -> ()

-- El francotirador: un soldado parado arriba de su torre. Es quien dispara (WaveService)
local sniperTemplate: Model? = nil
local function getSniperTemplate(): Model?
	if sniperTemplate then
		return sniperTemplate
	end
	local description = Instance.new("HumanoidDescription")
	local skin = Color3.fromRGB(204, 160, 120)
	local camo = Color3.fromRGB(86, 92, 62)
	description.HeadColor = skin
	description.LeftArmColor = camo
	description.RightArmColor = camo
	description.TorsoColor = camo
	description.LeftLegColor = Color3.fromRGB(56, 60, 42)
	description.RightLegColor = Color3.fromRGB(56, 60, 42)
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok then
		warn("[Torres] No se pudo crear el francotirador:", model)
		return nil
	end
	sniperTemplate = model
	return model
end

-- Los lugares para francotirador de una torre: uno (item.id), o dos con la investigación
-- "Más espacio" (el segundo se guarda como item.id .. "_2")
local function slotsOf(profile: DataService.Profile, item): { string }
	if (profile.research.Espacio or 0) >= 1 then
		return { item.id, item.id .. "_2" }
	end
	return { item.id }
end

-- El letrero de contratar se ve solo si a la torre le cabe otro francotirador
local function updateHire(state: State, item)
	local hire = state.hirePrompts[item.id]
	local profile = DataService.Get(state.owner)
	if not hire or not profile then
		return
	end
	local free = false
	for _, slot in slotsOf(profile, item) do
		free = free or state.snipers[slot] == nil
	end
	hire.Enabled = free
end

-- Las torretas marcan en el piso hasta dónde disparan (las torres alcanzan todo el terreno).
-- Las de las puertas solo disparan hacia el frente, hasta investigar "Torretas giratorias"
drawRange = function(state: State, item, model: Model)
	if not item.defense or item.kind == "SniperTower" then
		return
	end
	local old = state.plot.contents:FindFirstChild("Alcance_" .. item.id)
	if old then
		old:Destroy()
	end
	local profile = DataService.Get(state.owner)
	local turns = profile ~= nil and (profile.research.Giratorias or 0) >= 1
	local arc = if item.kind == "Turret" and not turns then Waves.turretArc else 360
	local o = placeOf(state.plot, item.at, item.rot)
	local marks = Builder.RangeMarks(state.plot.cframe, o, item.defense.range, arc)
	marks.Name = "Alcance_" .. item.id
	marks.Parent = state.plot.contents
	model.Destroying:Connect(function()
		marks:Destroy()
	end)
end

local function spawnSniper(state: State, item, slot: string)
	local base = getSniperTemplate()
	if not base or state.snipers[slot] then
		return
	end
	local model = base:Clone()
	model.Name = "Francotirador_" .. slot
	model:SetAttribute("Tower", item.id)
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	humanoid.MaxHealth = Waves.sniper.health
	humanoid.Health = Waves.sniper.health
	humanoid.DisplayName = "Francotirador"
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
	CollectionService:AddTag(model, "Ally") -- tus balas también le pegan (WeaponService)
	-- Arriba de la torre, mirando hacia afuera del terreno
	-- (el segundo, a un lado del primero)
	local spot = if slot == item.id then CFrame.new(0, 27.5, 0) else CFrame.new(-1.8, 27.5, 1.8)
	local top = (placeOf(state.plot, item.at) * spot).Position
	local outward = Vector3.new(top.X - state.plot.cframe.X, 0, top.Z - state.plot.cframe.Z)
	model:PivotTo(CFrame.lookAt(top, top + outward))
	root.Anchored = true -- no se cae de la torre
	model.Parent = state.plot.contents
	-- Con su rifle de francotirador en las manos (el mismo que venden en la Armería)
	TwoHands.Setup(model)
	humanoid:EquipTool(WeaponModels.MakeTool(Weapons.byId.Francotirador))
	state.snipers[slot] = model
	updateHire(state, item)
	humanoid.Died:Connect(function()
		if state.snipers[slot] ~= model then
			return
		end
		state.snipers[slot] = nil
		local profile = DataService.Get(state.owner)
		if profile then
			profile.snipers[slot] = nil
		end
		updateHire(state, item)
		root.Anchored = false
		Debris:AddItem(model, 3)
		notice:FireClient(state.owner, "¡Mataron a tu francotirador! Contrata otro en su torre", "bad")
	end)
end

-- Ya usó su francotirador gratis: los letreros de las demás torres vuelven a decir el precio
local function priceSnipers(state: State)
	for _, hire in state.hirePrompts do
		hire.ObjectText = Format.Money(Waves.sniper.price)
	end
end

local function hireSniper(state: State, item)
	local player = state.owner
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local slot = nil
	for _, candidate in slotsOf(profile, item) do
		if not slot and state.snipers[candidate] == nil then
			slot = candidate
		end
	end
	if not slot then
		return -- ya no caben más
	end
	if not working(state.models[item.id]) then
		notice:FireClient(player, "Primero repara la torre", "bad")
		return
	end
	-- El primero es gratis
	local free = not profile.freeSniper
	if not free and not DataService.Spend(player, Waves.sniper.price) then
		notice:FireClient(player, "Te faltan " .. Format.Money(Waves.sniper.price - profile.money), "bad")
		return
	end
	profile.freeSniper = true
	priceSnipers(state)
	profile.snipers[slot] = true
	spawnSniper(state, item, slot)
	notice:FireClient(player, if free then "¡Tu primer francotirador es gratis!" else "Contrataste un francotirador", "great")
end

-- La enfermería vende botiquines y antídotos (los usa WeaponService: salen en la barra de
-- abajo). field: dónde se guarda en el perfil; config: Waves.medkit o Waves.antidote
local function buyItem(player: Player, field: string, attribute: string, config, name: string)
	local profile = DataService.Get(player) :: any
	if not profile then
		return
	end
	local count = profile[field] or 0
	if count >= config.max then
		notice:FireClient(player, string.format("Ya cargas el máximo (%d)", config.max), "bad")
		return
	end
	if not DataService.Spend(player, config.price) then
		notice:FireClient(player, "Te faltan " .. Format.Money(config.price - profile.money), "bad")
		return
	end
	profile[field] = count + 1
	player:SetAttribute(attribute, count + 1)
	notice:FireClient(player, string.format("Compraste %s (tienes %d)", name, count + 1), "great")
end

-- Pone una construcción en el terreno. Con animate, las piezas bajan del cielo y aparecen
local function build(state: State, item, animate: boolean)
	if not item.kind then
		return -- es una mejora: no se dibuja
	end
	local player = state.owner
	local o = placeOf(state.plot, item.at, item.rot)
	local model = Builder.Build(item.kind, o)
	model.Name = item.id
	state.models[item.id] = model
	state.items[item.id] = item
	drawRange(state, item, model)
	if isBreakable(item) then
		-- La pone en la carpeta "Rompibles", con su vida
		WallService.Add(player, model, Waves.buildingHealth[item.kind] or Waves.buildingHealth.default)
	else
		model.Parent = state.plot.contents
	end

	if item.effect == "armory" then
		local spot = promptSpot(model, o * CFrame.new(0, 3, -8))
		prompt(spot, "Abrir armería", player, 0, function()
			armoryRemote:FireClient(player, "open")
		end)
	elseif item.effect == "heal" then
		local spot = promptSpot(model, o * CFrame.new(0, 3, -6.5))
		local buy = prompt(spot, "Comprar botiquín", player, 0, function()
			buyItem(player, "medkits", "Medkits", Waves.medkit, "un botiquín")
		end)
		buy.ObjectText = Format.Money(Waves.medkit.price)
		local cure = prompt(promptSpot(model, o * CFrame.new(4, 3, -6.5)), "Comprar antídoto", player, 0, function()
			buyItem(player, "antidotes", "Antidotes", Waves.antidote, "un antídoto")
		end)
		cure.ObjectText = Format.Money(Waves.antidote.price)
	elseif item.effect == "lab" then
		local spot = promptSpot(model, o * CFrame.new(0, 3, -7.5))
		prompt(spot, "Investigar", player, 0, function()
			researchRemote:FireClient(player, "open")
		end)
	elseif item.kind == "SniperTower" then
		local spot = promptSpot(model, o * CFrame.new(0, 3, -4))
		local hire = prompt(spot, "Contratar francotirador", player, 0.5, function()
			hireSniper(state, item)
		end)
		local owner = DataService.Get(player)
		hire.ObjectText = if owner and not owner.freeSniper then "¡GRATIS!" else Format.Money(Waves.sniper.price)
		state.hirePrompts[item.id] = hire
		local profile = DataService.Get(player)
		if profile then
			for _, slot in slotsOf(profile, item) do
				if profile.snipers[slot] then
					spawnSniper(state, item, slot) -- ya lo tenía contratado
				end
			end
			updateHire(state, item)
		end
	elseif item.effect == "fuel" then
		local spot = promptSpot(model, o * CFrame.new(0, 3, -6))
		state.fuelPrompt = prompt(spot, "Tomar bidón", player, 0.3, function()
			takeCan(state)
		end)
	elseif item.kind == "FireTrench" then
		-- En cualquier parte de la zanja: tres letreros a lo largo
		for _, x in { -50, 0, 50 } do
			local spot = promptSpot(model, o * CFrame.new(x, 2, 0))
			prompt(spot, "Llenar zanja", player, 0.8, function()
				fillTrench(state, model)
			end)
		end
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
			-- Otra vez al terminar de bajar: mientras baja no choca, y si te metiste te atrapaba
			task.delay(BUILD_TIME + 0.1, function()
				if model.Parent then
					moveOutOfTheWay(player, model)
				end
			end)
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

-- ¿Puede salirle gratis? (su edificio gratis: solo edificios, no trampas ni mejoras)
local function canBeFree(profile: DataService.Profile, item): boolean
	return not profile.freeUsed and item.kind ~= nil and not item.oneUse and item.effect ~= "wire"
end

local function buy(player: Player, item)
	local state = states[player]
	local profile = DataService.Get(player)
	if not state or not profile or not isAvailable(profile, item) then
		return
	end
	if canBeFree(profile, item) then
		profile.freeUsed = true
		notice:FireClient(player, "¡Usaste tu edificio gratis!", "great")
	elseif not DataService.Spend(player, item.price) then
		local now = os.clock()
		if now - (lastWarning[player] or 0) > 2 then
			lastWarning[player] = now
			local missing = item.price - profile.money
			notice:FireClient(player, string.format("Te faltan %s", Format.Money(missing)), "bad")
		end
		return
	end
	profile.owned[item.id] = true
	if item.kind == "SniperTower" and not profile.freeSniper then
		-- Tu primera torre de francotirador ya trae a su francotirador
		profile.freeSniper = true
		priceSnipers(state)
		profile.snipers[item.id] = true
		notice:FireClient(player, "¡Tu primera torre trae un francotirador gratis!", "great")
	end
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
	local extra = incomeFrom(item)
	local text = string.format("Construiste: %s", item.name)
	if extra > 0 then
		text ..= string.format(" (tu base junta +%s por segundo)", Format.Money(extra))
	end
	notice:FireClient(player, text, "good")
	refreshButtons(player)
	RankService.Check(player) -- medallas de construir
end

local function makeButton(player: Player, state: State, item)
	local spot = item.button or item.at
	local text = string.format("%s\n%s", item.name, Format.Money(item.price))
	local part, label = Builder.Button(placeOf(state.plot, spot), text)
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
	state.buttons[item.id] = { part = part, item = item, label = label }
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
		local item = button.item
		local free = canBeFree(profile, item)
		button.part.Color = if free or profile.money >= item.price then AFFORD else TOO_EXPENSIVE
		button.label.Text = string.format("%s\n%s", item.name, if free then "¡GRATIS! (solo 1)" else Format.Money(item.price))
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
	showVault(state, profile)
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

-- El bidón de gasolina que se lleva en la mano (de un rojo que se ve en la noche)
local function makeCan(): Tool
	local tool = Instance.new("Tool")
	tool.Name = "Bidon"
	tool.ToolTip = "Llévalo a una zanja y mantén E para llenarla"
	tool.CanBeDropped = false
	tool.Grip = CFrame.new(0, -0.4, 0)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1.6, 2, 0.8)
	handle.Color = Color3.fromRGB(190, 30, 25)
	handle.Material = Enum.Material.Metal
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	local cap = Instance.new("Part")
	cap.Size = Vector3.new(0.4, 0.4, 0.4)
	cap.Color = Color3.fromRGB(230, 190, 40)
	cap.CanCollide = false
	cap.Massless = true
	cap.CFrame = handle.CFrame * CFrame.new(0.5, 1.15, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = cap
	weld.Parent = cap
	cap.Parent = tool
	return tool
end

-- ¿Trae un bidón (en la mano o en la mochila)?
local function canOf(player: Player): Tool?
	local character = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	local found = character and character:FindFirstChild("Bidon")
	if not found and backpack then
		found = backpack:FindFirstChild("Bidon")
	end
	return if found and found:IsA("Tool") then found else nil
end

-- En el depósito: un bidón lleno (gasta combustible)
takeCan = function(state: State)
	local player = state.owner
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	if canOf(player) then
		notice:FireClient(player, "Ya traes un bidón: llévalo a una zanja", "bad")
		return
	end
	if state.fuel < Waves.fuel.cost then
		local wait = math.ceil((Waves.fuel.cost - state.fuel) / Waves.fuel.perSecond)
		notice:FireClient(player, string.format("Falta combustible: espera %d s", wait), "bad")
		return
	end
	state.fuel -= Waves.fuel.cost
	humanoid:EquipTool(makeCan())
	notice:FireClient(player, "Lleva el bidón a una zanja y mantén E para llenarla", "good")
end

-- Pinta la gasolina de la zanja: llena (brilla) o vacía
local function showFuel(trench: Model)
	local fuel = trench:FindFirstChild("Gasolina") :: BasePart?
	if fuel then
		local filled = trench:GetAttribute("Filled") == true
		fuel.Color = if filled then Color3.fromRGB(230, 150, 40) else Color3.fromRGB(70, 50, 90)
		fuel.Material = if filled then Enum.Material.Neon else Enum.Material.Glass
		fuel.Transparency = if filled then 0.45 else 0.3
	end
end

-- ¿Un bidón le alcanza para todas las zanjas? Si juega solo en el servidor, o si tiene Roblox
-- Premium o el pase VIP. Si no, cada zanja se llena con su propio bidón
local function fillsAll(player: Player): boolean
	return #Players:GetPlayers() <= 1
		or player.MembershipType == Enum.MembershipType.Premium
		or player:GetAttribute("Pass_VIP") == true
end

-- Vacía el bidón en la zanja (o en todas)
fillTrench = function(state: State, trench: Model)
	local player = state.owner
	local can = canOf(player)
	local profile = DataService.Get(player)
	local trenches = { trench }
	if fillsAll(player) and profile then
		trenches = {}
		for _, item in Buildings.list do
			local model = state.models[item.id]
			if item.kind == "FireTrench" and profile.owned[item.id] and model then
				table.insert(trenches, model)
			end
		end
	end
	local empty = {}
	for _, model in trenches do
		if not model:GetAttribute("Filled") then
			table.insert(empty, model)
		end
	end
	if #empty == 0 then
		notice:FireClient(player, if #trenches > 1 then "Las zanjas ya están llenas" else "Esta zanja ya está llena", "good")
		return
	end
	if not can then
		notice:FireClient(player, "Trae un bidón del depósito de combustible", "bad")
		return
	end
	can:Destroy()
	for _, model in empty do
		model:SetAttribute("Filled", true)
		showFuel(model)
	end
	local text = if #trenches > 1 then "¡Llenaste todas las zanjas!" else "Zanja llena"
	notice:FireClient(player, text .. ": enciéndelas en la gasolinera", "great")
end

-- Enciende las zanjas llenas un rato (Waves.fire); al apagarse quedan vacías
ignite = function(player: Player)
	local state = states[player]
	local profile = DataService.Get(player)
	if not state or not profile then
		return
	end
	local now = os.clock()
	if now < state.fireUntil then
		return -- ya están ardiendo
	end
	if not working(state.models.Gasolinera) then
		notice:FireClient(player, "La gasolinera está destruida: repárala", "bad")
		return
	end
	local owned, trenches = 0, {}
	for _, item in Buildings.list do
		if item.kind == "FireTrench" and profile.owned[item.id] then
			owned += 1
			local model = state.models[item.id]
			if model and model:GetAttribute("Filled") then
				table.insert(trenches, model)
			end
		end
	end
	if owned == 0 then
		notice:FireClient(player, "Primero compra zanjas de gasolina (botones junto al muro)", "bad")
		return
	end
	if #trenches == 0 then
		notice:FireClient(player, "Las zanjas están vacías: llénalas con un bidón del depósito", "bad")
		return
	end
	state.fireUntil = now + Waves.fire.duration
	RankService.Count(player, "ignites")
	for _, model in trenches do
		model:SetAttribute("Burning", true)
		task.delay(Waves.fire.duration, function()
			model:SetAttribute("Filled", nil)
			model:SetAttribute("Burning", nil)
			showFuel(model)
		end)
	end
	for _, model in trenches do
		local count = 0
		for _, flame in model:GetChildren() do
			if flame.Name == "Llama" then
				count += 1
				local fire = Instance.new("Fire")
				fire.Size = 9
				fire.Heat = 12
				fire.Parent = flame
				Debris:AddItem(fire, Waves.fire.duration)
				if count % 3 == 0 then -- luz en una de cada tres llamas (muchas luces hacen lento el juego)
					local glow = Instance.new("PointLight")
					glow.Color = Color3.fromRGB(255, 140, 50)
					glow.Range = 18
					glow.Parent = flame
					Debris:AddItem(glow, Waves.fire.duration)
				end
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
	local infirmary = state.models.Enfermeria
	if not root or not humanoid or humanoid.Health <= 0 or not infirmary or not infirmary:IsA("Model") then
		return
	end
	if (root.Position - (infirmary:GetBoundingBox()).Position).Magnitude < Waves.healRange then
		humanoid.Health = math.min(humanoid.Health + Waves.heal, humanoid.MaxHealth)
	end
end

-- Defensas premium ----------------------------------------------------------------------------

-- Una defensa premium colocada, como si fuera una cosa más de Config/Buildings. Su id lleva el
-- uid de la colocada (así se puede gastar una mina sin confundirla con otra)
premiumItem = function(entry)
	local base = Premium.byKey[entry.key]
	if not base then
		return nil
	end
	return {
		id = "Premium" .. entry.uid,
		name = base.name,
		kind = base.kind,
		at = { entry.x, entry.z },
		rot = entry.rot,
		defense = base.defense,
		effect = base.effect,
	}
end

-- Cuántas tiene sin colocar y dónde están las colocadas (lo lee la pantalla de colocar, para
-- avisar antes de que el servidor diga "Ya hay otra defensa")
publishPremium = function(player: Player, profile: DataService.Profile)
	for _, item in Premium.list do
		player:SetAttribute("Premium_" .. item.key, profile.premium[item.key] or 0)
	end
	player:SetAttribute("PremiumPlaced", HttpService:JSONEncode(profile.placed))
end

local function radiusOf(key: string): number
	local item = Premium.byKey[key]
	return if item then item.radius else 5
end

-- Coloca una defensa premium en (x, z) del terreno, girada rot grados, si se puede
local function place(player: Player, key: any, x: any, z: any, rot: any)
	local state = states[player]
	local profile = DataService.Get(player)
	local base = Premium.byKey[key]
	if not state or not profile or not base or type(x) ~= "number" or type(z) ~= "number" or type(rot) ~= "number" then
		return
	end
	if (profile.premium[key] or 0) <= 0 then
		return
	end
	x, z, rot = math.floor(x * 10) / 10, math.floor(z * 10) / 10, (math.floor(rot / 90) * 90) % 360
	local ok, reason = Placement.Check(x, z, base.radius, profile.placed, radiusOf)
	if not ok then
		notice:FireClient(player, "No se puede ahí: " .. (reason or ""), "bad")
		return
	end
	profile.premium[key] -= 1
	local entry = { key = key, x = x, z = z, rot = rot, uid = HttpService:GenerateGUID(false) }
	table.insert(profile.placed, entry)
	local item = premiumItem(entry)
	if item then
		build(state, item, true)
	end
	publishPremium(player, profile)
	notice:FireClient(player, "Colocaste: " .. base.name, "great")
end

-- Barricadas (Config/Barricades) -------------------------------------------------------------

-- Dónde están las hileras (lo lee la pantalla de barricadas, para unirse a sus puntas)
local function publishBarricades(player: Player, profile: DataService.Profile)
	player:SetAttribute("Barricades", HttpService:JSONEncode(profile.barricades))
end

local function barricadeCount(profile: DataService.Profile): number
	local count = 0
	for _, row in profile.barricades do
		count += row[5]
	end
	return count
end

-- Dibuja una hilera: sus pedazos, cada uno con su vida
local function buildRow(state: State, row: { number })
	local a, b, count = Vector2.new(row[1], row[2]), Vector2.new(row[3], row[4]), row[5]
	for i = 1, count do
		local from, to = a:Lerp(b, (i - 1) / count), a:Lerp(b, i / count)
		local length = (to - from).Magnitude
		local o = state.plot.cframe
			* CFrame.lookAt(Vector3.new(from.X, 0, from.Y), Vector3.new(to.X, 0, to.Y))
			* CFrame.new(0, 0, -length / 2)
		WallService.Add(state.owner, Builder.BarricadeSegment(o, length), Barricades.health)
	end
end

-- Pone una hilera de barricadas de (ax, az) a (bx, bz), si se puede y le alcanza
local function onBarricade(player: Player, ax: any, az: any, bx: any, bz: any)
	local state = states[player]
	local profile = DataService.Get(player)
	for _, n in { ax, az, bx, bz } do
		if type(n) ~= "number" or n ~= n then
			return
		end
	end
	if not state or not profile then
		return
	end
	local points = Placement.RowPoints(profile.barricades)
	local a, b, count = Placement.Row(Vector2.new(ax, az), Vector2.new(bx, bz), points)
	if count <= 0 then
		return
	end
	if barricadeCount(profile) + count > Barricades.max then
		notice:FireClient(player, string.format("Ya tienes el máximo de barricadas (%d)", Barricades.max), "bad")
		return
	end
	local ok, reason = Placement.CheckRow(a, b, profile.placed, radiusOf)
	if not ok then
		notice:FireClient(player, "No se puede ahí: " .. (reason or ""), "bad")
		return
	end
	local price = count * Barricades.price
	if not DataService.Spend(player, price) then
		notice:FireClient(player, "Te faltan " .. Format.Money(price - profile.money), "bad")
		return
	end
	local function round(n: number): number
		return math.floor(n * 100 + 0.5) / 100
	end
	local row = { round(a.X), round(a.Y), round(b.X), round(b.Y), count }
	table.insert(profile.barricades, row)
	buildRow(state, row)
	publishBarricades(player, profile)
end

-- Prepara el terreno de un jugador que acaba de llegar: caja fuerte, muro, lo que ya había
-- construido (sin animación) y los botones
function TycoonService.Setup(player: Player, plot: PlotService.Plot)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	Lamps.Build(plot.cframe, plot.contents)
	for i, grave in Buildings.graves do
		local o = plot.cframe * CFrame.new(grave[1], 0, grave[2]) * CFrame.Angles(0, math.rad(grave[3]), 0)
		Builder.Grave(o, i % 3 == 0).Parent = plot.contents
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
	-- Con la frecuencia de la cura (laboratorio infestado) la caja se vuelve antena
	local function showAntenna()
		if not profile.frequency or vault:FindFirstChild("Antena") then
			return
		end
		local antenna = Builder.Antenna(plot.cframe)
		antenna.Parent = vault
		local transmit = prompt(body, "Transmitir la cura", player, 5, function()
			if profile.frequency and TycoonService.OnTransmit then
				TycoonService.OnTransmit(player)
			end
		end)
		transmit.ObjectText = "Antena · tu base vuelve a empezar con +50% de dinero"
		transmit.UIOffset = Vector2.new(0, 80)
	end
	player:SetAttribute("Frequency", profile.frequency or nil)
	player:GetAttributeChangedSignal("Frequency"):Connect(showAntenna)
	showAntenna()
	local state: State = {
		owner = player,
		plot = plot,
		buttons = {},
		vaultText = vaultText,
		vaultHealth = Waves.vaultHealth,
		repairPrompt = repairPrompt,
		fireUntil = 0,
		fuel = 0,
		models = {},
		items = {},
		snipers = {},
		hirePrompts = {},
	}
	states[player] = state
	player:SetAttribute("PlotCenter", plot.cframe) -- para la pantalla de colocar
	WallService.Setup(player, plot, Buildings.LevelOf(profile.owned, "wall"))
	for _, item in Buildings.list do
		if profile.owned[item.id] then
			build(state, item, false)
		end
	end
	for index, entry in profile.placed do
		entry.uid = entry.uid or tostring(index) -- las colocadas antes de que hubiera uid
		local item = premiumItem(entry)
		if item then
			build(state, item, false)
		end
	end
	for _, row in profile.barricades do
		buildRow(state, row)
	end
	publishBarricades(player, profile)
	publishPremium(player, profile)
	showVault(state, profile)
	vaultHealthChanged(state)
	player:SetAttribute("Income", incomeOf(player, profile))
	refreshButtons(player)
	-- La primera vez: cómo se juega, en pocas palabras
	if profile.record == 0 and profile.wave == 1 and next(profile.owned) == nil then
		local tips = {
			"Tu caja fuerte junta dinero solo: pisa su botón verde para cobrarlo",
			"Pisa los botones del piso para construir. Todo lo que compres sube lo que junta tu base",
			"Tienes UN edificio gratis: el primero que pises de los que dicen ¡GRATIS! Elige bien",
			"Antes de que lleguen los zombis, pon defensas en tu muro. ¡Aguanta todas las olas que puedas!",
		}
		for i, tip in tips do
			task.delay(4 + (i - 1) * 6, function()
				if player.Parent then
					notice:FireClient(player, tip, "great")
				end
			end)
		end
	end
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
	local state = states[player]
	return state ~= nil and profile ~= nil and hasEffect(state, profile, effect)
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

-- Se gastó algo de un solo uso (una mina): desaparece y su botón vuelve a salir. Si era una
-- mina premium (de Robux), se quita de las colocadas
function TycoonService.Consume(player: Player, id: string)
	local state = states[player]
	local profile = DataService.Get(player)
	if not state or not profile then
		return
	end
	profile.owned[id] = nil
	for i, entry in profile.placed do
		if "Premium" .. tostring(entry.uid) == id then
			table.remove(profile.placed, i)
			publishPremium(player, profile)
			break
		end
	end
	local model = state.models[id]
	if model then
		model:Destroy()
		state.models[id] = nil
		state.items[id] = nil
	end
	refreshButtons(player)
end

-- Las minas premium colocadas: { id, position }
function TycoonService.PremiumMines(player: Player): { { id: string, position: Vector3 } }
	local state = states[player]
	local list = {}
	if state then
		for id, item in state.items do
			if item.effect == "mine" and string.sub(id, 1, 7) == "Premium" then
				table.insert(list, { id = id, position = placeOf(state.plot, item.at).Position })
			end
		end
	end
	return list
end

-- Deja como nuevo el muro, las barricadas, los edificios y la caja fuerte
function TycoonService.RepairEverything(player: Player)
	local state = states[player]
	if not state then
		return
	end
	state.vaultHealth = Waves.vaultHealth
	vaultHealthChanged(state)
	WallService.RepairAll(player)
	Lamps.FixAll(state.plot.contents) -- y los faroles rotos
end

-- Un soldado de refuerzo (Config/Store, kind "squad") parado en cframe, con su rifle. Lo
-- maneja WaveService
function TycoonService.SpawnSoldier(player: Player, cframe: CFrame): Model?
	local state = states[player]
	local base = getSniperTemplate()
	if not state or not base then
		return nil
	end
	local model = base:Clone()
	model.Name = "Refuerzo"
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	humanoid.DisplayName = "Refuerzo"
	model:PivotTo(cframe)
	root.Anchored = true -- se queda en su lugar
	model.Parent = state.plot.contents
	TwoHands.Setup(model)
	humanoid:EquipTool(WeaponModels.MakeTool(Weapons.byId.Rifle))
	return model
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
	showVault(state, profile)
	-- Las defensas premium (de Robux) solo duran hasta que destruyen la caja fuerte
	if #profile.placed > 0 then
		for id, model in state.models do
			if string.sub(id, 1, 7) == "Premium" then
				WallService.Remove(player, model)
				state.models[id] = nil
				state.items[id] = nil
			end
		end
		profile.placed = {}
		publishPremium(player, profile)
		notice:FireClient(player, "Se perdieron tus defensas premium", "bad")
	end
	TycoonService.RepairEverything(player)
	return lost
end

-- Lo construido con ese id (nil si no lo tiene)
function TycoonService.ModelOf(player: Player, id: string): Model?
	local state = states[player]
	return state and state.models[id]
end

-- ¿Funciona lo construido con ese id? (no está roto)
function TycoonService.IsWorking(player: Player, id: string): boolean
	return working(TycoonService.ModelOf(player, id))
end

-- El francotirador vivo de una torre (nil si no tiene). slot: id de la torre, o id .. "_2"
-- para el segundo (investigación "Más espacio")
function TycoonService.SniperOf(player: Player, id: string): Model?
	local state = states[player]
	local function alive(slot: string): Model?
		local sniper = state and state.snipers[slot]
		local humanoid = sniper and sniper:FindFirstChildOfClass("Humanoid")
		return if humanoid and humanoid.Health > 0 then sniper else nil
	end
	return alive(id) or alive(id .. "_2")
end

-- Los francotiradores vivos de una torre: { { slot, model } }
function TycoonService.SnipersOf(player: Player, id: string): { { slot: string, model: Model } }
	local state = states[player]
	local list = {}
	for _, slot in { id, id .. "_2" } do
		local sniper = state and state.snipers[slot]
		local humanoid = sniper and sniper:FindFirstChildOfClass("Humanoid")
		if sniper and humanoid and humanoid.Health > 0 then
			table.insert(list, { slot = slot, model = sniper })
		end
	end
	return list
end

-- Terminó una investigación (ResearchService): con "Más espacio" vuelve a salir el letrero de
-- contratar en las torres
function TycoonService.ResearchDone(player: Player)
	local state = states[player]
	if not state then
		return
	end
	for _, item in Buildings.list do
		if item.kind == "SniperTower" then
			updateHire(state, item)
		elseif item.kind == "Turret" and state.models[item.id] then
			drawRange(state, item, state.models[item.id]) -- con "Torretas giratorias", el círculo completo
		end
	end
end

-- Lo que buscan los zombis especiales (que no esté roto):
--   "tower" las torres, "defense" torres y torretas, "building" los demás edificios
function TycoonService.Targets(player: Player, category: string): { { id: string, model: Model, item: any } }
	local state = states[player]
	local list = {}
	if not state then
		return list
	end
	for id, model in state.models do
		local item = state.items[id]
		if item and isBreakable(item) and working(model) and item.effect ~= "barricade" then
			local defense = item.defense ~= nil
			local fits = if category == "any"
				then true
				elseif category == "tower"
				then item.kind == "SniperTower"
				elseif category == "defense" then defense
				else not defense
			if fits then
				table.insert(list, { id = id, model = model, item = item })
			end
		end
	end
	return list
end

-- Todo lo que dispara solo (torres, torretas y torretas premium): { id, item, model }
function TycoonService.Defenders(player: Player): { { id: string, model: Model, item: any } }
	local state = states[player]
	local list = {}
	if state then
		for id, model in state.models do
			local item = state.items[id]
			if item and item.defense then
				table.insert(list, { id = id, model = model, item = item })
			end
		end
	end
	return list
end

-- Lo pone VictoryService: qué pasa al transmitir la cura desde la antena
TycoonService.OnTransmit = nil :: ((Player) -> ())?

-- Borra todo lo construido y vuelve a armar el terreno según el perfil (después de la victoria)
function TycoonService.Rebuild(player: Player)
	local state = states[player]
	if not state then
		return
	end
	local plot = state.plot
	TycoonService.Cleanup(player)
	plot.contents:ClearAllChildren()
	TycoonService.Setup(player, plot)
end

function TycoonService.Cleanup(player: Player)
	WallService.Cleanup(player)
	states[player] = nil
	lastWarning[player] = nil
	lastCollect[player] = nil
end

function TycoonService.Start()
	DataService.MoneyChanged.Event:Connect(refreshButtons)
	placeRemote.OnServerEvent:Connect(place)
	barricadeRemote.OnServerEvent:Connect(onBarricade)
	-- Cada segundo: la caja fuerte junta dinero, la gasolinera genera combustible y se actualizan
	-- los letreros
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
					showVault(state, profile)
					if hasEffect(state, profile, "heal") then
						heal(state)
					end
					-- Si rompen una torre, su francotirador se cae
					for _, sniper in state.snipers do
						local humanoid = sniper:FindFirstChildOfClass("Humanoid")
						if humanoid and not working(state.models[sniper:GetAttribute("Tower")]) then
							humanoid.Health = 0
						end
					end
					-- La gasolinera genera combustible y el depósito lo guarda
					if working(state.models.Gasolinera) and working(state.models.Taller) then
						state.fuel = math.min(state.fuel + Waves.fuel.perSecond, Waves.fuel.capacity)
					end
					player:SetAttribute("WallHealth", math.floor(WallService.WallShare(player) * 100))
					local missing = WallService.Missing(player)
					state.repairPrompt.ObjectText = if missing >= 1
						then "Cuesta " .. Format.Money(math.ceil(missing * Waves.repairCost))
						else "Todo en buen estado"
					if state.fuelPrompt then
						state.fuelPrompt.ObjectText = string.format(
							"Combustible %d / %d (un bidón gasta %d)",
							state.fuel,
							Waves.fuel.capacity,
							Waves.fuel.cost
						)
					end
					if state.firePrompt then
						local filled, total = 0, 0
						for _, item in Buildings.list do
							local trench = item.kind == "FireTrench" and state.models[item.id]
							if trench then
								total += 1
								filled += if trench:GetAttribute("Filled") then 1 else 0
							end
						end
						state.firePrompt.ObjectText = string.format("Zanjas llenas: %d de %d", filled, total)
					end
				end
			end
		end
	end)
end

return TycoonService
