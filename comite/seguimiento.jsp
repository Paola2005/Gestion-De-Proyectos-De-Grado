<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c"   uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="sql" uri="http://java.sun.com/jsp/jstl/sql" %>
<%@ taglib prefix="fn"  uri="http://java.sun.com/jsp/jstl/functions" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<%@ include file="/WEB-INF/jspf/guard.jspf" %>

<%-- Si se pasa id, cargamos el proyecto específico para el tracker de 6 fases --%>
<c:set var="esSoloEst" value="${fn:contains(sessionScope.roles,'estudiante') and not fn:contains(sessionScope.roles,'comite') and not fn:contains(sessionScope.roles,'administrador') and not fn:contains(sessionScope.roles,'docente')}"/>
<c:if test="${not empty param.id}">
  <sql:query dataSource="${db}" var="proySel">
    SELECT p.*, per.codigo AS periodo_codigo,
           CONCAT(d.nombres, ' ', d.apellidos) AS director_nom,
           CONCAT(cod.nombres, ' ', cod.apellidos) AS codirector_nom
    FROM proyectos p
    JOIN periodos per ON p.periodo_id = per.id
    LEFT JOIN usuarios d ON p.director_id = d.id
    LEFT JOIN usuarios cod ON p.codirector_id = cod.id
    WHERE p.id = ?
    <sql:param value="${param.id}"/>
  </sql:query>
  <c:if test="${proySel.rowCount == 0}">
    <c:redirect url="/inicio.jsp"><c:param name="error" value="Proyecto no encontrado."/></c:redirect>
  </c:if>
  <%-- Estudiante solo puede ver sus propios proyectos (nunca ve evaluador) --%>
  <c:if test="${esSoloEst}">
    <sql:query dataSource="${db}" var="permEst">
      SELECT COUNT(*) AS c FROM proyecto_integrantes WHERE proyecto_id = ? AND usuario_id = ?
      <sql:param value="${param.id}"/><sql:param value="${sessionScope.usuario_id}"/>
    </sql:query>
    <c:if test="${permEst.rows[0].c == 0}">
      <c:redirect url="/inicio.jsp"><c:param name="error" value="Acceso denegado: no pertenece a este proyecto."/></c:redirect>
    </c:if>
  </c:if>
  <c:set var="proy" value="${proySel.rows[0]}" />

  <%-- Integrantes --%>
  <sql:query dataSource="${db}" var="integrantes">
    SELECT u.nombres, u.apellidos, u.documento, u.email, u.telefono
    FROM usuarios u
    JOIN proyecto_integrantes pi ON u.id = pi.usuario_id
    WHERE pi.proyecto_id = ?
    <sql:param value="${proy.id}"/>
  </sql:query>

  <%-- Documentos radicados agrupados por fase --%>
  <sql:query dataSource="${db}" var="docsProyecto">
    SELECT d.*, u.nombres AS subido_por_nom
    FROM documentos d
    LEFT JOIN usuarios u ON d.subido_por = u.id
    WHERE d.proyecto_id = ?
    ORDER BY d.fase ASC, d.version DESC
    <sql:param value="${proy.id}"/>
  </sql:query>

  <%-- Historial de respuestas / decisiones (CIEGO para estudiante puro: nunca ve al evaluador) --%>
  <c:choose>
    <c:when test="${esSoloEst}">
      <sql:query dataSource="${db}" var="respuestas">
        SELECT r.*,
          CASE
            WHEN r.rol = 'evaluador' THEN 'Docente Evaluador (Evaluación a ciegas)'
            WHEN r.rol = 'director' THEN CONCAT('Director: ', u.nombres, ' ', u.apellidos)
            ELSE 'Comité de Grado'
          END AS usuario_nom
        FROM respuestas r
        JOIN usuarios u ON r.usuario_id = u.id
        WHERE r.proyecto_id = ?
        ORDER BY r.fase ASC, r.fecha DESC
        <sql:param value="${proy.id}"/>
      </sql:query>
    </c:when>
    <c:otherwise>
      <sql:query dataSource="${db}" var="respuestas">
        SELECT r.*, CONCAT(u.nombres, ' ', u.apellidos) AS usuario_nom
        FROM respuestas r
        JOIN usuarios u ON r.usuario_id = u.id
        WHERE r.proyecto_id = ?
        ORDER BY r.fase ASC, r.fecha DESC
        <sql:param value="${proy.id}"/>
      </sql:query>
    </c:otherwise>
  </c:choose>

  <%-- Sustentación si existe --%>
  <sql:query dataSource="${db}" var="sust">
    SELECT * FROM sustentaciones WHERE proyecto_id = ?
    <sql:param value="${proy.id}"/>
  </sql:query>
