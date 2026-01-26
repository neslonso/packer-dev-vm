#!/bin/bash
# ==============================================================================
# PROVISION.SH - Script único de provisioning
# ==============================================================================
# Todas las configuraciones se reciben via variables de entorno VM_*
# Este script NO tiene valores hardcodeados.
# ==============================================================================

set -euo pipefail

# Force unbuffered output
export PYTHONUNBUFFERED=1
stty -echo 2>/dev/null || true

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
INSTALL_PORTAINER="${VM_INSTALL_PORTAINER}"
DESKTOP_THEME="${VM_DESKTOP_THEME}"
INSTALL_VSCODE="${VM_INSTALL_VSCODE}"
INSTALL_ANTIGRAVITY="${VM_INSTALL_ANTIGRAVITY}"
INSTALL_CURSOR="${VM_INSTALL_CURSOR}"
INSTALL_SUBLIMEMERGE="${VM_INSTALL_SUBLIMEMERGE}"
INSTALL_BROWSER="${VM_INSTALL_BROWSER}"
WELCOME_HTML="${VM_WELCOME_HTML}"

# Red
NETWORK_MODE="${VM_NETWORK_MODE}"
STATIC_IP="${VM_STATIC_IP}"
STATIC_GATEWAY="${VM_STATIC_GATEWAY}"
STATIC_DNS="${VM_STATIC_DNS}"

# GPG Fingerprints (from centralized configuration in main.pkr.hcl)
DOCKER_GPG_FINGERPRINT="${GPG_FINGERPRINT_DOCKER}"
GITHUB_CLI_GPG_FINGERPRINT="${GPG_FINGERPRINT_GITHUB}"
MICROSOFT_GPG_FINGERPRINT="${GPG_FINGERPRINT_MICROSOFT}"
GOOGLE_GPG_FINGERPRINT="${GPG_FINGERPRINT_GOOGLE}"

HOME_DIR="/home/${USERNAME}"

export DEBIAN_FRONTEND=noninteractive

# ==============================================================================
# LOGGING
# ==============================================================================
PROVISION_LOG="/var/log/provision.log"
touch "$PROVISION_LOG"
chmod 644 "$PROVISION_LOG"

# Redirect all command output to log file
exec 3>&1 4>&2  # Save stdout/stderr
exec 1>>"$PROVISION_LOG" 2>&1  # Redirect to log

# Function to write to both console and log
log_msg() {
    echo "$@" >&3  # Write to console (saved fd 3)
    echo "$@" >>"$PROVISION_LOG"  # Also write to log
}

# ==============================================================================
# INICIO DEL SCRIPT
# ==============================================================================
log_msg ""
log_msg "============================================================"
log_msg ">>> INICIO DE PROVISION.SH"
log_msg ">>> Timestamp: $(date '+%Y-%m-%d %H:%M:%S %Z')"
log_msg ">>> Log file: $PROVISION_LOG"
log_msg "============================================================"
log_msg ""
log_msg "VARIABLES DE BUILD:"
log_msg "  - Usuario: ${USERNAME}"
log_msg "  - Hostname: ${HOSTNAME}"
log_msg "  - Timezone: ${TIMEZONE}"
log_msg "  - Locale: ${LOCALE}"
log_msg "  - Keyboard: ${KEYBOARD}"
log_msg "  - Shell: ${SHELL_TYPE}"
log_msg "  - Prompt Theme: ${PROMPT_THEME}"
log_msg "  - Nerd Font: ${NERD_FONT}"
log_msg "  - Desktop Theme: ${DESKTOP_THEME}"
log_msg "  - Install VS Code: ${INSTALL_VSCODE}"
log_msg "  - Install Antigravity: ${INSTALL_ANTIGRAVITY}"
log_msg "  - Install Browser: ${INSTALL_BROWSER}"
log_msg "  - Git Name: ${GIT_NAME}"
log_msg "  - Git Email: ${GIT_EMAIL}"
log_msg "  - Git Default Branch: ${GIT_DEFAULT_BRANCH}"
log_msg "  - Docker Log Max Size: ${DOCKER_LOG_MAX_SIZE}"
log_msg "  - Docker Log Max File: ${DOCKER_LOG_MAX_FILE}"
log_msg "  - Install Portainer: ${INSTALL_PORTAINER}"
log_msg ""

# ==============================================================================
# FUNCIONES AUXILIARES
# ==============================================================================

log_section() {
    local msg="$1"
    # Main section headers with box (N/10 steps only)
    log_msg ""
    log_msg "╔══════════════════════════════════════════════════════════════╗"
    log_msg "║ $msg"
    log_msg "╚══════════════════════════════════════════════════════════════╝"
}

log_task() {
    local msg="$1"
    # Sub-tasks with simple arrow prefix
    log_msg "→ $msg"
}

log_success() {
    local msg="$1"
    # Success messages with checkmark
    log_msg "✓ $msg"
}

log_warning() {
    local msg="$1"
    # Warning messages with warning symbol
    log_msg "⚠ $msg"
}

log_error() {
    local msg="$1"
    # Error messages with X symbol
    log_msg "✗ $msg"
}

# Escape string for safe use in shell commands
shell_escape() {
    local str="$1"
    # Replace single quotes with '\'' (end quote, escaped quote, start quote)
    printf '%s' "$str" | sed "s/'/'\\\\''/g"
}

# Run command as user with proper escaping
run_as_user() {
    local cmd="$1"
    sudo -u "${USERNAME}" -H bash -c "$cmd"
}

