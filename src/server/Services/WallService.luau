-- El muro y las barricadas: cosas con vida que los zombis rompen y tú reparas.
--
-- El muro es un cuadrado alrededor de la caja fuerte (a Waves.wallInset del centro), hecho de
-- pedazos de 10 studs. Cada pedazo, y cada barricada, es un "objetivo" con los atributos
-- Health y MaxHealth. Al perder vida se oscurece; con 0 queda como escombro transparente que
-- los zombis atraviesan. Al repararlo vuelve a estar como nuevo.
--
-- Todos los objetivos de un jugador van en la carpeta "Rompibles" de su terreno: así los
-- zombis (WaveService) solo buscan ahí lo que tienen enfrente.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Waves = require(ReplicatedStorage.Shared.Config.Waves)
local Builder = require(script.Parent.Parent.Builder)

local SEGMENT = 10 -- ancho de cada pedazo del muro
local SIDE_ANGLES = { 0, -90, 180, 90 } -- frente, derecha, atrás e izquierda
local DAMAGED = Color3.fromRGB(25, 25, 25) -- el color al que se acerca al perder vida

local WallService = {}

type State = { plot: any, folder: Folder, segments: { BasePart }, targets: { Instance } }

local states: { [Player]: State } = {}

local function partsOf(target: Instance): { BasePart }
	if target:IsA("BasePart") then
		return { target }
	end
	local list = {}
	for _, piece in target:GetDescendants() do
		if piece:IsA("BasePart") then
			table.insert(list, piece)
		end
	end
	return list
end

-- Pinta el objetivo según su vida: más oscuro si está dañado, escombro si está roto
local function show(target: Instance)
	local health = target:GetAttribute("Health") or 0
	local max = target:GetAttribute("MaxHealth") or 1
	local broken = health <= 0
	local wear = 1 - math.clamp(health / max, 0, 1)
	for _, p in partsOf(target) do
		if p:GetAttribute("BaseColor") == nil then
			p:SetAttribute("BaseColor", p.Color)
			p:SetAttribute("BaseTransparency", p.Transparency)
		end
		p.Color = (p:GetAttribute("BaseColor") :: Color3):Lerp(DAMAGED, wear * 0.6)
		p.Transparency = if broken then 0.85 else p:GetAttribute("BaseTransparency") :: number
		p.CanCollide = not broken
		p.CanQuery = not broken -- roto, ni los zombis ni las balas lo "ven"
	end
end

local function setHealth(target: Instance, health: number)
	local max = target:GetAttribute("MaxHealth") or 1
	target:SetAttribute("Health", math.clamp(health, 0, max))
	show(target)
end

local function buildSegments(state: State, level: number)
	for _, segment in state.segments do
		local index = table.find(state.targets, segment)
		if index then
			table.remove(state.targets, index)
		end
		segment:Destroy()
	end
	state.segments = {}
	local max = Waves.wallHealth[level] or Waves.wallHealth[1]
	local inset = Waves.wallInset
	for _, angle in SIDE_ANGLES do
		local side = state.plot.cframe * CFrame.Angles(0, math.rad(angle), 0)
		for x = -inset + SEGMENT / 2, inset - SEGMENT / 2, SEGMENT do
			local segment = Builder.WallSegment(side * CFrame.new(x, 0, -inset), SEGMENT, level)
			segment:SetAttribute("MaxHealth", max)
			segment.Parent = state.folder
			setHealth(segment, max)
			table.insert(state.segments, segment)
			table.insert(state.targets, segment)
		end
	end
end

-- Arma el muro del jugador en su terreno con el nivel que tiene
function WallService.Setup(player: Player, plot, level: number)
	local folder = Instance.new("Folder")
	folder.Name = "Rompibles"
	folder.Parent = plot.contents
	local state: State = { plot = plot, folder = folder, segments = {}, targets = {} }
	states[player] = state
	buildSegments(state, level)
end

-- Mejoró el muro: se vuelve a hacer con más vida, como nuevo
function WallService.SetLevel(player: Player, level: number)
	local state = states[player]
	if state then
		buildSegments(state, level)
	end
end

-- Agrega algo que se puede romper (una barricada)
function WallService.Add(player: Player, target: Instance, maxHealth: number)
	local state = states[player]
	if not state then
		return
	end
	target:SetAttribute("MaxHealth", maxHealth)
	target.Parent = state.folder
	setHealth(target, maxHealth)
	table.insert(state.targets, target)
end

-- La carpeta donde están las cosas que se rompen (para que los zombis las busquen)
function WallService.Folder(player: Player): Folder?
	local state = states[player]
	return state and state.folder
end

-- El objetivo al que pertenece una pieza (el pedazo de muro o la barricada), o nil
function WallService.TargetOf(piece: Instance): Instance?
	local current: Instance? = piece
	while current and not current:IsA("Folder") do
		if current:GetAttribute("MaxHealth") then
			return current
		end
		current = current.Parent
	end
	return nil
end

function WallService.Damage(target: Instance, amount: number)
	local health = target:GetAttribute("Health")
	if health and health > 0 then
		setHealth(target, health - amount)
	end
end

-- Cuánta vida le falta en total a todo lo del jugador
function WallService.Missing(player: Player): number
	local state = states[player]
	local missing = 0
	if state then
		for _, target in state.targets do
			missing += (target:GetAttribute("MaxHealth") or 0) - (target:GetAttribute("Health") or 0)
		end
	end
	return missing
end

-- Repara hasta "points" puntos de vida, empezando por lo más dañado. Devuelve cuántos usó
function WallService.Repair(player: Player, points: number): number
	local state = states[player]
	if not state then
		return 0
	end
	local list = table.clone(state.targets)
	table.sort(list, function(a, b)
		return (a:GetAttribute("Health") or 0) < (b:GetAttribute("Health") or 0)
	end)
	local used = 0
	for _, target in list do
		local health = target:GetAttribute("Health") or 0
		local fix = math.min((target:GetAttribute("MaxHealth") or 0) - health, points - used)
		if fix > 0 then
			setHealth(target, health + fix)
			used += fix
		end
	end
	return used
end

-- El taller: cada cosa recupera esta parte de su vida (0.03 = 3%)
function WallService.RepairShare(player: Player, share: number)
	local state = states[player]
	if not state then
		return
	end
	for _, target in state.targets do
		local health = target:GetAttribute("Health") or 0
		local max = target:GetAttribute("MaxHealth") or 0
		if health < max then
			setHealth(target, health + max * share)
		end
	end
end

-- Todo como nuevo (después de perder la caja fuerte)
function WallService.RepairAll(player: Player)
	local state = states[player]
	if state then
		for _, target in state.targets do
			setHealth(target, target:GetAttribute("MaxHealth") or 0)
		end
	end
end

function WallService.Cleanup(player: Player)
	states[player] = nil
end

return WallService
