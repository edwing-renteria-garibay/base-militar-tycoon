-- Los faroles del terreno (Buildings.lamps): un poste con una lámpara de luz anaranjada que a
-- veces parpadea. De noche son casi la única luz. Si les disparas (aunque sea por error) se
-- rompe el vidrio y se apagan; se arreglan solos al pasar la ola (TycoonService).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Buildings = require(ReplicatedStorage.Shared.Config.Buildings)
local Effects = require(script.Parent.Effects)

local LIGHT = Color3.fromRGB(255, 170, 90)
local BROKEN = Color3.fromRGB(40, 38, 35)
local POLE = Color3.fromRGB(45, 45, 48)
local TAG = "Farol" -- la lámpara de cada farol lleva esta etiqueta (así WeaponService la reconoce)

local Lamps = {}

local function newPart(parent: Instance, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false -- los zombis pasan sin atorarse
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function setLit(bulb: BasePart, lit: boolean)
	bulb.Color = if lit then LIGHT else BROKEN
	bulb.Material = if lit then Enum.Material.Neon else Enum.Material.Glass
	local light = bulb:FindFirstChildOfClass("PointLight")
	if light then
		light.Enabled = lit
	end
	bulb:SetAttribute("Broken", not lit)
end

-- Pone los faroles de un terreno en la carpeta folder
function Lamps.Build(center: CFrame, folder: Instance)
	for _, spot in Buildings.lamps do
		local base = center * CFrame.new(spot[1], 0, spot[2])
		local lamp = Instance.new("Model")
		lamp.Name = "Farol"
		newPart(lamp, Vector3.new(0.6, 12, 0.6), base * CFrame.new(0, 6, 0), POLE, Enum.Material.Metal)
		newPart(lamp, Vector3.new(1.4, 0.4, 1.4), base * CFrame.new(0, 0.2, 0), POLE, Enum.Material.Metal)
		newPart(lamp, Vector3.new(1.6, 0.3, 1.6), base * CFrame.new(0, 13.2, 0), POLE, Enum.Material.Metal)
		local bulb = newPart(lamp, Vector3.new(1.1, 1.1, 1.1), base * CFrame.new(0, 12.5, 0), LIGHT, Enum.Material.Neon)
		bulb.Name = "Lampara"
		local light = Instance.new("PointLight")
		light.Color = LIGHT
		light.Range = 34
		light.Brightness = 2
		light.Shadows = true
		light.Parent = bulb
		CollectionService:AddTag(bulb, TAG)
		setLit(bulb, true)
		lamp.Parent = folder
	end
end

-- ¿Esta pieza es la lámpara de un farol? (la que se rompe de un balazo)
function Lamps.IsLamp(part: Instance): boolean
	return CollectionService:HasTag(part, TAG)
end

-- Le dieron un balazo: se rompe el vidrio y se apaga
function Lamps.Break(bulb: BasePart)
	if bulb:GetAttribute("Broken") then
		return
	end
	setLit(bulb, false)
	Effects.Hit(bulb.Position)
end

-- Arregla todos los faroles de esa carpeta
function Lamps.FixAll(folder: Instance)
	for _, bulb in CollectionService:GetTagged(TAG) do
		if bulb:IsDescendantOf(folder) then
			setLit(bulb, true)
		end
	end
end

-- De vez en cuando un farol parpadea (para que se vea lúgubre)
function Lamps.Start()
	task.spawn(function()
		while true do
			task.wait(0.4)
			local bulbs = CollectionService:GetTagged(TAG)
			local bulb = bulbs[math.random(math.max(#bulbs, 1))]
			if bulb and not bulb:GetAttribute("Broken") and math.random() < 0.5 then
				local light = bulb:FindFirstChildOfClass("PointLight")
				for _ = 1, math.random(2, 4) do
					if light then
						light.Enabled = false
					end
					bulb.Material = Enum.Material.Glass
					task.wait(0.06 + math.random() * 0.08)
					if bulb:GetAttribute("Broken") then
						break
					end
					if light then
						light.Enabled = true
					end
					bulb.Material = Enum.Material.Neon
					task.wait(0.05 + math.random() * 0.1)
				end
			end
		end
	end)
end

return Lamps
