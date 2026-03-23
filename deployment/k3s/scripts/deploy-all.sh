#!/usr/bin/env bash
###############################################################################
# Master Deployment Orchestration Script
#
# Runs all Phase 1 deployment steps in sequence:
#   1. Bootstrap K3s + Ingress (Traefik, APISIX)
#   2. Create Kubernetes Secrets (replaces Vault)
#   3. Deploy PostgreSQL + PostGIS databases
#   4. Build EDC images and deploy via Terraform
#   5. Seed the dataspace with initial data
#
# This script automates the full Phase 1 from the Gaia-X blueprint:
# "Foundational Infrastructure and Base EDC Bootstrapping"
#
# Usage: sudo bash deploy-all.sh [--skip-build] [--skip-k3s]
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/deploy-all.log"

SKIP_BUILD=false
SKIP_K3S=false

for arg in "$@"; do
    case $arg in
        --skip-build) SKIP_BUILD=true ;;
        --skip-k3s)   SKIP_K3S=true ;;
        *)            echo "Unknown argument: $arg"; exit 1 ;;
    esac
done

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

run_step() {
    local step="$1"
    local script="$2"

    log "================================================================"
    log "  STEP ${step}: $(basename "$script")"
    log "================================================================"

    bash "$script" 2>&1 | tee -a "$LOG_FILE"

    log "  STEP ${step} COMPLETED"
    echo
}

###############################################################################
# Main
###############################################################################
main() {
    log "================================================================"
    log "  EDC GAIA-X DATASPACE - PHASE 1 FULL DEPLOYMENT"
    log "  Starting: $(date)"
    log "================================================================"
    echo

    # Step 1: K3s + Ingress
    if [[ "$SKIP_K3S" == "false" ]]; then
        run_step 1 "${SCRIPT_DIR}/01-bootstrap-k3s.sh"
    else
        log "SKIPPING Step 1 (K3s bootstrap) - --skip-k3s flag set"
    fi

    # Step 2: Kubernetes Secrets
    run_step 2 "${SCRIPT_DIR}/02-create-secrets.sh"

    # Step 3: PostgreSQL + PostGIS
    run_step 3 "${SCRIPT_DIR}/03-deploy-databases.sh"

    # Step 4: Build + Deploy EDC
    if [[ "$SKIP_BUILD" == "false" ]]; then
        run_step 4 "${SCRIPT_DIR}/04-build-and-deploy-edc.sh"
    else
        log "SKIPPING Step 4 (Build & Deploy) - --skip-build flag set"
    fi

    log "================================================================"
    log "  PHASE 1 DEPLOYMENT COMPLETE"
    log "================================================================"
    log ""
    log "  Next steps:"
    log "    1. Verify pods:  kubectl get pods -n mvd"
    log "    2. Seed data:    bash seed-k8s.sh"
    log "    3. Proceed to Phase 2 (Identity Layer)"
    log ""
    log "  Access points (via Traefik LoadBalancer):"
    log "    Consumer Management:  http://<NODE_IP>/consumer/cp/api/management"
    log "    Provider Q&A Mgmt:    http://<NODE_IP>/provider-qna/cp/api/management"
    log "    Provider Mfg Mgmt:    http://<NODE_IP>/provider-manufacturing/cp/api/management"
    log "    Catalog Server:       http://<NODE_IP>/provider-catalog-server/cp/api/management"
    log ""
    log "================================================================"
}

main
