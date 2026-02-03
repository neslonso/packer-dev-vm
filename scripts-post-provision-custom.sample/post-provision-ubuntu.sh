#!/bin/bash
# ==============================================================================
# POST-PROVISION-UBUNTU.SH - Comandos específicos para Ubuntu
# ==============================================================================
# Este script es llamado automáticamente desde post-provision.sh
# Solo se ejecuta si el flavor es 'ubuntu'
# ==============================================================================

echo ""
echo ">>> Configuración específica de Ubuntu..."

# ==============================================================================
# MÓDULOS ESPECÍFICOS DE UBUNTU
# ==============================================================================
# Descomenta los módulos específicos para Ubuntu:

# source "${SCRIPT_DIR}/modules/gnome-config.sh"

# ==============================================================================
# COMANDOS ESPECÍFICOS DE UBUNTU
# ==============================================================================
# Añade aquí comandos que solo se ejecuten en Ubuntu:

echo "    No hay comandos específicos de Ubuntu configurados."
