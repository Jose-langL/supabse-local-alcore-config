# 🚀 Supabase Local Self-Hosted con Docker

## 📖 Descripción General

Este documento describe la implementación de una plataforma Supabase Self-Hosted utilizando Docker Compose.

La arquitectura incluye:

- PostgreSQL
- Realtime (WebSockets)
- Auth (GoTrue)
- PostgREST
- Storage
- Image Proxy
- Postgres Meta
- Studio
- Kong API Gateway

Esta configuración permite ejecutar Supabase completamente en infraestructura propia sin depender de la nube de Supabase.

---

# 🏗️ Arquitectura

mermaid flowchart TB  Client[Aplicaciones Web / Mobile]  Client --> Kong  Kong --> Auth Kong --> Rest Kong --> Realtime Kong --> Storage Kong --> Studio  Auth --> PostgreSQL Rest --> PostgreSQL Realtime --> PostgreSQL Storage --> PostgreSQL Meta --> PostgreSQL  Storage --> ImgProxy  Studio --> Meta 

---

# 📁 Estructura Recomendada

bash supabase/ │ ├── docker-compose.yml ├── .env ├── kong.yml │ ├── volumes/ │   ├── postgres/ │   └── storage/ │ └── backups/ 

---

# 🔐 Variables de Entorno

Crear archivo:

bash touch .env 

Contenido:

env ######################################## # PostgreSQL ########################################  POSTGRES_DB=postgres POSTGRES_PORT=5432 POSTGRES_PASSWORD=SuperPassword123  ######################################## # JWT ########################################  JWT_SECRET=CAMBIAR_POR_UN_SECRET_DE_32_CARACTERES JWT_EXPIRY=3600  ######################################## # API KEYS ########################################  ANON_KEY=GENERAR_ANON_KEY SERVICE_ROLE_KEY=GENERAR_SERVICE_ROLE_KEY  ######################################## # Realtime ########################################  SECRET_KEY_BASE=GENERAR_SECRET_KEY_BASE  ######################################## # Meta ########################################  PG_META_CRYPTO_KEY=GENERAR_CRYPTO_KEY  ######################################## # URLs ########################################  SITE_URL=http://localhost:3000  API_EXTERNAL_URL=http://localhost:8000  SUPABASE_PUBLIC_URL=http://localhost:8000  ADDITIONAL_REDIRECT_URLS=http://localhost:3000  ######################################## # Studio ########################################  STUDIO_ORG=ALCORE STUDIO_PROJECT=Supabase Local  ######################################## # Gateway ########################################  KONG_HTTP_PORT=8000 

---

# 🐘 Servicio PostgreSQL

## Función

Motor principal de base de datos.

Almacena:

- Usuarios
- Datos de negocio
- Políticas RLS
- Eventos Realtime
- Storage Metadata

---

## Configuración

yaml db:   image: supabase/postgres:15.8.1.085    container_name: supabase-db    restart: unless-stopped    ports:     - "${POSTGRES_PORT}:5432"    environment:     POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}     POSTGRES_DB: ${POSTGRES_DB}     JWT_SECRET: ${JWT_SECRET}     JWT_EXP: ${JWT_EXPIRY}    volumes:     - supabase_db_data:/var/lib/postgresql/data 

---

# ⚡ Servicio Realtime

## Función

Permite:

- WebSockets
- Escucha de cambios en tablas
- Notificaciones en tiempo real
- Chats
- Dashboards en vivo

---

## Configuración

yaml realtime:   image: supabase/realtime:v2.102.3    container_name: realtime-dev.supabase-realtime    restart: unless-stopped    depends_on:     db:       condition: service_healthy    environment:      PORT: 4000      DB_HOST: db     DB_PORT: 5432     DB_USER: supabase_admin     DB_PASSWORD: ${POSTGRES_PASSWORD}     DB_NAME: ${POSTGRES_DB}      API_JWT_SECRET: ${JWT_SECRET}      SECRET_KEY_BASE: ${SECRET_KEY_BASE}      METRICS_JWT_SECRET: ${JWT_SECRET}      APP_NAME: realtime      SEED_SELF_HOST: "true"      RUN_JANITOR: "true" 

---

# 🔑 Servicio Auth

## Función

Gestiona:

- Login
- Registro
- Recuperación de contraseña
- JWT
- OAuth

---

yaml auth:   image: supabase/gotrue:v2.178.0    restart: unless-stopped    environment:      GOTRUE_API_HOST: 0.0.0.0      GOTRUE_API_PORT: 9999      API_EXTERNAL_URL: ${API_EXTERNAL_URL}      GOTRUE_DB_DRIVER: postgres      GOTRUE_DB_DATABASE_URL: postgres://supabase_auth_admin:${POSTGRES_PASSWORD}@db:5432/${POSTGRES_DB}      GOTRUE_SITE_URL: ${SITE_URL}      GOTRUE_JWT_SECRET: ${JWT_SECRET}      GOTRUE_JWT_EXP: ${JWT_EXPIRY} 

