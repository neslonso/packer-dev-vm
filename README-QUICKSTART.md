# Quick Start - Packer Dev VM

## Windows

1. **Generar hash de contraseña**:
```powershell
.\generate-hash.ps1 "developer"
```

2. **Copiar el hash a `variables.pkrvars.hcl`**:
```hcl
password_hash = "$6$abcd1234..."  # Pegar aquí el hash generado
```

3. **Validar y construir**:
```powershell
packer validate -var-file=variables.pkrvars.hcl main.pkr.hcl
packer build -var-file=variables.pkrvars.hcl main.pkr.hcl
```

## Eso es todo.

Ejecutas el script UNA vez, copias el hash, y usas Packer normalmente.
