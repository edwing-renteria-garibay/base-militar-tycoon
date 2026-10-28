-- El Laboratorio: investigar más daño (Config/Research).
--
-- 1. El letrero del laboratorio (TycoonService) abre la pantalla de investigar (RemoteEvent
--    "Research", src/client/UI/Lab.luau).
-- 2. Al elegir algo se paga y empieza a investigarse: tarda unos segundos (se ve encima del
--    laboratorio). Solo una cosa a la vez. Sigue aunque salgas del juego (usa os.time()).
-- 3. Al terminar sube su nivel en profile.research; WeaponService y WaveService lo leen con
--    Research.Bonus.
--
-- La pantalla lee los atributos "Research_<key>" (nivel), "ResearchKey" y "ResearchEnds".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local Research = require(ReplicatedStorage.Shared.Config.Research)
local Settings = require(ReplicatedStorage.Shared.Config.Settings)
local DataService = require(script.Parent.DataService)
local TycoonService = require(script.Parent.TycoonService)

local researchRemote = ReplicatedStorage.Remotes.Research :: RemoteEvent
local notice = ReplicatedStorage.Remotes.Notice :: RemoteEvent

local SPEED = if Settings.Testing.enabled then 5 else 1 -- en prueba, 5 veces más rápido

local ResearchService = {}

local function publish(player: Player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	for _, line in Research.lines do
		player:SetAttribute("Research_" .. line.key, profile.research[line.key] or 0)
	end
	local current = profile.researching
	player:SetAttribute("ResearchKey", current and current.key)
	player:SetAttribute("ResearchEnds", current and current.finish)
end

-- Un letrero encima del laboratorio: qué se investiga y cuánto falta
local function updateSign(player: Player)
	local lab = TycoonService.ModelOf(player, "Laboratorio")
	local profile = DataService.Get(player)
	if not lab or not profile then
		return
	end
	local gui = lab:FindFirstChild("Investigando") :: BillboardGui?
	if not gui then
		local box, size = lab:GetBoundingBox()
		local anchor = Instance.new("Part")
		anchor.Name = "LetreroLab"
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.Transparency = 1
		anchor.Size = Vector3.one
		anchor.CFrame = box + Vector3.new(0, size.Y / 2 + 4, 0)
		anchor.Parent = lab
		local newGui = Instance.new("BillboardGui")
		newGui.Name = "Investigando"
		newGui.Adornee = anchor
		newGui.Size = UDim2.fromOffset(260, 50)
		newGui.MaxDistance = 150
		newGui.Parent = lab
		local text = Instance.new("TextLabel")
		text.Name = "Texto"
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.GothamBlack
		text.TextScaled = true
		text.TextColor3 = Color3.fromRGB(90, 255, 120)
		text.TextStrokeTransparency = 0.4
		text.Parent = newGui
		gui = newGui
	end
	local text = (gui :: BillboardGui):FindFirstChild("Texto") :: TextLabel
	local current = profile.researching
	local line = current and Research.byKey[current.key]
	if current and line then
		local left = math.max(0, current.finish - os.time())
		local level = (profile.research[line.key] or 0) + 1
		text.Text = string.format("Investigando %s %d: %d:%02d", line.name, level, left // 60, left % 60)
	else
		text.Text = "Laboratorio: mantén E para investigar"
	end
end

local function start(player: Player, key: any)
	local profile = DataService.Get(player)
	local line = Research.byKey[key]
	if not profile or not line or not TycoonService.Has(player, "lab") then
		return
	end
	if profile.researching then
		notice:FireClient(player, "El laboratorio ya está investigando algo", "bad")
		return
	end
	local level = (profile.research[line.key] or 0) + 1
	local cost = line.levels[level]
	if not cost then
		return -- ya está al máximo
	end
	if not DataService.Spend(player, cost.price) then
		notice:FireClient(player, "Te faltan " .. Format.Money(cost.price - profile.money), "bad")
		return
	end
	profile.researching = { key = line.key, finish = os.time() + math.ceil(cost.time / SPEED) }
	publish(player)
	updateSign(player)
	notice:FireClient(player, string.format("Investigando: %s %d", line.name, level), "good")
end

-- Cada segundo: ¿ya terminó lo que se investiga?
local function tick(player: Player)
	local profile = DataService.Get(player)
	local current = profile and profile.researching
	if profile and current and os.time() >= current.finish then
		local line = Research.byKey[current.key]
		profile.researching = nil
		if line then
			local level = math.min((profile.research[line.key] or 0) + 1, #line.levels)
			profile.research[line.key] = level
			notice:FireClient(player, string.format("¡Investigación lista: %s %d!", line.name, level), "great")
		end
		publish(player)
	end
	updateSign(player)
end

-- Al terminar de cargar su perfil (init.server.luau)
ResearchService.Publish = publish

function ResearchService.Start()
	researchRemote.OnServerEvent:Connect(function(player, action, key)
		if action == "start" then
			start(player, key)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(tick, player)
				if not ok then
					warn("[Laboratorio] Error:", err)
				end
			end
		end
	end)
end

return ResearchService
