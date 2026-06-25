-- Student implementation: user types API data model.
-- This migration is intentionally documented block by block so students can see
-- every database object required by a Supabase API: table, indexes, seed data,
-- grants and RLS policies.

-- 1. Main catalog table.
-- `oms.user_type` stores the functional roles/types that the OMS system uses
-- to decide what each user can see or operate.
CREATE TABLE IF NOT EXISTS oms.user_type (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code text NOT NULL UNIQUE,
    name text NOT NULL,
    description text,
    priority smallint NOT NULL DEFAULT 100,
    permissions jsonb NOT NULL DEFAULT '{}'::jsonb,
    is_system boolean NOT NULL DEFAULT false,
    active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CHECK (code = lower(code)),
    CHECK (code ~ '^[a-z][a-z0-9_]*$'),
    CHECK (jsonb_typeof(permissions) = 'object')
);

-- 2. Assignment table.
-- One OMS user account can have many user types. Keeping this as a table is
-- better than a JSON array when we need auditability, indexes and constraints.
CREATE TABLE IF NOT EXISTS oms.user_account_type (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_account_id uuid NOT NULL REFERENCES oms.user_account(id) ON DELETE CASCADE,
    user_type_id uuid NOT NULL REFERENCES oms.user_type(id) ON DELETE RESTRICT,
    assigned_by uuid,
    assigned_at timestamptz NOT NULL DEFAULT now(),
    active boolean NOT NULL DEFAULT true,
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    CHECK (jsonb_typeof(metadata) = 'object')
);

-- 3. Indexes for the API.
-- These indexes support list screens, lookups by code and assignment queries.
CREATE INDEX IF NOT EXISTS idx_user_type_active_priority
ON oms.user_type (active, priority, code);

CREATE INDEX IF NOT EXISTS idx_user_type_permissions_gin
ON oms.user_type USING gin (permissions jsonb_path_ops);

CREATE INDEX IF NOT EXISTS idx_user_account_type_user
ON oms.user_account_type (user_account_id, active);

CREATE INDEX IF NOT EXISTS idx_user_account_type_type
ON oms.user_account_type (user_type_id, active);

CREATE UNIQUE INDEX IF NOT EXISTS ux_user_account_type_active
ON oms.user_account_type (user_account_id, user_type_id)
WHERE active = true;

-- 4. Updated-at trigger.
-- Supabase/Postgres will run this automatically every time the API updates a
-- row. The application does not need to send `updated_at` manually.
CREATE OR REPLACE FUNCTION oms.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_user_type_updated_at ON oms.user_type;
CREATE TRIGGER trg_user_type_updated_at
BEFORE UPDATE ON oms.user_type
FOR EACH ROW
EXECUTE FUNCTION oms.set_updated_at();

-- 5. Authorization helper.
-- Supabase recommends using app metadata for authorization decisions because
-- user metadata is editable by the user. This helper reads
-- `auth.jwt()->'app_metadata'->'user_type_codes'`.
CREATE OR REPLACE FUNCTION oms.jwt_has_user_type(required_codes text[])
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM jsonb_array_elements_text(
            COALESCE(auth.jwt() -> 'app_metadata' -> 'user_type_codes', '[]'::jsonb)
        ) AS jwt_type(code)
        WHERE jwt_type.code = ANY(required_codes)
    );
$$;

