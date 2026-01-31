#!/bin/bash
# ==============================================================================
# PRIVACY.SH - Instalación de herramientas de privacidad y cifrado
# ==============================================================================
# Instala: Keybase, Element según configuración
# Requiere: common.sh
# ==============================================================================

install_privacy() {
    # Si es "none", salir inmediatamente
    if [[ "${INSTALL_PRIVACY}" == "none" ]]; then
        log_task "Sin herramientas de privacidad."
        return 0
    fi

    # Si es "all", expandir a todas las apps soportadas
    local apps_to_install="${INSTALL_PRIVACY}"
    if [[ "${INSTALL_PRIVACY}" == "all" ]]; then
        apps_to_install="keybase,element"
    fi

    log_section "Configurando privacidad: ${apps_to_install}..."

    # Iterar sobre la lista separada por comas
    IFS=',' read -ra ADDR <<< "${apps_to_install}"
    for app in "${ADDR[@]}"; do
        case "${app}" in
            "keybase")
                log_task "Instalando Keybase..."
                local keybase_deb="/tmp/keybase.deb"
                log_task "Descargando Keybase .deb..."
                if ! curl --max-time 120 --fail --silent --show-error --location \
                    "https://prerelease.keybase.io/keybase_amd64.deb" \
                    -o "$keybase_deb"; then
                    log_error "Error descargando Keybase"
                    continue
                fi

                log_task "Instalando paquete Keybase..."
                apt-get install -y "$keybase_deb"
                rm -f "$keybase_deb"
                log_success "Keybase instalado"
                ;;

            "element")
                log_task "Instalando Element (Matrix)..."
                # Descargar clave GPG
                log_task "Configurando repositorio Element..."
                if ! curl --max-time 30 --fail --silent --show-error --location \
                    "https://packages.element.io/debian/element-io-archive-keyring.gpg" \
                    -o /usr/share/keyrings/element-io-archive-keyring.gpg; then
                    log_error "Error descargando clave GPG de Element"
                    continue
                fi

                # Crear archivo de repositorio
                echo "deb [signed-by=/usr/share/keyrings/element-io-archive-keyring.gpg] https://packages.element.io/debian/ default main" > /etc/apt/sources.list.d/element-io.list

                apt-get update
                apt-get install -y element-desktop
                log_success "Element instalado"
                ;;

            "none")
                # Ignorar si está mezclado con otros
                ;;

            *)
                log_warning "App de privacidad desconocida: ${app}"
                ;;
        esac
    done
}

# Ejecutar
install_privacy
