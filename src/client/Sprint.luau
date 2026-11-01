-- Correr, igual que en Escuadrón Cero: mantén Shift (L3 en mando) para ir más rápido. En
-- celular sale un botón "Correr": tócalo una vez para correr y otra para dejar de correr.
-- Solo corre el jugador: los zombis caminan a su velocidad (Config/Waves).
--
-- La velocidad de tu personaje la controla tu propio cliente, así que basta con cambiar
-- WalkSpeed aquí. Se revisa cada fotograma si tienes Shift apretado (así no importa si otra
-- cosa de Roblox, como el "shift lock", se queda con la tecla).

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local WALK_SPEED = 16 -- lo normal en Roblox
local SPRINT_SPEED = 24

local Sprint = {}

local toggled = false -- con el botón de celular o L3: corre hasta que lo vuelvas a tocar

local function onToggle(_name: string, state: Enum.UserInputState)
	if state == Enum.UserInputState.Begin then
		toggled = not toggled
	end
	return Enum.ContextActionResult.Pass
end

function Sprint.Start()
	ContextActionService:BindAction("Sprint", onToggle, true, Enum.KeyCode.ButtonL3)
	ContextActionService:SetTitle("Sprint", "Correr")
	ContextActionService:SetPosition("Sprint", UDim2.new(1, -160, 1, -150))
	RunService.Heartbeat:Connect(function()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			toggled = false
			return
		end
		local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
			or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
		local speed = if shift or toggled then SPRINT_SPEED else WALK_SPEED
		if humanoid.WalkSpeed ~= speed then
			humanoid.WalkSpeed = speed
		end
	end)
end

return Sprint
