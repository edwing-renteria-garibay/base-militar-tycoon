-- Las armas (Config/Weapons): al hacer clic (o tocar la pantalla en celular) con un arma en
-- la mano, le dice al servidor a dónde apuntaste; si lo mantienes, sigue disparando. El
-- servidor decide si le diste a alguien y cuántas balas te quedan (WeaponService).
-- Aquí también se mueve el arma y sube la mira al disparar (retroceso), como en Escuadrón Cero.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local Camera = require(script.Parent.Camera)
local Sfx = require(script.Parent.Sfx)
local ViewModel = require(script.Parent.ViewModel)

local shootRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Shoot") :: RemoteEvent
local player = Players.LocalPlayer
local mouse = player:GetMouse()

local Weapon = {}

-- A dónde apuntas: lo que está bajo la mira (o bajo el dedo en celular), sin contar tu cuerpo
local function aim(): Vector3
	local ray = mouse.UnitRay
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Instance }
	local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
	return if result then result.Position else ray.Origin + ray.Direction * 1000
end

local connected: { [Tool]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local lastShot = 0

local function hook(tool: Instance)
	local weapon = Weapons.byId[tool.Name]
	if not tool:IsA("Tool") or not weapon or connected[tool] then
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
			if now - lastShot >= weapon.cooldown then
				lastShot = now
				if weapon.ammo and (player:GetAttribute("Ammo_" .. weapon.id) or 0) <= 0 then
					Sfx.PlayLocal(Sounds.emptyBy[weapon.id] or Sounds.empty) -- clic: sin balas
				else
					ViewModel.Kick() -- el arma se mueve y hace fogonazo en primera persona
					if weapon.recoil then
						Camera.Kick(weapon.recoil) -- la mira sube (escopeta y francotirador)
					end
				end
				shootRemote:FireServer(aim())
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
