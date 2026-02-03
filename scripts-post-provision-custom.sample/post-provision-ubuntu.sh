#!/bin/bash
# ==============================================================================
# POST-PROVISION-UBUNTU.SH - Orquestador post-provisión para Ubuntu
# ==============================================================================
# Este script se ejecuta MANUALMENTE después de conectarse a la VM.
# Ejecución: ~/post-provision.sh
#
# El SSH agent estará activo, por lo que puedes usar claves SSH con passphrase.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "============================================================"
echo ">>> POST-PROVISIÓN UBUNTU"
echo ">>> $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "============================================================"
echo ""

# ==============================================================================
# MÓDULOS
# ==============================================================================
# Descomenta los módulos que necesites:

# source "${SCRIPT_DIR}/modules/workspace.sh"
# source "${SCRIPT_DIR}/modules/repos.sh"

# ==============================================================================
# COMANDOS PERSONALIZADOS
# ==============================================================================
# Añade aquí comandos adicionales:

echo "No hay comandos personalizados configurados."
echo "Edita ~/post-provision/post-provision-ubuntu.sh para añadirlos."

# ==============================================================================
# FIN
# ==============================================================================

echo ""
echo "============================================================"
echo ">>> Post-provisión completada!"
echo "============================================================"
echo ""
