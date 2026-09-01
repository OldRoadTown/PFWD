#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIM="${SIM:-vcs}"
LANE_NUM="${LANE_NUM:-4}"
TC="${TC:-smoke}"
TC_FILE="${TC_FILE:-${ROOT_DIR}/tc/${TC}.sv}"
SEED="${SEED:-$(( ( $(date +%s) ^ $$ ^ RANDOM ) & 0x7fffffff ))}"
RTL_KIND="${RTL_KIND:-candidate}"
RESULTS_ROOT="${RESULTS_ROOT:-${ROOT_DIR}/out}"
BUILD_DIR="${BUILD_DIR:-${RESULTS_ROOT}/build/${SIM}/${RTL_KIND}/lane${LANE_NUM}/${TC}}"
RUN_DIR="${RUN_DIR:-${RESULTS_ROOT}/runs/${RTL_KIND}/lane${LANE_NUM}/${TC}/seed_${SEED}}"
REAL_DUT="${REAL_DUT:-1}"
USE_REAL_VIP="${USE_REAL_VIP:-1}"
FORCE_COMPILE="${FORCE_COMPILE:-0}"
CASE_TIMEOUT_SECONDS="${CASE_TIMEOUT_SECONDS:-1740}"
CASE_START_SECONDS=${SECONDS}
if [[ -z "${COVERAGE+x}" ]]; then
  if [[ "${LANE_NUM}" == "4" ]]; then COVERAGE=1; else COVERAGE=0; fi
fi
read -r -a EXTRA_PLUSARGS <<< "${SIM_PLUSARGS:-}"
COMMON_PLUSARGS=("+PFE_TC_NAME=${TC}"
                 "+PFE_PERF_FILE=${RUN_DIR}/pfe_perf.csv")

if (( LANE_NUM < 3 || LANE_NUM > 7 )); then
  echo "LANE_NUM must be in [3:7]" >&2
  exit 2
fi

if [[ ! -f "${TC_FILE}" ]]; then
  echo "TC_FILE=${TC_FILE} does not exist" >&2
  exit 2
fi

mkdir -p "${BUILD_DIR}" "${RUN_DIR}"

DEFINES=("+define+PFE_LANE_NUM=${LANE_NUM}")
INCDIRS=()
EXTRA_FILES=()

if [[ "${REAL_DUT}" == "1" ]]; then
  DEFINES+=("+define+PFE_REAL_DUT")
  DUT_BIND_DIR="${DUT_BIND_DIR:-${ROOT_DIR}/th}"
  if [[ ! -f "${DUT_BIND_DIR}/dut_bind.svh" ]]; then
    echo "${DUT_BIND_DIR}/dut_bind.svh is missing" >&2
    exit 2
  fi
  INCDIRS+=("+incdir+${DUT_BIND_DIR}")
fi

if [[ "${USE_REAL_VIP}" == "1" ]]; then
  if [[ -z "${VIP_DIR:-}" || ! -f "${VIP_DIR}/data_caculate_vip.sv" ]]; then
    echo "VIP_DIR must contain data_caculate_vip.sv" >&2
    exit 2
  fi
  DEFINES+=("+define+PFE_USE_REAL_DATA_VIP")
  INCDIRS+=("+incdir+${VIP_DIR}")
fi

if [[ -n "${DUT_FILELIST:-}" ]]; then
  if [[ ! -f "${DUT_FILELIST}" ]]; then
    echo "DUT_FILELIST=${DUT_FILELIST} does not exist" >&2
    exit 2
  fi
  EXTRA_FILES+=("-f" "${DUT_FILELIST}")
elif [[ "${REAL_DUT}" == "1" ]]; then
  echo "DUT_FILELIST is required for a real DUT run" >&2
  exit 2
fi

echo "PFE_RUN sim=${SIM} rtl=${RTL_KIND} lanes=${LANE_NUM} tc=${TC_FILE} seed=${SEED}"
echo "PFE_RUN_DIR ${RUN_DIR}"

cd "${ROOT_DIR}"

run_limited() {
  local elapsed=$((SECONDS - CASE_START_SECONDS))
  local remaining=$((CASE_TIMEOUT_SECONDS - elapsed))
  if (( remaining <= 0 )); then
    echo "TIMEOUT: PFE case exceeded ${CASE_TIMEOUT_SECONDS} seconds" >&2
    return 124
  fi
  python3 "${ROOT_DIR}/scripts/with_timeout.py" \
    --seconds "${remaining}" -- "$@"
}

