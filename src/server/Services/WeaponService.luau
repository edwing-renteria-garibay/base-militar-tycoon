-- Las armas de cada jugador (Config/Weapons) y la Armería.
--
-- 1. Al aparecer, el jugador recibe todas las armas que tiene (el Rifle siempre).
-- 2. El cliente (src/client/Weapon.luau) avisa con el RemoteEvent "Shoot" a dónde apuntó. El
--    servidor revisa qué arma trae en la mano, que no dispare más rápido de lo permitido y que
--    le queden balas; traza las balas (Raycast) y, si le dan a un zombi, le quita vida (más
--    con el Laboratorio).
-- 3. En la Armería (el RemoteEvent "Armory") se compran armas, munición y mejoras.
-- 4. Cada arma tiene cargador: al vaciarlo recarga sola (o con R: el cliente manda "reload"
--    por el mismo "Shoot"). Mientras recarga no dispara.
--
-- Lo que tiene cada quien se guarda en su perfil (weapons, ammo y mods) y se muestra con los
-- atributos "Weapon_<id>", "Ammo_<id>", "Mod_<id>_<mejora>", "Clip_<id>" (balas en el
-- cargador) y "Reloading" (el arma que está recargando). Los lee la pantalla.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local Research = require(ReplicatedStorage.Shared.Config.Research)
local Waves = require(ReplicatedStorage.Shared.Config.Waves)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local Effects = require(script.Parent.Parent.Effects)
local Lamps = require(script.Parent.Parent.Lamps)
local RankService = require(script.Parent.RankService)
local TwoHands = require(script.Parent.Parent.TwoHands)
local WeaponModels = require(ReplicatedStorage.Shared.WeaponModels)
local DataService = require(script.Parent.DataService)
local TycoonService = require(script.Parent.TycoonService)

local shootRemote = ReplicatedStorage.Remotes.Shoot :: RemoteEvent
local armoryRemote = ReplicatedStorage.Remotes.Armory :: RemoteEvent
local hitRemote = ReplicatedStorage.Remotes.Hit :: RemoteEvent
local notice = ReplicatedStorage.Remotes.Notice :: RemoteEvent

local WeaponService = {}

local lastShot: { [Player]: number } = {}
local lastEmpty: { [Player]: number } = {}
local clips: { [Player]: { [string]: number } } = {} -- balas en el cargador (no se guarda)
local reloading: { [Player]: { id: string, token: number } } = {}
local reloadCount = 0

-- ¿Tiene esa mejora para esa arma?
local function hasMod(profile: DataService.Profile, weapon): (string) -> boolean
	return function(key: string): boolean
		local mods = profile.mods[weapon.id]
		return mods ~= nil and mods[key] == true
	end
end

local function magazineOf(profile: DataService.Profile, weapon): number
	return Weapons.Stat(weapon, "magazine", hasMod(profile, weapon))
end

-- Lo más que le cabe al cargador ahora (las armas con munición, hasta donde alcancen sus balas)
local function fullClip(profile: DataService.Profile, weapon): number
	local size = magazineOf(profile, weapon)
	return if weapon.ammo then math.min(size, profile.ammo[weapon.id] or 0) else size
end

local function clipOf(player: Player, profile: DataService.Profile, weapon): number
	local mine = clips[player]
	if not mine then
		mine = {}
		clips[player] = mine
	end
	if mine[weapon.id] == nil then
		mine[weapon.id] = fullClip(profile, weapon) -- al aparecer, todos los cargadores llenos
		player:SetAttribute("Clip_" .. weapon.id, mine[weapon.id])
	end
	return mine[weapon.id]
end

local function setClip(player: Player, weapon, value: number)
	clips[player] = clips[player] or {}
	clips[player][weapon.id] = value
	player:SetAttribute("Clip_" .. weapon.id, value)
end

-- Recarga: tarda weapon.reload segundos. Si cambia de arma a la mitad, se cancela
local function reload(player: Player, profile: DataService.Profile, weapon)
	if reloading[player] then
		return
	end
	local current = clipOf(player, profile, weapon)
	if fullClip(profile, weapon) <= current then
		return -- ya está lleno (o no hay más balas)
	end
	reloadCount += 1
	local token = reloadCount
	reloading[player] = { id = weapon.id, token = token }
	player:SetAttribute("Reloading", weapon.id)
	task.delay(weapon.reload, function()
		local now = reloading[player]
		if not now or now.token ~= token then
			return
		end
		reloading[player] = nil
		player:SetAttribute("Reloading", nil)
		local latest = DataService.Get(player)
		if latest then
			setClip(player, weapon, fullClip(latest, weapon))
		end
	end)
end

local function cancelReload(player: Player)
	reloading[player] = nil
	player:SetAttribute("Reloading", nil)
