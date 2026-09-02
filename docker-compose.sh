#!/bin/bash
# Upgrade a Docker CE v27.x

# 1. Desinstalar versión vieja
apt-get remove -y docker docker-engine docker.io containerd runc docker-compose

# 2. Dependencias
apt-get update
apt-get install -y ca-certificates curl gnupg lsb-release

# 3. Repositorio oficial de Docker
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# 4. Instalar Docker CE v27.x fijado
apt-get update
apt-get install -y \
  docker-ce=5:27.5.1-1~ubuntu.22.04~jammy \
  docker-ce-cli=5:27.5.1-1~ubuntu.22.04~jammy \
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
