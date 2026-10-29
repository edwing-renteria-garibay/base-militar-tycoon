-- Las armas de cada jugador (Config/Weapons) y la Armería.
--
-- 1. Al aparecer, el jugador recibe todas las armas que tiene (el Rifle siempre).
-- 2. El cliente (src/client/Weapon.luau) avisa con el RemoteEvent "Shoot" a dónde apuntó. El
--    servidor revisa qué arma trae en la mano, que no dispare más rápido de lo permitido y que
--    le queden balas; traza las balas (Raycast) y, si le dan a un zombi, le quita vida (más
--    con el Laboratorio).
-- 3. En la Armería (el RemoteEvent "Armory") se compran armas y munición.
--
-- Lo que tiene cada quien se guarda en su perfil (weapons y ammo) y se muestra con los
-- atributos "Weapon_<id>" y "Ammo_<id>" (los lee la pantalla).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local Research = require(ReplicatedStorage.Shared.Config.Research)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local Effects = require(script.Parent.Parent.Effects)
local TwoHands = require(script.Parent.Parent.TwoHands)
local WeaponModels = require(script.Parent.Parent.WeaponModels)
local DataService = require(script.Parent.DataService)
local TycoonService = require(script.Parent.TycoonService)

local shootRemote = ReplicatedStorage.Remotes.Shoot :: RemoteEvent
local armoryRemote = ReplicatedStorage.Remotes.Armory :: RemoteEvent
local notice = ReplicatedStorage.Remotes.Notice :: RemoteEvent

local WeaponService = {}

local lastShot: { [Player]: number } = {}
local lastEmpty: { [Player]: number } = {}

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

local function onShoot(player: Player, target: any)
	if typeof(target) ~= "Vector3" then
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
	local now = os.clock()
	if now - (lastShot[player] or 0) < weapon.cooldown * 0.8 then
		return -- dispara más rápido de lo permitido
	end
	if weapon.ammo then
		local ammo = profile.ammo[weapon.id] or 0
		if ammo <= 0 then
			if now - (lastEmpty[player] or 0) > 3 then
				lastEmpty[player] = now
				notice:FireClient(player, "Sin balas: compra munición en la Armería", "bad")
			end
			return
		end
		profile.ammo[weapon.id] = ammo - 1
		player:SetAttribute("Ammo_" .. weapon.id, ammo - 1)
	end
	lastShot[player] = now

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
	for i = 1, weapon.pellets or 1 do
		local direction = aim.LookVector
		if weapon.spread then
			local spread = math.rad(weapon.spread)
			direction = (aim * CFrame.Angles((math.random() - 0.5) * spread * 2, (math.random() - 0.5) * spread * 2, 0)).LookVector
		end
		local result = workspace:Raycast(origin, direction * weapon.range, params)
		local hitPoint = if result then result.Position else origin + direction * weapon.range
		local surface = nil
		if result then
			local victim, ally = targetOf(result.Instance)
			if victim then
				surface = "flesh"
				if victim.Health > 0 then
					victim:TakeDamage(damage)
					if ally and now - (lastEmpty[player] or 0) > 3 then
						lastEmpty[player] = now
						notice:FireClient(player, "¡Cuidado! Le diste a tu francotirador", "bad")
					end
				end
			else
				surface = Effects.SurfaceOf(result.Instance)
			end
		end
		-- Solo la primera bala suena (la escopeta dispara 6 a la vez)
		Effects.Shot(muzzle, hitPoint, if i == 1 then weapon.sound else nil, surface)
	end
end

-- La Armería: comprar un arma (trae un paquete de balas) o más munición
local function onArmory(player: Player, action: any, id: any)
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
	end
end

-- Al terminar de cargar su perfil (init.server.luau): sus armas
WeaponService.Give = giveWeapons

function WeaponService.Start()
	shootRemote.OnServerEvent:Connect(onShoot)
	armoryRemote.OnServerEvent:Connect(onArmory)
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
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
	end)
end

return WeaponService
