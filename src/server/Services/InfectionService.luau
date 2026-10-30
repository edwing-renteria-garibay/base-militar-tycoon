-- La infección del zombi corrosivo (Waves.special, explode.infect). Un jugador infectado tiene
-- el atributo "Infected" y pierde Waves.infection.dps de vida cada segundo, hasta que usa un
-- antídoto (WeaponService) o muere. Al reaparecer ya no está infectado.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Waves = require(ReplicatedStorage.Shared.Config.Waves)

local InfectionService = {}

function InfectionService.Start()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			player:SetAttribute("Infected", nil)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if player:GetAttribute("Infected") and humanoid and humanoid.Health > 0 then
					humanoid:TakeDamage(Waves.infection.dps)
				end
			end
		end
	end)
end

return InfectionService
