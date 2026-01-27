#!/bin/bash
# ==============================================================================
# DATABASES.SH - Instalación de clientes de base de datos
# ==============================================================================
# Instala: mysql-client, postgresql-client, redis-tools, sqlite3
# Requiere: common.sh
# ==============================================================================

install_database_clients() {
    log_section "Instalando clientes de base de datos..."

    apt-get install -y \
        mysql-client \
        postgresql-client \
        redis-tools \
        sqlite3

    log_success "Clientes de base de datos instalados"
}

# Ejecutar
install_database_clients
