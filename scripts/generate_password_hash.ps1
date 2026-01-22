# Generate SHA-512 password hash for cloud-init
# Usage: generate_password_hash.ps1 <password>
param(
    [Parameter(Mandatory=$true)]
    [string]$Password
)

$ErrorActionPreference = "Stop"

# Validate password
if ([string]::IsNullOrWhiteSpace($Password)) {
    Write-Error "ERROR: Password cannot be empty"
    exit 1
}

# Check if mkpasswd is available (from WSL or Cygwin)
$mkpasswd = Get-Command mkpasswd -ErrorAction SilentlyContinue
if ($mkpasswd) {
    # Use mkpasswd if available
    $hash = $Password | & mkpasswd -m sha-512 -s
    $json = @{ hash = $hash } | ConvertTo-Json -Compress
    Write-Output $json
    exit 0
}

# Check if openssl is available
$openssl = Get-Command openssl -ErrorAction SilentlyContinue
if ($openssl) {
    # Generate random salt
    $saltBytes = New-Object byte[] 16
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $rng.GetBytes($saltBytes)
    $salt = -join ($saltBytes | ForEach-Object { [char]$_ }) | ForEach-Object { $_ -replace '[^a-zA-Z0-9]', '' }
    $salt = $salt.Substring(0, [Math]::Min(16, $salt.Length))

    # Generate hash using openssl
    $hash = $Password | & openssl passwd -6 -salt $salt -stdin
    $json = @{ hash = $hash } | ConvertTo-Json -Compress
    Write-Output $json
    exit 0
}

# Fallback: Use .NET to generate SHA-512 hash (not compatible with Linux crypt format, but works)
# WARNING: This generates a different format than mkpasswd/openssl
Write-Error "WARNING: Neither mkpasswd nor openssl found. Please install Git for Windows (includes openssl) or WSL."
Write-Error "Alternatively, install OpenSSL for Windows: https://slproweb.com/products/Win32OpenSSL.html"
exit 1
