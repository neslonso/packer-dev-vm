# Scripts de Post-Provisión

Esta carpeta contiene plantillas de ejemplo para los scripts de post-provisión.

## Uso

1. **Copia la carpeta** a `scripts-post-provision-custom/`:

   ```bash
   cp -r scripts-post-provision-custom.sample scripts-post-provision-custom
   ```

2. **Edita los scripts** según tus necesidades:
   - `post-provision.sh` - Punto de entrada principal (módulos comunes)
   - `post-provision-ubuntu.sh` - Comandos específicos de Ubuntu (opcional)
   - `post-provision-xubuntu.sh` - Comandos específicos de Xubuntu (opcional)
   - `modules/` - Módulos reutilizables

3. **Ejecuta el build** de Packer. La carpeta se subirá a `~/post-provision/` en la VM.

4. **Tras conectarte a la VM**, ejecuta:

   ```bash
   ./post-provision.sh
   ```

## Estructura

```
scripts-post-provision-custom/
├── post-provision.sh           # Punto de entrada (ejecuta módulos comunes + flavor)
├── post-provision-ubuntu.sh    # Específico Ubuntu (opcional, llamado automáticamente)
├── post-provision-xubuntu.sh   # Específico Xubuntu (opcional, llamado automáticamente)
└── modules/                    # Módulos compartidos
    ├── workspace.sh            # Crear estructura de directorios
    └── repos.sh                # Clonar repositorios
```

## Flujo de ejecución

```
post-provision.sh (punto de entrada)
    │
    ├── 1. Ejecuta módulos comunes (workspace.sh, repos.sh, etc.)
    │
    └── 2. Si existe post-provision-{flavor}.sh, lo ejecuta
            └── Ejecuta módulos específicos del flavor
```

## Notas

- El archivo `.flavor` se genera automáticamente durante el provisioning
- La carpeta `scripts-post-provision-custom/` está en `.gitignore` (contiene config personal)
- El SSH agent estará activo, se pedirá passphrase si las claves la tienen
- Puedes añadir tantos módulos como necesites en `modules/`
