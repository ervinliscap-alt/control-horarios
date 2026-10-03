# PROVICA V3
Incluye dashboard con datos reales, Clientes, Instalaciones, Puestos y Personal.

## Instalación
1. Subir todo el contenido de este ZIP a la raíz del repositorio y reemplazar los archivos existentes.
2. Commit a main y esperar Vercel Ready.
3. Ejecutar UNA VEZ en Supabase SQL Editor: `supabase/v3_crud_rls.sql`.
4. No volver a ejecutar `schema.sql` ni `v2_auth_rls.sql`.
5. Probar en orden: Clientes → Instalaciones → Puestos.

La V3 mantiene las variables NEXT_PUBLIC_SUPABASE_URL y NEXT_PUBLIC_SUPABASE_ANON_KEY ya configuradas.
