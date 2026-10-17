# Preparar un servidor para Odoo + autodoo

Scripts para dejar listo un servidor nuevo (Ubuntu) de CRUMGES. Se corren como root.

## Orden

1. **`docker-compose.sh`**: Docker, Traefik, `/opt/odoo` y la clave SSH del servidor (`~/.ssh/id_rsa`).
   Al final pregunta si querés bajar autodoo.
2. Instalá el Odoo (Doodba) del cliente.
3. Encendé autodoo: `cd /opt/autodoo && python3 configure.py && docker compose up -d --build`.

## autodoo.sh

Baja autodoo en `/opt/autodoo` con la clave del servidor (`~/.ssh/id_rsa`). autodoo está en un repositorio
privado, así que esa clave tiene que estar cargada en la cuenta de GitHub con acceso
(perfil › Settings › SSH and GPG keys).

Antes de bajar nada, comprueba que GitHub acepta la clave. Si no la acepta, te la muestra, te dice dónde
cargarla y espera; si sigue sin entrar, te dice qué revisar y vuelve a esperar, o cancelás con «c».

Si autodoo ya estaba en `/opt/autodoo`, solo lo apunta a GitHub con esa clave para que «Actualizar» funcione.
No apaga ni reinicia nada.

```bash
sudo bash autodoo.sh
```

## Próxima etapa: «autodoo Central»

Ideas para más adelante (no necesariamente la etapa inmediata):

- **autodoo Central:** una aplicación de CRUMGES que gobierne a todos los autodoo: despliegues, estado de cada
  servidor, versiones y gestión de claves. Cada servidor sigue teniendo su propio autodoo.
- **Asistente gráfico de instalación:** el usuario corre un solo comando de SSH en su computadora (Windows, Mac o
  Linux), que abre un túnel, y sigue el resto en su navegador: Docker y Traefik, dominio (que apunte al servidor),
  claves con «Copiar» y «Abrir GitHub», y autodoo. Más adelante, crear el Odoo desde el propio autodoo.
  Para eso autodoo tiene que poder instalarse sin Odoo (dominio cargado a mano) y arrancar sin ambientes.
- **Seguridad de las claves:** una clave cargada en la cuenta de GitHub puede leer **y escribir** en todos los
  repositorios de esa cuenta, incluidos los de los demás clientes. Pasar a deploy keys de solo lectura por
  repositorio (o un usuario de GitHub solo para servidores) para que un servidor comprometido no llegue a los demás.
- **Repartir autodoo** cuando lo instale el cliente: no puede cargar claves en el repositorio privado de
  CRUMGES. Opciones: que CRUMGES cargue la clave, imagen de Docker ya armada en un registro privado, o repositorio
  público.

## traefik.sh

Versión vieja (Traefik en `/opt/odoo/inverseproxy`). **Borra esa carpeta y la vuelve a crear.**
`docker-compose.sh` ya instala Traefik en `/opt/traefik`.
