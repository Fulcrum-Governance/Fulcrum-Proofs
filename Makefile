.PHONY: sync-contracts contracts-check proof-gate model-gate bench-gate bench-nightly fault-gate evidence-gate audit-gate

PYTHON ?= python3
BENCH_MANIFEST ?= benchmarks/manifests/benchmark_manifest.yaml
BENCH_SCHEMA ?= benchmarks/reports/benchmark_run.schema.json
BENCH_SUITE_SCHEMA ?= benchmarks/reports/benchmark_suite.schema.json
BENCH_REPORT_DIR ?= benchmarks/raw
FAULT_SCHEMA ?= fault/reports/fault_campaign.schema.json
FAULT_REPORT_DIR ?= fault/raw
BENCH_WORKLOADS := durable-governed-path non-durable-fast-path finops-sensitivity-sweep
FAULT_SCENARIOS := revocation_delay version_skew stale_replay clock_skew

sync-contracts:
	./contracts/sync/sync_contracts.sh --source /Users/td/ConceptDev/Projects/Fulcrum

contracts-check:
	$(PYTHON) contracts/sync/check_version_manifest.py

proof-gate:
	./proofs/lean/scripts/replay.sh

model-gate:
	./models/tla/scripts/run_tlc.sh

bench-gate:
	@set -euo pipefail; \
	mkdir -p "$(BENCH_REPORT_DIR)"; \
	for w in $(BENCH_WORKLOADS); do \
		out="$(BENCH_REPORT_DIR)/$${w}.json"; \
		$(PYTHON) benchmarks/harness/run_benchmarks.py --manifest "$(BENCH_MANIFEST)" --workload "$$w" --out "$$out"; \
		$(PYTHON) scripts/schema_check.py --schema "$(BENCH_SCHEMA)" --input "$$out"; \
	done

bench-nightly:
	@set -euo pipefail; \
	mkdir -p "$(BENCH_REPORT_DIR)"; \
	$(PYTHON) benchmarks/harness/run_benchmarks.py --manifest "$(BENCH_MANIFEST)" --out "$(BENCH_REPORT_DIR)/nightly-suite.json"; \
	$(PYTHON) scripts/schema_check.py --schema "$(BENCH_SUITE_SCHEMA)" --input "$(BENCH_REPORT_DIR)/nightly-suite.json"; \
	for f in "$(BENCH_REPORT_DIR)"/bench-*.json; do \
		$(PYTHON) scripts/schema_check.py --schema "$(BENCH_SCHEMA)" --input "$$f"; \
	done

fault-gate:
	@set -euo pipefail; \
	mkdir -p "$(FAULT_REPORT_DIR)"; \
	for s in $(FAULT_SCENARIOS); do \
		out="$(FAULT_REPORT_DIR)/$${s}.json"; \
		$(PYTHON) fault/injectors/run_fault_campaign.py --scenario "fault/scenarios/$${s}.yaml" --out "$$out" --strict; \
		$(PYTHON) scripts/schema_check.py --schema "$(FAULT_SCHEMA)" --input "$$out"; \
	done

evidence-gate:
	$(PYTHON) contracts/sync/check_version_manifest.py
	$(PYTHON) scripts/evidence_gate.py

audit-gate:
	$(PYTHON) scripts/audit_gate.py
