#!/usr/bin/env bash
###############################################################################
# Phase 1 - Step 1: Bootstrap K3s and Install Ingress Controllers
#
# Replaces the MVD KinD-based deployment with K3s for Fontys Netlab.
#
# This script:
#   1. Installs K3s (lightweight Kubernetes) with default Traefik disabled
#   2. Installs Helm 3 package manager
#   3. Creates the 'mvd' namespace (matching MVD conventions)
#   4. Deploys Traefik for external TLS/SSL termination
#   5. Deploys Apache APISIX as internal API gateway / PEP
#
# Prerequisites:
#   - Linux server (Ubuntu 20.04+ recommended) on Fontys Netlab
#   - Root or sudo access
#   - Internet connectivity
#   - VPN connectivity to Netlab established
#
# Usage: sudo bash 01-bootstrap-k3s.sh
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="${SCRIPT_DIR}/.."
LOG_FILE="${SCRIPT_DIR}/bootstrap-k3s.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log "ERROR: This script must be run as root (use sudo)"
        exit 1
    fi
}

###############################################################################
# 1. Install K3s (replaces KinD from MVD)
###############################################################################
install_k3s() {
    log "=== Installing K3s (lightweight Kubernetes) ==="

    if command -v k3s &>/dev/null; then
        log "K3s is already installed: $(k3s --version)"
    else
        # Install K3s with default Traefik DISABLED (we deploy our own)
        # --write-kubeconfig-mode 644: allow non-root kubectl access
        # --tls-san: add node IP to TLS cert for remote access
        curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
            --disable traefik \
            --write-kubeconfig-mode 644 \
            --tls-san $(hostname -I | awk '{print $1}') \
            --node-name edc-node-1" sh -

        log "Waiting for K3s node to become Ready..."
        local retries=30
        until kubectl get nodes 2>/dev/null | grep -q "Ready" || [[ $retries -eq 0 ]]; do
            sleep 2
            retries=$((retries - 1))
        done

        if [[ $retries -eq 0 ]]; then
            log "ERROR: K3s failed to become Ready within 60 seconds"
            exit 1
        fi

        log "K3s installed successfully: $(k3s --version)"
    fi

    # Set up kubeconfig for the current user and for Terraform
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    mkdir -p "$HOME/.kube"
    cp /etc/rancher/k3s/k3s.yaml "$HOME/.kube/config"
    chmod 600 "$HOME/.kube/config"

    kubectl get nodes -o wide
}

###############################################################################
# 2. Install Helm 3
###############################################################################
install_helm() {
    log "=== Installing Helm 3 ==="

    if command -v helm &>/dev/null; then
        log "Helm is already installed: $(helm version --short)"
        return 0
    fi

    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    log "Helm installed successfully: $(helm version --short)"
}

###############################################################################
# 3. Create MVD namespace (matches existing MVD Terraform config)
###############################################################################
create_namespace() {
    log "=== Creating 'mvd' namespace ==="

    if kubectl get namespace mvd &>/dev/null; then
        log "Namespace 'mvd' already exists"
    else
        kubectl create namespace mvd
        log "Created namespace: mvd"
    fi
}

###############################################################################
# 4. Deploy Traefik (External Ingress / TLS Termination)
#    Replaces NGINX ingress from MVD's KinD setup
###############################################################################
deploy_traefik() {
    log "=== Deploying Traefik Ingress Controller ==="

    helm repo add traefik https://traefik.github.io/charts 2>/dev/null || true
    helm repo update

    helm upgrade --install traefik traefik/traefik \
        --namespace kube-system \
        --values "${INFRA_DIR}/ingress/traefik-values.yaml" \
        --wait --timeout 180s

    log "Traefik deployed successfully"
    kubectl get svc -n kube-system -l app.kubernetes.io/name=traefik
}

###############################################################################
# 5. Deploy Apache APISIX (Internal API Gateway / PEP)
###############################################################################
deploy_apisix() {
    log "=== Deploying Apache APISIX API Gateway ==="

    helm repo add apisix https://charts.apiseven.com 2>/dev/null || true
    helm repo update

    helm upgrade --install apisix apisix/apisix \
        --namespace mvd \
        --values "${INFRA_DIR}/ingress/apisix-values.yaml" \
        --wait --timeout 180s

    log "Apache APISIX deployed successfully"
    kubectl get svc -n mvd -l app.kubernetes.io/name=apisix
}

###############################################################################
# 6. Install required CLI tools
###############################################################################
install_tools() {
    log "=== Checking required CLI tools ==="

    # jq
    if ! command -v jq &>/dev/null; then
        log "Installing jq..."
        apt-get update -qq && apt-get install -y -qq jq
    fi
    log "jq: $(jq --version)"

    # openssl
    if ! command -v openssl &>/dev/null; then
        log "Installing openssl..."
        apt-get update -qq && apt-get install -y -qq openssl
    fi
    log "openssl: $(openssl version)"

    # newman (for seed scripts)
    if ! command -v newman &>/dev/null; then
        if command -v npm &>/dev/null; then
            log "Installing newman via npm..."
            npm install -g newman
        else
            log "WARNING: npm not found. Install Node.js and run: npm install -g newman"
        fi
    fi

    # terraform
    if ! command -v terraform &>/dev/null; then
        log "Installing Terraform..."
        apt-get update -qq && apt-get install -y -qq gnupg software-properties-common
        curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
            > /etc/apt/sources.list.d/hashicorp.list
        apt-get update -qq && apt-get install -y -qq terraform
    fi
    log "terraform: $(terraform version -json | jq -r '.terraform_version')"
}

###############################################################################
# 7. Verify
###############################################################################
verify() {
    log "=== Verification ==="
    log "--- Nodes ---"
    kubectl get nodes -o wide
    log "--- Namespaces ---"
    kubectl get namespaces
    log "--- All pods ---"
    kubectl get pods --all-namespaces
    log "--- Services in mvd namespace ---"
    kubectl get svc -n mvd
    log "=== Phase 1 Step 1 COMPLETE ==="
}

###############################################################################
# Main
###############################################################################
main() {
    log "=========================================="
    log "EDC Gaia-X Phase 1: K3s Bootstrap"
    log "=========================================="

    check_root
    install_k3s
    install_helm
    install_tools
    create_namespace
    deploy_traefik
    deploy_apisix
    verify

    log "=========================================="
    log "DONE. Next: Run 02-create-secrets.sh"
    log "=========================================="
}

main "$@"
