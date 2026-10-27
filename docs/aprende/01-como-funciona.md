# 1. Cómo funciona el tycoon

## Las piezas del código

| Archivo | Qué hace |
|---|---|
| `src/shared/Config/Buildings.luau` | La lista de construcciones: nombre, precio, cuánto generan y dónde van |
| `src/shared/Config/Settings.luau` | Ajustes: dinero inicial, modo de prueba, número de terrenos |
| `src/server/Services/PlotService.luau` | Arma el mapa y reparte los terrenos |
| `src/server/Services/DataService.luau` | El dinero y la base de cada jugador, y el guardado |
| `src/server/Services/TycoonService.luau` | Botones de compra, construir y la caja fuerte |
| `src/server/Builder.luau` | Los "dibujos" de cada construcción, hechos con bloques |
| `src/client/UI/HUD.luau` | La pantalla con tu dinero y los avisos |

## El ciclo

1. Cada segundo, `TycoonService` suma el `income` de todo lo que construiste y lo mete a tu
   caja fuerte (`profile.vault`).
2. Al pisar el botón verde de la caja fuerte, ese dinero pasa a tu cuenta (`profile.money`).
3. Al pisar el botón de una construcción, `DataService.Spend` revisa que te alcance. Si sí,
   se marca como tuya (`profile.owned`) y `Builder` la dibuja.
4. Sale el botón de la siguiente de la lista.

## Cambiar precios o agregar una construcción

Abre `Config/Buildings.luau` y cambia `price` o `income`. Para una construcción nueva:

1. Escribe su dibujo en `Builder.luau`, dentro de `Builder.kinds` (copia uno parecido).
2. Agrégala a `Buildings.list` con ese `kind`, en el lugar de la lista donde quieres que se
   desbloquee.
3. Elige un `at` libre dentro del terreno: va de -65 a 65, y el frente (la calle) es z = -65.

**Ojo:** no cambies el `id` de una construcción después de publicar, porque así se guarda en
el perfil de los jugadores.

## El terreno

Cada terreno tiene un `cframe` en el centro de su piso que mira a la calle. Todas las
posiciones son relativas a él (`plot.cframe * CFrame.new(x, 0, z)`), por eso la misma lista
sirve para los 6 terrenos aunque estén de lados distintos de la calle.
