#!/usr/bin/env bash
###############################################################################
# Phase 1 - Step 3: Deploy PostgreSQL + PostGIS Databases
#
# Deploys PostgreSQL with PostGIS extension for both Provider and Consumer.
# Uses local-path PVCs (K3s default storage class) for persistence.
#
# PostGIS is included for geospatial policy evaluation support
# (RegionLocation ODRL constraints in Phase 3).
#
# Prerequisites:
#   - K3s running (01-bootstrap-k3s.sh)
#   - Secrets created (02-create-secrets.sh)
#
# Usage: bash 03-deploy-databases.sh
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="${SCRIPT_DIR}/.."
LOG_FILE="${SCRIPT_DIR}/deploy-databases.log"
NAMESPACE="mvd"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

wait_for_pod() {
    local label="$1"
    local timeout="${2:-120}"
    log "Waiting for pod with label '$label' to be ready (timeout: ${timeout}s)..."
    kubectl wait --for=condition=Ready pod -l "$label" \
        -n "$NAMESPACE" --timeout="${timeout}s" 2>/dev/null || {
        log "WARNING: Pod not ready within ${timeout}s, checking status..."
        kubectl get pods -n "$NAMESPACE" -l "$label"
    }
}

###############################################################################
# Deploy Provider PostgreSQL (PostGIS)
###############################################################################
deploy_provider_postgres() {
    log "=== Deploying Provider PostgreSQL + PostGIS ==="
    kubectl apply -f "${INFRA_DIR}/modules/postgres/provider-postgres.yaml" -n "$NAMESPACE"
    wait_for_pod "app=postgres,role=provider" 120
}

###############################################################################
# Deploy Consumer PostgreSQL (PostGIS)
###############################################################################
deploy_consumer_postgres() {
    log "=== Deploying Consumer PostgreSQL + PostGIS ==="
    kubectl apply -f "${INFRA_DIR}/modules/postgres/consumer-postgres.yaml" -n "$NAMESPACE"
    wait_for_pod "app=postgres,role=consumer" 120
}

###############################################################################
# Deploy Issuer PostgreSQL (PostGIS)
###############################################################################
deploy_issuer_postgres() {
    log "=== Deploying Issuer PostgreSQL + PostGIS ==="
    kubectl apply -f "${INFRA_DIR}/modules/postgres/issuer-postgres.yaml" -n "$NAMESPACE"
    wait_for_pod "app=postgres,role=issuer" 120
}

###############################################################################
# Verify
###############################################################################
verify() {
    log "=== Verifying PostgreSQL Deployments ==="
    kubectl get pods -n "$NAMESPACE" -l app=postgres
    kubectl get svc -n "$NAMESPACE" -l app=postgres
    kubectl get pvc -n "$NAMESPACE"
    log "=== Phase 1 Step 3 COMPLETE ==="
}

###############################################################################
# Main
###############################################################################
main() {
    log "=========================================="
    log "EDC Gaia-X Phase 1: PostgreSQL Deployment"
    log "=========================================="

    deploy_provider_postgres
    deploy_consumer_postgres
    deploy_issuer_postgres
    verify

    log "=========================================="
    log "DONE. Next: Run 04-build-and-deploy-edc.sh"
    log "=========================================="
}

main "$@"
