-- Las armas se agarran con las dos manos. Roblox solo pone la herramienta en la mano derecha,
-- así que la mano izquierda se lleva a la agarradera de enfrente con un IKControl ("cinemática
-- inversa": Roblox dobla el hombro y el codo solo para que la mano llegue a un punto).
--
-- El punto es el Attachment "LeftHandGrip" que pone WeaponModels. El IKControl vive en el
-- Humanoid y se replica, así que todos lo ven. Igual que en Escuadrón Cero.

local TwoHands = {}

local IK_NAME = "LeftHandIK"

local function release(humanoid: Humanoid)
	local ik = humanoid:FindFirstChild(IK_NAME)
	if ik then
		ik:Destroy()
	end
end

local function grab(character: Model, humanoid: Humanoid, tool: Tool)
	release(humanoid)
	local handle = tool:FindFirstChild("Handle")
	local grip = handle and handle:FindFirstChild("LeftHandGrip")
	local upperArm = character:FindFirstChild("LeftUpperArm")
	local hand = character:FindFirstChild("LeftHand")
	if not grip or not upperArm or not hand then
		return -- sin agarradera, o un cuerpo R6
	end
	local ik = Instance.new("IKControl")
	ik.Name = IK_NAME
	ik.Type = Enum.IKControlType.Position
	ik.ChainRoot = upperArm
	ik.EndEffector = hand
	ik.Target = grip
	ik.SmoothTime = 0.05
	ik.Parent = humanoid
end

-- Para un jugador o un soldado: cada vez que saca un arma, la agarra con las dos manos
function TwoHands.Setup(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			grab(character, humanoid, child)
		end
	end)
	character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") and not character:FindFirstChildOfClass("Tool") then
			release(humanoid)
		end
	end)
	humanoid.Died:Connect(function()
		release(humanoid)
	end)
	local tool = character:FindFirstChildOfClass("Tool")
	if tool then
		grab(character, humanoid, tool)
	end
end

return TwoHands
