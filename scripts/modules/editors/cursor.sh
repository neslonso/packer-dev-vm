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

    # Dependencias necesarias para Cursor/Electron
    apt-get install -y libasound2t64 libnss3 libgbm1 libxcb-dri3-0 libxtst6

    TEMP_DEB="/tmp/cursor_latest_amd64.deb"

    log_task "Downloading Cursor .deb package..."
    CURSOR_DOWNLOADED=false

    # URLs oficiales de Cursor (.deb)
    CURSOR_URLS=(
        "https://api2.cursor.sh/updates/download/golden/linux-x64-deb/cursor/latest"
        "https://api2.cursor.sh/updates/download/golden/linux-x64-deb/cursor/2.4"
    )

    # Intentar cada URL
    for url in "${CURSOR_URLS[@]}"; do
        log_task "Trying: ${url}"

        # Reintentar hasta 3 veces con espera
        for attempt in 1 2 3; do
            if curl --max-time 300 --retry 3 --retry-delay 5 -fSL -o "${TEMP_DEB}" "${url}"; then
                # Verificar que el archivo descargado es válido (> 50MB)
                if [[ -f "${TEMP_DEB}" ]] && [[ $(stat -c%s "${TEMP_DEB}" 2>/dev/null || stat -f%z "${TEMP_DEB}" 2>/dev/null) -gt 50000000 ]]; then
                    CURSOR_DOWNLOADED=true
                    log_success "Downloaded from ${url}"
                    break 2
                else
                    log_warning "Downloaded file too small or invalid, retrying..."
                    rm -f "${TEMP_DEB}"
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
        log_task "Installing Cursor package..."
        if apt-get install -y "${TEMP_DEB}"; then
            log_success "Cursor package installed successfully"
            rm -f "${TEMP_DEB}"

            # Note: The .deb usually creates its own desktop entry.
            # If we need --no-sandbox (common in some VMs with issues),
            # we might need to patch the official desktop entry.
            if [[ -f "/usr/share/applications/cursor.desktop" ]]; then
                log_task "Configuring Cursor desktop entry for VM compatibility..."
                sed -i 's|Exec=/opt/Cursor/cursor|Exec=/opt/Cursor/cursor --no-sandbox|g' /usr/share/applications/cursor.desktop 2>/dev/null || true
            fi

            log_success "Cursor installed successfully"

            # Configure Cursor settings
            apply_vscode_settings "Cursor"
        else
            log_error "Failed to install Cursor .deb package"
            rm -f "${TEMP_DEB}"
        fi
    else
        log_error "Failed to download Cursor from all URLs, skipping..."
    fi
}

# Ejecutar
install_cursor

