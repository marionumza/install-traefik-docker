#!/bin/bash
# Upgrade a Docker CE v27.x de forma dinámica según la versión de Ubuntu
# e instalación de utilidades adicionales.

echo "==================================================="
echo "   Configuración Inicial del Servidor Destino"
echo "==================================================="
echo ""

# 0. Preguntar por generación de clave RSA
read -p "¿Deseas generar una clave SSH RSA nueva para este servidor? (s/n): " GENERAR_CLAVE
if [[ "$GENERAR_CLAVE" == "s" || "$GENERAR_CLAVE" == "S" ]]; then
    # Extraer el email sugerido: usuario@hostname
    DEFAULT_EMAIL="$(whoami)@$(hostname)"
    read -p "Ingresa el email para la clave (Enter para usar: $DEFAULT_EMAIL): " SSH_EMAIL
    SSH_EMAIL=${SSH_EMAIL:-$DEFAULT_EMAIL}
    
    echo "Generando clave RSA sin contraseña para $SSH_EMAIL..."
    # -N "" significa sin contraseña, -f ~/.ssh/id_rsa fuerza la ruta sin preguntar
    # Si la llave ya existe, ssh-keygen preguntará si deseas sobreescribirla
    ssh-keygen -t rsa -b 4096 -C "$SSH_EMAIL" -N "" -f ~/.ssh/id_rsa
    echo "Clave generada o actualizada correctamente."
fi

# 0.1 Preguntar por email para Traefik
read -p "Ingresa el email para Let's Encrypt en Traefik (Enter para: marionumza@gmail.com): " TRAEFIK_EMAIL
TRAEFIK_EMAIL=${TRAEFIK_EMAIL:-marionumza@gmail.com}
echo ""

# 1. Liberar paquetes retenidos (por si falló antes) y desinstalar versión vieja
echo "Desinstalando versiones anteriores de Docker..."
apt-mark unhold docker-ce docker-ce-cli > /dev/null 2>&1
apt-get remove -y docker docker-engine docker.io containerd runc docker-compose > /dev/null 2>&1

# 2. Dependencias y utilidades (incluyendo mc)
echo "Instalando dependencias y Midnight Commander (mc)..."
apt-get update
apt-get install -y ca-certificates curl gnupg lsb-release mc

# 3. Repositorio oficial de Docker
echo "Configurando repositorio de Docker..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Detectar el nombre en clave de Ubuntu (ej. jammy, noble)
UBUNTU_CODENAME=$(lsb_release -cs)

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $UBUNTU_CODENAME stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# 4. Instalar Docker CE v27.x fijado (Detectando versión de Ubuntu dinámicamente)
apt-get update

# Detectar la versión numérica de Ubuntu (ej. 22.04, 24.04)
UBUNTU_VERSION=$(lsb_release -rs)

# Construir el string de la versión del paquete
DOCKER_VERSION="5:27.5.1-1~ubuntu.${UBUNTU_VERSION}~${UBUNTU_CODENAME}"

echo "Instalando Docker versión: $DOCKER_VERSION"

apt-get install -y --allow-change-held-packages \
  docker-ce=$DOCKER_VERSION \
  docker-ce-cli=$DOCKER_VERSION \
  containerd.io \
  docker-compose-plugin

# 5. Fijar versión
apt-mark hold docker-ce docker-ce-cli

# 6. Symlink docker-compose
ln -sf /usr/libexec/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose

# 7. Creación de rutas y Configuración de Traefik
echo ""
echo "Configurando entorno Odoo y Traefik..."

# Crear la ruta de Odoo solicitada
mkdir -p /opt/odoo
echo "✅ Directorio /opt/odoo asegurado."

# Configurar Traefik
DIR="/opt/traefik"

mkdir -p "$DIR"
cd "$DIR"

# Verificar si acme.json existe antes de crear/pisar archivos
ACME_EXISTS=false
if [ -f "acme.json" ]; then
    ACME_EXISTS=true
fi

cat > docker-compose.yml << 'EOF'
version: "3.8"
services:
  traefik:
    image: traefik:v2.11
    container_name: traefik
    hostname: traefik
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    environment:
      - DOCKER_API_VERSION=1.40
    networks:
      - inverseproxy_shared
      - public
      - private
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - ./traefik.yml:/traefik.yml:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./acme.json:/acme.json
networks:
  inverseproxy_shared:
    name: inverseproxy_shared
    internal: true
    driver_opts:
      encrypted: 1
  private:
    internal: true
    driver_opts:
      encrypted: 1
  public:
EOF

cat > traefik.yml << EOF
# STATIC CONFIGURATION
log:
  level: INFO
api:
  dashboard: false
entryPoints:
  http:
    address: ":80"
  https:
    address: ":443"
providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
certificatesResolvers:
  letsencrypt:
    acme:
      email: $TRAEFIK_EMAIL
      storage: acme.json
      httpChallenge:
        entryPoint: http
EOF

if [ "$ACME_EXISTS" = true ]; then
    chmod 600 acme.json
    echo "✅ Directorio $DIR actualizado. acme.json ya existía y se conservó con permisos 600."
else
    touch acme.json
    chmod 600 acme.json
    echo "✅ Directorio $DIR recreado con docker-compose.yml, traefik.yml y acme.json (permisos 600)."
fi

# 8. Resumen final
echo ""
echo "==================================================="
echo "              RESUMEN DE INSTALACIÓN"
echo "==================================================="
echo "- Midnight Commander (mc): $(mc --version | head -n 1)"
echo "- Docker CE: $(docker --version)"
echo "- Docker Compose: $(docker compose version)"
echo "- Symlink Clásico: $(docker-compose version | head -n 1)"

if [ "$ACME_EXISTS" = true ]; then
    echo "- Certificados Traefik: acme.json ya existía y no fue reemplazado."
    echo "  (Si necesitas forzar certificados nuevos, bórralo manualmente)."
fi
echo "==================================================="

# Mostrar la clave pública si fue generada (o si ya existe en la ruta por defecto)
if [ -f ~/.ssh/id_rsa.pub ]; then
    echo ""
    echo "🔑 Tu clave pública RSA (cópiala entera para pegarla en Github u otros servidores):"
    echo "-------------------------------------------------------------------"
    cat ~/.ssh/id_rsa.pub
    echo "-------------------------------------------------------------------"
fi

echo "Proceso finalizado correctamente."
