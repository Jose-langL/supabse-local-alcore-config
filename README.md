# 🚀 Supabase Local Self-Hosted con Docker

## 📌 Objetivo

Este repositorio ofrece una configuración funcional de Supabase self-hosted para ejecución local con Docker Compose. Está diseñada para que puedas levantar todos los servicios de Supabase juntos y probarlos en tu máquina sin depender de la nube.

Incluye:

- PostgreSQL
- Realtime (WebSockets)
- Auth (GoTrue)
- PostgREST
- Storage
- ImgProxy
- Postgres Meta
- Studio
- Kong API Gateway
- Paquete OMS Backend con migraciones Supabase/Postgres normalizadas.
- Mapping legacy -> normalizado para 1,180 tablas y 41,460 campos.

---

## 📁 Archivos incluidos

- `docker-compose.yml` — define los servicios y su conexión interna.
- `kong.yml` — configuraciones declarativas de Kong para enrutar a cada servicio.
- `.env.example` — plantilla de variables de entorno para crear tu propio `.env`.
- `.gitignore` — evita subir tu `.env` y otros archivos locales.
- `CONTRIBUTING.md` — guía para contribuir al proyecto.
- `LICENSE` — licencia abierta para uso y contribuciones.
- `SUPABASE_HERRAMIENTAS.md` — explicación didáctica de cada componente de Supabase, sus puertos y su uso.
- `supabase/` — configuración Supabase CLI, migraciones OMS, seed y tests SQL.
- `docs/oms/` — documentación, mapping y runbooks para integrar `oms-backend`.
- `scripts/` — validaciones y aplicación manual de migraciones OMS.
- `Makefile` — comandos operativos para levantar, validar y aplicar el ecosistema.
- `README.md` — documentación de uso y referencia.

---

## ⚙️ Cómo usar

1. Copia el ejemplo de entorno:

```bash
cp .env.example .env
```

2. Ajusta los valores dentro de `.env`.

3. Levanta el stack:

```bash
docker compose up -d
```

4. Verifica el estado de los contenedores:

```bash
docker compose ps
```

5. Accede a Kong en:

```text
http://localhost:8000
```

---

## 🧩 Ecosistema OMS Backend

Este repo ahora incluye la base Supabase/Postgres para el proyecto `oms-backend`.

Cobertura incorporada:

- `1,180` tablas legacy mapeadas.
- `41,460` campos legacy mapeados.
- `32,726` rutas JSONB para formularios y datos variables.
- `26` tablas destino normalizadas en schemas `oms`, `ref`, `legacy` y `staging`.

Archivos principales:

- `supabase/config.toml`
- `supabase/migrations/`
- `supabase/seed.sql`
- `supabase/tests/001_migration_quality_checks.sql`
- `docs/oms/README.md`
- `docs/oms/RUNBOOK_LOCAL.md`
- `docs/oms/RUNBOOK_BACKEND_INTEGRATION.md`
- `docs/oms/SECURITY_RLS.md`
- `docs/oms/MIGRATION_PIPELINE.md`
- `docs/oms/SUPABASE_COMPONENT_MATRIX.md`
- `docs/oms/OPERATIONS_CHECKLIST.md`
- `docs/oms/SUPABASE_2026_NOTES.md`
- `docs/oms/API_USER_TYPES_STUDENTS.md`
- `docs/oms/legacy_to_canonical_mapping.csv`
- `docs/oms/table_to_entity_mapping.csv`

Validar estructura:

```bash
make check
```

Aplicar migraciones OMS con `psql`:

```bash
export DATABASE_URL='postgres://postgres:TU_PASSWORD@127.0.0.1:5432/postgres'
make apply-oms
make validate-oms
```

> No subas `.env`, tokens reales ni claves `service_role`.

---

## 🌐 Servicios y conexiones

### `docker-compose.yml`

El archivo `docker-compose.yml` enlaza todos los servicios localmente y mantiene el enlace entre ellos mediante Docker Networking.

- `db` expone PostgreSQL en `5432`
- `auth` corre en `9999`
- `rest` corre en `3000`
- `realtime` corre en `4000`
- `storage` usa `5000` internamente
- `meta` corre en `8080`
- `studio` corre en `3000`
- `kong` expone la entrada en `8000`

### `kong.yml`

Kong actúa como gateway principal y enruta todas las solicitudes a cada servicio:

- `/auth/v1` → Auth
- `/rest/v1` → REST API
- `/realtime/v1` → Realtime
- `/storage/v1` → Storage
- `/` → Studio

---

## 🔧 Variables de entorno

Copia `.env.example` a `.env` y actualiza los valores.

- `POSTGRES_PASSWORD` — contraseña de la base de datos.
- `JWT_SECRET` — secreto JWT de al menos 32 caracteres.
- `ANON_KEY`, `SERVICE_ROLE_KEY` — claves de API.
- `SECRET_KEY_BASE` — clave larga para Realtime.
- `PG_META_CRYPTO_KEY` — clave para Postgres Meta.
- `SITE_URL`, `API_EXTERNAL_URL`, `SUPABASE_PUBLIC_URL` — URLs usadas por los servicios.

> No compartas tu `.env` en el repositorio. Usa `.env.example` como plantilla.

---

## ✅ Flujo interno de la plataforma

1. El gateway Kong recibe la petición.
2. Kong enruta según la ruta solicitada al servicio correspondiente.
3. Cada servicio usa la base de datos `db` para leer y escribir datos.
4. `Studio` se conecta a `meta` para la gestión del proyecto.
5. `Storage` usa `imgproxy` para procesar imágenes.

---

## 🚀 Probar la instalación

Una vez levantado el stack, puedes probar estos endpoints:

- Auth: `http://localhost:8000/auth/v1`
- REST: `http://localhost:8000/rest/v1`
- Realtime: `http://localhost:8000/realtime/v1`
- Storage: `http://localhost:8000/storage/v1`
- Studio: `http://localhost:8000`

---

## 💬 Contribuciones

Este proyecto está pensado para ayudar a la comunidad.

- Si encuentras un error, abre un issue.
- Si quieres mejorar la documentación o la configuración, envía un pull request.
- Revisa `CONTRIBUTING.md` para saber cómo contribuir.

## 📜 Licencia

Este proyecto está disponible bajo la licencia `MIT`. Consulta el archivo `LICENSE` para más detalles.

## Notas finales

Este repositorio está listo para usar con Docker Compose y provee la configuración de Supabase local necesaria para que los servicios estén conectados entre sí.

El repositorio ya incluye un archivo `.gitignore` que excluye el `.env` y evita que tus secretos de entorno se suban al control de versiones.
