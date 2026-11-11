#!/usr/bin/env bash
set -euo pipefail

readonly HELM_IMAGE=${HELM_IMAGE:-ghcr.io/appuio/helm-v4}
# renovate: datasource=docker depName=ghcr.io/appuio/helm-v4
DEFAULT_HELM_VERSION=4.3.0
readonly HELM_VERSION=${HELM_VERSION:-$DEFAULT_HELM_VERSION}

exec docker run --rm -i --user "$(id -u)" \
  --volume "$PWD":/app --workdir /app \
  --volume "$HOME/.kube:/tmp/.kube" \
  --env KUBECONFIG=/tmp/.kube/config \
  "$HELM_IMAGE:$HELM_VERSION" helm "$@"
