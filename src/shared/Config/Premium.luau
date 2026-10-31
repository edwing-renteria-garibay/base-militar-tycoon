-- Las defensas premium: se compran con Robux (Config/Store, products con kind = "defense") y
-- tú eliges dónde ponerlas en tu terreno, menos en los lugares marcados de lo que se compra
-- con dinero del juego (ver src/shared/Placement.luau).
--
--   kind     su dibujo (src/server/Builder.luau); su vida está en Waves.buildingHealth
--   radius   cuánto espacio ocupa (un círculo de este radio, en studs)
--   defense  si dispara sola: { damage, range, cooldown, sound }. Dispara a todos lados
--   effect   "barricade" = tapa el paso (los zombis demoledores no la buscan); "mine" =
--            explota cuando pasa un zombi y se gasta (como las minas de Config/Buildings)
--
-- No cambies la key después de publicar: así se guarda cuántas tiene cada jugador.

local Premium = {}

Premium.list = {
	{
		key = "TorretaPesada",
		name = "Torreta pesada",
		description = "Dispara a todos lados, con mucho alcance",
		kind = "HeavyTurret",
		radius = 5,
		defense = { damage = 40, range = 120, cooldown = 0.3, sound = "AssaultRifle" },
	},
	{
		key = "BarricadaAcero",
		name = "Barricada de acero",
		description = "Tapa el paso y aguanta 3,000 golpes",
		kind = "SteelBarricade",
		radius = 7,
		effect = "barricade",
	},
	{
		key = "Mina",
		name = "Mina",
		description = "Explota cuando un zombi la pisa (se gasta)",
		kind = "Mine",
		radius = 2,
		effect = "mine",
	},
}

Premium.byKey = {}
for _, item in Premium.list do
	Premium.byKey[item.key] = item
end

return Premium
