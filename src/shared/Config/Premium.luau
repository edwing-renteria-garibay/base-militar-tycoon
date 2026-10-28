-- Las defensas premium: se compran con Robux (Config/Store, products con kind = "defense") y
-- tú eliges dónde ponerlas en tu terreno, menos en los lugares marcados de lo que se compra
-- con dinero del juego (ver src/shared/Placement.luau).
--
--   kind     su dibujo (src/server/Builder.luau); su vida está en Waves.buildingHealth
--   radius   cuánto espacio ocupa (un círculo de este radio, en studs)
--   defense  si dispara sola: { damage, range, cooldown, sound }. Dispara a todos lados
--   effect   "barricade" = tapa el paso (los zombis demoledores no la buscan)
--
-- No cambies la key después de publicar: así se guarda cuántas tiene cada jugador.

local Premium = {}

Premium.list = {
	{
		key = "TorretaPesada",
		name = "Torreta pesada",
		kind = "HeavyTurret",
		radius = 5,
		defense = { damage = 40, range = 120, cooldown = 0.3, sound = "AssaultRifle" },
	},
	{
		key = "BarricadaAcero",
		name = "Barricada de acero",
		kind = "SteelBarricade",
		radius = 7,
		effect = "barricade",
	},
}

Premium.byKey = {}
for _, item in Premium.list do
	Premium.byKey[item.key] = item
end

return Premium
