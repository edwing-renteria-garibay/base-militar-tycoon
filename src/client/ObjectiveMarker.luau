-- La marca de OBJETIVO: un rombo con la distancia que se ve a través de todo, encima de a donde
-- tienes que ir para el objetivo principal (Config/Missions, target). El servidor dice cuál
-- con el atributo "ObjectiveTarget" (RankService):
--   "lab"      tu laboratorio (para investigar)
--   "infested" la terminal del laboratorio infestado, al final de la calle
--   "vault"    tu caja fuerte (antena): para transmitir la cura
-- De cerca se esconde, para no tapar.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Buildings = require(ReplicatedStorage.Shared.Config.Buildings)

local player = Players.LocalPlayer

local COLOR = Color3.fromRGB(255, 110, 80)
local HIDE_NEAR = 18 -- studs

local ObjectiveMarker = {}

-- Dónde está el objetivo ahora (nil si no hay o todavía no carga)
local function targetPosition(): Vector3?
	local target = player:GetAttribute("ObjectiveTarget")
	local plot = player:GetAttribute("PlotCenter")
	if target == "infested" then
		local lab = workspace:FindFirstChild("LaboratorioInfestado")
		local terminal = lab and lab:FindFirstChild("Terminal", true)
		return if terminal and terminal:IsA("BasePart") then terminal.Position + Vector3.new(0, 4, 0) else nil
	elseif target == "vault" and typeof(plot) == "CFrame" then
		return (plot * CFrame.new(0, 12, 0)).Position
	elseif target == "lab" and typeof(plot) == "CFrame" then
		local spot = Buildings.byId.Laboratorio.at
		return (plot * CFrame.new(spot[1], 12, spot[2])).Position
	end
	return nil
end

function ObjectiveMarker.Start()
	local anchor = Instance.new("Part")
	anchor.Name = "MarcaObjetivo"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Parent = workspace

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(140, 64)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Adornee = anchor
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local diamond = Instance.new("Frame")
	diamond.AnchorPoint = Vector2.new(0.5, 0)
	diamond.Position = UDim2.fromScale(0.5, 0)
	diamond.Size = UDim2.fromOffset(22, 22)
	diamond.Rotation = 45
	diamond.BackgroundColor3 = COLOR
	diamond.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Thickness = 2
	stroke.Parent = diamond
	local label = Instance.new("TextLabel")
	label.Position = UDim2.fromOffset(0, 30)
	label.Size = UDim2.new(1, 0, 0, 32)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 15
	label.TextColor3 = COLOR
	label.TextStrokeTransparency = 0.3
	label.Parent = gui

	RunService.Heartbeat:Connect(function()
		local position = targetPosition()
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not position or not root then
			gui.Enabled = false
			return
		end
		local distance = (position - root.Position).Magnitude
		anchor.Position = position
		gui.Enabled = distance > HIDE_NEAR
		label.Text = string.format("OBJETIVO\n%d m", math.floor(distance))
	end)
end

return ObjectiveMarker