</c:if>

<%-- Si no hay id, listado de proyectos (estudiante solo ve los propios) --%>
<c:if test="${empty param.id}">
  <c:set var="q" value="${param.q}" />
  <c:choose>
    <c:when test="${esSoloEst}">
      <sql:query dataSource="${db}" var="listaProy">
        SELECT p.*, per.codigo AS periodo_codigo,
               CONCAT(d.nombres, ' ', d.apellidos) AS director_nom
        FROM proyectos p
        JOIN periodos per ON p.periodo_id = per.id
        LEFT JOIN usuarios d ON p.director_id = d.id
        INNER JOIN proyecto_integrantes pi ON pi.proyecto_id = p.id AND pi.usuario_id = ?
        WHERE (? = '' OR p.codigo LIKE ? OR p.titulo LIKE ?)
        ORDER BY p.id DESC
        <sql:param value="${sessionScope.usuario_id}"/>
        <sql:param value="${empty q ? '' : q}"/>
        <sql:param value="%${q}%"/>
        <sql:param value="%${q}%"/>
      </sql:query>
    </c:when>
    <c:otherwise>
      <sql:query dataSource="${db}" var="listaProy">
        SELECT p.*, per.codigo AS periodo_codigo,
               CONCAT(d.nombres, ' ', d.apellidos) AS director_nom
        FROM proyectos p
        JOIN periodos per ON p.periodo_id = per.id
        LEFT JOIN usuarios d ON p.director_id = d.id
        WHERE (? = '' OR p.codigo LIKE ? OR p.titulo LIKE ?)
        ORDER BY p.id DESC
        <sql:param value="${empty q ? '' : q}"/>
        <sql:param value="%${q}%"/>
        <sql:param value="%${q}%"/>
      </sql:query>
    </c:otherwise>
  </c:choose>
</c:if>

<!DOCTYPE html>
<html lang="es">
<head>
  <%@ include file="/WEB-INF/jspf/header.jspf" %>
  <title>Seguimiento del Proyecto - SIGRADO UTS</title>
  <style>
    .fase-step-card {
      border-radius: 16px;
      padding: 1.25rem;
      border: 1px solid #dee2e6;
      background: #ffffff;
      transition: all 0.2s ease;
      height: 100%;
      display: flex;
      flex-column;
      justify-content: space-between;
    }
    .fase-step-card.activa {
      background: #047857;
      color: #ffffff;
      border-color: #065F46;
      box-shadow: 0 6px 18px rgba(4, 120, 87, 0.25);
    }
    .fase-step-card.activa .text-muted {
      color: #D1FAE5 !important;
    }
    .fase-step-card.superada {
      background: #f0fdf8;
      border-color: #047857;
    }
    .fase-step-card.pendiente {
      background: #fbfbfb;
      opacity: 0.75;
    }
  </style>
