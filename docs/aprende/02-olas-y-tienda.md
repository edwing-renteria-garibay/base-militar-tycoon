# 2. Olas de zombis, tienda y premio diario

## Olas de zombis

Un minuto después de entrar (20 segundos en modo de prueba) empieza la ola que te toca, y
entre una y otra hay 40 segundos de descanso. Cada ola trae más zombis, con más vida, más
rápidos y por más lados: de la 1 a la 2 por un lado, hasta la 5 por dos, hasta la 9 por tres
y después por los cuatro.

Cada zombi camina derecho hacia tu muro. Si algo le tapa el paso (un pedazo del muro o una
barricada) lo golpea hasta romperlo y, ya adentro, va por tu caja fuerte. Si la destruyen,
se llevan la cuarta parte de lo que tenía, todo se repara y vuelves a la ola 1. Tu récord no
se pierde.

- **Armas:** el Rifle (tecla **1**) tiene balas infinitas. En la Armería (mantén **E** en su
  entrada) compras escopeta, ametralladora y rifle de francotirador, y su munición. Mantén
  el clic, o el dedo en celular, para disparar seguido. Todo está en `Config/Weapons.luau`.
- **Cámara:** como en Escuadrón Cero, juegas en primera persona y con **V** cambias a tercera.
  El mouse queda fijo en la mira; para usar la tienda o colocar defensas usa **B** y **G** (o
  los botones), y mientras el menú está abierto el mouse se suelta. Eso lo hace
  `src/client/Menus.luau`: cada menú registra su botón X con `Modal = true`.
- **Laboratorio:** mantén **E** en su entrada para investigar. Hay 3 líneas con 3 niveles
  cada una: balas (tus armas), torretas (torres y torretas) y explosivos (minas, zanjas y
  alambre). Cada nivel cuesta dinero y tarda un rato; se investiga una a la vez y encima del
  laboratorio ves cuánto falta. Todo está en `Config/Research.luau`.
- **Enfermería:** si estás cerca, te cura 20 de vida por segundo.
- **Torres:** solo disparan si contratas un francotirador (mantén **E** al pie de la torre).
  Si un zombi lo mata, o tú le disparas por error, hay que contratar otro.
- **Torretas:** disparan solas, pero solo hacia su frente (45°). Las rayas amarillas del piso marcan hasta dónde alcanzan.
- **Zombis especiales** (`Waves.special`): desde la ola 3 salen trepadores (se saltan el muro
  y suben a las torres por el francotirador), desde la 4 demoledores (grandes y lentos, van
  por tus edificios), desde la 5 saboteadores (van por tus torres y torretas) y desde la 6
  explosivos (traen una bomba roja en el pecho: explotan al llegar al muro o a ti). El aviso
  de la ola no dice cuáles vienen: fíjate en quién te ataca.
- **Todo se rompe:** los edificios y las defensas tienen vida. Rotos se ven oscuros y
  transparentes, y no funcionan hasta que los reparas.
- **Alambre:** frena a los zombis y los lastima mientras lo cruzan.
- **Minas:** explotan cuando un zombi pasa cerca y se gastan; su botón vuelve a salir.
- **Zanjas de gasolina:** mantén **E** en la gasolinera para encenderlas 10 segundos. Se
  recargan en un minuto.
- **Reparar:** mantén **E** junto a la caja fuerte. Cuesta $0.50 por punto de vida. Con el
  taller, el muro se repara solo poco a poco.
- **Premios:** cada zombi da $4 más el número de la ola, y pasar la ola n da $100 x n.

Todos los números están en `src/shared/Config/Waves.luau`.

| Archivo | Qué hace |
|---|---|
| `Services/WaveService.luau` | La cuenta regresiva, los zombis, las trampas y las torres |
| `Services/WallService.luau` | La vida del muro y las barricadas |
| `Services/WeaponService.luau` | Da el rifle y revisa cada disparo en el servidor |
| `client/Weapon.luau` | Avisa al servidor a dónde apuntaste |
| `client/Fx.luau` y `Config/Sounds.luau` | Los efectos y sonidos de los disparos (los de Escuadrón Cero) |
| `client/UI/Armory.luau` | La tienda de la armería |

## Tienda (pases y bolsa de dinero)

El botón **TIENDA** abajo a la izquierda abre la lista. Todo está en
`src/shared/Config/Store.luau`.

| Qué | Tipo | Precio | Qué da |
|---|---|---|---|
| x2 Dinero | Pase | 299 | Tu caja fuerte junta el doble |
| Auto-cobrar | Pase | 199 | El dinero entra solo |
| VIP | Pase | 249 | +20% y estrellas en tu letrero |
| Munición x2 | Pase | 149 | Los paquetes de munición traen el doble |
| Bolsa de dinero | Producto | 49 | 10 minutos de lo que junta tu caja fuerte (mínimo $2,000) |
| Torreta pesada | Producto | 99 | Una torreta que dispara a todos lados; la colocas donde quieras |
| Barricada de acero | Producto | 49 | Una barricada de 3,000 de vida; la colocas donde quieras |

### Defensas premium

Lo que compras con Robux (`Config/Premium.luau`) no tiene lugar marcado: con el botón
**COLOCAR** (abajo a la izquierda) se abre un menú con cada defensa, cuántas tienes y botones
para colocarla o comprar más. Al elegir "Colocar" sale una vista previa. Verde = se puede, rojo = no. **R** o
"Girar" la gira y clic o "Colocar" la pone. No se puede encimar en los lugares marcados de lo
que se compra con dinero del juego, ni en el muro, ni en otra defensa
(`src/shared/Placement.luau`). En modo de prueba tienes 2 de cada una sin pagar.

**Ojo:** las defensas premium solo duran hasta que destruyen tu caja fuerte. Si pasa, se
pierden y hay que comprar otras.

### Barricadas

Las barricadas de concreto se compran con dinero del juego, pero no tienen lugar marcado: con
**BARRICADAS** (o **H**) haces clic donde empieza una hilera y otra vez donde termina (de 1 a 3
pedazos). La siguiente sigue desde ahí, así dibujas la forma que quieras. Si la punta queda
cerca de otra barricada, se pegan. Precio, vida y cuántas puedes tener: `Config/Barricades.luau`.

### Cómo crearlos (cuando ya publiques el juego)

1. [create.roblox.com](https://create.roblox.com) > **Creaciones** > Base Militar Tycoon.
2. **Pases:** menú **Monetización > Pases** > **Crear un pase**. Sube una imagen, ponle el
   nombre, guárdalo, entra a **Ventas**, actívalo y ponle el precio. Copia su **ID**.
3. **Bolsa de dinero y defensas premium:** menú **Monetización > Productos de desarrollador**
   > **Crear**. Uno por cada producto de la tabla, con su nombre y precio. Copia su **ID**.
4. Pásale los ID a Claude, o ponlos en `Store.luau` en lugar de los `id = 0`.

## Premio diario

Al entrar una vez al día recibes de 2 a 10 minutos de lo que junta tu caja fuerte (mínimo $200),
y sube si entras días seguidos. En modo de prueba no hay premio diario.
