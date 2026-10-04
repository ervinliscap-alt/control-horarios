# PROVICA V3.3.4.1
- Solo ADMIN edita o activa/inactiva personal.
- RRHH conserva alta de Operativo/Guardia y lectura.
- OPERACIONES/SUPERVISOR: lectura.
- No hay eliminación física desde la UI.
- Motivo obligatorio y auditoría dedicada `personnel_audit`.
- Personal vinculado inactivo sincroniza `profiles.active`.
- Trigger impide nuevos turnos a guardias vinculados inactivos.

Orden: subir archivos, ejecutar `supabase/v3_3_4_1_personnel_control.sql`, probar con ADMIN.
