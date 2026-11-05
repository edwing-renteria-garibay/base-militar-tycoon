-- Punto de entrada del cliente: la cámara (primera persona, V para tercera), correr (Shift), el arma en primera
-- persona y la mira, la pantalla con tu dinero, los avisos y la próxima ola, la tienda, la
-- armería, el laboratorio, colocar defensas premium, poner barricadas, la bomba y el ataque aéreo, invitar amigos, las armas, los efectos de los disparos, lo
-- que gira y los sonidos de fondo (poca vida, alarma, música de la ola).

local Ambience = require(script.Ambience)
local Camera = require(script.Camera)
local Crosshair = require(script.Crosshair)
local Fx = require(script.Fx)
local Spinner = require(script.Spinner)
local Sprint = require(script.Sprint)
local ViewModel = require(script.ViewModel)
local Weapon = require(script.Weapon)
local ArmoryUI = require(script.UI.Armory)
local BarricadesUI = require(script.UI.Barricades)
local BossBar = require(script.UI.BossBar)
local ControlsUI = require(script.UI.Controls)
local HUD = require(script.UI.HUD)
local InviteUI = require(script.UI.Invite)
local Layout = require(script.Layout)
local LabUI = require(script.UI.Lab)
local MedalsUI = require(script.UI.Medals)
local MissionsUI = require(script.UI.Missions)
local ObjectiveMarker = require(script.ObjectiveMarker)
local PlacementUI = require(script.UI.Placement)
local PowersUI = require(script.UI.Powers)
local RoomsUI = require(script.UI.Rooms)
local StoreUI = require(script.UI.Store)
local TouchButtons = require(script.UI.TouchButtons)

-- Cada parte arranca por separado: si una falla (sale en rojo en Output), las demás siguen
local parts = {
	Layout,
	Camera,
	Sprint,
	ViewModel,
	Crosshair,
	HUD,
	StoreUI,
	ArmoryUI,
	LabUI,
	PlacementUI,
	BarricadesUI,
	PowersUI,
	BossBar,
	InviteUI,
	MedalsUI,
	MissionsUI,
	ObjectiveMarker,
	Weapon,
	Fx,
	Spinner,
	Ambience,
	ControlsUI,
	RoomsUI,
	TouchButtons,
}
for _, part in parts do
	task.spawn(function()
		local ok, err = pcall(part.Start)
		if not ok then
			warn("[Cliente] No arrancó una parte:", err)
		end
	end)
end
