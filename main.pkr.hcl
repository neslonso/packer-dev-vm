# ==============================================================================
# PACKER DEVELOPMENT VM - MAIN TEMPLATE
# ==============================================================================
# Hypervisores soportados: Hyper-V (preparado para añadir VirtualBox, VMware, QEMU)
# ==============================================================================

packer {
  required_version = ">= 1.9.0"
  required_plugins {
    hyperv = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/hyperv"
    }
  }
}

# ==============================================================================
# DATA SOURCES
# ==============================================================================

# Contraseña fija: "developer"
# - Hardcoded en ssh_password para build de Packer
# - El hash por defecto está en la variable password_hash
# - Usuario debe cambiar contraseña tras primer login con: passwd

# ==============================================================================
# VARIABLES
# ==============================================================================

# --- Identidad ---
variable "vm_name" {
  type        = string
  description = "Nombre de la VM (usado para directorios de output). Ejemplo: 'ubuntu-dev', 'my-workstation'"
  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9_-]{0,98}[a-zA-Z0-9]$", var.vm_name))
    error_message = "La variable vm_name debe tener entre 2 y 100 caracteres, comenzar y terminar con alfanumérico, y solo contener letras, números, guiones y guiones bajos."
  }
}

variable "username" {
  type        = string
  description = "Usuario principal del sistema. Debe seguir convenciones Linux: comenzar con letra minúscula o '_', solo a-z, 0-9, '-', '_' (máx 32 chars). Ejemplo: 'developer', 'john_doe'"
  validation {
    condition     = can(regex("^[a-z_][a-z0-9_-]{0,31}$", var.username))
    error_message = "La variable username debe comenzar con letra minúscula o guión bajo, y solo contener letras minúsculas, números, guiones y guiones bajos (máximo 32 caracteres)."
  }
}

variable "hostname" {
  type        = string
  description = "Hostname de la máquina (nombre visible en red). Ejemplo: 'dev-machine', 'ubuntu-desktop'"
  validation {
    condition     = can(regex("^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$", var.hostname))
    error_message = "La variable hostname debe tener entre 1 y 63 caracteres, comenzar y terminar con alfanumérico, y solo contener letras, números y guiones."
  }
}

# --- Localización ---
variable "timezone" {
  type        = string
  description = "Zona horaria (formato IANA). Ejemplos: 'America/New_York', 'Europe/Madrid', 'Asia/Tokyo', 'UTC'. Ver: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones"
  validation {
    condition     = can(regex("^[A-Za-z_]+(/[A-Za-z_]+)+$", var.timezone)) || var.timezone == "UTC"
    error_message = "La variable timezone debe tener formato IANA válido (ej: 'America/New_York', 'Europe/Madrid') o ser 'UTC'."
  }
}

variable "locale" {
  type        = string
  description = "Locale del sistema (idioma y región). Ejemplos: 'en_US.UTF-8', 'es_ES.UTF-8', 'de_DE.UTF-8'"
  validation {
    condition     = can(regex("^[a-z]{2}_[A-Z]{2}\\.UTF-8$", var.locale))
    error_message = "La variable locale debe tener formato válido (ej: 'en_US.UTF-8', 'es_ES.UTF-8')."
  }
}

variable "keyboard" {
  type        = string
  description = "Layout de teclado. Ejemplos: 'us' (inglés), 'es' (español), 'de' (alemán), 'fr' (francés)"
  validation {
    condition     = can(regex("^[a-z]{2}(-[a-z]+)?$", var.keyboard))
    error_message = "La variable keyboard debe ser un código válido de layout (ej: 'us', 'es', 'de', 'fr', 'en-gb')."
  }
}

# --- Recursos ---
variable "memory" {
  type        = number
  description = "RAM en MB"
  validation {
    condition     = var.memory >= 2048 && var.memory <= 131072
    error_message = "La variable memory debe estar entre 2048 MB (2 GB) y 131072 MB (128 GB). Ubuntu Desktop requiere mínimo 2 GB."
  }
}

variable "cpus" {
  type        = number
  description = "Número de CPUs"
  validation {
    condition     = var.cpus >= 1 && var.cpus <= 128
    error_message = "La variable cpus debe estar entre 1 y 128."
  }
}

