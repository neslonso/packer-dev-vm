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

# Mapeo de navegador a nombre XFCE helper
get_xfce_helper() {
    case "$1" in
        "firefox")  echo "firefox" ;;
        "chrome")   echo "google-chrome" ;;
        "chromium") echo "chromium" ;;
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

            # Contenido del mimeapps.list
            local mimeapps_content="[Default Applications]
x-scheme-handler/http=${desktop_file}
x-scheme-handler/https=${desktop_file}
x-scheme-handler/about=${desktop_file}
x-scheme-handler/unknown=${desktop_file}
text/html=${desktop_file}
application/xhtml+xml=${desktop_file}
application/x-extension-htm=${desktop_file}
application/x-extension-html=${desktop_file}
application/x-extension-shtml=${desktop_file}
application/x-extension-xhtml=${desktop_file}
application/x-extension-xht=${desktop_file}
"

            # 1. Nivel sistema: /etc/xdg/mimeapps.list (máxima prioridad)
            mkdir -p /etc/xdg
            echo "$mimeapps_content" > /etc/xdg/mimeapps.list

            # 2. Nivel usuario: ~/.config/mimeapps.list
            local user_mimeapps_dir="${HOME_DIR}/.config"
            mkdir -p "$user_mimeapps_dir"
            echo "$mimeapps_content" > "${user_mimeapps_dir}/mimeapps.list"
            chown -R "${USERNAME}:${USERNAME}" "$user_mimeapps_dir"

            # 3. Nivel usuario alternativo: ~/.local/share/applications/mimeapps.list
            local user_apps_dir="${HOME_DIR}/.local/share/applications"
            mkdir -p "$user_apps_dir"
            echo "$mimeapps_content" > "${user_apps_dir}/mimeapps.list"
            chown -R "${USERNAME}:${USERNAME}" "${HOME_DIR}/.local"

            # 4. update-alternatives (sistema)
            case "$first_browser" in
                "firefox")  update-alternatives --set x-www-browser /usr/bin/firefox 2>/dev/null || true ;;
                "chrome")   update-alternatives --set x-www-browser /usr/bin/google-chrome-stable 2>/dev/null || true ;;
                "chromium") update-alternatives --set x-www-browser /usr/bin/chromium 2>/dev/null || true ;;
            esac

            # 5. XFCE: ~/.config/xfce4/helpers.rc (usado por exo-open)
            local xfce_helper
            xfce_helper=$(get_xfce_helper "$first_browser")
            if [[ -n "$xfce_helper" ]]; then
                local xfce_config_dir="${HOME_DIR}/.config/xfce4"
                mkdir -p "$xfce_config_dir"

                # Crear o actualizar helpers.rc
                local helpers_rc="${xfce_config_dir}/helpers.rc"
                if [[ -f "$helpers_rc" ]]; then
                    # Si existe, actualizar la línea WebBrowser
                    if grep -q "^WebBrowser=" "$helpers_rc"; then
                        sed -i "s/^WebBrowser=.*/WebBrowser=${xfce_helper}/" "$helpers_rc"
                    else
                        echo "WebBrowser=${xfce_helper}" >> "$helpers_rc"
                    fi
                else
                    # Crear nuevo helpers.rc
                    echo "WebBrowser=${xfce_helper}" > "$helpers_rc"
                fi
                chown -R "${USERNAME}:${USERNAME}" "$xfce_config_dir"
            fi

            log_success "${first_browser} establecido como predeterminado"
        fi
    fi
}

# Ejecutar
install_browser
