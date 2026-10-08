<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c"   uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="sql" uri="http://java.sun.com/jsp/jstl/sql" %>
<%@ taglib prefix="fn"  uri="http://java.sun.com/jsp/jstl/functions" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<%@ include file="/WEB-INF/jspf/guardDocente.jspf" %>

<%-- Procesamiento: Respuesta Evaluador Fase 3 (Propuesta II, solo turno F3·Evaluador) --%>
<c:if test="${param.accion == 'responder_fase3' and not empty param.proyecto_id}">
  <c:catch var="errF3">
    <sql:query dataSource="${db}" var="turnoE3">
      SELECT fase, responsable, estado, evaluador_id FROM proyectos WHERE id = ?
      <sql:param value="${param.proyecto_id}"/>
    </sql:query>
    <c:if test="${turnoE3.rowCount == 0 or turnoE3.rows[0].fase != 3 or turnoE3.rows[0].responsable != 'evaluador' or turnoE3.rows[0].estado != 'En curso' or turnoE3.rows[0].evaluador_id != sessionScope.usuario_id}">
      <c:redirect url="/docente/evaluador.jsp"><c:param name="error" value="No tiene el turno para responder este proyecto."/></c:redirect>
    </c:if>
    <%-- Responder sobre un proyecto existente no usa las ventanas de inscripción. --%>
    <c:if test="${not empty param.propuesta_url and not fn:startsWith(param.propuesta_url,'https://')}">
      <c:redirect url="/docente/evaluador.jsp"><c:param name="error" value="La propuesta firmada debe ser una URL válida (https://)."/></c:redirect>
    </c:if>
    <%-- Evaluador aprueba Fase 3 solo con URL de la propuesta firmada F-DC-124 --%>
    <c:if test="${param.estado == 'Aprobado' and (empty param.propuesta_url or not fn:startsWith(param.propuesta_url,'https://'))}">
      <c:redirect url="/docente/evaluador.jsp"><c:param name="error" value="Para aprobar Fase 3 debe adjuntar la URL de la propuesta firmada F-DC-124 (https://)."/></c:redirect>
    </c:if>
    <sql:query dataSource="${db}" var="rondaE3">
      SELECT COUNT(*)+1 AS sig FROM respuestas WHERE proyecto_id = ? AND fase = 3
      <sql:param value="${param.proyecto_id}"/>
    </sql:query>
    <sql:query dataSource="${db}" var="verE3">
      SELECT COALESCE(MAX(version),0) AS mv FROM documentos WHERE proyecto_id = ? AND tipo = 'Propuesta_FDC124'
      <sql:param value="${param.proyecto_id}"/>
    </sql:query>
    <sql:transaction dataSource="${db}">
      <sql:update>
        INSERT INTO respuestas (proyecto_id, fase, ronda, version_evaluada, usuario_id, rol, estado, acta_numero, acta_fecha, comentario, propuesta_url)
        VALUES (?, 3, ?, ?, ?, 'evaluador', ?, ?, ?, ?, ?)
        <sql:param value="${param.proyecto_id}"/>
        <sql:param value="${rondaE3.rows[0].sig}"/>
        <sql:param value="${verE3.rows[0].mv}"/>
        <sql:param value="${sessionScope.usuario_id}"/>
        <sql:param value="${param.estado}"/>
        <sql:param value="${param.acta}"/>
        <sql:param value="${param.acta_fecha}"/>
        <sql:param value="${param.comentario}"/>
        <sql:param value="${param.propuesta_url}"/>
      </sql:update>

      <%-- Registrar documento F-DC-124 firmado si ingresó URL --%>
      <c:if test="${not empty param.propuesta_url}">
        <sql:query var="maxV3">
          SELECT COALESCE(MAX(version),0)+1 AS sigVer FROM documentos 
          WHERE proyecto_id = ? AND tipo = 'Propuesta_FDC124'
          <sql:param value="${param.proyecto_id}"/>
        </sql:query>
        <sql:update>
          INSERT INTO documentos (proyecto_id, fase, tipo, version, url, nombre_archivo, subido_por)
          VALUES (?, 3, 'Propuesta_FDC124', ?, ?, 'Propuesta F-DC-124 Firmada', ?)
          <sql:param value="${param.proyecto_id}"/>
          <sql:param value="${maxV3.rows[0].sigVer}"/>
          <sql:param value="${param.propuesta_url}"/>
          <sql:param value="${sessionScope.usuario_id}"/>
        </sql:update>
      </c:if>

      <c:choose>
        <c:when test="${param.estado == 'Aprobado'}">
          <sql:update>UPDATE proyectos SET fase = 3, responsable = 'comite', estado = 'En curso' WHERE id = ? AND fase = 3 AND responsable = 'evaluador' AND estado = 'En curso'<sql:param value="${param.proyecto_id}"/></sql:update>
        </c:when>
        <c:when test="${param.estado == 'Correcciones'}">
          <sql:update>UPDATE proyectos SET fase = 2, responsable = 'estudiante', estado = 'En curso' WHERE id = ? AND fase = 3 AND responsable = 'evaluador' AND estado = 'En curso'<sql:param value="${param.proyecto_id}"/></sql:update>
        </c:when>
        <c:when test="${param.estado == 'Rechazado'}">
          <sql:update>UPDATE proyectos SET estado = 'Rechazado', responsable = 'comite' WHERE id = ? AND estado = 'En curso'<sql:param value="${param.proyecto_id}"/></sql:update>
        </c:when>
      </c:choose>

      <sql:update>
        INSERT INTO historial (proyecto_id, usuario_id, accion, fase, acta_numero, comentario)
        VALUES (?, ?, 'Dictamen Evaluador Fase 3', 3, ?, ?)
        <sql:param value="${param.proyecto_id}"/>
        <sql:param value="${sessionScope.usuario_id}"/>
        <sql:param value="${param.acta}"/>
        <sql:param value="Dictamen registrado."/>
      </sql:update>

      <sql:update>
        INSERT INTO auditoria (usuario_id, accion, entidad, detalle)
        VALUES (?, 'Dictamen Evaluador Fase 3', 'proyectos', ?)
        <sql:param value="${sessionScope.usuario_id}"/>
        <sql:param value="Evaluador emitió dictamen en Fase 3 para proyecto ID ${param.proyecto_id}"/>
      </sql:update>
    </sql:transaction>
    <c:redirect url="/docente/evaluador.jsp"><c:param name="ok" value="Respuesta enviada correctamente"/></c:redirect>
  </c:catch>
  <c:if test="${not empty errF3}"><c:set var="errorMsg" value="Error en Fase 3. Intente de nuevo."/></c:if>
