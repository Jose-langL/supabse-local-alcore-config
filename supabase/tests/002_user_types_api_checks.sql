-- Validation checks for the user types API.

DO $$
DECLARE
    user_type_count integer;
    rls_enabled boolean;
    policy_count integer;
BEGIN
    SELECT count(*) INTO user_type_count
    FROM oms.user_type
    WHERE code IN (
        'super_admin',
        'admin',
        'operator',
        'evaluator',
        'inspector',
        'lab_technician',
        'read_only'
    );

    IF user_type_count <> 7 THEN
        RAISE EXCEPTION 'Expected 7 seeded user types, found %', user_type_count;
    END IF;

    SELECT relrowsecurity INTO rls_enabled
    FROM pg_class
    WHERE oid = 'oms.user_type'::regclass;

    IF rls_enabled IS DISTINCT FROM true THEN
        RAISE EXCEPTION 'RLS is not enabled on oms.user_type';
    END IF;

    SELECT count(*) INTO policy_count
    FROM pg_policies
    WHERE schemaname = 'oms'
      AND tablename = 'user_type';

    IF policy_count < 4 THEN
        RAISE EXCEPTION 'Expected at least 4 policies on oms.user_type, found %', policy_count;
    END IF;
END $$;

SELECT
    code,
    name,
    priority,
    active
FROM oms.user_type
ORDER BY priority, code;