variable "disk_size" {
  type        = number
  description = "Tamaño del disco en MB"
  validation {
    condition     = var.disk_size >= 20480 && var.disk_size <= 2097152
    error_message = "La variable disk_size debe estar entre 20480 MB (20 GB) y 2097152 MB (2 TB). Ubuntu Desktop requiere mínimo 20 GB."
  }
}

# --- Ubuntu ---
variable "iso_url" {
  type        = string
  description = "URL de la ISO de Ubuntu (HTTP/HTTPS o file://)"
  validation {
    condition     = can(regex("^(https?|file)://", var.iso_url))
    error_message = "La variable iso_url debe comenzar con http://, https:// o file://."
  }
}

variable "iso_checksum" {
  type        = string
  description = "Checksum de la ISO (formato: sha256:HEXSTRING)"
  validation {
    condition     = can(regex("^(md5|sha1|sha256|sha512):[a-fA-F0-9]+$", var.iso_checksum))
    error_message = "La variable iso_checksum debe tener formato válido: 'sha256:HEXSTRING' (también soporta md5, sha1, sha512)."
  }
}

# --- Sistema ---
variable "autologin" {
  type        = bool
  description = "Habilitar autologin"
}

variable "ssh_port" {
  type        = number
  description = "Puerto SSH"
  validation {
    condition     = var.ssh_port >= 1 && var.ssh_port <= 65535
    error_message = "La variable ssh_port debe estar entre 1 y 65535."
  }
}

variable "ssh_allow_password" {
  type        = bool
  description = "Permitir autenticación por contraseña"
}

variable "sudo_nopassword" {
  type        = bool
  description = "Sudo sin contraseña"
}

# --- Shell y Prompt ---
variable "shell" {
  type        = string
  description = "Shell: bash o zsh"
  validation {
    condition     = contains(["bash", "zsh"], var.shell)
    error_message = "La variable shell debe ser 'bash' o 'zsh'."
  }
}

variable "prompt_theme" {
  type        = string
  description = "Tema del prompt: none, starship, ohmybash, ohmyzsh"
  validation {
    condition     = contains(["none", "starship", "ohmybash", "ohmyzsh"], var.prompt_theme)
    error_message = "La variable prompt_theme debe ser 'none', 'starship', 'ohmybash' o 'ohmyzsh'."
  }
}

variable "ohmyzsh_theme" {
  type        = string
  default     = "robbyrussell"
  description = "Tema de Oh My Zsh. Ejemplos: 'robbyrussell' (default), 'agnoster', 'powerlevel10k', 'spaceship'. Ver: https://github.com/ohmyzsh/ohmyzsh/wiki/Themes"
  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]+$", var.ohmyzsh_theme))
    error_message = "La variable ohmyzsh_theme solo debe contener letras, números, guiones y guiones bajos."
  }
}

variable "ohmyzsh_plugins" {
  type        = string
  default     = "git"
  description = "Plugins de Oh My Zsh (separados por coma sin espacios). Ejemplos: 'git,docker,kubectl', 'git,z,fzf'. Ver: https://github.com/ohmyzsh/ohmyzsh/wiki/Plugins"
  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]+(,[a-zA-Z0-9_-]+)*$", var.ohmyzsh_plugins))
    error_message = "La variable ohmyzsh_plugins debe ser una lista de plugins separados por coma (solo letras, números, guiones y guiones bajos)."
  }
}

variable "ohmybash_theme" {
  type        = string
  default     = "powerline"
  description = "Tema de Oh My Bash. Ejemplos: 'powerline', 'agnoster', 'simple'. Ver: https://github.com/ohmybash/oh-my-bash/wiki/Themes"
  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]+$", var.ohmybash_theme))
    error_message = "La variable ohmybash_theme solo debe contener letras, números, guiones y guiones bajos."
  }
}

variable "starship_preset" {
  type        = string
  default     = "none"
  description = "Preset de Starship. Opciones: 'none' (sin preset), 'nerd-font-symbols', 'bracketed-segments', 'plain-text-symbols', 'no-runtime-versions', 'no-empty-icons', 'pure-preset', 'pastel-powerline', 'gruvbox-rainbow'. Ver: https://starship.rs/presets/"
  validation {
    condition     = contains(["none", "nerd-font-symbols", "bracketed-segments", "plain-text-symbols", "no-runtime-versions", "no-empty-icons", "pure-preset", "pastel-powerline", "gruvbox-rainbow"], var.starship_preset)
    error_message = "La variable starship_preset debe ser 'none', 'nerd-font-symbols', 'bracketed-segments', 'plain-text-symbols', 'no-runtime-versions', 'no-empty-icons', 'pure-preset', 'pastel-powerline' o 'gruvbox-rainbow'."
  }
}

