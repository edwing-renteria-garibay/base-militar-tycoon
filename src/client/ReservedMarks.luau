-- Mientras pones barricadas o defensas premium, se pintan de rojo en el piso los lugares donde
-- no se puede (los de src/shared/Placement.luau: edificios, sus botones, la caja fuerte y
-- donde apareces). Así se ve de antemano dónde sí cabe.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Placement = require(ReplicatedStorage.Shared.Placement)

local player = Players.LocalPlayer

local COLOR = Color3.fromRGB(230, 60, 50)

local ReservedMarks = {}

local folder: Folder? = nil
local users: { [string]: boolean } = {} -- qué pantallas lo están pidiendo ("Barricadas", "Colocar")

local function flatPart(parent: Instance, size: Vector3, cframe: CFrame, transparency: number): Part
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cframe
	p.Color = COLOR
	p.Material = Enum.Material.Neon
	p.Transparency = transparency
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false -- el mouse los atraviesa
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

local function build(center: CFrame): Folder
	local f = Instance.new("Folder")
	f.Name = "ZonasReservadas"
	for _, rect in Placement.zones.rects do
		local o = center * CFrame.new(rect.x, 0.15, rect.z) * CFrame.Angles(0, math.rad(rect.rot), 0)
		local w, d = rect.half.X * 2, rect.half.Y * 2
		flatPart(f, Vector3.new(w, 0.05, d), o, 0.8) -- relleno
		-- La orilla, más fuerte
		flatPart(f, Vector3.new(w, 0.1, 0.3), o * CFrame.new(0, 0, -d / 2), 0.2)
		flatPart(f, Vector3.new(w, 0.1, 0.3), o * CFrame.new(0, 0, d / 2), 0.2)
		flatPart(f, Vector3.new(0.3, 0.1, d), o * CFrame.new(-w / 2, 0, 0), 0.2)
		flatPart(f, Vector3.new(0.3, 0.1, d), o * CFrame.new(w / 2, 0, 0), 0.2)
	end
	for _, circle in Placement.zones.circles do
		local disc = flatPart(
			f,
			Vector3.new(0.05, circle.r * 2, circle.r * 2),
			center * CFrame.new(circle.x, 0.15, circle.z) * CFrame.Angles(0, 0, math.pi / 2),
			0.6
		)
		disc.Shape = Enum.PartType.Cylinder
	end
	return f
end

-- who: qué pantalla lo pide. show = true al entrar a colocar, false al salir
function ReservedMarks.Show(who: string, show: boolean)
	users[who] = if show then true else nil
	local visible = next(users) ~= nil
	local center = player:GetAttribute("PlotCenter")
	if visible and not folder and typeof(center) == "CFrame" then
		folder = build(center)
	end
	if folder then
		folder.Parent = if visible then workspace else nil
	end
end

return ReservedMarks
