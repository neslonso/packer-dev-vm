#!/bin/bash
# ==============================================================================
# MESSAGING.SH - Instalación de aplicaciones de mensajería
# ==============================================================================
# Instala: Slack, Signal, Telegram según configuración
# Requiere: common.sh
# ==============================================================================

install_messaging() {
    # Si es "none", salir inmediatamente
    if [[ "${INSTALL_MESSAGING}" == "none" ]]; then
        log_task "Sin aplicaciones de mensajería."
        return 0
    fi

    # Si es "all", expandir a todas las apps soportadas
    local apps_to_install="${INSTALL_MESSAGING}"
    if [[ "${INSTALL_MESSAGING}" == "all" ]]; then
        apps_to_install="slack,signal,telegram"
    fi

    log_section "Configurando mensajería: ${apps_to_install}..."

    # Iterar sobre la lista separada por comas
    IFS=',' read -ra ADDR <<< "${apps_to_install}"
    for app in "${ADDR[@]}"; do
        case "${app}" in
            "slack")
                log_task "Instalando Slack..."
                local slack_deb="/tmp/slack.deb"
                log_task "Descargando Slack .deb..."
                if ! curl --max-time 120 --fail --silent --show-error --location \
                    "https://downloads.slack-edge.com/desktop-releases/linux/x64/4.41.105/slack-desktop-4.41.105-amd64.deb" \
                    -o "$slack_deb"; then
                    # Fallback: intentar con la URL de redirección
                    log_task "Intentando URL alternativa..."
                    if ! curl --max-time 120 --fail --silent --show-error --location \
                        "https://slack.com/downloads/instructions/ubuntu" \
                        -o /dev/null; then
                        log_error "Error descargando Slack"
                        continue
                    fi
                fi

                if [[ -f "$slack_deb" ]]; then
                    log_task "Instalando paquete Slack..."
                    apt-get install -y "$slack_deb"
                    rm -f "$slack_deb"
                    log_success "Slack instalado"
                fi
                ;;

            "signal")
                log_task "Instalando Signal Desktop..."
                # Signal usa DEB822 format con key incluida
                log_task "Configurando repositorio Signal..."

                # Descargar el archivo .sources oficial (incluye la key)
                if ! curl --max-time 30 --fail --silent --show-error --location \
                    "https://updates.signal.org/desktop/apt/keys.asc" \
                    -o /tmp/signal-keys.asc; then
                    log_error "Error descargando clave GPG de Signal"
                    continue
                fi

                # Convertir a formato binario
                gpg --dearmor < /tmp/signal-keys.asc > /usr/share/keyrings/signal-desktop-keyring.gpg
                rm -f /tmp/signal-keys.asc

                # Crear archivo de repositorio
                cat > /etc/apt/sources.list.d/signal-desktop.list << 'SIGNAL_EOF'
deb [arch=amd64 signed-by=/usr/share/keyrings/signal-desktop-keyring.gpg] https://updates.signal.org/desktop/apt xenial main
SIGNAL_EOF

                apt-get update
                apt-get install -y signal-desktop
                log_success "Signal Desktop instalado"
                ;;

            "telegram")
                log_task "Instalando Telegram Desktop..."
                local telegram_tar="/tmp/telegram.tar.xz"
                log_task "Descargando Telegram..."
                if ! curl --max-time 120 --fail --silent --show-error --location \
                    "https://telegram.org/dl/desktop/linux" \
                    -o "$telegram_tar"; then
                    log_error "Error descargando Telegram"
                    continue
                fi

                log_task "Extrayendo Telegram..."
                # Validar archivo antes de extraer
                if ! validate_tar_archive "$telegram_tar" "Telegram archive"; then
                    rm -f "$telegram_tar"
                    continue
                fi

                tar -xf "$telegram_tar" -C /opt/
                rm -f "$telegram_tar"

                # Crear symlink
                ln -sf /opt/Telegram/Telegram /usr/local/bin/telegram-desktop

                # Crear .desktop entry
                cat > /usr/share/applications/telegram-desktop.desktop << 'TELEGRAM_EOF'
[Desktop Entry]
Version=1.0
Name=Telegram Desktop
Comment=Official Telegram Desktop Client
Exec=/opt/Telegram/Telegram -- %u
Icon=telegram
Terminal=false
StartupWMClass=TelegramDesktop
Type=Application
Categories=Chat;Network;InstantMessaging;
MimeType=x-scheme-handler/tg;
Keywords=tg;chat;im;messaging;messenger;
TELEGRAM_EOF

                log_success "Telegram Desktop instalado"
                ;;

            "none")
                # Ignorar si está mezclado con otros
                ;;

            *)
                log_warning "App de mensajería desconocida: ${app}"
                ;;
        esac
    done
}

# Ejecutar
install_messaging
