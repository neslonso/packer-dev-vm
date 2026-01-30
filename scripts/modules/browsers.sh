#!/bin/bash
# ==============================================================================
# BROWSERS.SH - Instalación de navegadores web
# ==============================================================================
# Instala: Firefox, Chrome o Chromium según configuración
# Requiere: common.sh
# ==============================================================================

install_browser() {
    # Si es "none", salir inmediatamente
    if [[ "${INSTALL_BROWSER}" == "none" ]]; then
        log_task "Sin navegador adicional."
        return 0
    fi

    # Si es "all", expandir a todos los navegadores soportados
    local browsers_to_install="${INSTALL_BROWSER}"
    if [[ "${INSTALL_BROWSER}" == "all" ]]; then
        browsers_to_install="firefox,chrome,chromium"
    fi

    log_section "Configurando navegadores: ${browsers_to_install}..."

    # Iterar sobre la lista separada por comas
    IFS=',' read -ra ADDR <<< "${browsers_to_install}"
    for browser in "${ADDR[@]}"; do
        case "${browser}" in
            "firefox")
                log_task "Instalando Firefox..."
                apt-get install -y firefox
                log_success "Firefox instalado"
                ;;
            "chrome")
                log_task "Instalando Google Chrome..."
                # Download Chrome directly as .deb to avoid GPG key issues
                local chrome_deb="/tmp/google-chrome-stable.deb"
                log_task "Descargando Google Chrome .deb..."
                if ! curl --max-time 120 --fail --silent --show-error --location \
                    "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb" \
                    -o "$chrome_deb"; then
                    log_error "Error descargando Google Chrome"
                    return 1
                fi

                log_task "Instalando dependencias y paquete Chrome..."
                apt-get install -y "$chrome_deb"
                rm -f "$chrome_deb"
                log_success "Google Chrome instalado"
                ;;
            "chromium")
                log_task "Instalando Chromium..."
                apt-get install -y chromium
                log_success "Chromium instalado"
                ;;
            "none")
                # Ignorar si está mezclado con otros
                ;;
            *)
                log_warning "Navegador desconocido: ${browser}"
                ;;
        esac
    done
}

# Ejecutar
install_browser
