#!/usr/bin/env bash
# teardown.sh — Remove everything the composer installed from the cluster.
#
# Usage:
#   bash scripts/teardown.sh --components   # remove postgres/redis/sync
#   bash scripts/teardown.sh --framework    # remove CWTs, workflow jobs
#   bash scripts/teardown.sh --argo         # uninstall Argo Workflows itself
#   bash scripts/teardown.sh --all          # remove everything
set -euo pipefail

ARGO_NS="argo-workflows"
ALL=false
COMPONENTS=false
FRAMEWORK=false
ARGO=false

for arg in "$@"; do
  case "$arg" in
    --all)        ALL=true; COMPONENTS=true; FRAMEWORK=true; ARGO=true ;;
    --components) COMPONENTS=true ;;
    --framework)  FRAMEWORK=true ;;
    --argo)       ARGO=true ;;
  esac
done

if ! $ALL && ! $COMPONENTS && ! $FRAMEWORK && ! $ARGO; then
  echo "Usage: $0 [--components] [--framework] [--argo] [--all]"
  echo ""
  echo "  --components  Remove installed components (postgres, redis, sync)"
  echo "  --framework   Remove ClusterWorkflowTemplates, workflow jobs"
  echo "  --argo        Uninstall RBAC and Argo Workflows from '${ARGO_NS}'"
  echo "  --all         Remove everything"
  exit 1
fi

echo "╔══════════════════════════════════════════╗"
echo "║      Composer — Teardown                 ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ── Components ──────────────────────────────────────────────────────
if $COMPONENTS; then
  echo "▸ Removing installed components..."
  helm uninstall postgresql -n postgres 2>/dev/null || true
  helm uninstall redis -n redis 2>/dev/null || true
  kubectl delete deployment -n postgres-redis-cache-integration postgres-redis-sync
  kubectl delete namespace postgresql --ignore-not-found
  kubectl delete namespace redis --ignore-not-found
  kubectl delete namespace postgres-redis-cache-integration --ignore-not-found
  echo "  ✓ Components removed"
  echo ""
fi

# ── Framework (CWTs + workflow jobs) ──────────────────────────
if $FRAMEWORK; then
  echo "▸ Deleting Workflow jobs in '${ARGO_NS}'..."
  kubectl delete workflows --all -n "${ARGO_NS}" --ignore-not-found
  echo "  ✓ Workflow jobs deleted"

  for tmpl in "workflowtemplates/01-components"/*.yaml; do
    echo "  → $(basename "${tmpl}")"
    kubectl delete -f "${tmpl}"
  done
  echo ""
fi

# ── Argo Workflows ───────────────────────────────────────────────────
if $ARGO; then
  echo "▸ Uninstalling Argo Workflows from '${ARGO_NS}'..."
  kubectl delete -f "argo-workflows/rbac/serviceaccount.yaml"
  kubectl delete -f "argo-workflows/rbac/clusterrolebinding.yaml"

  ARGO_VERSION="v3.5.8"
  kubectl delete -n "${ARGO_NS}" \
    -f "https://github.com/argoproj/argo-workflows/releases/download/${ARGO_VERSION}/install.yaml" \
    --ignore-not-found 2>/dev/null || true

  echo "  → Deleting namespace '${ARGO_NS}'..."
  kubectl delete namespace "${ARGO_NS}" --ignore-not-found

  echo "  ✓ Argo Workflows removed"
  echo ""
fi

echo "✓ Teardown complete"
