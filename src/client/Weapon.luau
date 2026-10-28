-- El rifle: al hacer clic (o tocar la pantalla en celular) con el rifle en la mano, le dice
-- al servidor a dónde apuntaste; si lo mantienes, sigue disparando. El servidor decide si le
-- diste a alguien (WeaponService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Waves = require(ReplicatedStorage.Shared.Config.Waves)

local shootRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Shoot") :: RemoteEvent
local player = Players.LocalPlayer
local mouse = player:GetMouse()

local Weapon = {}

local connected: { [Tool]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local lastShot = 0

local function hook(tool: Instance)
	if not tool:IsA("Tool") or tool.Name ~= "Rifle" or connected[tool] then
		return
	end
	connected[tool] = true
	-- Mientras mantienes el clic (o el dedo), sigue disparando a la velocidad de tu arma
	local firing = false
	tool.Activated:Connect(function()
		if firing then
			return
		end
		firing = true
		while firing and tool.Parent == player.Character do
			local now = os.clock()
			local rifle = Waves.rifle[player:GetAttribute("WeaponLevel") or 1] or Waves.rifle[1]
			if now - lastShot >= rifle.cooldown then
				lastShot = now
				shootRemote:FireServer(mouse.Hit.Position)
			end
			task.wait()
		end
		firing = false
	end)
	tool.Deactivated:Connect(function()
		firing = false
	end)
	tool.Unequipped:Connect(function()
		firing = false
	end)
end

local function watch(container: Instance)
	for _, child in container:GetChildren() do
		hook(child)
	end
	container.ChildAdded:Connect(hook)
end

function Weapon.Start()
	local function onCharacter(character: Model)
		watch(character)
		watch(player:WaitForChild("Backpack"))
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
end

return Weapon
