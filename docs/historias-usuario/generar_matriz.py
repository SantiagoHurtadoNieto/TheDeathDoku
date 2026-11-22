"""Genera la matriz de HU en XLSX."""
from pathlib import Path
from openpyxl import Workbook
from openpyxl.styles import Alignment, Font, PatternFill
from openpyxl.utils import get_column_letter

HEADERS = ["ID","Épica","Enunciado","Alias","Prioridad","Criterios de aceptación (Dado/Cuando/Entonces)","Servicio(s) responsable(s)","Endpoint(s)","Pruebas asociadas","Estado auditado"]
ROWS = [
["HU-01","E1 Tablero","Como jugador, quiero seleccionar un caso de biblioteca para elegir el misterio.","Elegir caso","Must","Dado un jugador, cuando filtra categoría/dificultad/estado, entonces ve casos con vista previa; hay ≥3 casos por hogar/oficina/trabajo/turístico y tableros 6x6, 8x8, 9x9.","Godot; cases-service","GET /cases","verify_case_library.gd; cases Jest","Parcial"],
["HU-02","E1 Tablero","Como jugador, quiero ver tablero, sospechosos, víctima, habitaciones y objetos.","Ver escena","Must","Dado un caso, cuando abro el tablero, entonces habitaciones y ocupabilidad se distinguen por texto/patrón/iconos y etiquetas accesibles.","Godot; cases-service","GET /cases/{id}","verify_board.gd; cases Jest","Parcial"],
["HU-03","E1 Tablero","Como jugador, quiero colocar, mover y retirar personajes según las pistas.","Marcar sospechosos","Must","Dado un personaje, cuando elijo casilla, entonces puedo colocarlo por mouse/teclado/táctil, ver conflictos y deshacer/rehacer.","Godot; partidas-service","/matches/*","verify_board.gd; verify_classic.gd","Parcial"],
["HU-04","E1 Tablero","Como jugador, quiero leer y aplicar indicios para deducir posiciones.","Leer pistas","Must","Dado un caso, cuando consulto pistas, entonces aparecen numeradas, marcables aplicada/descartada y resaltan referencias en el tablero.","Godot; cases-service","GET /cases/{id}","verify_case_library.gd; cases Jest","Parcial"],
["HU-05","E1 Tablero","Como jugador, quiero marcar candidatos en casillas.","Notas candidatos","Should","Dado un tablero, cuando activo notas, entonces puedo añadir/quitar/limpiar candidatos y recuperarlos al reanudar.","Godot; partidas-service","Estado de partida por confirmar","verify_board.gd; persistencia pendiente","Parcial"],
["HU-06","E1 Tablero","Como jugador, quiero confirmar la resolución e identificación del asesino.","Caso resuelto","Must","Dado un tablero completo, cuando envío solución y asesino, entonces backend valida, devuelve resumen y emite CaseSolved.","cases; partidas; users","POST /cases/{id}/validate","cases.e2e-spec; verify_classic; saga pendiente","Parcial"],
["HU-07","E1 Tablero","Como jugador, quiero usar ayudas al atascarme.","Pedir ayuda","Should","Dado un caso activo, cuando confirmo ayuda, entonces recibo pista gradual, contador y penalización visibles sin revelar solución completa.","Godot; cases; partidas","GET /cases/{id}/hints","cases Jest; penalización pendiente","Parcial"],
["HU-08","E2 Versus","Como jugador, quiero crear o unirme a una partida versus.","Crear partida VS","Must","Dado un jugador, cuando crea sala o usa código/matchmaking, entonces ambos reciben caso y estados de sala/reconexión.","Godot; partidas","/matches/*","verify_timed_versus.gd; partidas pytest","Parcial"],
["HU-09","E2 Versus","Como jugador, quiero ver progreso del rival en tiempo real sin ver su tablero.","Progreso rival","Must","Dada una partida, cuando cambia progreso, entonces recibo porcentaje/estado en tiempo real sin posiciones privadas.","partidas; Godot","Canal realtime faltante","Pendiente de crear","Faltante"],
["HU-10","E2 Versus","Como jugador, quiero que primero en resolver gane y obtenga experiencia.","Resultado VS","Must","Dada partida versus, cuando se resuelve, entonces servidor decide por timestamp, persiste ganador/XP idempotentemente y gestiona empate/abandono.","partidas; users; Kafka","/matches/*; eventos","H04-04/05; E2E pendiente","Parcial"],
["HU-11","E2 Versus","Como jugador, quiero puntaje competitivo para medir mi nivel.","Ver puntaje","Should","Dado resultado, cuando consulto ranking, entonces veo fórmula documentada, historial y ranking sincronizado por eventos.","partidas; users","API de ranking/perfil","users tests; E2E pendiente","Parcial"],
["HU-12","E3 Contrarreloj","Como jugador, quiero iniciar un caso con límite de tiempo.","Crear contrarreloj","Must","Dada dificultad, cuando inicio, entonces backend fija plazo y cliente muestra reloj que no puede pausarse.","partidas; Godot","/matches/timed","verify_timed_versus.gd; partidas pytest","Parcial"],
["HU-13","E3 Contrarreloj","Como jugador, quiero que al agotarse el tiempo termine y reduzca XP.","Expiración","Must","Dado reloj vencido, cuando servidor expira partida, entonces bloquea jugadas, emite TimeAttackExpired y reduce XP con piso cero.","partidas; users; Kafka","API timed; evento","H04-04/05; E2E pendiente","Parcial"],
["HU-14","E3 Contrarreloj","Como jugador, quiero bonificaciones por resolver rápido.","Bonificaciones","Should","Dada resolución temprana, cuando se calcula resultado, entonces aplica tramo documentado y explica bonus en resumen.","partidas; users","API resultados","Tramos/resumen pendientes","Parcial"],
["HU-15","E4 Perfil","Como jugador, quiero cuenta con nombre/avatar y personalizarla.","Personalizar cuenta","Must","Dado usuario autenticado, cuando edita perfil, entonces nombre/avatar validado se guarda y muestra.","Keycloak; users; Godot","GET/PUT /usuarios/me","users tests; perfil E2E pendiente","Parcial"],
["HU-16","E4 Perfil","Como jugador, quiero ver progreso y mejores tiempos por caso.","Mis mejores tiempos","Must","Dado mi perfil, cuando consulto progreso, entonces veo casos resueltos, tiempo total, racha actual/máxima, mejores tiempos e historial.","users; Godot","GET /usuarios/me/stats; /solved-cases","users tests; profile E2E pendiente","Parcial"],
["HU-17","E4 Perfil","Como jugador, quiero logros y medallas por hitos.","Logros","Should","Dado evento de progreso, cuando se cumple hito, entonces uno de ≥10 logros se desbloquea idempotentemente, notifica y muestra progreso.","users; Kafka; Godot","GET /usuarios/me/achievements","128 users tests; vitrina E2E pendiente","Parcial: catálogo de 11; UI pendiente"],
["HU-18","E4 Perfil","Como jugador, quiero iniciar sesión con MFA para proteger mi progreso.","Login","Must","Dado primer acceso, cuando autentico y enroló TOTP, entonces recibo token, renuevo/cierro sesión y accedo según rol JUGADOR/ADMIN.","Keycloak; Gateway; Godot","OIDC Keycloak; rutas Gateway","verify_logout/refresh; MFA manual pendiente","Parcial: requiere enrolamiento"],
["HU-19","E5 Experiencia","Como jugador, quiero tutorial interactivo de reglas básicas.","Tutorial","Should","Dado jugador nuevo, cuando abre tutorial, entonces completa/omite cinco pasos en tablero 4x4, persiste visto y puede repetir.","Godot; users","PUT /usuarios/me/tutorial","verify_ui_strict; E2E pendiente","Parcial"],
["HU-20","E5 Experiencia","Como jugador, quiero cambiar ES/EN en caliente y persistir preferencia.","Cambiar idioma","Should","Dada cualquier pantalla, cuando cambio idioma, entonces UI/errores/casos cambian y preferencia queda guardada localmente y en perfil.","Godot; users; cases","PATCH /usuarios/me/language; Accept-Language pendiente","verify_main_menu/journal pasan; cobertura pendiente","Parcial: selector corregido"],
["HU-21","E6 Administración","Como administrador, quiero crear y gestionar casos.","Gestionar casos","Must","Dado rol ADMIN, cuando crea/edita/publica, entonces solver verifica unicidad, admite borrador/publicado y audita cambios; no admin no puede CRUD.","cases; Gateway","POST/PUT/DELETE /admin/cases","cases Jest; solver/RBAC/auditoría pendiente","Parcial"],
]

