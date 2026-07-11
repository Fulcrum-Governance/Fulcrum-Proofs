.PHONY: sync-contracts contracts-check orchestrator-contract-check orchestrator-run proof-gate model-gate bench-gate bench-nightly fault-gate evidence-gate audit-gate

SHELL := /bin/bash

PYTHON ?= python3
BENCH_MANIFEST ?= benchmarks/manifests/benchmark_manifest.yaml
BENCH_SCHEMA ?= benchmarks/reports/benchmark_run.schema.json
BENCH_SUITE_SCHEMA ?= benchmarks/reports/benchmark_suite.schema.json
BENCH_REPORT_DIR ?= benchmarks/raw
FAULT_SCHEMA ?= fault/reports/fault_campaign.schema.json
FAULT_REPORT_DIR ?= fault/raw
BENCH_WORKLOADS := durable-governed-path non-durable-fast-path finops-sensitivity-sweep
FAULT_SCENARIOS := revocation_delay version_skew stale_replay clock_skew
BENCH_USE_EXISTING ?= 0
FAULT_USE_EXISTING ?= 0

sync-contracts:
	./contracts/sync/sync_contracts.sh

contracts-check:
	$(PYTHON) contracts/sync/check_version_manifest.py

orchestrator-contract-check:
	CHECK_ORCHESTRATION_OUTPUTS=1 $(PYTHON) skills/scripts/validate_orchestration_contract.py

orchestrator-run:
	$(PYTHON) scripts/orchestrator_run.py

proof-gate:
	./proofs/lean/scripts/replay.sh

probe-gate:
	./proofs/lean/scripts/probe_gate.sh

model-gate:
	./models/tla/scripts/run_tlc.sh

bench-gate:
	@set -euo pipefail; \
	mkdir -p "$(BENCH_REPORT_DIR)"; \
	if [[ "$(BENCH_USE_EXISTING)" == "1" ]]; then \
		for w in $(BENCH_WORKLOADS); do \
			out="$(BENCH_REPORT_DIR)/$${w}.json"; \
			test -f "$$out"; \
			$(PYTHON) scripts/schema_check.py --schema "$(BENCH_SCHEMA)" --input "$$out"; \
		done; \
	else \
		for w in $(BENCH_WORKLOADS); do \
			out="$(BENCH_REPORT_DIR)/$${w}.json"; \
			$(PYTHON) benchmarks/harness/run_benchmarks.py --manifest "$(BENCH_MANIFEST)" --commit "$$(git rev-parse HEAD)" --env "bench-gate" --workload "$$w" --out "$$out"; \
			$(PYTHON) scripts/schema_check.py --schema "$(BENCH_SCHEMA)" --input "$$out"; \
		done; \
	fi

bench-nightly:
	@set -euo pipefail; \
	mkdir -p "$(BENCH_REPORT_DIR)"; \
	if [[ "$(BENCH_USE_EXISTING)" == "1" ]]; then \
		test -f "$(BENCH_REPORT_DIR)/nightly-suite.json"; \
		$(PYTHON) scripts/schema_check.py --schema "$(BENCH_SUITE_SCHEMA)" --input "$(BENCH_REPORT_DIR)/nightly-suite.json"; \
		for w in $(BENCH_WORKLOADS); do \
			$(PYTHON) scripts/schema_check.py --schema "$(BENCH_SCHEMA)" --input "$(BENCH_REPORT_DIR)/$${w}.json"; \
		done; \
	else \
		$(PYTHON) benchmarks/harness/run_benchmarks.py --manifest "$(BENCH_MANIFEST)" --commit "$$(git rev-parse HEAD)" --env "bench-nightly" --out "$(BENCH_REPORT_DIR)/nightly-suite.json"; \
		$(PYTHON) scripts/schema_check.py --schema "$(BENCH_SUITE_SCHEMA)" --input "$(BENCH_REPORT_DIR)/nightly-suite.json"; \
		for f in "$(BENCH_REPORT_DIR)"/bench-*.json; do \
			$(PYTHON) scripts/schema_check.py --schema "$(BENCH_SCHEMA)" --input "$$f"; \
		done; \
	fi

fault-gate:
	@set -euo pipefail; \
	mkdir -p "$(FAULT_REPORT_DIR)"; \
	if [[ "$(FAULT_USE_EXISTING)" == "1" ]]; then \
		for s in $(FAULT_SCENARIOS); do \
			out="$(FAULT_REPORT_DIR)/$${s}.json"; \
			test -f "$$out"; \
			$(PYTHON) scripts/schema_check.py --schema "$(FAULT_SCHEMA)" --input "$$out"; \
		done; \
	else \
		for s in $(FAULT_SCENARIOS); do \
			out="$(FAULT_REPORT_DIR)/$${s}.json"; \
			$(PYTHON) fault/injectors/run_fault_campaign.py --scenario "fault/scenarios/$${s}.yaml" --out "$$out" --strict; \
			$(PYTHON) scripts/schema_check.py --schema "$(FAULT_SCHEMA)" --input "$$out"; \
		done; \
	fi

evidence-gate:
	$(PYTHON) contracts/sync/check_version_manifest.py
	$(PYTHON) skills/scripts/validate_orchestration_contract.py
	$(PYTHON) scripts/evidence_gate.py

audit-gate:
	$(PYTHON) scripts/audit_gate.py
	$(PYTHON) scripts/review_gate.py