# --- Fuentes ---
variable "nerd_font" {
  type        = string
  description = "Nerd Font a instalar ('none' para no instalar, o nombre de fuente). Opciones: 'JetBrainsMono', 'FiraCode', 'Hack', 'SourceCodePro', 'Meslo', 'none'. Ver: https://www.nerdfonts.com/font-downloads"
  validation {
    condition     = contains(["none", "JetBrainsMono", "FiraCode", "Hack", "SourceCodePro", "Meslo"], var.nerd_font)
    error_message = "La variable nerd_font debe ser 'none', 'JetBrainsMono', 'FiraCode', 'Hack', 'SourceCodePro' o 'Meslo'."
  }
}

# --- Git ---
variable "git_name" {
  type        = string
  description = "Nombre para commits de Git"
  validation {
    condition     = length(trimspace(var.git_name)) >= 1 && length(var.git_name) <= 255
    error_message = "La variable git_name debe tener entre 1 y 255 caracteres y no puede ser solo espacios."
  }
}

variable "git_email" {
  type        = string
  description = "Email para commits de Git"
  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.git_email))
    error_message = "La variable git_email debe tener un formato de email válido."
  }
}

variable "git_default_branch" {
  type        = string
  description = "Branch por defecto de Git"
  validation {
    condition     = length(var.git_default_branch) >= 1 && length(var.git_default_branch) <= 255
    error_message = "La variable git_default_branch debe tener entre 1 y 255 caracteres."
  }
}

# --- Docker ---
variable "docker_log_max_size" {
  type        = string
  description = "Tamaño máximo de logs de Docker"
  validation {
    condition     = can(regex("^[0-9]+(k|m|g)$", var.docker_log_max_size))
    error_message = "La variable docker_log_max_size debe tener formato válido (ej: 10m, 100k, 1g)."
  }
}

variable "docker_log_max_file" {
  type        = number
  description = "Número de archivos de log de Docker"
  validation {
    condition     = var.docker_log_max_file >= 1 && var.docker_log_max_file <= 100
    error_message = "La variable docker_log_max_file debe estar entre 1 y 100."
  }
}

# --- Desktop ---
variable "desktop_theme" {
  type        = string
  description = "Tema del desktop: dark o light"
  validation {
    condition     = contains(["dark", "light"], var.desktop_theme)
    error_message = "La variable desktop_theme debe ser 'dark' o 'light'."
  }
}

variable "install_vscode" {
  type        = bool
  description = "Instalar VS Code con extensiones básicas (Docker, Git, YAML)"
}

variable "install_antigravity" {
  type        = bool
  description = "Instalar Google Antigravity IDE (AI-powered IDE con agentes autónomos basado en Gemini 3). Requiere: Ubuntu 20.04+, 8GB RAM (16GB recomendado)"
}

variable "install_browser" {
  type        = string
  description = "Navegador a instalar: firefox, chrome, chromium o none"
  validation {
    condition     = contains(["firefox", "chrome", "chromium", "none"], var.install_browser)
    error_message = "La variable install_browser debe ser 'firefox', 'chrome', 'chromium' o 'none'."
  }
}

# --- Build ---
variable "output_directory" {
  type        = string
  description = "Directorio de salida (path relativo recomendado). Ejemplo: './output', './builds'"
  validation {
    condition     = can(regex("^\\./[a-zA-Z0-9][a-zA-Z0-9_/-]*$", var.output_directory)) || can(regex("^[a-zA-Z0-9][a-zA-Z0-9_/-]*$", var.output_directory))
    error_message = "La variable output_directory debe ser un path válido (preferiblemente relativo comenzando con './'), solo caracteres alfanuméricos, guiones, guiones bajos y barras."
  }
}

variable "headless" {
  type        = bool
  description = "Ejecutar sin ventana"
}

# --- Hyper-V ---
variable "hyperv_switch" {
  type        = string
  description = "Nombre del switch de Hyper-V"
}

