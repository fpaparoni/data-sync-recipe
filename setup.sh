#!/usr/bin/env bash
SKIP_ARGO=false
ARGO_NS="argo-workflows"
ARGO_VERSION="v3.5.8"

for arg in "$@"; do
  [[ "$arg" == "--skip-argo" ]] && SKIP_ARGO=true
done

# ── Step 0: Install Argo Workflows ──────────────────────────────────
if $SKIP_ARGO; then
  echo "▸ Skipping Argo Workflows installation (--skip-argo)"
else
  echo "▸ Installing Argo Workflows in namespace '${ARGO_NS}'..."

  kubectl create namespace "${ARGO_NS}" --dry-run=client -o yaml | kubectl apply -f -

  # Official quick-start manifest (pins a stable release).
  # The upstream install.yaml has "namespace: argo" hardcoded, so we rewrite
  # it to match ARGO_NS before applying.
  curl -sSL "https://github.com/argoproj/argo-workflows/releases/download/${ARGO_VERSION}/install.yaml" \
    | sed "s/namespace: argo$/namespace: ${ARGO_NS}/g" \
    | kubectl apply -n "${ARGO_NS}" -f -

  echo "  Waiting for Argo server to be ready (this takes ~60s)..."
  kubectl wait deployment argo-server \
    -n "${ARGO_NS}" \
    --for=condition=Available \
    --timeout=180s

  echo "  ✓ Argo Workflows ${ARGO_VERSION} installed in '${ARGO_NS}'"

  # Patch auth mode to server (no login required for local testing)
  kubectl patch deployment argo-server \
    -n "${ARGO_NS}" \
    --type='json' \
    -p='[{"op":"replace","path":"/spec/template/spec/containers/0/args","value":["server","--auth-mode=server"]}]' \
    2>/dev/null || true
  
  echo "▸ Applying namespace and RBAC..."
  kubectl apply -f "argo-workflows/namespace.yaml"
  kubectl apply -f "argo-workflows/rbac/serviceaccount.yaml"
  kubectl apply -f "argo-workflows/rbac/clusterrolebinding.yaml"
  echo "  ✓ Namespace '${ARGO_NS}' and RBAC ready"
fi
echo ""

set -euo pipefail
# ── Step 1 - Component ClusterWorkflowTemplates ──────────────────────
echo "▸ Applying component ClusterWorkflowTemplates..."
for tmpl in "workflowtemplates/01-components"/*.yaml; do
  echo "  → $(basename "${tmpl}")"
  kubectl apply -f "${tmpl}"
done
echo ""

# ── Step 2 - Integrations ClusterWorkflowTemplates ──────────────────────
echo "▸ Applying component ClusterWorkflowTemplates..."
for tmpl in "workflowtemplates/02-integrations"/*.yaml; do
  echo "  → $(basename "${tmpl}")"
  kubectl apply -f "${tmpl}"
done
echo ""

# ── Step 3 - Smoke tests ClusterWorkflowTemplates ──────────────────────
echo "▸ Applying component ClusterWorkflowTemplates..."
for tmpl in "workflowtemplates/03-smoke-tests"/*.yaml; do
  echo "  → $(basename "${tmpl}")"
  kubectl apply -f "${tmpl}"
done
echo ""