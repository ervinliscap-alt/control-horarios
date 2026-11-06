# Seguridad bajo control V3.4.5 — Navegación por pestañas y dashboard

## Instalación
Subir los archivos respetando las rutas. No requiere ejecutar SQL ni borrar turnos.

## Cambios
- Planificación dividida en pestañas: Titulares y puestos, Horarios, Pools de sacafrancos, Simulación global, Generación coordinada, Limpieza (ADMIN) y Dashboard.
- Dashboard de consulta con filtros por puesto, trabajador y turnos actuales/próximos.
- Identificación de titular frente a relevo por comparación con el titular actual del cajón.
- Consulta de solo lectura a `shifts`, respetando las políticas RLS existentes.

## Límites
- La pestaña «Titulares y puestos» conserva el componente original con sus secciones de creación y dotación; dividir internamente estas dos funciones queda pendiente.
- El dashboard no confirma presencia física ni asistencia.
- Los turnos de personas inactivas pueden mostrarse sin nombre porque el catálogo de personal enviado a la página filtra activos.
- El dashboard consulta un máximo de 1000 turnos y una ventana aproximada de 35 días. No es auditoría histórica exhaustiva.
- Las pestañas mantienen montado únicamente el componente activo: al cambiar de pestaña se reinicia el estado local no guardado.
- No se implementan todavía optimización global de desfases, validación legal contractual, traslados ni dashboard histórico completo.

## Pruebas recomendadas
1. Comprobar que la compilación en Vercel finalice correctamente.
2. Abrir cada pestaña y confirmar que los componentes previos siguen funcionando.
3. Abrir Dashboard y contrastar los turnos actuales y futuros con Supabase.
4. Verificar que el usuario no ADMIN no vea Limpieza.
5. No generar ni limpiar turnos durante la prueba visual.
