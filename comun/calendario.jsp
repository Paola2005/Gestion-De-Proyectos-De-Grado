<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ include file="/WEB-INF/jspf/guard.jspf" %>

<c:set var="puedeGestionarCal" value="${not empty sessionScope.rol_activo ? (sessionScope.rol_activo == 'comite' or sessionScope.rol_activo == 'administrador') : (fn:contains(sessionScope.roles,'comite') or fn:contains(sessionScope.roles,'administrador'))}"/>
<c:if test="${param.accion == 'crear' and puedeGestionarCal}">
  <c:catch var="err">
    <sql:update dataSource="${db}">
      INSERT INTO calendario_actividades (periodo_id, titulo, descripcion, fecha_inicio, fecha_fin, tipo, responsable)
      VALUES (?,?,?,?,?,?,?)
      <sql:param value="${param.periodo_id}"/><sql:param value="${param.titulo}"/><sql:param value="${param.descripcion}"/>
      <sql:param value="${param.fecha_inicio}"/><sql:param value="${param.fecha_fin}"/><sql:param value="${param.tipo}"/><sql:param value="${sessionScope.usuario_id}"/>
    </sql:update>
    <c:redirect url="/comun/calendario.jsp"><c:param name="ok" value="Actividad creada"/></c:redirect>
  </c:catch>
  <c:if test="${not empty err}"><c:redirect url="/comun/calendario.jsp"><c:param name="error" value="Error al crear la actividad. Intente de nuevo."/></c:redirect></c:if>
</c:if>

<c:if test="${param.accion == 'eliminar' and puedeGestionarCal}">
  <sql:update dataSource="${db}">DELETE FROM calendario_actividades WHERE id=?<sql:param value="${param.id}"/></sql:update>
  <c:redirect url="/comun/calendario.jsp"><c:param name="ok" value="Actividad eliminada"/></c:redirect>
</c:if>

<sql:query dataSource="${db}" var="periodoActivo">SELECT * FROM periodos WHERE activo=1 LIMIT 1</sql:query>
<sql:query dataSource="${db}" var="actividades">
  SELECT ca.*, CONCAT(u.nombres,' ',u.apellidos) AS responsable_nombre
  FROM calendario_actividades ca LEFT JOIN usuarios u ON ca.responsable=u.id
  WHERE ca.periodo_id=? ORDER BY ca.fecha_inicio
  <sql:param value="${periodoActivo.rows[0].id}"/>
</sql:query>

