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
log_msg "  - Install Browser: ${INSTALL_BROWSER}"
log_msg "  - Install Portainer: ${INSTALL_PORTAINER}"
log_msg "  - Network Mode: ${NETWORK_MODE}"
log_msg ""

# ==============================================================================
# EJECUTAR MÓDULOS EN ORDEN
# ==============================================================================

# 1. Sistema base (red, locale, herramientas)
log_section "1/10 Sistema base"
source "${MODULES_DIR}/system-base.sh"

# 2. Docker
log_section "2/10 Docker"
source "${MODULES_DIR}/docker.sh"

# 3. Git
log_section "3/10 Git"
source "${MODULES_DIR}/git.sh"

# 4. Nerd Fonts
log_section "4/10 Nerd Fonts"
source "${MODULES_DIR}/fonts.sh"

# 5. Shell y Prompt
log_section "5/10 Shell y Prompt"
source "${MODULES_DIR}/shell.sh"

# 6. Clientes de base de datos
log_section "6/10 Clientes de BD"
source "${MODULES_DIR}/databases.sh"

# 7. Editores
log_section "7/10 Editores"
source "${MODULES_DIR}/editors/vscode.sh"
source "${MODULES_DIR}/editors/antigravity.sh"
source "${MODULES_DIR}/editors/cursor.sh"
source "${MODULES_DIR}/editors/sublime-merge.sh"

# 8. Navegador
log_section "8/10 Navegador"
source "${MODULES_DIR}/browsers.sh"

# 9. Desktop XFCE + Aliases
log_section "9/10 Desktop XFCE"
source "${MODULES_DIR}/desktop/xfce.sh"
source "${MODULES_DIR}/aliases.sh"
source "${MODULES_DIR}/packer-shutdown.sh"

# 10. RDP (xrdp)
log_section "10/10 xrdp"
source "${MODULES_DIR}/rdp/xrdp.sh"

# Welcome document
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
log_msg "  - Navegador: ${INSTALL_BROWSER}"
log_msg "  - Nerd Font: ${NERD_FONT}"
log_msg "  - RDP: xrdp (puerto 3389)"
log_msg "  - Red: ${NETWORK_MODE} - IP: $(hostname -I | awk '{print $1}')"
log_msg ""
log_msg "Detalles completos en: $PROVISION_LOG"

# Restore stdout/stderr
exec 1>&3 2>&4 3>&- 4>&-
