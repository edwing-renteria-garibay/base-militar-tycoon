-- El dinero y la base de cada jugador, y su guardado.
--
-- Cada jugador tiene un "perfil" que se guarda en un DataStore (el almacenamiento de Roblox
-- que no se borra al salir del juego):
--   money = el dinero que tiene para gastar
--   vault = el dinero que está en la caja fuerte, sin cobrar
--   owned = lo que ya construyó: { Bandera = true, Sacos = true, ... }
--   rebirths = cuántas veces ha renacido (cada vez, su base genera más)
--
-- En Studio el DataStore solo funciona si el juego está publicado y activaste "Enable Studio
-- Access to API Services". Si no, todo funciona igual, pero no guarda nada.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Settings = require(ReplicatedStorage.Shared.Config.Settings)

local DataService = {}

export type Profile = {
	money: number,
	vault: number,
	owned: { [string]: boolean },
	rebirths: number,
}

-- Avisa cuando cambia el dinero de alguien (para pintar los botones que ya le alcanzan)
DataService.MoneyChanged = Instance.new("BindableEvent")

local profiles: { [Player]: Profile } = {}
local testing = Settings.Testing.enabled

local store: DataStore? = nil
if not testing then
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Settings.saveKey)
	end)
	if ok then
		store = result
	else
		warn("[Datos] No hay DataStore (¿juego sin publicar?). No se guardará nada.")
	end
end

local function keyOf(player: Player): string
	return "jugador_" .. player.UserId
end

local function save(player: Player)
	local profile = profiles[player]
	if not store or not profile then
		return
	end
	local ok, err = pcall(function()
		(store :: DataStore):SetAsync(keyOf(player), profile)
	end)
	if not ok then
		warn("[Datos] No se pudo guardar a", player.Name, err)
	end
end

local function publish(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	player:SetAttribute("Money", profile.money) -- lo lee la pantalla de dinero
	player:SetAttribute("Rebirths", profile.rebirths)
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		local money = stats:FindFirstChild("Dinero") :: IntValue?
		local rebirths = stats:FindFirstChild("Renacer") :: IntValue?
		if money then
			money.Value = math.floor(profile.money)
		end
		if rebirths then
			rebirths.Value = profile.rebirths
		end
	end
	DataService.MoneyChanged:Fire(player)
end

-- Carga el perfil (tarda un momento: pregunta al DataStore)
function DataService.Load(player: Player): Profile
	local profile: Profile = {
		money = if testing then Settings.Testing.startMoney else Settings.startMoney,
		vault = 0,
		owned = {},
		rebirths = 0,
	}
	if store then
		local ok, data = pcall(function()
			return (store :: DataStore):GetAsync(keyOf(player))
		end)
		if ok and type(data) == "table" then
			profile.money = tonumber(data.money) or profile.money
			profile.vault = tonumber(data.vault) or 0
			profile.owned = if type(data.owned) == "table" then data.owned else {}
			profile.rebirths = tonumber(data.rebirths) or 0
		elseif not ok then
			warn("[Datos] No se pudo cargar a", player.Name, data)
		end
	end
	profiles[player] = profile

	-- La tabla de jugadores de Roblox (arriba a la derecha) muestra el dinero
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local value = Instance.new("IntValue")
	value.Name = "Dinero"
	value.Parent = stats
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Renacer"
	rebirths.Parent = stats
	stats.Parent = player
	publish(player)
	return profile
end

function DataService.Get(player: Player): Profile?
	return profiles[player]
end

function DataService.AddMoney(player: Player, amount: number)
	local profile = profiles[player]
	if profile and amount > 0 then
		profile.money += amount
		publish(player)
	end
end

-- Gasta dinero si le alcanza. Devuelve si se pudo
function DataService.Spend(player: Player, amount: number): boolean
	local profile = profiles[player]
	if not profile or profile.money < amount then
		return false
	end
	profile.money -= amount
	publish(player)
	return true
end

-- Renacer: borra la base y el dinero, y suma un renacimiento. Se guarda en seguida
function DataService.Rebirth(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.rebirths += 1
	profile.money = if testing then Settings.Testing.startMoney else Settings.startMoney
	profile.vault = 0
	profile.owned = {}
	publish(player)
	task.spawn(save, player)
end

-- Al salir: guarda y olvida el perfil
function DataService.Release(player: Player)
	save(player)
	profiles[player] = nil
end

function DataService.Start()
	-- Al cerrar el servidor se guarda a todos los que siguen dentro
	game:BindToClose(function()
		for player in profiles do
			task.spawn(save, player)
		end
		task.wait(3)
	end)
	task.spawn(function()
		while true do
			task.wait(Settings.autosave)
			for player in profiles do
				task.spawn(save, player)
			end
		end
	end)
end

return DataService
