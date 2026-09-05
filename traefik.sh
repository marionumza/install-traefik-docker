#!/bin/bash
set -e

DIR="/opt/odoo/inverseproxy"

# 1. Eliminar el directorio si existe, y crearlo de nuevo
if [ -d "$DIR" ]; then
  rm -rf "$DIR"
fi
mkdir -p "$DIR"
cd "$DIR"

# 2. docker-compose.yml
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

# 3. traefik.yml
cat > traefik.yml << 'EOF'
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
      email: marionumza@gmail.com  # ← CAMBIA ESTO POR TU EMAIL
      storage: acme.json
      httpChallenge:
        entryPoint: http
EOF

# 4. acme.json vacío con permisos correctos
touch acme.json
chmod 600 acme.json

echo "✅ Listo. Directorio $DIR recreado con docker-compose.yml, traefik.yml y acme.json (permisos 600)."