</c:if>

<%-- Procesamiento: Respuesta Evaluador Fase 5 (Informe II, solo turno F5·Evaluador) --%>
<c:if test="${param.accion == 'responder_fase5' and not empty param.proyecto_id}">
  <c:catch var="errF5">
    <sql:query dataSource="${db}" var="turnoE5">
      SELECT fase, responsable, estado, evaluador_id FROM proyectos WHERE id = ?
      <sql:param value="${param.proyecto_id}"/>
    </sql:query>
    <c:if test="${turnoE5.rowCount == 0 or turnoE5.rows[0].fase != 5 or turnoE5.rows[0].responsable != 'evaluador' or turnoE5.rows[0].estado != 'En curso' or turnoE5.rows[0].evaluador_id != sessionScope.usuario_id}">
      <c:redirect url="/docente/evaluador.jsp"><c:param name="error" value="No tiene el turno para responder este proyecto."/></c:redirect>
    </c:if>
    <%-- Responder sobre un proyecto existente no usa las ventanas de inscripción. --%>
    <c:if test="${(not empty param.informe_url and not fn:startsWith(param.informe_url,'https://')) or (not empty param.rejilla_url and not fn:startsWith(param.rejilla_url,'https://'))}">
      <c:redirect url="/docente/evaluador.jsp"><c:param name="error" value="Las URLs del informe y rejilla deben ser https:// válidas."/></c:redirect>
    </c:if>
    <%-- Evaluador aprueba Fase 5 solo con URL del informe firmado F-DC-125 y de la rejilla F-DC-129 --%>
    <c:if test="${param.estado == 'Aprobado' and ((empty param.informe_url or not fn:startsWith(param.informe_url,'https://')) or (empty param.rejilla_url or not fn:startsWith(param.rejilla_url,'https://')))}">
      <c:redirect url="/docente/evaluador.jsp"><c:param name="error" value="Para aprobar Fase 5 debe adjuntar la URL del informe firmado F-DC-125 y de la rejilla F-DC-129 (https://)."/></c:redirect>
    </c:if>
    <sql:query dataSource="${db}" var="rondaE5">
      SELECT COUNT(*)+1 AS sig FROM respuestas WHERE proyecto_id = ? AND fase = 5
      <sql:param value="${param.proyecto_id}"/>
    </sql:query>
    <sql:query dataSource="${db}" var="verE5">
      SELECT COALESCE(MAX(version),0) AS mv FROM documentos WHERE proyecto_id = ? AND tipo = 'Informe_FDC125'
      <sql:param value="${param.proyecto_id}"/>
    </sql:query>
    <sql:transaction dataSource="${db}">
      <sql:update>
        INSERT INTO respuestas (proyecto_id, fase, ronda, version_evaluada, usuario_id, rol, estado, acta_numero, acta_fecha, comentario, informe_fdc125_url, rejilla_fdc129_url)
        VALUES (?, 5, ?, ?, ?, 'evaluador', ?, ?, ?, ?, ?, ?)
        <sql:param value="${param.proyecto_id}"/>
        <sql:param value="${rondaE5.rows[0].sig}"/>
        <sql:param value="${verE5.rows[0].mv}"/>
        <sql:param value="${sessionScope.usuario_id}"/>
        <sql:param value="${param.estado}"/>
        <sql:param value="${param.acta}"/>
        <sql:param value="${param.acta_fecha}"/>
        <sql:param value="${param.comentario}"/>
        <sql:param value="${param.informe_url}"/>
        <sql:param value="${param.rejilla_url}"/>
      </sql:update>

      <%-- Registrar Informe F-DC-125 si ingresó URL --%>
      <c:if test="${not empty param.informe_url}">
        <sql:query var="maxV5">
          SELECT COALESCE(MAX(version),0)+1 AS sigVer FROM documentos 
          WHERE proyecto_id = ? AND tipo = 'Informe_FDC125'
          <sql:param value="${param.proyecto_id}"/>
        </sql:query>
        <sql:update>
          INSERT INTO documentos (proyecto_id, fase, tipo, version, url, nombre_archivo, subido_por)
          VALUES (?, 5, 'Informe_FDC125', ?, ?, 'Informe F-DC-125 Firmado', ?)
          <sql:param value="${param.proyecto_id}"/>
          <sql:param value="${maxV5.rows[0].sigVer}"/>
          <sql:param value="${param.informe_url}"/>
          <sql:param value="${sessionScope.usuario_id}"/>
        </sql:update>
      </c:if>

      <%-- Registrar Rejilla F-DC-129 si ingresó URL --%>
      <c:if test="${not empty param.rejilla_url}">
        <sql:query var="maxVR">
          SELECT COALESCE(MAX(version),0)+1 AS sigVer FROM documentos 
          WHERE proyecto_id = ? AND tipo = 'Rejilla_FDC129'
          <sql:param value="${param.proyecto_id}"/>
        </sql:query>
        <sql:update>
          INSERT INTO documentos (proyecto_id, fase, tipo, version, url, nombre_archivo, subido_por)
          VALUES (?, 5, 'Rejilla_FDC129', ?, ?, 'Rejilla F-DC-129 Calificación', ?)
          <sql:param value="${param.proyecto_id}"/>
          <sql:param value="${maxVR.rows[0].sigVer}"/>
          <sql:param value="${param.rejilla_url}"/>
          <sql:param value="${sessionScope.usuario_id}"/>
        </sql:update>
      </c:if>

      <c:choose>
        <c:when test="${param.estado == 'Aprobado'}">
          <sql:update>UPDATE proyectos SET fase = 5, responsable = 'comite', estado = 'En curso' WHERE id = ? AND fase = 5 AND responsable = 'evaluador' AND estado = 'En curso'<sql:param value="${param.proyecto_id}"/></sql:update>
        </c:when>
        <c:when test="${param.estado == 'Correcciones'}">
          <sql:update>UPDATE proyectos SET fase = 4, responsable = 'estudiante', estado = 'En curso' WHERE id = ? AND fase = 5 AND responsable = 'evaluador' AND estado = 'En curso'<sql:param value="${param.proyecto_id}"/></sql:update>
        </c:when>
        <c:when test="${param.estado == 'Rechazado'}">
          <sql:update>UPDATE proyectos SET estado = 'Rechazado', responsable = 'comite' WHERE id = ? AND estado = 'En curso'<sql:param value="${param.proyecto_id}"/></sql:update>
        </c:when>
      </c:choose>

      <sql:update>
        INSERT INTO historial (proyecto_id, usuario_id, accion, fase, acta_numero, comentario)
        VALUES (?, ?, 'Dictamen Evaluador Fase 5', 5, ?, ?)
        <sql:param value="${param.proyecto_id}"/>
        <sql:param value="${sessionScope.usuario_id}"/>
        <sql:param value="${param.acta}"/>
        <sql:param value="Dictamen registrado."/>
      </sql:update>

      <sql:update>
        INSERT INTO auditoria (usuario_id, accion, entidad, detalle)
        VALUES (?, 'Dictamen Evaluador Fase 5', 'proyectos', ?)
        <sql:param value="${sessionScope.usuario_id}"/>
        <sql:param value="Evaluador emitió dictamen en Fase 5 para proyecto ID ${param.proyecto_id}"/>
      </sql:update>
    </sql:transaction>
    <c:redirect url="/docente/evaluador.jsp"><c:param name="ok" value="Respuesta enviada correctamente"/></c:redirect>
  </c:catch>
  <c:if test="${not empty errF5}"><c:set var="errorMsg" value="Error en Fase 5. Intente de nuevo."/></c:if>