# Download and verify script before execution
download_and_verify_script() {
    local url="$1"
    local temp_file="$2"
    local description="${3:-script}"

    log_task "Downloading ${description} from ${url}..."

    # Download with timeout and HTTPS verification
    if ! curl --max-time 60 --fail --silent --show-error --location "$url" -o "$temp_file"; then
        log_msg "ERROR: Failed to download ${description} from ${url}"
        return 1
    fi

    # Verify file is not empty
    if [[ ! -s "$temp_file" ]]; then
        log_msg "ERROR: Downloaded ${description} is empty"
        rm -f "$temp_file"
        return 1
    fi

    # Basic sanity check: file should contain shell script markers
    if ! grep -q -E '(^#!/|bash|sh)' "$temp_file"; then
        log_msg "ERROR: Downloaded ${description} doesn't appear to be a valid shell script"
        rm -f "$temp_file"
        return 1
    fi

    log_success "Successfully downloaded and verified ${description}"
    return 0
}

# Validate tar archive for path traversal attacks
validate_tar_archive() {
    local archive="$1"
    local description="${2:-archive}"

    log_task "Validating ${description} for security..."

    # Check for path traversal attempts
    if tar -tzf "$archive" 2>/dev/null | grep -E '(^|/)\.\.(\/|$)' > /dev/null; then
        log_msg "ERROR: ${description} contains dangerous path traversal sequences (..)"
        return 1
    fi

    # Check for absolute paths
    if tar -tzf "$archive" 2>/dev/null | grep -E '^/' > /dev/null; then
        log_msg "ERROR: ${description} contains absolute paths"
        return 1
    fi

    log_success "${description} passed security validation"
    return 0
}

# Validate zip archive for path traversal attacks
validate_zip_archive() {
    local archive="$1"
    local description="${2:-archive}"

    log_task "Validating ${description} for security..."

    # Check for path traversal attempts (using -Z -1 to handle filenames with spaces)
    if unzip -Z -1 "$archive" 2>/dev/null | grep -E '(^|/)\.\.(\/|$)' > /dev/null; then
        log_msg "ERROR: ${description} contains dangerous path traversal sequences (..)"
        return 1
    fi

    # Check for absolute paths
    if unzip -Z -1 "$archive" 2>/dev/null | grep -E '^/' > /dev/null; then
        log_msg "ERROR: ${description} contains absolute paths"
        return 1
    fi

    log_success "${description} passed security validation"
    return 0
}

# Download GPG key and verify fingerprint
download_and_verify_gpg_key() {
    local url="$1"
    local output_file="$2"
    local expected_fingerprint="$3"
    local description="${4:-GPG key}"

    log_task "Downloading ${description}..."

    # Download key to temporary file
    local temp_key="/tmp/gpg-key-$$.asc"
    if ! curl --max-time 30 --fail --silent --show-error --location "$url" -o "$temp_key"; then
        log_msg "ERROR: Failed to download ${description}"
        return 1
    fi

    # Import to temporary keyring and get fingerprint
    local temp_keyring="/tmp/keyring-$$"
    mkdir -p "$temp_keyring"
    chmod 700 "$temp_keyring"

    # Import key and capture output
    local import_output
    import_output=$(gpg --no-default-keyring --keyring "$temp_keyring/temp.gpg" --import "$temp_key" 2>&1)

    # Extract fingerprint - try multiple methods
    local actual_fingerprint=""

    # Method 1: Look for 40 consecutive hex chars
    actual_fingerprint=$(echo "$import_output" | grep -oP '[0-9A-F]{40}' | head -1)

    # Method 2: Look for fingerprint line with spaces
    if [[ -z "$actual_fingerprint" ]]; then
        actual_fingerprint=$(echo "$import_output" | grep -i 'fingerprint' | grep -oP '[0-9A-F]{4}(\s+[0-9A-F]{4}){9}' | head -1 | tr -d ' ')
    fi

    # Method 3: List keys and get fingerprint
    if [[ -z "$actual_fingerprint" ]]; then
        actual_fingerprint=$(gpg --no-default-keyring --keyring "$temp_keyring/temp.gpg" --fingerprint --with-colons 2>/dev/null | grep '^fpr:' | head -1 | cut -d: -f10)
    fi

    # Method 4: Try with list-keys
    if [[ -z "$actual_fingerprint" ]]; then
        local key_id=$(echo "$import_output" | grep -oP 'key [0-9A-F]+' | head -1 | awk '{print $2}')
        if [[ -n "$key_id" ]]; then
            actual_fingerprint=$(gpg --no-default-keyring --keyring "$temp_keyring/temp.gpg" --list-keys --with-colons "$key_id" 2>/dev/null | grep '^fpr:' | head -1 | cut -d: -f10)
        fi
    fi

    # Format fingerprint with spaces (groups of 4)
    if [[ -n "$actual_fingerprint" ]]; then
        # Remove any existing spaces first
        actual_fingerprint=$(echo "$actual_fingerprint" | tr -d ' ')
        # Add spaces every 4 chars
        actual_fingerprint=$(echo "$actual_fingerprint" | sed 's/.\{4\}/& /g' | xargs)
    fi

    # Clean up temporary keyring
    rm -rf "$temp_keyring"

    # Normalize fingerprints for comparison (remove spaces)
    local expected_norm="${expected_fingerprint// /}"
    local actual_norm="${actual_fingerprint// /}"

    # Verify fingerprint matches
    if [[ "$actual_norm" != "$expected_norm" ]]; then
        log_msg "ERROR: ${description} fingerprint mismatch!"
        log_msg "  Expected: ${expected_fingerprint}"
        log_msg "  Got:      ${actual_fingerprint}"
        rm -f "$temp_key"
        return 1
    fi

    log_success "${description} fingerprint verified: ${actual_fingerprint}"

    # Dearmor and save to final location
    gpg --dearmor < "$temp_key" > "$output_file"
    rm -f "$temp_key"

    return 0
}

