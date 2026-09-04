#!/bin/bash
# Upgrade a Docker CE v27.x de forma dinámica según la versión de Ubuntu

# 1. Desinstalar versión vieja
apt-get remove -y docker docker-engine docker.io containerd runc docker-compose

# 2. Dependencias
apt-get update
apt-get install -y ca-certificates curl gnupg lsb-release

# 3. Repositorio oficial de Docker
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
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

apt-get install -y \
  docker-ce=$DOCKER_VERSION \
  docker-ce-cli=$DOCKER_VERSION \
  containerd.io \
  docker-compose-plugin

# 5. Fijar versión
apt-mark hold docker-ce docker-ce-cli

# 6. Symlink docker-compose
ln -sf /usr/libexec/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose

# 7. Verificar
docker version
docker compose version
docker-compose version
