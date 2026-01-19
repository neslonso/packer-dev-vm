#!/bin/bash
# ==============================================================================
# PROVISION.SH - Script único de provisioning
# ==============================================================================
# Todas las configuraciones se reciben via variables de entorno VM_*
# Este script NO tiene valores hardcodeados.
# ==============================================================================

set -euo pipefail

# ==============================================================================
# VARIABLES (desde entorno)
# ==============================================================================
USERNAME="${VM_USERNAME}"
HOSTNAME="${VM_HOSTNAME}"
TIMEZONE="${VM_TIMEZONE}"
LOCALE="${VM_LOCALE}"
KEYBOARD="${VM_KEYBOARD}"
SHELL_TYPE="${VM_SHELL}"
PROMPT_THEME="${VM_PROMPT_THEME}"
OHMYZSH_THEME="${VM_OHMYZSH_THEME}"
OHMYZSH_PLUGINS="${VM_OHMYZSH_PLUGINS}"
OHMYBASH_THEME="${VM_OHMYBASH_THEME}"
STARSHIP_PRESET="${VM_STARSHIP_PRESET}"
NERD_FONT="${VM_NERD_FONT}"
GIT_NAME="${VM_GIT_NAME}"
GIT_EMAIL="${VM_GIT_EMAIL}"
GIT_DEFAULT_BRANCH="${VM_GIT_DEFAULT_BRANCH}"
DOCKER_LOG_MAX_SIZE="${VM_DOCKER_LOG_MAX_SIZE}"
DOCKER_LOG_MAX_FILE="${VM_DOCKER_LOG_MAX_FILE}"
DESKTOP_THEME="${VM_DESKTOP_THEME}"
INSTALL_VSCODE="${VM_INSTALL_VSCODE}"
INSTALL_ANTIGRAVITY="${VM_INSTALL_ANTIGRAVITY}"
INSTALL_BROWSER="${VM_INSTALL_BROWSER}"

HOME_DIR="/home/${USERNAME}"

export DEBIAN_FRONTEND=noninteractive

# ==============================================================================
# FUNCIONES AUXILIARES
# ==============================================================================

log() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  $1"
    echo "╚══════════════════════════════════════════════════════════════╝"
}

run_as_user() {
    sudo -u "${USERNAME}" -H bash -c "$1"
}

# ==============================================================================
# 1. SISTEMA BASE
# ==============================================================================

log "1/9 Configurando sistema base..."

# Actualizar sistema
apt-get update
apt-get upgrade -y

# Configurar locale
locale-gen "${LOCALE}" en_US.UTF-8
update-locale LANG="${LOCALE}"

# Instalar herramientas básicas
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
    bat

# Crear symlinks para herramientas con nombres diferentes
ln -sf /usr/bin/batcat /usr/local/bin/bat 2>/dev/null || true
ln -sf /usr/bin/fdfind /usr/local/bin/fd 2>/dev/null || true

# ==============================================================================
# 2. DOCKER
# ==============================================================================

log "2/9 Instalando Docker..."

# Añadir repositorio de Docker
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Configurar Docker
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

# Añadir usuario al grupo docker
usermod -aG docker "${USERNAME}"

# Habilitar Docker
systemctl enable docker
systemctl start docker

