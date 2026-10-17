#!/bin/bash
# Instala autodoo en este servidor, o lo prepara para que pueda actualizarse.
#
# autodoo está en un repositorio privado. Este script crea una clave solo para autodoo, te la muestra para
# que la cargues en GitHub y no sigue hasta comprobar que funciona. Esa clave es aparte de la del servidor
# (~/.ssh/id_rsa), que queda libre para los repositorios de Odoo de cada cliente: GitHub no acepta la misma
# clave en dos repositorios.
#
# Se puede correr las veces que haga falta:
#   - Servidor nuevo, con el Odoo ya instalado: crea la clave, clona autodoo en /opt/autodoo y lo enciende.
#   - Servidor nuevo, sin Odoo todavía: deja lista la clave; volvé a correrlo cuando el Odoo esté andando.
#   - Servidor con autodoo: deja lista la clave y apunta autodoo a ella, para que «Actualizar» funcione.
#     No apaga ni reinicia nada.
#   - Servidor con la carpeta vieja /opt/autogestion: además ofrece pasarla a /opt/autodoo.

set -u

GITHUB_REPO="marionumza/autodoo"
HOST_ALIAS="github-autodoo"
REPO_SSH="git@${HOST_ALIAS}:${GITHUB_REPO}.git"
DEST="/opt/autodoo"
OLD_DEST="/opt/autogestion"
SSH_DIR="/root/.ssh"
KEY="${SSH_DIR}/id_ed25519_autodoo"
SSH_CONFIG="${SSH_DIR}/config"

# Las preguntas se leen de la consola, así funciona también con «curl … | bash»
ask() { local __var="$1"; shift; read -r -p "$*" "$__var" < /dev/tty; }
ask_secret() { local __var="$1"; shift; read -r -s -p "$*" "$__var" < /dev/tty; echo ""; }
line() { echo "-------------------------------------------------------------------"; }

echo "==================================================="
echo "   autodoo: instalación y acceso a GitHub"
echo "==================================================="
echo ""

if [ "$(id -u)" -ne 0 ]; then
    echo "❌ Corré este script como root (sudo bash autodoo.sh)."
    exit 1
fi
if ! command -v git >/dev/null 2>&1 || ! command -v ssh-keygen >/dev/null 2>&1; then
    echo "Instalando git y ssh..."
    apt-get update -qq && apt-get install -y -qq git openssh-client
fi

# 1. Clave solo para autodoo (si ya existe, se usa la misma)
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"
if [ -f "$KEY" ]; then
    echo "✅ La clave de autodoo ya existe en este servidor; se usa la misma."
else
    if ! ssh-keygen -t ed25519 -N "" -C "autodoo@$(hostname)" -f "$KEY" -q; then
        echo "❌ No se pudo crear la clave de autodoo."
        exit 1
    fi
    echo "✅ Clave de autodoo creada."
fi

# 2. Alias para que GitHub reciba esta clave solo cuando se trata de autodoo
if [ ! -f "$SSH_CONFIG" ] || ! grep -qE "^Host[[:space:]]+${HOST_ALIAS}([[:space:]]|$)" "$SSH_CONFIG"; then
    {
        echo ""
        echo "# autodoo: clave propia para su repositorio (la agregó autodoo.sh)"
        echo "Host ${HOST_ALIAS}"
        echo "    HostName github.com"
        echo "    HostKeyAlias github.com"
        echo "    User git"
        echo "    IdentityFile ${KEY}"
        echo "    IdentitiesOnly yes"
    } >> "$SSH_CONFIG"
fi
chmod 600 "$SSH_CONFIG"
# Huella de GitHub, para que git no pregunte
if ! ssh-keygen -F github.com -f "${SSH_DIR}/known_hosts" >/dev/null 2>&1; then
    ssh-keyscan -t ed25519,rsa,ecdsa github.com >> "${SSH_DIR}/known_hosts" 2>/dev/null
fi

has_access() {
    GIT_SSH_COMMAND="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15" \
        git ls-remote "$REPO_SSH" HEAD >/dev/null 2>&1
}

# 3. Que la cargue en GitHub; no se sigue sin acceso
if has_access; then
    echo "✅ Este servidor ya tiene acceso al repositorio de autodoo."
