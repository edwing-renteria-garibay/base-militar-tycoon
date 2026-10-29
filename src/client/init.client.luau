-- Punto de entrada del cliente: la cámara (primera persona, V para tercera), el arma en primera
-- persona y la mira, la pantalla con tu dinero, los avisos y la próxima ola, la tienda, la
-- armería, el laboratorio, colocar defensas premium, poner barricadas, las armas, los efectos de los disparos y lo
-- que gira.

local Camera = require(script.Camera)
local Crosshair = require(script.Crosshair)
local Fx = require(script.Fx)
local Spinner = require(script.Spinner)
local ViewModel = require(script.ViewModel)
local Weapon = require(script.Weapon)
local ArmoryUI = require(script.UI.Armory)
local BarricadesUI = require(script.UI.Barricades)
local HUD = require(script.UI.HUD)
local LabUI = require(script.UI.Lab)
local PlacementUI = require(script.UI.Placement)
local StoreUI = require(script.UI.Store)

Camera.Start()
ViewModel.Start()
Crosshair.Start()
HUD.Start()
StoreUI.Start()
ArmoryUI.Start()
LabUI.Start()
PlacementUI.Start()
BarricadesUI.Start()
Weapon.Start()
Fx.Start()
Spinner.Start()
