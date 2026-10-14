# V3.4.0 — Calendario de cobertura

Se agrega una vista de consulta debajo del planificador, con filtros por plan y trabajador y filas por fecha, columnas por cajón. Usa los turnos ya generados en `shifts` y muestra el horario local de Guayaquil. No modifica datos ni requiere migración SQL.

## Prueba
1. Subir `app/planificacion/page.tsx` y `components/coverage-calendar.tsx`.
2. En Planificación, elegir el puesto 000001 y confirmar que se visualicen los 62 turnos generados.
3. Revisar los cajones de 08:00 y 20:00 y filtrar P000004.
4. Comparar el total por persona con las consultas SQL de auditoría.

Nota: vista inicial de consulta; no reemplaza controles de descanso ni cumplimiento laboral. La consulta está limitada a 1000 turnos por plan.