</c:if>

<%-- Paginación y búsqueda --%>
<c:set var="pagina" value="${empty param.pagina ? 1 : param.pagina}"/>
<c:set var="limite" value="${empty param.limite ? 10 : param.limite}"/>
<c:set var="offset" value="${(pagina - 1) * limite}"/>
<c:set var="q" value="${param.q}"/>

<c:choose>
  <c:when test="${not empty q}">
    <sql:query dataSource="${db}" var="conteo">
      SELECT COUNT(*) AS total FROM proyectos 
      WHERE evaluador_id = ? AND (codigo LIKE ? OR titulo LIKE ?)
      <sql:param value="${sessionScope.usuario_id}"/>
      <sql:param value="%${q}%"/>
      <sql:param value="%${q}%"/>
    </sql:query>
    <sql:query dataSource="${db}" var="proyectos">
      SELECT p.*, CONCAT(d.nombres, ' ', d.apellidos) AS director_nombre, per.codigo AS periodo_codigo
      FROM proyectos p
      JOIN periodos per ON p.periodo_id = per.id
      LEFT JOIN usuarios d ON p.director_id = d.id
      WHERE p.evaluador_id = ? AND (p.codigo LIKE ? OR p.titulo LIKE ?)
      ORDER BY p.fase DESC, p.id DESC LIMIT ${limite} OFFSET ${offset}
      <sql:param value="${sessionScope.usuario_id}"/>
      <sql:param value="%${q}%"/>
      <sql:param value="%${q}%"/>
    </sql:query>
  </c:when>
  <c:otherwise>
    <sql:query dataSource="${db}" var="conteo">
      SELECT COUNT(*) AS total FROM proyectos WHERE evaluador_id = ?
      <sql:param value="${sessionScope.usuario_id}"/>
    </sql:query>
    <sql:query dataSource="${db}" var="proyectos">
      SELECT p.*, CONCAT(d.nombres, ' ', d.apellidos) AS director_nombre, per.codigo AS periodo_codigo
      FROM proyectos p
      JOIN periodos per ON p.periodo_id = per.id
      LEFT JOIN usuarios d ON p.director_id = d.id
      WHERE p.evaluador_id = ? 
      ORDER BY p.fase DESC, p.id DESC LIMIT ${limite} OFFSET ${offset}
      <sql:param value="${sessionScope.usuario_id}"/>
    </sql:query>
  </c:otherwise>
