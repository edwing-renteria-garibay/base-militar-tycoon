-- Las misiones: van en orden y en la pantalla salen las siguientes "shown" que te faltan (a la
-- izquierda, debajo de tus barras). Al cumplir una te da su premio (reward) y sale la que sigue.
--
--   stat  qué se cuenta (lo mismo que las medallas, Config/Ranks): "kills", "headshots",
--         "bosses", "record" (la ola más alta), "buildings" (cosas compradas), "ignites" (veces
--         que encendiste las zanjas), "fills" (zanjas llenadas con bidón), "snipers"
--         (francotiradores contratados), "pickups" (consumibles agarrados), "research"
--         (niveles investigados), "frequencies" y "victories"
--   goal  cuánto hay que llegar
--
-- No cambies la key de una misión después de publicar: así se guarda cuáles cumpliste.

local Research = require(script.Parent.Research)

local Missions = {}

Missions.shown = 3

-- El objetivo principal: sale arriba de las misiones, uno a la vez y en este orden. Al
-- cumplirlo todo sale "done"
local allResearch = 0
for _, line in Research.lines do
	allResearch += #line.levels
end
Missions.main = {
	{ text = "Aguanta hasta la ola 25", stat = "record", goal = 25 },
	{ text = "Investiga todo en el laboratorio: las olas se calman y tu base se defiende sola", stat = "research", goal = allResearch },
	{ text = "Cruza los túneles infestados al final de la calle y saca la frecuencia de la cura", stat = "frequencies", goal = 1 },
	{ text = "Transmite la cura desde la antena de tu caja fuerte", stat = "victories", goal = 1 },
}
Missions.done = "¡Salvaste a todos! Saca otra frecuencia para ganar todavía más dinero"

Missions.list = {
	{ key = "M1", text = "Mata 10 zombis", stat = "kills", goal = 10, reward = 500 },
	{ key = "M2", text = "Construye 3 cosas para tu base", stat = "buildings", goal = 3, reward = 1000 },
	{ key = "M3", text = "Contrata un francotirador en su torre", stat = "snipers", goal = 1, reward = 1000 },
	{ key = "M4", text = "Pasa la ola 5", stat = "record", goal = 5, reward = 2000 },
	{ key = "M5", text = "Llena una zanja con un bidón", stat = "fills", goal = 1, reward = 1500 },
	{ key = "M6", text = "Enciende las zanjas en la gasolinera", stat = "ignites", goal = 1, reward = 2000 },
	{ key = "M7", text = "Haz 25 tiros a la cabeza", stat = "headshots", goal = 25, reward = 3000 },
	{ key = "M8", text = "Agarra 3 consumibles", stat = "pickups", goal = 3, reward = 2500 },
	{ key = "M9", text = "Investiga 3 mejoras en el laboratorio", stat = "research", goal = 3, reward = 5000 },
	{ key = "M10", text = "Pasa la ola 10", stat = "record", goal = 10, reward = 8000 },
	{ key = "M11", text = "Mata a un JEFE", stat = "bosses", goal = 1, reward = 10000 },
	{ key = "M12", text = "Enciende las zanjas 5 veces", stat = "ignites", goal = 5, reward = 10000 },
	{ key = "M13", text = "Mata 500 zombis", stat = "kills", goal = 500, reward = 15000 },
	{ key = "M14", text = "Construye 15 cosas para tu base", stat = "buildings", goal = 15, reward = 15000 },
	{ key = "M15", text = "Contrata 4 francotiradores", stat = "snipers", goal = 4, reward = 15000 },
	{ key = "M16", text = "Pasa la ola 15", stat = "record", goal = 15, reward = 25000 },
	{ key = "M17", text = "Investiga 10 mejoras en el laboratorio", stat = "research", goal = 10, reward = 30000 },
	{ key = "M18", text = "Haz 300 tiros a la cabeza", stat = "headshots", goal = 300, reward = 30000 },
	{ key = "M19", text = "Pasa la ola 20", stat = "record", goal = 20, reward = 50000 },
	{ key = "M20", text = "Mata a 3 JEFES", stat = "bosses", goal = 3, reward = 60000 },
	{ key = "M21", text = "Pasa la ola 25: se abre el laboratorio infestado", stat = "record", goal = 25, reward = 80000 },
	{ key = "M22", text = "Cruza el laberinto y saca la frecuencia de la cura", stat = "frequencies", goal = 1, reward = 100000 },
	{ key = "M23", text = "Transmite la cura desde la antena de tu caja", stat = "victories", goal = 1, reward = 150000 },
}

return Missions
