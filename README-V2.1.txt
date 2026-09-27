PROVICA V2.1 - Corrección de autenticación

Reemplazar únicamente:
1. middleware.ts
2. lib/supabase/server.ts

No ejecutar SQL adicional.
No cambiar las variables de Vercel.
Después del commit a main, esperar el deployment de Vercel y probar /login.
