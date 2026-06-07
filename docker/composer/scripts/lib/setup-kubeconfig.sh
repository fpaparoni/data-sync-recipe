#!/bin/bash
# Sets up kubectl in-cluster config when running inside a Kubernetes pod.
# Source this script at the beginning of any script that uses kubectl so that
# the tool never falls back to the default localhost:8080 endpoint.
SA_TOKEN_PATH=/var/run/secrets/kubernetes.io/serviceaccount/token
SA_CA_PATH=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt

if [ -f "${SA_TOKEN_PATH}" ]; then
  KUBE_SERVER="https://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}"
  kubectl config set-cluster in-cluster \
    --server="${KUBE_SERVER}" \
    --certificate-authority="${SA_CA_PATH}" >/dev/null
  kubectl config set-credentials sa \
    --token="$(cat "${SA_TOKEN_PATH}")" >/dev/null
  kubectl config set-context in-cluster \
    --cluster=in-cluster --user=sa >/dev/null
  kubectl config use-context in-cluster >/dev/null
fi
