#!/usr/bin/env bash
###############################################################################
# Phase 1 - Step 2: Create Kubernetes Secrets
#
# Replaces HashiCorp Vault from the MVD default deployment.
# Uses native Kubernetes Secrets (kubectl) for all cryptographic material,
# API keys, and database credentials.
#
# Blueprint rationale: "Kubernetes Secrets provide sufficient confidentiality
# for the deployment" - HashiCorp Vault is optional hardening beyond scope.
#
# Prerequisites:
#   - K3s running with kubectl configured (run 01-bootstrap-k3s.sh first)
#   - 'mvd' namespace exists
#
# Usage: bash 02-create-secrets.sh
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/create-secrets.log"
NAMESPACE="mvd"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

generate_password() {
    openssl rand -base64 "${1:-32}" | tr -dc 'a-zA-Z0-9' | head -c "${1:-32}"
}

generate_api_key() {
    openssl rand -hex 32
}

create_secret_if_absent() {
    local name="$1"
    shift
    if kubectl get secret "$name" -n "$NAMESPACE" &>/dev/null; then
        log "Secret '$name' already exists, skipping"
        return 0
    fi
    kubectl create secret generic "$name" --namespace "$NAMESPACE" "$@"
    log "Created secret: $name"
}

###############################################################################
# 1. PostgreSQL Credentials
#    Matches the user/password pairs used in MVD's Terraform configs
###############################################################################
create_db_secrets() {
    log "=== Creating PostgreSQL Secrets ==="

    # Provider databases (matches provider.tf user/password pairs)
    create_secret_if_absent "provider-postgres-credentials" \
        --from-literal=POSTGRES_USER="postgres" \
        --from-literal=POSTGRES_PASSWORD="$(generate_password 24)"

    # Consumer database
    create_secret_if_absent "consumer-postgres-credentials" \
        --from-literal=POSTGRES_USER="postgres" \
        --from-literal=POSTGRES_PASSWORD="$(generate_password 24)"

    # Issuer database
    create_secret_if_absent "issuer-postgres-credentials" \
        --from-literal=POSTGRES_USER="postgres" \
        --from-literal=POSTGRES_PASSWORD="$(generate_password 24)"
}

###############################################################################
# 2. EDC API Authentication Keys
#    These replace the Vault-stored API keys in the MVD default setup
###############################################################################
create_api_secrets() {
    log "=== Creating EDC API Secrets ==="

    # Provider connector API keys
    create_secret_if_absent "provider-edc-api-keys" \
        --from-literal=management-api-key="$(generate_api_key)" \
        --from-literal=protocol-api-key="$(generate_api_key)" \
        --from-literal=public-api-key="$(generate_api_key)"

    # Consumer connector API keys
    create_secret_if_absent "consumer-edc-api-keys" \
        --from-literal=management-api-key="$(generate_api_key)" \
        --from-literal=protocol-api-key="$(generate_api_key)" \
        --from-literal=public-api-key="$(generate_api_key)"

    # IdentityHub super-user key (matches MVD seed-k8s.sh)
    create_secret_if_absent "identityhub-api-key" \
        --from-literal=api-key="c3VwZXItdXNlcg==.c3VwZXItc2VjcmV0LWtleQo="
}

###############################################################################
# 3. Data Plane Transfer Tokens
#    EDR token signing/verification secrets
###############################################################################
create_transfer_secrets() {
    log "=== Creating Data Plane Transfer Secrets ==="

    create_secret_if_absent "provider-transfer-secrets" \
        --from-literal=transfer-proxy-token-signer="$(generate_api_key)" \
        --from-literal=transfer-proxy-token-verifier="$(generate_api_key)"

    create_secret_if_absent "consumer-transfer-secrets" \
        --from-literal=transfer-proxy-token-signer="$(generate_api_key)" \
        --from-literal=transfer-proxy-token-verifier="$(generate_api_key)"
}

###############################################################################
# 4. DID Private Key Placeholders
#    Will be populated in Phase 2 with actual EC key pairs
###############################################################################
create_did_key_placeholders() {
    log "=== Creating DID Key Placeholders (Phase 2 will populate) ==="

    # These are placeholder secrets - Phase 2 script will replace with real keys
    create_secret_if_absent "provider-did-keys" \
        --from-literal=private-key="PLACEHOLDER_REPLACE_IN_PHASE_2" \
        --from-literal=key-id="provider-key-1"

    create_secret_if_absent "consumer-did-keys" \
        --from-literal=private-key="PLACEHOLDER_REPLACE_IN_PHASE_2" \
        --from-literal=key-id="consumer-key-1"

    create_secret_if_absent "issuer-did-keys" \
        --from-literal=private-key="PLACEHOLDER_REPLACE_IN_PHASE_2" \
        --from-literal=key-id="issuer-key-1"
}

###############################################################################
# 5. Verify
###############################################################################
verify() {
    log "=== Verifying All Secrets in '$NAMESPACE' ==="
    kubectl get secrets -n "$NAMESPACE"
    log "=== Phase 1 Step 2 COMPLETE ==="
}

###############################################################################
# Main
###############################################################################
main() {
    log "=========================================="
    log "EDC Gaia-X Phase 1: Kubernetes Secrets"
    log "=========================================="

    create_db_secrets
    create_api_secrets
    create_transfer_secrets
    create_did_key_placeholders
    verify

    log "=========================================="
    log "DONE. Next: Run 03-deploy-databases.sh"
    log "=========================================="
}

main "$@"