else
    echo ""
    echo "🔑 Cargá esta clave en GitHub para que este servidor pueda bajar autodoo:"
    line
    cat "${KEY}.pub"
    line
    echo "  1. Abrí https://github.com/${GITHUB_REPO}/settings/keys/new"
    echo "  2. Título: $(hostname)"
    echo "  3. Pegá la clave de arriba (la línea entera)."
    echo "  4. NO tildes «Allow write access»: autodoo solo necesita leer."
    echo "  5. Tocá «Add key»."
    echo ""
    while true; do
        ask RESP "Cuando la hayas agregado, presioná Enter para seguir (o escribí «c» para cancelar): "
        case "$RESP" in
            c|C|cancelar)
                echo ""
                echo "Cancelado. La clave quedó creada; cuando quieras, volvé a correr este script."
                exit 1 ;;
        esac
        echo "Comprobando el acceso..."
        if has_access; then
            echo "✅ Listo: GitHub aceptó la clave."
            break
        fi
        echo ""
        echo "⚠️  GitHub todavía no acepta la clave. Revisá que:"
        echo "   - la cargaste en el repositorio ${GITHUB_REPO} (no en tu cuenta ni en otro repositorio);"
        echo "   - copiaste la línea entera, desde «ssh-ed25519» hasta «autodoo@$(hostname)»;"
        echo "   - tocaste «Add key» y GitHub la muestra en la lista."
        echo "   La clave es esta:"
        line
        cat "${KEY}.pub"
        line
    done
fi

# Apunta una instalación existente a la clave nueva (sin tocar los contenedores)
point_remote() {
    local dir="$1"
    git -C "$dir" remote set-url origin "$REPO_SSH"
    if git -C "$dir" fetch --quiet origin >/dev/null 2>&1; then
        echo "✅ autodoo en ${dir} usa la clave nueva: «Actualizar» y el aviso de versiones vuelven a funcionar."
    else
        echo "⚠️  Se cambió la dirección del repositorio en ${dir}, pero no se pudo traer de GitHub. Revisá la red."
    fi
}

# 4. Instalación existente: solo se ajusta el acceso
if [ -d "${DEST}/.git" ]; then
    point_remote "$DEST"
    echo ""
    echo "No se apagó ni se reinició nada. Proceso terminado."
    exit 0
fi

# 4b. Carpeta vieja: ofrecer pasarla a /opt/autodoo
if [ -d "${OLD_DEST}/.git" ]; then
    point_remote "$OLD_DEST"
    echo ""
    echo "autodoo está en la carpeta vieja ${OLD_DEST}."
    ask RESP "¿Lo paso a ${DEST}? Se apaga y se vuelve a encender (un minuto, aprox.) (s/n): "
    if [ "$RESP" = "s" ] || [ "$RESP" = "S" ]; then
        (cd "$OLD_DEST" && docker compose down) || { echo "❌ No se pudo apagar. No se movió nada."; exit 1; }
        mv "$OLD_DEST" "$DEST"
        (cd "$DEST" && docker compose up -d --build) || { echo "❌ No encendió en ${DEST}. Revisá con: cd ${DEST} && docker compose up -d"; exit 1; }
        echo "✅ autodoo quedó en ${DEST} y está encendido."
    else
        echo "Quedó en ${OLD_DEST}; funciona igual."
    fi
    exit 0
fi

# 5. Instalación nueva: hace falta el Odoo (Doodba) instalado
if ! ls /opt/*/prod.yaml /opt/odoo/*/prod.yaml >/dev/null 2>&1; then
    echo ""
    echo "El acceso a GitHub quedó listo, pero todavía no hay un Odoo instalado en este servidor."
    echo "Cuando el Odoo esté andando, volvé a correr este script para instalar autodoo."
    exit 0
fi

echo ""
echo "Instalando autodoo en ${DEST}..."
if ! git clone "$REPO_SSH" "$DEST"; then
    echo "❌ No se pudo bajar autodoo."
    exit 1
fi
cd "$DEST" || exit 1

# configure.py arma el .env (dominio, claves) y conserva lo que ya tuviera
if ! python3 configure.py; then
    echo "❌ No se pudo configurar autodoo. Corregí lo que indica arriba y corré: cd ${DEST} && python3 configure.py"
    exit 1
fi

# Correo de autodoo: la contraseña va solo en el .env (nunca en el código). Si ya está, no se toca.
if ! grep -q "^DOODBA_SMTP_PASSWORD=" .env 2>/dev/null; then
    echo ""
    echo "Correo de autodoo (avisos y resúmenes)."
    ask_secret SMTP_PASS "Contraseña de la casilla (Enter para cargarla después en Ajustes): "
    if [ -n "$SMTP_PASS" ]; then
        printf '\n# Correo de autodoo\nDOODBA_SMTP_PASSWORD=%s\n' "$SMTP_PASS" >> .env
        chmod 600 .env
        echo "✅ Contraseña guardada en el .env."
    fi
fi

echo ""
echo "Encendiendo autodoo (la primera vez tarda unos minutos)..."
if ! docker compose up -d --build; then
    echo "❌ autodoo no encendió. Revisá con: cd ${DEST} && docker compose up -d --build"
    exit 1
fi

DOMAIN=$(grep -m1 "^DOMAIN=" .env | cut -d= -f2-)
echo ""
echo "==================================================="
echo "✅ autodoo instalado y encendido."
[ -n "$DOMAIN" ] && echo "   Entrá en https://${DOMAIN}/autogestion/"
echo "==================================================="
