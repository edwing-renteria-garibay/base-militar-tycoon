-- Las barricadas de concreto: se compran con dinero del juego y se ponen donde quieras,
-- en hileras (como el muro). Si la punta de una hilera queda cerca de la punta de otra, se
-- unen ahí: así armas cuadrados, triángulos o la forma que quieras. Los zombis las rompen y
-- se reparan en la caja fuerte, igual que el muro.

local Barricades = {}

Barricades.segment = 8 -- largo de cada pedazo (en studs)
Barricades.maxPerRow = 3 -- pedazos por hilera (de 1 a 3)
Barricades.price = 250 -- precio de cada pedazo
Barricades.health = 800 -- vida de cada pedazo
Barricades.snap = 3 -- si la punta queda a menos de esto de otra punta, se unen
Barricades.max = 60 -- cuántos pedazos puedes tener en total

return Barricades
