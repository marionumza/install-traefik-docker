# Preparar un servidor para Odoo + autodoo

Scripts para dejar listo un servidor nuevo (Ubuntu) de CRUMGES. Se corren como root.

## Orden

1. **`docker-compose.sh`**: Docker, Traefik, `/opt/odoo` y la clave SSH del servidor (`~/.ssh/id_rsa`, para los
   repositorios de Odoo de cada cliente). Al final pregunta si querés preparar autodoo.
2. Instalá el Odoo (Doodba) del cliente.
3. **`autodoo.sh`**: instala autodoo en `/opt/autodoo` y lo enciende.

## autodoo.sh

autodoo está en un repositorio privado, así que el servidor necesita permiso para bajarlo y actualizarse.

1. Primero prueba con la clave del servidor (`~/.ssh/id_rsa`). Si ya entra (por ejemplo, porque está cargada en
   tu cuenta de GitHub), usa esa y sigue.
2. Si no entra (por ejemplo, porque es la deploy key del repositorio del cliente: GitHub no acepta la misma deploy
   key en dos repositorios), crea una clave **solo para autodoo** (`~/.ssh/id_ed25519_autodoo`), te la muestra y
   espera a que la cargues en `marionumza/autodoo` › Settings › Deploy keys, **sin** «Allow write access».
   Comprueba el acceso antes de seguir: si GitHub todavía no la acepta, te lo dice y vuelve a esperar, o cancelás.

Se puede correr las veces que haga falta:

| Situación del servidor | Qué hace |
|---|---|
| Sin Odoo todavía | Deja lista la clave. Volvé a correrlo cuando el Odoo esté andando. |
| Con Odoo, sin autodoo | Clona autodoo, arma el `.env` (`configure.py`), pide la contraseña del correo de autodoo (opcional) y lo enciende. |
| Con autodoo en `/opt/autodoo` | Apunta autodoo a la clave que tiene acceso, para que «Actualizar» funcione. No apaga ni reinicia nada. |
| Con la carpeta vieja `/opt/autogestion` | Lo mismo, y ofrece pasarla a `/opt/autodoo` (apaga y vuelve a encender). |

```bash
sudo bash autodoo.sh
```

## Pendiente: seguridad de las claves

Una clave del servidor cargada en la cuenta de GitHub puede leer **y escribir** en todos los repositorios de esa
cuenta, incluidos los de los demás clientes. Más adelante: deploy keys de solo lectura por repositorio (o un
usuario de GitHub solo para servidores, con permiso de lectura en `autodoo`), para que un servidor comprometido
no llegue a los demás.

## traefik.sh

Versión vieja (Traefik en `/opt/odoo/inverseproxy`). **Borra esa carpeta y la vuelve a crear.**
`docker-compose.sh` ya instala Traefik en `/opt/traefik`.
