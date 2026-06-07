#!/bin/bash
#############################################
# REQUIRED INPUTS (from Argo / Recipe)
#############################################
# NAMESPACE: target Kubernetes namespace
# PASSWORD: password for Postgres
# STORAGE: PVC size (e.g. 10Gi)

set -euo pipefail
source /scripts/lib/setup-kubeconfig.sh

echo "▸ Installing PostgreSQL in namespace '${NAMESPACE}'..."

kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

helm repo add bitnami https://charts.bitnami.com/bitnami --force-update
helm repo update bitnami

helm upgrade --install postgresql bitnami/postgresql \
  --namespace "${NAMESPACE}" \
  --set auth.postgresPassword="${PASSWORD}" \
  --set primary.persistence.size="${STORAGE}" \
  --wait --timeout 600s

echo "✓ PostgreSQL installed"
