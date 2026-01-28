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

    # -------------------------------------------------------------------------
    # Inyectar Servicios Web Dinámicos (usando awk para evitar problemas con sed)
    # -------------------------------------------------------------------------
    if [[ "${INSTALL_PORTAINER}" == "true" ]]; then
        SERVICES_HTML='<div class="card"><h2>Portainer CE <span class="tag">Docker TUI</span></h2><div class="card-content"><p style="font-size: 0.85rem; color: var(--text-dim); margin-bottom: 10px;">Gestión visual de contenedores, volúmenes y redes.</p><a href="https://localhost:9443" target="_blank" class="service-link">Abrir Portainer</a></div></div>'
        awk -v html="${SERVICES_HTML}" '{gsub(/<!-- DYNAMIC_SERVICES_PLACEHOLDER -->/, html)}1' "${WELCOME_FILE}" > "${WELCOME_FILE}.tmp" && mv "${WELCOME_FILE}.tmp" "${WELCOME_FILE}"
    fi

    # -------------------------------------------------------------------------
    # Parsear y Inyectar Aliases (escapando caracteres especiales)
    # -------------------------------------------------------------------------
    ALIASES_FILE="/tmp/provision/modules/aliases.sh"
    if [[ -f "${ALIASES_FILE}" ]]; then
        log_task "Parseando aliases desde ${ALIASES_FILE}..."
        TABLE_ROWS=""
        DESC=""

        while IFS= read -r line; do
            if [[ "$line" =~ ^#\ description:\ (.*) ]]; then
                DESC="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^alias\ ([^=]+)=\"(.+)\" ]]; then
                NAME="${BASH_REMATCH[1]}"
                CMD="${BASH_REMATCH[2]}"
                if [[ -n "$DESC" ]]; then
                    # Escapar caracteres especiales para HTML
                    CMD_ESCAPED=$(echo "$CMD" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g')
                    TABLE_ROWS+="<tr><td><span class='alias-name'>${NAME}</span></td><td><code class='alias-cmd'>${CMD_ESCAPED}</code></td><td class='alias-desc'>${DESC}</td></tr>"
                    DESC=""
                fi
            fi
        done < "${ALIASES_FILE}"

        if [[ -n "${TABLE_ROWS}" ]]; then
            # Usar awk para reemplazo seguro
            awk -v rows="${TABLE_ROWS}" '{gsub(/<!-- DYNAMIC_ALIASES_PLACEHOLDER -->/, rows)}1' "${WELCOME_FILE}" > "${WELCOME_FILE}.tmp" && mv "${WELCOME_FILE}.tmp" "${WELCOME_FILE}"
        fi
    fi

    # -------------------------------------------------------------------------
    # Ajustes finales
    # -------------------------------------------------------------------------
    # Intentar obtener la IP real para el documento
    REAL_IP=$(hostname -I | awk '{print $1}')
    if [[ -n "${REAL_IP}" ]]; then
        sed -i "s|172.x.x.x|${REAL_IP}|g" "${WELCOME_FILE}"
    fi

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
