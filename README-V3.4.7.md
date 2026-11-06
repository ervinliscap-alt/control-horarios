# Seguridad bajo control V3.4.7 — Dashboard inicial y Gantt

## Instalación
Subir los tres archivos en sus respectivas rutas:
- `components/planning-tabs.tsx` (reemplazar)
- `components/planning-dashboard.tsx` (reemplazar)
- `components/planning-gantt.tsx` (nuevo)

No ejecutar SQL. No se modifican funciones de generación ni datos de Supabase.

## Novedades
- La pestaña **Dashboard** es la primera que se muestra al abrir Planificación.
- Gantt por puesto con vista semanal o diaria de 24 horas, desplazamiento por semanas y segmentos azules (titulares) / naranjas (sustitutos).
- Se mantienen los filtros existentes de cliente, instalación, puesto y trabajador, además del calendario semanal de tarjetas.
- Los turnos nocturnos cruzan medianoche sin dividir la asignación original.

## Validación
1. Comprobar el despliegue en Vercel.
2. Abrir Planificación: debe aparecer Dashboard automáticamente.
3. Seleccionar cliente, instalación y puesto; comprobar que el Gantt se filtra.
4. Alternar entre semana y día, incluyendo una jornada nocturna.
5. Confirmar que las pestañas y motores anteriores siguen accesibles.

## Limitaciones
El Gantt muestra turnos programados; no representa asistencia confirmada. Un espacio en blanco no significa necesariamente déficit de cobertura porque faltan las reglas de servicio contratado. La clasificación titular/relevo usa el titular actual del cajón. No hay validación laboral adicional.
