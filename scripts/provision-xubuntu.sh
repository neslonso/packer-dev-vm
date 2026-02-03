#!/bin/bash
# ==============================================================================
# PROVISION-XUBUNTU.SH - Orquestador para Xubuntu (XFCE)
# ==============================================================================
# Este script coordina la ejecución de todos los módulos de provisioning
# para una VM con Xubuntu y XFCE.
# ==============================================================================

set -euo pipefail

# Determinar directorio de scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="${SCRIPT_DIR}/modules"

# ==============================================================================
# CARGAR MÓDULO COMÚN (logging, variables, funciones)
# ==============================================================================
source "${MODULES_DIR}/common.sh"

# ==============================================================================
# INICIO DEL PROVISIONING
# ==============================================================================
log_msg ""
log_msg "============================================================"
log_msg ">>> PROVISIONING XUBUNTU (XFCE)"
log_msg ">>> Timestamp: $(date '+%Y-%m-%d %H:%M:%S %Z')"
log_msg ">>> Log file: $PROVISION_LOG"
log_msg "============================================================"
log_msg ""
log_msg "VARIABLES DE BUILD:"
log_msg "  - Usuario: ${USERNAME}"
log_msg "  - Hostname: ${HOSTNAME}"
log_msg "  - Timezone: ${TIMEZONE}"
log_msg "  - Locale: ${LOCALE}"
log_msg "  - Keyboard: ${KEYBOARD}"
log_msg "  - Shell: ${SHELL_TYPE}"
log_msg "  - Prompt Theme: ${PROMPT_THEME}"
log_msg "  - Nerd Font: ${NERD_FONT}"
log_msg "  - Desktop Theme: ${DESKTOP_THEME}"
log_msg "  - Install VS Code: ${INSTALL_VSCODE}"
log_msg "  - Install Antigravity: ${INSTALL_ANTIGRAVITY}"
log_msg "  - Install Cursor: ${INSTALL_CURSOR}"
log_msg "  - Install Sublime Merge: ${INSTALL_SUBLIMEMERGE}"
log_msg "  - Install DBeaver: ${INSTALL_DBEAVER}"
log_msg "  - Install Browser: ${INSTALL_BROWSER}"
log_msg "  - Install Messaging: ${INSTALL_MESSAGING}"
log_msg "  - Install Privacy: ${INSTALL_PRIVACY}"
log_msg "  - Install Portainer: ${INSTALL_PORTAINER}"
log_msg "  - Network Mode: ${NETWORK_MODE}"
log_msg ""

# ==============================================================================
# DEFINICIÓN DE PASOS
# ==============================================================================
# Formato: "modulo1 modulo2 ...|Descripción del paso"
# Los módulos se ejecutan en orden dentro de cada paso.
# El total de pasos y la numeración se calculan automáticamente.
# ==============================================================================

declare -a STEPS=(
    "system-base.sh|Sistema base"
    "maldet.sh|Seguridad (maldet)"
    "docker.sh|Docker"
    "git.sh|Git"
    "fonts.sh|Nerd Fonts"
    "shell.sh|Shell y Prompt"
    "ssh-agent.sh|SSH Keys y Agent"
    "databases.sh|Clientes de BD"
    "editors/vscode.sh editors/antigravity.sh editors/cursor.sh editors/sublime-merge.sh|Editores"
    "browsers.sh|Navegador"
    "messaging.sh|Mensajería"
    "privacy.sh|Privacidad"
    "api-tools.sh|Herramientas de API"
    "desktop/xfce.sh aliases.sh history.sh packer-shutdown.sh|Desktop XFCE"
    "rdp/xrdp.sh|xrdp"
    "luks-finalize.sh|Finalizar LUKS"
)

# ==============================================================================
# EJECUTAR MÓDULOS EN ORDEN
# ==============================================================================

TOTAL_STEPS=${#STEPS[@]}
CURRENT_STEP=1

for step in "${STEPS[@]}"; do
    modules="${step%%|*}"
    description="${step#*|}"
    log_section "${CURRENT_STEP}/${TOTAL_STEPS} ${description}"
    for module in $modules; do
        source "${MODULES_DIR}/${module}"
    done
    ((CURRENT_STEP++))
done

# Welcome document (sin numerar, es informativo)
source "${MODULES_DIR}/welcome.sh"

# ==============================================================================
# FIN
# ==============================================================================

log_section "✓ Provisioning completado!"
log_msg ""
log_msg "Resumen:"
log_msg "  - Flavor: Xubuntu (XFCE)"
log_msg "  - Usuario: ${USERNAME}"
log_msg "  - Shell: ${SHELL_TYPE}"
log_msg "  - Prompt: ${PROMPT_THEME}"
log_msg "  - Docker: instalado"
log_msg "  - Portainer: ${INSTALL_PORTAINER}"
log_msg "  - VS Code: ${INSTALL_VSCODE}"
log_msg "  - Antigravity: ${INSTALL_ANTIGRAVITY}"
log_msg "  - Cursor: ${INSTALL_CURSOR}"
log_msg "  - Sublime Merge: ${INSTALL_SUBLIMEMERGE}"
log_msg "  - DBeaver: ${INSTALL_DBEAVER}"
log_msg "  - Navegador: ${INSTALL_BROWSER}"
log_msg "  - Mensajería: ${INSTALL_MESSAGING}"
log_msg "  - Privacidad: ${INSTALL_PRIVACY}"
log_msg "  - Nerd Font: ${NERD_FONT}"
log_msg "  - RDP: xrdp (puerto 3389)"
log_msg "  - Red: ${NETWORK_MODE} - IP: $(hostname -I | awk '{print $1}')"
log_msg ""
log_msg "Detalles completos en: $PROVISION_LOG"

# Restore stdout/stderr (ignorar errores si los file descriptors no existen)
exec 1>&3 2>&4 3>&- 4>&- 2>/dev/null || true

# Salir con éxito
exit 0
