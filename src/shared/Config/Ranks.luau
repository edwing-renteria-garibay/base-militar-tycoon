-- Rangos y medallas (los da src/server/Services/RankService.luau).
--
-- Rangos: suben con los zombis que matas tú (con tus balas). kills = cuántos necesitas.
-- Medallas: metas del juego; cada una se gana una sola vez y se guarda para siempre.
--   stat   qué se cuenta: "kills", "headshots", "bosses" (jefes que mataste), "record" (la
--          ola más alta que pasaste), "buildings" (cuántas cosas compraste), "ignites"
--          (veces que encendiste las zanjas), "wall" (nivel del muro)
--   goal   cuánto hace falta
-- No cambies la key de una medalla después de publicar: así se guarda quién la tiene.

local Ranks = {}

Ranks.list = {
	{ name = "Recluta", kills = 0 },
	{ name = "Soldado", kills = 50 },
	{ name = "Cabo", kills = 200 },
	{ name = "Sargento", kills = 500 },
	{ name = "Teniente", kills = 1000 },
	{ name = "Capitán", kills = 2500 },
	{ name = "Mayor", kills = 5000 },
	{ name = "Coronel", kills = 10000 },
	{ name = "General", kills = 25000 },
}

Ranks.medals = {
	{ key = "PrimeraSangre", name = "Primera sangre", description = "Mata a tu primer zombi", stat = "kills", goal = 1 },
	{ key = "Exterminador", name = "Exterminador", description = "Mata 1,000 zombis", stat = "kills", goal = 1000 },
	{ key = "Punteria", name = "Puntería", description = "100 tiros a la cabeza", stat = "headshots", goal = 100 },
	{ key = "Sobreviviente", name = "Sobreviviente", description = "Pasa la ola 5", stat = "record", goal = 5 },
	{ key = "Veterano", name = "Veterano", description = "Pasa la ola 10", stat = "record", goal = 10 },
	{ key = "Leyenda", name = "Leyenda", description = "Pasa la ola 25", stat = "record", goal = 25 },
	{ key = "Cazajefes", name = "Cazajefes", description = "Mata a un JEFE", stat = "bosses", goal = 1 },
	{ key = "Constructor", name = "Constructor", description = "Compra 15 cosas para tu base", stat = "buildings", goal = 15 },
	{ key = "Fortaleza", name = "Fortaleza", description = "Ten el muro reforzado", stat = "wall", goal = 3 },
	{ key = "Piromano", name = "Pirómano", description = "Enciende las zanjas 10 veces", stat = "ignites", goal = 10 },
}

-- El rango que te toca con esos kills (y el que sigue, si hay)
function Ranks.Of(kills: number): (any, any)
	local current, nextRank = Ranks.list[1], nil
	for i, rank in Ranks.list do
		if kills >= rank.kills then
			current, nextRank = rank, Ranks.list[i + 1]
		end
	end
	return current, nextRank
end

return Ranks
