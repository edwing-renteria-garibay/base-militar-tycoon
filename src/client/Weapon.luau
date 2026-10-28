-- El rifle: al hacer clic (o tocar la pantalla en celular) con el rifle en la mano, le dice
-- al servidor a dónde apuntaste. El servidor decide si le diste a alguien (WeaponService).

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
	tool.Activated:Connect(function()
		local now = os.clock()
		if now - lastShot < Waves.rifle.cooldown then
			return
		end
		lastShot = now
		shootRemote:FireServer(mouse.Hit.Position)
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
