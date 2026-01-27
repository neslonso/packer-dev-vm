#!/bin/bash
# ==============================================================================
# BROWSERS.SH - Instalación de navegadores web
# ==============================================================================
# Instala: Firefox, Chrome o Chromium según configuración
# Requiere: common.sh
# ==============================================================================

install_browser() {
    log_section "Configurando navegador (${INSTALL_BROWSER})..."

    case "${INSTALL_BROWSER}" in
        "firefox")
            apt-get install -y firefox
            log_success "Firefox instalado"
            ;;
        "chrome")
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
            apt-get install -y chromium
            log_success "Chromium instalado"
            ;;
        "none")
            log_task "Sin navegador adicional."
            ;;
    esac
}

# Ejecutar
install_browser
