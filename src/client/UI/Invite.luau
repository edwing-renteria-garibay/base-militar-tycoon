-- Invitar amigos: el botón INVITAR (abajo, junto a BARRICADAS) o la tecla I abre la ventana de Roblox para
-- invitar amigos. El amigo que acepta entra a este mismo servidor, con su propio terreno, y
-- puede ayudarte a matar a tus zombis (las balas le pegan a cualquier zombi).
--
-- Si Roblox te mandó a otro servidor, sale el botón "IR CON <amigo>": te lleva al servidor de
-- un amigo que está jugando Frecuencia Cero (Player:GetFriendsOnline).

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local SocialService = game:GetService("SocialService")
local TeleportService = game:GetService("TeleportService")

local Layout = require(script.Parent.Parent.Layout)
local Menus = require(script.Parent.Parent.Menus)

local player = Players.LocalPlayer

local InviteUI = {}

function InviteUI.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Invitar"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(140, 44)
	button.BackgroundColor3 = Color3.fromRGB(60, 120, 200)
	button.Font = Enum.Font.GothamBlack
	button.Text = "INVITAR · I"
	button.TextSize = 18
	button.TextColor3 = Color3.new(1, 1, 1)
	Layout.Dock(button, 4)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button

	local function invite()
		-- Roblox dice si se puede (por ejemplo, en Studio o con cuentas restringidas no)
		local ok, can = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
		if ok and can then
			Menus.SetOpen("Invitar", true) -- suelta el mouse para usar la ventana
			local options = Instance.new("ExperienceInviteOptions")
			options.PromptMessage = "¡Ayúdame a defender mi base en Frecuencia Cero!"
			SocialService:PromptGameInvite(player, options)
		else
			button.Text = "No disponible"
			task.delay(2, function()
				button.Text = "INVITAR · I"
			end)
		end
	end
	button.Activated:Connect(invite)
	-- La I también acerca la cámara en Roblox: con prioridad alta, la toma primero la invitación
	ContextActionService:BindActionAtPriority("Invite", function(_, state)
		if state == Enum.UserInputState.Begin then
			task.spawn(invite)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 100, Enum.KeyCode.I)
	SocialService.GameInvitePromptClosed:Connect(function()
		Menus.SetOpen("Invitar", false)
	end)

	-- IR CON <amigo>: aparece si un amigo juega esto mismo, pero en otro servidor
	local join = Instance.new("TextButton")
	join.Size = UDim2.fromOffset(200, 44)
	join.BackgroundColor3 = Color3.fromRGB(60, 170, 110)
	join.Font = Enum.Font.GothamBlack
	join.TextSize = 16
	join.TextColor3 = Color3.new(1, 1, 1)
	join.TextTruncate = Enum.TextTruncate.AtEnd
	join.Visible = false
	local joinCorner = Instance.new("UICorner")
	joinCorner.CornerRadius = UDim.new(0, 10)
	joinCorner.Parent = join
	Layout.Dock(join, 7)
	local target = nil
	join.Activated:Connect(function()
		if not target then
			return
		end
		join.Text = "Yendo..."
		local ok = pcall(TeleportService.TeleportToPlaceInstance, TeleportService, game.PlaceId, target.GameId, player)
		if not ok then
			join.Text = "No se pudo"
		end
	end)
	task.spawn(function()
		while true do
			local ok, friends = pcall(player.GetFriendsOnline, player, 200)
			target = nil
			if ok and type(friends) == "table" then
				for _, friend in friends do
					if friend.PlaceId == game.PlaceId and friend.GameId and friend.GameId ~= game.JobId then
						target = friend
						break
					end
				end
			end
			join.Visible = target ~= nil and game.JobId ~= ""
			if target then
				join.Text = "IR CON " .. string.upper(target.DisplayName or target.UserName or "TU AMIGO")
			end
			task.wait(20)
		end
	end)
end

return InviteUI
