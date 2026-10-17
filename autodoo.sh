#!/bin/bash
# Baja autodoo en /opt/autodoo usando la clave del servidor (~/.ssh/id_rsa).
#
# autodoo está en un repositorio privado: la clave del servidor tiene que estar cargada en la cuenta de GitHub
# que tiene acceso (perfil › Settings › SSH and GPG keys). El script no sigue hasta comprobar que entra.
# Si autodoo ya estaba en /opt/autodoo, solo revisa que pueda actualizarse; no apaga ni reinicia nada.
#
# PENDIENTE (etapa «autodoo Central»): una clave cargada en la cuenta puede leer y escribir en todos los
# repositorios de esa cuenta. Más adelante, deploy keys de solo lectura o un usuario de GitHub solo para servidores.

set -u

GITHUB_REPO="marionumza/autodoo"
REPO_SSH="git@github.com:${GITHUB_REPO}.git"
DEST="/opt/autodoo"
SSH_DIR="/root/.ssh"
KEY="${SSH_DIR}/id_rsa"

# Las preguntas se leen de la consola, así funciona también con «curl … | bash»
ask() { local __var="$1"; shift; read -r -p "$*" "$__var" < /dev/tty; }
line() { echo "-------------------------------------------------------------------"; }

echo "==================================================="
echo "   autodoo: descarga desde GitHub"
echo "==================================================="
echo ""

if [ "$(id -u)" -ne 0 ]; then
    echo "❌ Corré este script como root (sudo bash autodoo.sh)."
    exit 1
fi
if ! command -v git >/dev/null 2>&1; then
    echo "Instalando git..."
    apt-get update -qq && apt-get install -y -qq git
fi
if [ ! -f "${KEY}.pub" ]; then
    echo "❌ Este servidor no tiene clave SSH (${KEY}.pub)."
    echo "   Creala con docker-compose.sh (respondé «s» a la primera pregunta) y volvé a correr este script."
    exit 1
fi

# Huella de GitHub, para que git no pregunte
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"
if ! ssh-keygen -F github.com -f "${SSH_DIR}/known_hosts" >/dev/null 2>&1; then
    ssh-keyscan -t ed25519,rsa,ecdsa github.com >> "${SSH_DIR}/known_hosts" 2>/dev/null
fi

has_access() {
    GIT_SSH_COMMAND="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15" \
        git ls-remote "$REPO_SSH" HEAD >/dev/null 2>&1
}

# 1. Que la clave del servidor entre al repositorio; si no, insistir hasta que la cargue o cancele
if has_access; then
    echo "✅ La clave del servidor tiene acceso a autodoo."
else
    echo "🔑 Cargá esta clave en GitHub para que este servidor pueda bajar autodoo:"
    line
    cat "${KEY}.pub"
    line
    echo "  1. Abrí https://github.com/settings/ssh/new (con la cuenta que tiene acceso a ${GITHUB_REPO})."
    echo "  2. Título: $(hostname)"
    echo "  3. Pegá la clave de arriba (la línea entera) y tocá «Add SSH key»."
    echo ""
    while true; do
        ask RESP "Cuando la hayas agregado, presioná Enter para seguir (o escribí «c» para cancelar): "
        case "$RESP" in
            c|C|cancelar)
                echo ""
                echo "Cancelado. Cuando quieras, volvé a correr este script."
                exit 1 ;;
        esac
        echo "Comprobando el acceso..."
        if has_access; then
            echo "✅ Listo: GitHub aceptó la clave."
            break
        fi
        echo ""
        echo "⚠️  GitHub todavía no acepta la clave. Revisá que:"
        echo "   - la cargaste en tu cuenta (Settings › SSH and GPG keys), no como deploy key de otro repositorio:"
        echo "     GitHub no deja usar la misma clave como deploy key en dos repositorios;"
        echo "   - esa cuenta tiene acceso a ${GITHUB_REPO};"
        echo "   - copiaste la línea entera y tocaste «Add SSH key»."
        echo "   La clave es esta:"
        line
        cat "${KEY}.pub"
        line
    done
fi

# 2. Ya instalado: solo se apunta al repositorio con la clave del servidor
if [ -d "${DEST}/.git" ]; then
    git -C "$DEST" remote set-url origin "$REPO_SSH"
    if git -C "$DEST" fetch --quiet origin >/dev/null 2>&1; then
        echo "✅ autodoo ya estaba en ${DEST} y puede actualizarse desde GitHub. No se apagó ni se reinició nada."
        exit 0
    fi
    echo "⚠️  autodoo está en ${DEST}, pero no se pudo traer de GitHub. Revisá la red."
    exit 1
fi
if [ -e "$DEST" ]; then
    echo "❌ ${DEST} ya existe y no es una copia de autodoo. Movela o borrala y volvé a correr este script."
    exit 1
fi

# 3. Bajar autodoo
echo ""
echo "Bajando autodoo en ${DEST}..."
if ! git clone "$REPO_SSH" "$DEST"; then
    echo "❌ No se pudo bajar autodoo."
    exit 1
fi

echo ""
echo "==================================================="
echo "✅ autodoo quedó en ${DEST}."
echo ""
echo "Para encenderlo (con el Odoo ya instalado):"
echo "   cd ${DEST}"
echo "   python3 configure.py"
echo "   docker compose up -d --build"
echo "==================================================="
