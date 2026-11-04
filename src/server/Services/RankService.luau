-- Rangos y medallas (Config/Ranks). Lo que se cuenta se guarda en el perfil (profile.stats y
-- profile.medals). Se publica en atributos para la pantalla de medallas (UI/Medals):
-- "Kills", "Rank" y "Medals" (las que tienes, en JSON). El rango también sale en la tabla de
-- jugadores (leaderstats).
-- También las misiones (Config/Missions): las que siguen se publican en el atributo "Missions"
-- (JSON: { { text, have, goal, reward } }) y al cumplir una se paga su premio.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Buildings = require(ReplicatedStorage.Shared.Config.Buildings)
local Format = require(ReplicatedStorage.Shared.Format)
local Missions = require(ReplicatedStorage.Shared.Config.Missions)
local Ranks = require(ReplicatedStorage.Shared.Config.Ranks)
local DataService = require(script.Parent.DataService)

local notice = ReplicatedStorage.Remotes.Notice :: RemoteEvent

local RankService = {}

-- Cuánto lleva de cada cosa que cuentan las medallas
local function statOf(profile: DataService.Profile, stat: string): number
	if stat == "record" then
		return profile.record
	elseif stat == "buildings" then
		local count = 0
		for _ in profile.owned do
			count += 1
		end
		return count
	elseif stat == "wall" then
		return Buildings.LevelOf(profile.owned, "wall")
	elseif stat == "research" then
		local count = 0
		for _, level in profile.research do
			count += level
		end
		return count
	end
	return profile.stats[stat] or 0
end

local function publish(player: Player, profile: DataService.Profile)
	local kills = profile.stats.kills or 0
	local rank = Ranks.Of(kills)
	player:SetAttribute("Kills", kills)
	player:SetAttribute("Rank", rank.name)
	player:SetAttribute("Medals", HttpService:JSONEncode(profile.medals))
	-- Las misiones que siguen
	local upcoming = {}
	for _, mission in Missions.list do
		if #upcoming < Missions.shown and not profile.missions[mission.key] then
			local have = math.min(statOf(profile, mission.stat), mission.goal)
			table.insert(upcoming, { text = mission.text, have = have, goal = mission.goal, reward = mission.reward })
		end
	end
	player:SetAttribute("Missions", HttpService:JSONEncode(upcoming))
	-- El objetivo principal
	local main = { text = Missions.done }
	local target = nil
	for _, goal in Missions.main do
		local have = statOf(profile, goal.stat)
		if have < goal.goal then
			main = { text = goal.text, have = have, goal = goal.goal }
			target = goal.target
			break
		end
	end
	-- Ya tiene la frecuencia: ahora va a su caja (aunque el contador diga otra cosa)
	if profile.frequency then
		target = "vault"
	end
	player:SetAttribute("MainObjective", HttpService:JSONEncode(main))
	player:SetAttribute("ObjectiveTarget", target) -- la marca en la pantalla (ObjectiveMarker)
	local stats = player:FindFirstChild("leaderstats")
	local value = stats and stats:FindFirstChild("Rango") :: StringValue?
	if stats and not value then
		value = Instance.new("StringValue")
		value.Name = "Rango"
		value.Parent = stats
	end
	if value then
		value.Value = rank.name
	end
end

-- Revisa si ya ganó alguna medalla nueva (se llama después de cada cosa que cuenta)
function RankService.Check(player: Player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	for _, medal in Ranks.medals do
		if not profile.medals[medal.key] and statOf(profile, medal.stat) >= medal.goal then
			profile.medals[medal.key] = true
			notice:FireClient(player, string.format("¡Medalla: %s! (%s)", medal.name, medal.description), "great")
		end
	end
	-- Misiones cumplidas: en orden, solo las que se ven en la pantalla
	local shown = 0
	for _, mission in Missions.list do
		if not profile.missions[mission.key] and shown < Missions.shown then
			shown += 1
			if statOf(profile, mission.stat) >= mission.goal then
				profile.missions[mission.key] = true
				shown -= 1 -- deja lugar para la que sigue
				DataService.AddMoney(player, mission.reward)
				local text = string.format("¡Misión cumplida: %s! +%s", mission.text, Format.Money(mission.reward))
				notice:FireClient(player, text, "great")
			end
		end
	end
	publish(player, profile)
end

-- Suma uno a algo que se cuenta ("ignites", "bosses"...)
function RankService.Count(player: Player, stat: string, amount: number?)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	profile.stats[stat] = (profile.stats[stat] or 0) + (amount or 1)
	RankService.Check(player)
end

-- Mataste a un zombi con tus balas. Si con eso subes de rango, se avisa
function RankService.Kill(player: Player, headshot: boolean, boss: boolean)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local before = Ranks.Of(profile.stats.kills or 0)
	profile.stats.kills = (profile.stats.kills or 0) + 1
	if headshot then
		profile.stats.headshots = (profile.stats.headshots or 0) + 1
	end
	if boss then
		profile.stats.bosses = (profile.stats.bosses or 0) + 1
	end
	local after = Ranks.Of(profile.stats.kills)
	if after ~= before then
		notice:FireClient(player, "¡Subiste de rango: " .. after.name .. "!", "great")
	end
	RankService.Check(player)
end

return RankService