# Instalar herramientas Docker adicionales
# lazydocker
LAZYDOCKER_VERSION=$(curl -s https://api.github.com/repos/jesseduffield/lazydocker/releases/latest | jq -r '.tag_name')
curl -Lo /tmp/lazydocker.tar.gz "https://github.com/jesseduffield/lazydocker/releases/download/${LAZYDOCKER_VERSION}/lazydocker_${LAZYDOCKER_VERSION#v}_Linux_x86_64.tar.gz"
tar xzf /tmp/lazydocker.tar.gz -C /usr/local/bin lazydocker
chmod +x /usr/local/bin/lazydocker
rm /tmp/lazydocker.tar.gz

# ==============================================================================
# 3. GIT
# ==============================================================================

log "3/9 Configurando Git..."

# lazygit
LAZYGIT_VERSION=$(curl -s https://api.github.com/repos/jesseduffield/lazygit/releases/latest | jq -r '.tag_name')
curl -Lo /tmp/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/download/${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION#v}_Linux_x86_64.tar.gz"
tar xzf /tmp/lazygit.tar.gz -C /usr/local/bin lazygit
chmod +x /usr/local/bin/lazygit
rm /tmp/lazygit.tar.gz

# GitHub CLI
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list
apt-get update
apt-get install -y gh

# Configurar Git para el usuario
run_as_user "git config --global user.name '${GIT_NAME}'"
run_as_user "git config --global user.email '${GIT_EMAIL}'"
run_as_user "git config --global init.defaultBranch '${GIT_DEFAULT_BRANCH}'"
run_as_user "git config --global core.editor vim"
run_as_user "git config --global pull.rebase true"
run_as_user "git config --global push.autoSetupRemote true"

# ==============================================================================
# 4. NERD FONT (si está habilitado)
# ==============================================================================

if [[ "${NERD_FONT}" == "true" ]]; then
    log "4/9 Instalando JetBrains Mono Nerd Font..."
    
    FONT_DIR="${HOME_DIR}/.local/share/fonts"
    mkdir -p "${FONT_DIR}"
    
    FONT_VERSION="v3.1.1"
    curl -Lo /tmp/JetBrainsMono.zip "https://github.com/ryanoasis/nerd-fonts/releases/download/${FONT_VERSION}/JetBrainsMono.zip"
    unzip -o /tmp/JetBrainsMono.zip -d "${FONT_DIR}"
    rm /tmp/JetBrainsMono.zip
    
    chown -R "${USERNAME}:${USERNAME}" "${FONT_DIR}"
    
    # Actualizar cache de fuentes
    fc-cache -fv
else
    log "4/9 Saltando instalación de Nerd Font (deshabilitado)..."
fi

# ==============================================================================
# 5. SHELL Y PROMPT
# ==============================================================================

log "5/9 Configurando shell (${SHELL_TYPE}) y prompt (${PROMPT_THEME})..."

# Instalar Zsh si es necesario
if [[ "${SHELL_TYPE}" == "zsh" ]]; then
    apt-get install -y zsh
    chsh -s /bin/zsh "${USERNAME}"
fi

# --- Instalar tema de prompt ---

case "${PROMPT_THEME}" in
    "ohmyzsh")
        if [[ "${SHELL_TYPE}" != "zsh" ]]; then
            echo "ERROR: Oh My Zsh requiere shell=zsh"
            exit 1
        fi
        
        # Instalar Oh My Zsh
        run_as_user 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended'
        
        # Configurar tema
        sed -i "s/ZSH_THEME=\".*\"/ZSH_THEME=\"${OHMYZSH_THEME}\"/" "${HOME_DIR}/.zshrc"
        
        # Configurar plugins
        PLUGINS_FORMATTED=$(echo "${OHMYZSH_PLUGINS}" | tr ',' ' ')
        sed -i "s/plugins=(.*)/plugins=(${PLUGINS_FORMATTED})/" "${HOME_DIR}/.zshrc"
        
        # Si el tema es powerlevel10k, instalarlo
        if [[ "${OHMYZSH_THEME}" == "powerlevel10k" ]]; then
            run_as_user "git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \${ZSH_CUSTOM:-${HOME_DIR}/.oh-my-zsh/custom}/themes/powerlevel10k"
            sed -i 's/ZSH_THEME="powerlevel10k"/ZSH_THEME="powerlevel10k\/powerlevel10k"/' "${HOME_DIR}/.zshrc"
        fi
        ;;
        
    "ohmybash")
        if [[ "${SHELL_TYPE}" != "bash" ]]; then
            echo "ERROR: Oh My Bash requiere shell=bash"
            exit 1
        fi
        
        # Instalar Oh My Bash
        run_as_user 'bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)" --unattended'
        
        # Configurar tema
        sed -i "s/OSH_THEME=\".*\"/OSH_THEME=\"${OHMYBASH_THEME}\"/" "${HOME_DIR}/.bashrc"
        ;;
        
    "starship")
        # Instalar Starship
        curl -sS https://starship.rs/install.sh | sh -s -- -y
        
        # Aplicar preset
        mkdir -p "${HOME_DIR}/.config"
        if [[ "${STARSHIP_PRESET}" != "none" && "${STARSHIP_PRESET}" != "" ]]; then
            starship preset "${STARSHIP_PRESET}" -o "${HOME_DIR}/.config/starship.toml" || true
        fi
        
        # Añadir a shell
        if [[ "${SHELL_TYPE}" == "zsh" ]]; then
            echo 'eval "$(starship init zsh)"' >> "${HOME_DIR}/.zshrc"
        else
            echo 'eval "$(starship init bash)"' >> "${HOME_DIR}/.bashrc"
        fi
        
        chown -R "${USERNAME}:${USERNAME}" "${HOME_DIR}/.config"
        ;;
        
    "none")
        echo "Sin tema de prompt, usando defaults."
        ;;
