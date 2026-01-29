#!/bin/bash
# ==============================================================================
# API-TOOLS.SH - Instalación de clientes de API (Bruno, Insomnia)
# ==============================================================================
# Requiere: common.sh
# ==============================================================================

install_api_tools() {
    log_section "Instalando herramientas de API..."

    # Convertir la lista separada por comas en un array
    IFS=',' read -ra TOOLS <<< "${VM_INSTALL_API_TOOLS}"

    for tool in "${TOOLS[@]}"; do
        case "${tool}" in
            "bruno")
                log_task "Instalando Bruno API Client..."

                # Obtener la última versión de GitHub
                BRUNO_VERSION=$(curl --max-time 30 --fail --silent --show-error https://api.github.com/repos/usebruno/bruno/releases/latest 2>/dev/null | jq -r '.tag_name' 2>/dev/null || echo "")

                if [[ -z "$BRUNO_VERSION" || "$BRUNO_VERSION" == "null" ]]; then
                    log_warning "Failed to fetch Bruno latest version, using fallback v1.31.0"
                    BRUNO_VERSION="v1.31.0"
                fi

                # Limpiar la 'v' de la versión para el nombre del archivo
                BR_VER_CLEAN="${BRUNO_VERSION#v}"
                DEB_URL="https://github.com/usebruno/bruno/releases/download/${BRUNO_VERSION}/bruno_${BR_VER_CLEAN}_amd64_linux.deb"
                TEMP_DEB="/tmp/bruno.deb"

                # Descargar con reintentos (GitHub a veces tarda en redirigir)
                if curl --retry 3 --retry-delay 2 --max-time 120 --fail -Lo "$TEMP_DEB" "$DEB_URL"; then
                    apt-get install -y "$TEMP_DEB"
                    rm -f "$TEMP_DEB"
                    log_success "Bruno ${BRUNO_VERSION} instalado correctamente"
                else
                    log_error "Error al descargar Bruno de ${DEB_URL}"
                fi
                ;;

            "insomnia")
                log_task "Instalando Insomnia..."

                # Obtener la URL del último .deb de GitHub Releases
                # El tag suele ser 'core@X.Y.Z'
                INSOMNIA_DEB_URL=$(curl --max-time 30 --fail --silent --show-error https://api.github.com/repos/Kong/insomnia/releases/latest | jq -r '.assets[] | select(.name | endswith(".deb")) | .browser_download_url' 2>/dev/null || echo "")

                if [[ -n "$INSOMNIA_DEB_URL" && "$INSOMNIA_DEB_URL" != "null" ]]; then
                    TEMP_DEB="/tmp/insomnia.deb"
                    if curl --retry 3 --retry-delay 2 --max-time 120 --fail -Lo "$TEMP_DEB" "$INSOMNIA_DEB_URL"; then
                        apt-get install -y "$TEMP_DEB"
                        rm -f "$TEMP_DEB"
                        log_success "Insomnia instalado correctamente desde GitHub"
                    else
                        log_error "Error al descargar Insomnia de ${INSOMNIA_DEB_URL}"
                    fi
                else
                    log_error "No se pudo encontrar la URL de descarga de Insomnia en GitHub"
                fi
                ;;

            "none")
                log_task "No se seleccionaron herramientas de API adicionales."
                ;;

            *)
                if [[ -n "${tool}" ]]; then
                    log_warning "Herramienta de API desconocida: ${tool}"
                fi
                ;;
        esac
    done

    log_success "Finalizada la configuración de herramientas de API"
}

# Ejecutar
install_api_tools
