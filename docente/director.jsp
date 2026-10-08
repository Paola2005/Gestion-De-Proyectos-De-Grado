<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c"   uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="sql" uri="http://java.sun.com/jsp/jstl/sql" %>
<%@ taglib prefix="fn"  uri="http://java.sun.com/jsp/jstl/functions" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<%@ include file="/WEB-INF/jspf/guardDocente.jspf" %>

<%-- Procesamiento: Respuesta del Director (Fase 2 y Fase 4, solo quien tiene el turno) --%>
<c:if test="${param.accion == 'responder' and not empty param.proyecto_id}">
  <c:catch var="errResp">
    <sql:query dataSource="${db}" var="turnoDir">
      SELECT p.fase, p.responsable, p.estado, p.director_id, per.fin_aprobacion_propuesta,
             (CURDATE() > per.fin_aprobacion_propuesta) AS vencida
      FROM proyectos p JOIN periodos per ON p.periodo_id = per.id
      WHERE p.id = ?
      <sql:param value="${param.proyecto_id}"/>
    </sql:query>
    <c:if test="${turnoDir.rowCount == 0 or turnoDir.rows[0].responsable != 'director' or turnoDir.rows[0].estado != 'En curso' or turnoDir.rows[0].director_id != sessionScope.usuario_id or turnoDir.rows[0].fase != param.fase or (param.fase != 2 and param.fase != 4)}">
      <c:redirect url="/docente/director.jsp"><c:param name="error" value="No tiene el turno para responder este proyecto."/></c:redirect>
    </c:if>
    <%-- El proyecto se evalúa con el periodo con el que fue inscrito. Solo se bloquea
         la aprobación de la propuesta (Fase 2) después de fin_aprobacion_propuesta. --%>
    <c:if test="${param.fase == 2 and param.estado == 'Aprobado' and turnoDir.rows[0].vencida == 1}">
      <fmt:formatDate value="${turnoDir.rows[0].fin_aprobacion_propuesta}" pattern="dd/MM/yyyy" var="fLimiteF2"/>
      <c:redirect url="/docente/director.jsp"><c:param name="error" value="La fecha límite de aprobación de propuesta fue el ${fLimiteF2}."/></c:redirect>
    </c:if>
    <c:if test="${not empty param.turnitin and not fn:startsWith(param.turnitin,'https://')}">
      <c:redirect url="/docente/director.jsp"><c:param name="error" value="El Turnitin debe ser una URL válida (https://)."/></c:redirect>
    </c:if>
    <%-- Fase 2 aprueba solo con URL de Turnitin; Rechazado/Correcciones exigen acta+comentarios --%>
    <c:if test="${param.fase == 2 and param.estado == 'Aprobado' and (empty param.turnitin or not fn:startsWith(param.turnitin,'https://'))}">
      <c:redirect url="/docente/director.jsp"><c:param name="error" value="Para aprobar Fase 2 debe adjuntar la URL de Turnitin (https://)."/></c:redirect>
    </c:if>
    <sql:query dataSource="${db}" var="rondaDir">
      SELECT COUNT(*)+1 AS sig FROM respuestas WHERE proyecto_id = ? AND fase = ?
      <sql:param value="${param.proyecto_id}"/><sql:param value="${param.fase}"/>
    </sql:query>
    <sql:query dataSource="${db}" var="verDir">
      SELECT COALESCE(MAX(version),0) AS mv FROM documentos
      WHERE proyecto_id = ? AND tipo = ?
      <sql:param value="${param.proyecto_id}"/>
      <sql:param value="${param.fase == 2 ? 'Propuesta_FDC124' : 'Informe_FDC125'}"/>
    </sql:query>
    <sql:transaction dataSource="${db}">
      <sql:update>
        INSERT INTO respuestas (proyecto_id, fase, ronda, version_evaluada, usuario_id, rol, estado, acta_numero, acta_fecha, comentario, turnitin_url)
        VALUES (?, ?, ?, ?, ?, 'director', ?, ?, ?, ?, ?)
        <sql:param value="${param.proyecto_id}"/>
        <sql:param value="${param.fase}"/>
        <sql:param value="${rondaDir.rows[0].sig}"/>
        <sql:param value="${verDir.rows[0].mv}"/>
        <sql:param value="${sessionScope.usuario_id}"/>
        <sql:param value="${param.estado}"/>
        <sql:param value="${param.acta}"/>
        <sql:param value="${param.acta_fecha}"/>
        <sql:param value="${param.comentario}"/>
        <sql:param value="${param.turnitin}"/>
      </sql:update>

      <%-- Registrar documento de Turnitin si se ingresó URL --%>
      <c:if test="${not empty param.turnitin}">
        <sql:query var="maxV">
          SELECT COALESCE(MAX(version),0)+1 AS sigVer FROM documentos 
          WHERE proyecto_id = ? AND tipo = ?
          <sql:param value="${param.proyecto_id}"/>
          <sql:param value="${param.fase == 2 ? 'Turnitin_FDC124' : 'Turnitin_FDC125'}"/>
        </sql:query>
        <sql:update>
          INSERT INTO documentos (proyecto_id, fase, tipo, version, url, nombre_archivo, subido_por)
          VALUES (?, ?, ?, ?, ?, 'Informe Turnitin Plagio', ?)
          <sql:param value="${param.proyecto_id}"/>
          <sql:param value="${param.fase}"/>
          <sql:param value="${param.fase == 2 ? 'Turnitin_FDC124' : 'Turnitin_FDC125'}"/>
          <sql:param value="${maxV.rows[0].sigVer}"/>
          <sql:param value="${param.turnitin}"/>
          <sql:param value="${sessionScope.usuario_id}"/>
        </sql:update>
      </c:if>

      <%-- Transiciones de Estado según Fase 2 y 4 (F2 Aprueba->F3 Evaluador; F4 Aprueba->F5 Evaluador) --%>
      <c:choose>
        <%-- Fase 2 Director --%>
        <c:when test="${param.fase == 2 and param.estado == 'Aprobado'}">
          <sql:update>UPDATE proyectos SET fase = 3, responsable = 'evaluador', estado = 'En curso' WHERE id = ? AND fase = 2 AND responsable = 'director' AND estado = 'En curso'<sql:param value="${param.proyecto_id}"/></sql:update>
        </c:when>
        <c:when test="${param.fase == 2 and param.estado == 'Correcciones'}">
          <sql:update>UPDATE proyectos SET fase = 2, responsable = 'estudiante', estado = 'En curso' WHERE id = ? AND fase = 2 AND responsable = 'director' AND estado = 'En curso'<sql:param value="${param.proyecto_id}"/></sql:update>
        </c:when>
        <c:when test="${param.fase == 2 and param.estado == 'Rechazado'}">
          <sql:update>UPDATE proyectos SET estado = 'Rechazado', responsable = 'comite' WHERE id = ? AND estado = 'En curso'<sql:param value="${param.proyecto_id}"/></sql:update>
        </c:when>

        <%-- Fase 4 Director --%>
        <c:when test="${param.fase == 4 and param.estado == 'Aprobado'}">
          <sql:update>UPDATE proyectos SET fase = 5, responsable = 'evaluador', estado = 'En curso' WHERE id = ? AND fase = 4 AND responsable = 'director' AND estado = 'En curso'<sql:param value="${param.proyecto_id}"/></sql:update>
        </c:when>
        <c:when test="${param.fase == 4 and param.estado == 'Correcciones'}">
          <sql:update>UPDATE proyectos SET fase = 4, responsable = 'estudiante', estado = 'En curso' WHERE id = ? AND fase = 4 AND responsable = 'director' AND estado = 'En curso'<sql:param value="${param.proyecto_id}"/></sql:update>
        </c:when>
        <c:when test="${param.fase == 4 and param.estado == 'Rechazado'}">
          <sql:update>UPDATE proyectos SET estado = 'Rechazado', responsable = 'comite' WHERE id = ? AND estado = 'En curso'<sql:param value="${param.proyecto_id}"/></sql:update>
        </c:when>
      </c:choose>

      <sql:update>
        INSERT INTO historial (proyecto_id, usuario_id, accion, fase, acta_numero, comentario)
        VALUES (?, ?, 'Dictamen Director', ?, ?, ?)
        <sql:param value="${param.proyecto_id}"/>
        <sql:param value="${sessionScope.usuario_id}"/>
        <sql:param value="${param.fase}"/>
        <sql:param value="${param.acta}"/>
        <sql:param value="Dictamen ${param.estado}: ${param.comentario}"/>
      </sql:update>

      <sql:update>
        INSERT INTO auditoria (usuario_id, accion, entidad, detalle)
        VALUES (?, 'Dictamen Director', 'proyectos', ?)
        <sql:param value="${sessionScope.usuario_id}"/>
        <sql:param value="Director emitió dictamen ${param.estado} en Fase ${param.fase} para proyecto ID ${param.proyecto_id}"/>
      </sql:update>
    </sql:transaction>
    <c:redirect url="/docente/director.jsp"><c:param name="ok" value="Respuesta enviada correctamente"/></c:redirect>
  </c:catch>
  <c:if test="${not empty errResp}"><c:set var="errorMsg" value="Error al procesar respuesta. Intente de nuevo."/></c:if>
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
      WHERE director_id = ? AND (codigo LIKE ? OR titulo LIKE ?)
      <sql:param value="${sessionScope.usuario_id}"/>
      <sql:param value="%${q}%"/>
      <sql:param value="%${q}%"/>
    </sql:query>
    <sql:query dataSource="${db}" var="proyectos">
      SELECT p.*, CONCAT(ev.nombres, ' ', ev.apellidos) AS evaluador_nombre, CONCAT(per.codigo, '') AS periodo_codigo
      FROM proyectos p
      JOIN periodos per ON p.periodo_id = per.id
      LEFT JOIN usuarios ev ON p.evaluador_id = ev.id
      WHERE p.director_id = ? AND (p.codigo LIKE ? OR p.titulo LIKE ?)
      ORDER BY p.fase DESC, p.id DESC LIMIT ${limite} OFFSET ${offset}
      <sql:param value="${sessionScope.usuario_id}"/>
      <sql:param value="%${q}%"/>
      <sql:param value="%${q}%"/>
    </sql:query>
  </c:when>
  <c:otherwise>
    <sql:query dataSource="${db}" var="conteo">
      SELECT COUNT(*) AS total FROM proyectos WHERE director_id = ?
      <sql:param value="${sessionScope.usuario_id}"/>
    </sql:query>
    <sql:query dataSource="${db}" var="proyectos">
      SELECT p.*, CONCAT(ev.nombres, ' ', ev.apellidos) AS evaluador_nombre, CONCAT(per.codigo, '') AS periodo_codigo
      FROM proyectos p
      JOIN periodos per ON p.periodo_id = per.id
      LEFT JOIN usuarios ev ON p.evaluador_id = ev.id
      WHERE p.director_id = ? 
      ORDER BY p.fase DESC, p.id DESC LIMIT ${limite} OFFSET ${offset}
      <sql:param value="${sessionScope.usuario_id}"/>
    </sql:query>
  </c:otherwise>
