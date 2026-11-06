# Seguridad bajo control V3.4.6 — Dashboard jerárquico y semana gráfica

## Instalación
Subir `components/planning-dashboard.tsx` (reemplazar) y `components/planning-weekly-grid.tsx` (nuevo). No se requiere SQL ni alterar los turnos existentes.

## Funciones
- Filtros encadenados por cliente, instalación, puesto y trabajador.
- Tabla de turnos con jerarquía cliente → instalación → puesto.
- Grilla semanal de lunes a domingo con navegación y turnos que cruzan medianoche.
- Alternancia de agrupación por puesto o trabajador.
- Indicadores de titulares y relevos actualmente programados.

## Pruebas
1. Abrir Planificación → Dashboard y verificar nombres de cliente/instalación.
2. Filtrar cliente, instalación y puesto y comprobar que la tabla y grilla cambien conjuntamente.
3. Seleccionar semana 2026-11-09 y verificar turnos diurnos/nocturnos.
4. Agrupar por trabajador y confirmar que P000004/P000005 aparecen donde estén programados.
5. Comprobar que los turnos nocturnos figuren en los dos días correspondientes.

## Limitaciones
- El calendario es una grilla semanal por día, no un Gantt horario proporcional.
- Clasificación titular/relevo usa el titular actual del cajón.
- No confirma presencia física, cobertura contractual ni cumplimiento legal.
- Consulta limitada a 1.000 turnos; requiere paginación para operaciones grandes.
- La zona horaria operativa se fija en America/Guayaquil.
