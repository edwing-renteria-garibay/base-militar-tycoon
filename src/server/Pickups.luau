-- Los consumibles que sueltan los zombis (Waves.pickups): una caja que brilla y gira en el
-- piso. Quien pase encima la agarra y por unos segundos dispara más rápido, pega más fuerte o
-- se va curando. WeaponService lee los atributos "Buff_<key>" (y el cliente, para disparar).

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Waves = require(ReplicatedStorage.Shared.Config.Waves)
local RankService = require(script.Parent.Services.RankService)

local notice = ReplicatedStorage.Remotes.Notice :: RemoteEvent

local Pickups = {}

local function give(player: Player, humanoid: Humanoid, kind)
	local config = Waves.pickups
	local finish = workspace:GetServerTimeNow() + config.duration
	player:SetAttribute("Buff_" .. kind.key, finish)
	notice:FireClient(player, string.format("¡%s por %d segundos!", kind.name, config.duration), "great")
	RankService.Count(player, "pickups") -- misiones
	if kind.heal then
		task.spawn(function()
			while humanoid.Parent and humanoid.Health > 0 and workspace:GetServerTimeNow() < finish do
				humanoid.Health = math.min(humanoid.Health + kind.heal, humanoid.MaxHealth)
				task.wait(1)
			end
		end)
	end
end

-- Suelta uno al azar en ese lugar (si always, seguro; si no, según la probabilidad)
function Pickups.Drop(position: Vector3, always: boolean?)
	local config = Waves.pickups
	if not always and math.random() > config.chance then
		return
	end
	local kind = config.kinds[math.random(#config.kinds)]
	-- Sobre el piso (el cuerpo del zombi ya no cuenta para los rayos)
	local ground = workspace:Raycast(position + Vector3.new(0, 2, 0), Vector3.new(0, -60, 0))
	if ground then
		position = ground.Position + Vector3.new(0, 2, 0)
	end
	local model = Instance.new("Model")
	model.Name = "Consumible_" .. kind.key
	local box = Instance.new("Part")
	box.Name = "Caja"
	box.Size = Vector3.new(1.8, 1.8, 1.8)
	box.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(45))
	box.Anchored = true
	box.CanCollide = false
	box.CanQuery = false -- las balas lo atraviesan
	box.Color = kind.color
	box.Material = Enum.Material.Neon
	box.Transparency = 0.15
	box.Parent = model
	local light = Instance.new("PointLight")
	light.Color = kind.color
	light.Range = 10
	light.Brightness = 2
	light.Parent = box
	local sign = Instance.new("BillboardGui")
	sign.Size = UDim2.fromOffset(160, 30)
	sign.StudsOffset = Vector3.new(0, 2.2, 0)
	sign.AlwaysOnTop = true
	sign.MaxDistance = 80
	sign.Parent = box
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 16
	label.TextColor3 = kind.color
	label.TextStrokeTransparency = 0.3
	label.Text = kind.name
	label.Parent = sign
	model.PrimaryPart = box
	model:SetAttribute("SpinSpeed", 2)
	CollectionService:AddTag(model, "Spin") -- gira en la pantalla de cada quien (Spinner)
	model.Parent = workspace
	local taken = false
	box.Touched:Connect(function(hit)
		if taken then
			return
		end
		local character = hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if player and humanoid and humanoid.Health > 0 then
			taken = true
			give(player, humanoid, kind)
			model:Destroy()
		end
	end)
	Debris:AddItem(model, config.life)
end

return Pickups
