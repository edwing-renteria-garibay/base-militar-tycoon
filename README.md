# Base Militar Tycoon

Juego de defensa para Roblox: cada jugador recibe un terreno con una caja fuerte en el centro
que junta dinero. Con ese dinero construyes muros, trampas y defensas para aguantar olas de
zombis cada vez más difíciles. Tu récord es la ola más alta que pasas.

Plan de diseño: https://claude.ai/artifact/3Gw8f2RDgqLrFddtKvoat1

## Qué hay

- Mapa con una calle y 6 terrenos de 200 x 200; cada jugador recibe uno con un letrero con su nombre
- **Caja fuerte** en el centro: junta dinero cada segundo; pisa su botón verde para cobrar. Se mejora hasta el nivel 5. Todo lo que compras para tu base sube lo que junta. Empiezas con $1,000 y 90 segundos antes de la primera ola
- **Muro** alrededor (a 70 del centro) hecho de pedazos con vida: los zombis lo rompen y tú lo reparas manteniendo **E** junto a la caja fuerte. Se mejora a concreto y a reforzado
- **Olas de zombis** numeradas: cada una trae más, con más vida y por más lados (frente, derecha, atrás, izquierda). Si destruyen tu caja fuerte se llevan parte de su dinero y vuelves a la ola 1
- **Zombis especiales:** trepadores (se saltan el muro y suben a las torres por el francotirador), demoledores (grandes, van por tus edificios) saboteadores (van por tus torres y torretas) y corrosivos (verdes, explotan y te **infectan**: pierdes vida hasta que usas un antídoto de la enfermería)
- Los edificios y defensas también tienen vida: rotos dejan de funcionar hasta que los reparas
- **Puertas:** el muro tiene una pluma en medio de cada lado, que se levanta cuando llegas: tú pasas y los zombis no, aunque la pueden romper como el resto del muro
- **Defensas** en lugares marcados (sus botones están adentro, junto al muro):
  - torre en cada esquina donde contratas un francotirador (mantén **E** al pie; el primero es gratis; si muere, contratas otro; ¡tus balas también le pegan!) y una torreta por lado (dispara sola)
  - alambre de púas (frena y lastima)
  - minas (explotan y se gastan; su botón vuelve a salir) y zanjas de gasolina pegadas al muro por fuera (cada una cubre un lado entero: las cuatro rodean toda la base). Si juegas solo en el servidor (o tienes Premium o VIP), un bidón llena todas
- **Edificios con función:** gasolinera (genera combustible para encender las zanjas) y depósito de combustible (lo guarda; si cualquiera de los dos está roto, no se encienden), armería (compra armas y munición), enfermería (te cura si estás cerca y vende botiquines y antídotos para usar donde sea), laboratorio (mantén **E** para investigar más daño de armas, torretas o explosivos, muros blindados con más vida, torretas giratorias (las de las puertas disparan hacia todos lados) o más espacio (segundo francotirador por torre); tarda un rato y se ve encima) y radar (ves a los zombis a través de las paredes)
- **Misiones** (Config/Missions): a la izquierda salen las 3 que siguen (mata zombis, llena y enciende zanjas, investiga, saca la frecuencia...); al cumplir una te paga y sale otra
- **Consumibles** (Waves.pickups): a veces un zombi suelta una caja brillante (el jefe siempre). Pasa encima y por 10 segundos tienes ataque rápido, más daño o curación
- **Armas** (Config/Weapons): rifle con balas infinitas, y en la armería escopeta, ametralladora y rifle de francotirador. Mantén el clic para disparar seguido. Cada arma tiene cargador: **R** recarga (y al vaciarlo recarga sola). En la armería cada arma se mejora con **cargador grande** y **mira precisa**. Mismos modelos, sonidos y efectos de Escuadrón Cero (`src/shared/WeaponModels.luau`), y se agarran con las dos manos
- **Cámara como Escuadrón Cero:** primera persona con el arma y los brazos en pantalla (`src/client/ViewModel.luau`), **V** cambia a tercera persona sobre el hombro, **Shift** para correr (en celular, botón Correr), mira en el centro que se pone roja al acertar, retroceso, y **clic derecho** con el francotirador hace zoom. **B** abre la tienda y **G** el menú de colocar; con un menú abierto el mouse queda libre (`src/client/Menus.luau`)
- **Torretas** que solo disparan hacia su frente (45°); su alcance se marca en el piso con rayas amarillas
- **Barricadas de concreto** (botón **BARRICADAS** o tecla **H**): las pones donde quieras en hileras de 1 a 3 pedazos, clic donde empieza y clic donde termina; si la punta queda cerca de otra barricada se unen, así armas la forma que quieras. Se rompen y se reparan como el muro (`Config/Barricades.luau`)
- **Tienda** (botón abajo a la izquierda): pases x2 dinero, auto-cobrar, VIP y munición x2, bolsa de dinero, **defensas premium** (torreta pesada, barricada de acero y minas), antídotos, bomba que mata a todos (**N**), ataque aéreo (**J**), vida extra, reparación total, refuerzos y paquete inicial. En Studio lo que no tiene ID se puede **Probar** gratis
- **Defensas premium:** las compradas con Robux las colocas donde quieras con el botón **COLOCAR**, menos en los lugares marcados (`src/shared/Placement.luau`). En modo de prueba tienes 2 de cada una gratis
- **Invitar amigos** (botón **INVITAR** o tecla **I**): el amigo entra a tu mismo servidor con su propio terreno y puede ayudarte a matar a tus zombis. En Studio dice "No disponible"; pruébalo en el juego publicado
- **Tumbas** alrededor de la base: de ahí salen los zombis, inmunes (con brillo) hasta que caminan un poco (`Buildings.graves`, `Waves.immuneUntil`)
- **De noche y con niebla**, con faroles que parpadean. Si les disparas (aunque sea por error) se rompen y se apagan hasta que pasas la ola (`src/server/Lamps.luau`; la luz está en `default.project.json`, Lighting)
- **Rangos y medallas** (botón **MEDALLAS** o tecla **M**): el rango sube con los zombis que matas (de Recluta a General) y las medallas se ganan con metas (pasar olas, matar un jefe, construir...). Se cambian en `Config/Ranks.luau`
- **Laboratorio infestado** al final de la calle (`Config/Lab.luau`): un laberinto de metal lleno de zombis. Solo entra quien pasó la ola 25 (en Studio, cualquiera). Al fondo, mantén **E** en la terminal para tomar la **frecuencia de la cura**. Con ella tu caja fuerte se vuelve **antena**: mantén **E** en "Transmitir la cura" y ganas. Tu base empieza de nuevo, pero junta +50% de dinero para siempre por cada victoria (te quedas con medallas, rango, récord, armas, lo investigado y lo de Robux, y otro edificio gratis)
- **Premio diario** que sube si entras días seguidos
- Se guardan tu dinero, tu base, la ola en la que vas y tu récord (DataStore)

## Cómo probarlo

1. En una terminal, dentro de esta carpeta: `git pull` y luego `rojo serve`
2. Abre Roblox Studio con un lugar vacío (Baseplate), conecta el plugin de Rojo y dale **Play**.
3. En Studio el modo de prueba se prende solo (mucho dinero, olas rápidas, no se guarda nada).
   En el juego publicado siempre está apagado.

Para publicar: `rojo build -o base-militar-tycoon.rbxl`, ábrelo en Studio y usa
*Archivo > Publicar en Roblox como…*.

Las guías para entender el código están en [`docs/aprende/`](docs/aprende/).
