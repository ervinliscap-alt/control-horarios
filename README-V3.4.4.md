# Seguridad bajo control — V3.4.4

## Alcance implementado

- Nueva sección **7. Generación coordinada multipuesto** en Planificación.
- Vista previa cronológica de los puestos asociados al mismo pool.
- Generación atómica de todos los turnos futuros de esos puestos si se logra cobertura total.
- Comprueba descanso mínimo de 12 horas, cruces entre trabajadores y turnos existentes en otros puestos.
- No borra ni sustituye turnos; **rechaza** la generación si hay turnos futuros activos de cualquiera de los planes del pool.
- Solo ADMIN y OPERACIONES pueden generar; RRHH/SUPERVISOR solo previsualizan.
- Registra en `shared_pool_generation_audit` el usuario y los IDs de los turnos creados.

## Limitaciones importantes

- **No hay todavía optimización global de desfases**: se usan los desfases actuales y un asignador heurístico que prioriza titulares y distribuye relevos por menor carga acumulada.
- No aplica todavía límites contractuales de horas, descansos semanales, preferencia diurna/nocturna ni traslados. El 100% de cobertura NO certifica cumplimiento laboral.
- El bloqueo asesor serializa las generaciones que usen este procedimiento; las escrituras externas directas a `shifts` requieren controles adicionales a nivel de base de datos para impedir condiciones de carrera.
- No permite reemplazar turnos futuros existentes: utilice la limpieza controlada V3.4.2 solamente si son pruebas, sin asistencias ni incidentes, y previa auditoría.
- La vista previa es una fotografía del momento; el generador recalcula todo al ejecutarse y puede rechazar si cambió la disponibilidad.

## Instalación

1. Subir `app/planificacion/page.tsx` y `components/shared-pool-coordinator.tsx` a GitHub.
2. Subir `supabase/v3_4_4_coordinated_generation.sql` y este README.
3. **Antes de ejecutar SQL, revisar con ADMIN**. En Supabase SQL Editor ejecutar el archivo completo. No genera turnos al instalar.
4. Verificar la función `provica_shared_pool_schedule(p_pool uuid,p_min_rest_hours integer,p_generate boolean,p_confirm text)`.
5. Entrar a Planificación y pulsar **Vista previa coordinada** para el pool GYE Operaciones.
6. **No generar todavía**: comparar los resultados con V3.4.3, auditar datos y confirmar que ambos planes carezcan de turnos futuros.

## SQL de verificación de instalación

```sql
SELECT proname,pg_get_function_identity_arguments(oid)
FROM pg_proc WHERE proname='provica_shared_pool_schedule';
```

## Verificación después de generar

Consultar el registro `shared_pool_generation_audit` y auditar globalmente los turnos por trabajador y descanso. No operar turnos reales sin validación legal y operativa adicional.
