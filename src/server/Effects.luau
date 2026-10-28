-- Efectos que usan varios servicios: los disparos y las explosiones.
--
-- El servidor solo avisa a todos los jugadores con el RemoteEvent "Fx"; cada uno dibuja la
-- línea de la bala, el fogonazo y el impacto, y oye el sonido (src/client/Fx.luau). Son los
-- mismos efectos y sonidos de Escuadrón Cero.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local fx = ReplicatedStorage.Remotes.Fx :: RemoteEvent

local Effects = {}

-- Qué tocó la bala, para el color del impacto y su sonido
local METAL = {
	[Enum.Material.Metal] = true,
	[Enum.Material.DiamondPlate] = true,
}
local WOOD = {
	[Enum.Material.Wood] = true,
	[Enum.Material.WoodPlanks] = true,
}
function Effects.SurfaceOf(part: BasePart?): string?
	if not part then
		return nil -- no le dio a nada
	end
	if METAL[part.Material] then
		return "metal"
	elseif WOOD[part.Material] then
		return "wood"
	end
	return "concrete"
end

-- Un disparo de from a to. sound: su sonido en Config/Sounds (nil = sin sonido, por ejemplo
-- las otras balas de la escopeta). surface: qué tocó ("flesh" = un zombi o una persona)
function Effects.Shot(from: Vector3, to: Vector3, sound: string?, surface: string?)
	fx:FireAllClients("shot", from, to, sound, surface)
end

-- Una explosión que solo se ve y se oye: no empuja ni rompe nada (el daño lo pone quien la llama)
function Effects.Explosion(position: Vector3, radius: number)
	local explosion = Instance.new("Explosion")
	explosion.Position = position
	explosion.BlastRadius = radius
	explosion.BlastPressure = 0
	explosion.DestroyJointPercent = 0
	explosion.Parent = workspace
	fx:FireAllClients("explosion", position)
end

return Effects
