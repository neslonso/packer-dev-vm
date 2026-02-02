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
log_msg "  - Install Messaging: ${INSTALL_MESSAGING}"
log_msg "  - Install Privacy: ${INSTALL_PRIVACY}"
log_msg "  - Install Portainer: ${INSTALL_PORTAINER}"
log_msg "  - Network Mode: ${NETWORK_MODE}"
log_msg ""

# ==============================================================================
# EJECUTAR MÓDULOS EN ORDEN
# ==============================================================================

# 1. Sistema base (red, locale, herramientas)
log_section "1/17 Sistema base"
source "${MODULES_DIR}/system-base.sh"

# 2. Seguridad (maldet)
log_section "2/17 Seguridad (maldet)"
source "${MODULES_DIR}/maldet.sh"

# 3. Docker
log_section "3/17 Docker"
source "${MODULES_DIR}/docker.sh"

# 4. Git
log_section "4/17 Git"
source "${MODULES_DIR}/git.sh"

# 5. Nerd Fonts
log_section "5/17 Nerd Fonts"
source "${MODULES_DIR}/fonts.sh"

# 6. Shell y Prompt
log_section "6/17 Shell y Prompt"
source "${MODULES_DIR}/shell.sh"

# 7. SSH Keys y Agent
log_section "7/17 SSH Keys y Agent"
source "${MODULES_DIR}/ssh-agent.sh"

# 8. Clientes de base de datos
log_section "8/17 Clientes de BD"
source "${MODULES_DIR}/databases.sh"

# 9. Editores
log_section "9/17 Editores"
source "${MODULES_DIR}/editors/vscode.sh"
source "${MODULES_DIR}/editors/antigravity.sh"
source "${MODULES_DIR}/editors/cursor.sh"
source "${MODULES_DIR}/editors/sublime-merge.sh"

# 10. Navegador
log_section "10/17 Navegador"
source "${MODULES_DIR}/browsers.sh"

# 11. Mensajeria (Slack, Signal, Telegram)
log_section "11/17 Mensajeria"
source "${MODULES_DIR}/messaging.sh"

# 12. Privacidad (Keybase, Element)
log_section "12/17 Privacidad"
source "${MODULES_DIR}/privacy.sh"

# 13. Herramientas de API (Bruno, Insomnia)
log_section "13/17 Herramientas de API"
source "${MODULES_DIR}/api-tools.sh"

# 14. Desktop XFCE + Aliases
log_section "14/17 Desktop XFCE"
source "${MODULES_DIR}/desktop/xfce.sh"
source "${MODULES_DIR}/aliases.sh"
source "${MODULES_DIR}/history.sh"
source "${MODULES_DIR}/packer-shutdown.sh"

# 15. RDP (xrdp)
log_section "15/17 xrdp"
source "${MODULES_DIR}/rdp/xrdp.sh"

# 16. Comandos personalizados (post-provisioning)
log_section "16/17 Comandos personalizados"
source "${MODULES_DIR}/custom-commands.sh"

# 17. Finalizar LUKS (eliminar keyfile, requerir password)
log_section "17/17 Finalizar LUKS"
source "${MODULES_DIR}/luks-finalize.sh"

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
