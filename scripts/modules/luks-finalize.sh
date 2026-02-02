#!/bin/bash
# ==============================================================================
# LUKS-FINALIZE.SH - Finaliza configuración LUKS eliminando auto-unlock
# ==============================================================================
# Este módulo elimina el keyfile de auto-unlock para que el próximo arranque
# requiera introducir la contraseña LUKS manualmente.
#
# IMPORTANTE: Este módulo debe ejecutarse como ÚLTIMO paso del provisioning.
# Requiere: common.sh
# ==============================================================================

finalize_luks_encryption() {
    if [[ "${DISK_ENCRYPTION_ENABLED}" != "true" ]]; then
        log_task "Cifrado de disco no habilitado, omitiendo finalización LUKS"
        return 0
    fi

    log_section "Finalizando configuración LUKS..."

    local keyfile="/etc/cryptsetup-keys.d/luks-keyfile"
    local crypttab="/etc/crypttab"

    # -------------------------------------------------------------------------
    # Verificar que existe el keyfile
    # -------------------------------------------------------------------------
    if [[ ! -f "$keyfile" ]]; then
        log_warning "Keyfile no encontrado en $keyfile - puede que LUKS no esté configurado correctamente"
        return 0
    fi

    # -------------------------------------------------------------------------
    # Encontrar el dispositivo LUKS
    # -------------------------------------------------------------------------
    log_task "Buscando dispositivo LUKS..."
    local luks_dev
    luks_dev=$(blkid -t TYPE=crypto_LUKS -o device | head -1)

    if [[ -z "$luks_dev" ]]; then
        log_error "No se encontró dispositivo LUKS"
        return 1
    fi

    log_success "Dispositivo LUKS encontrado: $luks_dev"

    # -------------------------------------------------------------------------
    # Eliminar el keyfile de LUKS (slot)
    # -------------------------------------------------------------------------
    log_task "Eliminando keyfile de los slots LUKS..."

    # Primero verificamos cuántos slots hay ocupados
    local slots_before
    slots_before=$(cryptsetup luksDump "$luks_dev" | grep -c "ENABLED")
    log_task "  Slots LUKS activos antes: $slots_before"

    # El keyfile debería estar en slot 1 (slot 0 es el password original)
    # Intentamos eliminar usando el propio keyfile para autenticarnos
    if cryptsetup luksRemoveKey "$luks_dev" "$keyfile" 2>/dev/null; then
        log_success "  Keyfile eliminado de LUKS correctamente"
    else
        log_warning "  No se pudo eliminar el keyfile de LUKS (puede que ya esté eliminado)"
    fi

    local slots_after
    slots_after=$(cryptsetup luksDump "$luks_dev" | grep -c "ENABLED")
    log_task "  Slots LUKS activos después: $slots_after"

    # -------------------------------------------------------------------------
    # Restaurar crypttab para pedir password
    # -------------------------------------------------------------------------
    log_task "Restaurando crypttab para requerir password..."

    if [[ -f "$crypttab" ]]; then
        # Reemplazar la ruta del keyfile con 'none' para pedir password
        sed -i "s|/etc/cryptsetup-keys.d/luks-keyfile|none|g" "$crypttab"
        log_success "  crypttab actualizado"
        log_task "  Contenido actual de crypttab:"
        cat "$crypttab" | while read line; do
            log_msg "    $line"
        done
    else
        log_warning "  crypttab no encontrado"
    fi

    # -------------------------------------------------------------------------
    # Eliminar el keyfile del sistema de archivos
    # -------------------------------------------------------------------------
    log_task "Eliminando keyfile del sistema de archivos..."

    # Sobrescribir con datos aleatorios antes de eliminar (secure delete)
    if [[ -f "$keyfile" ]]; then
        dd if=/dev/urandom of="$keyfile" bs=4096 count=1 conv=notrunc 2>/dev/null
        sync
        rm -f "$keyfile"
        log_success "  Keyfile eliminado de forma segura"
    fi

    # Eliminar directorio si está vacío
    rmdir /etc/cryptsetup-keys.d 2>/dev/null || true

    # -------------------------------------------------------------------------
    # Regenerar initramfs sin el keyfile
    # -------------------------------------------------------------------------
    log_task "Regenerando initramfs..."
    update-initramfs -u -k all
    log_success "  initramfs regenerado"

    # -------------------------------------------------------------------------
    # Resumen final
    # -------------------------------------------------------------------------
    log_success "Configuración LUKS finalizada"
    log_msg ""
    log_msg "  ╔════════════════════════════════════════════════════════════╗"
    log_msg "  ║  IMPORTANTE: En el próximo arranque se pedirá la           ║"
    log_msg "  ║  contraseña LUKS para desbloquear el disco.                ║"
    log_msg "  ║                                                            ║"
    log_msg "  ║  Sin esta contraseña, los datos son IRRECUPERABLES.        ║"
    log_msg "  ╚════════════════════════════════════════════════════════════╝"
    log_msg ""
}

# Ejecutar
finalize_luks_encryption
