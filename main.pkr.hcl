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

variable "disk_encryption_password" {
  type        = string
  default     = ""
  sensitive   = true
  description = "Password para cifrado LUKS del disco. Si está vacío, el disco no se cifra. El cifrado usa AES-256-XTS y cumple con GDPR, HIPAA, PCI-DSS, ISO 27001."
}

# --- VM Flavor ---
variable "vm_flavor" {
  type        = string
  default     = "xubuntu"
  description = "Flavor de la VM: 'xubuntu' (XFCE, ligero, ideal para VM), 'ubuntu' (GNOME, completo)"
  validation {
    condition     = contains(["ubuntu", "xubuntu"], var.vm_flavor)
    error_message = "La variable vm_flavor debe ser 'ubuntu' o 'xubuntu'."
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

# --- Red ---
# NOTA: static_ip/gateway/dns se usan SIEMPRE durante el build (cloud-init + SSH).
# network_mode determina si después del build se cambia a DHCP o se mantiene estática.

variable "network_mode" {
  type        = string
  description = "Modo de red FINAL (tras provisioning): 'dhcp' cambia a DHCP, 'static' mantiene la IP configurada"
  default     = "dhcp"
  validation {
    condition     = contains(["dhcp", "static"], var.network_mode)
    error_message = "La variable network_mode debe ser 'dhcp' o 'static'."
  }
}

variable "static_ip" {
  type        = string
  description = "IP para build y final (si network_mode=static). Debe ser alcanzable desde el host. Formato CIDR: '192.168.1.100/24'"
  default     = "172.20.144.100/20"
  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+/[0-9]+$", var.static_ip))
    error_message = "La variable static_ip debe tener formato CIDR válido (ej: '192.168.1.100/24')."
  }
}

variable "static_gateway" {
  type        = string
  description = "Gateway para build y final (si network_mode=static)"
  default     = "172.20.144.1"
  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+$", var.static_gateway))
    error_message = "La variable static_gateway debe ser una IP válida."
  }
}

