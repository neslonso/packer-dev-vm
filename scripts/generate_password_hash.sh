#!/bin/bash
# Generate SHA-512 password hash for cloud-init
# Usage: generate_password_hash.sh <password>

set -euo pipefail

# Validate argument
if [[ $# -ne 1 ]]; then
    echo "ERROR: Missing password argument" >&2
    echo "Usage: $0 <password>" >&2
    exit 1
fi

if [[ -z "$1" ]]; then
    echo "ERROR: Password cannot be empty" >&2
    exit 1
fi

PASSWORD="$1"

# Check if mkpasswd is available
if ! command -v mkpasswd &> /dev/null; then
    # Fallback: use openssl if mkpasswd not available
    if command -v openssl &> /dev/null; then
        SALT=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 16)
        HASH=$(echo "$PASSWORD" | openssl passwd -6 -salt "$SALT" -stdin)
        echo "{\"hash\": \"$HASH\"}"
        exit 0
    else
        echo "ERROR: Neither mkpasswd nor openssl available" >&2
        exit 1
    fi
fi

# Use mkpasswd (preferred method)
HASH=$(echo "$PASSWORD" | mkpasswd -m sha-512 -s)

# Output as JSON for Packer
echo "{\"hash\": \"$HASH\"}"
