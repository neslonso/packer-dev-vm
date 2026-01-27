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
                download_and_verify_gpg_key \
                    "https://dl.google.com/linux/linux_signing_key.pub" \
                    "/etc/apt/keyrings/google-chrome.gpg" \
                    "$GOOGLE_GPG_FINGERPRINT" \
                    "Google Chrome"

                echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list
                apt-get update
                apt-get install -y google-chrome-stable
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