variable "static_dns" {
  type        = string
  description = "Servidores DNS separados por coma para build y final (si network_mode=static)"
  default     = "8.8.8.8,8.8.4.4"
  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+(,[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+)*$", var.static_dns))
    error_message = "La variable static_dns debe ser una lista de IPs separadas por coma."
  }
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

variable "install_portainer" {
  type        = bool
  description = "Instalar Portainer CE (Web UI para gestión de contenedores Docker). Accesible en https://localhost:9443"
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

variable "install_cursor" {
  type        = bool
  description = "Instalar Cursor (AI-powered code editor basado en VS Code)"
}

variable "install_sublimemerge" {
  type        = bool
  description = "Instalar Sublime Merge (cliente Git visual de alta velocidad)"
}

variable "vscode_extensions" {
  type        = list(string)
  default     = []
  description = "Lista de extensiones para VS Code, Cursor y Antigravity (IDs del marketplace)"
}

variable "install_api_tools" {
  type        = list(string)
  default     = ["none"]
  description = "Lista de herramientas de API a instalar: bruno, insomnia o none"
  validation {
    condition     = alltrue([for t in var.install_api_tools : contains(["bruno", "insomnia", "none"], t)])
    error_message = "Cada elemento de install_api_tools debe ser 'bruno', 'insomnia' o 'none'."
  }
}

variable "install_browser" {
  type        = list(string)
  default     = ["firefox"]
  description = "Lista de navegadores a instalar: firefox, chrome, chromium, all o none"
  validation {
    condition     = alltrue([for b in var.install_browser : contains(["firefox", "chrome", "chromium", "all", "none"], b)])
    error_message = "Cada elemento de install_browser debe ser 'firefox', 'chrome', 'chromium', 'all' o 'none'."
  }
}

variable "install_messaging" {
  type        = list(string)
  default     = ["none"]
  description = "Lista de apps de mensajería a instalar: slack, signal, telegram, all o none"
  validation {
    condition     = alltrue([for m in var.install_messaging : contains(["slack", "signal", "telegram", "all", "none"], m)])
    error_message = "Cada elemento de install_messaging debe ser 'slack', 'signal', 'telegram', 'all' o 'none'."
  }
}

variable "install_privacy" {
  type        = list(string)
  default     = ["none"]
  description = "Lista de herramientas de privacidad a instalar: keybase, element, all o none"
  validation {
    condition     = alltrue([for p in var.install_privacy : contains(["keybase", "element", "all", "none"], p)])
    error_message = "Cada elemento de install_privacy debe ser 'keybase', 'element', 'all' o 'none'."
  }
}

# --- SSH Keys ---
variable "ssh_key_pairs" {
  type = list(object({
    name        = string
    private_key = string
    public_key  = string
  }))
  default     = []
  sensitive   = true
  description = "Lista de pares de claves SSH a instalar. Cada elemento tiene: name (nombre del archivo sin extensión, ej: 'id_rsa'), private_key (contenido de la clave privada), public_key (contenido de la clave pública)"
}

# --- VM Registration (post-build) ---
variable "register_vm" {
  type        = bool
  description = "Registrar la VM en el hypervisor local tras el build"
  default     = false
}

variable "register_vm_copy" {
  type        = bool
  description = "true = copiar VM a register_vm_path (nuevo ID), false = registrar in-place desde output_directory"
  default     = true
}

variable "register_vm_path" {
  type        = string
  description = "Ruta base donde almacenar la VM copiada (solo si register_vm_copy=true). Ej: C:/VMs"
  default     = ""
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

  # ===========================================================================
  # FLAVORS - Configuración de ISOs y scripts por flavor
  # ===========================================================================
  # NOTA: xubuntu usa Ubuntu Server ISO + paquete xubuntu-desktop porque
  # la ISO de Xubuntu Desktop no soporta autoinstall de forma confiable.
  # ===========================================================================
  flavors = {
    xubuntu = {
      iso_url       = "https://releases.ubuntu.com/24.04.3/ubuntu-24.04.3-live-server-amd64.iso"
      iso_checksum  = "sha256:c3514bf0056180d09376462a7a1b4f213c1d6e8ea67fae5c25099c6fd3d8274b"
      user_data_tpl = "${path.root}/templates/user-data-xubuntu.pkrtpl"
      description   = "Ubuntu Server 24.04.3 + xubuntu-desktop (XFCE) - Ligero, ideal para VM"
    }
    ubuntu = {
      iso_url       = "https://releases.ubuntu.com/24.04.3/ubuntu-24.04.3-desktop-amd64.iso"
      iso_checksum  = "sha256:faabcf33ae53976d2b8207a001ff32f4e5daae013505ac7188c9ea63988f8328"
      user_data_tpl = "${path.root}/templates/user-data-ubuntu.pkrtpl"
      description   = "Ubuntu 24.04.3 LTS (GNOME) - Completo"
    }
  }

  # Flavor seleccionado
  flavor = local.flavors[var.vm_flavor]

  # GPG Key Fingerprints (centralized for easy maintenance)
  # These fingerprints are verified during package repository setup
  gpg_fingerprints = {
    docker    = "9DC8 5822 9FC7 DD38 854A  E2D8 8D81 803C 0EBF CD88"
    github    = "2C61 0620 1985 B60E 6C7A C873 23F3 D4EA 7571 6059"  # Updated 2026-01-23
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
    "VM_NETWORK_MODE=${var.network_mode}",
    "VM_STATIC_IP=${var.static_ip}",
    "VM_STATIC_GATEWAY=${var.static_gateway}",
    "VM_STATIC_DNS=${var.static_dns}",
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
    "VM_INSTALL_PORTAINER=${var.install_portainer}",
    "VM_DESKTOP_THEME=${var.desktop_theme}",
    "VM_INSTALL_VSCODE=${var.install_vscode}",
    "VM_INSTALL_ANTIGRAVITY=${var.install_antigravity}",
    "VM_INSTALL_CURSOR=${var.install_cursor}",
    "VM_INSTALL_SUBLIMEMERGE=${var.install_sublimemerge}",
    "VM_VSCODE_EXTENSIONS=${join(",", var.vscode_extensions)}",
    "VM_INSTALL_BROWSER=${join(",", var.install_browser)}",
    "VM_INSTALL_MESSAGING=${join(",", var.install_messaging)}",
    "VM_INSTALL_PRIVACY=${join(",", var.install_privacy)}",
    "VM_INSTALL_API_TOOLS=${join(",", var.install_api_tools)}",
    # SSH Keys (JSON encoded)
    "VM_SSH_KEY_PAIRS=${base64encode(jsonencode(var.ssh_key_pairs))}",
    # Disk encryption (empty = no encryption)
    "VM_DISK_ENCRYPTION_ENABLED=${var.disk_encryption_password != "" ? "true" : "false"}",
    # GPG Fingerprints (centralized)
    "GPG_FINGERPRINT_DOCKER=${local.gpg_fingerprints.docker}",
    "GPG_FINGERPRINT_GITHUB=${local.gpg_fingerprints.github}",
    "GPG_FINGERPRINT_MICROSOFT=${local.gpg_fingerprints.microsoft}",
    "GPG_FINGERPRINT_GOOGLE=${local.gpg_fingerprints.google}",
    "VM_WELCOME_HTML=${local.welcome_html_content}",
  ]

  # Welcome HTML Rendered
  welcome_html_content = templatefile("${path.root}/templates/user-welcome.html.pkrtpl", {
    hostname            = var.hostname
    username            = var.username
    ssh_port            = var.ssh_port
    install_browser     = join(", ", var.install_browser)
    install_vscode      = var.install_vscode ? "true" : "false"
    install_cursor      = var.install_cursor ? "true" : "false"
    install_antigravity = var.install_antigravity ? "true" : "false"
    install_portainer   = var.install_portainer ? "true" : "false"
    install_sublimemerge = var.install_sublimemerge ? "true" : "false"
    install_api_tools   = join(", ", var.install_api_tools)
    timestamp           = local.timestamp
  })
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
  enable_mac_spoofing              = true

  # --- ISO (desde flavor) ---
  iso_url      = local.flavor.iso_url
  iso_checksum = local.flavor.iso_checksum

  # --- Boot ---
  # boot_wait: tiempo de espera antes de enviar boot_command
  # Para Ubuntu Server: seleccionar opción de instalación y añadir parámetros autoinstall
  boot_wait = "5s"
  boot_command = [
    # Esperar a que GRUB cargue y seleccionar la primera opción
    "<wait3>",
    # Presionar 'e' para editar la entrada de GRUB
    "e",
    "<wait>",
    # Navegar hasta la línea del kernel (linux)
    "<down><down><down><end>",
    # Añadir parámetros de autoinstall
    " autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/",
    # Arrancar con F10
    "<f10>"
  ]

  # --- HTTP Server for cloud-init (template desde flavor) ---
  http_content = {
    "/user-data" = templatefile(local.flavor.user_data_tpl, {
      hostname                 = var.hostname
      username                 = var.username
      password_hash            = local.password_hash
      timezone                 = var.timezone
      locale                   = var.locale
      keyboard                 = var.keyboard
      autologin                = var.autologin
      ssh_allow_password       = var.ssh_allow_password
      sudo_nopassword          = var.sudo_nopassword
      disk_encryption_password = var.disk_encryption_password
      # Red (usada durante build y opcionalmente después si network_mode=static)
      static_ip                = var.static_ip
      static_gateway           = var.static_gateway
      static_dns               = var.static_dns
    })
    "/meta-data" = templatefile("${path.root}/templates/meta-data.pkrtpl", {
      hostname = var.hostname
    })
  }

  # --- SSH ---
  # Contraseña fija "developer" para que Packer se conecte durante el build
  # Si cambias password_hash, debes cambiar también este valor aquí
  # IP extraída de static_ip (sin máscara CIDR) para conexión SSH
  communicator     = "ssh"
  ssh_host         = split("/", var.static_ip)[0]
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

  # --- Crear directorio para scripts ---
  provisioner "shell" {
    inline = ["mkdir -p /tmp/provision"]
  }

  # --- Subir scripts de provisioning a la VM ---
  provisioner "file" {
    source      = "${path.root}/scripts/"
    destination = "/tmp/provision/"
  }

  # --- Ejecutar provisioning con todas las variables ---
  provisioner "shell" {
    environment_vars = local.provision_env_vars
    inline = [
      # Convertir CRLF a LF (por si los scripts vienen de Windows)
      "find /tmp/provision -type f -name '*.sh' -exec sed -i 's/\\r$//' {} \\;",
      "chmod -R +x /tmp/provision/",
      # El script escribe al log internamente, no usar tee para evitar problemas con pipefail
      "sudo -E /tmp/provision/provision-${var.vm_flavor}.sh"
    ]
  }

  # --- Limpieza final ---
  provisioner "shell" {
    inline = [
      "echo 'Limpieza final...'",
      "sudo rm -rf /tmp/provision || true",
      "sudo apt-get autoremove -y || true",
      "sudo apt-get clean || true",
      "sudo rm -rf /var/lib/apt/lists/* || true",
      "sudo rm -rf /tmp/* || true",
      "sudo rm -rf /var/tmp/* || true",
      "sudo truncate -s 0 /etc/machine-id || true",
      "sudo rm -f /var/lib/dbus/machine-id || true",
      "rm -f ~/.bash_history || true",
      "echo ''",
      "echo '============================================================'",
      "echo 'BUILD COMPLETADO EXITOSAMENTE'",
      "echo '============================================================'",
      "echo 'Flavor: ${var.vm_flavor}'",
      "echo 'Credenciales: ${var.username} / developer'",
      "echo 'Recuerda: Cambiar password tras login (passwd)'",
      "echo 'Recuerda: Habilitar MAC spoofing si Docker falla'",
      "echo '============================================================'",
      "echo ''"
    ]
  }

  # --- Asegurar que los archivos a descargar existen ---
  provisioner "shell" {
    inline = [
      "sudo touch /home/${var.username}/provision-${var.hostname}.log || true",
      "touch /home/${var.username}/connect-${var.hostname}.rdp 2>/dev/null || sudo touch /home/${var.username}/connect-${var.hostname}.rdp || true"
    ]
  }

  # --- Subir carpeta post-provision según flavor ---
  provisioner "file" {
    source      = "${path.root}/scripts-post-provision-custom/"
    destination = "/home/${var.username}/post-provision/"
  }

  # --- Configurar script post-provision ---
  provisioner "shell" {
    inline = [
      "chmod -R +x /home/${var.username}/post-provision/",
      "chown -R ${var.username}:${var.username} /home/${var.username}/post-provision/",
      "echo '${var.vm_flavor}' > /home/${var.username}/post-provision/.flavor",
      "ln -sf /home/${var.username}/post-provision/post-provision.sh /home/${var.username}/post-provision.sh",
      "echo ''",
      "echo '============================================================'",
      "echo 'SCRIPT POST-PROVISION DISPONIBLE'",
      "echo '============================================================'",
      "echo 'Se ha copiado la carpeta post-provision/ al home.'",
      "echo 'Ejecuta manualmente tras conectarte a la VM:'",
      "echo '  ./post-provision.sh'",
      "echo '============================================================'",
      "echo ''"
    ]
  }

  # --- Descargar log de provisioning al host ---
  provisioner "file" {
    source      = "/home/${var.username}/provision-${var.hostname}.log"
    destination = "${var.output_directory}/provision-${var.hostname}.log"
    direction   = "download"
  }

  # --- Descargar archivo .rdp para conexión fácil desde Windows ---
  provisioner "file" {
    source      = "/home/${var.username}/connect-${var.hostname}.rdp"
    destination = "${var.output_directory}/connect-${var.hostname}.rdp"
    direction   = "download"
  }

  # --- Descargar log en caso de error ---
  error-cleanup-provisioner "file" {
    source      = "/home/${var.username}/provision-${var.hostname}.log"
    destination = "${var.output_directory}/provision-${var.hostname}.log"
    direction   = "download"
  }

  # ===========================================================================
  # POST-PROCESSORS: Hyper-V VM Registration
  # ===========================================================================
  # Registers the VM in Hyper-V after build (if register_vm=true)
  # Supports copy mode (new location + new ID) or in-place registration
  post-processor "shell-local" {
    only = ["hyperv-iso.ubuntu"]
    inline = [
      "powershell.exe -ExecutionPolicy Bypass -File \"${path.root}/scripts/hyperv-register-vm.ps1\" -VmName \"${var.vm_name}\" -OutputDir \"${var.output_directory}/hyperv-${var.vm_name}\" -RegisterVm \"${var.register_vm}\" -RegisterVmCopy \"${var.register_vm_copy}\" -RegisterVmPath \"${var.register_vm_path}\""
    ]
  }
}