compile_vcs() {
  run_limited vcs -full64 -sverilog -ntb_opts uvm-1.2 -timescale=1ns/1ps \
    -assert enable_diag -cm assert+branch+cond+fsm+line+tgl \
    "${DEFINES[@]}" "${INCDIRS[@]}" "${EXTRA_FILES[@]}" \
    -f sim/files.f "${TC_FILE}" th/harness.sv -Mdir="${BUILD_DIR}/csrc" \
    -o "${BUILD_DIR}/simv" -l "${BUILD_DIR}/compile.log"
}

run_vcs() {
  local cov_args=()
  if [[ "${COVERAGE}" == "1" ]]; then
    cov_args=(-cm assert+branch+cond+fsm+line+tgl -cm_dir "${RUN_DIR}/cov.vdb")
  fi
  run_limited /usr/bin/time -p "${BUILD_DIR}/simv" \
    "${COMMON_PLUSARGS[@]}" +ntb_random_seed="${SEED}" \
    "${cov_args[@]}" "${EXTRA_PLUSARGS[@]}" \
    -l "${RUN_DIR}/sim.log" 2>"${RUN_DIR}/cpu_time.log"
}

compile_xrun() {
  run_limited xrun -64bit -uvm -sv -compile -timescale 1ns/1ps \
    -assert -coverage all -xmlibdirname "${BUILD_DIR}/xcelium.d" \
    "${DEFINES[@]}" "${INCDIRS[@]}" "${EXTRA_FILES[@]}" \
    -f sim/files.f "${TC_FILE}" th/harness.sv -l "${BUILD_DIR}/compile.log"
}

run_xrun() {
  local cov_args=()
  if [[ "${COVERAGE}" == "1" ]]; then
    cov_args=(-coverage all -covtest "${TC}_${SEED}" -covworkdir "${RUN_DIR}/cov")
  fi
  run_limited /usr/bin/time -p xrun -64bit -R -xmlibdirname "${BUILD_DIR}/xcelium.d" \
    -svseed "${SEED}" "${COMMON_PLUSARGS[@]}" \
    "${cov_args[@]}" "${EXTRA_PLUSARGS[@]}" \
    -l "${RUN_DIR}/sim.log" 2>"${RUN_DIR}/cpu_time.log"
}

compile_questa() {
  rm -rf "${BUILD_DIR}/work"
  run_limited vlib "${BUILD_DIR}/work"
  run_limited vlog -64 -sv -mfcu -work "${BUILD_DIR}/work" +cover=sbecft \
    "${DEFINES[@]}" "${INCDIRS[@]}" "${EXTRA_FILES[@]}" \
    -f sim/files.f "${TC_FILE}" th/harness.sv -l "${BUILD_DIR}/compile.log"
}

run_questa() {
  run_limited /usr/bin/time -p vsim -64 -c -coverage -assertcover \
    -work "${BUILD_DIR}/work" -sv_seed "${SEED}" harness \
    "${COMMON_PLUSARGS[@]}" \
    "${EXTRA_PLUSARGS[@]}" \
    -do "run -all; coverage save -assert -codeAll ${RUN_DIR}/coverage.ucdb; quit -f" \
    -l "${RUN_DIR}/sim.log" 2>"${RUN_DIR}/cpu_time.log"
}

case "${SIM}" in
  vcs)
    if [[ "${FORCE_COMPILE}" == "1" || ! -x "${BUILD_DIR}/simv" ]]; then compile_vcs; fi
    run_vcs
    ;;
  xrun)
    if [[ "${FORCE_COMPILE}" == "1" || ! -d "${BUILD_DIR}/xcelium.d" ]]; then compile_xrun; fi
    run_xrun
    ;;
  questa)
    if [[ "${FORCE_COMPILE}" == "1" || ! -d "${BUILD_DIR}/work" ]]; then compile_questa; fi
    run_questa
    ;;
  *)
    echo "Unsupported SIM=${SIM}; supported: vcs, xrun, questa" >&2
    exit 2
    ;;
esac

echo "PFE_PASS lanes=${LANE_NUM} tc=${TC} seed=${SEED}"
