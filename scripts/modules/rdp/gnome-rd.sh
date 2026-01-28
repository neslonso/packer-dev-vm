#!/bin/bash
# ==============================================================================
# GNOME-RD.SH - GNOME Remote Desktop (RDP nativo para GNOME/Wayland)
# ==============================================================================
# Configura: gnome-remote-desktop en modo sistema, certificados TLS
# Requiere: common.sh
# ==============================================================================

configure_gnome_remote_desktop() {
    log_section "Configurando GNOME Remote Desktop (modo sistema)..."

    # Instalar gnome-remote-desktop, avahi (mDNS) y herramientas necesarias
    apt-get install -y gnome-remote-desktop avahi-daemon xclip openssl

    GRD_USER="gnome-remote-desktop"
    GRD_DIR="/var/lib/gnome-remote-desktop/.local/share/gnome-remote-desktop"

    # Crear directorio de certificados
    log_task "Creando directorio para certificados TLS..."
    sudo -u "${GRD_USER}" mkdir -p "${GRD_DIR}"

    # -------------------------------------------------------------------------
    # Generar certificados TLS
    # -------------------------------------------------------------------------
    log_task "Generando certificados TLS para RDP..."

    OPENSSL_CONF_TMP="${GRD_DIR}/openssl.cnf"
    sudo -u "${GRD_USER}" bash -c "cat > '${OPENSSL_CONF_TMP}'" << OPENSSL_EOF
[req]
default_bits = 4096
prompt = no
default_md = sha256
distinguished_name = dn
x509_extensions = v3_ext

[dn]
C = US
ST = NONE
L = NONE
O = GNOME Remote Desktop
CN = ${HOSTNAME}.local

[v3_ext]
basicConstraints = CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth, 1.3.6.1.4.1.311.54.1.2
subjectKeyIdentifier = hash
subjectAltName = DNS:${HOSTNAME}, DNS:${HOSTNAME}.local
OPENSSL_EOF

    sudo -u "${GRD_USER}" openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 \
        -config "${OPENSSL_CONF_TMP}" \
        -out "${GRD_DIR}/tls.crt" \
        -keyout "${GRD_DIR}/tls.key" 2>/dev/null

    rm -f "${OPENSSL_CONF_TMP}"

    log_success "Certificados TLS generados en ${GRD_DIR}"

    # -------------------------------------------------------------------------
    # Configurar GNOME Remote Desktop
    # -------------------------------------------------------------------------
    log_task "Configurando RDP en modo sistema..."

    grdctl --system rdp set-tls-key "${GRD_DIR}/tls.key" || log_warning "Could not set TLS key"
    grdctl --system rdp set-tls-cert "${GRD_DIR}/tls.crt" || log_warning "Could not set TLS cert"

    log_task "Configurando credenciales RDP..."
    grdctl --system rdp set-credentials "${USERNAME}" "developer" || log_warning "Could not set system credentials"

    grdctl --system rdp enable || log_warning "Could not enable system RDP"

    log_task "Verificando configuración..."
    grdctl --system status 2>/dev/null || true

    systemctl enable gnome-remote-desktop.service
    systemctl restart gnome-remote-desktop.service || true

    # -------------------------------------------------------------------------
    # Firewall y Avahi
    # -------------------------------------------------------------------------
    if command -v ufw >/dev/null 2>&1; then
        ufw allow 3389/tcp
        ufw allow 5353/udp
    fi

    systemctl enable avahi-daemon.service
    systemctl start avahi-daemon.service || true

    # -------------------------------------------------------------------------
    # Generar archivo .rdp
    # -------------------------------------------------------------------------
    RDP_FILE="/home/${USERNAME}/connect-${HOSTNAME}.rdp"
    log_task "Generando archivo RDP: ${RDP_FILE}"
    cat > "${RDP_FILE}" << RDP_EOF
full address:s:${HOSTNAME}.local:3389
username:s:${USERNAME}
prompt for credentials:i:1
administrative session:i:1
screen mode id:i:2
use multimon:i:0
desktopwidth:i:1920
desktopheight:i:1080
session bpp:i:32
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
allow desktop composition:i:1
disable full window drag:i:0
disable menu anims:i:0
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
authentication level:i:2
negotiate security layer:i:1
remoteapplicationmode:i:0
gatewayusagemethod:i:4
gatewaycredentialssource:i:4
gatewayprofileusagemethod:i:0
use redirection server name:i:1
RDP_EOF
    chown "${USERNAME}:${USERNAME}" "${RDP_FILE}"
    chmod 644 "${RDP_FILE}"

    log_success "GNOME Remote Desktop configurado (RDP en puerto 3389)"
    log_msg ""
    log_msg "CONEXIÓN RDP:"
    log_msg "  Opción 1 - Usar archivo .rdp (recomendado):"
    log_msg "    Copiar ~/connect-${HOSTNAME}.rdp a Windows y ejecutar"
    log_msg ""
    log_msg "  Opción 2 - Conexión manual:"
    log_msg "    Conectar a: ${HOSTNAME}.local (o IP de la VM)"
    log_msg ""
    log_msg "  Credenciales RDP: ${USERNAME} / developer"
    log_msg "  Después: login en pantalla de GNOME"
    log_msg ""
    log_msg "NOTA: Cambiar contraseña tras primer login con: passwd"
    log_msg "NOTA: El hostname ${HOSTNAME}.local se resuelve via mDNS (requiere Bonjour en Windows)"
}

# Ejecutar
configure_gnome_remote_desktop
