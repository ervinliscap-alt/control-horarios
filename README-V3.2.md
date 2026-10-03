# PROVICA V3.2 — Gestión y Control de Turnos
- Jornadas individuales exclusivamente de 8 o 12 horas.
- Hora final calculada automáticamente al crear.
- Editar turno.
- Eliminar turno sin asistencia; si ya existe asistencia se preserva la trazabilidad.
- Estados visuales PROGRAMADO / EN CURSO / FINALIZADO / CANCELADO.
- Protección contra superposición mantenida.
- Restricción de duración también en PostgreSQL.

Instalación: subir el contenido a la raíz, commit, verificar Vercel y luego ejecutar UNA VEZ `supabase/v3_2_turnos.sql`.
El constraint se crea NOT VALID para permitir corregir el turno antiguo de 25 días.