</c:choose>
<c:set var="total" value="${conteo.rows[0].total}"/>
<c:set var="totalPaginas" value="${(total + limite - 1) / limite}"/>

<%-- Cargar todos los documentos de los proyectos del director en una sola query --%>
<sql:query dataSource="${db}" var="allDocsDirector">
  SELECT d.* FROM documentos d
  WHERE EXISTS (
    SELECT 1 FROM proyectos p WHERE p.id = d.proyecto_id AND p.director_id = ?
  )
  ORDER BY d.proyecto_id, d.fase, d.version DESC
  <sql:param value="${sessionScope.usuario_id}"/>
</sql:query>

<!DOCTYPE html>
<html lang="es">
<head>
  <%@ include file="/WEB-INF/jspf/header.jspf" %>
  <title>Docente Director - SIGRADO UTS</title>
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
              Docente <span class="badge-title-box">DIRECTOR</span>
            </h2>
            <div class="small text-muted mt-1">
              Proyectos bajo tu dirección académica. Revisa propuestas (Fase 2) e informes finales (Fase 4).
            </div>
          </div>
          <div class="d-flex gap-2">
            <a href="${pageContext.request.contextPath}/inicio.jsp" class="btn-volver">
              <i class="fas fa-arrow-left"></i> Volver
            </a>
          </div>
        </div>

        <div class="p-3">
          <form method="get" action="director.jsp" class="table-controls mb-3">
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
                <a href="director.jsp" class="btn btn-outline-secondary btn-sm">Limpiar</a>
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
                  <th>Evaluador</th>
                  <th style="width: 130px; text-align: center;">Acciones</th>
                </tr>
              </thead>
              <tbody>
