#!/bin/sh

set -e

NAMESPACE="${1}"
BUCKET_SECRET=k8up-repo
ENCRYPTION_SECRET=backup-encryption

action="${2:-list}"

kubectl="kubectl"

secret_access_allowed=false
if kubectl -n "${NAMESPACE}" get secret "${BUCKET_SECRET}" > /dev/null 2>&1; then
  secret_access_allowed=true
fi

# VSHNeers don't have direct access to customer namespaces on openshift clusters..they need to impersonate an admin
if [ "${secret_access_allowed}" != "true" ] && kubectl --as system:admin -n "${NAMESPACE}" get secret "${BUCKET_SECRET}" > /dev/null 2>&1; then
  secret_access_allowed=true
  kubectl="kubectl --as system:admin"
fi

if [ "${secret_access_allowed}" != "true" ]; then
  printf "You don't have access to the secret %s in namespace %s\n" "${BUCKET_SECRET}" "${NAMESPACE}"
  exit 1
fi

# shellcheck disable=SC2046
export AWS_ACCESS_KEY_ID=$($kubectl -n "${NAMESPACE}" get secret "${BUCKET_SECRET}" -ogo-template='{{.data.AWS_ACCESS_KEY_ID|base64decode}}')
# shellcheck disable=SC2046
export AWS_SECRET_ACCESS_KEY=$($kubectl -n "${NAMESPACE}" get secret "${BUCKET_SECRET}" -ogo-template='{{.data.AWS_SECRET_ACCESS_KEY|base64decode}}')
# shellcheck disable=SC2046
export RESTIC_REPOSITORY=$($kubectl -n "${NAMESPACE}" get secret "${BUCKET_SECRET}" -ogo-template='s3:{{.data.ENDPOINT|base64decode}}/{{.data.BUCKET_NAME|base64decode}}')
# shellcheck disable=SC2046
export RESTIC_PASSWORD=$($kubectl -n "${NAMESPACE}" get secret "${ENCRYPTION_SECRET}" -ogo-template='{{.data.password|base64decode}}')
echo $RESTIC_REPOSITORY

if [ "$action" = "list" ]; then
  exec restic snapshots
fi

if [ "$action" = "restore-dump" ]; then
  restore_snapshot=${3:-latest}

  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "${tmp_dir}"' EXIT

  restic restore --path "/${NAMESPACE}-mongodb.archive" "${restore_snapshot}" --target "${tmp_dir}"
  ls -lah "${tmp_dir}"

  dump_file="$(find "${tmp_dir}" -type f -name '*.archive' | head -n 1)"
  if [ -z "${dump_file}" ]; then
    echo "No *.archive dump found in the latest snapshot" >&2
    exit 1
  fi

  any_pod="$($kubectl -n "${NAMESPACE}" get pods -l k8ify.service=mongodb -o jsonpath='{.items[0].metadata.name}')"
  # shellcheck disable=SC2016
  primary_host="$($kubectl -n "${NAMESPACE}" exec "${any_pod}" -- sh -c 'mongosh --quiet --username="$MONGODB_ROOT_USER" --password="$MONGODB_ROOT_PASSWORD" --authenticationDatabase admin --eval "db.hello().primary"' 2> /dev/null | tail -n 1)"
  if [ -z "${primary_host}" ]; then
    echo "Could not determine the replica set primary via pod ${any_pod}" >&2
    exit 1
  fi

  # hostname is <pod-name>.mongodb.<namespace>.svc.cluster.local[:27017]
  primary_host="${primary_host%%:*}"
  pod="${primary_host%%.*}"
  echo "Replica set primary is ${primary_host} (pod ${pod})"

  echo "Restoring ${dump_file} into pod ${pod} in namespace ${NAMESPACE}..."
  # shellcheck disable=SC2002
  # shellcheck disable=SC2016
  cat "${dump_file}" | $kubectl -n "${NAMESPACE}" exec -i "${pod}" -- sh -c 'mongorestore --username="$MONGODB_ROOT_USER" --password="$MONGODB_ROOT_PASSWORD" --drop --archive'
  echo "Restore complete."
fi
