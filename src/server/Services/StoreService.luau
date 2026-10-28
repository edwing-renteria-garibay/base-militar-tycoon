-- Las compras con Robux (Config/Store) y el premio diario.
--
-- Pases: Roblox recuerda quién los compró, así que no se guardan en el perfil. Al entrar se
-- pregunta a Roblox y, si lo tiene, se marca con el atributo "Pass_x2", "Pass_VIP"... Lo
-- demás del juego solo lee esos atributos (TycoonService para el dinero, WeaponService para
-- la munición x2).
--
-- Paquetes (la bolsa de dinero y las defensas premium): Roblox llama a processReceipt y solo da por buena la compra
-- si devolvemos PurchaseGranted. Si algo falla devolvemos NotProcessedYet y Roblox lo
-- reintenta después, así el jugador nunca pierde sus Robux.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local Settings = require(ReplicatedStorage.Shared.Config.Settings)
local Store = require(ReplicatedStorage.Shared.Config.Store)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local TycoonService = require(script.Parent.TycoonService)

local notice = ReplicatedStorage.Remotes.Notice :: RemoteEvent

local MAX_RECEIPTS = 50

local StoreService = {}

local function grantPass(player: Player, key: string)
	player:SetAttribute("Pass_" .. key, true)
	if key == "VIP" then
		PlotService.SetVIP(player)
	end
end

-- Pregunta a Roblox qué pases tiene el jugador
function StoreService.CheckPasses(player: Player)
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
	-- Lo que da: dinero, o una defensa premium para colocar
	local amount = 0
	if product.kind == "defense" then
		profile.premium[product.key] = (profile.premium[product.key] or 0) + 1
	else
		amount = math.max(product.minimum, TycoonService.IncomeOf(player) * product.seconds)
		DataService.AddMoney(player, amount)
	end
	table.insert(profile.receipts, purchaseId)
	if #profile.receipts > MAX_RECEIPTS then
		table.remove(profile.receipts, 1)
	end
	if not DataService.SaveNow(player) then
		-- No se guardó: se deshace y Roblox lo reintenta después
		if product.kind == "defense" then
			profile.premium[product.key] -= 1
		else
			DataService.Spend(player, amount)
		end
		table.remove(profile.receipts)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if product.kind == "defense" then
		player:SetAttribute("Premium_" .. product.key, profile.premium[product.key])
		notice:FireClient(player, string.format("¡Gracias! Coloca tu %s con el botón COLOCAR", product.name), "great")
	else
		notice:FireClient(player, string.format("¡Gracias! +%s", Format.Money(amount)), "great")
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function StoreService.Start()
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(onPassPurchased)
	MarketplaceService.ProcessReceipt = processReceipt
end

return StoreService
