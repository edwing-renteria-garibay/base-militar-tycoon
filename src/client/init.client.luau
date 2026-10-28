-- Punto de entrada del cliente: la pantalla con tu dinero, los avisos y la próxima ola, la
-- tienda, el rifle y lo que gira.

local Spinner = require(script.Spinner)
local Weapon = require(script.Weapon)
local HUD = require(script.UI.HUD)
local StoreUI = require(script.UI.Store)

HUD.Start()
StoreUI.Start()
Weapon.Start()
Spinner.Start()