esac

# ==============================================================================
# 6. CLIENTES DE BASE DE DATOS
# ==============================================================================

log "6/9 Instalando clientes de base de datos..."

apt-get install -y \
    mysql-client \
    postgresql-client \
    redis-tools \
    sqlite3

# ==============================================================================
# 7. VS CODE (si está habilitado)
# ==============================================================================

if [[ "${INSTALL_VSCODE}" == "true" ]]; then
    log "7/9 Instalando VS Code..."
    
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /usr/share/keyrings/packages.microsoft.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list
    
    apt-get update
    apt-get install -y code
    
    # Configurar VS Code
    VSCODE_DIR="${HOME_DIR}/.config/Code/User"
    mkdir -p "${VSCODE_DIR}"
    
    cat > "${VSCODE_DIR}/settings.json" << 'EOF'
{
    "editor.fontFamily": "'JetBrainsMono Nerd Font', 'JetBrains Mono', 'Fira Code', monospace",
    "editor.fontSize": 14,
    "editor.fontLigatures": true,
    "editor.formatOnSave": true,
    "editor.minimap.enabled": false,
    "editor.bracketPairColorization.enabled": true,
    "workbench.colorTheme": "Default Dark Modern",
    "workbench.startupEditor": "none",
    "terminal.integrated.fontFamily": "'JetBrainsMono Nerd Font', monospace",
    "terminal.integrated.fontSize": 13,
    "files.autoSave": "afterDelay",
    "files.trimTrailingWhitespace": true,
    "git.autofetch": true,
    "git.confirmSync": false,
    "docker.showStartPage": false,
    "telemetry.telemetryLevel": "off"
}
EOF
    
    chown -R "${USERNAME}:${USERNAME}" "${HOME_DIR}/.config"
    
    # Instalar extensiones básicas
    EXTENSIONS=(
        "ms-azuretools.vscode-docker"
        "ms-vscode-remote.remote-containers"
        "eamodio.gitlens"
        "mhutchie.git-graph"
        "EditorConfig.EditorConfig"
        "redhat.vscode-yaml"
    )
    
    for ext in "${EXTENSIONS[@]}"; do
        run_as_user "code --install-extension ${ext} --force" || true
    done
else
    log "7/9 Saltando instalación de VS Code (deshabilitado)..."
fi

# ==============================================================================
# 8. NAVEGADOR (si está configurado)
# ==============================================================================

log "8/9 Configurando navegador (${INSTALL_BROWSER})..."

