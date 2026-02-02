#!/bin/bash
# ==============================================================================
# CUSTOM-COMMANDS.SH - Ejecucion de comandos personalizados post-provisioning
# ==============================================================================
# Ejecuta una lista de comandos definidos por el usuario al final del
# provisioning. Los comandos se ejecutan como el usuario normal (no root).
# Requiere: common.sh
#
# NOTA: Las claves SSH con passphrase NO funcionarán automáticamente.
#       Use claves sin passphrase para el provisioning automatizado.
# ==============================================================================

run_custom_commands() {
    log_section "Ejecutando comandos personalizados..."

    if [[ -z "${POST_PROVISION_COMMANDS_JSON:-}" ]]; then
        log_task "No hay comandos personalizados configurados"
        return 0
    fi

    # Decodificar JSON de base64
    local json_data
    json_data=$(echo "${POST_PROVISION_COMMANDS_JSON}" | base64 -d 2>/dev/null || echo "[]")

    # Verificar si hay comandos
    local cmd_count
    cmd_count=$(echo "$json_data" | jq -r 'length' 2>/dev/null || echo "0")

    if [[ "$cmd_count" -eq 0 ]]; then
        log_task "No hay comandos personalizados configurados"
        return 0
    fi

    log_task "Ejecutando ${cmd_count} comando(s) personalizado(s)..."

    # -------------------------------------------------------------------------
    # Preparar SSH agent para comandos que necesiten SSH (git clone, etc.)
    # -------------------------------------------------------------------------
    log_task "Iniciando SSH agent para comandos..."

    # Crear script temporal que inicia SSH agent, añade claves y ejecuta comando
    local ssh_wrapper="/tmp/ssh-cmd-wrapper.sh"
    cat > "$ssh_wrapper" << 'WRAPPER_EOF'
#!/bin/bash
# Iniciar SSH agent
eval "$(ssh-agent -s)" > /dev/null 2>&1

# Añadir todas las claves privadas de ~/.ssh (sin passphrase)
for key in ~/.ssh/id_* ~/.ssh/*_key; do
    if [[ -f "$key" && ! "$key" =~ \.pub$ ]]; then
        # Intentar añadir (fallará silenciosamente si tiene passphrase)
        ssh-add "$key" 2>/dev/null || true
    fi
done

# Ejecutar el comando pasado como argumento
eval "$1"
exit_code=$?

# Matar el agent
ssh-agent -k > /dev/null 2>&1

exit $exit_code
WRAPPER_EOF
    chmod +x "$ssh_wrapper"
    chown "${USERNAME}:${USERNAME}" "$ssh_wrapper"

    local failed_commands=0

    # Iterar sobre cada comando
    for i in $(seq 0 $((cmd_count - 1))); do
        local cmd
        cmd=$(echo "$json_data" | jq -r ".[$i]" 2>/dev/null)

        if [[ -n "$cmd" && "$cmd" != "null" ]]; then
            log_task "  [$(($i + 1))/${cmd_count}] Ejecutando: ${cmd}"

            # Ejecutar el comando con el wrapper de SSH
            if run_as_user "$ssh_wrapper '$cmd'"; then
                log_success "  Comando completado exitosamente"
            else
                log_warning "  Comando fallo (codigo de salida: $?)"
                ((failed_commands++))
            fi
        fi
    done

    # Limpiar
    rm -f "$ssh_wrapper"

    if [[ $failed_commands -gt 0 ]]; then
        log_warning "${failed_commands} comando(s) fallaron"
    else
        log_success "Todos los comandos personalizados ejecutados correctamente"
    fi
}

# Ejecutar si se llama directamente o si se sourcea
run_custom_commands
