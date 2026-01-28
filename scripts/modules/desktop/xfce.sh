#!/bin/bash
# ==============================================================================
# XFCE.SH - Configuración específica de XFCE Desktop (Xubuntu)
# ==============================================================================
# Configura: tema, panel, terminal, fuentes, autostart
# Requiere: common.sh
# ==============================================================================

configure_xfce_desktop() {
    log_section "Configurando XFCE desktop..."

    # Crear directorios de configuración
    run_as_user "mkdir -p '${HOME_DIR}/.config/xfce4/xfconf/xfce-perchannel-xml'"
    run_as_user "mkdir -p '${HOME_DIR}/.config/xfce4/terminal'"
    run_as_user "mkdir -p '${HOME_DIR}/.config/autostart'"

    # -------------------------------------------------------------------------
    # Configurar tema oscuro/claro
    # -------------------------------------------------------------------------
    if [[ "${DESKTOP_THEME}" == "dark" ]]; then
        GTK_THEME="Greybird-dark"
        ICON_THEME="elementary-xfce-dark"
        WM_THEME="Greybird-dark"
    else
        GTK_THEME="Greybird"
        ICON_THEME="elementary-xfce"
        WM_THEME="Greybird"
    fi

    # Crear configuración de xsettings
    cat > "${HOME_DIR}/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="${GTK_THEME}"/>
    <property name="IconThemeName" type="string" value="${ICON_THEME}"/>
  </property>
</channel>
EOF

    # Configuración del window manager
    cat > "${HOME_DIR}/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="theme" type="string" value="${WM_THEME}"/>
    <property name="use_compositing" type="bool" value="false"/>
    <property name="tile_on_move" type="bool" value="true"/>
  </property>
</channel>
EOF

    # -------------------------------------------------------------------------
    # Configurar terminal XFCE
    # -------------------------------------------------------------------------
    # Determinar fuente para terminal
    if [[ "${NERD_FONT}" != "none" ]]; then
        case "${NERD_FONT}" in
            "JetBrainsMono") TERM_FONT="JetBrainsMono Nerd Font 11" ;;
            "FiraCode") TERM_FONT="FiraCode Nerd Font 11" ;;
            "Hack") TERM_FONT="Hack Nerd Font 11" ;;
            "SourceCodePro") TERM_FONT="SauceCodePro Nerd Font 11" ;;
            "Meslo") TERM_FONT="MesloLGS NF 11" ;;
            *) TERM_FONT="${NERD_FONT} Nerd Font 11" ;;
        esac
    else
        TERM_FONT="Monospace 11"
    fi

    cat > "${HOME_DIR}/.config/xfce4/terminal/terminalrc" << EOF
[Configuration]
FontName=${TERM_FONT}
MiscAlwaysShowTabs=FALSE
MiscBell=FALSE
MiscBellUrgent=FALSE
MiscBordersDefault=TRUE
MiscCursorBlinks=TRUE
MiscCursorShape=TERMINAL_CURSOR_SHAPE_BLOCK
MiscDefaultGeometry=120x35
MiscInheritGeometry=FALSE
MiscMenubarDefault=TRUE
MiscMouseAutohide=FALSE
MiscMouseWheelZoom=TRUE
MiscToolbarDefault=FALSE
MiscConfirmClose=TRUE
MiscCycleTabs=TRUE
MiscTabCloseButtons=TRUE
MiscTabCloseMiddleClick=TRUE
MiscTabPosition=GTK_POS_TOP
MiscHighlightUrls=TRUE
MiscMiddleClickOpensUri=FALSE
MiscCopyOnSelect=FALSE
MiscShowRelaunchDialog=TRUE
MiscRewrapOnResize=TRUE
MiscUseShiftArrowsToScroll=FALSE
MiscSlimTabs=FALSE
MiscNewTabAdjacent=FALSE
MiscSearchDialogOpacity=100
MiscShowUnsafePasteDialog=TRUE
ScrollingUnlimited=TRUE
ColorForeground=#f8f8f2
ColorBackground=#282a36
ColorCursor=#f8f8f2
ColorBold=#6e46a4
ColorBoldIsBright=FALSE
ColorPalette=#21222c;#ff5555;#50fa7b;#f1fa8c;#bd93f9;#ff79c6;#8be9fd;#f8f8f2;#6272a4;#ff6e6e;#69ff94;#ffffa5;#d6acff;#ff92df;#a4ffff;#ffffff
EOF

    # -------------------------------------------------------------------------
    # Establecer xfce4-terminal como terminal predeterminada
    # -------------------------------------------------------------------------
    update-alternatives --set x-terminal-emulator /usr/bin/xfce4-terminal.wrapper 2>/dev/null || true

    # Configurar exo-preferred-applications
    run_as_user "mkdir -p '${HOME_DIR}/.config/xfce4'"
    cat > "${HOME_DIR}/.config/xfce4/helpers.rc" << EOF
TerminalEmulator=xfce4-terminal
EOF

    # -------------------------------------------------------------------------
    # Desactivar power management / screen blanking
    # -------------------------------------------------------------------------
    cat > "${HOME_DIR}/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-power-manager" version="1.0">
  <property name="xfce4-power-manager" type="empty">
    <property name="dpms-enabled" type="bool" value="false"/>
    <property name="blank-on-ac" type="int" value="0"/>
    <property name="dpms-on-ac-sleep" type="uint" value="0"/>
    <property name="dpms-on-ac-off" type="uint" value="0"/>
    <property name="inactivity-on-ac" type="uint" value="0"/>
  </property>
</channel>
EOF

    # -------------------------------------------------------------------------
    # Crear script de configuración adicional (primer login)
    # -------------------------------------------------------------------------
    cat > "${HOME_DIR}/.config/autostart-setup.sh" << 'SETUP_EOF'
#!/bin/bash
# Configuración de XFCE (ejecutar una vez)

set -euo pipefail
LOG_FILE="${HOME}/.config/xfce-setup.log"
exec > >(tee -a "${LOG_FILE}") 2>&1

echo "[$(date)] Starting XFCE configuration..."

# Refresh panel
xfce4-panel --restart 2>/dev/null || true

echo "[$(date)] XFCE configuration completed successfully"

# Auto-eliminar este script después de ejecutar exitosamente
rm -f "$0"
rm -f "${HOME}/.config/autostart/setup.desktop"
SETUP_EOF

    chmod +x "${HOME_DIR}/.config/autostart-setup.sh"

    cat > "${HOME_DIR}/.config/autostart/setup.desktop" << EOF
[Desktop Entry]
Type=Application
Name=Initial Setup
Exec=${HOME_DIR}/.config/autostart-setup.sh
Hidden=false
NoDisplay=false
X-XFCE-Autostart-Override=true
EOF

    # Fix ownership
    chown -R "${USERNAME}:${USERNAME}" "${HOME_DIR}/.config"

    log_success "XFCE desktop configurado"
}

# Ejecutar
configure_xfce_desktop
