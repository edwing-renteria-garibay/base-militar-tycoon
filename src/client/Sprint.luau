-- Correr, igual que en Escuadrón Cero: mantén Shift (L3 en mando) para ir más rápido. En
-- celular sale un botón "Correr": tócalo una vez para correr y otra para dejar de correr.
-- Solo corre el jugador: los zombis caminan a su velocidad (Config/Waves).
--
-- La velocidad de tu personaje la controla tu propio cliente, así que basta con cambiar
-- WalkSpeed aquí.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local WALK_SPEED = 16 -- lo normal en Roblox
local SPRINT_SPEED = 24

local Sprint = {}

local function getHumanoid(): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function setRunning(running: boolean)
	local humanoid = getHumanoid()
	if humanoid and humanoid.Health > 0 then
		humanoid.WalkSpeed = if running then SPRINT_SPEED else WALK_SPEED
	end
end

local function onAction(_name: string, state: Enum.UserInputState, input: InputObject)
	if input.UserInputType == Enum.UserInputType.Touch then
		-- En celular: un toque prende y otro apaga
		if state == Enum.UserInputState.Begin then
			local humanoid = getHumanoid()
			setRunning(humanoid ~= nil and humanoid.WalkSpeed < SPRINT_SPEED)
		end
	elseif state == Enum.UserInputState.Begin then
		setRunning(true)
	else
		setRunning(false) -- soltaste la tecla (o se canceló)
	end
	return Enum.ContextActionResult.Pass
end

function Sprint.Start()
	ContextActionService:BindAction("Sprint", onAction, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
	ContextActionService:SetTitle("Sprint", "Correr")
	ContextActionService:SetPosition("Sprint", UDim2.new(1, -160, 1, -150))
end

return Sprint
