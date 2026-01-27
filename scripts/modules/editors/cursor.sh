#!/bin/bash
# ==============================================================================
# CURSOR.SH - Instalación de Cursor (AI-powered code editor)
# ==============================================================================
# Requiere: common.sh
# ==============================================================================

install_cursor() {
    if [[ "${INSTALL_CURSOR}" != "true" ]]; then
        log_task "Saltando instalación de Cursor (deshabilitado)"
        return 0
    fi

    log_section "Instalando Cursor..."

    # Instalar libfuse2 (necesario para AppImages)
    apt-get install -y libfuse2

    CURSOR_APPIMAGE="/opt/cursor/cursor.AppImage"
    mkdir -p /opt/cursor

    log_task "Downloading Cursor AppImage..."
    CURSOR_DOWNLOADED=false

    # URLs oficiales de Cursor (pueden cambiar)
    CURSOR_URLS=(
        "https://downloader.cursor.sh/linux/appImage/x64"
        "https://download.cursor.sh/linux/appImage/x64"
        "https://downloads.cursor.sh/production/client/linux/x64/appimage/latest"
    )

    # Intentar cada URL con reintentos
    for url in "${CURSOR_URLS[@]}"; do
        log_task "Trying: ${url}"

        # Reintentar hasta 3 veces con espera
        for attempt in 1 2 3; do
            if curl --max-time 180 --retry 2 --retry-delay 5 -fSL -o "${CURSOR_APPIMAGE}" "${url}" 2>&1; then
                # Verificar que el archivo descargado es válido (> 50MB)
                if [[ -f "${CURSOR_APPIMAGE}" ]] && [[ $(stat -f%z "${CURSOR_APPIMAGE}" 2>/dev/null || stat -c%s "${CURSOR_APPIMAGE}" 2>/dev/null) -gt 50000000 ]]; then
                    CURSOR_DOWNLOADED=true
                    log_success "Downloaded from ${url}"
                    break 2
                else
                    log_warning "Downloaded file too small or invalid, retrying..."
                    rm -f "${CURSOR_APPIMAGE}"
                fi
            fi

            if [[ $attempt -lt 3 ]]; then
                log_task "Attempt $attempt failed, waiting 5s before retry..."
                sleep 5
            fi
        done

        log_warning "Failed: ${url}"
    done

    if [[ "${CURSOR_DOWNLOADED}" == "true" ]]; then
        chmod +x "${CURSOR_APPIMAGE}"
        log_success "Cursor downloaded successfully"

        # Create desktop entry
        cat > /usr/share/applications/cursor.desktop << 'CURSOR_DESKTOP_EOF'
[Desktop Entry]
Name=Cursor
Comment=AI-powered code editor
Exec=/opt/cursor/cursor.AppImage --no-sandbox %F
Icon=cursor
Type=Application
Categories=Development;IDE;
MimeType=text/plain;
StartupNotify=true
StartupWMClass=Cursor
CURSOR_DESKTOP_EOF

        # Download and install icon
        curl -fsSL "https://www.cursor.com/assets/images/logo.svg" -o /usr/share/icons/cursor.svg 2>/dev/null || true

        log_success "Cursor installed successfully"

        # Configure Cursor settings
        apply_vscode_settings "Cursor"
    else
        log_error "Failed to download Cursor from all URLs, skipping..."
        rm -rf /opt/cursor
    fi
}

# Ejecutar
install_cursor
