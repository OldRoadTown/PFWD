#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v h_regress >/dev/null 2>&1; then
  echo "h_regress is not available on PATH; run this entry point in the internal environment" >&2
  exit 127
fi

# h_regress is site-specific. H_REGRESS_ARGS must point it at a site config
# whose case command is scripts/h_regress_case.sh and whose matrix comes from
# tc/testlist.csv. No seed is supplied by this repository.
if [[ -z "${H_REGRESS_ARGS:-}" ]]; then
  echo "Set H_REGRESS_ARGS to the internal h_regress configuration arguments." >&2
  echo "Manifest: ${ROOT_DIR}/tc/testlist.csv" >&2
  exit 2
fi

cd "${ROOT_DIR}"
# Intentional word splitting: internal h_regress accepts a site-defined option
# string which cannot be known outside the intranet.
# shellcheck disable=SC2086
exec h_regress ${H_REGRESS_ARGS}
