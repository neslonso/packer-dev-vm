#!/bin/bash
# ==============================================================================
# XRDP.SH - xrdp para XFCE/LXQt (RDP genérico para X11)
# ==============================================================================
# Configura: xrdp server, certificados TLS, sesión XFCE
# Requiere: common.sh
# ==============================================================================

configure_xrdp() {
    log_section "Configurando xrdp para acceso RDP..."

    # -------------------------------------------------------------------------
    # Instalar xrdp y dependencias
    # -------------------------------------------------------------------------
    apt-get install -y xrdp xorgxrdp avahi-daemon ssl-cert

    # Añadir usuario xrdp al grupo ssl-cert para acceso a certificados
    usermod -aG ssl-cert xrdp

    # -------------------------------------------------------------------------
    # Configurar sesión XFCE para xrdp
    # -------------------------------------------------------------------------
    log_task "Configurando sesión XFCE..."

    # Crear .xsession para el usuario (usado por xrdp)
    cat > "${HOME_DIR}/.xsession" << 'XSESSION_EOF'
#!/bin/bash
# xrdp session startup script

# Ensure D-Bus is running
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    eval $(dbus-launch --sh-syntax)
    export DBUS_SESSION_BUS_ADDRESS
fi

# Set XDG directories
export XDG_SESSION_TYPE=x11
export XDG_SESSION_DESKTOP=xfce
export XDG_CURRENT_DESKTOP=XFCE

# Start XFCE session
exec startxfce4
XSESSION_EOF

    chmod +x "${HOME_DIR}/.xsession"
    chown "${USERNAME}:${USERNAME}" "${HOME_DIR}/.xsession"

    # Symlink para compatibilidad
    ln -sf "${HOME_DIR}/.xsession" "${HOME_DIR}/.xinitrc" 2>/dev/null || true
    chown -h "${USERNAME}:${USERNAME}" "${HOME_DIR}/.xinitrc" 2>/dev/null || true

    # -------------------------------------------------------------------------
    # Configurar xrdp.ini
    # -------------------------------------------------------------------------
    log_task "Configurando xrdp.ini..."

    # Backup original
    cp /etc/xrdp/xrdp.ini /etc/xrdp/xrdp.ini.bak

    # Modificar configuración
    sed -i 's/^port=3389/port=3389/' /etc/xrdp/xrdp.ini
    sed -i 's/^max_bpp=32/max_bpp=24/' /etc/xrdp/xrdp.ini
    sed -i 's/^#tcp_nodelay=true/tcp_nodelay=true/' /etc/xrdp/xrdp.ini

    # -------------------------------------------------------------------------
    # Configurar sesman.ini
    # -------------------------------------------------------------------------
    log_task "Configurando sesman..."

    # Asegurar que xrdp use la sesión correcta
    if ! grep -q "^AllowRootLogin=false" /etc/xrdp/sesman.ini; then
        sed -i 's/^AllowRootLogin=.*/AllowRootLogin=false/' /etc/xrdp/sesman.ini
    fi

    # -------------------------------------------------------------------------
    # Generar certificados TLS (auto-firmados)
    # -------------------------------------------------------------------------
    log_task "Generando certificados TLS para xrdp..."

    # xrdp usa los certificados en /etc/xrdp/
    if [[ ! -f /etc/xrdp/cert.pem ]] || [[ ! -f /etc/xrdp/key.pem ]]; then
        openssl req -x509 -newkey rsa:4096 -nodes -days 365 \
            -keyout /etc/xrdp/key.pem \
            -out /etc/xrdp/cert.pem \
            -subj "/C=US/ST=NONE/L=NONE/O=xrdp/CN=${HOSTNAME}.local" \
            -addext "subjectAltName=DNS:${HOSTNAME},DNS:${HOSTNAME}.local" 2>/dev/null

        chmod 640 /etc/xrdp/key.pem
        chown root:xrdp /etc/xrdp/key.pem
    fi

    log_success "Certificados TLS generados"

    # -------------------------------------------------------------------------
    # Configurar Polkit para permitir color management (Ubuntu 24.04+)
    # -------------------------------------------------------------------------
    # Ubuntu 24.04 usa polkit con archivos .rules (JavaScript), no .pkla
    log_task "Configurando Polkit para xrdp..."

    mkdir -p /etc/polkit-1/rules.d

    cat > /etc/polkit-1/rules.d/45-allow-colord.rules << 'POLKIT_EOF'
// Allow colord for all users (needed for xrdp sessions)
polkit.addRule(function(action, subject) {
    if ((action.id == "org.freedesktop.color-manager.create-device" ||
         action.id == "org.freedesktop.color-manager.create-profile" ||
         action.id == "org.freedesktop.color-manager.delete-device" ||
         action.id == "org.freedesktop.color-manager.delete-profile" ||
         action.id == "org.freedesktop.color-manager.modify-device" ||
         action.id == "org.freedesktop.color-manager.modify-profile")) {
        return polkit.Result.YES;
    }
});
POLKIT_EOF

    chmod 644 /etc/polkit-1/rules.d/45-allow-colord.rules

    # -------------------------------------------------------------------------
    # Firewall y Avahi
    # -------------------------------------------------------------------------
    if command -v ufw >/dev/null 2>&1; then
        ufw allow 3389/tcp
        ufw allow 5353/udp
    fi

    # Habilitar Avahi para mDNS
    systemctl enable avahi-daemon.service
    systemctl start avahi-daemon.service || true

    # -------------------------------------------------------------------------
    # Habilitar y arrancar xrdp
    # -------------------------------------------------------------------------
    systemctl enable xrdp
    systemctl enable xrdp-sesman
    systemctl restart xrdp || true
    systemctl restart xrdp-sesman || true

    # -------------------------------------------------------------------------
    # Generar archivo .rdp
    # -------------------------------------------------------------------------
    RDP_FILE="/home/${USERNAME}/connect-${HOSTNAME}.rdp"
    log_task "Generando archivo RDP: ${RDP_FILE}"

    cat > "${RDP_FILE}" << RDP_EOF
full address:s:${HOSTNAME}.local:3389
username:s:${USERNAME}
prompt for credentials:i:1
administrative session:i:0
screen mode id:i:2
use multimon:i:0
desktopwidth:i:1920
desktopheight:i:1080
session bpp:i:24
compression:i:1
keyboardhook:i:2
audiocapturemode:i:0
videoplaybackmode:i:1
connection type:i:7
networkautodetect:i:1
bandwidthautodetect:i:1
enableworkspacereconnect:i:0
disable wallpaper:i:0
allow font smoothing:i:1
allow desktop composition:i:0
disable full window drag:i:1
disable menu anims:i:1
disable themes:i:0
disable cursor setting:i:0
bitmapcachepersistenable:i:1
audiomode:i:0
redirectprinters:i:0
redirectcomports:i:0
redirectsmartcards:i:0
redirectclipboard:i:1
redirectposdevices:i:0
autoreconnection enabled:i:1
authentication level:i:0
negotiate security layer:i:1
remoteapplicationmode:i:0
gatewayusagemethod:i:4
gatewaycredentialssource:i:4
gatewayprofileusagemethod:i:0
use redirection server name:i:0
RDP_EOF

    chown "${USERNAME}:${USERNAME}" "${RDP_FILE}"
    chmod 644 "${RDP_FILE}"

    log_success "xrdp configurado (RDP en puerto 3389)"
    log_msg ""
    log_msg "CONEXIÓN RDP:"
    log_msg "  Opción 1 - Usar archivo .rdp (recomendado):"
    log_msg "    Copiar ~/connect-${HOSTNAME}.rdp a Windows y ejecutar"
    log_msg ""
    log_msg "  Opción 2 - Conexión manual:"
    log_msg "    Conectar a: ${HOSTNAME}.local (o IP de la VM)"
    log_msg ""
    log_msg "  Credenciales: ${USERNAME} / developer"
    log_msg ""
    log_msg "NOTA: Cambiar contraseña tras primer login con: passwd"
    log_msg "NOTA: El hostname ${HOSTNAME}.local se resuelve via mDNS (requiere Bonjour en Windows)"
}

# Ejecutar
configure_xrdp
