-- Invitar amigos: el botón INVITAR (abajo, junto a BARRICADAS) o la tecla I abre la ventana de Roblox para
-- invitar amigos. El amigo que acepta entra a este mismo servidor, con su propio terreno, y
-- puede ayudarte a matar a tus zombis (las balas le pegan a cualquier zombi).

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local SocialService = game:GetService("SocialService")

local Menus = require(script.Parent.Parent.Menus)

local player = Players.LocalPlayer

local InviteUI = {}

function InviteUI.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Invitar"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(0, 1)
	button.Position = UDim2.new(0, 552, 1, -12)
	button.Size = UDim2.fromOffset(140, 44)
	button.BackgroundColor3 = Color3.fromRGB(60, 120, 200)
	button.Font = Enum.Font.GothamBlack
	button.Text = "INVITAR · I"
	button.TextSize = 18
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button

	local function invite()
		-- Roblox dice si se puede (por ejemplo, en Studio o con cuentas restringidas no)
		local ok, can = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
		if ok and can then
			Menus.SetOpen("Invitar", true) -- suelta el mouse para usar la ventana
			SocialService:PromptGameInvite(player)
		else
			button.Text = "No disponible"
			task.delay(2, function()
				button.Text = "INVITAR · I"
			end)
		end
	end
	button.Activated:Connect(invite)
	ContextActionService:BindAction("Invite", function(_, state)
		if state == Enum.UserInputState.Begin then
			task.spawn(invite)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.I)
	SocialService.GameInvitePromptClosed:Connect(function()
		Menus.SetOpen("Invitar", false)
	end)
end

return InviteUI
