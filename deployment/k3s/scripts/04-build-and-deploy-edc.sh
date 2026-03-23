#!/usr/bin/env bash
###############################################################################
# Phase 1 - Step 4: Build Docker Images and Deploy EDC via Terraform
#
# This script:
#   1. Builds the MVD Docker images with PostgreSQL persistence enabled
#   2. Imports images into K3s containerd (since K3s doesn't use Docker)
#   3. Runs Terraform to deploy all EDC components to the K3s cluster
#
# Prerequisites:
#   - K3s running (01-bootstrap-k3s.sh)
#   - Secrets created (02-create-secrets.sh)
#   - PostgreSQL deployed (03-deploy-databases.sh)
#   - Docker installed (for building images)
#   - Java 23+ installed (for Gradle build)
#
# Usage: bash 04-build-and-deploy-edc.sh
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}/../../.."
DEPLOY_DIR="${SCRIPT_DIR}/.."
LOG_FILE="${SCRIPT_DIR}/build-and-deploy.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

###############################################################################
# 1. Build MVD Docker images with persistence support
###############################################################################
build_images() {
    log "=== Building EDC Docker images with PostgreSQL persistence ==="

    cd "$PROJECT_ROOT"

    # Build with -Ppersistence=true to include PostgreSQL SQL modules
    # This replaces the in-memory stores with proper database-backed ones
    ./gradlew -Ppersistence=true clean build -x test 2>&1 | tee -a "$LOG_FILE"

    log "Building Docker images..."
    ./gradlew -Ppersistence=true dockerize 2>&1 | tee -a "$LOG_FILE"

    log "Docker images built:"
    docker images | grep -E "(controlplane|dataplane|identity-hub|catalog-server|issuerservice)" | tee -a "$LOG_FILE"
}

###############################################################################
# 2. Import Docker images into K3s containerd
#    K3s uses containerd, not Docker, so we need to import the images
###############################################################################
import_images_to_k3s() {
    log "=== Importing Docker images into K3s containerd ==="

    local images=(
        "controlplane:latest"
        "dataplane:latest"
        "identity-hub:latest"
        "catalog-server:latest"
        "issuerservice:latest"
    )

    for img in "${images[@]}"; do
        log "Importing $img..."
        docker save "$img" | k3s ctr images import -
    done

    log "Images available in K3s:"
    k3s ctr images list | grep -E "(controlplane|dataplane|identity-hub|catalog-server|issuerservice)" | tee -a "$LOG_FILE"
}

###############################################################################
# 3. Deploy via Terraform
#    Uses the existing MVD Terraform modules (they deploy to 'mvd' namespace)
###############################################################################
deploy_terraform() {
    log "=== Deploying EDC components via Terraform ==="

    cd "${PROJECT_ROOT}/deployment"

    # Initialize Terraform
    terraform init

    # Plan the deployment
    terraform plan -out=tfplan

    # Apply
    terraform apply tfplan

    log "Terraform deployment complete"
}

###############################################################################
# 4. Deploy Traefik IngressRoutes (replacing KinD NGINX ingress)
###############################################################################
deploy_ingress_routes() {
    log "=== Deploying Traefik IngressRoutes ==="

    kubectl apply -f "${DEPLOY_DIR}/ingress/ingress-routes.yaml" -n mvd

    log "IngressRoutes deployed"
    kubectl get ingressroute -n mvd 2>/dev/null || kubectl get ingress -n mvd
}

###############################################################################
# 5. Verify
###############################################################################
verify() {
    log "=== Verifying EDC Deployment ==="

    log "--- Pods ---"
    kubectl get pods -n mvd -o wide

    log "--- Services ---"
    kubectl get svc -n mvd

    log "--- Checking EDC health endpoints ---"
    local services=(
        "consumer-controlplane:8080"
        "provider-qna-controlplane:8080"
        "provider-manufacturing-controlplane:8080"
    )

    for svc in "${services[@]}"; do
        local name="${svc%%:*}"
        local port="${svc##*:}"
        local url="http://${name}.mvd.svc.cluster.local:${port}/api/check/liveness"
        log "Checking ${name}..."
        kubectl run --rm -i --restart=Never health-check-${name} \
            --image=curlimages/curl --namespace=mvd -- \
            curl -s --max-time 5 "$url" 2>/dev/null || log "  WARNING: ${name} not ready yet"
    done

    log "=== Phase 1 Step 4 COMPLETE ==="
}

###############################################################################
# Main
###############################################################################
main() {
    log "=========================================="
    log "EDC Gaia-X Phase 1: Build & Deploy EDC"
    log "=========================================="

    build_images
    import_images_to_k3s
    deploy_terraform
    deploy_ingress_routes
    verify

    log "=========================================="
    log "DONE. Run seed-k8s-gaiax.sh to seed data"
    log "=========================================="
}

main "$@"