<!DOCTYPE html>
<html lang="es">
<head><title>Calendario [ACADÉMICO] - SIGRADO</title><%@ include file="/WEB-INF/jspf/header.jspf" %></head>
<body>
<%@ include file="/WEB-INF/jspf/sidebar.jspf" %>
<main class="main">
  <header class="topbar">
    <div class="welcome">Calendario <span class="text-uts">[ACADÉMICO]</span></div>
    <div class="user-info"><div class="user-name">${sessionScope.usuario_nombres} ${sessionScope.usuario_apellidos}</div><div class="user-rol">${sessionScope.rol_principal}</div></div>
  </header>
  <div class="container-fluid py-4 px-4">
    <div class="row g-4">
      <div class="col-12">
        <div class="card-uts mb-4">
          <div class="card-header-uts d-flex justify-content-between align-items-center">
            <h5 class="card-title-institucional mb-0">Calendario Oficial UTS</h5>
            <a href="https://www.uts.edu.co/sitio/calendario-academico/" target="_blank" class="btn btn-uts btn-sm"><i class="fas fa-external-link-alt me-1"></i> Ver en Sitio Web</a>
          </div>
          <div class="card-body">
            <div class="alert alert-info">
              <i class="fas fa-info-circle me-2"></i>
              Consulte el <strong>calendario académico oficial de la UTS</strong> para fechas de matrícula, exámenes, vacaciones y ceremonias de grado.
            </div>
          </div>
        </div>
      </div>
      <div class="col-lg-8">
        <div class="card-uts mb-4">
          <div class="card-header-uts d-flex justify-content-between align-items-center">
            <h5 class="card-title-institucional mb-0">Actividades del Periodo ${periodoActivo.rows[0].codigo}</h5>
            <c:if test="${fn:contains(sessionScope.roles,'comite') or fn:contains(sessionScope.roles,'administrador')}">
              <button class="btn btn-uts btn-sm" data-bs-toggle="modal" data-bs-target="#nuevaActividad"><i class="fas fa-plus me-1"></i> Agregar</button>
            </c:if>
          </div>
          <div class="card-body p-0">
            <div class="table-responsive">
              <table class="table table-hover mb-0">
                <thead><tr><th>Fecha</th><th>Título</th><th>Tipo</th><th>Responsable</th><th>Acciones</th></tr></thead>
                <tbody>
                  <c:forEach items="${actividades.rows}" var="a">
                    <tr>
                      <td><strong>${fn:substring(a.fecha_inicio,0,10)}</strong> <c:if test="${a.fecha_fin != a.fecha_inicio}">a ${fn:substring(a.fecha_fin,0,10)}</c:if></td>
                      <td>${a.titulo}<br><small class="text-muted">${a.descripcion}</small></td>
                      <td><span class="badge bg-info text-white">${a.tipo}</span></td>
                      <td>${a.responsable_nombre}</td>
                      <td>
                        <c:if test="${fn:contains(sessionScope.roles,'comite') or fn:contains(sessionScope.roles,'administrador')}">
                          <a href="calendario.jsp?accion=eliminar&id=${a.id}" class="btn-action btn-retirar" onclick="return confirm('¿Eliminar actividad?')"><i class="fas fa-trash"></i></a>
                        </c:if>
                      </td>
                    </tr>
                  </c:forEach>
                  <c:if test="${actividades.rowCount==0}"><tr><td colspan="5" class="empty-state">No hay actividades registradas</td></tr></c:if>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>
      <div class="col-lg-4">
        <div class="card-uts">
          <div class="card-header-uts"><h5 class="card-title-institucional mb-0">Fechas Clave del Periodo</h5></div>
          <div class="card-body">
            <ul class="list-group list-group-flush">
              <li class="list-group-item d-flex justify-content-between"><span>Inicio Propuestas Banco</span><strong>${fn:substring(periodoActivo.rows[0].inicio_propuestas_banco,0,10)}</strong></li>
              <li class="list-group-item d-flex justify-content-between"><span>Fin Propuestas Banco</span><strong>${fn:substring(periodoActivo.rows[0].fin_propuestas_banco,0,10)}</strong></li>
              <li class="list-group-item d-flex justify-content-between"><span>Inicio Nuevos Proyectos</span><strong>${fn:substring(periodoActivo.rows[0].inicio_nuevos_proyectos,0,10)}</strong></li>
              <li class="list-group-item d-flex justify-content-between"><span>Fin Aprobación Propuesta (Fase 1)</span><strong>${fn:substring(periodoActivo.rows[0].fin_aprobacion_propuesta,0,10)}</strong></li>
            </ul>
          </div>
        </div>
      </div>
    </div>

    <!-- Modal Nueva Actividad -->
    <c:if test="${fn:contains(sessionScope.roles,'comite') or fn:contains(sessionScope.roles,'administrador')}">
      <div class="modal fade" id="nuevaActividad" tabindex="-1">
        <div class="modal-dialog"><form method="post" class="modal-content">
          <input type="hidden" name="accion" value="crear"/><input type="hidden" name="periodo_id" value="${periodoActivo.rows[0].id}"/>
          <div class="modal-header bg-uts"><h5 class="modal-title">Nueva Actividad</h5><button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button></div>
          <div class="modal-body row g-3">
            <div class="col-12"><label class="form-label">Título *</label><input type="text" name="titulo" class="form-control" required></div>
            <div class="col-12"><label class="form-label">Descripción</label><textarea name="descripcion" class="form-control" rows="2"></textarea></div>
            <div class="col-md-6"><label class="form-label">Fecha Inicio *</label><input type="date" name="fecha_inicio" class="form-control" required></div>
            <div class="col-md-6"><label class="form-label">Fecha Fin</label><input type="date" name="fecha_fin" class="form-control"></div>
            <div class="col-md-6"><label class="form-label">Tipo *</label><select name="tipo" class="form-select" required><option value="">Seleccione</option><option value="Academico">Académico</option><option value="Administrativo">Administrativo</option><option value="Grado">Grado</option><option value="Otro">Otro</option></select></div>
          </div>
          <div class="modal-footer"><button type="submit" class="btn btn-uts">Guardar</button></form></div>
      </div>
    </c:if>
  </div>
  <%@ include file="/WEB-INF/jspf/footer.jspf" %>
</main>
</body>
</html>
