SHELL := /bin/bash

.PHONY: lint lint-rtl lint-bind lint-uvm lint-topologies smoke regress bundle perf-compare summarize clean

LANE_NUM ?= auto
TC ?= smoke
SIM ?= vcs

lint: lint-rtl lint-bind lint-uvm

lint-rtl:
	verilator --lint-only --timing --assert -Wall -Wno-fatal \
		-Wno-PROCASSINIT -Wno-UNUSEDSIGNAL -Wno-SYNCASYNCNET \
		-Itools/lint -Ienv -Ith \
		--top-module lint_top \
		tools/lint/uvm_pkg.sv env/pfe_if.sv env/protocol_sva.sv \
		th/dut_adapter.sv tools/lint/lint_top.sv

lint-bind:
	verilator --lint-only --timing --assert -Wall -Wno-fatal \
		-Wno-PROCASSINIT -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-Wno-SYNCASYNCNET -DPFE_REAL_DUT -DLANE_4 \
		-DLANE_WIDTH=3:0 -Ienv -Ith -Itools/lint \
		--top-module lint_top tools/lint/EXAM2021_TOP.sv \
		tools/lint/uvm_pkg.sv env/pfe_if.sv env/protocol_sva.sv th/dut_adapter.sv \
		tools/lint/lint_top.sv

lint-uvm:
	verilator --lint-only --timing -Wall -Wno-fatal \
		-Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-Wno-COVERIGN -Wno-VARHIDDEN -Wno-UNDRIVEN -Wno-PROCASSINIT \
		-Wno-SYNCASYNCNET -Wno-IMPURE --assert \
		-Itools/lint -Ienv -Itc -Ith \
		--top-module harness \
		env/pfe_if.sv tools/lint/uvm_pkg.sv \
		env/env_pkg.sv env/protocol_sva.sv tc/tc_pkg.sv \
		th/dut_adapter.sv th/harness.sv

lint-topologies:
	@for lane in 3 4 5 6 7; do \
		echo "Linting automatic RTL LANE_$$lane selection"; \
		verilator --lint-only --timing --assert -Wno-fatal \
			-Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
			-Wno-COVERIGN -Wno-VARHIDDEN -Wno-UNDRIVEN -Wno-PROCASSINIT \
			-Wno-SYNCASYNCNET -Wno-IMPURE -DLANE_$$lane \
			-Itools/lint -Ienv -Itc -Ith --top-module harness \
			env/pfe_if.sv tools/lint/uvm_pkg.sv \
			env/env_pkg.sv env/protocol_sva.sv tc/tc_pkg.sv \
			th/dut_adapter.sv th/harness.sv || exit $$?; \
	done

smoke:
	SIM=$(SIM) LANE_NUM=$(LANE_NUM) TC=$(TC) ./scripts/run_test.sh

regress:
	./scripts/run_h_regress.sh

bundle:
	./scripts/package_uvm.sh

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
