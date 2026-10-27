# Base Militar Tycoon

Tycoon militar para Roblox: cada jugador recibe un terreno y construye su base pieza por
pieza. La base genera dinero sola y con ese dinero compras la siguiente construcción.

Plan de diseño: https://claude.ai/artifact/3Gw8f2RDgqLrFddtKvoat1

## Qué hay ya (semanas 1 y 2)

- Mapa con una calle y 6 terrenos de 130 x 230; cada jugador recibe uno con un letrero con su nombre
- **Etapa 1, Campamento:** bandera, sacos de arena, tienda de campaña, fogata, cajas, antena de radio y torre de vigilancia
- **Etapa 2, Cuartel:** generador, cuartel, armería, campo de tiro, comedor, muro de concreto y portón
- **Etapa 3, Motor:** tanques de gasolina, gasolinera, garaje, taller, fábrica de jeeps y camión
- **Etapa 4, Defensa:** búnker, dos torretas, radar, polvorín, torre de francotirador y tanque de guerra
- **Etapa 5, Comando:** helipuerto, helicóptero, hangar, centro de mando, antena satelital y bandera gigante
- **Jeep:** con el garaje, mantén **E** en su entrada para sacar un jeep y manejarlo por tu base
- **Renacer:** al terminar toda la base sale un botón dorado; mantén **E** 2 segundos y tu base se reinicia, pero desde entonces todo genera más (x1.5, x2, x2.5...)
- Aspas, radar, torretas y antena giran (`src/client/Spinner.luau`)
- Botones de compra en el piso: verdes si te alcanza, rojos si no. Al comprar, la construcción cae del cielo
- Caja fuerte que junta el dinero de la base; pisa su botón verde para cobrar
- Se guarda tu dinero y tu base (DataStore)
- Pantalla con tu dinero y cuánto genera tu base por segundo, y avisos

## Cómo probarlo

1. En una terminal, dentro de esta carpeta: `rojo serve`
2. Abre Roblox Studio con un lugar vacío (Baseplate), conecta el plugin de Rojo y dale **Play**.
3. Para probar rápido con mucho dinero: en `src/shared/Config/Settings.luau` pon
   `Testing.enabled = true` (y regrésalo a `false` antes de publicar).

Para publicar: `rojo build -o base-militar-tycoon.rbxl`, ábrelo en Studio y usa
*Archivo > Publicar en Roblox como…*.

Las guías para entender el código están en [`docs/aprende/`](docs/aprende/).
