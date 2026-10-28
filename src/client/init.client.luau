-- Punto de entrada del cliente: la pantalla con tu dinero, los avisos y la próxima ola, la
-- tienda, la armería, el laboratorio, colocar defensas premium, las armas, los efectos de los disparos y lo que gira.

local Fx = require(script.Fx)
local Spinner = require(script.Spinner)
local Weapon = require(script.Weapon)
local ArmoryUI = require(script.UI.Armory)
local HUD = require(script.UI.HUD)
local LabUI = require(script.UI.Lab)
local PlacementUI = require(script.UI.Placement)
local StoreUI = require(script.UI.Store)

HUD.Start()
StoreUI.Start()
ArmoryUI.Start()
LabUI.Start()
PlacementUI.Start()
Weapon.Start()
Fx.Start()
Spinner.Start()
