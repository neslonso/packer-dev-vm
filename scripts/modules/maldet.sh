#!/bin/bash
# ==============================================================================
# MALDET.SH - Instalación y configuración de Linux Malware Detect
# ==============================================================================
# Instala maldet (LMD) y configura escaneo diario a las 20:00h
# Requiere: common.sh
# ==============================================================================

install_maldet() {
    log_section "Instalando Linux Malware Detect (maldet)..."

    local maldet_version="1.6.5"
    local maldet_url="https://www.rfxn.com/downloads/maldetect-${maldet_version}.tar.gz"
    local temp_dir="/tmp/maldet_install"

    # -------------------------------------------------------------------------
    # Instalar dependencias
    # -------------------------------------------------------------------------
    log_task "Instalando dependencias..."
    apt-get install -y inotify-tools wget ed

    # -------------------------------------------------------------------------
    # Descargar maldet
    # -------------------------------------------------------------------------
    log_task "Descargando maldet ${maldet_version}..."
    mkdir -p "$temp_dir"
    cd "$temp_dir"

    if ! curl --max-time 60 --fail --silent --show-error --location "$maldet_url" -o maldetect.tar.gz; then
        log_error "Error descargando maldet"
        return 1
    fi

    # -------------------------------------------------------------------------
    # Extraer e instalar
    # -------------------------------------------------------------------------
    log_task "Instalando maldet..."
    tar -xzf maldetect.tar.gz
    cd maldetect-${maldet_version}

    # Ejecutar instalador
    ./install.sh

    # -------------------------------------------------------------------------
    # Configurar maldet
    # -------------------------------------------------------------------------
    log_task "Configurando maldet..."

    local conf_file="/usr/local/maldetect/conf.maldet"

    if [[ -f "$conf_file" ]]; then
        # Habilitar cuarentena de archivos infectados
        sed -i 's/quarantine_hits="0"/quarantine_hits="1"/' "$conf_file"

        # Habilitar limpieza de malware
        sed -i 's/quarantine_clean="0"/quarantine_clean="1"/' "$conf_file"

        # Habilitar alertas por email (si se configura)
        sed -i 's/email_alert="0"/email_alert="1"/' "$conf_file"

        # Escanear archivos ocultos
        sed -i 's/scan_ignore_root="1"/scan_ignore_root="0"/' "$conf_file"

        log_success "Configuración de maldet actualizada"
    else
        log_warning "Archivo de configuración no encontrado: $conf_file"
    fi

    # -------------------------------------------------------------------------
    # Actualizar firmas
    # -------------------------------------------------------------------------
    log_task "Actualizando firmas de malware..."
    maldet --update-sigs || log_warning "No se pudieron actualizar las firmas (puede requerir conexión)"
    maldet --update || log_warning "No se pudo actualizar maldet"

    # -------------------------------------------------------------------------
    # Configurar escaneo diario a las 20:00h
    # -------------------------------------------------------------------------
    log_task "Configurando escaneo diario a las 20:00h..."

    # Crear script de escaneo
    cat > /usr/local/bin/maldet-daily-scan.sh << 'EOF'
#!/bin/bash
# ==============================================================================
# Escaneo diario de maldet
# ==============================================================================
LOG_FILE="/var/log/maldet-daily-$(date +%Y%m%d).log"

echo "=== Escaneo maldet iniciado: $(date) ===" >> "$LOG_FILE"

# Escanear directorios importantes
maldet --scan-all /home >> "$LOG_FILE" 2>&1
maldet --scan-all /tmp >> "$LOG_FILE" 2>&1
maldet --scan-all /var/tmp >> "$LOG_FILE" 2>&1

echo "=== Escaneo maldet completado: $(date) ===" >> "$LOG_FILE"

# Limpiar logs antiguos (más de 30 días)
find /var/log -name "maldet-daily-*.log" -mtime +30 -delete 2>/dev/null
EOF

    chmod +x /usr/local/bin/maldet-daily-scan.sh

    # Crear cron job para las 20:00h
    cat > /etc/cron.d/maldet-daily << 'EOF'
# Escaneo diario de maldet a las 20:00h
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

0 20 * * * root /usr/local/bin/maldet-daily-scan.sh
EOF

    chmod 644 /etc/cron.d/maldet-daily

    log_success "Cron job configurado: escaneo diario a las 20:00h"

    # -------------------------------------------------------------------------
    # Limpieza
    # -------------------------------------------------------------------------
    log_task "Limpiando archivos temporales..."
    rm -rf "$temp_dir"

    # -------------------------------------------------------------------------
    # Verificar instalación
    # -------------------------------------------------------------------------
    # maldet puede instalarse en diferentes ubicaciones
    local maldet_bin=""
    for path in /usr/local/sbin/maldet /usr/local/maldetect/maldet /usr/sbin/maldet; do
        if [[ -x "$path" ]]; then
            maldet_bin="$path"
            break
        fi
    done

    if [[ -n "$maldet_bin" ]]; then
        local installed_version
        installed_version=$("$maldet_bin" --version 2>&1 | head -1)
        log_success "maldet instalado correctamente: $installed_version"
        log_task "  Ubicación: $maldet_bin"
    else
        log_error "maldet no se instaló correctamente (no encontrado en rutas conocidas)"
        return 1
    fi

    log_success "Linux Malware Detect configurado correctamente"
    log_msg ""
    log_msg "  Comandos útiles:"
    log_msg "    maldet --scan-all /path    # Escanear directorio"
    log_msg "    maldet --report list       # Ver reportes"
    log_msg "    maldet --quarantine SCANID # Cuarentena de escaneo"
    log_msg ""
    log_msg "  Logs de escaneo diario: /var/log/maldet-daily-*.log"
    log_msg "  Escaneo programado: todos los días a las 20:00h"
    log_msg ""
}

# Ejecutar
install_maldet
