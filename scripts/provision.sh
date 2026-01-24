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
DESKTOP_THEME="${VM_DESKTOP_THEME}"
INSTALL_VSCODE="${VM_INSTALL_VSCODE}"
INSTALL_ANTIGRAVITY="${VM_INSTALL_ANTIGRAVITY}"
INSTALL_BROWSER="${VM_INSTALL_BROWSER}"

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

# Cambiar red de IP estática (usada para build) a DHCP (para uso normal)
log_task "Configurando red a DHCP..."

# Remove ALL old netplan configs to avoid warnings (permissions, deprecated gateway4, etc.)
rm -f /etc/netplan/*.yaml

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

# Set correct permissions to avoid netplan warnings
chmod 600 /etc/netplan/00-installer-config.yaml

netplan apply

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
    
    # Configurar VS Code
    VSCODE_DIR="${HOME_DIR}/.config/Code/User"
    mkdir -p "${VSCODE_DIR}"

    # Determine font family based on installed Nerd Font (if any)
    if [[ "${NERD_FONT}" != "none" ]]; then
        # Map font names to their VS Code font family names
        case "${NERD_FONT}" in
            "JetBrainsMono")
                VSCODE_FONT_FAMILY="'JetBrainsMono Nerd Font', 'JetBrains Mono', monospace"
                ;;
            "FiraCode")
                VSCODE_FONT_FAMILY="'FiraCode Nerd Font', 'Fira Code', monospace"
                ;;
            "Hack")
                VSCODE_FONT_FAMILY="'Hack Nerd Font', 'Hack', monospace"
                ;;
            "SourceCodePro")
                VSCODE_FONT_FAMILY="'SauceCodePro Nerd Font', 'Source Code Pro', monospace"
                ;;
            "Meslo")
                VSCODE_FONT_FAMILY="'MesloLGS NF', 'Meslo', monospace"
                ;;
            *)
                VSCODE_FONT_FAMILY="'${NERD_FONT} Nerd Font', monospace"
                ;;
        esac
    else
        # No Nerd Font installed, use system defaults
        VSCODE_FONT_FAMILY="'Fira Code', 'Consolas', monospace"
    fi

    cat > "${VSCODE_DIR}/settings.json" << EOF
{
    "editor.fontFamily": "${VSCODE_FONT_FAMILY}",
    "editor.fontSize": 14,
    "editor.fontLigatures": true,
    "editor.formatOnSave": true,
    "editor.minimap.enabled": false,
    "editor.bracketPairColorization.enabled": true,
    "workbench.colorTheme": "Default Dark Modern",
    "workbench.startupEditor": "none",
    "terminal.integrated.fontFamily": "${VSCODE_FONT_FAMILY}",
    "terminal.integrated.fontSize": 13,
    "files.autoSave": "afterDelay",
    "files.trimTrailingWhitespace": true,
    "git.autofetch": true,
    "git.confirmSync": false,
    "docker.showStartPage": false,
    "telemetry.telemetryLevel": "off"
}
EOF

    # Fix ownership so user can install extensions
    chown -R "${USERNAME}:${USERNAME}" "${HOME_DIR}/.config/Code"

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
DOCK_APPS="'org.gnome.Nautilus.desktop', 'org.gnome.Terminal.desktop'"
if [[ "${INSTALL_VSCODE}" == "true" ]]; then
    DOCK_APPS="\${DOCK_APPS}, 'code.desktop'"
fi
case "${INSTALL_BROWSER}" in
    "firefox")
        DOCK_APPS="\${DOCK_APPS}, 'firefox.desktop'"
        ;;
    "chrome")
        DOCK_APPS="\${DOCK_APPS}, 'google-chrome.desktop'"
        ;;
    "chromium")
        DOCK_APPS="\${DOCK_APPS}, 'chromium.desktop'"
        ;;
esac
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
# HYPER-V ENHANCED SESSION MODE (RDP para portapapeles compartido)
# ==============================================================================

log_section "10/10 Configurando Enhanced Session Mode (xrdp)..."

# Instalar xrdp para habilitar Enhanced Session Mode
apt-get install -y xrdp xorgxrdp

# Configurar xrdp para usar el desktop environment correcto
cat > /etc/xrdp/startwm.sh << 'XRDP_EOF'
#!/bin/sh
if [ -r /etc/default/locale ]; then
  . /etc/default/locale
  export LANG LANGUAGE
fi
# Start Ubuntu desktop session
exec /usr/bin/gnome-session
XRDP_EOF

chmod +x /etc/xrdp/startwm.sh

# Añadir usuario al grupo ssl-cert (necesario para xrdp)
usermod -a -G ssl-cert "${USERNAME}"

# Habilitar y arrancar xrdp
systemctl enable xrdp
systemctl start xrdp

# Configurar firewall para permitir RDP (puerto 3389)
if command -v ufw >/dev/null 2>&1; then
    ufw allow 3389/tcp
fi

log_success "Enhanced Session Mode configurado (RDP en puerto 3389)"
log_msg "  Ahora puedes usar portapapeles compartido con el host"

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
log_msg "  - VS Code: ${INSTALL_VSCODE}"
log_msg "  - Google Antigravity IDE: ${INSTALL_ANTIGRAVITY}"
log_msg "  - Navegador: ${INSTALL_BROWSER}"
log_msg "  - Nerd Font: ${NERD_FONT}"
log_msg ""
log_msg "Detalles completos en: $PROVISION_LOG"

# Restore stdout/stderr
exec 1>&3 2>&4 3>&- 4>&-
