#!/bin/bash
# ==============================================================================
# WELCOME.SH - Documento de bienvenida
# ==============================================================================
# Crea el HTML de bienvenida y configura autostart
# Requiere: common.sh
# ==============================================================================

setup_welcome_document() {
    log_section "Finalizando: Documento de bienvenida..."

    WELCOME_FILE="${HOME_DIR}/welcome.html"
    log_task "Creando ${WELCOME_FILE}..."
    echo "${WELCOME_HTML}" > "${WELCOME_FILE}"
    chown "${USERNAME}:${USERNAME}" "${WELCOME_FILE}"
    chmod 644 "${WELCOME_FILE}"

    # Crear lanzador para autostart
    AUTOSTART_DIR="${HOME_DIR}/.config/autostart"
    mkdir -p "${AUTOSTART_DIR}"
    cat > "${AUTOSTART_DIR}/welcome-html.desktop" << EOF
[Desktop Entry]
Type=Application
Name=Welcome Guide
Exec=xdg-open ${WELCOME_FILE}
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

    chown -R "${USERNAME}:${USERNAME}" "${AUTOSTART_DIR}"
    log_success "Documento de bienvenida configurado"
}

# Ejecutar
setup_welcome_document