variable "hyperv_generation" {
  type        = number
  description = "Generación de VM Hyper-V (1 o 2)"
  validation {
    condition     = var.hyperv_generation == 1 || var.hyperv_generation == 2
    error_message = "Hyperv generation debe ser 1 o 2."
  }
}

variable "hyperv_secure_boot" {
  type        = bool
  description = "Habilitar Secure Boot"
}

# ==============================================================================
# LOCALS - Valores calculados
# ==============================================================================

locals {
  # Contraseña fija: "developer" (hardcoded)
  # Usuario debe cambiar tras primer login con: passwd
  password_hash = "$6$AQiJ5GBZLGsQOSsY$VZpRX.aQa8u3VwVuKlx0g6q1BoTUkaNJvu1R2eyDZVVdQAbvBnJsRvYkNdSGVgQUmruie/x2jD5q4IuxtfY2o1"

  # Timestamp para nombres únicos
  timestamp = formatdate("YYYYMMDD-hhmm", timestamp())

  # GPG Key Fingerprints (centralized for easy maintenance)
  # These fingerprints are verified during package repository setup
  gpg_fingerprints = {
    docker    = "9DC8 5822 9FC7 DD38 854A  E2D8 8D81 803C 0EBF CD88"
    github    = "23F3 D4EA 75C7 C96E ED2F  6D8B 15D3 3B7B D59C 46E1"
    microsoft = "BC52 8686 B50D 79E3 39D3  721C EB3E 94AD BE12 29CF"
    google    = "EB4C 1BFD 4F04 2F6D DDCC  EC91 7721 F63B D38B 4796"
  }

  # Variables para el script de provisioning (todas las que necesita)
  provision_env_vars = [
    "VM_USERNAME=${var.username}",
    "VM_HOSTNAME=${var.hostname}",
    "VM_TIMEZONE=${var.timezone}",
    "VM_LOCALE=${var.locale}",
    "VM_KEYBOARD=${var.keyboard}",
    "VM_AUTOLOGIN=${var.autologin}",
    "VM_SSH_PORT=${var.ssh_port}",
    "VM_SSH_ALLOW_PASSWORD=${var.ssh_allow_password}",
    "VM_SUDO_NOPASSWORD=${var.sudo_nopassword}",
    "VM_SHELL=${var.shell}",
    "VM_PROMPT_THEME=${var.prompt_theme}",
    "VM_OHMYZSH_THEME=${var.ohmyzsh_theme}",
    "VM_OHMYZSH_PLUGINS=${var.ohmyzsh_plugins}",
    "VM_OHMYBASH_THEME=${var.ohmybash_theme}",
    "VM_STARSHIP_PRESET=${var.starship_preset}",
    "VM_NERD_FONT=${var.nerd_font}",
    "VM_GIT_NAME=${var.git_name}",
    "VM_GIT_EMAIL=${var.git_email}",
    "VM_GIT_DEFAULT_BRANCH=${var.git_default_branch}",
    "VM_DOCKER_LOG_MAX_SIZE=${var.docker_log_max_size}",
    "VM_DOCKER_LOG_MAX_FILE=${var.docker_log_max_file}",
    "VM_DESKTOP_THEME=${var.desktop_theme}",
    "VM_INSTALL_VSCODE=${var.install_vscode}",
    "VM_INSTALL_ANTIGRAVITY=${var.install_antigravity}",
    "VM_INSTALL_BROWSER=${var.install_browser}",
    # GPG Fingerprints (centralized)
    "GPG_FINGERPRINT_DOCKER=${local.gpg_fingerprints.docker}",
    "GPG_FINGERPRINT_GITHUB=${local.gpg_fingerprints.github}",
    "GPG_FINGERPRINT_MICROSOFT=${local.gpg_fingerprints.microsoft}",
    "GPG_FINGERPRINT_GOOGLE=${local.gpg_fingerprints.google}",
  ]
}

# ==============================================================================
# SOURCE: HYPER-V
# ==============================================================================

