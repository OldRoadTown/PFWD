#!/usr/bin/env bash
set -euo pipefail

# Adapter called once per case by the internal h_regress configuration.
# The variable aliases cover common scheduler naming conventions without
# placing a fixed seed in the checked-in regression manifest.
export TC="${TC:-${HREG_TC:-smoke}}"
export LANE_NUM="${LANE_NUM:-${HREG_LANE_NUM:-4}}"
export RTL_KIND="${RTL_KIND:-${HREG_RTL_KIND:-candidate}}"
export COVERAGE="${COVERAGE:-${HREG_COVERAGE:-}}"
export SEED="${SEED:-${HREG_SEED:-}}"
if [[ -z "${SEED}" ]]; then unset SEED; fi
if [[ -z "${COVERAGE}" ]]; then unset COVERAGE; fi

exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/run_test.sh"
