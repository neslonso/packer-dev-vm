#!/bin/bash
# ==============================================================================
# CUSTOM-COMMANDS.SH - Ejecucion de comandos personalizados post-provisioning
# ==============================================================================
# Ejecuta una lista de comandos definidos por el usuario al final del
# provisioning. Los comandos se ejecutan como el usuario normal (no root).
# Requiere: common.sh
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

    local failed_commands=0

    # Iterar sobre cada comando
    for i in $(seq 0 $((cmd_count - 1))); do
        local cmd
        cmd=$(echo "$json_data" | jq -r ".[$i]" 2>/dev/null)

        if [[ -n "$cmd" && "$cmd" != "null" ]]; then
            log_task "  [$(($i + 1))/${cmd_count}] Ejecutando: ${cmd}"

            # Ejecutar el comando como usuario normal
            # Usamos bash -l para cargar el entorno completo (incluyendo SSH agent)
            if run_as_user "bash -l -c '$cmd'"; then
                log_success "  Comando completado exitosamente"
            else
                log_warning "  Comando fallo (codigo de salida: $?)"
                ((failed_commands++))
            fi
        fi
    done

    if [[ $failed_commands -gt 0 ]]; then
        log_warning "${failed_commands} comando(s) fallaron"
    else
        log_success "Todos los comandos personalizados ejecutados correctamente"
    fi
}

# Ejecutar si se llama directamente o si se sourcea
run_custom_commands
