-- Punto de entrada del servidor: arma el mapa y, a cada jugador que entra, le carga sus datos,
-- le da un terreno, revisa sus pases, le prepara su base y le da su premio diario. También
-- arranca el rifle (WeaponService) y las olas de enemigos (WaveService).

local Players = game:GetService("Players")

local Services = script.Services
local DataService = require(Services.DataService)
local PlotService = require(Services.PlotService)
local ResearchService = require(Services.ResearchService)
local StoreService = require(Services.StoreService)
local TycoonService = require(Services.TycoonService)
local WallService = require(Services.WallService)
local WaveService = require(Services.WaveService)
local WeaponService = require(Services.WeaponService)

local notice = game:GetService("ReplicatedStorage").Remotes.Notice :: RemoteEvent

PlotService.Start()
WallService.Start() -- las puertas del muro
DataService.Start()
TycoonService.Start()
StoreService.Start()
WeaponService.Start()
WaveService.Start()
ResearchService.Start()

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
	StoreService.CheckPasses(player) -- antes de armar la base: los pases cambian lo que genera
	TycoonService.Setup(player, plot)
	task.spawn(WeaponService.Give, player)
	ResearchService.Publish(player)
	StoreService.GiveDaily(player)
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