---

# 🌐 Servicio REST API

## Función

Genera automáticamente una API REST para PostgreSQL.

---

yaml rest:   image: postgrest/postgrest:v14.12    restart: unless-stopped    environment:      PGRST_DB_URI: postgres://authenticator:${POSTGRES_PASSWORD}@db:5432/${POSTGRES_DB}      PGRST_DB_SCHEMAS: public,storage,graphql_public      PGRST_DB_ANON_ROLE: anon      PGRST_JWT_SECRET: ${JWT_SECRET} 

---

# 📦 Servicio Storage

## Función

Permite almacenar:

- Imágenes
- PDFs
- Videos
- Archivos empresariales

---

yaml storage:   image: supabase/storage-api:v1.60.4    restart: unless-stopped    environment:      ANON_KEY: ${ANON_KEY}      SERVICE_KEY: ${SERVICE_ROLE_KEY}      AUTH_JWT_SECRET: ${JWT_SECRET}      STORAGE_BACKEND: file      FILE_STORAGE_BACKEND_PATH: /var/lib/storage    volumes:     - supabase_storage_data:/var/lib/storage 

---

# 🖼️ Servicio ImgProxy

## Función

Optimización automática de imágenes.

Características:

- WebP
- Resize
- Thumbnail
- Cache

---

yaml imgproxy:   image: darthsim/imgproxy:v3.30.1    restart: unless-stopped    environment:      IMGPROXY_BIND: ":5001"      IMGPROXY_AUTO_WEBP: "true" 

---

# 📊 Servicio Postgres Meta

## Función

Permite a Studio administrar PostgreSQL.

---

yaml meta:   image: supabase/postgres-meta:v0.96.6    restart: unless-stopped    environment:      PG_META_DB_HOST: db      PG_META_DB_PORT: 5432      PG_META_DB_NAME: ${POSTGRES_DB}      PG_META_DB_USER: supabase_admin      PG_META_DB_PASSWORD: ${POSTGRES_PASSWORD} 

---

# 🎛️ Servicio Studio

## Función

Panel gráfico de administración.

Permite:

- Crear tablas
- Gestionar usuarios
- Ejecutar SQL
- Configurar Storage

---

yaml studio:   image: supabase/studio    restart: unless-stopped    environment:      STUDIO_PG_META_URL: http://meta:8080      SUPABASE_URL: ${SUPABASE_PUBLIC_URL}      SUPABASE_ANON_KEY: ${ANON_KEY}      SUPABASE_SERVICE_KEY: ${SERVICE_ROLE_KEY} 

---

# 🚪 Kong Gateway

## Función

Punto único de entrada.

Rutas:

| Ruta | Servicio |
|--------|-----------|
| /auth/v1 | Auth |
| /rest/v1 | REST |
| /realtime/v1 | Realtime |
| /storage/v1 | Storage |
| / | Studio |

---

# ▶️ Levantar la Plataforma

bash docker compose up -d 

Verificar:

bash docker ps 

---

# 🔍 Validaciones

Comprobar PostgreSQL:

bash docker exec -it supabase-db psql -U postgres 

Comprobar Realtime:

bash docker logs realtime-dev.supabase-realtime 

Comprobar Storage:

bash docker logs supabase-storage 

---

# 💾 Backups

Crear respaldo:

bash docker exec supabase-db pg_dumpall -U postgres > backup.sql 

Restaurar:

bash docker exec -i supabase-db psql -U postgres < backup.sql 

---

# 🔒 Recomendaciones de Seguridad

## Producción

Cambiar:

env POSTGRES_PASSWORD JWT_SECRET ANON_KEY SERVICE_ROLE_KEY SECRET_KEY_BASE 

---

## Firewall

Permitir únicamente:

text 22 80 443 

Bloquear:

text 5432 9999 4000 8080 5000 

---

## SSL

Utilizar:

- Traefik
- Nginx Proxy Manager
- HAProxy

con certificados Let's Encrypt.

---

# 🌍 URLs Finales

text https://supabase.midominio.com https://supabase.midominio.com/auth/v1 https://supabase.midominio.com/rest/v1 https://supabase.midominio.com/storage/v1 https://supabase.midominio.com/realtime/v1 

---

# ✅ Resultado

Al finalizar tendrás una plataforma Supabase completamente funcional con:

- PostgreSQL
- Realtime
- JWT
- Auth
- REST API
- Storage
- Studio
- Kong Gateway
- Persistencia de datos
- Preparada para producción
- Lista para integrarse con React, Angular, Vue, Flutter, React Native y aplicaciones móviles empresarial




# 🚪 Configuración de Kong Gateway para Supabase Self-Hosted

