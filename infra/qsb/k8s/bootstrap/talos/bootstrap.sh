#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

ACTION=${1:-generate}

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
TALENV_FILE="${DIR}/talenv.sops.yaml"
TALSECRET_FILE="${DIR}/talsecret.sops.yaml"
TALCONFIG_FILE="${DIR}/talconfig.yaml"
CLUSTERCONFIG_DIR="${DIR}/clusterconfig"
APPS_DIR="${DIR}/../apps"
INTEGRATIONS_DIR="${DIR}/integrations"
export SOPS_AGE_KEY_FILE="${DIR}/../../../../age.key"

if [[ "$ACTION" == "generate" ]] || [[ "$ACTION" == "apply" ]]; then
  for var in DIR TALENV_FILE TALSECRET_FILE TALCONFIG_FILE APPS_DIR INTEGRATIONS_DIR SOPS_AGE_KEY_FILE; do
    if [[ ! -d "${!var}" && ! -f "${!var}" ]]; then
      echo "ERROR: ${var} is not a folder or file"
      exit 1
    fi
  done
  rm -rf "$CLUSTERCONFIG_DIR"

  talhelper genconfig --env-file "$TALENV_FILE" --secret-file "$TALSECRET_FILE" --config-file "$TALCONFIG_FILE" --out-dir "$CLUSTERCONFIG_DIR"
  export TALOSCONFIG_FILE="${CLUSTERCONFIG_DIR}/talosconfig.yaml"
fi

if [[ "$ACTION" == "apply" ]]; then
  NODES=$(yq e -o=j -I=0 '.nodes[]' "$TALCONFIG_FILE")

  while IFS=\= read -r action; do
    HOSTNAME=$(yq e '.hostname' <<<"$action" | cut -d . -f 1)
    IP_ADDRESS=$(yq e '.ipAddress' <<<"$action")
    echo "Applying config for $HOSTNAME ($IP_ADDRESS)"
    talosctl apply-config -i -n "$IP_ADDRESS" -f "$CLUSTERCONFIG_DIR"/*"${HOSTNAME}"*.yaml
  done <<EOF
$NODES
EOF
fi

if [[ "$ACTION" == "kustomize" ]]; then
  CNI="${INTEGRATIONS_DIR}/cni"
  CNI_CHARTS="${CNI}/charts"
  CNI_VALUES="${CNI}/values.yaml"

  rm -rf "${CNI_CHARTS}"
  envsubst <"${APPS_DIR}"/kube-system/cilium/app/values.yaml >"${CNI_VALUES}"
  kustomize build --enable-helm "${CNI}" | kubectl apply -f -
  rm "${CNI_VALUES}"
  rm -rf "${CNI_CHARTS}"

  KCA="${INTEGRATIONS_DIR}/kubelet-csr-approver"
  KCA_CHARTS="${KCA}/charts"
  KCA_VALUES="${KCA}/values.yaml"
  rm -rf "${KCA_CHARTS}"
  envsubst <"${APPS_DIR}"/system-controllers/kubelet-csr-approver/app/values.yaml >"${KCA_VALUES}"
  if ! kubectl get ns system-controllers >/dev/null 2>&1; then
    kubectl create ns system-controllers
  fi
  kustomize build --enable-helm "${KCA}" | kubectl apply -f -
  rm "${KCA_VALUES}"
  rm -rf "${KCA_CHARTS}"
fi