</c:choose>
<c:set var="total" value="${conteo.rows[0].total}"/>
<c:set var="totalPaginas" value="${(total + limite - 1) / limite}"/>

<%-- Cargar todos los documentos de los proyectos del evaluador en una sola query --%>
<sql:query dataSource="${db}" var="allDocsEvaluador">
  SELECT d.* FROM documentos d
  WHERE EXISTS (
    SELECT 1 FROM proyectos p WHERE p.id = d.proyecto_id AND p.evaluador_id = ?
  )
  ORDER BY d.proyecto_id, d.fase, d.version DESC
  <sql:param value="${sessionScope.usuario_id}"/>
</sql:query>

<!DOCTYPE html>
<html lang="es">
<head>
  <%@ include file="/WEB-INF/jspf/header.jspf" %>
  <title>Docente Evaluador - SIGRADO UTS</title>
</head>
<body>
  <%@ include file="/WEB-INF/jspf/sidebar.jspf" %>

  <div class="main-wrapper">
    <%@ include file="/WEB-INF/jspf/topbar.jspf" %>

    <div class="main-content">
      <c:if test="${not empty param.ok}">
        <div class="alert alert-success alert-dismissible fade show py-2 small" role="alert">
          <i class="fas fa-check-circle me-1"></i> <c:out value="${param.ok}"/>
          <button type="button" class="btn-close py-2" data-bs-dismiss="alert"></button>
        </div>
      </c:if>
      <c:if test="${not empty errorMsg}">
        <div class="alert alert-danger alert-dismissible fade show py-2 small" role="alert">
          <i class="fas fa-exclamation-triangle me-1"></i> <c:out value="${errorMsg}"/>
          <button type="button" class="btn-close py-2" data-bs-dismiss="alert"></button>
        </div>
      </c:if>

      <div class="card-sigrado">
        <div class="card-header-custom">
          <div>
            <h2 class="page-title">
              Docente <span class="badge-title-box">EVALUADOR</span>
            </h2>
            <div class="small text-muted mt-1">
              Proyectos asignados para tu evaluación técnica e institucional (Fase 3 y Fase 5)
            </div>
          </div>
          <div class="d-flex gap-2">
            <a href="${pageContext.request.contextPath}/inicio.jsp" class="btn-volver">
              <i class="fas fa-arrow-left"></i> Volver
            </a>
          </div>
        </div>

        <div class="p-3">
          <form method="get" action="evaluador.jsp" class="table-controls mb-3">
            <div class="d-flex align-items-center gap-2">
              <span class="small text-muted">Mostrar</span>
              <select name="limite" class="form-select form-select-sm" style="width: 75px;" onchange="this.form.submit()">
                <option value="5" ${limite == 5 ? 'selected' : ''}>5</option>
                <option value="10" ${limite == 10 ? 'selected' : ''}>10</option>
                <option value="25" ${limite == 25 ? 'selected' : ''}>25</option>
              </select>
              <span class="small text-muted">registros</span>
            </div>

            <div class="d-flex align-items-center gap-2">
              <span class="small text-muted">Buscar:</span>
              <input type="text" name="q" class="form-control form-control-sm" style="width: 250px;" 
                     placeholder="Código o título..." value="${fn:escapeXml(q)}">
              <button type="submit" class="btn btn-uts btn-sm"><i class="fas fa-search"></i></button>
              <c:if test="${not empty q}">
                <a href="evaluador.jsp" class="btn btn-outline-secondary btn-sm">Limpiar</a>
              </c:if>
            </div>
          </form>

          <div class="table-responsive">
            <table class="table-sigrado">
              <thead>
                <tr>
                  <th style="width: 120px;">Código</th>
                  <th>Título del Proyecto</th>
                  <th style="width: 140px; text-align: center;">Fase Actual</th>
                  <th style="width: 130px; text-align: center;">Estado</th>
                  <th>Director</th>
                  <th style="width: 130px; text-align: center;">Acciones</th>
                </tr>
              </thead>
              <tbody>
