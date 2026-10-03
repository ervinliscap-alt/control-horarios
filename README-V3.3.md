# PROVICA V3.3 — Roles, permisos y administración
ADMIN: control completo, roles y auditoría.
RRHH: edición de datos de guardias; no puede cambiar roles.
OPERACIONES: clientes, instalaciones, puestos y turnos.
SUPERVISOR: consulta (la edición se limitará a instalaciones asignadas en una fase posterior).
GUARDIA: sin acceso a maestros administrativos.

Clientes, instalaciones y puestos se activan/desactivan en lugar de borrarse. Se incorpora auditoría automática de altas y cambios.

Instalación: subir archivos, commit, verificar Vercel y ejecutar UNA VEZ supabase/v3_3_roles_audit.sql.
