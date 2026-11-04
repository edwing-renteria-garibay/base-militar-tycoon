-- La victoria: con la frecuencia de la cura (laboratorio infestado, LabService) mantienes E en
-- la antena de tu caja fuerte y transmites la cura. Tu base vuelve a empezar desde cero, pero
-- para siempre juntas más dinero (Lab.victoryBonus por cada victoria) y te quedas con tus
-- medallas, tu rango, tu récord, tus armas, lo investigado y lo comprado con Robux.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lab = require(ReplicatedStorage.Shared.Config.Lab)
local Settings = require(ReplicatedStorage.Shared.Config.Settings)
local DataService = require(script.Parent.DataService)
local RankService = require(script.Parent.RankService)
local TycoonService = require(script.Parent.TycoonService)
local WaveService = require(script.Parent.WaveService)

local notice = ReplicatedStorage.Remotes.Notice :: RemoteEvent

local VictoryService = {}

local function transmit(player: Player)
	local profile = DataService.Get(player)
	if not profile or not profile.frequency then
		return
	end
	profile.frequency = false
	profile.victories += 1
	player:SetAttribute("Frequency", nil)
	-- La base vuelve a empezar
	WaveService.Reset(player)
	profile.owned = {}
	profile.placed = {}
	profile.barricades = {}
	profile.snipers = {}
	profile.wave = 1
	profile.vault = 0
	profile.freeUsed = false -- ¡otro edificio gratis!
	profile.freeSniper = false -- y otro francotirador gratis
	DataService.Spend(player, profile.money)
	DataService.AddMoney(player, if Settings.Testing.enabled then Settings.Testing.startMoney else Settings.startMoney)
	TycoonService.Rebuild(player)
	RankService.Count(player, "victories")
	DataService.SaveNow(player)
	local text = string.format(
		"¡TRANSMITISTE LA CURA! Victoria %d: tu base empieza de nuevo y ahora junta +%d%% de dinero para siempre",
		profile.victories,
		math.floor(Lab.victoryBonus * profile.victories * 100)
	)
	notice:FireClient(player, text, "great")
end

function VictoryService.Start()
	TycoonService.OnTransmit = transmit
end

return VictoryService
