# Instalación y configuración

## Prerequisitos

| Herramienta | Versión recomendada |
|---|---|
| Windows + PowerShell | Actual |
| Docker Desktop | Con Compose v2 |
| Java JDK | Compatible con los módulos Maven |
| Node.js | Compatible con NestJS |
| Python | 3.11 o superior |
| Godot | 4.7.2 |

## Preparación

1. Copiar `.env.example` a `.env`.
2. Reemplazar contraseñas y secretos.
3. Crear el archivo secreto indicado por `METRICS_SCRAPE_PASSWORD_FILE`.
4. Verificar puertos libres: `8762`, `8765`, `8180`, `3000`, `9090`.

## Levantamiento

```powershell
docker compose up --build
```

Para ejecutar en segundo plano:

```powershell
docker compose up --build -d
docker compose ps
```

## Importación de Keycloak

El compose incluido importa `realm-hopedoku.json`. Configurar las contraseñas semilla mediante variables `KC_*`.

## Verificación

| Recurso | URL |
|---|---|
| Gateway | http://localhost:8765 |
| Eureka | http://localhost:8762 |
| Keycloak | http://localhost:8180 |
| Prometheus | http://localhost:9090 |
| Grafana | http://localhost:3000 |

Pruebas mínimas:

```powershell
curl http://localhost:8765/usuarios/health
```

La ruta exacta de usuarios se debe verificar en `/usuarios/health`.
