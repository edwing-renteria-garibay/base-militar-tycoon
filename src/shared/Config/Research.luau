-- Lo que se investiga en el Laboratorio. Cada línea tiene 3 niveles; cada nivel cuesta dinero
-- y tarda un rato (solo se investiga una cosa a la vez). Al terminar, su bonus queda para
-- siempre. En modo de prueba (Config/Settings) los tiempos son 5 veces más cortos.
--
--   bonus  cuánto sube el daño por nivel (0.25 = +25% por nivel)
--   levels el precio y los segundos de cada nivel
--
-- No cambies la key después de publicar: así se guarda lo que investigó cada jugador.

local Research = {}

Research.lines = {
	{
		key = "Balas",
		name = "Balas perforantes",
		description = "+25% de daño de tus armas por nivel",
		bonus = 0.25,
		levels = { { price = 3000, time = 30 }, { price = 10000, time = 60 }, { price = 30000, time = 120 } },
	},
	{
		key = "Torretas",
		name = "Torretas mejoradas",
		description = "+25% de daño de torres y torretas por nivel",
		bonus = 0.25,
		levels = { { price = 4000, time = 30 }, { price = 12000, time = 60 }, { price = 35000, time = 120 } },
	},
	{
		key = "Explosivos",
		name = "Explosivos",
		description = "+50% de daño de minas, zanjas y alambre por nivel",
		bonus = 0.5,
		levels = { { price = 2000, time = 30 }, { price = 8000, time = 60 }, { price = 25000, time = 120 } },
	},
}

Research.byKey = {}
for _, line in Research.lines do
	Research.byKey[line.key] = line
end

-- Cuánto multiplica el daño lo investigado: levels = profile.research ({ Balas = 2, ... })
function Research.Bonus(levels: { [string]: number }, key: string): number
	local line = Research.byKey[key]
	return 1 + (if line then line.bonus * (levels[key] or 0) else 0)
end

return Research
