# PROVICA V3.3.4
Personal separado conceptualmente de credenciales, clasificación Operativo/Control, indicador Acceso App y alcance muchos-a-muchos de supervisores por cliente/instalación.

Importante: esta versión NO crea contraseñas ni usuarios Auth desde el navegador. El registro RRHH puede existir sin login. Las credenciales se vincularán mediante un flujo administrativo seguro posterior. Esto evita exponer service_role.

Orden: subir archivos, verificar despliegue, ejecutar `supabase/v3_3_4_personnel_supervision.sql`, probar Personal y Supervisión.