## 📖 ¿Qué es Kong?

Kong es el API Gateway utilizado por Supabase para centralizar todas las peticiones hacia los servicios internos.

Su función principal es:

- Gestionar rutas
- Aplicar CORS
- Aplicar autenticación
- Centralizar tráfico
- Ocultar servicios internos
- Exponer una única URL pública

---

# 📁 Crear Archivo

Ubicarse en la raíz del proyecto:

bash touch kong.yml 

Estructura recomendada:

text supabase/ │ ├── docker-compose.yml ├── .env ├── kong.yml │ ├── volumes/ │   ├── postgres/ │   └── storage/ │ └── backups/ 

---

# ⚙️ Archivo kong.yml

yaml _format_version: "2.1"  services:    #########################################################################   # AUTH   #########################################################################    - name: auth-v1      url: http://auth:9999      routes:       - name: auth-v1-route          strip_path: true          paths:           - /auth/v1    #########################################################################   # REST API   #########################################################################    - name: rest-v1      url: http://rest:3000      routes:       - name: rest-v1-route          strip_path: true          paths:           - /rest/v1    #########################################################################   # REALTIME   #########################################################################    - name: realtime-v1      url: http://realtime:4000/socket/      routes:       - name: realtime-v1-route          strip_path: true          preserve_host: true          protocols:           - http           - https          paths:           - /realtime/v1    #########################################################################   # STORAGE   #########################################################################    - name: storage-v1      url: http://storage:5000      routes:       - name: storage-v1-route          strip_path: true          paths:           - /storage/v1    #########################################################################   # STUDIO   #########################################################################    - name: studio      url: http://studio:3000      routes:       - name: studio-route          strip_path: true          paths:           - /  ######################################################################### # PLUGINS GLOBALES #########################################################################  plugins:    #######################################################################   # CORS   #######################################################################    - name: cors      config:        origins:         - "*"        methods:         - GET         - POST         - PUT         - PATCH         - DELETE         - OPTIONS        headers:         - Accept         - Authorization         - Content-Type         - apikey         - x-client-info         - origin        exposed_headers:         - Content-Length         - Content-Range        credentials: true        max_age: 3600    #######################################################################   # REQUEST TRANSFORMER   #######################################################################    - name: request-transformer      config:        add:          headers:           - X-Powered-By:Supabase    #######################################################################   # RESPONSE TRANSFORMER   #######################################################################    - name: response-transformer      config:        add:          headers:           - X-Supabase-Environment:SelfHosted 

---

# 🔍 Explicación de las Rutas

## Auth

Responsable de:

- Registro de usuarios
- Inicio de sesión
- Recuperación de contraseña
- Refresh Token
- JWT

Ruta:

text /auth/v1 

Ejemplo:

text http://localhost:8000/auth/v1/signup 

---

## REST API

Generada automáticamente por PostgREST.

Ruta:

text /rest/v1 

Ejemplo:

text http://localhost:8000/rest/v1/users 

---

## Realtime

Permite:

- WebSockets
- Escuchar INSERT
- Escuchar UPDATE
- Escuchar DELETE
- Chats en tiempo real
- Dashboards en vivo

Ruta:

text /realtime/v1 

Ejemplo:

text ws://localhost:8000/realtime/v1 

---

## Storage

Permite:

- Subir imágenes
- Subir documentos
- Subir videos
- Crear buckets

Ruta:

text /storage/v1 

Ejemplo:

text http://localhost:8000/storage/v1/object/public 

---

## Studio

Interfaz administrativa de Supabase.

Ruta:

text / 

Ejemplo:

text http://localhost:8000 

---

# 🔐 Seguridad Recomendada para Producción

## Exponer únicamente

text 80 443 

---

## Mantener privados

text 5432 5000 8080 9999 4000 

---

## Firewall UFW

bash sudo ufw default deny incoming  sudo ufw default allow outgoing  sudo ufw allow 22/tcp  sudo ufw allow 80/tcp  sudo ufw allow 443/tcp  sudo ufw enable 

---

# 🚀 Verificación

Verificar que Kong cargó correctamente:

bash docker logs supabase-kong 

Resultado esperado:

text Kong started successfully 

---

# 🌍 Endpoints Finales

text https://supabase.midominio.com 

---

### Studio

text https://supabase.midominio.com 

---

### Auth

text https://supabase.midominio.com/auth/v1 

---

### REST

text https://supabase.midominio.com/rest/v1 

---

### Realtime

text wss://supabase.midominio.com/realtime/v1 

---

### Storage

text https://supabase.midominio.com/storage/v1 

---

# ✅ Resultado

Al finalizar tendrás un Gateway Kong completamente configurado para:

- PostgreSQL
- Realtime
- JWT
- Auth
- REST API
- Storage
- Studio

Todo centralizado a través del puerto público:

text 8000 

o en producción:

text 443 
