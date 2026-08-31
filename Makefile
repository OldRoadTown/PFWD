SHELL := /bin/bash

.PHONY: lint lint-rtl lint-uvm lint-topologies smoke regress gen-bind perf-compare summarize clean

LANE_NUM ?= 4
TEST ?= pfe_smoke_test
SIM ?= vcs

lint: lint-rtl lint-uvm

lint-rtl:
	verilator --lint-only --timing --assert -Wall -Wno-fatal \
		-Wno-PROCASSINIT -Wno-UNUSEDSIGNAL -Wno-SYNCASYNCNET \
		-Itb -Itb/interfaces -Itb/integration \
		--top-module pfe_lint_top \
		tb/interfaces/pfe_if.sv tb/sva/pfe_protocol_sva.sv \
		tb/top/pfe_dut_adapter.sv \
		tb/top/pfe_lint_top.sv

lint-uvm:
	verilator --lint-only --timing -Wall -Wno-fatal \
		-Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-Wno-COVERIGN -Wno-VARHIDDEN -Wno-UNDRIVEN -Wno-PROCASSINIT \
		-Wno-SYNCASYNCNET -Wno-IMPURE --assert \
		-Itb/lint -Itb -Itb/interfaces -Itb/pkg -Itb/agents -Itb/env \
		-Itb/seq -Itb/tests -Itb/integration \
		--top-module pfe_tb_top \
		tb/interfaces/pfe_if.sv tb/lint/uvm_pkg.sv \
		tb/pkg/pfe_uvm_pkg.sv tb/sva/pfe_protocol_sva.sv \
		tb/top/pfe_dut_adapter.sv tb/top/pfe_tb_top.sv

lint-topologies:
	@for lane in 3 4 5 6 7; do \
		echo "Linting PFE_LANE_NUM=$$lane"; \
		verilator --lint-only --timing --assert -Wno-fatal \
			-Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
			-Wno-COVERIGN -Wno-VARHIDDEN -Wno-UNDRIVEN -Wno-PROCASSINIT \
			-Wno-SYNCASYNCNET -Wno-IMPURE -DPFE_LANE_NUM=$$lane \
			-Itb/lint -Itb -Itb/interfaces -Itb/pkg -Itb/agents -Itb/env \
			-Itb/seq -Itb/tests -Itb/integration --top-module pfe_tb_top \
			tb/interfaces/pfe_if.sv tb/lint/uvm_pkg.sv \
			tb/pkg/pfe_uvm_pkg.sv tb/sva/pfe_protocol_sva.sv \
			tb/top/pfe_dut_adapter.sv tb/top/pfe_tb_top.sv || exit $$?; \
	done

smoke:
	SIM=$(SIM) LANE_NUM=$(LANE_NUM) TEST=$(TEST) ./scripts/run_test.sh

regress:
	./scripts/run_h_regress.sh

gen-bind:
	@test -n "$(DUT_MODULE)" || (echo "DUT_MODULE is required"; exit 2)
	python3 scripts/gen_flat_bind.py --module "$(DUT_MODULE)" \
		--lanes "$(LANE_NUM)" --output tb/integration/pfe_dut_bind.svh

perf-compare:
	@test -n "$(GOLDEN)" || (echo "GOLDEN CSV/glob is required"; exit 2)
	@test -n "$(CANDIDATE)" || (echo "CANDIDATE CSV/glob is required"; exit 2)
	python3 scripts/compare_perf.py --golden "$(GOLDEN)" \
		--candidate "$(CANDIDATE)" --report out/perf_comparison.json

summarize:
	@test -n "$(RUNS)" || (echo "RUNS directory glob is required"; exit 2)
	python3 scripts/summarize_regression.py --runs "$(RUNS)" \
		--report out/regression_summary.json

clean:
	@echo "Remove ./out manually when its retained logs and coverage databases are no longer needed."
