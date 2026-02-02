#!/bin/bash
# ==============================================================================
# SSH-AGENT.SH - Configuracion de claves SSH y agente SSH
# ==============================================================================
# Instala claves SSH y configura el agente SSH en .bashrc/.zshrc
# Requiere: common.sh
# ==============================================================================

install_ssh_keys_and_agent() {
    log_section "Configurando SSH keys y agente..."

    local ssh_dir="${HOME_DIR}/.ssh"

    # -------------------------------------------------------------------------
    # Crear directorio .ssh si no existe
    # -------------------------------------------------------------------------
    if [[ ! -d "$ssh_dir" ]]; then
        log_task "Creando directorio .ssh..."
        mkdir -p "$ssh_dir"
        chmod 700 "$ssh_dir"
        chown "${USERNAME}:${USERNAME}" "$ssh_dir"
    fi

    # -------------------------------------------------------------------------
    # Instalar claves SSH desde la configuracion
    # -------------------------------------------------------------------------
    local key_names=()

    if [[ -n "${SSH_KEY_PAIRS_JSON:-}" ]]; then
        log_task "Procesando claves SSH..."

        # Decodificar JSON de base64
        local json_data
        json_data=$(echo "${SSH_KEY_PAIRS_JSON}" | base64 -d 2>/dev/null || echo "[]")

        # Verificar si hay claves
        local key_count
        key_count=$(echo "$json_data" | jq -r 'length' 2>/dev/null || echo "0")

        if [[ "$key_count" -gt 0 ]]; then
            log_task "Instalando ${key_count} par(es) de claves SSH..."

            # Iterar sobre cada clave
            for i in $(seq 0 $((key_count - 1))); do
                local key_name
                local private_key
                local public_key

                key_name=$(echo "$json_data" | jq -r ".[$i].name" 2>/dev/null)
                private_key=$(echo "$json_data" | jq -r ".[$i].private_key" 2>/dev/null)
                public_key=$(echo "$json_data" | jq -r ".[$i].public_key" 2>/dev/null)

                if [[ -n "$key_name" && "$key_name" != "null" ]]; then
                    log_task "  Instalando clave: ${key_name}..."

                    # Escribir clave privada
                    if [[ -n "$private_key" && "$private_key" != "null" ]]; then
                        printf '%s\n' "$private_key" > "${ssh_dir}/${key_name}"
                        chmod 600 "${ssh_dir}/${key_name}"
                        chown "${USERNAME}:${USERNAME}" "${ssh_dir}/${key_name}"
                        key_names+=("${key_name}")
                    fi

                    # Escribir clave publica
                    if [[ -n "$public_key" && "$public_key" != "null" ]]; then
                        printf '%s\n' "$public_key" > "${ssh_dir}/${key_name}.pub"
                        chmod 644 "${ssh_dir}/${key_name}.pub"
                        chown "${USERNAME}:${USERNAME}" "${ssh_dir}/${key_name}.pub"
                    fi

                    log_success "  Clave ${key_name} instalada"
                fi
            done
        else
            log_task "No hay claves SSH configuradas"
        fi
    else
        log_task "No hay claves SSH configuradas"
    fi

    # -------------------------------------------------------------------------
    # Configurar SSH agent en shell rc file
    # -------------------------------------------------------------------------
    log_task "Configurando SSH agent en shell..."

    local rc_file
    if [[ "${SHELL_TYPE}" == "zsh" ]]; then
        rc_file="${HOME_DIR}/.zshrc"
    else
        rc_file="${HOME_DIR}/.bashrc"
    fi

    # Crear el bloque de configuracion del SSH agent
    local ssh_agent_config
    ssh_agent_config=$(cat << 'SSHAGENT_EOF'

# ==============================================================================
# SSH Agent Configuration
# ==============================================================================
# Start ssh-agent if not running
if [ -z "$SSH_AUTH_SOCK" ]; then
    # Check for existing agent
    if [ -f ~/.ssh/agent.env ]; then
        . ~/.ssh/agent.env > /dev/null
        if ! kill -0 "$SSH_AGENT_PID" 2>/dev/null; then
            # Agent is dead, start new one
            eval "$(ssh-agent -s)" > /dev/null
            echo "export SSH_AUTH_SOCK=$SSH_AUTH_SOCK" > ~/.ssh/agent.env
            echo "export SSH_AGENT_PID=$SSH_AGENT_PID" >> ~/.ssh/agent.env
        fi
    else
        # No agent file, start new one
        eval "$(ssh-agent -s)" > /dev/null
        mkdir -p ~/.ssh
        echo "export SSH_AUTH_SOCK=$SSH_AUTH_SOCK" > ~/.ssh/agent.env
        echo "export SSH_AGENT_PID=$SSH_AGENT_PID" >> ~/.ssh/agent.env
    fi
fi

# Add SSH keys to agent (if not already added)
SSHAGENT_EOF
)

    # Agregar comandos para cada clave
    if [[ ${#key_names[@]} -gt 0 ]]; then
        for key_name in "${key_names[@]}"; do
            ssh_agent_config+="
if [ -f ~/.ssh/${key_name} ]; then
    ssh-add -l 2>/dev/null | grep -q \"\$(ssh-keygen -lf ~/.ssh/${key_name} 2>/dev/null | awk '{print \$2}')\" || ssh-add ~/.ssh/${key_name}
fi"
        done
    else
        # Si no hay claves especificas, agregar id_rsa y id_ed25519 por defecto
        ssh_agent_config+='
# Add default keys if they exist
for key in ~/.ssh/id_rsa ~/.ssh/id_ed25519 ~/.ssh/id_ecdsa; do
    if [ -f "$key" ]; then
        ssh-add -l 2>/dev/null | grep -q "$(ssh-keygen -lf "$key" 2>/dev/null | awk '"'"'{print $2}'"'"')" || ssh-add "$key"
    fi
done'
    fi

    ssh_agent_config+='
# ==============================================================================
'

    # Agregar al archivo rc
    echo "$ssh_agent_config" >> "$rc_file"
    chown "${USERNAME}:${USERNAME}" "$rc_file"

    log_success "SSH agent configurado en ${rc_file}"

    # -------------------------------------------------------------------------
    # Crear archivo known_hosts con hosts comunes
    # -------------------------------------------------------------------------
    log_task "Configurando known_hosts..."

    local known_hosts="${ssh_dir}/known_hosts"
    touch "$known_hosts"
    chmod 644 "$known_hosts"
    chown "${USERNAME}:${USERNAME}" "$known_hosts"

    # Agregar fingerprints de hosts conocidos (GitHub, GitLab, Bitbucket)
    # Usando ssh-keyscan para obtener las claves reales
    {
        ssh-keyscan -t ed25519,rsa,ecdsa github.com 2>/dev/null || true
        ssh-keyscan -t ed25519,rsa,ecdsa gitlab.com 2>/dev/null || true
        ssh-keyscan -t ed25519,rsa,ecdsa bitbucket.org 2>/dev/null || true
    } >> "$known_hosts"

    log_success "known_hosts configurado con GitHub, GitLab y Bitbucket"

    log_success "SSH configurado correctamente"
}

# Ejecutar si se llama directamente o si se sourcea
install_ssh_keys_and_agent
