# ==============================================================================
# GENERAR HASH DE CONTRASEÑA - Script simple
# ==============================================================================
# Ejecutar UNA vez para generar el hash, luego copiar a variables.pkrvars.hcl
# ==============================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$Password
)

Write-Host "Buscando herramientas para generar hash..." -ForegroundColor Yellow

# Opción 1: bash (Git Bash)
$bash = Get-Command bash -ErrorAction SilentlyContinue
if ($bash) {
    Write-Host "Usando Git Bash..." -ForegroundColor Green
    $hash = bash -c "echo '$Password' | mkpasswd -m sha-512 -s 2>/dev/null"
    if ($hash) {
        Write-Host "`nHash generado:" -ForegroundColor Cyan
        Write-Host $hash -ForegroundColor White
        Write-Host "`nCopia este hash a tu variables.pkrvars.hcl:" -ForegroundColor Yellow
        Write-Host "password_hash = `"$hash`"" -ForegroundColor White
        exit 0
    }
}

# Opción 2: OpenSSL
$openssl = Get-Command openssl -ErrorAction SilentlyContinue
if ($openssl) {
    Write-Host "Usando OpenSSL..." -ForegroundColor Green
    $salt = -join ((65..90) + (97..122) | Get-Random -Count 16 | ForEach-Object {[char]$_})
    $hash = $Password | & openssl passwd -6 -salt $salt -stdin
    if ($hash) {
        Write-Host "`nHash generado:" -ForegroundColor Cyan
        Write-Host $hash -ForegroundColor White
        Write-Host "`nCopia este hash a tu variables.pkrvars.hcl:" -ForegroundColor Yellow
        Write-Host "password_hash = `"$hash`"" -ForegroundColor White
        exit 0
    }
}

Write-Error "No se encontró bash ni openssl. Instala Git for Windows."
exit 1