<c:choose>
                    <c:when test="${proyectos.rowCount > 0}">
                      <c:forEach items="${proyectos.rows}" var="p">
                        <c:set var="esTurnoEval" value="${p.responsable == 'evaluador' and (p.fase == 3 or p.fase == 5)}" />
                        <tr>
                        <td class="fw-bold">${p.codigo}</td>
                        <td class="text-dark">${p.titulo}</td>
                        <td style="text-align: center;">
                          <span class="badge-fase-dual activa-${p.responsable}">
                            <span class="fase-tag">Fase ${p.fase}</span>
                            <span class="actor-tag text-capitalize">${p.responsable}</span>
                          </span>
                        </td>
                        <td style="text-align: center;">
                          <c:choose>
                            <c:when test="${p.estado == 'Finalizado'}"><span class="badge-pill-custom badge-finalizado">Finalizado</span></c:when>
                            <c:when test="${p.estado == 'Rechazado'}"><span class="badge-pill-custom badge-rechazado">Rechazado</span></c:when>
                            <c:otherwise><span class="badge bg-primary px-2 py-1">${p.estado}</span></c:otherwise>
                          </c:choose>
                        </td>
                        <td class="small">${empty p.director_nombre ? 'Sin asignar' : p.director_nombre}</td>
                        <td style="text-align: center;">
                          <%-- 1. Ver detalles --%>
                          <button type="button" class="btn-icon-sq btn-icon-eye" data-bs-toggle="modal" data-bs-target="#modalDet${p.id}" title="Ver detalles y documentos">
                            <i class="fas fa-eye"></i>
                          </button>
                          <%-- 2. Seguimiento --%>
                          <a href="${pageContext.request.contextPath}/comite/seguimiento.jsp?id=${p.id}" class="btn-icon-sq btn-icon-map" title="Seguimiento de fases">
                            <i class="fas fa-route"></i>
                          </a>
                          <%-- 3. Responder evaluación --%>
                          <c:choose>
                            <c:when test="${esTurnoEval}">
                              <button type="button" class="btn-icon-sq btn-icon-reply" data-bs-toggle="modal" data-bs-target="#modalResp${p.id}" title="Emitir dictamen de evaluación">
                                <i class="fas fa-reply"></i>
                              </button>
                            </c:when>
                            <c:otherwise>
                              <button type="button" class="btn-icon-sq btn-icon-reply" style="opacity: 0.35; cursor: not-allowed;" title="En espera de entrega o turno de ${p.responsable}" disabled>
                                <i class="fas fa-clock"></i>
                              </button>
                            </c:otherwise>
                          </c:choose>
                        </td>
                      </tr>

                      <%-- MODAL DETALLES DEL PROYECTO --%>
                      <div class="modal fade" id="modalDet${p.id}" tabindex="-1" aria-hidden="true">
                        <div class="modal-dialog modal-dialog-centered modal-lg">
                          <div class="modal-content">
                            <div class="modal-header modal-header-sigrado">
                              <h5 class="modal-title fw-bold">
                                Documentos a Evaluar - <span class="badge-title-box">${p.codigo}</span>
                              </h5>
                              <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                            </div>
                            <div class="modal-body p-4">
                              <h5 class="fw-bold text-dark mb-2">${p.titulo}</h5>
                              <div class="row g-2 small text-muted mb-3">
                                <div class="col-md-6"><strong>Modalidad:</strong> ${p.tipo_modalidad} (${p.tipo_nivel})</div>
                                <div class="col-md-6"><strong>Director:</strong> ${empty p.director_nombre ? 'Sin asignar' : p.director_nombre}</div>
                              </div>
                              <hr class="my-2 text-muted">
                              <h6 class="fw-bold text-dark mb-2">Entregas Disponibles para Revisión (Fase ${p.fase}):</h6>
                              <c:set var="tiposFase" value="${p.fase == 3 ? 'Propuesta_FDC124,Turnitin_FDC124' : 'Informe_FDC125,Turnitin_FDC125'}"/>
                              <c:set var="hasDocs" value="false"/>
                              <c:forEach var="d" items="${allDocsEvaluador.rows}">
                                <c:if test="${d.proyecto_id == p.id and fn:contains(tiposFase, d.tipo)}">
                                  <c:set var="hasDocs" value="true"/>
                                </c:if>
                              </c:forEach>
                              <c:choose>
                                <c:when test="${hasDocs}">
                                  <ul class="list-group mb-2">
                                    <c:forEach var="d" items="${allDocsEvaluador.rows}">
                                      <c:if test="${d.proyecto_id == p.id and fn:contains(tiposFase, d.tipo)}">
                                        <li class="list-group-item d-flex justify-content-between align-items-center">
                                          <div>
                                            <span class="badge bg-secondary me-2">v${d.version}</span>
                                            <strong>${d.nombre_archivo}</strong> (${d.tipo})
                                            <div class="small text-muted">${d.fecha_subida}</div>
                                          </div>
                                          <a href="${d.url}" target="_blank" class="btn btn-outline-primary btn-sm">
                                            <i class="fas fa-external-link-alt me-1"></i> Abrir enlace
                                          </a>
                                        </li>
                                      </c:if>
                                    </c:forEach>
                                  </ul>
                                </c:when>
                                <c:otherwise>
                                  <div class="alert alert-info small mb-0">No hay documentos cargados para la fase actual.</div>
                                </c:otherwise>
                              </c:choose>
                              <c:remove var="hasDocs" scope="page"/>
                            </div>
                            <div class="modal-footer modal-footer-sigrado">
                              <button type="button" class="btn btn-secondary btn-sm" data-bs-dismiss="modal">Cerrar</button>
                            </div>
                          </div>
                        </div>
                      </div>

                      <%-- MODAL RESPUESTA DEL EVALUADOR --%>
                      <c:if test="${esTurnoEval}">
                        <div class="modal fade" id="modalResp${p.id}" tabindex="-1" aria-hidden="true">
                          <div class="modal-dialog modal-dialog-centered modal-lg">
                            <div class="modal-content">
                              <form method="post" action="evaluador.jsp">
                                <input type="hidden" name="accion" value="${p.fase == 3 ? 'responder_fase3' : 'responder_fase5'}">
                                <input type="hidden" name="proyecto_id" value="${p.id}">
                                <div class="modal-header modal-header-sigrado">
                                  <h5 class="modal-title fw-bold">
                                    Evaluación <span class="badge-title-box">FASE ${p.fase}</span>
                                  </h5>
                                  <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                                </div>
                                <div class="modal-body p-4">
                                  <p class="small text-muted mb-3">
                                    Proyecto: <strong>${p.codigo} - ${p.titulo}</strong>
                                  </p>