case "${INSTALL_BROWSER}" in
    "firefox")
        apt-get install -y firefox
        ;;
    "chrome")
        wget -q -O /tmp/chrome.deb "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
        apt-get install -y /tmp/chrome.deb || apt-get install -f -y
        rm /tmp/chrome.deb
        ;;
    "chromium")
        apt-get install -y chromium-browser
        ;;
    "none")
        echo "Sin navegador adicional."
        ;;
esac

# ==============================================================================
# 9. CONFIGURACIÓN DESKTOP
# ==============================================================================

log "9/9 Configurando desktop..."

# Instalar gnome-tweaks
apt-get install -y gnome-tweaks gnome-shell-extension-manager

# Crear script de configuración GNOME (se ejecuta en primer login)
cat > "${HOME_DIR}/.config/autostart-setup.sh" << EOF
#!/bin/bash
# Configuración de GNOME (ejecutar una vez)

# Tema
gsettings set org.gnome.desktop.interface color-scheme 'prefer-${DESKTOP_THEME}'

# Fuente monospace si Nerd Font está instalado
if [[ "${NERD_FONT}" == "true" ]]; then
    gsettings set org.gnome.desktop.interface monospace-font-name 'JetBrainsMono Nerd Font 11'
fi

# Desactivar suspensión
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing'

# Dock favorites
gsettings set org.gnome.shell favorite-apps "['org.gnome.Nautilus.desktop', 'org.gnome.Terminal.desktop', 'code.desktop', 'firefox.desktop']"

# Auto-eliminar este script después de ejecutar
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

# ==============================================================================
# ALIASES DOCKER (añadir al shell config)
# ==============================================================================

ALIASES_CONTENT='
# ==============================================================================
# Docker Aliases
# ==============================================================================
alias d="docker"
alias dc="docker compose"
alias dps="docker ps --format \"table {{.Names}}\t{{.Status}}\t{{.Ports}}\""
alias dpsa="docker ps -a"
alias di="docker images"
alias dex="docker exec -it"
alias dlogs="docker logs -f"
alias dprune="docker system prune -af"
alias dcup="docker compose up -d"
alias dcdown="docker compose down"
alias dclogs="docker compose logs -f"
alias dcbuild="docker compose build --no-cache"

# ==============================================================================
# Git Aliases
# ==============================================================================
alias g="git"
alias gs="git status"
alias ga="git add"
alias gc="git commit"
alias gp="git push"
alias gl="git pull"
alias gd="git diff"
alias gco="git checkout"
alias glog="git log --oneline --graph --decorate -20"
alias lg="lazygit"
alias lzd="lazydocker"

# ==============================================================================
# Navigation
# ==============================================================================
alias ll="ls -la"
alias ..="cd .."
alias ...="cd ../.."
alias proj="cd ~/projects"
alias work="cd ~/projects/work"
'

if [[ "${SHELL_TYPE}" == "zsh" ]]; then
    echo "${ALIASES_CONTENT}" >> "${HOME_DIR}/.zshrc"
else
    echo "${ALIASES_CONTENT}" >> "${HOME_DIR}/.bashrc"
fi

chown "${USERNAME}:${USERNAME}" "${HOME_DIR}/.zshrc" 2>/dev/null || true
chown "${USERNAME}:${USERNAME}" "${HOME_DIR}/.bashrc" 2>/dev/null || true

# ==============================================================================
# FIN
# ==============================================================================

log "✓ Provisioning completado!"
echo ""
echo "Resumen:"
echo "  - Usuario: ${USERNAME}"
echo "  - Shell: ${SHELL_TYPE}"
echo "  - Prompt: ${PROMPT_THEME}"
echo "  - Docker: instalado"
echo "  - VS Code: ${INSTALL_VSCODE}"
echo "  - Navegador: ${INSTALL_BROWSER}"
echo "  - Nerd Font: ${NERD_FONT}"
echo ""
