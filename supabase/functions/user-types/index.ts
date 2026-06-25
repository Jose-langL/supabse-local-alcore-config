import { createClient } from "npm:@supabase/supabase-js@2.108.2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";

type UserTypeInput = {
  code?: string;
  name?: string;
  description?: string | null;
  priority?: number;
  permissions?: Record<string, unknown>;
  active?: boolean;
};

const adminUserTypes = new Set(["super_admin", "admin"]);

function getRequiredEnv(name: string) {
  const value = Deno.env.get(name);
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

function decodeJwtPayload(jwt: string) {
  const [, payload] = jwt.split(".");
  if (!payload) return {};
  const normalized = payload.replace(/-/g, "+").replace(/_/g, "/");
  const decoded = atob(normalized);
  return JSON.parse(decoded);
}

function getBearerToken(req: Request) {
  const authorization = req.headers.get("authorization") ?? "";
  const [scheme, token] = authorization.split(" ");
  if (scheme?.toLowerCase() !== "bearer" || !token) {
    return null;
  }
  return token;
}

function getUserTypeCodes(token: string) {
  const payload = decodeJwtPayload(token) as {
    app_metadata?: { user_type_codes?: string[]; role?: string };
  };
  const codes = payload.app_metadata?.user_type_codes ?? [];
  const role = payload.app_metadata?.role;
  if (role && !codes.includes(role)) {
    codes.push(role);
  }
  return codes;
}

function isAdmin(token: string) {
  return getUserTypeCodes(token).some((code) => adminUserTypes.has(code));
}

function normalizeCode(code: string) {
  return code.trim().toLowerCase().replace(/[^a-z0-9_]/g, "_");
}

function sanitizeInput(input: UserTypeInput, partial = false) {
  const payload: Record<string, unknown> = {};

  if (!partial || input.code !== undefined) {
    if (!input.code) throw new Error("code is required");
    payload.code = normalizeCode(input.code);
  }

  if (!partial || input.name !== undefined) {
    if (!input.name) throw new Error("name is required");
    payload.name = input.name.trim();
  }

  if (input.description !== undefined) payload.description = input.description;
  if (input.priority !== undefined) payload.priority = input.priority;
  if (input.permissions !== undefined) payload.permissions = input.permissions;
  if (input.active !== undefined) payload.active = input.active;

  return payload;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const token = getBearerToken(req);
    if (!token) {
      return jsonResponse({ error: "Missing bearer token" }, 401);
    }

    const supabaseUrl = getRequiredEnv("SUPABASE_URL");
    const serviceRoleKey = getRequiredEnv("SUPABASE_SERVICE_ROLE_KEY");

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false },
      global: { headers: { Authorization: `Bearer ${token}` } },
    });

    const url = new URL(req.url);
    const pathParts = url.pathname.split("/").filter(Boolean);
    const idFromPath = pathParts[pathParts.length - 1] !== "user-types"
      ? pathParts[pathParts.length - 1]
      : null;
    const code = url.searchParams.get("code");
    const includeInactive = url.searchParams.get("includeInactive") === "true";

    if (req.method === "GET") {
      const singleRecord = Boolean(idFromPath || code);
      let query = supabase
        .schema("oms")
        .from("user_type")
        .select("id, code, name, description, priority, permissions, is_system, active, created_at, updated_at")
        .order("priority", { ascending: true })
        .order("code", { ascending: true });

      if (idFromPath) query = query.eq("id", idFromPath);
      if (code) query = query.eq("code", normalizeCode(code));
      if (!includeInactive) query = query.eq("active", true);
      if (singleRecord) query = query.maybeSingle();

      const { data, error } = await query;
      if (error) return jsonResponse({ error: error.message }, 400);
      return jsonResponse({ data });
    }

    if (!isAdmin(token)) {
      return jsonResponse({ error: "Only admin user types can modify user types" }, 403);
    }

    if (req.method === "POST") {
      const body = sanitizeInput(await req.json());
      const { data, error } = await supabase
        .schema("oms")
        .from("user_type")
        .insert(body)
        .select()
        .single();

      if (error) return jsonResponse({ error: error.message }, 400);
      return jsonResponse({ data }, 201);
    }

    if (req.method === "PUT" || req.method === "PATCH") {
      const targetCode = code ? normalizeCode(code) : null;
      if (!idFromPath && !targetCode) {
        return jsonResponse({ error: "Provide an id in the path or code query param" }, 400);
      }

      const body = sanitizeInput(await req.json(), req.method === "PATCH");
      let query = supabase.schema("oms").from("user_type").update(body);
      query = idFromPath ? query.eq("id", idFromPath) : query.eq("code", targetCode);

      const { data, error } = await query.select().single();
      if (error) return jsonResponse({ error: error.message }, 400);
      return jsonResponse({ data });
    }

    if (req.method === "DELETE") {
      const targetCode = code ? normalizeCode(code) : null;
      if (!idFromPath && !targetCode) {
        return jsonResponse({ error: "Provide an id in the path or code query param" }, 400);
      }

      const hardDelete = url.searchParams.get("hard") === "true";
      let query = hardDelete
        ? supabase.schema("oms").from("user_type").delete()
        : supabase.schema("oms").from("user_type").update({ active: false });

      query = idFromPath ? query.eq("id", idFromPath) : query.eq("code", targetCode);

      const { data, error } = await query.select().single();
      if (error) return jsonResponse({ error: error.message }, 400);
      return jsonResponse({ data });
    }

    return jsonResponse({ error: `Method ${req.method} not allowed` }, 405);
  } catch (error) {
    return jsonResponse({ error: error instanceof Error ? error.message : "Unexpected error" }, 500);
  }
});
