# API Gateway y Eureka

## API Gateway

El Gateway escucha en `8765`. Valida JWT con JWKS de Keycloak, verifica issuer, audiencia y cliente autorizado, elimina cabeceras de identidad externas y crea `X-User-Id` y `X-Roles`.

## Rutas públicas

| Ruta | Destino |
|---|---|
| `/usuarios/health` | Health de usuarios |
| `/usuarios/swagger-ui/**` | Documentación usuarios |
| `/usuarios/v3/api-docs/**` | OpenAPI usuarios |
| `/actuator/health` | Gestión Gateway |

Rutas públicas adicionales solo deben incluir autenticación/discovery explícitamente exigidos.

## Rutas protegidas

| Prefijo | Servicio |
|---|---|
| `/usuarios/**` | usuarios-service |
| `/casos/**` | casos-service |
| `/partidas/**` | partidas-service |

## Eureka

Todos los servicios se registran con nombres de Docker y Eureka. Los clientes internos deben usar Eureka o nombres DNS; no se deben quemar IPs.

## Seguridad de cabeceras

El cliente Godot no envía `X-User-Id`, `X-Roles` ni `X-Gateway-Secret`. El Gateway es el único componente que completa estas cabeceras. Si llegan del exterior se eliminan antes de inyectar valores derivados del token.