end

-- Pone en la pantalla qué armas tiene y cuántas balas le quedan
local function publish(player: Player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	for _, weapon in Weapons.list do
		player:SetAttribute("Weapon_" .. weapon.id, weapon.price == 0 or profile.weapons[weapon.id] == true)
		if weapon.ammo then
			player:SetAttribute("Ammo_" .. weapon.id, profile.ammo[weapon.id] or 0)
		end
		for _, mod in Weapons.mods do
			player:SetAttribute("Mod_" .. weapon.id .. "_" .. mod.key, hasMod(profile, weapon)(mod.key) or nil)
		end
		player:SetAttribute("Clip_" .. weapon.id, clipOf(player, profile, weapon))
	end
	player:SetAttribute("Medkits", profile.medkits)
	player:SetAttribute("Antidotes", profile.antidotes)
end

-- Lo que se compra en la enfermería y se usa desde la barra de abajo:
--   Botiquin: una cajita blanca con cruz roja; cura Waves.medkit.heal de vida
--   Antidoto: un frasco verde; quita la infección del zombi corrosivo
-- field: dónde se guarda cuántos tiene (perfil) y attribute: cómo lo lee la pantalla
local ITEMS = {
	{ id = "Botiquin", name = "Botiquín", field = "medkits", attribute = "Medkits" },
	{ id = "Antidoto", name = "Antídoto", field = "antidotes", attribute = "Antidotes" },
}
local lastUse: { [Player]: number } = {}

local function itemPart(tool: Tool, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material): Part
	local handle = tool:FindFirstChild("Handle") :: BasePart?
	local p = Instance.new("Part")
	p.Size = size
	p.Color = color
	p.Material = material
	p.CanCollide = false
	p.Massless = true
	if handle then
		p.CFrame = handle.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = p
		weld.Parent = p
	else
		p.Name = "Handle"
	end
	p.Parent = tool
	return p
end

-- Usarlo: devuelve el aviso si se usó, o nil si no hacía falta (y por qué)
local function useItem(player: Player, item, humanoid: Humanoid): (boolean, string)
	if item.id == "Botiquin" then
		if humanoid.Health >= humanoid.MaxHealth then
			return false, "Ya tienes toda tu vida"
		end
		humanoid.Health = math.min(humanoid.Health + Waves.medkit.heal, humanoid.MaxHealth)
		return true, string.format("+%d de vida", Waves.medkit.heal)
	end
	if not player:GetAttribute("Infected") then
		return false, "No estás infectado"
	end
	player:SetAttribute("Infected", nil)
	return true, "Ya no estás infectado"
end

local function makeItem(player: Player, item): Tool
	local tool = Instance.new("Tool")
	tool.Name = item.id
	tool.CanBeDropped = false
	tool.Grip = CFrame.new(0, 0, -0.3)
	if item.id == "Botiquin" then
		itemPart(tool, Vector3.new(1.2, 0.9, 0.5), CFrame.new(), Color3.fromRGB(235, 235, 230), Enum.Material.SmoothPlastic)
		for _, size in { Vector3.new(0.6, 0.18, 0.52), Vector3.new(0.18, 0.6, 0.52) } do
			itemPart(tool, size, CFrame.new(), Color3.fromRGB(200, 30, 30), Enum.Material.SmoothPlastic)
		end
	else
		itemPart(tool, Vector3.new(0.5, 0.9, 0.5), CFrame.new(), Color3.fromRGB(110, 255, 90), Enum.Material.Glass)
		itemPart(tool, Vector3.new(0.3, 0.25, 0.3), CFrame.new(0, 0.55, 0), Color3.fromRGB(60, 60, 60), Enum.Material.SmoothPlastic)
	end
	tool.Activated:Connect(function()
		local profile = DataService.Get(player) :: any
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local now = os.clock()
		if not profile or not humanoid or humanoid.Health <= 0 or now - (lastUse[player] or 0) < 1 then
			return
		end
		if (profile[item.field] or 0) <= 0 then
			return
		end
		local used, message = useItem(player, item, humanoid)
		if not used then
			notice:FireClient(player, message, "bad")
			return
		end
		lastUse[player] = now
		profile[item.field] -= 1
		player:SetAttribute(item.attribute, profile[item.field])
		notice:FireClient(player, string.format("%s (te quedan %d)", message, profile[item.field]), "good")
	end)
	return tool
end

-- Pone o quita el botiquín y el antídoto de la barra según cuántos tiene
local function updateItems(player: Player)
	local profile = DataService.Get(player) :: any
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not profile or not backpack then
		return
	end
	local character = player.Character
	for _, item in ITEMS do
		local count = profile[item.field] or 0
		local tool = backpack:FindFirstChild(item.id) or (character and character:FindFirstChild(item.id))
		if count > 0 then
			if not tool then
				tool = makeItem(player, item)
				tool.Parent = backpack
			end
			(tool :: Tool).ToolTip = string.format("%s (%d)", item.name, count)
		elseif tool then
			tool:Destroy()
		end
	end
end


local function owns(profile: DataService.Profile, weapon): boolean
	return weapon.price == 0 or profile.weapons[weapon.id] == true
end

-- Le da las armas que tiene y que todavía no trae
local function giveWeapons(player: Player)
	local profile = DataService.Get(player)
	local backpack = player:WaitForChild("Backpack", 5)
	if not profile or not backpack then
		return
	end
	local character = player.Character
	for _, weapon in Weapons.list do
		local has = backpack:FindFirstChild(weapon.id) or (character and character:FindFirstChild(weapon.id))
		if owns(profile, weapon) and not has then
			WeaponModels.MakeTool(weapon).Parent = backpack
		end
	end
	publish(player)
	updateItems(player)
end

-- ¿Le dio a alguien? Devuelve su Humanoid y si es aliado (un francotirador de las torres:
-- también le pega, así que cuidado)
local function targetOf(part: BasePart): (Humanoid?, boolean)
	local model = part:FindFirstAncestorOfClass("Model")
	while model do
		if CollectionService:HasTag(model, "Enemy") then
			return model:FindFirstChildOfClass("Humanoid"), false
		elseif CollectionService:HasTag(model, "Ally") then
			return model:FindFirstChildOfClass("Humanoid"), true
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil, false
end

-- Cuánto multiplica el daño de sus armas lo investigado en el Laboratorio
function WeaponService.DamageBonus(player: Player): number
	local profile = DataService.Get(player)
	if not profile then
		return 1
	end
	return Research.Bonus(profile.research, "Balas")
end

-- Como workspace:Raycast, pero las balas atraviesan lo invisible (la pieza que tapa la puerta,
-- la parte central del personaje...): solo choca con lo que se ve
local function castVisible(origin: Vector3, direction: Vector3, params: RaycastParams): RaycastResult?
	for _ = 1, 10 do
		local result = workspace:Raycast(origin, direction, params)
		if not result or result.Instance.Transparency < 0.95 then
			return result
		end
		params:AddToFilter(result.Instance)
	end
	return nil
end

local function onShoot(player: Player, target: any)
	if typeof(target) ~= "Vector3" and target ~= "reload" then
		return
	end
	local profile = DataService.Get(player)
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	local weapon = tool and Weapons.byId[tool.Name]
	local head = character and character:FindFirstChild("Head") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not profile or not weapon or not head or not humanoid or humanoid.Health <= 0 then
		return
	end
	local busy = reloading[player]
	if busy and busy.id ~= weapon.id then
		cancelReload(player) -- cambió de arma a la mitad
		busy = nil
	end
	if target == "reload" then
		reload(player, profile, weapon)
		return
	end
	if busy then
		return -- está recargando
	end
	local now = os.clock()
	if now - (lastShot[player] or 0) < weapon.cooldown * 0.8 then
		return -- dispara más rápido de lo permitido
	end
	if weapon.ammo and (profile.ammo[weapon.id] or 0) <= 0 then
		if now - (lastEmpty[player] or 0) > 3 then
			lastEmpty[player] = now
			notice:FireClient(player, "Sin balas: compra munición en la Armería", "bad")
		end
		return
	end
	local clip = clipOf(player, profile, weapon)
	if clip <= 0 then
		reload(player, profile, weapon) -- se vació el cargador: recarga sola
		return
	end
	setClip(player, weapon, clip - 1)
	if weapon.ammo then
		local ammo = profile.ammo[weapon.id] or 0
		profile.ammo[weapon.id] = ammo - 1
		player:SetAttribute("Ammo_" .. weapon.id, ammo - 1)
	end
	lastShot[player] = now
	if clip - 1 <= 0 then
		reload(player, profile, weapon)
	end

	local origin = head.Position
	if (target - origin).Magnitude < 0.1 then
		return
	end
	local aim = CFrame.lookAt(origin, target)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local handle = (tool :: Tool):FindFirstChild("Handle")
	local tip = handle and handle:FindFirstChild("Muzzle") :: Attachment?
	local muzzle = if tip then tip.WorldPosition else origin
	local damage = weapon.damage * WeaponService.DamageBonus(player)
	local has = hasMod(profile, weapon)
	local headshotTimes = Weapons.Stat(weapon, "headshot", has)
	for i = 1, weapon.pellets or 1 do
		local direction = aim.LookVector
		if weapon.spread then
			local spread = math.rad(Weapons.Stat(weapon, "spread", has))
			direction = (aim * CFrame.Angles((math.random() - 0.5) * spread * 2, (math.random() - 0.5) * spread * 2, 0)).LookVector
		end
		local result = castVisible(origin, direction * weapon.range, params)
		local hitPoint = if result then result.Position else origin + direction * weapon.range
		local surface = nil
		if result then
			local victim, ally = targetOf(result.Instance)
			if victim then
				surface = "flesh"
				if victim.Health > 0 then
					local headshot = result.Instance.Name == "Head"
					victim:TakeDamage(if headshot then damage * headshotTimes else damage)
					local immune = (victim.Parent :: Instance):FindFirstChildOfClass("ForceField") ~= nil
					if not ally and victim.Health <= 0 then
						-- Lo mataste tú: cuenta para tu rango y tus medallas
						RankService.Kill(player, headshot, (victim.Parent :: Instance):GetAttribute("Boss") == true)
					end
					if not ally and not immune then
						hitRemote:FireClient(player) -- la mira se pone roja y suena el aviso
					end
					if ally and now - (lastEmpty[player] or 0) > 3 then
						lastEmpty[player] = now
						notice:FireClient(player, "¡Cuidado! Le diste a tu francotirador", "bad")
					end
				end
			else
				surface = Effects.SurfaceOf(result.Instance)
				if Lamps.IsLamp(result.Instance) then
					Lamps.Break(result.Instance :: BasePart) -- ¡rompiste un farol!
				end
			end
		end
		-- Solo la primera bala suena (la escopeta dispara 6 a la vez)
		Effects.Shot(muzzle, hitPoint, if i == 1 then weapon.sound else nil, surface, player)
	end
end

-- La Armería: comprar un arma (trae un paquete de balas), más munición o una mejora
local function onArmory(player: Player, action: any, id: any, modKey: any)
	local profile = DataService.Get(player)
	local weapon = Weapons.byId[id]
	if not profile or not weapon or not TycoonService.Has(player, "armory") then
		return
	end
	local packSize = if weapon.ammo then weapon.ammo.amount else 0
	if player:GetAttribute("Pass_MunicionX2") then
		packSize *= 2
	end
	if action == "weapon" then
		if owns(profile, weapon) then
			return
		end
		if not DataService.Spend(player, weapon.price) then
			notice:FireClient(player, "Te faltan " .. Format.Money(weapon.price - profile.money), "bad")
			return
		end
		profile.weapons[weapon.id] = true
		profile.ammo[weapon.id] = (profile.ammo[weapon.id] or 0) + packSize
		giveWeapons(player)
		notice:FireClient(player, "Compraste: " .. weapon.name, "great")
	elseif action == "ammo" then
		if not weapon.ammo or not owns(profile, weapon) then
			return
		end
		if not DataService.Spend(player, weapon.ammo.price) then
			notice:FireClient(player, "Te faltan " .. Format.Money(weapon.ammo.price - profile.money), "bad")
			return
		end
		profile.ammo[weapon.id] = (profile.ammo[weapon.id] or 0) + packSize
		publish(player)
		notice:FireClient(player, string.format("+%d balas de %s", packSize, weapon.name), "good")
	elseif action == "mod" then
		local mod = Weapons.modById[modKey]
		if not mod or not owns(profile, weapon) or hasMod(profile, weapon)(mod.key) then
			return
		end
		if not DataService.Spend(player, weapon.modPrice) then
			notice:FireClient(player, "Te faltan " .. Format.Money(weapon.modPrice - profile.money), "bad")
			return
		end
		profile.mods[weapon.id] = profile.mods[weapon.id] or {}
		profile.mods[weapon.id][mod.key] = true
		publish(player)
		notice:FireClient(player, string.format("%s: %s", weapon.name, mod.name), "great")
	end
end

-- Al terminar de cargar su perfil (init.server.luau): sus armas
WeaponService.Give = giveWeapons

function WeaponService.Start()
	shootRemote.OnServerEvent:Connect(onShoot)
	armoryRemote.OnServerEvent:Connect(onArmory)
	local function onPlayer(player: Player)
		for _, item in ITEMS do
			player:GetAttributeChangedSignal(item.attribute):Connect(function()
				updateItems(player)
			end)
		end
		player.CharacterAdded:Connect(function(character)
			clips[player] = nil -- al aparecer, cargadores llenos
			cancelReload(player)
			TwoHands.Setup(character)
			giveWeapons(player)
		end)
		if player.Character then
			task.spawn(TwoHands.Setup, player.Character)
			task.spawn(giveWeapons, player)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastShot[player] = nil
		lastEmpty[player] = nil
		lastUse[player] = nil
		clips[player] = nil
		reloading[player] = nil
	end)
end

return WeaponService
