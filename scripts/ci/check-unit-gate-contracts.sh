#!/usr/bin/env bash
# Single owner of the cheap per-merge repo-hygiene contract checks: the
# known-failures unit-gate baseline growth/integrity gate and its wiring
# contract tests (#15646), the orphaned-test-file reachability guard (#16013),
# and the emit failing-row direction gate's own contract tests (#16171). Both
# the ci.yml cheap-guards step and full-ci.sh run_lint invoke this script, so
# the two tiers cannot drift.
#
# The emit gate itself only runs nightly, so its wiring has to be checked on
# every merge — otherwise a break in the gate is invisible for a day, which is
# the failure mode #16171 is about.
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

growth_args=(--fetch-base)
if [[ -z "${CI:-}" ]]; then
  growth_args+=(--allow-unavailable-base)
fi
python3 scripts/ci/check-known-failures-growth.py "${growth_args[@]}"
python3 scripts/ci/test_check_known_failures_growth.py
python3 scripts/ci/test_unit_nextest.py
python3 scripts/ci/test_full_ci_unit_gate.py
node scripts/ci/test-known-failures-check.mjs
python3 scripts/ci/check-test-file-reachability.py
python3 scripts/ci/test_check_test_file_reachability.py
python3 scripts/ci/test_check_emit_regression_set.py

# Temporary PR-only validation for tsz-org/tsz#17570. Test the resolver fix
# without the earlier rough-partial workaround.
git show 50b76b85e2a8f3b9c0225e4fdcf2588d259611b4:crates/tsz-checker/src/types/class_type/constructor_parts/rough_partial.rs > crates/tsz-checker/src/types/class_type/constructor_parts/rough_partial.rs
python3 - <<'PY'
from pathlib import Path
p = Path('crates/tsz-checker/src/context/resolver.rs')
s = p.read_text()
old = '''            if !is_atomics\n                && !has_local_symbol_collision\n                && let Some(ty) = self.symbol_types.get(&sym_id)\n            {\n'''
new = '''            let symbol_is_class = matches!(def_kind, Some(DefKind::Class))\n                || self\n                    .binder\n                    .symbols\n                    .get(sym_id)\n                    .is_some_and(|symbol| symbol.has_any_flags(symbol_flags::CLASS));\n            if !is_atomics\n                && !has_local_symbol_collision\n                // A Lazy class reference denotes the INSTANCE side. `symbol_types`\n                // holds the class VALUE/constructor side, so never use that cache\n                // as a type-position resolution for a class-shaped symbol.\n                && !symbol_is_class\n                && let Some(ty) = self.symbol_types.get(&sym_id)\n            {\n'''
if old not in s:
    raise SystemExit('resolver anchor not found')
s = s.replace(old, new, 1)
p.write_text(s)
PY
cargo test -p tsz-cli cross_file_class_namespace_merge_value_keeps_call_signature_in_import_cycle -- --nocapture
cargo test -p tsz-cli export_default_class_function_property_constraints_see_instance_members -- --nocapture
echo 'BEGIN_RESOLVER_BASE64'
base64 -w0 crates/tsz-checker/src/context/resolver.rs
echo
echo 'END_RESOLVER_BASE64'
