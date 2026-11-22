# Auditoría UI/UX según Nielsen

## Estado general

La interfaz Godot ya usa tema compartido, controles flexibles y feedback. La auditoría confirma mejoras aplicadas y resuelve principalmente la salida segura de partidas activas.

## Hallazgos y mejoras

| Principio | Evaluación | Mejora |
|---|---|---|
| Visibilidad | Buena: temporizador, estados versus y carga | Mantener deshabilitados los botones mientras hay solicitudes |
| Mundo real | Buena: mensajes detectivescos | Evitar exponer códigos técnicos |
| Control y libertad | Corregida: salida activa con confirmación | Agregar confirmación en el tablero |
| Consistencia | Buena: tema pixel compartido | Usar el mismo tema en todas las pantallas |
| Prevención | Buena: casillas fijas bloqueadas | Mantener comprobaciones en drag y clic |
| Reconocimiento | Buena: leyendas y reglas visibles | Mantener pistas disponibles |
| Flexibilidad | Buena: drag & drop y clic | Conservar ambos mecanismos |
| Minimalismo | Buena: jerarquía por contenedores | Eliminar texto técnico y nodos basura |
| Recuperación | Buena: mensajes y reintento | Mantener acción de reintento sin cadenas HTTP |
| Ayuda | Buena: tutorial accesible | Mantener tutorial desde menú y tablero |

## Checklist visual

| Verificación | Resultado esperado |
|---|---|
| Resolución mínima | Sin solapes ni controles fuera de pantalla |
| Contraste | Texto legible sobre fondo claro |
| Carga | Indicadores visibles |
| Error | Mensaje comprensible y acción Reintentar |
| Confirmación | No abandonar partida activa sin confirmación |
| Accesibilidad | Traducciones ES/EN completas |
