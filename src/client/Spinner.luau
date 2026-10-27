-- Hace girar todo lo que tenga la etiqueta "Spin" (aspas del helicóptero, radar, torretas...).
-- Lo hace cada jugador en su pantalla: el servidor solo dice qué gira y qué tan rápido
-- (atributo "SpinSpeed", en radianes por segundo). Ver spinner() en src/server/Builder.luau.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Spinner = {}

function Spinner.Start()
	RunService.RenderStepped:Connect(function(dt)
		for _, group in CollectionService:GetTagged("Spin") do
			if group:IsA("Model") and group:IsDescendantOf(workspace) then
				local speed = group:GetAttribute("SpinSpeed") or 1
				group:PivotTo(group:GetPivot() * CFrame.Angles(0, speed * dt, 0))
			end
		end
	end)
end

return Spinner