<c:choose>
                    <c:when test="${proyectos.rowCount > 0}">
                      <c:forEach items="${proyectos.rows}" var="p">
                        <c:set var="esTurnoDirector" value="${p.responsable == 'director' and (p.fase == 2 or p.fase == 4)}" />
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
                        <td class="small">${empty p.evaluador_nombre ? 'Sin asignar' : p.evaluador_nombre}</td>
                        <td style="text-align: center;">
                          <%-- 1. Ver detalles --%>
                          <button type="button" class="btn-icon-sq btn-icon-eye" data-bs-toggle="modal" data-bs-target="#modalDet${p.id}" title="Ver detalles y documentos">
                            <i class="fas fa-eye"></i>
                          </button>
                          <%-- 2. Seguimiento --%>
                          <a href="${pageContext.request.contextPath}/comite/seguimiento.jsp?id=${p.id}" class="btn-icon-sq btn-icon-map" title="Seguimiento de fases">
                            <i class="fas fa-route"></i>
                          </a>
                          <%-- 3. Responder esta fase (solo si tiene el turno) --%>
                          <c:choose>
                            <c:when test="${esTurnoDirector}">
                              <button type="button" class="btn-icon-sq btn-icon-reply" data-bs-toggle="modal" data-bs-target="#modalResp${p.id}" title="Responder esta fase">
                                <i class="fas fa-reply"></i>
                              </button>
                            </c:when>
                            <c:otherwise>
                              <button type="button" class="btn-icon-sq btn-icon-reply" style="opacity: 0.35; cursor: not-allowed;" title="En espera de entrega del estudiante" disabled>
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
                                Detalles del Proyecto - <span class="badge-title-box">${p.codigo}</span>
                              </h5>
                              <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                            </div>
                            <div class="modal-body p-4">
                              <h5 class="fw-bold text-dark mb-2">${p.titulo}</h5>
                              <div class="row g-2 small text-muted mb-3">
                                <div class="col-md-6"><strong>Modalidad:</strong> ${p.tipo_modalidad} (${p.tipo_nivel})</div>
                                <div class="col-md-6"><strong>Código Modalidad:</strong> ${empty p.codigo_modalidad ? 'Pendiente' : p.codigo_modalidad}</div>
                                <div class="col-md-6"><strong>Periodo:</strong> ${p.periodo_codigo}</div>
                                <div class="col-md-6"><strong>Docente Evaluador:</strong> ${empty p.evaluador_nombre ? 'Sin asignar' : p.evaluador_nombre}</div>
                              </div>
                              <hr class="my-2 text-muted">
                              <h6 class="fw-bold text-dark mb-2">Últimos documentos radicados por el estudiante (Fase ${p.fase}):</h6>
                              <%-- Muestra la última versión de cada tipo de la fase (propuesta+Turnitin en F2, informe+Turnitin en F4), con su enlace --%>
                              <c:set var="tiposDoc" value="${p.fase == 2 ? 'Propuesta_FDC124,Turnitin_FDC124' : 'Informe_FDC125,Turnitin_FDC125'}"/>
                              <c:set var="vistos" value=","/>
                              <c:set var="hayDoc" value="false"/>
                              <ul class="list-group mb-2">
                                <c:forEach var="d" items="${allDocsDirector.rows}">
                                  <c:if test="${d.proyecto_id == p.id and fn:contains(tiposDoc, d.tipo) and not fn:contains(vistos, d.tipo)}">
                                    <c:set var="vistos" value="${vistos}${d.tipo},"/>
                                    <c:set var="hayDoc" value="true"/>
                                    <li class="list-group-item d-flex justify-content-between align-items-center">
                                      <div>
                                        <span class="badge bg-secondary me-2">v${d.version}</span>
                                        <strong>${d.nombre_archivo}</strong>
                                        <div class="small text-muted">${d.tipo} · ${d.fecha_subida}</div>
                                      </div>
                                      <a href="${d.url}" target="_blank" class="btn btn-outline-primary btn-sm">
                                        <i class="fas fa-external-link-alt me-1"></i> Abrir enlace
                                      </a>
                                    </li>
                                  </c:if>
                                </c:forEach>
                              </ul>
                              <c:if test="${not hayDoc}">
                                <div class="alert alert-warning small mb-0">El estudiante aún no ha radicado el documento de la fase actual.</div>
                              </c:if>
                              <c:remove var="vistos" scope="page"/>
                              <c:remove var="hayDoc" scope="page"/>
                              <c:remove var="tiposDoc" scope="page"/>
                            </div>
                            <div class="modal-footer modal-footer-sigrado">
                              <button type="button" class="btn btn-secondary btn-sm" data-bs-dismiss="modal">Cerrar</button>
                            </div>
                          </div>
                        </div>
                      </div>

                      <%-- MODAL RESPUESTA DEL DIRECTOR (FASE 2 Y FASE 4) --%>
                      <c:if test="${esTurnoDirector}">
                        <div class="modal fade" id="modalResp${p.id}" tabindex="-1" aria-hidden="true">
                          <div class="modal-dialog modal-dialog-centered modal-lg">
                            <div class="modal-content">
                              <form method="post" action="director.jsp">
                                <input type="hidden" name="accion" value="responder">
                                <input type="hidden" name="proyecto_id" value="${p.id}">
                                <input type="hidden" name="fase" value="${p.fase}">
                                <div class="modal-header modal-header-sigrado">
                                  <h5 class="modal-title fw-bold">
                                    Proyecto <span class="badge-title-box">FASE ${p.fase}</span>
                                  </h5>
                                  <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                                </div>
                                <div class="modal-body p-4">
                                  <p class="small text-muted mb-3">
                                    Proyecto: <strong>${p.codigo} - ${p.titulo}</strong>
                                  </p>

                                  <div class="mb-3">
                                    <label class="form-label small fw-bold">Estado del proyecto *</label>
                                    <select name="estado" class="form-select form-select-sm" required>
                                      <option value="Aprobado">Aprobado (Avanza a Fase ${p.fase + 1})</option>
                                      <option value="Correcciones">Correcciones (Vuelve al estudiante)</option>
                                      <option value="Rechazado">Rechazado (Cancelar proyecto)</option>
                                    </select>
                                  </div>

                                  <div class="mb-3">
                                    <label class="form-label small fw-bold">Informe de plagio (Turnitin URL) ${p.fase == 2 ? '*' : '(Opcional)'}</label>
                                    <input type="url" name="turnitin" class="form-control form-control-sm" ${p.fase == 2 ? 'required' : ''} placeholder="https://turnitin.com/report/...">
                                    <div class="form-text small">Pegue el enlace público o institucional del reporte de similitud Turnitin.</div>
                                  </div>

                                  <div class="row">
                                    <div class="col-md-6 mb-3">
                                      <label class="form-label small fw-bold">Número de Acta (Opcional)</label>
                                      <input type="text" name="acta" class="form-control form-control-sm" placeholder="ej: ACTA-002">
                                    </div>
                                    <div class="col-md-6 mb-3">
                                      <label class="form-label small fw-bold">Fecha del Acta (Opcional)</label>
                                      <input type="date" name="acta_fecha" class="form-control form-control-sm">
                                    </div>
                                  </div>

                                  <div class="mb-3">
                                    <label class="form-label small fw-bold">Comentarios de la respuesta *</label>
                                    <textarea name="comentario" class="form-control form-control-sm" rows="4" required placeholder="Describe los detalles de la respuesta y retroalimentación para el estudiante..."></textarea>
                                  </div>
                                </div>
                                <div class="modal-footer modal-footer-sigrado">
                                  <button type="button" class="btn btn-secondary btn-sm" data-bs-dismiss="modal">Cancelar</button>
                                  <button type="submit" class="btn btn-uts btn-sm">Enviar Respuesta</button>
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
                        No tienes proyectos asignados como Director actualmente.
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
                <a href="director.jsp?pagina=${pagina - 1}&limite=${limite}&q=${fn:escapeXml(q)}" class="btn btn-outline-secondary btn-sm">Anterior</a>
              </c:if>
              <span class="btn btn-uts btn-sm">${pagina}</span>
              <c:if test="${pagina < totalPaginas}">
                <a href="director.jsp?pagina=${pagina + 1}&limite=${limite}&q=${fn:escapeXml(q)}" class="btn btn-outline-secondary btn-sm">Siguiente</a>
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