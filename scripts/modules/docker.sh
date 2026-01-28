#!/bin/bash
# ==============================================================================
# DOCKER.SH - Instalación de Docker y herramientas relacionadas
# ==============================================================================
# Instala: Docker CE, lazydocker, Portainer (opcional)
# Requiere: common.sh
# ==============================================================================

install_docker() {
    log_section "Instalando Docker..."

    # -------------------------------------------------------------------------
    # Añadir repositorio de Docker
    # -------------------------------------------------------------------------
    install -m 0755 -d /etc/apt/keyrings
    if ! download_and_verify_gpg_key "https://download.docker.com/linux/ubuntu/gpg" "/etc/apt/keyrings/docker.gpg" "$DOCKER_GPG_FINGERPRINT" "Docker GPG key"; then
        log_msg "ERROR: Failed to verify Docker GPG key"
        exit 1
    fi
    chmod a+r /etc/apt/keyrings/docker.gpg

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list

    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # -------------------------------------------------------------------------
    # Configurar Docker
    # -------------------------------------------------------------------------
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json << EOF
{
    "storage-driver": "overlay2",
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "${DOCKER_LOG_MAX_SIZE}",
        "max-file": "${DOCKER_LOG_MAX_FILE}"
    },
    "features": {
        "buildkit": true
    },
    "exec-opts": ["native.cgroupdriver=systemd"]
}
EOF

    usermod -aG docker "${USERNAME}"

    systemctl enable containerd
    systemctl enable docker
    systemctl start docker

    wait_for_docker

    # -------------------------------------------------------------------------
    # lazydocker
    # -------------------------------------------------------------------------
    LAZYDOCKER_VERSION=$(curl --max-time 30 --fail --silent --show-error https://api.github.com/repos/jesseduffield/lazydocker/releases/latest 2>/dev/null | jq -r '.tag_name' 2>/dev/null || echo "")

    if [[ -z "$LAZYDOCKER_VERSION" || "$LAZYDOCKER_VERSION" == "null" ]]; then
        log_warning "Failed to fetch lazydocker latest version from GitHub API, using fallback"
        LAZYDOCKER_VERSION="v0.23.1"
    fi

    log_task "Installing lazydocker ${LAZYDOCKER_VERSION}..."

    if curl --max-time 60 --fail -Lo /tmp/lazydocker.tar.gz "https://github.com/jesseduffield/lazydocker/releases/download/${LAZYDOCKER_VERSION}/lazydocker_${LAZYDOCKER_VERSION#v}_Linux_x86_64.tar.gz" 2>&1; then
        if validate_tar_archive /tmp/lazydocker.tar.gz "lazydocker archive"; then
            tar xzf /tmp/lazydocker.tar.gz -C /usr/local/bin lazydocker
            chmod +x /usr/local/bin/lazydocker
            log_success "lazydocker ${LAZYDOCKER_VERSION} installed successfully"
        else
            log_error "lazydocker archive validation failed, skipping installation"
        fi
        rm /tmp/lazydocker.tar.gz
    else
        log_warning "Failed to download lazydocker, skipping..."
    fi

    log_success "Docker instalado"
}

wait_for_docker() {
    log_task "Esperando a que el socket de Docker esté disponible..."
    local counter=0
    local max_wait=30
    while [ ! -S /var/run/docker.sock ]; do
        sleep 1
        counter=$((counter + 1))
        if [ $counter -ge $max_wait ]; then
            log_error "Timed out waiting for Docker socket"
            return 1
        fi
    done
    log_success "Docker socket detectado"

    # Adicionalmente, verificar que el daemon responde
    until docker info >/dev/null 2>&1; do
        sleep 1
        counter=$((counter + 1))
        if [ $counter -ge $max_wait ]; then
            log_error "Timed out waiting for Docker daemon to respond"
            return 1
        fi
    done
    log_success "Docker daemon respondiendo"
    return 0
}

install_portainer() {
    if [[ "${INSTALL_PORTAINER}" != "true" ]]; then
        log_task "Saltando instalación de Portainer (deshabilitado)"
        return 0
    fi

    log_task "Instalando Portainer CE..."

    wait_for_docker || {
        log_error "No se puede instalar Portainer: Docker no responde"
        return 1
    }

    log_task "Limpiando instalaciones previas de Portainer..."
    docker stop portainer >/dev/null 2>&1 || true
    docker rm portainer >/dev/null 2>&1 || true

    log_task "Creando volumen portainer_data..."
    docker volume create portainer_data >/dev/null 2>&1 || true

    log_task "Descargando imagen de Portainer..."
    if ! docker pull portainer/portainer-ce:lts; then
        log_error "Error al descargar imagen de Portainer"
        return 1
    fi

    log_task "Arrancando contenedor de Portainer..."
    if docker run -d \
        -p 9443:9443 \
        --name portainer \
        --restart=always \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v portainer_data:/data \
        portainer/portainer-ce:lts; then

        # Verificar que el contenedor está corriendo
        sleep 2
        if docker ps | grep -q portainer; then
            log_success "Portainer CE instalado y ejecutándose (https://localhost:9443)"
        else
            log_warning "Portainer se creó pero no parece estar en ejecución inmediata"
            docker logs portainer | tail -n 5 || true
        fi
    else
        log_error "Failed to start Portainer container"
    fi

    # Crear servicio systemd para garantizar que Portainer arranque tras reboot
    # (Docker restart policy no siempre persiste tras export de Packer)
    log_task "Creando servicio systemd para Portainer..."
    cat > /etc/systemd/system/portainer.service << 'SYSTEMD_EOF'
[Unit]
Description=Portainer Container
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash -c 'docker start portainer 2>/dev/null || docker run -d -p 9443:9443 --name portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:lts'
ExecStop=/usr/bin/docker stop portainer

[Install]
WantedBy=multi-user.target
SYSTEMD_EOF

    systemctl daemon-reload
    systemctl enable portainer.service
    log_success "Servicio portainer.service habilitado"
}

# Ejecutar
install_docker
install_portainer
