#!/bin/bash
# ==============================================================================
# COMMON.SH - Funciones compartidas y configuración base
# ==============================================================================
# Este módulo debe ser sourced primero por todos los orquestadores.
# Proporciona: logging, variables de entorno, funciones auxiliares.
# ==============================================================================

set -euo pipefail

# Force unbuffered output
export PYTHONUNBUFFERED=1
stty -echo 2>/dev/null || true

# ==============================================================================
# VARIABLES (desde entorno VM_*)
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

log_section() {
    local msg="$1"
    log_msg ""
    log_msg "╔══════════════════════════════════════════════════════════════╗"
    log_msg "║ $msg"
    log_msg "╚══════════════════════════════════════════════════════════════╝"
}

log_task() {
    local msg="$1"
    log_msg "→ $msg"
}

log_success() {
    local msg="$1"
    log_msg "✓ $msg"
}

log_warning() {
    local msg="$1"
    log_msg "⚠ $msg"
}

log_error() {
    local msg="$1"
    log_msg "✗ $msg"
}

# ==============================================================================
# FUNCIONES AUXILIARES
# ==============================================================================

# Escape string for safe use in shell commands
shell_escape() {
    local str="$1"
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

    if ! curl --max-time 60 --fail --silent --show-error --location "$url" -o "$temp_file"; then
        log_msg "ERROR: Failed to download ${description} from ${url}"
        return 1
    fi

    if [[ ! -s "$temp_file" ]]; then
        log_msg "ERROR: Downloaded ${description} is empty"
        rm -f "$temp_file"
        return 1
    fi

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

    if tar -tzf "$archive" 2>/dev/null | grep -E '(^|/)\.\.(\/|$)' > /dev/null; then
        log_msg "ERROR: ${description} contains dangerous path traversal sequences (..)"
        return 1
    fi

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

    if unzip -Z -1 "$archive" 2>/dev/null | grep -E '(^|/)\.\.(\/|$)' > /dev/null; then
        log_msg "ERROR: ${description} contains dangerous path traversal sequences (..)"
        return 1
    fi

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

    local temp_key="/tmp/gpg-key-$$.asc"
    if ! curl --max-time 30 --fail --silent --show-error --location "$url" -o "$temp_key"; then
        log_msg "ERROR: Failed to download ${description}"
        return 1
    fi

    local temp_keyring="/tmp/keyring-$$"
    mkdir -p "$temp_keyring"
    chmod 700 "$temp_keyring"

    local import_output
    import_output=$(gpg --no-default-keyring --keyring "$temp_keyring/temp.gpg" --import "$temp_key" 2>&1)

    local actual_fingerprint=""
    actual_fingerprint=$(echo "$import_output" | grep -oP '[0-9A-F]{40}' | head -1)

    if [[ -z "$actual_fingerprint" ]]; then
        actual_fingerprint=$(echo "$import_output" | grep -i 'fingerprint' | grep -oP '[0-9A-F]{4}(\s+[0-9A-F]{4}){9}' | head -1 | tr -d ' ')
    fi

    if [[ -z "$actual_fingerprint" ]]; then
        actual_fingerprint=$(gpg --no-default-keyring --keyring "$temp_keyring/temp.gpg" --fingerprint --with-colons 2>/dev/null | grep '^fpr:' | head -1 | cut -d: -f10)
    fi

    if [[ -z "$actual_fingerprint" ]]; then
        local key_id=$(echo "$import_output" | grep -oP 'key [0-9A-F]+' | head -1 | awk '{print $2}')
        if [[ -n "$key_id" ]]; then
            actual_fingerprint=$(gpg --no-default-keyring --keyring "$temp_keyring/temp.gpg" --list-keys --with-colons "$key_id" 2>/dev/null | grep '^fpr:' | head -1 | cut -d: -f10)
        fi
    fi

    if [[ -n "$actual_fingerprint" ]]; then
        actual_fingerprint=$(echo "$actual_fingerprint" | tr -d ' ')
        actual_fingerprint=$(echo "$actual_fingerprint" | sed 's/.\{4\}/& /g' | xargs)
    fi

    rm -rf "$temp_keyring"

    local expected_norm="${expected_fingerprint// /}"
    local actual_norm="${actual_fingerprint// /}"

    if [[ "$actual_norm" != "$expected_norm" ]]; then
        log_msg "ERROR: ${description} fingerprint mismatch!"
        log_msg "  Expected: ${expected_fingerprint}"
        log_msg "  Got:      ${actual_fingerprint}"
        rm -f "$temp_key"
        return 1
    fi

    log_success "${description} fingerprint verified: ${actual_fingerprint}"

    gpg --dearmor < "$temp_key" > "$output_file"
    rm -f "$temp_key"

    return 0
}

# ==============================================================================
# GLOBAL FONT FAMILY (usado por editores)
# ==============================================================================
determine_global_font_family() {
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
    export GLOBAL_FONT_FAMILY
}

# Function to apply VS Code-based editor settings (used by vscode, cursor, antigravity)
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

# Initialize font family on load
determine_global_font_family
