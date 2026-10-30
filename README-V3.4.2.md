# V3.4.2 — Pools compartidos y limpieza controlada

## Alcance implementado
- Crear pools compartidos de sacafrancos; agregar o retirar integrantes; vincular pools con varios planes.
- Un mismo trabajador puede aparecer en varios pools. Los miembros se sincronizan hacia `post_plan_relief_pool`, que ya consulta el motor V3.4.1.
- Preferencias diurno/nocturno/mixto almacenadas **solo como metadato**; aún no las aplica el motor.
- Borrar **únicamente turnos futuros PROGRAMADO** de un plan, mediante RPC de ADMIN y auditoría.
- No borra turnos históricos ni iniciados. No modifica automáticamente registros de asistencia.

## Limitaciones importantes
- **No es todavía un optimizador global multipuesto**. V3.4.1 optimiza cada plan individualmente; verifica los turnos ya guardados de otros planes, pero dos simulaciones simultáneas pueden proponer el mismo sacafrancos. Para asignación definitiva multipuesto se requiere planificación conjunta con reserva transaccional.
- Desvincular pool o retirar miembro no revoca automáticamente el personal ya copiado a `post_plan_relief_pool`; debe revisarse manualmente en Planificación.
- El algoritmo actual de titulares no reasigna automáticamente un turno titular no disponible a un relevo: queda pendiente.
- No se comprueba traslado físico ni legalidad de jornadas/descansos semanales.
- No eliminar turnos con asistencia, incidentes o dependencias. La RPC confía en las claves foráneas para impedir borrados vinculados.

## Instalación (orden estricto)
1. Subir los archivos del ZIP a GitHub en sus rutas, sin borrar el resto del proyecto.
2. Ejecutar `supabase/v3_4_2_shared_relief.sql` en SQL Editor de Supabase.
3. Comprobar `Success` y recargar la web con Ctrl+F5.
4. Crear pool `Guayaquil Norte`, agregar un relevo y vincular un plan de prueba.
5. Confirmar que el trabajador aparece en Bolsa de relevos de ese plan.
6. Antes de cualquier limpieza, confirmar que se trata de turnos **de prueba** sin registros operativos. La limpieza no se ejecuta al instalar.
7. Ejecutar una simulación; **no regenerar turnos reales** sin auditoría.

## Pruebas de aceptación
- Usuario ADMIN puede crear pool y ejecutar limpieza con frase exacta.
- OPERACIONES puede gestionar pools pero no limpiar turnos.
- SUPERVISOR y RRHH solo pueden consultar el catálogo.
- Un trabajador puede estar en dos pools, pero no debe quedar en turnos solapados cuando se generen planes en secuencia.
- Verificar que los 19 turnos ya iniciados no se eliminan.
- Comprobar auditoría `plan_cleanup_audit` después de limpieza.

## Recomendación siguiente
V3.4.3: planificador global multi-puesto con reservas atómicas, preferencias de turno, traslados, sustitución de titulares ausentes y validación laboral configurada.
