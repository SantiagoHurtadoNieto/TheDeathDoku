# Decisiones de arquitectura

## ADR-001 — Conservar Godot como cliente

- **Estado:** aceptada.
- **Contexto:** el cliente funcional ya está implementado en Godot y ofrece escenas, recursos y pruebas de regresión. Migrarlo a React/Vite reescribiría la interfaz sin cubrir un requisito funcional faltante.
- **Decisión:** mantener Godot 4.7 como frontend del proyecto y cerrar sus flujos y pruebas en el mismo cliente.
- **Consecuencias:** se conserva la inversión existente; Lighthouse/axe web no aplican directamente. La accesibilidad se verifica con controles de teclado, foco, etiquetas, contraste y reducción de movimiento en Godot.

## ADR-002 — Commits manuales del usuario

- **Estado:** aceptada.
- **Contexto:** el usuario indicó que realizará los commits manualmente.
- **Decisión:** dejar los cambios en los repositorios de trabajo sin crear commits ni alterar historial.
- **Consecuencias:** el usuario revisa y agrupa los cambios cuando lo decida.

## ADR-003 — Mantener Opciones y añadir acceso compacto al idioma

- **Estado:** aceptada.
- **Contexto:** la regresión de menú exigía solo tres botones y el selector de idioma no existía. El requisito del usuario mantiene el botón Opciones visible, y las pruebas de pantallas requieren poder cambiar idioma desde el menú principal.
- **Decisión:** conservar las tres opciones de juego y el botón Opciones; añadir un selector compacto `es/en` en la esquina inferior derecha. Mantener también el selector detallado dentro de Opciones.
- **Consecuencias:** la regresión verifica cuatro acciones centrales y el acceso compacto al idioma sin retirar funcionalidad existente.
