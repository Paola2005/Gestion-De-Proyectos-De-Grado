<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c"   uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="sql" uri="http://java.sun.com/jsp/jstl/sql" %>
<%@ taglib prefix="fn"  uri="http://java.sun.com/jsp/jstl/functions" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<%@ include file="/WEB-INF/jspf/guardEstudiante.jspf" %>

<%-- Obtener proyecto del estudiante --%>
<c:set var="proyParamId" value="${param.id}"/>
<c:choose>
  <c:when test="${not empty proyParamId}">
    <sql:query dataSource="${db}" var="mi">
      SELECT p.id AS proyecto_id, p.codigo, p.titulo, p.estado, p.fase, p.responsable
      FROM proyectos p
      INNER JOIN proyecto_integrantes pi ON p.id = pi.proyecto_id
      WHERE p.id = ? AND pi.usuario_id = ?
      LIMIT 1
      <sql:param value="${proyParamId}"/>
      <sql:param value="${sessionScope.usuario_id}"/>
    </sql:query>
  </c:when>
  <c:otherwise>
    <sql:query dataSource="${db}" var="mi">
      SELECT p.id AS proyecto_id, p.codigo, p.titulo, p.estado, p.fase, p.responsable
      FROM proyectos p
      INNER JOIN proyecto_integrantes pi ON p.id = pi.proyecto_id
      WHERE pi.usuario_id = ?
      ORDER BY p.id DESC
      LIMIT 1
      <sql:param value="${sessionScope.usuario_id}"/>
    </sql:query>
  </c:otherwise>
</c:choose>

<c:if test="${mi.rowCount == 0}">
  <c:redirect url="/estudiante/banco.jsp">
    <c:param name="error" value="No tienes un proyecto de grado vinculado."/>
  </c:redirect>
</c:if>

<%-- NOTA: el JSTL incluido usa el nombre real de la columna (id), no el alias;
     por eso se lee mi.rows[0].id y no mi.rows[0].proyecto_id. --%>
<c:set var="pid" value="${mi.rows[0].id}"/>
<c:set var="proyCodigo" value="${mi.rows[0].codigo}"/>
<c:set var="proyTitulo" value="${mi.rows[0].titulo}"/>
<c:set var="proyFase" value="${mi.rows[0].fase}"/>
<c:set var="proyEstado" value="${mi.rows[0].estado}"/>
<c:set var="proyResponsable" value="${mi.rows[0].responsable}"/>

