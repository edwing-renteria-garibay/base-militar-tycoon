# 2. Olas de enemigos, tienda y premio diario

## Olas de enemigos

Cuando ya tienes la Torre de vigilancia (fin de la etapa 1), cada 2 minutos y medio llegan
soldados enemigos por la calle. Entran por el portón y van a tu caja fuerte. El que llega se
roba la cuarta parte de lo que haya en ella.

- **Tu rifle:** está en tu barra de abajo (tecla **1**). Haz clic, o toca la pantalla en
  celular, donde quieras disparar.
- **Defensa automática:** la torre, el búnker, las torretas, la torre de francotirador, el
  tanque y el helicóptero les disparan solos.
- **Premios:** cada enemigo eliminado da 4 segundos de lo que genera tu base, y eliminar toda
  la ola da 30 segundos más.

Todos los números están en `src/shared/Config/Waves.luau`.

| Archivo | Qué hace |
|---|---|
| `Services/WaveService.luau` | La cuenta regresiva, los enemigos, su camino y la defensa automática |
| `Services/WeaponService.luau` | Da el rifle y revisa cada disparo en el servidor |
| `client/Weapon.luau` | Avisa al servidor a dónde apuntaste |

## Tienda (pases y bolsa de dinero)

El botón **TIENDA** abajo a la izquierda abre la lista. Todo está en
`src/shared/Config/Store.luau`.

| Qué | Tipo | Precio | Qué da |
|---|---|---|---|
| x2 Dinero | Pase | 299 | Tu base genera el doble |
| Auto-cobrar | Pase | 199 | El dinero entra solo |
| VIP | Pase | 249 | +20% y estrellas en tu letrero |
| Jeep dorado | Pase | 149 | El jeep sale de oro |
| Bolsa de dinero | Producto | 49 | 10 minutos de lo que genera tu base (mínimo $2,000) |

### Cómo crearlos (cuando ya publiques el juego)

1. [create.roblox.com](https://create.roblox.com) > **Creaciones** > Base Militar Tycoon.
2. **Pases:** menú **Monetización > Pases** > **Crear un pase**. Sube una imagen, ponle el
   nombre, guárdalo, entra a **Ventas**, actívalo y ponle el precio. Copia su **ID**.
3. **Bolsa de dinero:** menú **Monetización > Productos de desarrollador** > **Crear**.
   Nombre "Bolsa de dinero", precio 49. Copia su **ID**.
4. Pásale los ID a Claude, o ponlos en `Store.luau` en lugar de los `id = 0`.

## Premio diario

Al entrar una vez al día recibes de 2 a 10 minutos de lo que genera tu base (mínimo $200),
y sube si entras días seguidos. En modo de prueba no hay premio diario.
