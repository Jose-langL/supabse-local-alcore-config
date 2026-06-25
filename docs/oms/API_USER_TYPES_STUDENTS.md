# API de Tipos de Usuario OMS para estudiantes

Esta guia explica de inicio a fin como se crea un API en Supabase para una tabla real del sistema. El objetivo es que puedas repetir el patron con otras entidades del proyecto.

## Que vamos a construir

El API administra los tipos funcionales de usuarios del sistema OMS:

- `super_admin`
- `admin`
- `operator`
- `evaluator`
- `inspector`
- `lab_technician`
- `read_only`

## Archivos que se integran

| Archivo | Para que sirve |
| --- | --- |
| `supabase/migrations/20260625000100_oms_user_types_api.sql` | Crea tablas, indices, seeds, grants y RLS |
| `supabase/functions/user-types/index.ts` | Expone CRUD HTTP con Edge Functions |
| `supabase/functions/_shared/cors.ts` | Centraliza headers CORS y respuestas JSON |
| `supabase/tests/002_user_types_api_checks.sql` | Valida que la tabla y politicas existan |
| `supabase/config.toml` | Registra la funcion `user-types` |
| `docs/oms/API_USER_TYPES_STUDENTS.md` | Documentacion didactica para entender el flujo |

## Paso 1: tabla principal

La tabla `oms.user_type` guarda los tipos de usuario. Sus campos principales son:

| Campo | Uso |
| --- | --- |
| `id` | Identificador UUID |
| `code` | Codigo estable para permisos y menus |
| `name` | Nombre visible |
| `description` | Explicacion funcional |
| `priority` | Orden de visualizacion |
| `permissions` | Permisos por modulo en JSONB |
| `is_system` | Marca tipos semilla del sistema |
| `active` | Permite baja logica |

## Paso 2: tabla de asignacion

`oms.user_account_type` permite que un usuario tenga varios tipos. Esto es mejor que guardar todo en un array porque permite:

- auditar quien asigno el tipo;
- consultar por usuario o tipo;
- evitar duplicados activos;
- desactivar una asignacion sin perder historia.

## Paso 3: seeds iniciales

La migracion inserta los tipos base con `ON CONFLICT`. Eso permite ejecutar la migracion mas de una vez sin duplicar registros.

## Paso 4: grants

Supabase requiere grants explicitos para que la Data API pueda ver las tablas. Por eso la migracion incluye:

```sql
GRANT USAGE ON SCHEMA oms TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON oms.user_type TO authenticated;
```

El grant no significa que todos pueden modificar todo. Solo hace visible la tabla. La autorizacion real la controla RLS.

## Paso 5: RLS

RLS queda habilitado en las dos tablas.

- Usuarios autenticados pueden leer tipos activos.
- Solo `super_admin` y `admin` pueden crear, actualizar o eliminar.
- La autorizacion lee `app_metadata.user_type_codes`, no `user_metadata`.

Ejemplo del JWT esperado:

```json
{
  "app_metadata": {
    "user_type_codes": ["admin"]
  }
}
```

## Paso 6: Edge Function

La funcion `user-types` expone CRUD:

| Metodo | Ruta | Accion |
| --- | --- | --- |
| `GET` | `/functions/v1/user-types` | Listar tipos activos |
| `GET` | `/functions/v1/user-types?code=admin` | Buscar por codigo |
| `POST` | `/functions/v1/user-types` | Crear tipo |
| `PATCH` | `/functions/v1/user-types?code=operator` | Actualizar parcialmente |
| `PUT` | `/functions/v1/user-types?code=operator` | Reemplazar campos enviados |
| `DELETE` | `/functions/v1/user-types?code=operator` | Baja logica |
| `DELETE` | `/functions/v1/user-types?code=operator&hard=true` | Eliminacion fisica |

## Ejemplos de consumo

### Listar

```bash
curl -X GET "$SUPABASE_URL/functions/v1/user-types" \
  -H "Authorization: Bearer $USER_JWT"
```

### Crear

```bash
curl -X POST "$SUPABASE_URL/functions/v1/user-types" \
  -H "Authorization: Bearer $ADMIN_JWT" \
  -H "Content-Type: application/json" \
  -d '{
    "code": "support",
    "name": "Soporte",
    "description": "Usuario de soporte operativo",
    "priority": 80,
    "permissions": {
      "cases": "read",
      "tickets": "write"
    }
  }'
```

### Actualizar

```bash
curl -X PATCH "$SUPABASE_URL/functions/v1/user-types?code=support" \
  -H "Authorization: Bearer $ADMIN_JWT" \
  -H "Content-Type: application/json" \
  -d '{ "active": false }'
```

## Como validar

```bash
make check
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/002_user_types_api_checks.sql
```

## Patron que debes repetir para otras APIs

1. Crear migracion.
2. Crear tabla.
3. Agregar constraints.
4. Agregar indices.
5. Agregar seeds si aplica.
6. Agregar grants.
7. Activar RLS.
8. Crear politicas.
9. Crear Edge Function si necesitas logica HTTP propia.
10. Crear tests SQL.
11. Documentar consumo.
