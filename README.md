# Packer Development VM

VM de desarrollo portable con Docker, configuración centralizada en un único archivo.

## Filosofía

```
┌─────────────────────────────────────────────────────────────┐
  variables.pkrvars.hcl  ← ÚNICA fuente de configuración     
         │                                                   
         ├──► main.pkr.hcl (Packer template)                 
         │         │                                         
         │         ├──► templates/user-data.pkrtpl           
         │         │    (cloud-init generado)                
         │         │                                         
         │         └──► scripts/provision.sh                 
         │              (recibe config via ENV vars)         
         │                                                   
         └──► VM lista con todo configurado                  
└─────────────────────────────────────────────────────────────┘
```

**Cero valores hardcodeados.** Cambias algo en `variables.pkrvars.hcl` y afecta a todo.

## Requisitos

- [Packer](https://www.packer.io/) >= 1.9.0
- Hyper-V habilitado (Windows 10/11 Pro o Enterprise)
- Permisos de administrador

### Nota sobre contraseñas

La contraseña por defecto es `developer`. Tras el primer login, cámbiala con:
```bash
passwd
```

## Quick Start

### 🪟 Windows

```powershell
# 1. Clonar el proyecto
git clone <repo>
cd packer-dev-vm

# 2. Copiar y editar configuración
copy variables.pkrvars.hcl.sample variables.pkrvars.hcl
# Editar variables.pkrvars.hcl con tus preferencias

# 3. Inicializar y validar
packer init main.pkr.hcl
packer validate -var-file=variables.pkrvars.hcl main.pkr.hcl

# 4. IMPORTANTE: Desactivar NumLock antes de construir
#    (Si NumLock está activo, el boot_command fallará)

# 5. Construir la VM
packer build -var-file=variables.pkrvars.hcl main.pkr.hcl

# 6. Configuración post-build (REQUERIDO - PowerShell como admin)
Get-VMNetworkAdapter -VMName "dev-workstation" | Set-VMNetworkAdapter -MacAddressSpoofing On
```

**Credenciales:** Usuario `developer`, password `developer`. **Cambia la contraseña** tras primer login con `passwd`.

### 🐧 Linux/macOS

**Nota:** Este proyecto está diseñado para Hyper-V (Windows). Para Linux/macOS se requeriría añadir soporte para VirtualBox, VMware o KVM.

## Estructura del Proyecto

```
packer-dev-vm/
├── variables.pkrvars.hcl      # ÚNICA fuente de configuración
├── main.pkr.hcl               # Template Packer (Hyper-V)
├── templates/
│   ├── user-data.pkrtpl       # Cloud-init (generado desde variables)
│   └── meta-data.pkrtpl       # Cloud-init metadata
├── scripts/
│   └── provision.sh           # Script de provisioning (usa ENV vars)
└── README.md
```

## Variables Disponibles

### Identidad

| Variable | Default | Descripción |
|----------|---------|-------------|
| `vm_name` | `dev-workstation` | Nombre de la VM en Hyper-V |
| `username` | `developer` | Usuario principal |
| `hostname` | `dev-workstation` | Hostname |

**Nota:** La contraseña por defecto es `developer` (hardcoded). Cámbiala tras primer login con `passwd`.

### Localización

| Variable | Default | Descripción |
|----------|---------|-------------|
| `timezone` | `Europe/Madrid` | Zona horaria |
| `locale` | `es_ES.UTF-8` | Locale |
| `keyboard` | `es` | Layout de teclado |

### Recursos

| Variable | Default | Descripción |
|----------|---------|-------------|
| `memory` | `8192` | RAM en MB |
| `cpus` | `4` | Número de CPUs |
| `disk_size` | `80000` | Disco en MB |

### Sistema

| Variable | Default | Descripción |
|----------|---------|-------------|
| `autologin` | `true` | Login automático en desktop |
| `ssh_port` | `22` | Puerto SSH |
| `ssh_allow_password` | `true` | Auth por password |
| `sudo_nopassword` | `true` | Sudo sin password |

### Shell y Prompt

| Variable | Default | Descripción |
|----------|---------|-------------|
| `shell` | `zsh` | `bash` o `zsh` |
| `prompt_theme` | `ohmyzsh` | `none`, `starship`, `ohmybash`, `ohmyzsh` |
| `ohmyzsh_theme` | `agnoster` | Tema de Oh My Zsh |
| `ohmyzsh_plugins` | `git,docker,...` | Plugins (separados por coma) |
| `ohmybash_theme` | `powerline` | Tema de Oh My Bash |
| `starship_preset` | `plain-text-symbols` | Preset de Starship |
| `nerd_font` | `JetBrainsMono` | Nerd Font a instalar (`none` para no instalar) |

### Git

| Variable | Default | Descripción |
|----------|---------|-------------|
| `git_name` | `Developer` | Nombre para commits |
| `git_email` | `developer@example.com` | Email para commits |
| `git_default_branch` | `main` | Branch por defecto |

### Docker

| Variable | Default | Descripción |
|----------|---------|-------------|
| `docker_log_max_size` | `10m` | Tamaño máximo de logs |
| `docker_log_max_file` | `3` | Archivos de log a mantener |

### Desktop

| Variable | Default | Descripción |
|----------|---------|-------------|
| `desktop_theme` | `dark` | `dark` o `light` |
| `install_vscode` | `true` | Instalar VS Code |
| `install_antigravity` | `false` | Instalar Antigravity IDE |
| `install_browser` | `firefox` | `firefox`, `chrome`, `chromium`, `none` |

### Build

| Variable | Default | Descripción |
|----------|---------|-------------|
| `output_directory` | `./output` | Directorio de salida |
| `headless` | `false` | Sin ventana (para CI/CD) |

### Hyper-V

| Variable | Default | Descripción |
|----------|---------|-------------|
| `hyperv_switch` | `Default Switch` | Switch virtual |
| `hyperv_generation` | `2` | Generación (1=BIOS, 2=UEFI) |
| `hyperv_secure_boot` | `false` | Secure Boot |

---

## Combinaciones de Shell y Prompt

### Combinaciones válidas

| `shell` | `prompt_theme` | Resultado |
|---------|----------------|-----------|
| `bash` | `none` | Bash vanilla |
| `bash` | `starship` | Bash + Starship |
| `bash` | `ohmybash` | Bash + Oh My Bash |
| `zsh` | `none` | Zsh vanilla |
| `zsh` | `starship` | Zsh + Starship |
| `zsh` | `ohmyzsh` | Zsh + Oh My Zsh |

### Combinaciones inválidas (el build fallará)

- `bash` + `ohmyzsh` ❌
- `zsh` + `ohmybash` ❌

---

## Temas de Prompt

### Oh My Zsh (`ohmyzsh_theme`)

**Sin Nerd Font** (funcionan con cualquier fuente):
- `robbyrussell` - Default, simple
- `bira` - Dos líneas, compacto
- `dst` - Hora a la derecha
- `refined` - Ultra-minimal
- `ys` - Muy popular, informativo
- `pure` - Minimalista elegante
- `minimal` - Lo más simple
- `bureau` - Combina dst + refined
- `josh` - Limpio con hora
- `gnzh` - Similar a bira

**Con Nerd Font** (requiere `nerd_font != "none"`):
- `agnoster` - Muy popular, segmentos powerline
- `powerlevel10k` - El más configurable (se instala automáticamente)

📋 **Lista completa:** https://github.com/ohmyzsh/ohmyzsh/wiki/Themes

### Oh My Bash (`ohmybash_theme`)

**Sin Nerd Font**:
- `font` - Default
- `bobby` - Simple
- `clean` - Ultra-minimal
- `minimal` - Mínimo
- `pure` - Elegante
- `modern` - Actualizado
- `brainy` - Informativo

**Con Nerd Font** (requiere `nerd_font != "none"`):
- `agnoster` - Segmentos powerline
- `powerline` - Estilo powerline clásico
- `powerline-multiline` - Powerline dos líneas
- `powerline-plain` - Powerline sin iconos
- `powerbash10k` - Similar a powerlevel10k

📋 **Lista completa:** https://github.com/ohmybash/oh-my-bash/wiki/Themes

### Starship (`starship_preset`)

**Sin Nerd Font**:
- `plain-text-symbols` - Solo texto ASCII
- `bracketed-segments` - Segmentos entre corchetes
- `pure-preset` - Emula Pure de zsh
- `no-runtime-versions` - Sin versiones de runtime
- `no-empty-icons` - Sin iconos vacíos
- `none` - Sin preset (config por defecto)

**Con Nerd Font** (requiere `nerd_font != "none"`):
- `pastel-powerline` - Colores pastel
- `gruvbox-rainbow` - Colores Gruvbox
- `nerd-font-symbols` - Todos los iconos

📋 **Lista completa:** https://starship.rs/presets/

---

## Qué incluye la VM

### Siempre instalado
- Ubuntu 24.04 Desktop (minimal)
- Docker Engine + Docker Compose + BuildKit
- Git + GitHub CLI + lazygit
- lazydocker (TUI para Docker)
- Clientes de BD: mysql-client, psql, redis-cli, sqlite3
- Herramientas: fzf, ripgrep, fd, bat, tmux, htop

### Según configuración
- VS Code con extensiones Docker/Git (`install_vscode`)
- Navegador (`install_browser`)
- Oh My Zsh / Oh My Bash / Starship (`prompt_theme`)
- JetBrains Mono Nerd Font (`nerd_font`)

---

## Uso con el Equipo

### Opción A: Compartir proyecto Packer (recomendado)

1. Subir proyecto a Git
2. Cada miembro clona y ajusta `variables.pkrvars.hcl`
3. Ejecuta `packer build`

**Ventajas:** Archivo pequeño, cada uno personaliza, queda en control de versiones.

### Opción B: Exportar VM

```powershell
# En PowerShell como admin
Export-VM -Name "dev-workstation" -Path "C:\VMs\export"
```

Pasar el directorio exportado al colega, quien importa con:

```powershell
Import-VM -Path "C:\VMs\export\dev-workstation\..."
```

---

## Añadir Otros Hypervisores (futuro)

El proyecto está preparado para añadir VirtualBox, VMware o QEMU. Solo hay que:

1. Añadir plugin en `main.pkr.hcl`:
   ```hcl
   required_plugins {
     virtualbox = {
       version = ">= 1.0.0"
       source  = "github.com/hashicorp/virtualbox"
     }
   }
   ```

2. Añadir source block:
   ```hcl
   source "virtualbox-iso" "ubuntu" {
     vm_name          = var.vm_name
     cpus             = var.cpus
     memory           = var.memory
     # ... resto de config
   }
   ```

3. Descomentar variables específicas en `variables.pkrvars.hcl`

4. Añadir al build:
   ```hcl
   sources = [
     "source.hyperv-iso.ubuntu",
     "source.virtualbox-iso.ubuntu"
   ]
   ```

---

## Troubleshooting

### Boot command escribe números (2221) en lugar de navegar
- **Causa:** NumLock está activado
- **Solución:** Desactivar NumLock antes de ejecutar `packer build`
- Con NumLock activo, las teclas de navegación se interpretan como números del teclado numérico

### SSH timeout durante build
- Verificar checksum de la ISO
- Asegurar que existe el switch "Default Switch" en Hyper-V
- Aumentar `ssh_timeout` en main.pkr.hcl si es necesario

### Warning: "mac spoofing should be allowed"
- Este warning es normal e informativo
- Packer no puede configurar MAC spoofing automáticamente
- Si Docker tiene problemas de networking, ejecutar en el host (PowerShell como admin):
  ```powershell
  Get-VMNetworkAdapter -VMName "dev-workstation" | Set-VMNetworkAdapter -MacAddressSpoofing On
  ```

### Nested virtualization no funciona (Docker falla)
- Ejecutar como Administrador
- Verificar que la VM tiene `enable_virtualization_extensions = true`
- En host: `Set-VMProcessor -VMName "dev-workstation" -ExposeVirtualizationExtensions $true`

### Oh My Zsh/Bash no muestra iconos
- Verificar `nerd_font != "none"` en variables
- Configurar el terminal para usar "JetBrainsMono Nerd Font"

### Error en combinación shell/prompt
- `ohmyzsh` requiere `shell = "zsh"`
- `ohmybash` requiere `shell = "bash"`
- `starship` funciona con ambos

---

## Licencia

MIT
