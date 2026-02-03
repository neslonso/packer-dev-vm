# Scripts de Post-Provisión

Esta carpeta contiene plantillas de ejemplo para los scripts de post-provisión.

## Uso

1. **Copia la carpeta** a `scripts-post-provision-custom/`:

   ```bash
   cp -r scripts-post-provision-custom.sample scripts-post-provision-custom
   ```

2. **Edita los scripts** según tus necesidades:
   - `post-provision-ubuntu.sh` - Orquestador para Ubuntu
   - `post-provision-xubuntu.sh` - Orquestador para Xubuntu
   - `modules/` - Módulos reutilizables

3. **Ejecuta el build** de Packer normalmente. La carpeta se subirá a `~/post-provision/` en la VM.

4. **Tras conectarte a la VM**, ejecuta:

   ```bash
   ./post-provision.sh
   ```

## Estructura

```
scripts-post-provision-custom/
├── post-provision-ubuntu.sh    # Orquestador Ubuntu (symlink desde ~/post-provision.sh)
├── post-provision-xubuntu.sh   # Orquestador Xubuntu (symlink desde ~/post-provision.sh)
└── modules/                    # Módulos compartidos
    ├── workspace.sh            # Crear estructura de directorios
    └── repos.sh                # Clonar repositorios
```

## Notas

- La carpeta `scripts-post-provision-custom/` está en `.gitignore` porque contiene configuración personal (repos privados, etc.)
- El SSH agent estará activo cuando ejecutes el script, por lo que se pedirá la passphrase si tus claves la tienen
- Puedes añadir tantos módulos como necesites en `modules/`