</head>
<body>
  <%@ include file="/WEB-INF/jspf/sidebar.jspf" %>

  <div class="main-wrapper">
    <%@ include file="/WEB-INF/jspf/topbar.jspf" %>

    <div class="main-content">
      <c:choose>
        <%-- VISTA 1: DETALLE DE SEGUIMIENTO (6 FASES) --%>
        <c:when test="${not empty param.id}">
          <div class="card-sigrado mb-4">
            <div class="card-header-custom">
              <div>
                <h2 class="page-title">
                  Seguimiento del <span class="badge-title-box">PROYECTO</span>
                </h2>
                <div class="small text-muted mt-1">
                  Aquí podrás llevar el seguimiento del progreso del proyecto de grado en curso
                </div>
              </div>
              <div class="d-flex gap-2 align-items-center">
                <a href="${pageContext.request.contextPath}/comun/calendario.jsp" class="btn btn-outline-secondary btn-sm" title="Fechas del periodo">
                  <i class="fas fa-calendar-alt"></i>
                </a>
                <a href="${pageContext.request.contextPath}/comite/historico.jsp?q=${proy.codigo}" class="btn btn-outline-secondary btn-sm" title="Historial y versiones">
                  <i class="fas fa-cog"></i>
                </a>
                <a href="seguimiento.jsp" class="btn-volver">
                  <i class="fas fa-arrow-left"></i> Volver
                </a>
              </div>
            </div>

            <div class="p-4">
              <%-- Tarjeta Info Proyecto --%>
              <div class="p-3 bg-light rounded-3 border mb-4">
                <div class="d-flex justify-content-between align-items-start flex-wrap gap-2 mb-2">
                  <div>
                    <span class="badge bg-secondary mb-1">${proy.codigo}</span>
                    <h5 class="fw-bold text-dark mb-1">${proy.titulo}</h5>
                  </div>
                  <div class="d-flex gap-2 align-items-center">
                    <span class="badge-fase-dual activa-${proy.responsable}">
                      <span class="fase-tag">Fase ${proy.fase}</span>
                      <span class="actor-tag text-capitalize">${proy.responsable}</span>
                    </span>
                    <c:choose>
                      <c:when test="${proy.estado == 'Finalizado'}"><span class="badge-pill-custom badge-finalizado">Finalizado</span></c:when>
                      <c:when test="${proy.estado == 'Rechazado'}"><span class="badge-pill-custom badge-rechazado">Rechazado</span></c:when>
                      <c:otherwise><span class="badge bg-primary px-2 py-1">${proy.estado}</span></c:otherwise>
                    </c:choose>
                  </div>
                </div>

                <div class="row g-2 small text-muted">
                  <div class="col-md-3"><strong>Modalidad:</strong> ${proy.tipo_modalidad} (${proy.tipo_nivel})</div>
                  <div class="col-md-3"><strong>Código Mod:</strong> ${empty proy.codigo_modalidad ? 'Por asignar' : proy.codigo_modalidad}</div>
                  <div class="col-md-3"><strong>Director:</strong> ${empty proy.director_nom ? 'Sin asignar' : proy.director_nom}</div>
                  <div class="col-md-3"><strong>Periodo:</strong> ${proy.periodo_codigo}</div>
                </div>
              </div>

              <%-- LAS 6 TARJETAS EN FILA --%>
              <h5 class="fw-bold text-dark mb-3"><i class="fas fa-route text-primary me-2"></i> Estado de las 6 Fases Institucionales</h5>
              
              <div class="row g-3 mb-4">
                <%-- FASE 1 --%>
                <div class="col-lg-4 col-md-6">
                  <c:set var="st1" value="${proy.fase == 1 ? 'activa' : (proy.fase > 1 ? 'superada' : 'pendiente')}" />
                  <div class="fase-step-card ${st1} d-flex flex-column justify-content-between">
                    <div>
                      <div class="d-flex justify-content-between align-items-center mb-2">
                        <span class="fw-bold fs-6">Fase 1: Pago</span>
                        <i class="fas ${proy.fase > 1 ? 'fa-check-circle text-success' : 'fa-receipt'} fa-lg"></i>
                      </div>
                      <p class="small text-muted mb-3">El estudiante describe su idea y sube el comprobante de pago.</p>
                    </div>
                    <div class="d-flex gap-2">
                      <button type="button" class="btn btn-sm ${st1=='activa' ? 'btn-light text-dark' : 'btn-outline-primary'}" data-bs-toggle="modal" data-bs-target="#modalOjoF1">
                        <i class="fas fa-eye me-1"></i> Ver entregas
                      </button>
                    </div>
                  </div>
                </div>

                <%-- FASE 2 --%>
                <div class="col-lg-4 col-md-6">
                  <c:set var="st2" value="${proy.fase == 2 ? 'activa' : (proy.fase > 2 ? 'superada' : 'pendiente')}" />
                  <div class="fase-step-card ${st2} d-flex flex-column justify-content-between">
                    <div>
                      <div class="d-flex justify-content-between align-items-center mb-2">
                        <span class="fw-bold fs-6">Fase 2: Propuesta I</span>
                        <i class="fas ${proy.fase > 2 ? 'fa-check-circle text-success' : (proy.fase == 2 ? 'fa-hourglass-half' : 'fa-clock text-muted')} fa-lg"></i>
                      </div>
                      <p class="small text-muted mb-3">El estudiante envía la propuesta (F-DC-124) al director.</p>
                    </div>
                    <div class="d-flex gap-2">
                      <button type="button" class="btn btn-sm ${st2=='activa' ? 'btn-light text-dark' : 'btn-outline-primary'}" data-bs-toggle="modal" data-bs-target="#modalOjoF2">
                        <i class="fas fa-eye me-1"></i> Ver entregas
                      </button>
                    </div>
                  </div>
                </div>

                <%-- FASE 3 --%>
                <div class="col-lg-4 col-md-6">
                  <c:set var="st3" value="${proy.fase == 3 ? 'activa' : (proy.fase > 3 ? 'superada' : 'pendiente')}" />
                  <div class="fase-step-card ${st3} d-flex flex-column justify-content-between">
                    <div>
                      <div class="d-flex justify-content-between align-items-center mb-2">
                        <span class="fw-bold fs-6">Fase 3: Propuesta II</span>
                        <i class="fas ${proy.fase > 3 ? 'fa-check-circle text-success' : (proy.fase == 3 ? 'fa-paper-plane' : 'fa-clock text-muted')} fa-lg"></i>
                      </div>
                      <p class="small text-muted mb-3">El director envía propuesta a evaluador y comité.</p>
                    </div>
                    <div class="d-flex gap-2">
                      <button type="button" class="btn btn-sm ${st3=='activa' ? 'btn-light text-dark' : 'btn-outline-primary'}" data-bs-toggle="modal" data-bs-target="#modalOjoF3">
                        <i class="fas fa-eye me-1"></i> Ver entregas
                      </button>
                    </div>
                  </div>
                </div>

                <%-- FASE 4 --%>
                <div class="col-lg-4 col-md-6">
                  <c:set var="st4" value="${proy.fase == 4 ? 'activa' : (proy.fase > 4 ? 'superada' : 'pendiente')}" />
                  <div class="fase-step-card ${st4} d-flex flex-column justify-content-between">
                    <div>
                      <div class="d-flex justify-content-between align-items-center mb-2">
                        <span class="fw-bold fs-6">Fase 4: Informe I</span>
                        <i class="fas ${proy.fase > 4 ? 'fa-check-circle text-success' : (proy.fase == 4 ? 'fa-hourglass-half' : 'fa-clock text-muted')} fa-lg"></i>
                      </div>
                      <p class="small text-muted mb-3">El estudiante envía el informe (F-DC-125) al director.</p>
                    </div>
                    <div class="d-flex gap-2">
                      <button type="button" class="btn btn-sm ${st4=='activa' ? 'btn-light text-dark' : 'btn-outline-primary'}" data-bs-toggle="modal" data-bs-target="#modalOjoF4">
                        <i class="fas fa-eye me-1"></i> Ver entregas
                      </button>
                    </div>
                  </div>
                </div>

                <%-- FASE 5 --%>
                <div class="col-lg-4 col-md-6">
                  <c:set var="st5" value="${proy.fase == 5 ? 'activa' : (proy.fase > 5 ? 'superada' : 'pendiente')}" />
                  <div class="fase-step-card ${st5} d-flex flex-column justify-content-between">
                    <div>
                      <div class="d-flex justify-content-between align-items-center mb-2">
                        <span class="fw-bold fs-6">Fase 5: Informe II</span>
                        <i class="fas ${proy.fase > 5 ? 'fa-check-circle text-success' : (proy.fase == 5 ? 'fa-paper-plane' : 'fa-clock text-muted')} fa-lg"></i>
                      </div>
                      <p class="small text-muted mb-3">El director envía el informe al evaluador y comité.</p>
                    </div>
                    <div class="d-flex gap-2">
                      <button type="button" class="btn btn-sm ${st5=='activa' ? 'btn-light text-dark' : 'btn-outline-primary'}" data-bs-toggle="modal" data-bs-target="#modalOjoF5">
                        <i class="fas fa-eye me-1"></i> Ver entregas
                      </button>
                    </div>
                  </div>
                </div>

                <%-- FASE FINAL --%>
                <div class="col-lg-4 col-md-6">
                  <c:set var="st6" value="${proy.estado == 'Finalizado' ? 'activa' : (proy.fase == 6 ? 'activa' : 'pendiente')}" />
                  <div class="fase-step-card ${st6} d-flex flex-column justify-content-between" style="border: 2px solid ${st6=='activa'?'#065F46':'#dee2e6'};">
                    <div>
                      <div class="d-flex justify-content-between align-items-center mb-2">
                        <span class="fw-bold fs-6">Fase Final: Sustentación</span>
                        <i class="fas fa-graduation-cap fa-lg"></i>
                      </div>
                      <p class="small text-muted mb-3">Estudiantes, director y evaluador programan sustentación y cierre.</p>
                    </div>
                    <div class="d-flex gap-2">
                      <button type="button" class="btn btn-sm ${st6=='activa' ? 'btn-light text-dark' : 'btn-outline-primary'}" data-bs-toggle="modal" data-bs-target="#modalOjoF6">
                        <i class="fas fa-eye me-1"></i> Ver sustentación
                      </button>
                    </div>
                  </div>
                </div>
              </div>

              <%-- MODALES DE CADA FASE CON DOCUMENTOS Y VERSIONES URL --%>
              <%-- MODAL FASE 1 --%>
              <div class="modal fade" id="modalOjoF1" tabindex="-1" aria-hidden="true">
                <div class="modal-dialog modal-dialog-centered modal-lg">
                  <div class="modal-content">
                    <div class="modal-header modal-header-sigrado">
                      <h5 class="modal-title fw-bold">Detalles Fase 1 - <span class="badge-title-box">PAGO</span></h5>
                      <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                    </div>
                    <div class="modal-body p-4">
                      <h6 class="fw-bold mb-2">Comprobantes de Pago Radicados (URL):</h6>
                      <ul class="list-group mb-3">
                        <c:forEach var="d" items="${docsProyecto.rows}">
                          <c:if test="${d.tipo == 'SoportePago'}">
                            <li class="list-group-item d-flex justify-content-between align-items-center">
                              <div>
                                <span class="badge bg-secondary me-2">v${d.version}</span>
                                <strong>${d.nombre_archivo}</strong>
                                <div class="small text-muted">${d.fecha_subida}</div>
                              </div>
                              <a href="${d.url}" target="_blank" class="btn btn-outline-primary btn-sm">
                                <i class="fas fa-external-link-alt me-1"></i> Abrir enlace
                              </a>
                            </li>
                          </c:if>
                        </c:forEach>
                      </ul>
                      <div class="small text-muted"><strong>Objetivo General:</strong> ${proy.objetivo_general}</div>
                    </div>
                    <div class="modal-footer modal-footer-sigrado">
                      <button type="button" class="btn btn-secondary btn-sm" data-bs-dismiss="modal">Cerrar</button>
                    </div>
                  </div>
                </div>
              </div>

              <%-- MODAL FASE 2 --%>
              <div class="modal fade" id="modalOjoF2" tabindex="-1" aria-hidden="true">
                <div class="modal-dialog modal-dialog-centered modal-lg">
                  <div class="modal-content">
                    <div class="modal-header modal-header-sigrado">
                      <h5 class="modal-title fw-bold">Detalles Fase 2 - <span class="badge-title-box">PROPUESTA I</span></h5>
                      <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                    </div>
                    <div class="modal-body p-4">
                      <h6 class="fw-bold mb-2">Entregas de Propuesta F-DC-124 (URL):</h6>
                      <ul class="list-group mb-3">
                        <c:forEach var="d" items="${docsProyecto.rows}">
                          <c:if test="${d.tipo == 'Propuesta_FDC124' or d.tipo == 'Turnitin_FDC124'}">
                            <li class="list-group-item d-flex justify-content-between align-items-center">
                              <div>
                                <span class="badge bg-secondary me-2">v${d.version}</span>
                                <strong>${d.tipo == 'Turnitin_FDC124' ? 'Informe Turnitin' : 'Propuesta F-DC-124'}</strong> - ${d.nombre_archivo}
                                <div class="small text-muted">${d.fecha_subida}</div>
                              </div>
                              <a href="${d.url}" target="_blank" class="btn btn-outline-primary btn-sm">
                                <i class="fas fa-external-link-alt me-1"></i> Abrir enlace
                              </a>
                            </li>
                          </c:if>
                        </c:forEach>
                      </ul>
                    </div>
                    <div class="modal-footer modal-footer-sigrado">
                      <button type="button" class="btn btn-secondary btn-sm" data-bs-dismiss="modal">Cerrar</button>
                    </div>
                  </div>
                </div>
              </div>

              <%-- MODAL FASE 3 --%>
              <div class="modal fade" id="modalOjoF3" tabindex="-1" aria-hidden="true">
                <div class="modal-dialog modal-dialog-centered modal-lg">
                  <div class="modal-content">
                    <div class="modal-header modal-header-sigrado">
                      <h5 class="modal-title fw-bold">Detalles Fase 3 - <span class="badge-title-box">PROPUESTA II</span></h5>
                      <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                    </div>
                    <div class="modal-body p-4">
                      <h6 class="fw-bold mb-2">Documentos Evaluados en Fase 3:</h6>
                      <p class="small text-muted">Revisión ciega de propuesta de grado y reporte Turnitin.</p>
                      <ul class="list-group">
                        <c:forEach var="r" items="${respuestas.rows}">
                          <c:if test="${r.fase == 3}">
                            <li class="list-group-item">
                              <div class="d-flex justify-content-between">
                                <strong>Dictamen ${r.rol} · Ronda ${r.ronda} · v${r.version_evaluada}:</strong>
                                <span class="badge bg-primary">${r.estado}</span>
                              </div>
                              <div class="small text-muted mt-1">${r.comentario}</div>
                              <c:if test="${not empty r.acta_numero}">
                                <div class="small text-muted">Acta: ${r.acta_numero} <c:if test="${not empty r.acta_fecha}">(${r.acta_fecha})</c:if> · ${r.fecha}</div>
                              </c:if>
                            </li>
                          </c:if>
                        </c:forEach>
                      </ul>
                    </div>
                    <div class="modal-footer modal-footer-sigrado">
                      <button type="button" class="btn btn-secondary btn-sm" data-bs-dismiss="modal">Cerrar</button>
                    </div>
                  </div>
                </div>
              </div>

              <%-- MODAL FASE 4 --%>
              <div class="modal fade" id="modalOjoF4" tabindex="-1" aria-hidden="true">
                <div class="modal-dialog modal-dialog-centered modal-lg">
                  <div class="modal-content">
                    <div class="modal-header modal-header-sigrado">
                      <h5 class="modal-title fw-bold">Detalles Fase 4 - <span class="badge-title-box">INFORME I</span></h5>
                      <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                    </div>
                    <div class="modal-body p-4">
                      <h6 class="fw-bold mb-2">Entregas de Informe Final F-DC-125 (URL):</h6>
                      <ul class="list-group">
                        <c:forEach var="d" items="${docsProyecto.rows}">
                          <c:if test="${d.tipo == 'Informe_FDC125' or d.tipo == 'Turnitin_FDC125'}">
                            <li class="list-group-item d-flex justify-content-between align-items-center">
                              <div>
                                <span class="badge bg-secondary me-2">v${d.version}</span>
                                <strong>${d.tipo == 'Turnitin_FDC125' ? 'Turnitin Informe' : 'Informe F-DC-125'}</strong> - ${d.nombre_archivo}
                                <div class="small text-muted">${d.fecha_subida}</div>
                              </div>
                              <a href="${d.url}" target="_blank" class="btn btn-outline-primary btn-sm">
                                <i class="fas fa-external-link-alt me-1"></i> Abrir enlace
                              </a>
                            </li>
                          </c:if>
                        </c:forEach>
                      </ul>
                    </div>
                    <div class="modal-footer modal-footer-sigrado">
                      <button type="button" class="btn btn-secondary btn-sm" data-bs-dismiss="modal">Cerrar</button>
                    </div>
                  </div>
                </div>
              </div>

              <%-- MODAL FASE 5 --%>
              <div class="modal fade" id="modalOjoF5" tabindex="-1" aria-hidden="true">
                <div class="modal-dialog modal-dialog-centered modal-lg">
                  <div class="modal-content">
                    <div class="modal-header modal-header-sigrado">
                      <h5 class="modal-title fw-bold">Detalles Fase 5 - <span class="badge-title-box">INFORME II</span></h5>
                      <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                    </div>
                    <div class="modal-body p-4">
                      <h6 class="fw-bold mb-2">Documentos de Calificación Final (F-DC-125 y Rejilla F-DC-129):</h6>
                      <ul class="list-group mb-3">
                        <c:forEach var="d" items="${docsProyecto.rows}">
                          <c:if test="${d.tipo == 'Rejilla_FDC129' or d.tipo == 'Informe_FDC125'}">
                            <li class="list-group-item d-flex justify-content-between align-items-center">
                              <div>
                                <span class="badge bg-secondary me-2">v${d.version}</span>
                                <strong>${d.tipo}</strong>
                              </div>
                              <a href="${d.url}" target="_blank" class="btn btn-outline-primary btn-sm">
                                <i class="fas fa-external-link-alt me-1"></i> Abrir enlace
                              </a>
                            </li>
                          </c:if>
                        </c:forEach>
                      </ul>
                      <h6 class="fw-bold mb-2">Decisiones Fase 5 (ronda · versión evaluada · acta):</h6>
                      <ul class="list-group">
                        <c:forEach var="r" items="${respuestas.rows}">
                          <c:if test="${r.fase == 5}">
                            <li class="list-group-item">
                              <div class="d-flex justify-content-between">
                                <strong>${r.usuario_nom} · Ronda ${r.ronda} · v${r.version_evaluada}:</strong>
                                <span class="badge bg-primary">${r.estado}</span>
                              </div>
                              <div class="small text-muted mt-1">${r.comentario}</div>
                              <c:if test="${not empty r.acta_numero}">
                                <div class="small text-muted">Acta: ${r.acta_numero} <c:if test="${not empty r.acta_fecha}">(${r.acta_fecha})</c:if> · ${r.fecha}</div>
                              </c:if>
                            </li>
                          </c:if>
                        </c:forEach>
                      </ul>
                    </div>
                    <div class="modal-footer modal-footer-sigrado">
                      <button type="button" class="btn btn-secondary btn-sm" data-bs-dismiss="modal">Cerrar</button>
                    </div>
                  </div>
                </div>
              </div>

              <%-- MODAL FASE 6 (SUSTENTACIÓN) --%>
              <div class="modal fade" id="modalOjoF6" tabindex="-1" aria-hidden="true">
                <div class="modal-dialog modal-dialog-centered modal-lg">
                  <div class="modal-content">
                    <div class="modal-header modal-header-sigrado">
                      <h5 class="modal-title fw-bold">Fase Final - <span class="badge-title-box">SUSTENTACIÓN</span></h5>
                      <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                    </div>
                    <div class="modal-body p-4">
                      <c:choose>
                        <c:when test="${sust.rowCount > 0}">
                          <c:set var="s" value="${sust.rows[0]}" />
                          <div class="p-3 bg-light rounded border">
                            <div><strong>Fecha:</strong> ${s.fecha} | <strong>Hora:</strong> ${s.hora}</div>
                            <div><strong>Lugar / Enlace:</strong> <a href="${s.lugar_o_enlace}" target="_blank">${s.lugar_o_enlace}</a></div>
                            <div><strong>N° Acta:</strong> ${s.numero_acta}</div>
                            <div><strong>Resultado:</strong> <span class="badge bg-success">${s.resultado}</span></div>
                          </div>
                        </c:when>
                        <c:otherwise>
                          <div class="alert alert-info small mb-0">
                            La sustentación para este proyecto se encuentra en programación por el Comité de Grado.
                          </div>
                        </c:otherwise>
                      </c:choose>
                    </div>
                    <div class="modal-footer modal-footer-sigrado">
                      <button type="button" class="btn btn-secondary btn-sm" data-bs-dismiss="modal">Cerrar</button>
                    </div>
                  </div>
                </div>
              </div>

            </div>
          </div>
        </c:when>

        <%-- VISTA 2: LISTADO DE PROYECTOS PARA SEGUIMIENTO --%>
        <c:otherwise>
          <div class="card-sigrado">
            <div class="card-header-custom">
              <div>
                <h2 class="page-title">
                  Seguimiento de <span class="badge-title-box">PROYECTOS</span>
                </h2>
                <div class="small text-muted mt-1">
                  Seleccione un proyecto para consultar el avance paso a paso a través de las 6 fases
                </div>
              </div>
              <div class="d-flex gap-2">
                <a href="${pageContext.request.contextPath}/inicio.jsp" class="btn-volver">
                  <i class="fas fa-arrow-left"></i> Volver
                </a>
              </div>
            </div>

            <div class="p-3">
              <form method="get" action="seguimiento.jsp" class="table-controls mb-3">
                <div class="d-flex align-items-center gap-2">
                  <span class="small text-muted">Buscar:</span>
                  <input type="text" name="q" class="form-control form-control-sm" style="width: 260px;" 
                         placeholder="Código o título de proyecto..." value="${fn:escapeXml(q)}">
                  <button type="submit" class="btn btn-uts btn-sm"><i class="fas fa-search"></i></button>
                  <c:if test="${not empty q}">
                    <a href="seguimiento.jsp" class="btn btn-outline-secondary btn-sm">Limpiar</a>
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
                      <th style="width: 110px; text-align: center;">Seguimiento</th>
                    </tr>
                  </thead>
                  <tbody>
                    <c:choose>
                      <c:when test="${listaProy.rowCount > 0}">
                        <c:forEach var="p" items="${listaProy.rows}">
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
                            <td>${empty p.director_nom ? '<span class=\"text-muted\">Por asignar</span>' : p.director_nom}</td>
                            <td style="text-align: center;">
                              <a href="seguimiento.jsp?id=${p.id}" class="btn-icon-sq btn-icon-map" title="Ver seguimiento de las 6 fases">
                                <i class="fas fa-route"></i>
                              </a>
                            </td>
                          </tr>
                        </c:forEach>
                      </c:when>
                      <c:otherwise>
                        <tr>
                          <td colspan="6" class="text-center py-4 text-muted">
                            No se encontraron proyectos disponibles para seguimiento.
                          </td>
                        </tr>
                      </c:otherwise>
                    </c:choose>
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        </c:otherwise>
      </c:choose>
    </div>
  </div>

  <%@ include file="/WEB-INF/jspf/footer.jspf" %>
</body>
</html>