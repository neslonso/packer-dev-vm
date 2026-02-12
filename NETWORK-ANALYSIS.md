# Analisis de Red de la VM - Packer Dev VM

> Documento de analisis del proceso de red durante instalacion, aprovisionamiento
> y runtime de la VM, para toma de decisiones sobre configuracion final.

---

## Indice

1. [Resumen ejecutivo](#1-resumen-ejecutivo)
2. [Fase 1: Instalacion (cloud-init)](#2-fase-1-instalacion-cloud-init)
3. [Fase 2: Comunicacion Packer-VM (SSH)](#3-fase-2-comunicacion-packer-vm-ssh)
4. [Fase 3: Aprovisionamiento (system-base.sh)](#4-fase-3-aprovisionamiento-system-basesh)
5. [Fase 4: Servicios de red instalados](#5-fase-4-servicios-de-red-instalados)
6. [Fase 5: Runtime (VM en uso)](#6-fase-5-runtime-vm-en-uso)
7. [Mapa completo de puertos y servicios](#7-mapa-completo-de-puertos-y-servicios)
8. [Diagrama del flujo de red](#8-diagrama-del-flujo-de-red)
9. [Hallazgos y posibles mejoras](#9-hallazgos-y-posibles-mejoras)
10. [Opciones de decision](#10-opciones-de-decision)

---

## 1. Resumen ejecutivo

La VM utiliza **red estatica durante todo el build** (cloud-init + Packer SSH) y
luego **opcionalmente cambia a DHCP** al final del aprovisionamiento segun la
variable `network_mode`. El rango por defecto (`172.20.144.100/20`) esta pensado
para el **Hyper-V Default Switch**.

### Flujo simplificado:

```
[cloud-init]         [Packer SSH]         [system-base.sh]         [Runtime]
IP estatica    -->   Conecta por SSH  --> Cambia a DHCP o    -->  RDP/SSH/Docker
172.20.144.100       al static_ip         mantiene estatica       mDNS hostname.local
```

---

## 2. Fase 1: Instalacion (cloud-init)

**Archivos implicados:**
- `templates/user-data-xubuntu.pkrtpl` (lineas 44-58)
- `templates/user-data-ubuntu.pkrtpl` (lineas 48-63)
- `main.pkr.hcl` (lineas 618-638 - bloque `http_content`)

### Configuracion de red en cloud-init

Durante la instalacion, cloud-init configura **siempre IP estatica** usando
netplan v2. Esto es obligatorio porque Packer necesita saber a que IP conectarse
por SSH.

```yaml
network:
  version: 2
  ethernets:
    eth0:
      match:
        name: "eth*"
      addresses:
        - 172.20.144.100/20      # static_ip (variable)
      routes:
        - to: default
          via: 172.20.144.1      # static_gateway (variable)
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]  # static_dns (variable)
      dhcp4: false
      dhcp6: false
```

### Variables que controlan esta fase

| Variable | Default | Descripcion |
|----------|---------|-------------|
| `static_ip` | `172.20.144.100/20` | IP + mascara CIDR durante el build |
| `static_gateway` | `172.20.144.1` | Gateway (Hyper-V Default Switch) |
| `static_dns` | `8.8.8.8,8.8.4.4` | DNS (Google DNS) |

### Hallazgo: Bug en template Ubuntu

En `user-data-ubuntu.pkrtpl` (lineas 48-49), hay un **`network:` duplicado**:

```yaml
  network:       # <-- nivel autoinstall
    network:     # <-- BUG: nivel extra anidado
      version: 2
```

Mientras que en `user-data-xubuntu.pkrtpl` (lineas 44-45) esta correcto:

```yaml
  network:       # <-- nivel autoinstall
    version: 2   # <-- directo
```

Esto podria causar que la configuracion de red **no se aplique correctamente**
en el flavor Ubuntu (GNOME). El installer podria caer en DHCP por defecto o
fallar en configurar la red.

### Interfaz de red

- Se usa `eth0` con `match: name: "eth*"` (wildcard)
- Esto cubre interfaces como `eth0`, `eth1`, etc.
- **IPv6 deshabilitado** (`dhcp6: false`, sin direcciones v6)
- No se configura MTU, VLAN ni interfaces adicionales

---

## 3. Fase 2: Comunicacion Packer-VM (SSH)

**Archivo:** `main.pkr.hcl` (lineas 644-649)

Packer se conecta a la VM por SSH usando la IP estatica configurada en cloud-init:

```hcl
communicator     = "ssh"
ssh_host         = split("/", var.static_ip)[0]  # extrae IP sin CIDR -> 172.20.144.100
ssh_username     = var.username
ssh_password     = "developer"
ssh_port         = var.ssh_port    # default: 22
ssh_timeout      = "45m"
```

### Punto critico

La IP de `ssh_host` se extrae de `static_ip` quitando la mascara CIDR. Si
`static_ip` no es alcanzable desde el host Windows, **el build fallara aqui**
con timeout de 45 minutos.

### MAC Spoofing

```hcl
enable_mac_spoofing = true   # Necesario para Docker networking
```

Esto permite que la VM use MACs diferentes de la asignada por Hyper-V, lo cual
es necesario para Docker bridge networks.

---

## 4. Fase 3: Aprovisionamiento (system-base.sh)

**Archivo:** `scripts/modules/system-base.sh` (lineas 9-66)

Al final de la instalacion, el script `system-base.sh` **reescribe la
configuracion de red** segun la variable `network_mode`:

### Modo DHCP (`network_mode = "dhcp"` - default)

```yaml
network:
  version: 2
  ethernets:
    eth0:
      match:
        name: "eth*"
      dhcp4: true
      dhcp6: false
```

Despues ejecuta:
```bash
netplan apply
sleep 2
dhclient -r eth0    # libera lease anterior
dhclient eth0       # solicita nuevo lease DHCP
sleep 2
```

### Modo estatico (`network_mode = "static"`)

Mantiene la configuracion original con `static_ip`, `static_gateway` y
`static_dns`.

### Hallazgo: Riesgo de desconexion SSH

Cuando `network_mode = "dhcp"`, el script cambia la IP **durante el
aprovisionamiento**. Esto podria provocar:

1. **Desconexion temporal de SSH** mientras se renueva la IP
2. Si la nueva IP DHCP es diferente, Packer podria perder la conexion

Sin embargo, `system-base.sh` se ejecuta como paso 1 del aprovisionamiento
(dentro del script principal `provision-{flavor}.sh`), y Packer mantiene la
sesion SSH abierta. Si la IP cambia pero la conexion TCP sobrevive, continua.
Si no sobrevive, el build falla.

En la practica, como todo se ejecuta en un unico `provisioner "shell"` que
llama a `provision-{flavor}.sh`, la sesion SSH ya esta establecida y es probable
que sobreviva al cambio de IP. Pero es un riesgo.

### Herramientas de red instaladas

En `system-base.sh` (lineas 86-102) se instalan:

| Paquete | Funcion |
|---------|---------|
| `net-tools` | `ifconfig`, `netstat`, `route` |
| `dnsutils` | `dig`, `nslookup`, `host` |
| `curl` | Transferencias HTTP/S |
| `wget` | Descargas HTTP/S |
| `apt-transport-https` | APT sobre HTTPS |
| `gnupg` | Verificacion de claves GPG |
| `software-properties-common` | `add-apt-repository` |

---

## 5. Fase 4: Servicios de red instalados

### 5.1 Docker (docker.sh)

**Archivo:** `scripts/modules/docker.sh`

Configuracion de red de Docker:

```json
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",     // configurable
        "max-file": "3"        // configurable
    },
    "exec-opts": ["native.cgroupdriver=systemd"]
}
```

- **No se configura explicitamente la red de Docker** (usa bridge default `docker0`: `172.17.0.0/16`)
- Se requiere `enable_mac_spoofing = true` en Hyper-V para que Docker bridge funcione
- Portainer (opcional) escucha en **`0.0.0.0:9443`** (HTTPS)

### Conexiones de red durante aprovisionamiento Docker

El script hace `curl` a:
- `https://download.docker.com` - repositorio Docker
- `https://api.github.com` - versiones de lazydocker y docker-compose
- `https://github.com/jesseduffield/lazydocker/releases/` - descarga lazydocker
- `https://github.com/docker/compose/releases/` - descarga docker-compose
- Docker Hub (`docker pull portainer/portainer-ce:lts`) - si Portainer habilitado

### 5.2 RDP - xrdp (para Xubuntu/XFCE)

**Archivo:** `scripts/modules/rdp/xrdp.sh`

| Aspecto | Configuracion |
|---------|--------------|
| Puerto RDP | `3389/tcp` |
| Puerto mDNS | `5353/udp` |
| TLS | RSA 4096-bit, auto-firmado, 365 dias |
| CN certificado | `{hostname}.local` |
| Hostname mDNS | `{hostname}.local` (via Avahi) |
| Resolucion RDP | 1920x1080, 24-bit |
| TCP nodelay | `true` |
| AllowRootLogin | `false` |
| Firewall (UFW) | Abre `3389/tcp` y `5353/udp` |

Genera archivo `.rdp` con:
```
full address:s:{hostname}.local:3389
authentication level:i:0     # Sin verificacion de certificado (auto-firmado)
```

### 5.3 RDP - GNOME Remote Desktop (para Ubuntu/GNOME)

**Archivo:** `scripts/modules/rdp/gnome-rd.sh`

| Aspecto | Configuracion |
|---------|--------------|
| Puerto RDP | `3389/tcp` |
| Puerto mDNS | `5353/udp` |
| TLS | RSA 4096-bit, auto-firmado, 365 dias |
| CN certificado | `{hostname}.local` |
| Hostname mDNS | `{hostname}.local` (via Avahi) |
| Resolucion RDP | 1920x1080, 32-bit |
| Modo | Sistema (`grdctl --system`) |
| Firewall (UFW) | Abre `3389/tcp` y `5353/udp` |

Genera archivo `.rdp` con:
```
full address:s:{hostname}.local:3389
authentication level:i:2     # Verificacion de certificado
```

### 5.4 SSH

**Archivos:**
- `templates/user-data-*.pkrtpl` (instalacion openssh-server)
- `scripts/modules/ssh-agent.sh` (claves y agente)

| Aspecto | Configuracion |
|---------|--------------|
| Puerto | Configurable (`ssh_port`, default 22) |
| Password auth | Configurable (`ssh_allow_password`) |
| Claves SSH | Desde variable `ssh_key_pairs` (JSON base64) |
| known_hosts | Pre-cargado con GitHub, GitLab, Bitbucket |
| SSH agent | Auto-start en `.bashrc`/`.zshrc` |

### 5.5 Conexiones salientes durante aprovisionamiento

Ademas de Docker, otros scripts hacen conexiones de red:

| Script | URLs/Endpoints |
|--------|---------------|
| `git.sh` | `https://cli.github.com`, GitHub API |
| `shell.sh` | `https://raw.githubusercontent.com` (oh-my-zsh/bash), `https://starship.rs` |
| `fonts.sh` | `https://github.com/ryanoasis/nerd-fonts/releases/` |
| `browsers.sh` | `https://dl.google.com` (Chrome), repos APT |
| `editors/*.sh` | `https://packages.microsoft.com` (VS Code), repos APT |
| `messaging.sh` | repos APT de Slack, Signal, Telegram |
| `privacy.sh` | repos APT de Keybase, Element |
| `maldet.sh` | `https://www.rfxn.com` (Linux Malware Detect) |
| `ssh-agent.sh` | `ssh-keyscan` a github.com, gitlab.com, bitbucket.org |

---

## 6. Fase 5: Runtime (VM en uso)

Cuando el usuario arranca la VM terminada:

### Acceso remoto

```
Host Windows --[RDP 3389]--> VM (hostname.local via mDNS / IP directa)
Host Windows --[SSH  22]---> VM (hostname.local o IP)
Browser      --[HTTPS 9443]-> Portainer (si habilitado)
```

### Resolucion de nombres

- **mDNS (Avahi):** `{hostname}.local` en puerto 5353/udp
  - Requiere Bonjour en Windows (o mDNS compatible)
  - Si mDNS no funciona, se debe usar IP directa
- **DNS:** Google DNS (8.8.8.8, 8.8.4.4) o los configurados

### Modo final de red

| `network_mode` | IP | Comportamiento |
|----------------|----|----|
| `dhcp` | Asignada por Hyper-V DHCP | Cambia en cada reinicio (puede ser diferente) |
| `static` | La configurada en `static_ip` | Fija, predecible, necesita estar en rango del switch |

---

## 7. Mapa completo de puertos y servicios

| Puerto | Proto | Servicio | Direccion | Notas |
|--------|-------|----------|-----------|-------|
| 22 | TCP | SSH | Entrante | Configurable via `ssh_port` |
| 3389 | TCP | RDP | Entrante | xrdp (XFCE) o gnome-remote-desktop (GNOME) |
| 5353 | UDP | mDNS/Avahi | Bidireccional | Resolucion `{hostname}.local` |
| 9443 | TCP | Portainer | Entrante | Solo si `install_portainer = true` |
| 68 | UDP | DHCP client | Saliente | Solo si `network_mode = "dhcp"` |
| 53 | UDP/TCP | DNS | Saliente | Hacia `static_dns` o DHCP-asignado |

### Firewall (UFW)

Si UFW esta activo, se abren:
- `3389/tcp` (RDP)
- `5353/udp` (mDNS)

**No se abre explicitamente** el puerto SSH ni el de Portainer en UFW. Sin
embargo, UFW no se activa por defecto en la VM, asi que todos los puertos
estan accesibles.

---

## 8. Diagrama del flujo de red

```
                        BUILD TIME
    =====================================================

    [Host Windows / Packer]
         |
         | 1. boot_command via Hyper-V console
         |    (inyecta URL del HTTP server de Packer)
         |
         v
    [Hyper-V VM - Installer]
         |
         | 2. cloud-init descarga user-data de:
         |    http://{{ .HTTPIP }}:{{ .HTTPPort }}/
         |    (HTTP server temporal de Packer en el host)
         |
         | 3. Configura IP estatica: 172.20.144.100/20
         |    via netplan (cloud-init network config)
         |
         v
    [VM con IP estatica]
         |
         | 4. Packer conecta por SSH a 172.20.144.100:22
         |    user: developer, pass: developer
         |
         | 5. Sube scripts a /tmp/provision/
         |
         | 6. Ejecuta provision-{flavor}.sh
         |    |
         |    +-- system-base.sh
         |    |     SI network_mode=dhcp:
         |    |       - Reescribe netplan a DHCP
         |    |       - netplan apply
         |    |       - dhclient -r/-renew
         |    |       - IP puede cambiar aqui (!)
         |    |     SI network_mode=static:
         |    |       - Mantiene IP original
         |    |
         |    +-- docker.sh (descarga paquetes, configura Docker)
         |    +-- git.sh, shell.sh, fonts.sh... (descargan tools)
         |    +-- rdp/xrdp.sh o rdp/gnome-rd.sh
         |    |     - Abre 3389/tcp
         |    |     - Configura Avahi mDNS
         |    |     - Genera certificados TLS
         |    |     - Genera archivo .rdp
         |    +-- ssh-agent.sh (instala claves SSH)
         |
         | 7. Packer descarga logs y .rdp del VM
         |
         | 8. Packer ejecuta shutdown -P now
         |
         v
    [VM apagada - imagen exportada]
         |
         | 9. post-processor: hyperv-register-vm.ps1
         |    (registra VM en Hyper-V local)
         |

                        RUNTIME
    =====================================================

    [Usuario arranca VM]
         |
         | IP segun network_mode:
         |   dhcp   -> IP asignada por Hyper-V
         |   static -> 172.20.144.100 (o configurada)
         |
         | Servicios activos:
         |   - SSH      (22/tcp)
         |   - RDP      (3389/tcp)
         |   - mDNS     (5353/udp) -> hostname.local
         |   - Docker   (bridge 172.17.0.0/16)
         |   - Portainer (9443/tcp, opcional)
         |
         v
    [Host conecta via RDP o SSH]
         hostname.local:3389  (mDNS)
         hostname.local:22    (mDNS)
         o IP directa
```

---

## 9. Hallazgos y posibles mejoras

### 9.1 BUG: `network:` duplicado en template Ubuntu

**Archivo:** `templates/user-data-ubuntu.pkrtpl:48-49`
**Severidad:** Alta (puede causar fallo de red durante instalacion del flavor Ubuntu)

```yaml
# ACTUAL (buggy):
  network:
    network:     # <-- nivel extra
      version: 2

# CORRECTO (como en xubuntu):
  network:
    version: 2
```

### 9.2 Riesgo de desconexion SSH al cambiar a DHCP

**Archivo:** `scripts/modules/system-base.sh:33-38`
**Severidad:** Media

Cuando `network_mode=dhcp`, el script cambia la IP y hace `dhclient` durante
el aprovisionamiento. Si la sesion SSH se pierde, el build falla. En la
practica funciona porque:
- La sesion TCP ya esta establecida
- Hyper-V Default Switch suele reasignar la misma IP
- Pero no es determinista

### 9.3 UFW no abre SSH ni Portainer

**Archivos:** `scripts/modules/rdp/xrdp.sh:121-124`, `scripts/modules/rdp/gnome-rd.sh:82-85`
**Severidad:** Baja (UFW no esta activo por defecto)

Solo se abren 3389/tcp y 5353/udp. Si alguien activa UFW, SSH (22) y
Portainer (9443) quedarian bloqueados. No es un problema actualmente porque UFW
no se activa en ningun script.

### 9.4 IPv6 completamente deshabilitado

**Severidad:** Informativo

En todas las fases se usa `dhcp6: false` y no se configura ninguna direccion
IPv6. Esto es correcto para un entorno de desarrollo local pero limita testing
de aplicaciones con IPv6.

### 9.5 DNS hardcoded a Google (8.8.8.8)

**Severidad:** Informativo

Los DNS por defecto son Google. En modo DHCP, el DNS se obtiene del DHCP server
(generalmente el gateway de Hyper-V). En modo estatico, se usan los configurados.
Consideraciones de privacidad: Google DNS registra queries.

### 9.6 Certificados TLS auto-firmados

**Severidad:** Informativo

Los certificados RDP son auto-firmados con validez de 365 dias. Esto es normal
para un entorno de desarrollo local. `authentication level:i:0` en xrdp
desactiva la verificacion (nivel de seguridad bajo).

### 9.7 Credenciales en texto plano

**Severidad:** Informativo (entorno de desarrollo)

- Password SSH de Packer: `"developer"` hardcoded en `main.pkr.hcl:647`
- Credenciales RDP de GNOME: `grdctl --system rdp set-credentials` en `gnome-rd.sh:69`
- Se espera que el usuario cambie la password tras primer login

### 9.8 Sin VLAN ni segmentacion de red

**Severidad:** Informativo

No hay configuracion de VLANs, interfaces multiples ni segmentacion. La VM
tiene una unica interfaz `eth0` en un unico segmento de red.

---

## 10. Opciones de decision

A continuacion se presentan las areas donde puedes decidir como quieres que
quede la configuracion de red:

### Decision 1: Modo de red por defecto

| Opcion | Pros | Contras |
|--------|------|---------|
| **DHCP** (actual default) | Sin configuracion manual, funciona con cualquier switch | IP cambia entre reinicios, mas dificil conectar por IP |
| **Estatica** | IP predecible, facil de documentar | Requiere que el rango sea valido para el switch |

### Decision 2: Resolver el bug del template Ubuntu

| Opcion | Impacto |
|--------|---------|
| **Corregir** el `network:` duplicado | El flavor Ubuntu configurara la red correctamente |
| **Dejar como esta** | El flavor Ubuntu podria no tener red correcta durante build |

### Decision 3: DNS por defecto

| Opcion | Pros | Contras |
|--------|------|---------|
| **Google** (8.8.8.8) actual | Rapido, confiable | Privacidad |
| **Cloudflare** (1.1.1.1) | Rapido, mejor privacidad | Diferente proveedor |
| **Quad9** (9.9.9.9) | Bloqueo de malware | Puede bloquear sitios legitimos |
| **Configurable** (actual) | El usuario elige | Ya es asi |

### Decision 4: Firewall (UFW)

| Opcion | Pros | Contras |
|--------|------|---------|
| **No activar** (actual) | Simple, todo funciona | Sin proteccion de red |
| **Activar con reglas** | Seguridad | Requiere abrir SSH, RDP, Portainer, Docker |

### Decision 5: IPv6

| Opcion | Pros | Contras |
|--------|------|---------|
| **Deshabilitado** (actual) | Simple, sin conflictos | Sin testing IPv6 |
| **Habilitado** | Stack dual completo | Posibles conflictos con Hyper-V |

### Decision 6: Seguridad de certificados RDP

| Opcion | Pros | Contras |
|--------|------|---------|
| **Auto-firmado** (actual) | Sin dependencias, funciona siempre | Warning en cliente RDP |
| **Auto-firmado con fingerprint** | Verificable manualmente | Mas pasos para el usuario |

### Decision 7: Riesgo de cambio de IP durante build

| Opcion | Pros | Contras |
|--------|------|---------|
| **Mantener** (actual) | Sencillo | Posible fallo si SSH se desconecta |
| **Retrasar cambio a DHCP** al final | Menor riesgo | Requiere reorganizar scripts |
| **Cambiar en post-provision** | Sin riesgo durante build | El cambio es manual |

---

## Archivos clave por fase

| Fase | Archivos |
|------|----------|
| Instalacion | `templates/user-data-*.pkrtpl`, `templates/meta-data.pkrtpl` |
| Build (Packer) | `main.pkr.hcl` (source hyperv-iso, build) |
| Aprovisionamiento | `scripts/modules/system-base.sh`, `scripts/modules/common.sh` |
| Docker | `scripts/modules/docker.sh` |
| RDP | `scripts/modules/rdp/xrdp.sh`, `scripts/modules/rdp/gnome-rd.sh` |
| SSH | `scripts/modules/ssh-agent.sh`, cloud-init `ssh:` |
| Post-build | `scripts/hyperv-register-vm.ps1` |
| Post-provision | `scripts-post-provision-custom.sample/` |
