#!/bin/bash
# ==============================================================================
# SYSTEM-BASE.SH - Configuración del sistema base
# ==============================================================================
# Configura: red, locale, herramientas básicas
# Requiere: common.sh
# ==============================================================================

install_system_base() {
    log_section "Configurando sistema base..."

    # -------------------------------------------------------------------------
    # Configurar red según network_mode
    # -------------------------------------------------------------------------
    log_task "Configurando red (modo: ${NETWORK_MODE})..."

    # Remove ALL old netplan configs
    rm -f /etc/netplan/*.yaml

    if [[ "${NETWORK_MODE}" == "dhcp" ]]; then
        cat > /etc/netplan/00-installer-config.yaml << 'NETPLAN_EOF'
network:
  version: 2
  ethernets:
    eth0:
      match:
        name: "eth*"
      dhcp4: true
      dhcp6: false
NETPLAN_EOF

        chmod 600 /etc/netplan/00-installer-config.yaml
        netplan apply

        sleep 2
        dhclient -r eth0 2>/dev/null || true
        dhclient eth0 2>/dev/null || true
        sleep 2

        log_success "Red configurada (DHCP) - IP: $(hostname -I | awk '{print $1}')"
    else
        DNS_YAML=$(echo "${STATIC_DNS}" | sed 's/,/, /g')

        cat > /etc/netplan/00-installer-config.yaml << NETPLAN_EOF
network:
  version: 2
  ethernets:
    eth0:
      match:
        name: "eth*"
      addresses:
        - ${STATIC_IP}
      routes:
        - to: default
          via: ${STATIC_GATEWAY}
      nameservers:
        addresses: [${DNS_YAML}]
      dhcp4: false
      dhcp6: false
NETPLAN_EOF

        chmod 600 /etc/netplan/00-installer-config.yaml
        netplan apply

        log_success "Red configurada (estática) - IP: ${STATIC_IP}"
    fi

    # -------------------------------------------------------------------------
    # Actualizar sistema
    # -------------------------------------------------------------------------
    log_task "Actualizar sistema..."
    apt-get update
    apt-get upgrade -y

    # -------------------------------------------------------------------------
    # Configurar locale
    # -------------------------------------------------------------------------
    log_task "Configurar locale..."
    locale-gen "${LOCALE}" en_US.UTF-8
    update-locale LANG="${LOCALE}"

    # -------------------------------------------------------------------------
    # Instalar herramientas básicas
    # -------------------------------------------------------------------------
    log_task "Instalar herramientas básicas..."
    apt-get install -y \
        software-properties-common \
        apt-transport-https \
        net-tools \
        dnsutils \
        tree \
        ncdu \
        tmux \
        fzf \
        ripgrep \
        fd-find \
        bat \
        gnupg \
        curl \
        wget \
        make \
        build-essential \
        cifs-utils

    # Crear symlinks para herramientas con nombres diferentes
    if ! ln -sf /usr/bin/batcat /usr/local/bin/bat 2>/dev/null; then
        log_warning "batcat not available, bat command will not work"
    fi
    if ! ln -sf /usr/bin/fdfind /usr/local/bin/fd 2>/dev/null; then
        log_warning "fdfind not available, fd command will not work"
    fi

    # -------------------------------------------------------------------------
    # Samba (opcional)
    # -------------------------------------------------------------------------
    if [[ "${INSTALL_SAMBA}" == "true" ]]; then
        log_task "Instalando y configurando Samba..."
        apt-get install -y samba
        systemctl enable smbd nmbd
        ufw allow samba
        log_success "Samba instalado y configurado"
    else
        log_task "Samba: omitido (INSTALL_SAMBA=${INSTALL_SAMBA})"
    fi

    log_success "Sistema base configurado"
}

# Ejecutar si se llama directamente o si se sourcea
install_system_base
