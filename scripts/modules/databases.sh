#!/bin/bash
# ==============================================================================
# DATABASES.SH - Instalación de clientes de base de datos
# ==============================================================================
# Instala: mysql-client, postgresql-client, redis-tools, sqlite3
# Opcionalmente: DBeaver CE (cliente gráfico universal)
# Requiere: common.sh
# ==============================================================================

install_database_clients() {
    log_task "Instalando clientes CLI de base de datos..."

    apt-get install -y \
        mysql-client \
        postgresql-client \
        redis-tools \
        sqlite3

    log_success "Clientes CLI de base de datos instalados"
}

install_dbeaver() {
    if [[ "${INSTALL_DBEAVER}" != "true" ]]; then
        log_task "DBeaver: omitido (INSTALL_DBEAVER=${INSTALL_DBEAVER})"
        return 0
    fi

    log_task "Instalando DBeaver Community Edition..."

    # Añadir repositorio oficial de DBeaver
    # https://dbeaver.io/download/
    wget -qO /usr/share/keyrings/dbeaver.gpg.key https://dbeaver.io/debs/dbeaver.gpg.key
    echo "deb [signed-by=/usr/share/keyrings/dbeaver.gpg.key] https://dbeaver.io/debs/dbeaver-ce /" > /etc/apt/sources.list.d/dbeaver.list

    apt-get update
    apt-get install -y dbeaver-ce

    log_success "DBeaver Community Edition instalado"
}

# Ejecutar
install_database_clients
install_dbeaver
