# Ecosistema Supabase para OMS Backend

Este directorio documenta el paquete OMS agregado al repo de Supabase local.

## Objetivo

Dejar una base reproducible para que `oms-backend` trabaje con Supabase/Postgres usando el modelo normalizado que consolida las tres bases legacy:

- `VENTANILLA`
- `ADMINISTRATIVO-EVALUADOR`
- `MONITOREO-VIGILANCIA`

## Cobertura

- Tablas legacy documentadas: `1,180`
- Campos legacy mapeados: `41,460`
- Entidades/tablas destino normalizadas: `26`
- Rutas JSONB de preservacion: `32,726`
- Constraints invalidas en validacion original: `0`

## Estructura agregada

```text
supabase/
  config.toml
  migrations/
  seed.sql
  tests/
docs/oms/
  legacy_to_canonical_mapping.csv
  table_to_entity_mapping.csv
  normalization_summary.json
scripts/
  check-oms-supabase.sh
  apply-oms-migrations.sh
Makefile
```

## Orden de lectura para desarrolladores

1. `docs/oms/RUNBOOK_LOCAL.md`
2. `docs/oms/RUNBOOK_BACKEND_INTEGRATION.md`
3. `docs/oms/SECURITY_RLS.md`
4. `docs/oms/MIGRATION_PIPELINE.md`
5. `docs/oms/SUPABASE_COMPONENT_MATRIX.md`
6. `docs/oms/OPERATIONS_CHECKLIST.md`
7. `docs/oms/SUPABASE_2026_NOTES.md`
8. `docs/oms/API_USER_TYPES_STUDENTS.md`
9. `docs/oms/table_to_entity_mapping.csv`
10. `docs/oms/legacy_to_canonical_mapping.csv`
11. `supabase/migrations/`

## Principio de consumo

El frontend y el backend no deben intentar recrear las 1,180 tablas legacy.

El consumo nuevo debe ir contra las tablas normalizadas `oms`, `ref`, `legacy` y `staging`. Los campos variables o formularios amplios se preservan en `jsonb` con ruta documentada en el mapping.

## Fuente original

Este paquete fue copiado desde `oms-backend/docs/database/normalized`, donde el modelo fue validado en PostgreSQL contra `alcore_system_bussines_suite`.