source "hyperv-iso" "ubuntu" {
  # --- VM Settings ---
  vm_name          = var.vm_name
  generation       = var.hyperv_generation
  switch_name      = var.hyperv_switch
  cpus             = var.cpus
  memory           = var.memory
  disk_size        = var.disk_size
  enable_secure_boot    = var.hyperv_secure_boot
  secure_boot_template  = "MicrosoftUEFICertificateAuthority"
  
  # Nested virtualization para Docker
  enable_virtualization_extensions = true
  enable_dynamic_memory            = false
  
  # --- ISO ---
  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum
  
  # --- Boot ---
  boot_wait = "10s"
  boot_command = [
    "<wait>e<wait>",
    "<down><down><down><end>",
    " autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/",
    "<f10>"
  ]
  
  # --- HTTP Server for cloud-init ---
  http_content = {
    "/user-data" = templatefile("${path.root}/templates/user-data.pkrtpl", {
      hostname           = var.hostname
      username           = var.username
      password_hash      = local.password_hash
      timezone           = var.timezone
      locale             = var.locale
      keyboard           = var.keyboard
      autologin          = var.autologin
      ssh_allow_password = var.ssh_allow_password
      sudo_nopassword    = var.sudo_nopassword
    })
    "/meta-data" = templatefile("${path.root}/templates/meta-data.pkrtpl", {
      hostname = var.hostname
    })
  }
  
  # --- SSH ---
  # Contraseña fija "developer" para que Packer se conecte durante el build
  # Si cambias password_hash, debes cambiar también este valor aquí
  # IP estática fija para evitar problemas de detección de Hyper-V
  communicator     = "ssh"
  ssh_host         = "172.20.144.100"
  ssh_username     = var.username
  ssh_password     = "developer"
  ssh_port         = var.ssh_port
  ssh_timeout      = "45m"
  
  # --- Output ---
  output_directory = "${var.output_directory}/hyperv-${var.vm_name}"
  headless         = var.headless
  
  # --- Shutdown ---
  # Note: provision.sh creates /etc/sudoers.d/99-packer-shutdown to allow shutdown without password
  # This works regardless of sudo_nopassword setting (security: only allows shutdown, not all sudo)
  shutdown_command = "sudo shutdown -P now"
}

# ==============================================================================
# BUILD
# ==============================================================================

build {
  name = "dev-vm"
  
  sources = [
    "source.hyperv-iso.ubuntu"
  ]
  
  # --- Esperar a que cloud-init termine ---
  provisioner "shell" {
    inline = [
      "echo 'Esperando a que cloud-init termine...'",
      "cloud-init status --wait || true",
      "echo 'cloud-init completado.'"
    ]
  }

  # --- Ejecutar provisioning con todas las variables ---
  provisioner "shell" {
    environment_vars = local.provision_env_vars
    script           = "${path.root}/scripts/provision.sh"
  }
  
  # --- Limpieza final ---
  provisioner "shell" {
    inline = [
      "echo 'Limpieza final...'",
      "sudo apt-get autoremove -y",
      "sudo apt-get clean",
      "sudo rm -rf /var/lib/apt/lists/*",
      "sudo rm -rf /tmp/*",
      "sudo rm -rf /var/tmp/*",
      "sudo truncate -s 0 /etc/machine-id",
      "sudo rm -f /var/lib/dbus/machine-id",
      "history -c",
      "echo 'VM lista!'"
    ]
  }

  # --- Aviso post-build (se ejecuta en el HOST) ---
  provisioner "shell-local" {
    inline = [
      "echo ''",
      "echo '============================================================'",
      "echo 'VM CREADA EXITOSAMENTE'",
      "echo '============================================================'",
      "echo ''",
      "echo 'Credenciales por defecto:'",
      "echo '  Usuario: ${var.username}'",
      "echo '  Password: developer'",
      "echo ''",
      "echo 'IMPORTANTE - Configuración post-build requerida:'",
      "echo ''",
      "echo '1. Habilitar MAC spoofing para Docker (PowerShell como admin):'",
      "echo '   Get-VMNetworkAdapter -VMName \"${var.vm_name}\" | Set-VMNetworkAdapter -MacAddressSpoofing On'",
      "echo ''",
      "echo '2. Cambiar contraseña tras primer login:'",
      "echo '   passwd'",
      "echo ''",
      "echo '============================================================'",
      "echo ''"
    ]
  }

  # --- Post-processors ---
  post-processor "manifest" {
    output     = "${var.output_directory}/manifest.json"
    strip_path = true
  }
}
