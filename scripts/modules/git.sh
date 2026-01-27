#!/bin/bash
# ==============================================================================
# GIT.SH - Configuración de Git y herramientas relacionadas
# ==============================================================================
# Instala: lazygit, GitHub CLI. Configura: git global settings
# Requiere: common.sh
# ==============================================================================

install_git_tools() {
    log_section "Configurando Git..."

    # -------------------------------------------------------------------------
    # lazygit
    # -------------------------------------------------------------------------
    LAZYGIT_VERSION=$(curl --max-time 30 --fail --silent --show-error https://api.github.com/repos/jesseduffield/lazygit/releases/latest 2>/dev/null | jq -r '.tag_name' 2>/dev/null || echo "")

    if [[ -z "$LAZYGIT_VERSION" || "$LAZYGIT_VERSION" == "null" ]]; then
        log_warning "Failed to fetch lazygit latest version from GitHub API, using fallback"
        LAZYGIT_VERSION="v0.40.2"
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

    # -------------------------------------------------------------------------
    # GitHub CLI
    # -------------------------------------------------------------------------
    if ! download_and_verify_gpg_key "https://cli.github.com/packages/githubcli-archive-keyring.gpg" "/usr/share/keyrings/githubcli-archive-keyring.gpg" "$GITHUB_CLI_GPG_FINGERPRINT" "GitHub CLI GPG key"; then
        log_msg "ERROR: Failed to verify GitHub CLI GPG key"
        exit 1
    fi
    chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list
    apt-get update
    apt-get install -y gh

    # -------------------------------------------------------------------------
    # Configurar Git para el usuario
    # -------------------------------------------------------------------------
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
    run_as_user "git config --global core.autocrlf input"
    run_as_user "git config --global core.filemode false"
    run_as_user "git config --global fetch.prune true"
    run_as_user "git config --global diff.colorMoved zebra"
    run_as_user "git config --global rerere.enabled true"
    run_as_user "git config --global help.autocorrect 10"

    log_success "Git configurado"
}

# Ejecutar
install_git_tools
