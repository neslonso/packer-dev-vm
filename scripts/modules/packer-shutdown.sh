#!/bin/bash
# ==============================================================================
# PACKER-SHUTDOWN.SH - Configurar permisos de shutdown para Packer
# ==============================================================================
# Permite shutdown sin password para que Packer pueda apagar la VM
# Requiere: common.sh
# ==============================================================================

configure_packer_shutdown() {
    log_task "Configurando permisos de shutdown para Packer..."

    echo "# Temporary: Allow shutdown for Packer build (added by provision.sh)" > /etc/sudoers.d/99-packer-shutdown
    echo "${USERNAME} ALL=(ALL) NOPASSWD: /usr/sbin/shutdown" >> /etc/sudoers.d/99-packer-shutdown
    echo "${USERNAME} ALL=(ALL) NOPASSWD: /sbin/shutdown" >> /etc/sudoers.d/99-packer-shutdown
    chmod 440 /etc/sudoers.d/99-packer-shutdown

    if ! visudo -c -f /etc/sudoers.d/99-packer-shutdown; then
        log_msg "ERROR: Invalid sudoers file created"
        rm -f /etc/sudoers.d/99-packer-shutdown
        exit 1
    fi

    log_success "Shutdown permissions configured for Packer build"
}

# Ejecutar
configure_packer_shutdown
