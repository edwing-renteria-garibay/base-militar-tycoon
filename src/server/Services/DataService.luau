-- El dinero y la base de cada jugador, y su guardado.
--
-- Cada jugador tiene un "perfil" que se guarda en un DataStore (el almacenamiento de Roblox
-- que no se borra al salir del juego):
--   money = el dinero que tiene para gastar
--   vault = el dinero que está en la caja fuerte, sin cobrar
--   owned = lo que ya construyó: { Caja2 = true, Torre1 = true, ... }
--   wave     = la ola que sigue (si sale y vuelve, sigue desde ahí)
--   record   = la ola más alta que ha pasado
--   weapons  = las armas que compró en la armería: { Escopeta = true, ... }
--   ammo     = sus balas: { Escopeta = 24, ... }
--   snipers  = las torres que tienen francotirador contratado: { Torre1 = true, ... }
--   research = lo investigado en el laboratorio: { Balas = 2, ... }, y lo que se está
--              investigando: researching = { key, finish } (finish = os.time() al terminar)
--   premium  = defensas premium compradas y sin colocar: { TorretaPesada = 1, ... }
--   placed   = las defensas premium ya colocadas: { { key, x, z, rot }, ... }. Se pierden si
--              destruyen tu caja fuerte
--   medkits  = cuántos botiquines carga (Waves.medkit); antidotes = cuántos antídotos
--   barricades = las hileras de barricadas: { { ax, az, bx, bz, pedazos }, ... }
--   daily    = premio diario: el último día que lo cobró y cuántos días seguidos lleva
--   receipts = compras con Robux ya entregadas (para no darlas dos veces)
--
-- En Studio el DataStore solo funciona si el juego está publicado y activaste "Enable Studio
-- Access to API Services". Si no, todo funciona igual, pero no guarda nada.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Premium = require(ReplicatedStorage.Shared.Config.Premium)
local Settings = require(ReplicatedStorage.Shared.Config.Settings)

local DataService = {}

export type Profile = {
	money: number,
	vault: number,
	owned: { [string]: boolean },
	wave: number,
	record: number,
	weapons: { [string]: boolean },
	ammo: { [string]: number },
	snipers: { [string]: boolean },
	research: { [string]: number },
	researching: { key: string, finish: number }?,
	premium: { [string]: number },
	placed: { { key: string, x: number, z: number, rot: number } },
	barricades: { { number } },
	medkits: number,
	antidotes: number,
	daily: { last: number, streak: number },
	receipts: { string },
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
	player:SetAttribute("Record", profile.record)
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		local money = stats:FindFirstChild("Dinero") :: IntValue?
		local record = stats:FindFirstChild("Récord") :: IntValue?
		if money then
			money.Value = math.floor(profile.money)
		end
		if record then
			record.Value = profile.record
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
		wave = 1,
		record = 0,
		weapons = {},
		ammo = {},
		snipers = {},
		research = {},
		researching = nil,
		premium = {},
		placed = {},
		barricades = {},
		daily = { last = 0, streak = 0 },
		receipts = {},
		medkits = 0,
		antidotes = 0,
	}
	if store then
		local ok, data = pcall(function()
			return (store :: DataStore):GetAsync(keyOf(player))
		end)
		if ok and type(data) == "table" then
			profile.money = tonumber(data.money) or profile.money
			profile.vault = tonumber(data.vault) or 0
			profile.owned = if type(data.owned) == "table" then data.owned else {}
			profile.wave = math.max(1, tonumber(data.wave) or 1)
			profile.record = tonumber(data.record) or 0
			profile.weapons = if type(data.weapons) == "table" then data.weapons else {}
			profile.ammo = if type(data.ammo) == "table" then data.ammo else {}
			profile.snipers = if type(data.snipers) == "table" then data.snipers else {}
			profile.research = if type(data.research) == "table" then data.research else {}
			profile.researching = if type(data.researching) == "table" then data.researching else nil
			profile.premium = if type(data.premium) == "table" then data.premium else {}
			profile.placed = if type(data.placed) == "table" then data.placed else {}
			profile.barricades = if type(data.barricades) == "table" then data.barricades else {}
			profile.medkits = tonumber(data.medkits) or 0
			profile.antidotes = tonumber(data.antidotes) or 0
			if type(data.daily) == "table" then
				profile.daily.last = tonumber(data.daily.last) or 0
				profile.daily.streak = tonumber(data.daily.streak) or 0
			end
			profile.receipts = if type(data.receipts) == "table" then data.receipts else {}
		elseif not ok then
			warn("[Datos] No se pudo cargar a", player.Name, data)
		end
	end
	if testing then
		-- Para probar a colocar defensas premium sin pagar Robux
		for _, item in Premium.list do
			profile.premium[item.key] = Settings.Testing.premium
		end
	end
	profiles[player] = profile

	-- La tabla de jugadores de Roblox (arriba a la derecha) muestra el dinero y el récord
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local value = Instance.new("IntValue")
	value.Name = "Dinero"
	value.Parent = stats
	local record = Instance.new("IntValue")
	record.Name = "Récord"
	record.Parent = stats
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

-- Guarda en seguida (después de una compra con Robux). Devuelve si se pudo
function DataService.SaveNow(player: Player): boolean
	local profile = profiles[player]
	if not store or not profile then
		return true -- sin DataStore no hay nada que guardar
	end
	local ok, err = pcall(function()
		(store :: DataStore):SetAsync(keyOf(player), profile)
	end)
	if not ok then
		warn("[Datos] No se pudo guardar a", player.Name, err)
	end
	return ok
end

-- Pasó la ola n: sigue la n + 1 y, si es la más alta, es su nuevo récord
function DataService.WaveCleared(player: Player, n: number)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.wave = n + 1
	profile.record = math.max(profile.record, n)
	publish(player)
end

-- Perdió la caja fuerte: vuelve a la ola 1 (el récord se queda)
function DataService.ResetWave(player: Player)
	local profile = profiles[player]
	if profile then
		profile.wave = 1
	end
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
