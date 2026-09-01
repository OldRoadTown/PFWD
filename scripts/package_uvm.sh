#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE_DIR="${ROOT_DIR}/out"
BUNDLE_FILE="${BUNDLE_DIR}/PFWD_uvm_src.tar.gz"

mkdir -p "${BUNDLE_DIR}"
tar -C "${ROOT_DIR}" -czf "${BUNDLE_FILE}" \
  env tc th sim/files.f docs/intranet.md

echo "Created ${BUNDLE_FILE}"
