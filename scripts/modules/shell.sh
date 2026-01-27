#!/bin/bash
# ==============================================================================
# SHELL.SH - Configuración de shell y prompt
# ==============================================================================
# Configura: bash/zsh, Oh My Zsh, Oh My Bash, Starship
# Requiere: common.sh
# ==============================================================================

install_shell_config() {
    log_section "Configurando shell (${SHELL_TYPE}) y prompt (${PROMPT_THEME})..."

    # -------------------------------------------------------------------------
    # Instalar Zsh si es necesario
    # -------------------------------------------------------------------------
    if [[ "${SHELL_TYPE}" == "zsh" ]]; then
        apt-get install -y zsh
        chsh -s /bin/zsh "${USERNAME}"
    fi

    # -------------------------------------------------------------------------
    # Instalar tema de prompt
    # -------------------------------------------------------------------------
    case "${PROMPT_THEME}" in
        "ohmyzsh")
            if [[ "${SHELL_TYPE}" != "zsh" ]]; then
                log_msg "ERROR: Oh My Zsh requiere shell=zsh"
                exit 1
            fi

            OMZSH_SCRIPT="/tmp/omzsh-install.sh"
            if download_and_verify_script "https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh" "$OMZSH_SCRIPT" "Oh My Zsh installer"; then
                run_as_user "sh ${OMZSH_SCRIPT} --unattended"
                rm -f "$OMZSH_SCRIPT"
            else
                log_msg "ERROR: Failed to install Oh My Zsh"
                exit 1
            fi

            OHMYZSH_THEME_ESCAPED=$(printf '%s\n' "${OHMYZSH_THEME}" | sed 's/[\/&]/\\&/g')
            sed -i "s/^ZSH_THEME=\".*\"/ZSH_THEME=\"${OHMYZSH_THEME_ESCAPED}\"/" "${HOME_DIR}/.zshrc"

            PLUGINS_FORMATTED=$(echo "${OHMYZSH_PLUGINS}" | tr ',' ' ')
            PLUGINS_ESCAPED=$(printf '%s\n' "${PLUGINS_FORMATTED}" | sed 's/[\/&]/\\&/g')
            sed -i "s/^plugins=(.*)/plugins=(${PLUGINS_ESCAPED})/" "${HOME_DIR}/.zshrc"

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

            OMBSH_SCRIPT="/tmp/ombash-install.sh"
            if download_and_verify_script "https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh" "$OMBSH_SCRIPT" "Oh My Bash installer"; then
                run_as_user "bash ${OMBSH_SCRIPT} --unattended"
                rm -f "$OMBSH_SCRIPT"
            else
                log_msg "ERROR: Failed to install Oh My Bash"
                exit 1
            fi

            OHMYBASH_THEME_ESCAPED=$(printf '%s\n' "${OHMYBASH_THEME}" | sed 's/[\/&]/\\&/g')
            sed -i "s/^OSH_THEME=\".*\"/OSH_THEME=\"${OHMYBASH_THEME_ESCAPED}\"/" "${HOME_DIR}/.bashrc"
            ;;

        "starship")
            STARSHIP_SCRIPT="/tmp/starship-install.sh"
            if download_and_verify_script "https://starship.rs/install.sh" "$STARSHIP_SCRIPT" "Starship installer"; then
                sh "$STARSHIP_SCRIPT" -y
                rm -f "$STARSHIP_SCRIPT"
            else
                log_msg "ERROR: Failed to install Starship"
                exit 1
            fi

            if ! mkdir -p "${HOME_DIR}/.config"; then
                log_msg "ERROR: Failed to create .config directory"
                exit 1
            fi
            if [[ "${STARSHIP_PRESET}" != "none" && "${STARSHIP_PRESET}" != "" ]]; then
                if ! starship preset "${STARSHIP_PRESET}" -o "${HOME_DIR}/.config/starship.toml" 2>/dev/null; then
                    log_warning "Failed to apply starship preset '${STARSHIP_PRESET}', using default config"
                fi
            fi

            if [[ "${SHELL_TYPE}" == "zsh" ]]; then
                echo 'eval "$(starship init zsh)"' >> "${HOME_DIR}/.zshrc"
            else
                echo 'eval "$(starship init bash)"' >> "${HOME_DIR}/.bashrc"
            fi
            ;;

        "none")
            log_task "Sin tema de prompt, usando defaults."
            ;;
    esac

    log_success "Shell y prompt configurados"
}

# Ejecutar
install_shell_config
