#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

required_files=(
  "docker-compose.yml"
  "kong.yml"
  ".env.example"
  "supabase/config.toml"
  "supabase/seed.sql"
  "supabase/migrations/20260615000100_oms_initial_normalized_schema.sql"
  "supabase/migrations/20260615000200_oms_create_staging_raw.sql"
  "supabase/migrations/20260615000300_oms_seed_reference_data.sql"
  "supabase/migrations/20260615000400_oms_transform_case_requests.sql"
  "supabase/migrations/20260615000500_oms_transform_reference_entities.sql"
  "supabase/migrations/20260615000600_oms_rls_baseline.sql"
  "supabase/migrations/20260625000100_oms_user_types_api.sql"
  "supabase/tests/001_migration_quality_checks.sql"
  "supabase/tests/002_user_types_api_checks.sql"
  "supabase/functions/oms-health/index.ts"
  "supabase/functions/_shared/cors.ts"
  "supabase/functions/user-types/index.ts"
  "docs/oms/legacy_to_canonical_mapping.csv"
  "docs/oms/table_to_entity_mapping.csv"
  "docs/oms/normalization_summary.json"
  "docs/oms/SECURITY_RLS.md"
  "docs/oms/MIGRATION_PIPELINE.md"
  "docs/oms/SUPABASE_COMPONENT_MATRIX.md"
  "docs/oms/OPERATIONS_CHECKLIST.md"
  "docs/oms/SUPABASE_2026_NOTES.md"
  "docs/oms/API_USER_TYPES_STUDENTS.md"
)

for file in "${required_files[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "Falta archivo requerido: $file" >&2
    exit 1
  fi
done

if grep -R --line-number --exclude-dir=.git --include='*.env' --include='*.toml' --include='*.yml' --include='*.md' \
  -E 'SERVICE_ROLE_KEY=eyJ|ANON_KEY=eyJ|sb_secret_|gho_[A-Za-z0-9_]+' .; then
  echo "Se detecto un posible secreto real. Revisa antes de commitear." >&2
  exit 1
fi

if grep -R --line-number --exclude-dir=.git --include='*.env' --include='*.toml' --include='*.md' \
  -E 'postgres://[^[:space:]'\"'']+:[^[:space:]'\"''@]{16,}@' . | grep -v 'CAMBIA\\|TU_PASSWORD\\|password\\|PASSWORD\\|\\${'; then
  echo "Se detecto un posible secreto real. Revisa antes de commitear." >&2
  exit 1
fi

python3 - <<'PY'
import csv
import json
from pathlib import Path

root = Path(".")
legacy = list(csv.DictReader((root / "docs/oms/table_to_entity_mapping.csv").open()))
fields = list(csv.DictReader((root / "docs/oms/legacy_to_canonical_mapping.csv").open()))
summary = json.loads((root / "docs/oms/normalization_summary.json").read_text())

assert len(legacy) == 1180, f"tablas legacy esperadas=1180 actuales={len(legacy)}"
assert len(fields) == 41460, f"campos mapeados esperados=41460 actuales={len(fields)}"
assert summary["legacy_tables"] == 1180, summary["legacy_tables"]
assert summary["legacy_columns"] == 41460, summary["legacy_columns"]
print("OMS mapping OK: 1,180 tablas legacy y 41,460 campos.")
PY

python3 - <<'PY'
from pathlib import Path

migration = Path("supabase/migrations/20260625000100_oms_user_types_api.sql").read_text()
required_fragments = [
    "CREATE TABLE IF NOT EXISTS oms.user_type",
    "CREATE TABLE IF NOT EXISTS oms.user_account_type",
    "ALTER TABLE oms.user_type ENABLE ROW LEVEL SECURITY",
    "CREATE POLICY",
    "GRANT SELECT, INSERT, UPDATE, DELETE ON oms.user_type TO authenticated",
]
for fragment in required_fragments:
    assert fragment in migration, f"fragmento faltante en API user types: {fragment}"
print("User types API SQL OK.")
PY

if command -v docker >/dev/null 2>&1; then
  docker compose --env-file .env.example config >/tmp/oms_supabase_compose_config.yml
  echo "docker compose config OK."
else
  echo "Docker no esta disponible; se omite validacion de compose."
fi

echo "Checks OMS Supabase OK."
