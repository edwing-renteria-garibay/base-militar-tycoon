-- Punto de entrada del servidor: arma el mapa y, a cada jugador que entra, le carga sus datos,
-- le da un terreno y le prepara su base.

local Players = game:GetService("Players")

local Services = script.Services
local DataService = require(Services.DataService)
local PlotService = require(Services.PlotService)
local TycoonService = require(Services.TycoonService)

local notice = game:GetService("ReplicatedStorage").Remotes.Notice :: RemoteEvent

PlotService.Start()
DataService.Start()
TycoonService.Start()

local function onPlayerAdded(player: Player)
	DataService.Load(player)
	if not player.Parent then
		DataService.Release(player) -- se fue mientras cargaba
		return
	end
	local plot = PlotService.Claim(player)
	if not plot then
		notice:FireClient(player, "No hay terrenos libres en este servidor", "bad")
		return
	end
	TycoonService.Setup(player, plot)
end

local function onPlayerRemoving(player: Player)
	TycoonService.Cleanup(player)
	PlotService.Release(player)
	DataService.Release(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
