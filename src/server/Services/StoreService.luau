-- Las compras con Robux (Config/Store) y el premio diario.
--
-- Pases: Roblox recuerda quién los compró, así que no se guardan en el perfil. Al entrar se
-- pregunta a Roblox y, si lo tiene, se marca con el atributo "Pass_x2", "Pass_VIP"... Lo
-- demás del juego solo lee esos atributos (TycoonService para el dinero, WeaponService para
-- la munición x2).
--
-- Paquetes (dinero, defensas premium, bomba, vida extra...): Roblox llama a processReceipt y
-- solo da por buena la compra si devolvemos PurchaseGranted. Si algo falla devolvemos
-- NotProcessedYet y Roblox lo reintenta después, así el jugador nunca pierde sus Robux.
--
-- En Studio (modo prueba) los paquetes que aún no tienen ID se pueden "comprar" gratis con el
-- botón Probar de la tienda (RemoteEvent "Power", "test"), para probarlos antes de publicar.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local Settings = require(ReplicatedStorage.Shared.Config.Settings)
local Store = require(ReplicatedStorage.Shared.Config.Store)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local TycoonService = require(script.Parent.TycoonService)
local WaveService = require(script.Parent.WaveService)

local notice = ReplicatedStorage.Remotes.Notice :: RemoteEvent
local powerRemote = ReplicatedStorage.Remotes.Power :: RemoteEvent

local MAX_RECEIPTS = 50

local StoreService = {}

local function grantPass(player: Player, key: string)
	player:SetAttribute("Pass_" .. key, true)
	if key == "VIP" then
		PlotService.SetVIP(player)
	end
end

-- Lo que se guarda en el perfil y se usa con un botón: { kind, campo del perfil, atributo }
local COUNTERS = {
	antidote = { "antidotes", "Antidotes" },
	nuke = { "nukes", "Nukes" },
	airstrike = { "strikes", "Strikes" },
	life = { "lives", "Lives" },
}

-- Pregunta a Roblox qué pases tiene el jugador (y publica lo que tiene guardado de la tienda)
function StoreService.CheckPasses(player: Player)
	local profile = DataService.Get(player) :: any
	if profile then
		for _, counter in COUNTERS do
			player:SetAttribute(counter[2], profile[counter[1]])
		end
		player:SetAttribute("Starter", profile.starter)
	end
	for _, pass in Store.passes do
		if pass.id ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
			end)
			if ok and owns then
				grantPass(player, pass.key)
			end
		end
	end
end

