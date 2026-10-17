# Preparar un servidor para Odoo + autodoo

Scripts para dejar listo un servidor nuevo (Ubuntu) de CRUMGES. Se corren como root.

## Orden

1. **`docker-compose.sh`**: Docker, Traefik, `/opt/odoo` y la clave SSH del servidor (`~/.ssh/id_rsa`, para los
   repositorios de Odoo de cada cliente). Al final pregunta si querés preparar autodoo.
2. Instalá el Odoo (Doodba) del cliente.
3. **`autodoo.sh`**: instala autodoo en `/opt/autodoo` y lo enciende.

## autodoo.sh

autodoo está en un repositorio privado, así que el servidor necesita permiso para bajarlo y actualizarse.
El script crea una clave **solo para autodoo** (`~/.ssh/id_ed25519_autodoo`), te la muestra y espera a que la
cargues en GitHub (repositorio `marionumza/autodoo` › Settings › Deploy keys, **sin** «Allow write access»).
Comprueba el acceso antes de seguir: si GitHub todavía no la acepta, te lo dice y vuelve a esperar, o cancelás.

Es una clave aparte de `id_rsa` porque GitHub no acepta la misma clave en dos repositorios.

Se puede correr las veces que haga falta:

| Situación del servidor | Qué hace |
|---|---|
| Sin Odoo todavía | Deja lista la clave. Volvé a correrlo cuando el Odoo esté andando. |
| Con Odoo, sin autodoo | Clona autodoo, arma el `.env` (`configure.py`), pide la contraseña del correo de autodoo (opcional) y lo enciende. |
| Con autodoo en `/opt/autodoo` | Apunta autodoo a la clave nueva para que «Actualizar» funcione. No apaga ni reinicia nada. |
| Con la carpeta vieja `/opt/autogestion` | Lo mismo, y ofrece pasarla a `/opt/autodoo` (apaga y vuelve a encender). |

```bash
sudo bash autodoo.sh
```

## traefik.sh

Versión vieja (Traefik en `/opt/odoo/inverseproxy`). **Borra esa carpeta y la vuelve a crear.**
`docker-compose.sh` ya instala Traefik en `/opt/traefik`.
