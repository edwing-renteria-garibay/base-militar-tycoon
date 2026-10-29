# 1. Cómo funciona el juego

## Las piezas del código

| Archivo | Qué hace |
|---|---|
| `src/shared/Config/Buildings.luau` | Todo lo que se compra: nombre, precio, lugar y para qué sirve |
| `src/shared/Config/Waves.luau` | Los números de las olas, el muro, las trampas y el rifle |
| `src/shared/Config/Settings.luau` | Ajustes: dinero inicial, modo de prueba, número de terrenos |
| `src/server/Services/PlotService.luau` | Arma el mapa y reparte los terrenos |
| `src/server/Services/DataService.luau` | El dinero, la base, la ola y el récord de cada jugador, y el guardado |
| `src/server/Services/TycoonService.luau` | La caja fuerte, los botones de compra y lo que hace cada edificio |
| `src/server/Services/WallService.luau` | El muro y las barricadas: vida, daño y reparación |
| `src/server/Services/WaveService.luau` | Las olas de zombis, las trampas y las torres |
| `src/server/Builder.luau` | Los "dibujos" de cada construcción, hechos con bloques |
| `src/client/UI/HUD.luau` | La pantalla: dinero, ola, vida de la caja fuerte y avisos |

## El terreno

Cada terreno es un cuadrado de 200 x 200 con su `cframe` en el centro, mirando a la calle
(-Z). Todas las posiciones son relativas a él (`plot.cframe * CFrame.new(x, 0, z)`), por eso
la misma lista sirve para los 6 terrenos.

- La caja fuerte está en `{ 0, 0 }`.
- El muro está a 70 del centro por los 4 lados (`Waves.wallInset`).
- Afuera del muro, en cada lado, van de adentro hacia afuera: alambre (z = -83), zanja (-89) y
  minas (-95). Sus botones están adentro, en z = -64.
- Las barricadas de concreto no tienen lugar marcado: las pones tú donde quieras
  (`Config/Barricades.luau`).
- `Buildings.sides` gira esas mismas posiciones para los otros 3 lados.

## El ciclo

1. Cada segundo, la caja fuerte junta `Waves.vaultIncome[nivel]` y al pisar su botón verde
   ese dinero pasa a tu cuenta.
2. Al pisar un botón, `DataService.Spend` revisa que te alcance. Si sí, se marca como tuyo
   (`profile.owned`) y `Builder` lo dibuja.
3. Las olas (`WaveService`) te dan dinero por cada zombi y por pasar la ola.

## Cambiar precios o agregar algo

Abre `Config/Buildings.luau` y cambia `price`. Para algo nuevo:

1. Escribe su dibujo en `Builder.luau`, dentro de `Builder.kinds` (copia uno parecido).
2. Agrégalo con `add({ ... })`: `id`, `name`, `price`, `kind`, `at` y, si quieres, `requires`,
   `defense` (para que dispare solo) o `effect`.

**Ojo:** no cambies el `id` de algo después de publicar, porque así se guarda en el perfil de
los jugadores.