# ==============================================================================
# 1. SISTEMA BASE
# ==============================================================================

log_section "1/10 Configurando sistema base..."

# Configurar red según network_mode
log_task "Configurando red (modo: ${NETWORK_MODE})..."

# Remove ALL old netplan configs to avoid warnings (permissions, deprecated gateway4, etc.)
rm -f /etc/netplan/*.yaml

if [[ "${NETWORK_MODE}" == "dhcp" ]]; then
    # Configuración DHCP
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

    # Forzar renovación DHCP para obtener IP inmediatamente
    sleep 2
    dhclient -r eth0 2>/dev/null || true
    dhclient eth0 2>/dev/null || true
    sleep 2

    log_success "Red configurada (DHCP) - IP: $(hostname -I | awk '{print $1}')"
else
    # Configuración IP estática
    # Convertir DNS de "8.8.8.8,8.8.4.4" a formato YAML "[8.8.8.8, 8.8.4.4]"
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

# Actualizar sistema
log_task "Actualizar sistema..."
apt-get update
apt-get upgrade -y

# Configurar locale (generate user's locale and en_US.UTF-8 as fallback for tools that require it)
log_task "Configurar locale..."
locale-gen "${LOCALE}" en_US.UTF-8
update-locale LANG="${LOCALE}"

# Instalar herramientas básicas
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
    bat

# Crear symlinks para herramientas con nombres diferentes
# Note: || true is acceptable here - these are convenience symlinks that may not exist on all systems
if ! ln -sf /usr/bin/batcat /usr/local/bin/bat 2>/dev/null; then
    log_warning "batcat not available, bat command will not work"
fi
if ! ln -sf /usr/bin/fdfind /usr/local/bin/fd 2>/dev/null; then
    log_warning "fdfind not available, fd command will not work"
fi

# ==============================================================================
# 2. DOCKER
# ==============================================================================

log_section "2/10 Instalando Docker..."

# Añadir repositorio de Docker (with GPG key verification)
install -m 0755 -d /etc/apt/keyrings
# Docker official GPG key fingerprint (from main.pkr.hcl)
if ! download_and_verify_gpg_key "https://download.docker.com/linux/ubuntu/gpg" "/etc/apt/keyrings/docker.gpg" "$DOCKER_GPG_FINGERPRINT" "Docker GPG key"; then
    log_msg "ERROR: Failed to verify Docker GPG key"
    exit 1
fi
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
# lazydocker (with error handling and fallback version)
LAZYDOCKER_VERSION=$(curl --max-time 30 --fail --silent --show-error https://api.github.com/repos/jesseduffield/lazydocker/releases/latest 2>/dev/null | jq -r '.tag_name' 2>/dev/null || echo "")

if [[ -z "$LAZYDOCKER_VERSION" || "$LAZYDOCKER_VERSION" == "null" ]]; then
    log_warning "Failed to fetch lazydocker latest version from GitHub API, using fallback"
    LAZYDOCKER_VERSION="v0.23.1"  # Fallback to known stable version
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

# Portainer (Web UI para Docker)
if [[ "${INSTALL_PORTAINER}" == "true" ]]; then
    log_task "Instalando Portainer CE..."

    # Crear volumen para datos persistentes
    docker volume create portainer_data

    # Ejecutar Portainer como contenedor
    # Puerto 9443: HTTPS (recomendado)
    # Puerto 9000: HTTP (legacy, deshabilitado por defecto)
    if docker run -d \
        -p 9443:9443 \
        --name portainer \
        --restart=always \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v portainer_data:/data \
        portainer/portainer-ce:lts; then
        log_success "Portainer CE instalado (https://localhost:9443)"
    else
        log_error "Failed to start Portainer container"
    fi
else
    log_task "Saltando instalación de Portainer (deshabilitado)"
fi

# ==============================================================================
# 3. GIT
# ==============================================================================

log_section "3/10 Configurando Git..."

# lazygit (with error handling and fallback version)
LAZYGIT_VERSION=$(curl --max-time 30 --fail --silent --show-error https://api.github.com/repos/jesseduffield/lazygit/releases/latest 2>/dev/null | jq -r '.tag_name' 2>/dev/null || echo "")

if [[ -z "$LAZYGIT_VERSION" || "$LAZYGIT_VERSION" == "null" ]]; then
    log_warning "Failed to fetch lazygit latest version from GitHub API, using fallback"
    LAZYGIT_VERSION="v0.40.2"  # Fallback to known stable version
fi

log_task "Installing lazygit ${LAZYGIT_VERSION}..."

if curl --max-time 60 --fail -Lo /tmp/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/download/${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION#v}_Linux_x86_64.tar.gz" 2>&1; then
    if validate_tar_archive /tmp/lazygit.tar.gz "lazygit archive"; then
        tar xzf /tmp/lazygit.tar.gz -C /usr/local/bin lazygit
        chmod +x /usr/local/bin/lazygit
        log_success "lazygit ${LAZYGIT_VERSION} installed successfully"
    else
        log_error "lazygit archive validation failed, skipping installation"
    fi
    rm /tmp/lazygit.tar.gz
else
    log_warning "Failed to download lazygit, skipping..."
fi

# GitHub CLI (with GPG key verification)
# GitHub CLI official GPG key fingerprint (from main.pkr.hcl)
if ! download_and_verify_gpg_key "https://cli.github.com/packages/githubcli-archive-keyring.gpg" "/usr/share/keyrings/githubcli-archive-keyring.gpg" "$GITHUB_CLI_GPG_FINGERPRINT" "GitHub CLI GPG key"; then
    log_msg "ERROR: Failed to verify GitHub CLI GPG key"
    exit 1
fi
chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list
apt-get update
apt-get install -y gh

# Configurar Git para el usuario (using safe escaping)
GIT_NAME_ESCAPED=$(shell_escape "${GIT_NAME}")
GIT_EMAIL_ESCAPED=$(shell_escape "${GIT_EMAIL}")
GIT_BRANCH_ESCAPED=$(shell_escape "${GIT_DEFAULT_BRANCH}")

run_as_user "git config --global user.name '${GIT_NAME_ESCAPED}'"
run_as_user "git config --global user.email '${GIT_EMAIL_ESCAPED}'"
run_as_user "git config --global init.defaultBranch '${GIT_BRANCH_ESCAPED}'"
run_as_user "git config --global core.editor vim"
run_as_user "git config --global pull.rebase true"
run_as_user "git config --global push.autoSetupRemote true"

# Security and safety configurations
run_as_user "git config --global core.autocrlf input"  # Prevent CRLF issues
run_as_user "git config --global core.filemode false"  # Ignore file mode changes (useful in VMs)
run_as_user "git config --global fetch.prune true"     # Auto-prune deleted remote branches
run_as_user "git config --global diff.colorMoved zebra"  # Better diff visualization
run_as_user "git config --global rerere.enabled true"  # Remember resolved conflicts
run_as_user "git config --global help.autocorrect 10"  # Auto-correct typos after 1 second

# ==============================================================================
# 4. NERD FONT (si está habilitado)
# ==============================================================================

if [[ "${NERD_FONT}" != "none" ]]; then
    log_section "4/10 Instalando ${NERD_FONT} Nerd Font..."

    FONT_DIR="${HOME_DIR}/.local/share/fonts"
    run_as_user "mkdir -p '${FONT_DIR}'"

    # Try to fetch latest version from GitHub API, with fallback
    FONT_VERSION=$(curl --max-time 30 --fail --silent --show-error https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest 2>/dev/null | jq -r '.tag_name' 2>/dev/null || echo "")

    if [[ -z "$FONT_VERSION" || "$FONT_VERSION" == "null" ]]; then
        log_warning "Failed to fetch latest font version from GitHub API, using fallback"
        FONT_VERSION="v3.1.1"  # Fallback to known stable version
    fi

    log_task "Downloading ${NERD_FONT} Nerd Font ${FONT_VERSION}..."

    # Download font archive (name matches the variable, e.g., JetBrainsMono.zip, FiraCode.zip)
    FONT_FILE="/tmp/${NERD_FONT}.zip"
    FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/${FONT_VERSION}/${NERD_FONT}.zip"

    if curl --max-time 120 --fail -Lo "${FONT_FILE}" "${FONT_URL}" 2>&1; then
        if validate_zip_archive "${FONT_FILE}" "${NERD_FONT} font"; then
            unzip -o "${FONT_FILE}" -d "${FONT_DIR}"
            log_success "${NERD_FONT} Nerd Font installed successfully"
        else
            log_msg "ERROR: ${NERD_FONT} font archive validation failed"
            exit 1
        fi
        rm "${FONT_FILE}"
    else
        log_msg "ERROR: Failed to download ${NERD_FONT} Nerd Font from ${FONT_URL}"
        log_msg "NOTE: Ensure the font name matches the release asset name on GitHub"
        exit 1
    fi

    # Actualizar cache de fuentes
    fc-cache -fv
else
    log_section "4/10 Saltando instalación de Nerd Font (nerd_font=none)..."
fi
# ==============================================================================
# 4.5. GLOBAL FONT FAMILY (Mapping para editores)
# ==============================================================================

# Determine global font family based on installed Nerd Font (used by VS Code, Antigravity, Cursor, etc.)
if [[ "${NERD_FONT}" != "none" ]]; then
    case "${NERD_FONT}" in
        "JetBrainsMono")
            GLOBAL_FONT_FAMILY="'JetBrainsMono Nerd Font', 'JetBrains Mono', monospace"
            ;;
        "FiraCode")
            GLOBAL_FONT_FAMILY="'FiraCode Nerd Font', 'Fira Code', monospace"
            ;;
        "Hack")
            GLOBAL_FONT_FAMILY="'Hack Nerd Font', 'Hack', monospace"
            ;;
        "SourceCodePro")
            GLOBAL_FONT_FAMILY="'SauceCodePro Nerd Font', 'Source Code Pro', monospace"
            ;;
        "Meslo")
            GLOBAL_FONT_FAMILY="'MesloLGS NF', 'Meslo', monospace"
            ;;
        *)
            GLOBAL_FONT_FAMILY="'${NERD_FONT} Nerd Font', monospace"
            ;;
    esac
else
    GLOBAL_FONT_FAMILY="'Fira Code', 'Consolas', monospace"
fi


# ==============================================================================
# 5. SHELL Y PROMPT
# ==============================================================================

log_section "5/10 Configurando shell (${SHELL_TYPE}) y prompt (${PROMPT_THEME})..."

# Instalar Zsh si es necesario
if [[ "${SHELL_TYPE}" == "zsh" ]]; then
    apt-get install -y zsh
    chsh -s /bin/zsh "${USERNAME}"
fi

# --- Instalar tema de prompt ---

case "${PROMPT_THEME}" in
    "ohmyzsh")
        if [[ "${SHELL_TYPE}" != "zsh" ]]; then
            log_msg "ERROR: Oh My Zsh requiere shell=zsh"
            exit 1
        fi
        
        # Instalar Oh My Zsh (with verification)
        OMZSH_SCRIPT="/tmp/omzsh-install.sh"
        if download_and_verify_script "https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh" "$OMZSH_SCRIPT" "Oh My Zsh installer"; then
            run_as_user "sh ${OMZSH_SCRIPT} --unattended"
            rm -f "$OMZSH_SCRIPT"
        else
            log_msg "ERROR: Failed to install Oh My Zsh"
            exit 1
        fi

        # Configurar tema (using safe escaping for sed)
        OHMYZSH_THEME_ESCAPED=$(printf '%s\n' "${OHMYZSH_THEME}" | sed 's/[\/&]/\\&/g')
        sed -i "s/^ZSH_THEME=\".*\"/ZSH_THEME=\"${OHMYZSH_THEME_ESCAPED}\"/" "${HOME_DIR}/.zshrc"

        # Configurar plugins (using safe escaping)
        PLUGINS_FORMATTED=$(echo "${OHMYZSH_PLUGINS}" | tr ',' ' ')
        PLUGINS_ESCAPED=$(printf '%s\n' "${PLUGINS_FORMATTED}" | sed 's/[\/&]/\\&/g')
        sed -i "s/^plugins=(.*)/plugins=(${PLUGINS_ESCAPED})/" "${HOME_DIR}/.zshrc"
        
        # Si el tema es powerlevel10k, instalarlo
        if [[ "${OHMYZSH_THEME}" == "powerlevel10k" ]]; then
            run_as_user "git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \"\${ZSH_CUSTOM:-\$HOME/.oh-my-zsh/custom}/themes/powerlevel10k\""
            sed -i 's/^ZSH_THEME="powerlevel10k"/ZSH_THEME="powerlevel10k\/powerlevel10k"/' "${HOME_DIR}/.zshrc"
        fi
        ;;
        
    "ohmybash")
        if [[ "${SHELL_TYPE}" != "bash" ]]; then
            log_msg "ERROR: Oh My Bash requiere shell=bash"
            exit 1
        fi
        
        # Instalar Oh My Bash (with verification)
        OMBSH_SCRIPT="/tmp/ombash-install.sh"
        if download_and_verify_script "https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh" "$OMBSH_SCRIPT" "Oh My Bash installer"; then
            run_as_user "bash ${OMBSH_SCRIPT} --unattended"
            rm -f "$OMBSH_SCRIPT"
        else
            log_msg "ERROR: Failed to install Oh My Bash"
            exit 1
        fi

        # Configurar tema (using safe escaping for sed)
        OHMYBASH_THEME_ESCAPED=$(printf '%s\n' "${OHMYBASH_THEME}" | sed 's/[\/&]/\\&/g')
        sed -i "s/^OSH_THEME=\".*\"/OSH_THEME=\"${OHMYBASH_THEME_ESCAPED}\"/" "${HOME_DIR}/.bashrc"
        ;;
        
    "starship")
        # Instalar Starship (with verification)
        STARSHIP_SCRIPT="/tmp/starship-install.sh"
        if download_and_verify_script "https://starship.rs/install.sh" "$STARSHIP_SCRIPT" "Starship installer"; then
            sh "$STARSHIP_SCRIPT" -y
            rm -f "$STARSHIP_SCRIPT"
        else
            log_msg "ERROR: Failed to install Starship"
            exit 1
        fi
        
        # Aplicar preset
        if ! mkdir -p "${HOME_DIR}/.config"; then
            log_msg "ERROR: Failed to create .config directory"
            exit 1
        fi
        if [[ "${STARSHIP_PRESET}" != "none" && "${STARSHIP_PRESET}" != "" ]]; then
            if ! starship preset "${STARSHIP_PRESET}" -o "${HOME_DIR}/.config/starship.toml" 2>/dev/null; then
                log_warning "Failed to apply starship preset '${STARSHIP_PRESET}', using default config"
            fi
        fi
        
        # Añadir a shell
        if [[ "${SHELL_TYPE}" == "zsh" ]]; then
            echo 'eval "$(starship init zsh)"' >> "${HOME_DIR}/.zshrc"
        else
            echo 'eval "$(starship init bash)"' >> "${HOME_DIR}/.bashrc"
        fi
        ;;

    "none")
        echo "Sin tema de prompt, usando defaults."
        ;;
esac

# ==============================================================================
# 6. CLIENTES DE BASE DE DATOS
# ==============================================================================

log_section "6/10 Instalando clientes de base de datos..."

apt-get install -y \
    mysql-client \
    postgresql-client \
    redis-tools \
    sqlite3

# ==============================================================================
# 7. VS CODE (si está habilitado)
# ==============================================================================

if [[ "${INSTALL_VSCODE}" == "true" ]]; then
    log_section "7/10 Instalando VS Code..."

    # Microsoft GPG key (with verification - from main.pkr.hcl)
    if ! download_and_verify_gpg_key "https://packages.microsoft.com/keys/microsoft.asc" "/usr/share/keyrings/packages.microsoft.gpg" "$MICROSOFT_GPG_FINGERPRINT" "Microsoft GPG key"; then
        log_msg "ERROR: Failed to verify Microsoft GPG key"
        exit 1
    fi
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list
    
    apt-get update
    apt-get install -y code
    
    # Function to apply common VS Code-based settings
    apply_vscode_settings() {
        local config_dir=$1
        local user_dir="${HOME_DIR}/.config/${config_dir}/User"
        mkdir -p "${user_dir}"
        cat > "${user_dir}/settings.json" << EOF
{
    "editor.fontFamily": "${GLOBAL_FONT_FAMILY}",
    "editor.fontSize": 14,
    "editor.fontLigatures": true,
    "editor.formatOnSave": true,
    "editor.minimap.enabled": false,
    "editor.bracketPairColorization.enabled": true,
    "workbench.colorTheme": "Default Dark Modern",
    "workbench.startupEditor": "none",
    "terminal.integrated.fontFamily": "${GLOBAL_FONT_FAMILY}",
    "terminal.integrated.fontSize": 13,
    "files.autoSave": "afterDelay",
    "files.trimTrailingWhitespace": true,
    "explorer.excludeGitIgnore": false,
    "git.autofetch": true,
    "git.confirmSync": false,
    "docker.showStartPage": false,
    "telemetry.telemetryLevel": "off"
}
EOF
        chown -R "${USERNAME}:${USERNAME}" "${HOME_DIR}/.config/${config_dir}"
    }

    # Apply settings to VS Code
    apply_vscode_settings "Code"

    # Instalar extensiones básicas
    EXTENSIONS=(
        "ms-azuretools.vscode-docker"
        "ms-vscode-remote.remote-containers"
        "eamodio.gitlens"
        "mhutchie.git-graph"
        "EditorConfig.EditorConfig"
        "redhat.vscode-yaml"
    )

    log_task "Installing VS Code extensions..."
    for ext in "${EXTENSIONS[@]}"; do
        if run_as_user "code --install-extension ${ext} --force" 2>&1; then
            log_success "Installed extension: ${ext}"
        else
            log_warning "Failed to install extension: ${ext}"
        fi
    done
else
    log_section "7/10 Saltando instalación de VS Code (deshabilitado)..."
fi

# ==============================================================================
# 7.5. GOOGLE ANTIGRAVITY IDE (si está habilitado)
# ==============================================================================

if [[ "${INSTALL_ANTIGRAVITY}" == "true" ]]; then
    log_section "7.5/10 Instalando Google Antigravity IDE..."

    # Download and add Google Antigravity repository GPG key
    # Official key from https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg
    curl -fsSL https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg | gpg --dearmor -o /etc/apt/keyrings/antigravity-repo-key.gpg

    # Add Antigravity official repository
    echo "deb [signed-by=/etc/apt/keyrings/antigravity-repo-key.gpg] https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev antigravity-debian main" > /etc/apt/sources.list.d/antigravity.list

    apt-get update
    apt-get install -y antigravity

    log_success "Google Antigravity IDE installed successfully"

    # Configure Antigravity settings
    apply_vscode_settings "antigravity"

    # Configure desktop launcher (optional)
    if [[ -f "/usr/share/applications/antigravity.desktop" ]]; then
        # Make it available for the user (create directory as user to ensure correct ownership)
        run_as_user "mkdir -p '${HOME_DIR}/.local/share/applications'"
        cp /usr/share/applications/antigravity.desktop "${HOME_DIR}/.local/share/applications/"
        chown "${USERNAME}:${USERNAME}" "${HOME_DIR}/.local/share/applications/antigravity.desktop"
    fi
else
    log_section "7.5/10 Saltando instalación de Google Antigravity IDE (deshabilitado)..."
fi

# ==============================================================================
# 7.6. CURSOR (si está habilitado)
# ==============================================================================

if [[ "${INSTALL_CURSOR}" == "true" ]]; then
    log_section "7.6/10 Instalando Cursor..."

    # Instalar libfuse2 (necesario para AppImages)
    apt-get install -y libfuse2

    # Download Cursor AppImage (con fallback URLs)
    CURSOR_APPIMAGE="/opt/cursor/cursor.AppImage"
    mkdir -p /opt/cursor

    log_task "Downloading Cursor AppImage..."
    CURSOR_DOWNLOADED=false

    # Intentar múltiples URLs
    CURSOR_URLS=(
        "https://download.cursor.sh/linux/appImage/x64"
        "https://downloader.cursor.sh/linux/appImage/x64"
        "https://api2.cursor.sh/updates/download-latest?platform=linux-x64&releaseTrack=stable"
    )

    for url in "${CURSOR_URLS[@]}"; do
        log_task "Trying: ${url}"
        if curl --max-time 180 --fail -L -o "${CURSOR_APPIMAGE}" "${url}" 2>&1; then
            CURSOR_DOWNLOADED=true
            log_success "Downloaded from ${url}"
            break
        fi
        log_warning "Failed: ${url}"
    done

    if [[ "${CURSOR_DOWNLOADED}" == "true" ]]; then
        chmod +x "${CURSOR_APPIMAGE}"
        log_success "Cursor downloaded successfully"

        # Create desktop entry
        cat > /usr/share/applications/cursor.desktop << 'CURSOR_DESKTOP_EOF'
[Desktop Entry]
Name=Cursor
Comment=AI-powered code editor
Exec=/opt/cursor/cursor.AppImage --no-sandbox %F
Icon=cursor
Type=Application
Categories=Development;IDE;
MimeType=text/plain;
StartupNotify=true
StartupWMClass=Cursor
CURSOR_DESKTOP_EOF

        # Download and install icon
        curl -fsSL "https://www.cursor.com/assets/images/logo.svg" -o /usr/share/icons/cursor.svg 2>/dev/null || true

        log_success "Cursor installed successfully"

        # Configure Cursor settings
        apply_vscode_settings "Cursor"
    else
        log_error "Failed to download Cursor from all URLs, skipping..."
        rm -rf /opt/cursor
    fi
else
    log_section "7.6/10 Saltando instalación de Cursor (deshabilitado)..."
fi

# ==============================================================================
# 7.7. SUBLIME MERGE (si está habilitado)
# ==============================================================================

if [[ "${INSTALL_SUBLIMEMERGE}" == "true" ]]; then
    log_section "7.7/10 Instalando Sublime Merge..."

    # Add Sublime Text/Merge repository
    # GPG key from https://www.sublimetext.com/docs/linux_repositories.html
    curl -fsSL https://download.sublimetext.com/sublimehq-pub.gpg | gpg --dearmor -o /etc/apt/keyrings/sublimehq.gpg

    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/sublimehq.gpg] https://download.sublimetext.com/ apt/stable/" > /etc/apt/sources.list.d/sublime-text.list

    apt-get update
    apt-get install -y sublime-merge

    log_success "Sublime Merge installed successfully"
else
    log_section "7.7/10 Saltando instalación de Sublime Merge (deshabilitado)..."
fi

# ==============================================================================
# 8. NAVEGADOR (si está configurado)
# ==============================================================================

log_section "8/10 Configurando navegador (${INSTALL_BROWSER})..."

case "${INSTALL_BROWSER}" in
    "firefox")
        apt-get install -y firefox
        ;;
    "chrome")
        # Add Google Chrome repository with GPG verification
        download_and_verify_gpg_key \
            "https://dl.google.com/linux/linux_signing_key.pub" \
            "/etc/apt/keyrings/google-chrome.gpg" \
            "$GOOGLE_GPG_FINGERPRINT" \
            "Google Chrome"

        echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list
        apt-get update
        apt-get install -y google-chrome-stable
        ;;
    "chromium")
        apt-get install -y chromium
        ;;
    "none")
        echo "Sin navegador adicional."
        ;;
esac

# ==============================================================================
# 9. CONFIGURACIÓN DESKTOP
# ==============================================================================

log_section "9/10 Configurando desktop..."

# Instalar gnome-tweaks
apt-get install -y gnome-tweaks gnome-shell-extension-manager

# Crear script de configuración GNOME (se ejecuta en primer login)
cat > "${HOME_DIR}/.config/autostart-setup.sh" << EOF
#!/bin/bash
# Configuración de GNOME (ejecutar una vez)

# Error handling
set -euo pipefail
LOG_FILE="\${HOME}/.config/gnome-setup.log"
exec > >(tee -a "\${LOG_FILE}") 2>&1

echo "[\$(date)] Starting GNOME configuration..."

# Tema
gsettings set org.gnome.desktop.interface color-scheme 'prefer-${DESKTOP_THEME}' || echo "WARNING: Failed to set color scheme"

# Fuente monospace si Nerd Font está instalado
if [[ "${NERD_FONT}" != "none" ]]; then
    # Map font names to their system font names for GNOME
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
            # Default fallback - construct name from variable
            FONT_SYSTEM_NAME="${NERD_FONT} Nerd Font 11"
            ;;
    esac
    gsettings set org.gnome.desktop.interface monospace-font-name "\${FONT_SYSTEM_NAME}" || echo "WARNING: Failed to set monospace font"
fi

# Desactivar suspensión
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing' || echo "WARNING: Failed to set AC sleep policy"
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing' || echo "WARNING: Failed to set battery sleep policy"

# Dock favorites - build dynamically based on installed apps
# Order: Nautilus, Terminal, Antigravity, Cursor, Sublime Merge, Chromium, Firefox
DOCK_APPS="'org.gnome.Nautilus.desktop', 'org.gnome.Terminal.desktop'"

# IDEs/Editors (in order: Antigravity, Cursor, VS Code, Sublime Merge)
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

# Browsers (in order: Chromium, Chrome, Firefox)
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
'

if [[ "${SHELL_TYPE}" == "zsh" ]]; then
    echo "${ALIASES_CONTENT}" >> "${HOME_DIR}/.zshrc"
else
    echo "${ALIASES_CONTENT}" >> "${HOME_DIR}/.bashrc"
fi

# Fix ownership of shell config files (may not exist depending on shell choice)
chown "${USERNAME}:${USERNAME}" "${HOME_DIR}/.zshrc" 2>/dev/null || true
chown "${USERNAME}:${USERNAME}" "${HOME_DIR}/.bashrc" 2>/dev/null || true

# ==============================================================================
# PACKER BUILD - Allow shutdown without password
# ==============================================================================
# This is needed for Packer's shutdown_command to work regardless of sudo_nopassword setting
# Only allows shutdown command, not all sudo commands (security: principle of least privilege)
echo "# Temporary: Allow shutdown for Packer build (added by provision.sh)" > /etc/sudoers.d/99-packer-shutdown
echo "${USERNAME} ALL=(ALL) NOPASSWD: /usr/sbin/shutdown" >> /etc/sudoers.d/99-packer-shutdown
echo "${USERNAME} ALL=(ALL) NOPASSWD: /sbin/shutdown" >> /etc/sudoers.d/99-packer-shutdown
chmod 440 /etc/sudoers.d/99-packer-shutdown

# Validate sudoers file to ensure it's correct
if ! visudo -c -f /etc/sudoers.d/99-packer-shutdown; then
    log_msg "ERROR: Invalid sudoers file created"
    rm -f /etc/sudoers.d/99-packer-shutdown
    exit 1
fi

log_success "Shutdown permissions configured for Packer build"

# ==============================================================================
# GNOME REMOTE DESKTOP (RDP nativo con modo sistema)
# ==============================================================================

log_section "10/10 Configurando GNOME Remote Desktop (modo sistema)..."

# Instalar gnome-remote-desktop, avahi (mDNS) y herramientas necesarias
# avahi-daemon permite resolver el hostname como hostname.local en la red local
apt-get install -y gnome-remote-desktop avahi-daemon xclip openssl

# El usuario gnome-remote-desktop se crea automáticamente al instalar el paquete
# Los certificados DEBEN estar en ~gnome-remote-desktop/.local/share/gnome-remote-desktop/
GRD_USER="gnome-remote-desktop"
GRD_DIR="/var/lib/gnome-remote-desktop/.local/share/gnome-remote-desktop"

# Crear directorio de certificados como usuario gnome-remote-desktop
log_task "Creando directorio para certificados TLS..."
sudo -u "${GRD_USER}" mkdir -p "${GRD_DIR}"

# Generar certificados TLS como usuario gnome-remote-desktop
# IMPORTANTE: El certificado DEBE tener Extended Key Usage con los OIDs correctos para mstsc.exe:
# - serverAuth (1.3.6.1.5.5.7.3.1) - Autenticación de servidor TLS estándar
# - Remote Desktop Authentication (1.3.6.1.4.1.311.54.1.2) - OID específico de Microsoft para RDP
# La validez debe ser <= 825 días o mstsc rechazará el certificado con error 0x907
log_task "Generando certificados TLS para RDP..."

# Crear archivo de configuración temporal para OpenSSL con las extensiones requeridas
# El CN debe coincidir con el hostname para que mstsc confíe en el certificado
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
# Incluir tanto serverAuth como el OID específico de Microsoft para Remote Desktop
extendedKeyUsage = serverAuth, 1.3.6.1.4.1.311.54.1.2
subjectKeyIdentifier = hash
# Subject Alternative Names para hostname y hostname.local
subjectAltName = DNS:${HOSTNAME}, DNS:${HOSTNAME}.local
OPENSSL_EOF

# Usar 365 días (bien por debajo del límite de 825 días de mstsc)
sudo -u "${GRD_USER}" openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 \
    -config "${OPENSSL_CONF_TMP}" \
    -out "${GRD_DIR}/tls.crt" \
    -keyout "${GRD_DIR}/tls.key" 2>/dev/null

# Limpiar archivo de configuración temporal
rm -f "${OPENSSL_CONF_TMP}"

log_success "Certificados TLS generados en ${GRD_DIR}"

# Configurar GNOME Remote Desktop en modo sistema
log_task "Configurando RDP en modo sistema..."

# Configurar certificados TLS (rutas relativas al usuario gnome-remote-desktop)
grdctl --system rdp set-tls-key "${GRD_DIR}/tls.key" || log_warning "Could not set TLS key"
grdctl --system rdp set-tls-cert "${GRD_DIR}/tls.crt" || log_warning "Could not set TLS cert"

# Configurar credenciales del sistema (argumentos directos, no stdin)
log_task "Configurando credenciales RDP..."
grdctl --system rdp set-credentials "${USERNAME}" "developer" || log_warning "Could not set system credentials"

# Habilitar RDP en modo sistema
grdctl --system rdp enable || log_warning "Could not enable system RDP"

# Verificar estado de la configuración
log_task "Verificando configuración..."
grdctl --system status 2>/dev/null || true

# Habilitar el servicio de GNOME Remote Desktop a nivel de sistema
systemctl enable gnome-remote-desktop.service
systemctl restart gnome-remote-desktop.service || true

# Configurar firewall para permitir RDP (puerto 3389) y mDNS (puerto 5353)
if command -v ufw >/dev/null 2>&1; then
    ufw allow 3389/tcp
    ufw allow 5353/udp  # mDNS/Avahi para resolución de hostname.local
fi

# Habilitar y arrancar Avahi para mDNS
systemctl enable avahi-daemon.service
systemctl start avahi-daemon.service || true

# Generar archivo .rdp preconfigurado para conexión fácil desde Windows
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
log_msg "NOTA: El hostname ${HOSTNAME}.local se resuelve via mDNS/Avahi"

# ==============================================================================
# FIN
# ==============================================================================

log_section "✓ Provisioning completado!"
log_msg ""
log_msg "Resumen:"
log_msg "  - Usuario: ${USERNAME}"
log_msg "  - Shell: ${SHELL_TYPE}"
log_msg "  - Prompt: ${PROMPT_THEME}"
log_msg "  - Docker: instalado"
log_msg "  - Portainer: ${INSTALL_PORTAINER}"
log_msg "  - VS Code: ${INSTALL_VSCODE}"
log_msg "  - Google Antigravity IDE: ${INSTALL_ANTIGRAVITY}"
log_msg "  - Navegador: ${INSTALL_BROWSER}"
log_msg "  - Nerd Font: ${NERD_FONT}"
log_msg "  - Red: ${NETWORK_MODE} - IP: $(hostname -I | awk '{print $1}')"
log_msg ""

# ==============================================================================
# WELCOME DOCUMENT
# ==============================================================================
log_section "Finalizando: Documento de bienvenida..."

# Guardar el HTML de bienvenida
WELCOME_FILE="${HOME_DIR}/welcome.html"
log_task "Creando ${WELCOME_FILE}..."
echo "${WELCOME_HTML}" > "${WELCOME_FILE}"
chown "${USERNAME}:${USERNAME}" "${WELCOME_FILE}"
chmod 644 "${WELCOME_FILE}"

# Crear lanzador para autostart (abrir en el browser predeterminado)
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
log_success "Documento de bienvenida configurado para abrirse al iniciar sesión."

log_msg "Detalles completos en: $PROVISION_LOG"

# Restore stdout/stderr
exec 1>&3 2>&4 3>&- 4>&-
