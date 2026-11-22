# DeathDoku

DeathDoku es un juego de deducción con cliente Godot y servicios desacoplados para perfil, casos y partidas. El despliegue local usa Docker Compose.

## Inicio rápido

1. Copia .env.example a .env y define valores de desarrollo. No compartas ni versionees .env.
2. Desde esta carpeta ejecuta: docker compose up --build -d
3. Abre death-doku/project.godot con Godot 4.7.2 y pulsa Ejecutar proyecto. El primer acceso requiere enrolamiento TOTP en Keycloak.

El cliente todavía no se ejecuta desde Compose con un único comando. URLs locales principales: Gateway http://localhost:8765, Keycloak http://localhost:8180, Eureka http://localhost:8762, Prometheus http://localhost:9090 y Grafana http://localhost:3000. La API de casos se enruta por Gateway; OpenAPI aún requiere agregación.

## Estructura

| Carpeta | Contenido |
|---|---|
| death-doku/ | Cliente Godot, escenas, recursos y regresiones |
| apigateway/ | Gateway Spring y validación JWT |
| users_service/ | Perfil, progreso y eventos |
| cases-service/ | Catálogo y validación de casos |
| partidas-service/ | Partidas Classic, Timed y Versus |
| eureka-server/ | Descubrimiento de servicios |
| infra/ | Keycloak, Kafka y observabilidad |
| docs/ | Auditoría, plan, decisiones y entregables |

## Pruebas

- Compose: docker compose config --quiet y docker compose build.
- Casos: desde cases-service, npm run build y npm test -- --runInBand.
- Usuarios: users_service/tests/run_postgres_migrations.ps1.
- Partidas: desde partidas-service, ejecutar tests/run_h04_03_isolated.ps1, tests/run_h04_04_isolated.ps1 y tests/run_h04_05_isolated.ps1.
- Gateway/Eureka: mvnw.cmd test desde cada módulo.
- Godot: tests/run_all.ps1 desde death-doku; requiere Godot 4.7.2 y Docker accesible.

Consulta docs/AUDITORIA_INICIAL.md y docs/PLAN.md para brechas y criterios. No se considera cerrada la entrega final mientras queden requisitos abiertos en la matriz.
