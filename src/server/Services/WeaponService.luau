-- El rifle de cada jugador, para defender su base de las olas (Config/Waves, rifle).
--
-- El cliente (src/client/Weapon.luau) avisa con el RemoteEvent "Shoot" a dónde apuntó. El
-- servidor revisa que traiga el rifle en la mano y que no dispare más rápido de lo permitido,
-- traza la bala (Raycast) y, si le da a un enemigo, le quita vida.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Waves = require(ReplicatedStorage.Shared.Config.Waves)
local Effects = require(script.Parent.Parent.Effects)

local shootRemote = ReplicatedStorage.Remotes.Shoot :: RemoteEvent

local WeaponService = {}

local lastShot: { [Player]: number } = {}

local function makeRifle(): Tool
	local tool = Instance.new("Tool")
	tool.Name = "Rifle"
	tool.ToolTip = "Rifle: defiende tu base"
	tool.CanBeDropped = false
	tool.GripPos = Vector3.new(0, -0.2, 0.6)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.4, 0.7, 3)
	handle.Color = Color3.fromRGB(40, 42, 40)
	handle.Material = Enum.Material.Metal
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	local stock = Instance.new("Part")
	stock.Size = Vector3.new(0.35, 0.8, 1)
	stock.Color = Color3.fromRGB(86, 92, 62)
	stock.CanCollide = false
	stock.Massless = true
	stock.CFrame = handle.CFrame * CFrame.new(0, -0.2, 1.8)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = stock
	weld.Parent = stock
	stock.Parent = tool
	return tool
end

-- ¿Es un enemigo de las olas? Devuelve su Humanoid
local function enemyOf(part: BasePart): Humanoid?
	local model = part:FindFirstAncestorOfClass("Model")
	while model do
		if CollectionService:HasTag(model, "Enemy") then
			return model:FindFirstChildOfClass("Humanoid")
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil
end

local function onShoot(player: Player, target: any)
	if typeof(target) ~= "Vector3" then
		return
	end
	local character = player.Character
	local tool = character and character:FindFirstChild("Rifle")
	local head = character and character:FindFirstChild("Head") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not tool or not head or not humanoid or humanoid.Health <= 0 then
		return
	end
	local now = os.clock()
	if now - (lastShot[player] or 0) < Waves.rifle.cooldown * 0.8 then
		return -- dispara más rápido de lo permitido
	end
	lastShot[player] = now

	local origin = head.Position
	local direction = target - origin
	if direction.Magnitude < 0.1 then
		return
	end
	direction = direction.Unit * Waves.rifle.range
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local result = workspace:Raycast(origin, direction, params)
	local hitPoint = if result then result.Position else origin + direction
	local muzzle = (tool:FindFirstChild("Handle") :: BasePart?)
	Effects.Tracer(if muzzle then muzzle.Position else origin, hitPoint)
	if result then
		local enemy = enemyOf(result.Instance)
		if enemy and enemy.Health > 0 then
			enemy:TakeDamage(Waves.rifle.damage)
		end
	end
end

local function giveRifle(player: Player)
	local backpack = player:WaitForChild("Backpack", 5)
	if backpack and not backpack:FindFirstChild("Rifle") then
		makeRifle().Parent = backpack
	end
end

function WeaponService.Start()
	shootRemote.OnServerEvent:Connect(onShoot)
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			giveRifle(player)
		end)
		if player.Character then
			task.spawn(giveRifle, player)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastShot[player] = nil
	end)
end

return WeaponService
