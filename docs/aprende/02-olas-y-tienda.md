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
- **Laboratorio:** sube el daño de todo: +25%, +50% y x2 con sus mejoras.
- **Enfermería:** si estás cerca, te cura 20 de vida por segundo.
- **Torres y torretas:** disparan solas al zombi más cercano. Las torretas solo ven hacia su
  frente (45°, las rayas amarillas del piso).
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

### Cómo crearlos (cuando ya publiques el juego)

1. [create.roblox.com](https://create.roblox.com) > **Creaciones** > Base Militar Tycoon.
2. **Pases:** menú **Monetización > Pases** > **Crear un pase**. Sube una imagen, ponle el
   nombre, guárdalo, entra a **Ventas**, actívalo y ponle el precio. Copia su **ID**.
3. **Bolsa de dinero:** menú **Monetización > Productos de desarrollador** > **Crear**.
   Nombre "Bolsa de dinero", precio 49. Copia su **ID**.
4. Pásale los ID a Claude, o ponlos en `Store.luau` en lugar de los `id = 0`.

## Premio diario

Al entrar una vez al día recibes de 2 a 10 minutos de lo que junta tu caja fuerte (mínimo $200),
y sube si entras días seguidos. En modo de prueba no hay premio diario.
