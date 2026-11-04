-- Las misiones (Config/Missions), a la izquierda debajo de tus barras: arriba el objetivo
-- principal y abajo las misiones que siguen, con cuánto llevas y su premio. Las cumplidas se pagan solas (RankService publica el atributo
-- "Missions").

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)

local player = Players.LocalPlayer

local GOLD = Color3.fromRGB(230, 180, 50)
local OBJECTIVE = Color3.fromRGB(255, 110, 80)

local MissionsUI = {}

function MissionsUI.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Misiones"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.Position = UDim2.fromOffset(12, 178)
	panel.Size = UDim2.fromOffset(260, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.BackgroundColor3 = Color3.fromRGB(24, 26, 22)
	panel.BackgroundTransparency = 0.35
	panel.Visible = false
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = panel

	local function label(order: number, text: string, size: number, color: Color3): TextLabel
		local l = Instance.new("TextLabel")
		l.LayoutOrder = order
		l.BackgroundTransparency = 1
		l.Size = UDim2.new(1, 0, 0, 0)
		l.AutomaticSize = Enum.AutomaticSize.Y
		l.Font = Enum.Font.GothamBold
		l.Text = text
		l.TextSize = size
		l.TextColor3 = color
		l.TextWrapped = true
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.Parent = panel
		return l
	end

	local function redraw()
		for _, child in panel:GetChildren() do
			if child:IsA("TextLabel") then
				child:Destroy()
			end
		end
		local ok, list = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("Missions") or "[]")
		local okMain, main = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("MainObjective") or "null")
		if not ok or type(list) ~= "table" then
			list = {}
		end
		local hasMain = okMain and type(main) == "table"
		panel.Visible = hasMain or #list > 0
		if hasMain then
			label(-3, "OBJETIVO", 16, OBJECTIVE).Font = Enum.Font.GothamBlack
			local text = main.text
			if main.goal and main.goal > 1 then
				text ..= string.format(" (%d/%d)", main.have, main.goal)
			end
			label(-2, text, 15, Color3.new(1, 1, 1))
		end
		if #list == 0 then
			return
		end
		label(0, "MISIONES", 16, GOLD).Font = Enum.Font.GothamBlack
		for i, mission in list do
			local text = string.format("• %s (%d/%d) · %s", mission.text, mission.have, mission.goal, Format.Money(mission.reward))
			label(i, text, 14, Color3.new(1, 1, 1))
		end
	end
	player:GetAttributeChangedSignal("Missions"):Connect(redraw)
	player:GetAttributeChangedSignal("MainObjective"):Connect(redraw)
	redraw()
end

return MissionsUI
