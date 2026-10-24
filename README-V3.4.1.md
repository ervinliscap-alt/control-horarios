# Seguridad bajo control — V3.4.1

## Objetivo
Corregir la asignación de 24 horas consecutivas observada en P000004 (16/17 de octubre). **No está aprobada para operación real sin pruebas de aceptación y revisión laboral.**

## Instalación controlada
1. Subir `components/coverage-calendar.tsx` a GitHub reemplazando el archivo existente. Subir también este README y `supabase/v3_4_1_rest_engine.sql`.
2. Ejecutar **una sola vez** el SQL completo en Supabase SQL Editor. El SQL sustituye simulador, optimizador y generador; no elimina ni reescribe turnos existentes.
3. Confirmar `Success. No rows returned` y refrescar la web.
4. En el calendario, los turnos históricos incompatibles deberán aparecer en rojo. **No pulsar Generar turnos** hasta evaluar resultados.
5. Ejecutar **Simular actual**: si los desfases 3/5 generan incompatibilidad, el resultado será NO VIABLE. Ejecutar **Optimizar desfases** y comprobar si existe solución con 3 personas. Si no existe, incorporar relevo adicional de prueba y volver a simular.
6. Solo tras validar resultados, regenerar turnos futuros. Los turnos pasados se conservan. El generador rechaza íntegramente los planes no viables.

## Cambios
- Un único motor compartido por simulación, optimización y generación.
- Orden cronológico global de todos los cajones; descanso mínimo 12 h en ambos sentidos, incluido personal de otros puestos.
- Los 49 desfases se evalúan sin modificar la base de datos.
- Reutilización segura del plan: el motor ignora los turnos futuros PROGRAMADO del mismo plan que serían sustituidos; conserva los pasados.
- Calendario: alertas de fatiga sobre turnos ya existentes, con señalización roja. Al filtrar por trabajador, las celdas de los demás muestran “Otro trabajador”.

## Limitaciones
- 12 h es un **umbral operativo configurable**, no una certificación de cumplimiento del Código del Trabajo de Ecuador. La modalidad 5×2 con turnos de 12 horas debe revisarse jurídicamente.
- El calendario comprueba conflictos **dentro del plan visible**; la simulación y generación sí contrastan los demás turnos del personal.
- Para turnos futuros del mismo plan con estado distinto de PROGRAMADO, el motor los considera compromisos existentes y puede bloquear regeneración.
- Cambios concurrentes de turnos externos a este plan requieren políticas de bloqueo adicionales antes de producción.
- Los turnos con inicio pasado no se regeneran, y el porcentaje mostrado corresponde a turnos futuros.

## Prueba SQL de auditoría (solo lectura)
```sql
with ordered as (
 select s.id,s.personnel_id,s.starts_at,s.ends_at,
  lag(s.ends_at) over(partition by s.personnel_id order by s.starts_at,s.id) as previous_end
 from public.shifts s
 where s.status <> 'CANCELADO' and s.personnel_id is not null
)
select p.person_code,o.starts_at,o.previous_end,
 round((extract(epoch from (o.starts_at-o.previous_end))/3600)::numeric,2) as rest_hours
from ordered o join public.personnel p on p.id=o.personnel_id
where o.previous_end is not null
 and o.starts_at < o.previous_end + interval '12 hours'
order by o.starts_at;
```

**Nota:** Este reporte detecta conflictos en toda la tabla `shifts`, incluso turnos de otros planes; no corrige datos.
