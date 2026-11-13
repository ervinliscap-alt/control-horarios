# Seguridad bajo control — V3.4.8

Corrección de legibilidad del Gantt de Planificación.

## Instalación
Reemplazar `components/planning-gantt.tsx` en GitHub. No se requieren cambios de Supabase ni otros archivos.

## Mejoras
- Vista semanal de siete columnas amplias con desplazamiento horizontal y tarjetas de nombre completo.
- Una fila por identificador de cajón (`plan_slot_id`), sin superponer jornadas.
- Vista diaria de 24 horas con escala proporcional, carriles independientes y zoom 100/125/150 %.
- Panel de detalle al seleccionar un turno: cliente, instalación, puesto, trabajador, fechas y horas.
- Mantiene colores para titular actual y sustitución; no modifica datos.

## Limitaciones
- La numeración de cajón es visual, no el `slot_order` almacenado.
- Un turno nocturno aparece en ambos días de la vista semanal.
- La vista no valida cobertura contratada ni presencia física.

## Pruebas
1. Abrir Planificación → Dashboard → Gantt.
2. Revisar semana 2–8 noviembre de 2026, confirmar nombres completos.
3. Cambiar a Día 24 horas y probar zoom 125 % y 150 %.
4. Seleccionar un turno nocturno y comprobar fechas completas.
5. Verificar filtros por cliente/instalación/puesto y ausencia de cambios en Supabase.
