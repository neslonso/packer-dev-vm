#!/bin/bash
# ==============================================================================
# BROWSERS.SH - Instalación de navegadores web
# ==============================================================================
# Instala: Firefox, Chrome o Chromium según configuración
# Requiere: common.sh
# ==============================================================================

# Mapeo de navegador a archivo .desktop
get_desktop_file() {
    case "$1" in
        "firefox")  echo "firefox.desktop" ;;
        "chrome")   echo "google-chrome.desktop" ;;
        "chromium") echo "chromium.desktop" ;;
    esac
}

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

    # Guardar el primer navegador para establecerlo como predeterminado
    local first_browser=""

    # Iterar sobre la lista separada por comas
    IFS=',' read -ra ADDR <<< "${browsers_to_install}"
    for browser in "${ADDR[@]}"; do
        # Guardar el primer navegador válido
        if [[ -z "$first_browser" && "$browser" != "none" ]]; then
            first_browser="$browser"
        fi

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

    # Establecer el primer navegador como predeterminado
    if [[ -n "$first_browser" ]]; then
        local desktop_file
        desktop_file=$(get_desktop_file "$first_browser")
        if [[ -n "$desktop_file" ]]; then
            log_task "Estableciendo ${first_browser} como navegador predeterminado..."

            # Método 1: Escribir directamente en mimeapps.list (funciona sin sesión gráfica)
            local mimeapps_dir="${HOME_DIR}/.config"
            local mimeapps_file="${mimeapps_dir}/mimeapps.list"
            mkdir -p "$mimeapps_dir"

            # Crear o actualizar mimeapps.list
            cat > "$mimeapps_file" << MIMEAPPS_EOF
[Default Applications]
x-scheme-handler/http=${desktop_file}
x-scheme-handler/https=${desktop_file}
x-scheme-handler/about=${desktop_file}
text/html=${desktop_file}
application/xhtml+xml=${desktop_file}
application/x-extension-htm=${desktop_file}
application/x-extension-html=${desktop_file}
application/x-extension-shtml=${desktop_file}
application/x-extension-xhtml=${desktop_file}
application/x-extension-xht=${desktop_file}
MIMEAPPS_EOF
            chown "${USERNAME}:${USERNAME}" "$mimeapps_file"

            # Método 2: update-alternatives (sistema)
            case "$first_browser" in
                "firefox")  update-alternatives --set x-www-browser /usr/bin/firefox 2>/dev/null || true ;;
                "chrome")   update-alternatives --set x-www-browser /usr/bin/google-chrome-stable 2>/dev/null || true ;;
                "chromium") update-alternatives --set x-www-browser /usr/bin/chromium 2>/dev/null || true ;;
            esac

            log_success "${first_browser} establecido como predeterminado"
        fi
    fi
}

# Ejecutar
install_browser
