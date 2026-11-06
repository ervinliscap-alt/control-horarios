# Seguridad bajo control — V3.4.3 (simulación multipuesto, fase 1)

## Alcance real
- Simulación conjunta de los planes asociados a un pool, ordenada por inicio de jornada.
- Verificación de descansos mínimos de 12 h y solapamientos en la simulación y frente a turnos existentes en otros planes.
- Prioridad al titular en sus días de trabajo; cobertura con miembros del pool en los descansos.
- Informe por puesto, trabajador y turnos sin cubrir.
- **Solo lectura lógica**: la función usa tablas temporales y no cambia datos permanentes.

## Límites conocidos
- No optimiza automáticamente desfases ni genera turnos multipuesto.
- La asignación de relevos es voraz (greedy); un resultado incompleto no demuestra que no exista una solución mejor.
- No valida aún tiempo de traslado, preferencia de turno, descanso semanal ni topes legales/contractuales de jornada.
- Los turnos futuros PROGRAMADO de los planes incluidos se ignoran para permitir simular su reemplazo; los turnos iniciados y los de otros planes sí bloquean disponibilidad.
- No ejecutar generación individual en producción basándose únicamente en esta simulación.

## Instalación
1. Subir los archivos del ZIP a GitHub respetando sus rutas.
2. Verificar que Vercel compile.
3. Ejecutar `supabase/v3_4_3_global_simulator.sql` completo en Supabase SQL Editor.
4. En Planificación, sección 6, seleccionar el pool y pulsar «Simular puestos juntos».
5. Verificar que aparezcan los puestos 000001 y 000002 y que no se modifiquen los turnos históricos.

## Próxima fase
Optimizador de desfases conjunto, asignación con búsqueda/reoptimización, reglas laborales configurables y generación transaccional multipuesto.
