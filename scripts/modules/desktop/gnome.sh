#!/bin/bash
# ==============================================================================
# GNOME.SH - Configuración específica de GNOME Desktop
# ==============================================================================
# Configura: gnome-tweaks, tema, dock, autostart
# Requiere: common.sh
# ==============================================================================

configure_gnome_desktop() {
    log_section "Configurando GNOME desktop..."

    # Instalar gnome-tweaks
    apt-get install -y gnome-tweaks gnome-shell-extension-manager

    # Crear script de configuración GNOME (se ejecuta en primer login)
    cat > "${HOME_DIR}/.config/autostart-setup.sh" << EOF
#!/bin/bash
# Configuración de GNOME (ejecutar una vez)

set -euo pipefail
LOG_FILE="\${HOME}/.config/gnome-setup.log"
exec > >(tee -a "\${LOG_FILE}") 2>&1

echo "[\$(date)] Starting GNOME configuration..."

# Tema
gsettings set org.gnome.desktop.interface color-scheme 'prefer-${DESKTOP_THEME}' || echo "WARNING: Failed to set color scheme"

# Fuente monospace si Nerd Font está instalado
if [[ "${NERD_FONT}" != "none" ]]; then
    case "${NERD_FONT}" in
        "JetBrainsMono")
            FONT_SYSTEM_NAME="JetBrainsMono Nerd Font 11"
            ;;
        "FiraCode")
            FONT_SYSTEM_NAME="FiraCode Nerd Font 11"
            ;;
        "Hack")
            FONT_SYSTEM_NAME="Hack Nerd Font 11"
            ;;
        "SourceCodePro")
            FONT_SYSTEM_NAME="SauceCodePro Nerd Font 11"
            ;;
        "Meslo")
            FONT_SYSTEM_NAME="MesloLGS NF 11"
            ;;
        *)
            FONT_SYSTEM_NAME="${NERD_FONT} Nerd Font 11"
            ;;
    esac
    gsettings set org.gnome.desktop.interface monospace-font-name "\${FONT_SYSTEM_NAME}" || echo "WARNING: Failed to set monospace font"
fi

# Desactivar suspensión
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing' || echo "WARNING: Failed to set AC sleep policy"
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing' || echo "WARNING: Failed to set battery sleep policy"

# Dock favorites
DOCK_APPS="'org.gnome.Nautilus.desktop', 'org.gnome.Terminal.desktop'"

if [[ "${INSTALL_ANTIGRAVITY}" == "true" ]]; then
    DOCK_APPS="\${DOCK_APPS}, 'antigravity.desktop'"
fi
if [[ "${INSTALL_CURSOR}" == "true" ]]; then
    DOCK_APPS="\${DOCK_APPS}, 'cursor.desktop'"
fi
if [[ "${INSTALL_VSCODE}" == "true" ]]; then
    DOCK_APPS="\${DOCK_APPS}, 'code.desktop'"
fi
if [[ "${INSTALL_SUBLIMEMERGE}" == "true" ]]; then
    DOCK_APPS="\${DOCK_APPS}, 'sublime_merge.desktop'"
fi

if [[ "${INSTALL_BROWSER}" == "chromium" ]]; then
    DOCK_APPS="\${DOCK_APPS}, 'chromium.desktop'"
fi
if [[ "${INSTALL_BROWSER}" == "chrome" ]]; then
    DOCK_APPS="\${DOCK_APPS}, 'google-chrome.desktop'"
fi
if [[ "${INSTALL_BROWSER}" == "firefox" ]]; then
    DOCK_APPS="\${DOCK_APPS}, 'firefox.desktop'"
fi

gsettings set org.gnome.shell favorite-apps "[\${DOCK_APPS}]" || echo "WARNING: Failed to set dock favorites"

echo "[\$(date)] GNOME configuration completed successfully"

# Auto-eliminar este script después de ejecutar exitosamente
rm -f "\$0"
EOF

    chmod +x "${HOME_DIR}/.config/autostart-setup.sh"

    # Autostart para ejecutar config en primer login
    mkdir -p "${HOME_DIR}/.config/autostart"
    cat > "${HOME_DIR}/.config/autostart/setup.desktop" << EOF
[Desktop Entry]
Type=Application
Name=Initial Setup
Exec=${HOME_DIR}/.config/autostart-setup.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

    chown -R "${USERNAME}:${USERNAME}" "${HOME_DIR}/.config"

    log_success "GNOME desktop configurado"
}

# Ejecutar
configure_gnome_desktop