def main():
    wb = Workbook()
    ws = wb.active
    ws.title = "Historias HU"
    ws.sheet_view.showGridLines = False
    ws.append(["DeathDoku — Historias de usuario actualizadas"])
    ws.append(["Fuente: PROMPT_CODEX_DeathDoku.md. HU-18 se completa con MFA; estados basados en auditoría del 22-11-2026."])
    ws.append([])
    ws.append(HEADERS)
    for row in ROWS:
        ws.append(row)
    ws.merge_cells("A1:J1")
    ws.merge_cells("A2:J2")
    ws["A1"].font = Font(name="Arial", size=14, bold=True, color="FFFFFF")
    ws["A1"].fill = PatternFill("solid", fgColor="253247")
    ws["A2"].font = Font(name="Arial", size=10, italic=True, color="49515C")
    for cell in ws[4]:
        cell.fill = PatternFill("solid", fgColor="374B64")
        cell.font = Font(name="Arial", size=10, bold=True, color="FFFFFF")
        cell.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
    for row in ws.iter_rows(min_row=5, max_row=25, min_col=1, max_col=10):
        for cell in row:
            cell.font = Font(name="Arial", size=9, color="202124")
            cell.alignment = Alignment(vertical="top", wrap_text=True)
    widths = [10, 22, 45, 24, 14, 66, 30, 34, 38, 28]
    for i, width in enumerate(widths, 1):
        ws.column_dimensions[get_column_letter(i)].width = width
    ws.row_dimensions[1].height = 26
    ws.row_dimensions[2].height = 30
    ws.row_dimensions[4].height = 36
    for i in range(5, 26):
        ws.row_dimensions[i].height = 64
    ws.freeze_panes = "A5"
    ws.auto_filter.ref = "A4:J25"
    ws.page_setup.orientation = "landscape"
    ws.page_setup.fitToWidth = 1
    ws.page_setup.fitToHeight = 0
    ws.sheet_properties.pageSetUpPr.fitToPage = True
    out = Path(__file__).with_name("DeathDoku_HU_actualizado.xlsx")
    wb.save(out)
    print(f"{out}: {len(ROWS)} historias")

if __name__ == "__main__":
    main()
