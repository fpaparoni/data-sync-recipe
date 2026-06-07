#!/bin/bash
#############################################
# REQUIRED INPUTS (from Argo / Recipe)
#############################################
# NAMESPACE: target Kubernetes namespace
# PASSWORD: password for Redis
set -euo pipefail
source /scripts/lib/setup-kubeconfig.sh

echo "▸ Verifying Redis in '${NAMESPACE}'..."

echo "  1/3 Waiting for pod readiness..."
kubectl wait pod \
  -l app.kubernetes.io/name=redis \
  -n "${NAMESPACE}" \
  --for=condition=Ready \
  --timeout=120s
echo "  ✓ Pod ready"

echo "  2/3 Checking service..."
kubectl get svc redis-master -n "${NAMESPACE}" --no-headers
echo "  ✓ Service exists"

echo "  3/3 Running PING..."
# Recupera solo il nome del Pod Master chiudendo correttamente la sintassi
POD=$(kubectl get pod -n "${NAMESPACE}" \
  -l app.kubernetes.io/name=redis,app.kubernetes.io/component=master \
  -o jsonpath='{.items[0].metadata.name}')

# Esegue il PING usando la variabile $PASSWORD già presente nell'ambiente
kubectl exec -n "${NAMESPACE}" "${POD}" -- \
  bash -c "redis-cli -a '${PASSWORD}' PING" | grep -q PONG
echo "  ✓ Redis reachable"

echo "✓ Redis verification passed"
