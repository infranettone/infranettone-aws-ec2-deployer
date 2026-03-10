#!/bin/bash

set -euo pipefail

detect_awscli_arch() {
  local raw_arch="${DOCKER_DEFAULT_PLATFORM:-${TARGETPLATFORM:-}}"

  if [[ -z "${raw_arch}" ]]; then
    raw_arch="$(uname -m)"
  fi

  raw_arch="$(echo "${raw_arch}" | tr '[:upper:]' '[:lower:]')"

  case "${raw_arch}" in
    *amd64*|*x86_64*|*x86-64*|*x64*|*i386*|*i486*|*i586*|*i686*)
      echo "amd64"
      ;;
    *arm64*|*aarch64*|*armv8*|*armv9*|*arm*)
      echo "arm64"
      ;;
    *)
      # Fallback seguro para no bloquear el flujo en arquitecturas no contempladas.
      echo "amd64"
      ;;
  esac
}

AWSCLI_ARCH="$(detect_awscli_arch)"
echo "Arquitectura detectada para AWS CLI: ${AWSCLI_ARCH}"

DOCKER_GID="$(getent group docker | cut -d: -f3 || true)"
if [[ -z "${DOCKER_GID}" ]]; then
  DOCKER_GID="$(stat -c '%g' /var/run/docker.sock 2>/dev/null || true)"
fi

if [[ -z "${DOCKER_GID}" ]]; then
  echo "No se pudo detectar el GID de docker (grupo docker ni /var/run/docker.sock)." >&2
  exit 1
fi

DOCKER_GID="${DOCKER_GID}" AWSCLI_ARCH="${AWSCLI_ARCH}" docker compose -f main/docker-compose.yml up --build -d

time docker exec -it infranettone-aws-ec2-deployer bash main/run.sh
