#!/usr/bin/env bash
set -euo pipefail

readonly HELM_IMAGE=${HELM_IMAGE:-ghcr.io/appuio/helm-v4}
# renovate: datasource=docker depName=ghcr.io/appuio/helm-v4
DEFAULT_HELM_VERSION=4.3.0
readonly HELM_VERSION=${HELM_VERSION:-$DEFAULT_HELM_VERSION}
readonly CHARTSNAP_URL='https://github.com/jlandowner/helm-chartsnap'
readonly CHARTSNAP_VERSION='v0.6.0'

usage() {
  printf 'Usage: %s [--update]\n' "${0##*/}" >&2
  exit 2
}

update=()
case "$#" in
  0) ;;
  1)
    if [[ "$1" == --update ]]; then
      update=(--update-snapshot)
    else
      usage
    fi
    ;;
  *) usage ;;
esac

exec docker run --rm \
  --user "$(id -u):$(id -g)" \
  --volume "$PWD:/app" \
  --env HOME=/tmp/chartsnap-home \
  --env KUBECONFIG=/tmp/.kube/config \
  --env HELM_CONFIG_HOME=/tmp/helm/config \
  --env HELM_CACHE_HOME=/tmp/helm/cache \
  --env HELM_DATA_HOME=/tmp/helm/data \
  --env HELM_PLUGINS=/tmp/helm/plugins \
  --env "CHARTSNAP_URL=$CHARTSNAP_URL" \
  --env "CHARTSNAP_VERSION=$CHARTSNAP_VERSION" \
  --env NO_COLOR=1 \
  --workdir /app \
  --entrypoint sh \
  "$HELM_IMAGE:$HELM_VERSION" -eu -c '
    mkdir -p "$HOME" "$HELM_CONFIG_HOME" "$HELM_CACHE_HOME" "$HELM_DATA_HOME" "$HELM_PLUGINS"
    helm plugin install "$CHARTSNAP_URL" --version "$CHARTSNAP_VERSION" --verify=false
    exec helm chartsnap \
      --chart . \
      --values test/values \
      --release-name test \
      --namespace mongodb \
      --snapshot-version v3 \
      --parallelism 1 \
      --fail-helm-error \
      "$@"
  ' chartsnap "${update[@]}"
