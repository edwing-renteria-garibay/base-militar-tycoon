-- Dibuja los disparos y las explosiones que avisa el servidor (src/server/Effects.luau): la
-- línea de la bala, el fogonazo, el destello del impacto y sus sonidos. Copiado de los
-- efectos de Escuadrón Cero.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local Sfx = require(script.Parent.Sfx)

local fx = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Fx") :: RemoteEvent

local Fx = {}

-- Color del destello del impacto según lo que tocó la bala
local IMPACT_COLORS = {
	flesh = Color3.fromRGB(200, 30, 30), -- rojo: le dio a un zombi
	metal = Color3.fromRGB(255, 200, 80), -- chispas amarillas
	wood = Color3.fromRGB(140, 95, 50), -- astillas
	concrete = Color3.fromRGB(150, 140, 120), -- polvo: el suelo o una pared
}

local function effectPart(shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	if shape then
		p.Shape = shape
	end
	return p
end

-- Una línea brillante que se desvanece entre el arma y el impacto
local function drawTracer(from: Vector3, to: Vector3)
	local length = (to - from).Magnitude
	if length < 0.1 then
		return
	end
	local tracer = effectPart()
	tracer.Color = Color3.fromRGB(255, 220, 120)
	tracer.Size = Vector3.new(0.12, 0.12, length)
	tracer.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -length / 2)
	tracer.Parent = workspace
	TweenService:Create(tracer, TweenInfo.new(0.1), { Transparency = 1 }):Play()
	Debris:AddItem(tracer, 0.1)
end

-- Fogonazo en la boca del arma: una luz que dura un instante
local function drawMuzzleFlash(position: Vector3)
	local flash = effectPart(Enum.PartType.Ball)
	flash.Color = Color3.fromRGB(255, 205, 110)
	flash.Size = Vector3.one * 0.5
	flash.Position = position
	local light = Instance.new("PointLight")
	light.Color = flash.Color
	light.Range = 10
	light.Brightness = 3
	light.Parent = flash
	flash.Parent = workspace
	Debris:AddItem(flash, 0.05)
end

local function drawImpact(position: Vector3, surface: string)
	local impact = effectPart(Enum.PartType.Ball)
	impact.Color = IMPACT_COLORS[surface] or IMPACT_COLORS.concrete
	impact.Size = Vector3.one * 0.3
	impact.Position = position
	impact.Parent = workspace
	local grow = if surface == "flesh" then 2 else 1.2 -- en los zombis se ve más grande
	TweenService:Create(impact, TweenInfo.new(0.2), { Size = Vector3.one * grow, Transparency = 1 }):Play()
	Debris:AddItem(impact, 0.2)
end

local function onShot(from: Vector3, to: Vector3, sound: string?, surface: string?)
	if sound then
		drawMuzzleFlash(from)
		Sfx.PlayAt(Sounds.fire[sound], from)
	end
	drawTracer(from, to)
	if surface then
		drawImpact(to, surface)
		Sfx.PlayAt(Sounds.impact[surface], to, 0.5) -- "flesh" no tiene sonido
	end
end

function Fx.Start()
	fx.OnClientEvent:Connect(function(kind: string, ...)
		if kind == "shot" then
			onShot(...)
		elseif kind == "hit" then
			local position = ...
			drawImpact(position, "concrete")
			drawImpact(position + Vector3.new(0, 1, 0), "concrete")
			Sfx.PlayAt(Sounds.impact.concrete, position, 0.8)
		elseif kind == "explosion" then
			local position = ...
			Sfx.PlayAt(Sounds.explosion, position, 1)
		end
	end)
end

return Fx
