#!/bin/bash
# ==============================================================================
# WORKSPACE.SH - Crear estructura de directorios de trabajo
# ==============================================================================

echo ">>> Creando estructura de workspace..."

# Estructura por proveedor de git
mkdir -p ~/workspace/src/github.com
mkdir -p ~/workspace/src/gitlab.com
mkdir -p ~/workspace/src/bitbucket.org

# Directorios adicionales
mkdir -p ~/workspace/tmp
mkdir -p ~/workspace/docs

echo "    Estructura creada en ~/workspace/"
