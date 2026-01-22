# ==============================================================================
# PACKER BUILD WRAPPER FOR WINDOWS
# ==============================================================================
# Este script wrapper genera el password hash y ejecuta Packer build
# ==============================================================================

param(
    [string]$VarFile = "variables.pkrvars.hcl",
    [string]$PackerExe = "packer.exe",
    [switch]$ValidateOnly,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

if ($Help) {
    Write-Host @"
Packer Build Wrapper para Windows

USO:
    .\build.ps1 [-VarFile <ruta>] [-PackerExe <ruta>] [-ValidateOnly]

PARÁMETROS:
    -VarFile <ruta>      Archivo de variables (default: variables.pkrvars.hcl)
    -PackerExe <ruta>    Ejecutable de Packer (default: packer.exe en PATH)
    -ValidateOnly        Solo validar, no construir
    -Help                Mostrar esta ayuda

EJEMPLOS:
    # Validar configuración
    .\build.ps1 -ValidateOnly

    # Build con archivo de variables custom
    .\build.ps1 -VarFile .\mi-config.pkrvars.hcl

    # Build con ejecutable de Packer en ruta específica
    .\build.ps1 -PackerExe .\packer_1.14.3_windows_amd64\packer.exe

"@
    exit 0
}

Write-Host "=== PACKER BUILD WRAPPER ===" -ForegroundColor Cyan
Write-Host ""

# Verificar que existe el archivo de variables
if (-not (Test-Path $VarFile)) {
    Write-Error "ERROR: No se encontró el archivo de variables: $VarFile"
    exit 1
}

# Verificar que existe Packer
$PackerCmd = Get-Command $PackerExe -ErrorAction SilentlyContinue
if (-not $PackerCmd) {
    Write-Error "ERROR: No se encontró Packer: $PackerExe"
    Write-Host "Descarga Packer desde: https://www.packer.io/downloads" -ForegroundColor Yellow
    exit 1
}

Write-Host "[1/4] Leyendo configuración desde: $VarFile" -ForegroundColor Yellow

# Extraer password del archivo de variables
$varContent = Get-Content $VarFile -Raw
if ($varContent -match 'password\s*=\s*"([^"]+)"') {
    $password = $matches[1]
    Write-Host "      ✓ Password encontrado" -ForegroundColor Green
} else {
    Write-Error "ERROR: No se encontró la variable 'password' en $VarFile"
    exit 1
}

Write-Host ""
Write-Host "[2/4] Generando hash de contraseña..." -ForegroundColor Yellow

# Buscar herramientas para generar hash
$hashGenerated = $false
$passwordHash = ""

# Opción 1: Buscar bash (Git Bash, WSL, Cygwin)
$bashCmd = Get-Command bash -ErrorAction SilentlyContinue
if ($bashCmd -and (Test-Path ".\scripts\generate_password_hash.sh")) {
    try {
        Write-Host "      Usando bash (Git Bash/WSL)..." -ForegroundColor Gray
        $result = & bash .\scripts\generate_password_hash.sh $password 2>&1
        if ($LASTEXITCODE -eq 0) {
            $jsonResult = $result | ConvertFrom-Json
            $passwordHash = $jsonResult.hash
            $hashGenerated = $true
            Write-Host "      ✓ Hash generado con bash" -ForegroundColor Green
        }
    } catch {
        Write-Host "      ✗ Falló generación con bash" -ForegroundColor Red
    }
}

# Opción 2: Usar PowerShell con OpenSSL
if (-not $hashGenerated) {
    $opensslCmd = Get-Command openssl -ErrorAction SilentlyContinue
    if ($opensslCmd) {
        try {
            Write-Host "      Usando OpenSSL..." -ForegroundColor Gray
            # Generar salt aleatorio
            $saltBytes = New-Object byte[] 16
            $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
            $rng.GetBytes($saltBytes)
            $salt = [System.Convert]::ToBase64String($saltBytes) -replace '[^a-zA-Z0-9]', '' | Select-Object -First 16

            # Generar hash
            $passwordHash = $password | & openssl passwd -6 -salt $salt -stdin
            if ($LASTEXITCODE -eq 0 -and $passwordHash) {
                $hashGenerated = $true
                Write-Host "      ✓ Hash generado con OpenSSL" -ForegroundColor Green
            }
        } catch {
            Write-Host "      ✗ Falló generación con OpenSSL" -ForegroundColor Red
        }
    }
}

# Opción 3: Usar mkpasswd si está disponible
if (-not $hashGenerated) {
    $mkpasswdCmd = Get-Command mkpasswd -ErrorAction SilentlyContinue
    if ($mkpasswdCmd) {
        try {
            Write-Host "      Usando mkpasswd..." -ForegroundColor Gray
            $passwordHash = $password | & mkpasswd -m sha-512 -s
            if ($LASTEXITCODE -eq 0 -and $passwordHash) {
                $hashGenerated = $true
                Write-Host "      ✓ Hash generado con mkpasswd" -ForegroundColor Green
            }
        } catch {
            Write-Host "      ✗ Falló generación con mkpasswd" -ForegroundColor Red
        }
    }
}

if (-not $hashGenerated) {
    Write-Error @"
ERROR: No se pudo generar el hash de contraseña.

SOLUCIONES:
1. Instalar Git for Windows (incluye bash y openssl): https://git-scm.com/download/win
2. Instalar OpenSSL for Windows: https://slproweb.com/products/Win32OpenSSL.html
3. Habilitar WSL (Windows Subsystem for Linux)

Después de instalar, asegúrate de que bash u openssl estén en el PATH.
"@
    exit 1
}

Write-Host ""
Write-Host "[3/4] Ejecutando Packer..." -ForegroundColor Yellow

# Crear archivo temporal con el hash
$tempVarFile = [System.IO.Path]::GetTempFileName()
Copy-Item $VarFile $tempVarFile

# Añadir password_hash al archivo temporal
$passwordHashEscaped = $passwordHash -replace '\\', '\\\\'  # Escapar backslashes
$passwordHashEscaped = $passwordHashEscaped -replace '\$', '\\\$'  # Escapar $
Add-Content $tempVarFile "`n# Auto-generated by build.ps1"
Add-Content $tempVarFile "password_hash = `"$passwordHashEscaped`""

try {
    if ($ValidateOnly) {
        Write-Host "      Ejecutando: packer validate..." -ForegroundColor Gray
        & $PackerExe validate -var-file=$tempVarFile main.pkr.hcl
        $exitCode = $LASTEXITCODE
    } else {
        Write-Host "      Ejecutando: packer build..." -ForegroundColor Gray
        & $PackerExe build -var-file=$tempVarFile main.pkr.hcl
        $exitCode = $LASTEXITCODE
    }
} finally {
    # Limpiar archivo temporal
    Remove-Item $tempVarFile -ErrorAction SilentlyContinue
}

Write-Host ""
if ($exitCode -eq 0) {
    Write-Host "[4/4] ✓ Completado exitosamente" -ForegroundColor Green
} else {
    Write-Host "[4/4] ✗ Falló con código de salida: $exitCode" -ForegroundColor Red
}

exit $exitCode