-- Premio diario: si hoy no lo ha cobrado, se le da. Días seguidos = premio más grande
function StoreService.GiveDaily(player: Player)
	local profile = DataService.Get(player)
	if not profile or Settings.Testing.enabled then
		return
	end
	local today = math.floor(os.time() / 86400) -- días desde 1970 (cambia a medianoche UTC)
	local daily = profile.daily
	if daily.last == today then
		return
	end
	daily.streak = if daily.last == today - 1 then daily.streak + 1 else 1
	daily.last = today
	local minutes = Store.daily.minutes[math.min(daily.streak, #Store.daily.minutes)]
	local reward = math.max(Store.daily.minimum, TycoonService.IncomeOf(player) * minutes * 60)
	DataService.AddMoney(player, reward)
	local text = string.format("Premio diario: +%s", Format.Money(reward))
	if daily.streak > 1 then
		text ..= string.format(" (%d días seguidos)", daily.streak)
	end
	notice:FireClient(player, text, "great")
end

local function onPassPurchased(player: Player, passId: number, purchased: boolean)
	if not purchased then
		return
	end
	for _, pass in Store.passes do
		if pass.id ~= 0 and pass.id == passId then
			grantPass(player, pass.key)
			notice:FireClient(player, "¡Gracias! Ya tienes " .. pass.name, "great")
		end
	end
end

-- Da lo comprado. Devuelve dos funciones: undo lo quita (si no se pudo guardar) y done hace lo
-- que ya no se puede deshacer (reparar, mandar refuerzos) y avisa al jugador
local function grant(player: Player, profile: any, product): (() -> (), () -> ())
	local amount = product.amount or 1
	local counter = COUNTERS[product.kind]
	if counter then
		local field, attribute = counter[1], counter[2]
		profile[field] += amount
		return function()
			profile[field] -= amount
		end, function()
			player:SetAttribute(attribute, profile[field])
			local how = if product.kind == "nuke"
				then " (tecla N durante la ola)"
				elseif product.kind == "airstrike" then " (tecla J durante la ola)"
				else ""
			notice:FireClient(player, string.format("¡Gracias! Ya tienes %s%s", product.name, how), "great")
		end
	elseif product.kind == "defense" then
		profile.premium[product.key] = (profile.premium[product.key] or 0) + amount
		return function()
			profile.premium[product.key] -= amount
		end, function()
			player:SetAttribute("Premium_" .. product.key, profile.premium[product.key])
			notice:FireClient(player, string.format("¡Gracias! Coloca tu %s con el botón COLOCAR", product.name), "great")
		end
	elseif product.kind == "repair" then
		return function() end, function()
			TycoonService.RepairEverything(player)
			notice:FireClient(player, "¡Todo reparado al 100%!", "great")
		end
	elseif product.kind == "squad" then
		return function() end, function()
			WaveService.Reinforce(player)
		end
	elseif product.kind == "starter" then
		local starter = Store.starter
		profile.starter = true
		profile.premium[starter.defense] = (profile.premium[starter.defense] or 0) + 1
		profile.medkits += starter.medkits
		DataService.AddMoney(player, starter.money)
		return function()
			profile.starter = false
			profile.premium[starter.defense] -= 1
			profile.medkits -= starter.medkits
			DataService.Spend(player, starter.money)
		end, function()
			player:SetAttribute("Starter", true)
			player:SetAttribute("Premium_" .. starter.defense, profile.premium[starter.defense])
			player:SetAttribute("Medkits", profile.medkits)
			notice:FireClient(player, "¡Gracias! Paquete inicial: dinero, torreta pesada y botiquines", "great")
		end
	end
	-- "money": lo que genera tu base en un rato
	local money = math.max(product.minimum, TycoonService.IncomeOf(player) * product.seconds)
	DataService.AddMoney(player, money)
	return function()
		DataService.Spend(player, money)
	end, function()
		notice:FireClient(player, string.format("¡Gracias! +%s", Format.Money(money)), "great")
	end
end

local function processReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local profile = player and DataService.Get(player)
	if not player or not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(receipt.PurchaseId)
	if table.find(profile.receipts, purchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- ya se había dado
	end
	local product = nil
	for _, candidate in Store.products do
		if candidate.id ~= 0 and candidate.id == receipt.ProductId then
			product = candidate
		end
	end
	if not product then
		warn("[Tienda] Producto desconocido", receipt.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local undo, done = grant(player, profile, product)
	table.insert(profile.receipts, purchaseId)
	if #profile.receipts > MAX_RECEIPTS then
		table.remove(profile.receipts, 1)
	end
	if not DataService.SaveNow(player) then
		-- No se guardó: se deshace y Roblox lo reintenta después
		undo()
		table.remove(profile.receipts)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	done()
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- Botón Probar de la tienda (solo en Studio): da el paquete sin pagar
local function onTest(player: Player, what: any, key: any)
	local profile = DataService.Get(player)
	if what ~= "test" or not Settings.Testing.enabled or not profile then
		return
	end
	for _, product in Store.products do
		if product.key == key then
			local _, done = grant(player, profile, product)
			done()
		end
	end
end

function StoreService.Start()
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(onPassPurchased)
	MarketplaceService.ProcessReceipt = processReceipt
	powerRemote.OnServerEvent:Connect(onTest)
end

return StoreService