<%-- Procesar entrega de documento (solo quien tiene el turno F·Estudiante, URL https://) --%>
<c:if test="${param.accion == 'subir' and not empty param.tipo}">
  <c:catch var="errV">
    <c:if test="${proyResponsable != 'estudiante' or (proyEstado != 'En curso')}">
      <c:redirect url="/estudiante/versiones.jsp?id=${pid}"><c:param name="error" value="No tiene el turno para radicar en este proyecto."/></c:redirect>
    </c:if>
    <%-- La entrega de documentos de un proyecto existente no usa las ventanas de
         inscripción (nuevos proyectos); solo exige turno, URL https y tipo válido. --%>
    <c:if test="${empty param.enlace or empty param.nombre_archivo}">
      <c:redirect url="/estudiante/versiones.jsp?id=${pid}"><c:param name="error" value="El enlace institucional y el nombre del archivo son obligatorios"/></c:redirect>
    </c:if>
    <c:if test="${not fn:startsWith(param.enlace,'https://')}">
      <c:redirect url="/estudiante/versiones.jsp?id=${pid}"><c:param name="error" value="Todo documento debe ser una URL válida (https://). No se suben archivos."/></c:redirect>
    </c:if>
    <c:if test="${(proyFase == 1 and param.tipo != 'SoportePago' and param.tipo != 'Otro') or (proyFase == 2 and param.tipo != 'Propuesta_FDC124' and param.tipo != 'Turnitin_FDC124' and param.tipo != 'Otro') or (proyFase == 4 and param.tipo != 'Informe_FDC125' and param.tipo != 'Turnitin_FDC125' and param.tipo != 'Otro') or (proyFase != 1 and proyFase != 2 and proyFase != 4 and param.tipo != 'Otro')}">
      <c:redirect url="/estudiante/versiones.jsp?id=${pid}"><c:param name="error" value="Tipo de documento no válido para la fase actual."/></c:redirect>
    </c:if>

    <sql:transaction dataSource="${db}">
      <sql:query var="maxv">
        SELECT COALESCE(MAX(version), 0) + 1 AS sig 
        FROM documentos 
        WHERE proyecto_id = ? AND tipo = ?
        <sql:param value="${pid}"/>
        <sql:param value="${param.tipo}"/>
      </sql:query>
      <c:set var="sig" value="${maxv.rows[0].sig}"/>

      <sql:update>
        INSERT INTO documentos (proyecto_id, tipo, version, url, nombre_archivo, fase, subido_por, observaciones)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        <sql:param value="${pid}"/>
        <sql:param value="${param.tipo}"/>
        <sql:param value="${sig}"/>
        <sql:param value="${param.enlace}"/>
        <sql:param value="${param.nombre_archivo}"/>
        <sql:param value="${proyFase}"/>
        <sql:param value="${sessionScope.usuario_id}"/>
        <sql:param value="${param.observaciones}"/>
      </sql:update>

      <%-- Cambio de turno de revisión según el tipo de documento entregado --%>
      <c:choose>
        <%-- Entrega de propuesta en Fase 2 --%>
        <c:when test="${param.tipo == 'Propuesta_FDC124'}">
          <sql:update>
            UPDATE proyectos SET responsable = 'director', estado = 'En curso' WHERE id = ?
            <sql:param value="${pid}"/>
          </sql:update>
          <sql:update>
            INSERT INTO historial (proyecto_id, usuario_id, accion, fase, comentario)
            VALUES (?, ?, 'Entrega de Propuesta (F-DC-124)', 2, ?)
            <sql:param value="${pid}"/>
            <sql:param value="${sessionScope.usuario_id}"/>
            <sql:param value="Estudiante radicó versión ${sig} de la propuesta para revisión del Director."/>
          </sql:update>
        </c:when>

        <%-- Entrega de informe final en Fase 4 --%>
        <c:when test="${param.tipo == 'Informe_FDC125'}">
          <sql:update>
            UPDATE proyectos SET responsable = 'director', estado = 'En curso' WHERE id = ?
            <sql:param value="${pid}"/>
          </sql:update>
          <sql:update>
            INSERT INTO historial (proyecto_id, usuario_id, accion, fase, comentario)
            VALUES (?, ?, 'Entrega de Informe Final (F-DC-125)', 4, ?)
            <sql:param value="${pid}"/>
            <sql:param value="${sessionScope.usuario_id}"/>
            <sql:param value="Estudiante radicó versión ${sig} del informe final para revisión del Director."/>
          </sql:update>
        </c:when>

        <%-- Entrega de soporte de pago en Fase 1 --%>
        <c:when test="${param.tipo == 'SoportePago'}">
          <sql:update>
            UPDATE proyectos SET responsable = 'comite', estado = 'En curso' WHERE id = ?
            <sql:param value="${pid}"/>
          </sql:update>
          <sql:update>
            INSERT INTO historial (proyecto_id, usuario_id, accion, fase, comentario)
            VALUES (?, ?, 'Entrega de Soporte de Pago', 1, ?)
            <sql:param value="${pid}"/>
            <sql:param value="${sessionScope.usuario_id}"/>
            <sql:param value="Estudiante radicó comprobante de pago adicional."/>
          </sql:update>
        </c:when>

        <%-- Otro documento --%>
        <c:otherwise>
          <sql:update>
            INSERT INTO historial (proyecto_id, usuario_id, accion, fase, comentario)
            VALUES (?, ?, 'Entrega de Documento Anexo', ?, ?)
            <sql:param value="${pid}"/>
            <sql:param value="${sessionScope.usuario_id}"/>
            <sql:param value="${proyFase}"/>
            <sql:param value="Estudiante subió ${param.tipo} v${sig}: ${param.nombre_archivo}"/>
          </sql:update>
        </c:otherwise>
      </c:choose>
    </sql:transaction>

    <c:redirect url="/estudiante/versiones.jsp?id=${pid}"><c:param name="ok" value="Documento radicado exitosamente (versión ${sig}). El proyecto ha sido enviado a revisión."/></c:redirect>
  </c:catch>
  <c:if test="${not empty errV}">
    <c:redirect url="/estudiante/versiones.jsp?id=${pid}"><c:param name="error" value="Error al registrar documento. Intente de nuevo."/></c:redirect>
  </c:if>
</c:if>

<%-- Cargar documentos radicados --%>
<sql:query dataSource="${db}" var="docs">
  SELECT d.*, CONCAT(u.nombres, ' ', u.apellidos) AS subido_por_nombre
  FROM documentos d
  LEFT JOIN usuarios u ON d.subido_por = u.id
  WHERE d.proyecto_id = ?
  ORDER BY d.fase ASC, d.version DESC
  <sql:param value="${pid}"/>
</sql:query>

<%-- Cargar respuestas / evaluaciones del proyecto (CIEGA: ocultar evaluador) --%>
<sql:query dataSource="${db}" var="respuestas">
  SELECT r.*,
         CASE 
           WHEN r.rol = 'evaluador' THEN 'Docente Evaluador (Evaluación a ciegas)'
           WHEN r.rol = 'director' THEN CONCAT('Director: ', u.nombres, ' ', u.apellidos)
           ELSE 'Comité de Grado'
         END AS emisor_nombre
  FROM respuestas r
  LEFT JOIN usuarios u ON r.usuario_id = u.id
  WHERE r.proyecto_id = ?
  ORDER BY r.fase ASC, r.id ASC
  <sql:param value="${pid}"/>
</sql:query>

<!DOCTYPE html>
<html lang="es">
<head>
  <%@ include file="/WEB-INF/jspf/header.jspf" %>
  <title>Entregas y Versiones - Estudiante SIGRADO UTS</title>
</head>
<body>
  <%@ include file="/WEB-INF/jspf/sidebar.jspf" %>

  <div class="main-wrapper">
    <%@ include file="/WEB-INF/jspf/topbar.jspf" %>

    <div class="main-content">
      <c:if test="${not empty param.error}">
        <div class="alert alert-danger alert-dismissible fade show" role="alert">
          <i class="fas fa-exclamation-circle me-2"></i><c:out value="${param.error}"/>
          <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
        </div>
      </c:if>
      <c:if test="${not empty param.ok}">
        <div class="alert alert-success alert-dismissible fade show" role="alert">
          <i class="fas fa-check-circle me-2"></i><c:out value="${param.ok}"/>
          <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
        </div>
      </c:if>

      <%-- Banner del proyecto actual --%>
      <div class="card-sigrado mb-4">
        <div class="p-3">
          <div class="d-flex align-items-center justify-content-between flex-wrap gap-3">
            <div>
              <span class="badge bg-secondary mb-1">${proyCodigo}</span>
              <h5 class="fw-bold text-dark mb-0">${proyTitulo}</h5>
              <div class="small text-muted mt-1">Estado del proyecto: <strong>${proyEstado}</strong></div>
            </div>
            <div class="d-flex align-items-center gap-3">
              <span class="badge-fase-dual activa-${proyResponsable}">
                <span class="fase-tag">Fase ${proyFase}</span>
                <span class="actor-tag text-uppercase">${proyResponsable}</span>
              </span>

              <c:if test="${proyResponsable == 'estudiante' and proyEstado != 'Finalizado' and proyEstado != 'Rechazado'}">
                <button class="btn btn-uts btn-sm" data-bs-toggle="modal" data-bs-target="#subirDoc">
                  <i class="fas fa-file-upload me-1"></i> Radicar Documento / Versión
                </button>
              </c:if>

              <a href="${pageContext.request.contextPath}/estudiante/seguimiento.jsp?id=${pid}" class="btn btn-outline-secondary btn-sm" title="Ver seguimiento gráfico">
                <i class="fas fa-sitemap me-1"></i> Seguimiento
              </a>
            </div>
          </div>
        </div>
      </div>

      <div class="row g-4">
        <%-- Tabla de documentos radicados --%>
        <div class="col-lg-8">
          <div class="card-sigrado h-100">
            <div class="card-header-custom">
              <h2 class="page-title">
                Documentos y <span class="badge-title-box">VERSIONES</span>
              </h2>
              <span class="badge badge-uts">${docs.rowCount} radicado${docs.rowCount == 1 ? '' : 's'}</span>
            </div>

            <div class="p-0">
              <div class="table-responsive">
                <table class="table table-hover align-middle mb-0">
                  <thead class="table-light">
                    <tr>
                      <th style="width: 25%;">Documento</th>
                      <th style="width: 12%; text-align: center;">Versión</th>
                      <th style="width: 12%; text-align: center;">Fase</th>
                      <th style="width: 28%;">Archivo</th>
                      <th style="width: 13%;">Fecha</th>
                      <th style="width: 10%; text-align: center;">Enlace</th>
                    </tr>
                  </thead>
                  <tbody>
                    <c:forEach items="${docs.rows}" var="d">
                      <tr>
                        <td>
                          <span class="badge bg-light text-dark border fw-bold">${d.tipo}</span>
                          <c:if test="${not empty d.observaciones}">
                            <div class="small text-muted mt-1 text-wrap">${d.observaciones}</div>
                          </c:if>
                        </td>
                        <td style="text-align: center;">
                          <span class="badge bg-secondary">v${d.version}</span>
                        </td>
                        <td style="text-align: center;">
                          <span class="badge badge-fase">Fase ${d.fase}</span>
                        </td>
                        <td>
                          <div class="small fw-semibold text-dark text-wrap">${d.nombre_archivo}</div>
                          <div class="small text-muted">Por: ${d.subido_por_nombre}</div>
                        </td>
                        <td>
                          <small class="text-muted"><fmt:formatDate value="${d.fecha_subida}" pattern="dd/MM/yyyy"/></small>
                        </td>
                        <td style="text-align: center;">
                          <a href="${d.url}" target="_blank" class="btn btn-outline-primary btn-sm" title="Abrir enlace institucional">
                            <i class="fas fa-external-link-alt"></i>
                          </a>
                        </td>
                      </tr>
                    </c:forEach>

                    <c:if test="${docs.rowCount == 0}">
                      <tr>
                        <td colspan="6" class="text-center py-5 text-muted">
                          <i class="fas fa-file-upload fa-2x mb-2 d-block"></i>
                          Aún no has radicado documentos en este proyecto.
                        </td>
                      </tr>
                    </c:if>
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        </div>

        <%-- Panel de dictámenes y evaluaciones --%>
        <div class="col-lg-4">
          <div class="card-sigrado h-100">
            <div class="card-header-custom">
              <h2 class="page-title">
                Conceptos y <span class="badge-title-box">EVALUACIONES</span>
              </h2>
            </div>

            <div class="p-4">
              <c:choose>
                <c:when test="${respuestas.rowCount > 0}">
                  <c:forEach items="${respuestas.rows}" var="r">
                    <div class="p-3 mb-3 bg-light rounded-3 border">
                      <div class="d-flex justify-content-between align-items-center mb-2">
                        <span class="badge badge-fase">Fase ${r.fase} · Ronda ${r.ronda}</span>
                        <c:choose>
                          <c:when test="${r.estado == 'Aprobado'}"><span class="badge bg-success">Aprobado</span></c:when>
                          <c:when test="${r.estado == 'Correcciones'}"><span class="badge bg-warning text-dark">Correcciones</span></c:when>
                          <c:otherwise><span class="badge bg-danger">${r.estado}</span></c:otherwise>
                        </c:choose>
                      </div>
                      <div class="small fw-bold text-dark">${r.emisor_nombre}</div>
                      <c:if test="${not empty r.version_evaluada}">
                        <div class="small text-muted">Versión evaluada: v${r.version_evaluada}</div>
                      </c:if>
                      <c:if test="${not empty r.acta_numero}">
                        <div class="small text-muted">Acta: ${r.acta_numero} <c:if test="${not empty r.acta_fecha}">(${r.acta_fecha})</c:if></div>
                      </c:if>
                      <c:if test="${not empty r.comentario}">
                        <div class="small text-dark mt-2 p-2 bg-white rounded border">${r.comentario}</div>
                      </c:if>
                      <c:if test="${not empty r.turnitin_url}">
                        <div class="mt-2">
                          <a href="${r.turnitin_url}" target="_blank" class="btn btn-outline-secondary btn-sm w-100 small">
                            <i class="fas fa-shield-alt me-1"></i> Ver Informe Turnitin
                          </a>
                        </div>
                      </c:if>
                      <c:if test="${not empty r.informe_fdc125_url}">
                        <div class="mt-2">
                          <a href="${r.informe_fdc125_url}" target="_blank" class="btn btn-outline-secondary btn-sm w-100 small">
                            <i class="fas fa-file-signature me-1"></i> Ver Informe Calificado
                          </a>
                        </div>
                      </c:if>
                    </div>
                  </c:forEach>
                </c:when>
                <c:otherwise>
                  <div class="text-center text-muted py-5 small">
                    <i class="fas fa-hourglass-half fa-2x mb-2 d-block text-secondary"></i>
                    Aún no se han emitido conceptos o evaluaciones para este proyecto.
                  </div>
                </c:otherwise>
              </c:choose>
            </div>
          </div>
        </div>
      </div>
    </div>

    <%-- Modal para subir documento --%>
    <div class="modal fade" id="subirDoc" tabindex="-1" aria-hidden="true">
      <div class="modal-dialog modal-dialog-centered modal-lg">
        <form method="post" action="versiones.jsp?id=${pid}" class="modal-content">
          <input type="hidden" name="accion" value="subir"/>
          <div class="modal-header modal-header-sigrado">
            <h5 class="modal-title fw-bold">
              Radicar Entrega - <span class="badge-title-box">FASE ${proyFase}</span>
            </h5>
            <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
          </div>
          <div class="modal-body p-4 row g-3">
            <div class="col-12">
              <div class="alert alert-info small mb-0">
                <i class="fas fa-info-circle me-1"></i>
                Registra el enlace público institucional de tu documento (Google Drive / OneDrive / GitHub). Cada nueva radicación generará automáticamente un número de versión incremental.
              </div>
            </div>

            <div class="col-md-6">
              <label class="form-label small fw-bold">Tipo de Documento *</label>
              <select name="tipo" class="form-select form-select-sm" required>
                <option value="">Seleccione el tipo de entrega</option>
                <c:if test="${proyFase == 1}">
                  <option value="SoportePago">Soporte de Pago de Grado</option>
                </c:if>
                <c:if test="${proyFase == 2 or proyFase == 3}">
                  <option value="Propuesta_FDC124">Propuesta de Grado (F-DC-124)</option>
                  <option value="Turnitin_FDC124">Reporte de Similitud Turnitin</option>
                </c:if>
                <c:if test="${proyFase == 4 or proyFase == 5}">
                  <option value="Informe_FDC125">Informe Final de Grado (F-DC-125)</option>
                  <option value="Turnitin_FDC125">Reporte Turnitin Informe Final</option>
                </c:if>
                <option value="Otro">Documento Anexo / Soporte adicional</option>
              </select>
            </div>

            <div class="col-md-6">
              <label class="form-label small fw-bold">Nombre representativo del archivo *</label>
              <input type="text" name="nombre_archivo" class="form-control form-control-sm" required placeholder="ej: F-DC-124_Propuesta_v2.pdf">
            </div>

            <div class="col-12">
              <label class="form-label small fw-bold">Enlace institucional (URL Drive/OneDrive) *</label>
              <input type="url" name="enlace" class="form-control form-control-sm" required placeholder="https://drive.google.com/file/d/...">
              <div class="form-text small">Asegúrese que los permisos de lectura estén habilitados institucionalmente.</div>
            </div>

            <div class="col-12">
              <label class="form-label small fw-bold">Observaciones / Descripción de cambios para el Director</label>
              <textarea name="observaciones" class="form-control form-control-sm" rows="3" placeholder="Detalla los puntos ajustados o notas relevantes..."></textarea>
            </div>
          </div>
          <div class="modal-footer modal-footer-sigrado">
            <button type="button" class="btn btn-secondary btn-sm" data-bs-dismiss="modal">Cancelar</button>
            <button type="submit" class="btn btn-uts btn-sm">
              <i class="fas fa-paper-plane me-1"></i> Radicar Documento y Enviar a Revisión
            </button>
          </div>
        </form>
      </div>
    </div>

    <%@ include file="/WEB-INF/jspf/footer.jspf" %>
  </div>
</body>
</html>