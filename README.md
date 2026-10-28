# Base Militar Tycoon

Juego de defensa para Roblox: cada jugador recibe un terreno con una caja fuerte en el centro
que junta dinero. Con ese dinero construyes muros, trampas y defensas para aguantar olas de
zombis cada vez más difíciles. Tu récord es la ola más alta que pasas.

Plan de diseño: https://claude.ai/artifact/3Gw8f2RDgqLrFddtKvoat1

## Qué hay

- Mapa con una calle y 6 terrenos de 200 x 200; cada jugador recibe uno con un letrero con su nombre
- **Caja fuerte** en el centro: junta dinero cada segundo; pisa su botón verde para cobrar. Se mejora hasta el nivel 5
- **Muro** alrededor (a 70 del centro) hecho de pedazos con vida: los zombis lo rompen y tú lo reparas manteniendo **E** junto a la caja fuerte. Se mejora a concreto y a reforzado
- **Olas de zombis** numeradas: cada una trae más, con más vida y por más lados (frente, derecha, atrás, izquierda). Si destruyen tu caja fuerte se llevan parte de su dinero y vuelves a la ola 1
- **Defensas** en lugares marcados (sus botones están adentro, junto al muro):
  - torre de francotirador en cada esquina y una torreta por lado (disparan solas)
  - barricadas de concreto (se rompen y se reparan), alambre de púas (frena y lastima)
  - minas (explotan y se gastan; su botón vuelve a salir) y zanjas de gasolina
- **Edificios con función:** gasolinera (enciende las zanjas), armería y arsenal (mejor rifle), taller (repara el muro solo), radar (ves a los zombis a través de las paredes) y garaje (jeep para atropellarlos)
- **Rifle** (tecla 1): mantén el clic para disparar seguido
- **Tienda** (botón abajo a la izquierda): pases x2 dinero, auto-cobrar, VIP y jeep dorado, y bolsa de dinero
- **Premio diario** que sube si entras días seguidos
- Se guardan tu dinero, tu base, la ola en la que vas y tu récord (DataStore)

## Cómo probarlo

1. En una terminal, dentro de esta carpeta: `git pull` y luego `rojo serve`
2. Abre Roblox Studio con un lugar vacío (Baseplate), conecta el plugin de Rojo y dale **Play**.
3. Para probar rápido con mucho dinero: en `src/shared/Config/Settings.luau` pon
   `Testing.enabled = true` (y regrésalo a `false` antes de publicar).

Para publicar: `rojo build -o base-militar-tycoon.rbxl`, ábrelo en Studio y usa
*Archivo > Publicar en Roblox como…*.

Las guías para entender el código están en [`docs/aprende/`](docs/aprende/).
