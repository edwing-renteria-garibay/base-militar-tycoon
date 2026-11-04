-- La victoria: con la frecuencia de la cura (laboratorio infestado, LabService) mantienes F en
-- la antena de tu caja fuerte y empieza la transmisión: tarda Lab.final.duration segundos y
-- mientras tanto llega la ola final (WaveService.FinalWave). Si tu caja aguanta, transmites la
-- cura. Tu base vuelve a empezar desde cero, pero
-- para siempre juntas más dinero (Lab.victoryBonus por cada victoria) y te quedas con tus
-- medallas, tu rango, tu récord, tus armas, lo investigado y lo comprado con Robux.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lab = require(ReplicatedStorage.Shared.Config.Lab)
local Settings = require(ReplicatedStorage.Shared.Config.Settings)
local DataService = require(script.Parent.DataService)
local RankService = require(script.Parent.RankService)
local TycoonService = require(script.Parent.TycoonService)
local WaveService = require(script.Parent.WaveService)
local Effects = require(script.Parent.Parent.Effects)

local notice = ReplicatedStorage.Remotes.Notice :: RemoteEvent

local VictoryService = {}

local transmitting: { [Player]: boolean } = {}

local function win(player: Player)
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

-- Empieza la transmisión (y la ola final)
local function transmit(player: Player)
	local profile = DataService.Get(player)
	if not profile or not profile.frequency or transmitting[player] then
		return
	end
	transmitting[player] = true
	local config = Lab.final
	player:SetAttribute("Transmitting", workspace:GetServerTimeNow() + config.duration)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		Effects.Sound("cure", root.Position, 1.5)
	end
	notice:FireClient(player, string.format("Transmitiendo la cura: tu caja fuerte debe aguantar %d segundos", config.duration), "great")
	-- Cuánto falta, cada 15 segundos
	task.spawn(function()
		local left = config.duration
		while transmitting[player] and left > 15 do
			task.wait(15)
			left -= 15
			if transmitting[player] and left > 0 then
				notice:FireClient(player, string.format("Transmitiendo... faltan %d s", left), "good")
			end
		end
	end)
	WaveService.FinalWave(player, config, function(success: boolean)
		transmitting[player] = nil
		player:SetAttribute("Transmitting", nil)
		if success then
			win(player)
		else
			local text = "¡La transmisión falló! Destruyeron tu caja fuerte. Todavía tienes la frecuencia: inténtalo otra vez"
			notice:FireClient(player, text, "bad")
		end
	end)
end

function VictoryService.Start()
	TycoonService.OnTransmit = transmit
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		transmitting[player] = nil
	end)
end

return VictoryService
