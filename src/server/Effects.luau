-- Efectos que usan varios servicios: la línea de luz de un disparo.

local Debris = game:GetService("Debris")

local Effects = {}

-- Una línea brillante de from a to que desaparece en un momento (el "rastro" de la bala)
function Effects.Tracer(from: Vector3, to: Vector3, color: Color3?)
	local distance = (to - from).Magnitude
	if distance < 0.1 then
		return
	end
	local beam = Instance.new("Part")
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.Material = Enum.Material.Neon
	beam.Color = color or Color3.fromRGB(255, 220, 120)
	beam.Size = Vector3.new(0.15, 0.15, distance)
	beam.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -distance / 2)
	beam.Parent = workspace
	Debris:AddItem(beam, 0.08)
end

return Effects