-- 6. Seed values.
-- These are the first user types used by OMS. The permissions JSON is small on
-- purpose; production can expand it module by module without changing columns.
INSERT INTO oms.user_type (code, name, description, priority, permissions, is_system, active)
VALUES
    (
        'super_admin',
        'Super administrador',
        'Control total del ecosistema OMS y configuracion Supabase.',
        10,
        '{"system":"all","users":"all","cases":"all","catalogs":"all"}',
        true,
        true
    ),
    (
        'admin',
        'Administrador',
        'Administra catalogos, usuarios y configuracion funcional.',
        20,
        '{"users":"manage","cases":"manage","catalogs":"manage"}',
        true,
        true
    ),
    (
        'operator',
        'Operador',
        'Gestiona tramites, solicitudes y carga documental.',
        30,
        '{"cases":"write","documents":"write","catalogs":"read"}',
        true,
        true
    ),
    (
        'evaluator',
        'Evaluador',
        'Revisa expedientes, emite observaciones y actualiza estados de evaluacion.',
        40,
        '{"cases":"review","documents":"read","reports":"write"}',
        true,
        true
    ),
    (
        'inspector',
        'Inspector',
        'Registra inspecciones, hallazgos y seguimiento en campo.',
        50,
        '{"inspections":"write","cases":"read","documents":"read"}',
        true,
        true
    ),
    (
        'lab_technician',
        'Tecnico de laboratorio',
        'Registra controles, pruebas, resultados y reportes de laboratorio.',
        60,
        '{"lab":"write","cases":"read","documents":"read"}',
        true,
        true
    ),
    (
        'read_only',
        'Solo lectura',
        'Consulta informacion autorizada sin modificar registros.',
        90,
        '{"cases":"read","catalogs":"read","reports":"read"}',
        true,
        true
    )
ON CONFLICT (code) DO UPDATE
SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    priority = EXCLUDED.priority,
    permissions = EXCLUDED.permissions,
    is_system = EXCLUDED.is_system,
    active = EXCLUDED.active,
    updated_at = now();

-- 7. Data API grants.
-- Supabase is moving toward explicit grants for Data API access. RLS still
-- decides which rows/actions are allowed, but grants make the table visible.
GRANT USAGE ON SCHEMA oms TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON oms.user_type TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON oms.user_account_type TO authenticated;
GRANT EXECUTE ON FUNCTION oms.jwt_has_user_type(text[]) TO authenticated;

-- 8. Row Level Security.
-- The table is readable by signed-in users, but write operations require an
-- admin type inside `app_metadata.user_type_codes`.
ALTER TABLE oms.user_type ENABLE ROW LEVEL SECURITY;
ALTER TABLE oms.user_account_type ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_types_read_authenticated" ON oms.user_type;
CREATE POLICY "user_types_read_authenticated"
ON oms.user_type
FOR SELECT
TO authenticated
USING (active = true OR oms.jwt_has_user_type(ARRAY['super_admin', 'admin']));

DROP POLICY IF EXISTS "user_types_insert_admin" ON oms.user_type;
CREATE POLICY "user_types_insert_admin"
ON oms.user_type
FOR INSERT
TO authenticated
WITH CHECK (oms.jwt_has_user_type(ARRAY['super_admin', 'admin']));

DROP POLICY IF EXISTS "user_types_update_admin" ON oms.user_type;
CREATE POLICY "user_types_update_admin"
ON oms.user_type
FOR UPDATE
TO authenticated
USING (oms.jwt_has_user_type(ARRAY['super_admin', 'admin']))
WITH CHECK (oms.jwt_has_user_type(ARRAY['super_admin', 'admin']));

DROP POLICY IF EXISTS "user_types_delete_admin" ON oms.user_type;
CREATE POLICY "user_types_delete_admin"
ON oms.user_type
FOR DELETE
TO authenticated
USING (oms.jwt_has_user_type(ARRAY['super_admin', 'admin']));

DROP POLICY IF EXISTS "user_account_types_admin_all" ON oms.user_account_type;
CREATE POLICY "user_account_types_admin_all"
ON oms.user_account_type
FOR ALL
TO authenticated
USING (oms.jwt_has_user_type(ARRAY['super_admin', 'admin']))
WITH CHECK (oms.jwt_has_user_type(ARRAY['super_admin', 'admin']));

COMMENT ON TABLE oms.user_type IS
'Functional user types used by OMS authorization, menus and API behavior.';

COMMENT ON TABLE oms.user_account_type IS
'Many-to-many assignment between OMS user accounts and functional user types.';
