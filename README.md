# PROVICA — Control de Guardias

MVP web responsive para gestión de asistencia, turnos y cobertura de puestos de seguridad.

## Incluye
- Dashboard de operaciones
- Modelo de roles ADMIN / RRHH / OPERACIONES / SUPERVISOR / GUARDIA
- Clientes, instalaciones y geocercas
- Puestos con cobertura configurable 8/12/24 h
- Turnos individuales separados de la duración de cobertura
- Marcaciones: entrada, salida y relevos
- Base para GPS, fotografía, dispositivo e incidentes
- Auditoría de cambios

## Ejecutar localmente
1. Instalar Node.js 20 o superior.
2. `npm install`
3. `npm run dev`
4. Abrir http://localhost:3000

## Supabase
Crear un proyecto y ejecutar `supabase/schema.sql` desde SQL Editor.
Copiar `.env.example` a `.env.local` y completar las variables públicas del proyecto.

## Publicación
Importar este repositorio en Vercel. Next.js será detectado automáticamente.

> Importante: no subir `.env.local`, contraseñas ni claves privadas a GitHub.