<div class="mb-3">
                                     <label class="form-label small fw-bold">Estado / Dictamen *</label>
                                     <select name="estado" class="form-select form-select-sm" required>
                                       <option value="Aprobado">Aprobado (Pasa a Comité)</option>
                                       <option value="Correcciones">Correcciones (Vuelve a Estudiante)</option>
                                       <option value="Rechazado">Rechazado</option>
                                     </select>
                                   </div>

                                  <c:choose>
                                    <c:when test="${p.fase == 3}">
                                      <div class="mb-3">
                                        <label class="form-label small fw-bold">Propuesta (F-DC-124) firmada (URL) *</label>
                                        <input type="url" name="propuesta_url" class="form-control form-control-sm" required placeholder="https://drive.google.com/file/d/...">
                                      </div>
                                    </c:when>
                                    <c:when test="${p.fase == 5}">
                                      <div class="mb-3">
                                        <label class="form-label small fw-bold">Informe Final (F-DC-125) firmado (URL) *</label>
                                        <input type="url" name="informe_url" class="form-control form-control-sm" required placeholder="https://drive.google.com/file/d/...">
                                      </div>
                                      <div class="mb-3">
                                        <label class="form-label small fw-bold">Rejilla de Calificación (F-DC-129) firmada (URL) *</label>
                                        <input type="url" name="rejilla_url" class="form-control form-control-sm" required placeholder="https://drive.google.com/file/d/...">
                                      </div>
                                    </c:when>
                                  </c:choose>

                                  <div class="row">
                                    <div class="col-md-6 mb-3">
                                      <label class="form-label small fw-bold">Número de Acta (Opcional)</label>
                                      <input type="text" name="acta" class="form-control form-control-sm" placeholder="ej: ACTA-005">
                                    </div>
                                    <div class="col-md-6 mb-3">
                                      <label class="form-label small fw-bold">Fecha del Acta (Opcional)</label>
                                      <input type="date" name="acta_fecha" class="form-control form-control-sm">
                                    </div>
                                  </div>

                                  <div class="mb-3">
                                    <label class="form-label small fw-bold">Comentarios y Observaciones de la Evaluación *</label>
                                    <textarea name="comentario" class="form-control form-control-sm" rows="4" required placeholder="Describe las observaciones técnicas y metodológicas para el estudiante y comité..."></textarea>
                                  </div>
                                </div>
                                <div class="modal-footer modal-footer-sigrado">
                                  <button type="button" class="btn btn-secondary btn-sm" data-bs-dismiss="modal">Cancelar</button>
                                  <button type="submit" class="btn btn-uts btn-sm">Emitir Dictamen</button>
                                </div>
                              </form>
                            </div>
                          </div>
                        </div>
                      </c:if>

                    </c:forEach>
                  </c:when>
                  <c:otherwise>
                    <tr>
                      <td colspan="6" class="text-center py-4 text-muted">
                        No tienes proyectos asignados como Evaluador actualmente.
                      </td>
                    </tr>
                  </c:otherwise>
                </c:choose>
              </tbody>
            </table>
          </div>

          <div class="d-flex justify-content-between align-items-center mt-3 flex-wrap">
            <div class="small text-muted">
              Mostrando página ${pagina} de ${totalPaginas} (${total} proyectos)
            </div>
            <div class="d-flex gap-1">
              <c:if test="${pagina > 1}">
                <a href="evaluador.jsp?pagina=${pagina - 1}&limite=${limite}&q=${fn:escapeXml(q)}" class="btn btn-outline-secondary btn-sm">Anterior</a>
              </c:if>
              <span class="btn btn-uts btn-sm">${pagina}</span>
              <c:if test="${pagina < totalPaginas}">
                <a href="evaluador.jsp?pagina=${pagina + 1}&limite=${limite}&q=${fn:escapeXml(q)}" class="btn btn-outline-secondary btn-sm">Siguiente</a>
              </c:if>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>

  <%@ include file="/WEB-INF/jspf/footer.jspf" %>
</body>
</html>