#!/bin/bash
# ==============================================================================
# POST-PROVISION-UBUNTU.SH - Script de post-provisión para Ubuntu
# ==============================================================================
# Este script se ejecuta MANUALMENTE después de conectarse a la VM.
# Se sube automáticamente a ~/post-provision.sh durante el provisioning.
#
# Útil para: clonar repositorios, configuración inicial con SSH, etc.
# El SSH agent estará activo cuando ejecutes este script.
#
# Ejecución: ~/post-provision.sh
# ==============================================================================

set -euo pipefail

echo ""
echo "============================================================"
echo ">>> POST-PROVISIÓN UBUNTU"
echo ">>> $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "============================================================"
echo ""

# ==============================================================================
# PERSONALIZA AQUÍ TUS COMANDOS
# ==============================================================================

# Ejemplo: Crear estructura de directorios
# mkdir -p ~/workspace/src/github.com
# mkdir -p ~/workspace/src/gitlab.com

# Ejemplo: Clonar repositorios (SSH agent debe estar activo)
# git clone git@github.com:usuario/repo.git ~/workspace/src/github.com/usuario/repo
# git clone git@gitlab.com:empresa/proyecto.git ~/workspace/src/gitlab.com/empresa/proyecto

# ==============================================================================
# FIN
# ==============================================================================

echo ""
echo "============================================================"
echo ">>> Post-provisión completada!"
echo "============================================================"
echo ""
