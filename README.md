# Base Militar Tycoon

Tycoon militar para Roblox: cada jugador recibe un terreno y construye su base pieza por
pieza. La base genera dinero sola y con ese dinero compras la siguiente construcción.

Plan de diseño: https://claude.ai/artifact/3Gw8f2RDgqLrFddtKvoat1

## Qué hay ya (semana 1)

- Mapa con una calle y 6 terrenos; cada jugador recibe uno con un letrero con su nombre
- **Etapa 1, Campamento:** bandera, sacos de arena, tienda de campaña, fogata, cajas, antena de radio y torre de vigilancia
- **Etapa 2, Cuartel:** generador, cuartel, armería, campo de tiro, comedor, muro de concreto y portón
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
