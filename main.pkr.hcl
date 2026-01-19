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
# VARIABLES
# ==============================================================================

# --- Identidad ---
variable "vm_name" {
  type        = string
  description = "Nombre de la VM"
}

variable "username" {
  type        = string
  description = "Usuario principal"
}

variable "password" {
  type        = string
  sensitive   = true
  description = "Contraseña del usuario"
}

variable "hostname" {
  type        = string
  description = "Hostname de la máquina"
}

# --- Localización ---
variable "timezone" {
  type        = string
  description = "Zona horaria"
}

variable "locale" {
  type        = string
  description = "Locale del sistema"
}

variable "keyboard" {
  type        = string
  description = "Layout de teclado"
}

# --- Recursos ---
variable "memory" {
  type        = number
  description = "RAM en MB"
}

variable "cpus" {
  type        = number
  description = "Número de CPUs"
}

variable "disk_size" {
  type        = number
  description = "Tamaño del disco en MB"
}

# --- Ubuntu ---
variable "ubuntu_version" {
  type        = string
  description = "Versión de Ubuntu"
}

variable "iso_url" {
  type        = string
  description = "URL de la ISO de Ubuntu"
}

variable "iso_checksum" {
  type        = string
  description = "Checksum de la ISO"
}

# --- Sistema ---
variable "autologin" {
  type        = bool
  description = "Habilitar autologin"
}

variable "ssh_port" {
  type        = number
  description = "Puerto SSH"
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
    error_message = "Shell debe ser 'bash' o 'zsh'."
  }
}

variable "prompt_theme" {
  type        = string
  description = "Tema del prompt: none, starship, ohmybash, ohmyzsh"
  validation {
    condition     = contains(["none", "starship", "ohmybash", "ohmyzsh"], var.prompt_theme)
    error_message = "prompt_theme debe ser 'none', 'starship', 'ohmybash' o 'ohmyzsh'."
  }
}

variable "ohmyzsh_theme" {
  type        = string
  description = "Tema de Oh My Zsh"
}

variable "ohmyzsh_plugins" {
  type        = string
  description = "Plugins de Oh My Zsh (separados por coma)"
}

variable "ohmybash_theme" {
  type        = string
  description = "Tema de Oh My Bash"
}

variable "starship_preset" {
  type        = string
  description = "Preset de Starship"
}

# --- Fuentes ---
variable "nerd_font" {
  type        = bool
  description = "Instalar JetBrains Mono Nerd Font"
}

# --- Git ---
variable "git_name" {
  type        = string
  description = "Nombre para commits de Git"
}

variable "git_email" {
  type        = string
  description = "Email para commits de Git"
}

variable "git_default_branch" {
  type        = string
  description = "Branch por defecto de Git"
}

# --- Docker ---
variable "docker_log_max_size" {
  type        = string
  description = "Tamaño máximo de logs de Docker"
}

variable "docker_log_max_file" {
  type        = number
  description = "Número de archivos de log de Docker"
}

# --- Desktop ---
variable "desktop_theme" {
  type        = string
  description = "Tema del desktop: dark o light"
  validation {
    condition     = contains(["dark", "light"], var.desktop_theme)
    error_message = "desktop_theme debe ser 'dark' o 'light'."
  }
}

variable "install_vscode" {
  type        = bool
  description = "Instalar VS Code"
}

variable "install_antigravity" {
  type        = bool
  description = "Instalar Google Antigravity IDE"
}

variable "install_browser" {
  type        = string
  description = "Navegador a instalar: firefox, chrome, chromium o none"
  validation {
    condition     = contains(["firefox", "chrome", "chromium", "none"], var.install_browser)
    error_message = "install_browser debe ser 'firefox', 'chrome', 'chromium' o 'none'."
  }
}

# --- Build ---
variable "output_directory" {
  type        = string
  description = "Directorio de salida"
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
}

variable "hyperv_secure_boot" {
  type        = bool
  description = "Habilitar Secure Boot"
}

# ==============================================================================
# LOCALS - Valores calculados
# ==============================================================================

locals {
  # Password hash para cloud-init (SHA-512)
  # Nota: En producción, usar un hash pre-generado o mkpasswd
  password_hash = "$6$rounds=4096$packer$9nJ8xwZ0Z8vYvN9vJ5Z3Z8X0Z8vYvN9vJ5Z3Z8X0Z8vYvN9vJ5Z3"
  
  # Timestamp para nombres únicos
  timestamp = formatdate("YYYYMMDD-hhmm", timestamp())
  
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
  boot_wait = "5s"
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
  communicator     = "ssh"
  ssh_username     = var.username
  ssh_password     = var.password
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
  
  # --- Copiar script de provisioning ---
  provisioner "file" {
    source      = "${path.root}/scripts/provision.sh"
    destination = "/tmp/provision.sh"
  }
  
  # --- Ejecutar provisioning con todas las variables ---
  provisioner "shell" {
    environment_vars = local.provision_env_vars
    inline = [
      "chmod +x /tmp/provision.sh",
      "sudo -E /tmp/provision.sh",
      "rm /tmp/provision.sh"
    ]
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
  
  # --- Post-processors ---
  post-processor "manifest" {
    output     = "${var.output_directory}/manifest.json"
    strip_path = true
  }
}
