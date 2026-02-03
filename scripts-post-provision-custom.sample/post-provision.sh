#!/bin/bash
# ==============================================================================
# POST-PROVISION.SH - Punto de entrada único para post-provisión
# ==============================================================================
# Este script se ejecuta MANUALMENTE después de conectarse a la VM.
# Ejecución: ~/post-provision.sh
#
# El SSH agent estará activo, por lo que puedes usar claves SSH con passphrase.
#
# Flujo:
#   1. Ejecuta módulos comunes
#   2. Llama a post-provision-{flavor}.sh si existe
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Leer flavor del archivo generado durante provisioning
FLAVOR_FILE="${SCRIPT_DIR}/.flavor"
if [[ -f "$FLAVOR_FILE" ]]; then
    VM_FLAVOR=$(cat "$FLAVOR_FILE")
else
    VM_FLAVOR="unknown"
fi

echo ""
echo "============================================================"
echo ">>> POST-PROVISIÓN"
echo ">>> Flavor: ${VM_FLAVOR}"
echo ">>> $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "============================================================"
echo ""

# ==============================================================================
# MÓDULOS COMUNES
# ==============================================================================
# Descomenta los módulos que quieras ejecutar para TODOS los flavors:

# source "${SCRIPT_DIR}/modules/workspace.sh"
# source "${SCRIPT_DIR}/modules/repos.sh"

# ==============================================================================
# COMANDOS COMUNES
# ==============================================================================
# Añade aquí comandos que se ejecuten para todos los flavors:

echo "No hay módulos comunes configurados."

# ==============================================================================
# SCRIPT ESPECÍFICO DEL FLAVOR
# ==============================================================================
FLAVOR_SCRIPT="${SCRIPT_DIR}/post-provision-${VM_FLAVOR}.sh"

if [[ -f "$FLAVOR_SCRIPT" ]]; then
    echo ""
    echo ">>> Ejecutando script específico: post-provision-${VM_FLAVOR}.sh"
    source "$FLAVOR_SCRIPT"
else
    echo ""
    echo ">>> No existe script específico para flavor '${VM_FLAVOR}'"
fi

# ==============================================================================
# FIN
# ==============================================================================

echo ""
echo "============================================================"
echo ">>> Post-provisión completada!"
echo "============================================================"
echo ""
