#!/bin/bash
#############################################
# REQUIRED INPUTS (from Argo / Recipe)
#############################################
# NAMESPACE: target Kubernetes namespace
# PASSWORD: password for Redis
# STORAGE: PVC size (e.g. 10Gi)
# MAXMEMORY: Max memory used (e.g. 256mb)
set -euo pipefail
source /scripts/lib/setup-kubeconfig.sh

echo "▸ Installing Redis in namespace '${NAMESPACE}'..."

kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

helm repo add bitnami https://charts.bitnami.com/bitnami --force-update
helm repo update bitnami

helm upgrade --install redis bitnami/redis \
  --namespace "${NAMESPACE}" \
  --set auth.enabled=true \
  --set auth.password="${PASSWORD}" \
  --set master.persistence.size="${STORAGE}" \
  --set master.extraEnvVars[0].name=MAXMEMORY \
  --set master.extraEnvVars[0].value="${MAXMEMORY}" \
  --wait --timeout 600s

echo "✓ Redis installed"
