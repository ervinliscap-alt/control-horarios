# PROVICA Control de Guardias — V2

Esta versión agrega autenticación real con Supabase, sesión protegida, perfil/rol y políticas RLS iniciales.

## Antes de desplegar
1. En Supabase SQL Editor ejecutar `supabase/v2_auth_rls.sql`.
2. En Supabase Authentication > Users crear el primer usuario.
3. Copiar su UUID y ejecutar:
   `update public.profiles set role='ADMIN' where id='<UUID>';`
4. Vercel debe tener:
   - `NEXT_PUBLIC_SUPABASE_URL`
   - `NEXT_PUBLIC_SUPABASE_ANON_KEY`
5. Subir/reemplazar estos archivos en GitHub y esperar el despliegue automático de Vercel.

## Roles
ADMIN, RRHH, OPERACIONES, SUPERVISOR, GUARDIA.

## Seguridad
Nunca colocar `sb_secret_...`, `service_role` ni contraseña de base de datos en variables `NEXT_PUBLIC_*`.
